//
//  EZAudioReader.m
//  EngzoAudioRecorderToolKitDemo
//
//  Created by yangyang on 7/30/14.
//  Copyright (c) 2014 liulishuo. All rights reserved.
//

#import "EZAudioReader.h"
#import "EZLogger.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define kNumberOfBuffers 2
#define kBufferByteSize 32768
#define kAudioQueBufferByteSize 4096
#define kMaxNumInputPackets 12288 // kBufferByteSize / sizePerPacket(=2)
#define kEnergySmoothingWindowSize 20

typedef struct {
    // The input audio format, collected from audio device. Must be PCM 16-bit format for the scoring module.
    AudioStreamBasicDescription mInputFormat;
    // The output audio format that is saved to the disk.
    AudioStreamBasicDescription mOutputFormat;
    // The input buffer size for conversion.
    UInt32 mInputBufferByteSize;
    // The output buffer size to the encoded data.
    UInt32 mOutputBufferByteSize;
    
    // Audio Queue related
    AudioQueueRef mQueue;
    AudioQueueBufferRef mBuffers[kNumberOfBuffers];
    
    // The AudioFileID for output (Apple lossless compressed)
    AudioFileID mAudioFile;
    // The current packet when writing the output file.
    SInt64 mCurrentPacket;
    bool mAudioFileIsSet;
    
    // Reference to the current audio queue buffer that holds the input audio dada for conversion. Use in conversion callback function.
    AudioQueueBufferRef mCurrentBuffer;
    bool mCurrenBufferIsUsed;
    
    // A buffer that holds the encoded data.
    void *mOutputBuffer;
    
    UInt32 mNumOutputPackets;
    AudioStreamPacketDescription *mOutputPacketDescriptions;
    
    // Indicate whether the recording is running.
    bool mIsRunning;
    void *mDelegateRef;
    
    // Reference to the converter.
    AudioConverterRef mConverter;
} EZAudioReaderState;

@interface EZAudioReader ()
{
    EZAudioReaderState _state;
}

@property (nonatomic, readwrite, assign) CGFloat currentPlayDuration;

@end

@implementation EZAudioReader {
    NSMutableArray *_window;
    BOOL _isReady;
}


NSString *const kEZAudioReaderErrorDomain = @"EZAudioReader";
NSString *const kFailedToEnableLevelMeteringDescription = @"Audio reader failed to enable audio meter levels.";
NSString *const kFailedToAllocateAudioBufferDescription = @"Audio reader failed to allocate audio buffers.";
NSString *const kFailedToEnqueueAudioBufferDescription = @"Audio reader failed to enqueue audio buffers.";
NSString *const kFailedToCreateAudioFileDescription = @"Audio reader failed to create the audio file at the designated URL.";
NSString *const kFailedToOpenAudioReaderQueueDescription = @"Audio reader failed to open the audio capture queue.";
NSString *const kFailedToGetAudioLevelDescription = @"Audio reader failed to get audio levels.";
NSString *const kFailedToStartUtterance = @"Audio reader failed to start utterance.";
NSString *const kFailedToConvertAudio = @"Audio reader failed to convert audio.";

static NSError *errorForAudioErrorCode(EZAudioReaderError errorCode, OSStatus status)
{
    NSString *errorDescription;
    switch (errorCode)
    {
        case EZAudioReaderErrorFailedToEnableLevelMetering:
        {
            errorDescription = kFailedToEnableLevelMeteringDescription;
            break;
        }
            
        case EZAudioReaderErrorFailedToAllocateAudioBuffer:
        {
            errorDescription = kFailedToAllocateAudioBufferDescription;
            break;
        }
            
        case EZAudioReaderErrorFailedToEnqueueAudioBuffer:
        {
            errorDescription = kFailedToEnqueueAudioBufferDescription;
            break;
        }
            
        case EZAudioReaderErrorFailedToCreateAudioFile:
        {
            errorDescription = kFailedToCreateAudioFileDescription;
            break;
        }
            
        case EZAudioReaderErrorFailedToOpenAudioReaderQueue:
        {
            errorDescription = kFailedToOpenAudioReaderQueueDescription;
            break;
        }
            
        case EZAudioReaderErrorFailedToGetAudioLevel:
        {
            errorDescription = kFailedToGetAudioLevelDescription;
            break;
        }
            
        case EZAudioReaderErrorFailedToStartUtterance:
        {
            errorDescription = kFailedToStartUtterance;
            break;
        }
            
        case EZAudioReaderErrorFailedToConvertAudio:
        {
            errorDescription = kFailedToConvertAudio;
            break;
        }
    }
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorDescription
                                                         forKey:NSLocalizedDescriptionKey];
    NSError *error = [NSError errorWithDomain:kEZAudioReaderErrorDomain
                                         code:status
                                     userInfo:userInfo];
    
    return error;
}


// Sets the packet table containing information about the number of valid frames in a file and where they begin and end
// for the file types that support this information.
// Calling this function makes sure we write out the priming and remainder details to the destination file
static void WritePacketTableInfo(AudioConverterRef converter, AudioFileID destinationFileID)
{
    UInt32 isWritable;
    UInt32 dataSize;
    OSStatus error = AudioFileGetPropertyInfo(destinationFileID,
                                              kAudioFilePropertyPacketTableInfo,
                                              &dataSize,
                                              &isWritable);
    if (noErr == error && isWritable)
    {
        AudioConverterPrimeInfo primeInfo;
        dataSize = sizeof(primeInfo);
        
        // retrieve the leadingFrames and trailingFrames information from the converter,
        error = AudioConverterGetProperty(converter,
                                          kAudioConverterPrimeInfo,
                                          &dataSize,
                                          &primeInfo);
        
        if (noErr == error)
        {
            // we have some priming information to write out to the destination file
            /* The total number of packets in the file times the frames per packet (or counting each packet's
             frames individually for a variable frames per packet format) minus mPrimingFrames, minus
             mRemainderFrames, should equal mNumberValidFrames.
             */
            AudioFilePacketTableInfo pti;
            dataSize = sizeof(pti);
            error = AudioFileGetProperty(destinationFileID,
                                         kAudioFilePropertyPacketTableInfo,
                                         &dataSize,
                                         &pti);
            
            if (noErr == error)
            {
                // there's priming to write out to the file
                UInt64 totalFrames = pti.mNumberValidFrames + pti.mPrimingFrames + pti.mRemainderFrames;
                // get the total number of frames from the output file
                EZLog(@"Total number of frames from output file: %lld\n", totalFrames);
                pti.mPrimingFrames = primeInfo.leadingFrames;
                pti.mRemainderFrames = primeInfo.trailingFrames;
                pti.mNumberValidFrames = totalFrames - pti.mPrimingFrames - pti.mRemainderFrames;
                
                error = AudioFileSetProperty(destinationFileID,
                                             kAudioFilePropertyPacketTableInfo,
                                             sizeof(pti),
                                             &pti);
                
                if (noErr == error)
                {
                    EZLog(@"Writing packet table information to destination file: %ld\n", sizeof(pti));
                    EZLog(@"     Total valid frames: %lld\n", pti.mNumberValidFrames);
                    EZLog(@"         Priming frames: %d\n", (int)pti.mPrimingFrames);
                    EZLog(@"       Remainder frames: %d\n", (int)pti.mRemainderFrames);
                }
                else
                {
                    EZLog(@"Some audio files can't contain packet table information and that's OK\n");
                }
            }
            else
            {
                EZLog(@"Getting kAudioFilePropertyPacketTableInfo error: %d\n", (int)error);
            }
        }
        else
        {
            EZLog(@"No kAudioConverterPrimeInfo available and that's OK\n");
        }
    }
    else
    {
        EZLog(@"GetPropertyInfo for kAudioFilePropertyPacketTableInfo error: %d, isWritable: %u\n", (int)error, (unsigned int)isWritable);
    }
}

static void WriteCookie(AudioConverterRef converter, AudioFileID destinationFileID)
{
    // grab the cookie from the converter and write it to the destinateion file
    UInt32 cookieSize = 0;
    OSStatus error = AudioConverterGetPropertyInfo(converter,
                                                   kAudioConverterCompressionMagicCookie,
                                                   &cookieSize,
                                                   NULL);
    
    // if there is an error here, then the format doesn't have a cookie - this is perfectly fine as some formats do not
    if (noErr == error && 0 != cookieSize)
    {
        char *cookie = (char *)malloc(cookieSize);
        
        error = AudioConverterGetProperty(converter,
                                          kAudioConverterCompressionMagicCookie,
                                          &cookieSize,
                                          cookie);
        if (noErr == error)
        {
            error = AudioFileSetProperty(destinationFileID,
                                         kAudioFilePropertyMagicCookieData,
                                         cookieSize,
                                         cookie);
        }
        
        free(cookie);
    }
}

static OSStatus EncoderDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    EZAudioReaderState *pAqData = (EZAudioReaderState *)inUserData;
//    EZLog(@"ask ioNumberDataPackets %u", (unsigned int)*ioNumberDataPackets);
    // put the data pointer into the buffer list
    if (*ioNumberDataPackets > kMaxNumInputPackets)
    {
        *ioNumberDataPackets = kMaxNumInputPackets;
    }
    
    ioData->mBuffers[0].mData = (void *)pAqData->mCurrentBuffer->mAudioData;
    
    if (pAqData->mCurrenBufferIsUsed == true)
    {
        ioData->mBuffers[0].mDataByteSize = 0;
        *ioNumberDataPackets = 0;
    }
    else
    {
        ioData->mBuffers[0].mDataByteSize = pAqData->mCurrentBuffer->mAudioDataByteSize;
        *ioNumberDataPackets = pAqData->mCurrentBuffer->mAudioDataByteSize / pAqData->mInputFormat.mBytesPerPacket;
    }
    
    ioData->mBuffers[0].mNumberChannels = 1;
    pAqData->mCurrenBufferIsUsed = true;
//    EZLog(@"got ioNumberDataPackets %u", (unsigned int)*ioNumberDataPackets);
    if (outDataPacketDescription)
    {
        if (/* DISABLES CODE */ (0))   //pAqData->mOutputPacketDescriptions) {
        {
//            *outDataPacketDescription = pAqData->mOutputPacketDescriptions;
        }
        else
        {
            *outDataPacketDescription = NULL;
        }
    }
    
    return noErr;
}

static void HandleInputBuffer(void *aqData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime, UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc)
{
    EZAudioReaderState *pAqData = (EZAudioReaderState *)aqData;
    if (inNumPackets == 0 &&
        pAqData->mInputFormat.mBytesPerPacket != 0)
    {
        inNumPackets = inBuffer->mAudioDataByteSize / pAqData->mInputFormat.mBytesPerPacket;
    }
    
    if (inBuffer->mAudioDataByteSize == 0)
    {
        if (pAqData->mIsRunning)
        {
            //[delegate audioReaderDidCatpureAudioBuffer:inBuffer];
            AudioQueueEnqueueBuffer(pAqData->mQueue, inBuffer, 0, NULL);
        }
        
        return;
    }
    
    // Do the convertion
    AudioBufferList convertedData;
    convertedData.mNumberBuffers = 1;
    convertedData.mBuffers[0].mNumberChannels = 1;
    convertedData.mBuffers[0].mDataByteSize = pAqData->mOutputBufferByteSize;
    convertedData.mBuffers[0].mData = pAqData->mOutputBuffer;
    
    pAqData->mCurrentBuffer = inBuffer;
    pAqData->mCurrenBufferIsUsed = false;
    
    EZAudioReader *recorder = (__bridge EZAudioReader *)pAqData->mDelegateRef;
    if ([recorder.delegate respondsToSelector:@selector(audioReader:didReceiveAudioData:)])
    {
        NSData *data = [NSData dataWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
        [recorder.delegate audioReader:recorder didReceiveAudioData:data];
    }
    
    AudioConverterReset(pAqData->mConverter);
    UInt32 ioOutputDataPackets = pAqData->mNumOutputPackets;
    OSStatus error =
    AudioConverterFillComplexBuffer(pAqData->mConverter,
                                    EncoderDataProc,
                                    aqData,
                                    &ioOutputDataPackets,
                                    &convertedData,
                                    pAqData->mOutputPacketDescriptions);
    
    // if interrupted in the process of the conversion call, we must handle the error appropriately
    if (error)
    {
        if (kAudioConverterErr_HardwareInUse == error)
        {
            EZLog(@"Audio Converter returned kAudioConverterErr_HardwareInUse!\n");
            // Maybe we should do something here...
        }
        
        EZLog(@"Audio converter failed.");
    }
    else if (ioOutputDataPackets == 0)
    {
        EZLog(@"Zero output data packets");
    }
    
    if (pAqData->mAudioFileIsSet &&
        AudioFileWritePackets(pAqData->mAudioFile,
                              false,
                              convertedData.mBuffers[0].mDataByteSize,
                              pAqData->mOutputPacketDescriptions,
                              pAqData->mCurrentPacket,
                              &ioOutputDataPackets,
                              pAqData->mOutputBuffer) == noErr)
    {
        pAqData->mCurrentPacket += ioOutputDataPackets;
    }
    else
    {
        EZLog(@"Write file error");
    }
    
    if (pAqData->mIsRunning)
    {
        //[delegate audioReaderDidCatpureAudioBuffer:inBuffer];
        AudioQueueEnqueueBuffer(pAqData->mQueue, inBuffer, 0, NULL);
    }
}

- (void)dealloc
{
    free(_state.mOutputBuffer);
    AudioQueueDispose(_state.mQueue, true);
    EZLog(@"EZAudioReader dealloc");
}

- (void)handleError:(NSError *)error
{
    _state.mIsRunning = false;
    if ([[self delegate] respondsToSelector:@selector(audioReader:didFailWithError:)])
    {
        [[self delegate] audioReader:self didFailWithError:error];
    }
}

- (void)setInputOutputFormat
{
    memset(&_state.mInputFormat, 0, sizeof(_state.mInputFormat));
    _state.mInputFormat.mSampleRate = 16000.0;
    _state.mInputFormat.mFormatID = kAudioFormatLinearPCM;
    _state.mInputFormat.mFormatFlags =
    kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    _state.mInputFormat.mBytesPerPacket = 2;
    _state.mInputFormat.mFramesPerPacket = 1;
    _state.mInputFormat.mBytesPerFrame = 2;
    _state.mInputFormat.mChannelsPerFrame = 1;
    _state.mInputFormat.mBitsPerChannel = 16;
    
    memset(&_state.mOutputFormat, 0, sizeof(_state.mOutputFormat));
    _state.mOutputFormat.mFormatID = kAudioFormatAppleLossless;
    _state.mOutputFormat.mSampleRate = 16000.0;
    _state.mOutputFormat.mChannelsPerFrame = 1;
    _state.mOutputFormat.mBitsPerChannel = 0; //for compressed formats the mBitsPerChannel field is always 0
    _state.mOutputFormat.mBytesPerPacket = 0;
    _state.mOutputFormat.mFramesPerPacket = 4096;
    _state.mOutputFormat.mFormatFlags = kAppleLosslessFormatFlag_16BitSourceData;
    
    
    AudioConverterNew(&_state.mInputFormat,
                      &_state.mOutputFormat,
                      &_state.mConverter);
    
    _state.mOutputPacketDescriptions = NULL;
}

- (void)setupCoreAudioUtil
{
    [self setInputOutputFormat];
    
    _state.mAudioFileIsSet = false;
    
    OSStatus status = AudioQueueNewInput(&_state.mInputFormat,
                                         HandleInputBuffer,
                                         &_state,
                                         CFRunLoopGetCurrent(),
                                         kCFRunLoopCommonModes,
                                         0,
                                         &_state.mQueue);
    
    
    SInt32 metering = 1;
    AudioQueueSetProperty(_state.mQueue,
                          kAudioQueueProperty_EnableLevelMetering,
                          &metering,
                          sizeof(metering));
    
    
    if (status != noErr)
    {
        [self handleError:errorForAudioErrorCode(EZAudioReaderErrorFailedToEnableLevelMetering, status)];
        
        return;
    }
    
    UInt32 dataFormatSize = sizeof(_state.mInputFormat);
    AudioQueueGetProperty(_state.mQueue,
                          kAudioConverterCurrentOutputStreamDescription,
                          &_state.mInputFormat,
                          &dataFormatSize);
    
    
    _state.mInputBufferByteSize = kBufferByteSize;
    
    
    // setup input buffer for the audio queue.
    for (int i = 0; i < kNumberOfBuffers; ++i)
    {
        status = AudioQueueAllocateBuffer(_state.mQueue,
                                          kAudioQueBufferByteSize,
                                          &_state.mBuffers[i]);
        if (status != noErr)
        {
            [self handleError:errorForAudioErrorCode(EZAudioReaderErrorFailedToAllocateAudioBuffer, status)];
            
            return;
        }
        
        status = AudioQueueEnqueueBuffer(_state.mQueue, _state.mBuffers[i], 0, NULL);
        if (status != noErr)
        {
            [self handleError:errorForAudioErrorCode(EZAudioReaderErrorFailedToEnqueueAudioBuffer, status)];
            
            return;
        }
    }
    
    // We need to get max size per packet from the converter
    UInt32 outputSizePerPacket;
    UInt32 size = sizeof(outputSizePerPacket);
    AudioConverterGetProperty(_state.mConverter,
                              kAudioConverterPropertyMaximumOutputPacketSize,
                              &size,
                              &outputSizePerPacket);
    
    // allocate memory for the PacketDescription structures describing the layout of each packet
    _state.mOutputBufferByteSize = kBufferByteSize;
    _state.mNumOutputPackets = _state.mOutputBufferByteSize / outputSizePerPacket;
    _state.mOutputBuffer = malloc(sizeof(char) * _state.mOutputBufferByteSize);
    
    _state.mOutputPacketDescriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * _state.mNumOutputPackets);
    
    _state.mDelegateRef = (__bridge void *)(self);
}

- (void)setFileURL:(NSURL *)url
{
    AudioFileTypeID fileType = kAudioFileM4AType;
    //AudioFileTypeID fileType = kAudioFileCAFType;
    
    
    OSStatus status = AudioFileCreateWithURL((__bridge CFURLRef)url,
                                             fileType,
                                             &_state.mOutputFormat,
                                             kAudioFileFlags_EraseFile,
                                             &_state.mAudioFile);
    
    if (status != noErr)
    {
        if ([[self delegate] respondsToSelector:@selector(audioReader:didFailWithError:)])
        {
            [[self delegate] audioReader:self
                        didFailWithError:errorForAudioErrorCode(EZAudioReaderErrorFailedToCreateAudioFile, status)];
        }
        
        return;
    }
    
    WriteCookie(_state.mConverter,
                _state.mAudioFile);
    
    _state.mAudioFileIsSet = true;
}


- (void)recordToFileURL:(NSURL * _Nonnull)fileURL
{
    if (self.isRecording || _isReady)
    {
        return;
    }
    
    _isReady = YES;
    [self setupCoreAudioUtil];
    
    self.currentPlayDuration = 0;
    
    [self setFileURL:fileURL];
    
    _state.mCurrentPacket = 0;
    _state.mIsRunning = true;
    
    OSStatus status = AudioQueueStart(_state.mQueue, NULL);
    if (status != noErr)
    {
        [self handleError:errorForAudioErrorCode(EZAudioReaderErrorFailedToOpenAudioReaderQueue, status)];
        _isReady = NO;
        return;
    }
    else
    {
        if ([[self delegate] respondsToSelector:@selector(audioReaderDidBeginReading:)])
        {
            [[self delegate] audioReaderDidBeginReading:self];
        }
        
        [self startProgress];
    }
  
    for (int i = 0; i < kEnergySmoothingWindowSize; ++i)
    {
        [_window replaceObjectAtIndex:i withObject:[NSNumber numberWithInt:0]];
    }
    
    _isReady = NO;
    
}

- (float)getPower
{
    AudioQueueLevelMeterState levels[1];
    UInt32 dataSize = sizeof(AudioQueueLevelMeterState);
    OSStatus status = AudioQueueGetProperty(_state.mQueue,
                                            kAudioQueueProperty_CurrentLevelMeterDB,
                                            levels,
                                            &dataSize);
    if (status != noErr)
    {
        if ([[self delegate] respondsToSelector:@selector(audioReader:didFailWithError:)])
        {
            [[self delegate] audioReader:self
                        didFailWithError:errorForAudioErrorCode(EZAudioReaderErrorFailedToGetAudioLevel, status)];
        }
    }
    
    float power = levels[0].mAveragePower;
    
    return power;
}

- (BOOL)isRecording
{
    return _state.mIsRunning;
}

- (void)startProgress
{
    float_t delayInSeconds = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.currentPlayDuration = delayInSeconds;
        [self updateProgress];
    });
}

- (void)updateProgress
{
    if (_state.mIsRunning)
    {
        float power = [self getPower];
        
        [self stopWithLimitDuration];
        
        float v = MAX(0, (70 + power));
        if ([[self delegate] respondsToSelector:@selector(audioReader:didVolumnChange:)])
        {
            [[self delegate] audioReader:self didVolumnChange:v / 70];
        }
        
        float_t delayInMilliSeconds = 10;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInMilliSeconds * NSEC_PER_MSEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            self.currentPlayDuration += 0.01; // This is now an approximation.
            [self updateProgress];
        });
    }
}

- (void)stop
{
    if (!_state.mIsRunning || _isReady || _state.mCurrentPacket <= 0)
    {
        return;
    }
    
    AudioQueueStop(_state.mQueue, true);
    AudioQueueReset(_state.mQueue);
    WritePacketTableInfo(_state.mConverter, _state.mAudioFile);
    WriteCookie(_state.mConverter,
                _state.mAudioFile);
    _state.mIsRunning = false;
    //AudioQueueDispose(_state.mQueue, true);
    AudioFileClose(_state.mAudioFile);
    
    if ([[self delegate] respondsToSelector:@selector(engzoAudioRecorderDidStop:)])
    {
        [[self delegate] engzoAudioRecorderDidStop:self];
    }
}

- (void)stopWithLimitDuration
{
    if (self.currentPlayDuration >= 20.0 && self.enableLimitDuration)
    {
        [self stop];
        if ([self.delegate respondsToSelector:@selector(engzoAudioRecorderDidStop:)])
        {
            [self.delegate engzoAudioRecorderDidStop:self];
        }
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.enableLimitDuration = YES;
        
        _window = [[NSMutableArray alloc] initWithCapacity:kEnergySmoothingWindowSize];
        for (int i = 0; i < kEnergySmoothingWindowSize; ++i)
        {
            [_window addObject:[NSNumber numberWithInt:0]];
        }
    }
    return self;
}


@end
