//
//  EZOnlineScorerRecorder.m
//  EZOnlineScorerRecorder
//
//  Created by Johnny on 27/03/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import "EZOnlineScorerRecorder.h"
#import "EZAudioSocket.h"
#import "EZAudioReader.h"
#import "EZLogger.h"
#import <CommonCrypto/CommonDigest.h>

NSString *const kEZOnlineScorerRecorderErrorDomain = @"EZOnlineScorerRecorderError";
NSString *const kEZOnlineScorerRecorderErrorRecorderErrorDescription = @"Online scorer failed to record.";
NSString *const kEZOnlineScorerRecorderErrorConnectionErrorDescription = @"Online scorer failed to connect with server.";
NSString *const kEZOnlineScorerRecorderErrorInvalidParameterDescription = @"Online scorer input parameters invalid.";
NSString *const kEZOnlineScorerRecorderErrorResponseJSONErrorDescription = @"Online scorer failed to decode response.";


static NSError *errorForOnlineScorerErrorCode(EZOnlineScorerRecorderError errorCode, NSError *underlyingError) {
    NSString *errorDescription;
    switch (errorCode) {
        case EZOnlineScorerRecorderErrorRecorderError:
            errorDescription = kEZOnlineScorerRecorderErrorRecorderErrorDescription;
            break;
        case EZOnlineScorerRecorderErrorConnectionError:
            errorDescription = kEZOnlineScorerRecorderErrorConnectionErrorDescription;
            break;
        case EZOnlineScorerRecorderErrorInvalidParameter:
            errorDescription = kEZOnlineScorerRecorderErrorInvalidParameterDescription;
            break;
        case EZOnlineScorerRecorderErrorResponseJSONError:
            errorDescription = kEZOnlineScorerRecorderErrorResponseJSONErrorDescription;
            break;
    }
    
    NSMutableDictionary *userInfo = [@{NSLocalizedDescriptionKey: errorDescription} mutableCopy];
    if (underlyingError) {
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    }
    NSError *error = [NSError errorWithDomain:kEZOnlineScorerRecorderErrorDomain
                                         code:errorCode
                                     userInfo:userInfo];
    
    return error;
}

static NSString *md5HexDigest(NSString *input) {
    const char* str = [input UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), result);
    
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    for(int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}

@interface EZOnlineScorerRecorder () <EZAudioSocketDelegate, EZAudioReaderDelegate>

@property (nullable, nonatomic, strong) EZAudioSocket *audioSocket;
@property (nullable, nonatomic, strong) EZAudioReader *audioReader;
@property (readwrite, getter=isProcessing) BOOL processing;
@property (nonnull, readwrite, nonatomic) NSURL *recordURL;
@property (nonnull, readwrite, nonatomic) id<EZOnlineScorerRecorderPayload> payload;
@property (nonnull, nonatomic) dispatch_queue_t onlineScorerRecorderOperationQueue;
@property (nonnull, nonatomic, strong) NSMutableData *cachedAudioData;

//flags
@property (nonatomic, assign) BOOL disposal;
@property (nonatomic, assign) BOOL recordCalled;
@property (nonatomic, assign) BOOL recordFailed;
@property (nonatomic, assign) BOOL recordStopped;

@end


@implementation EZOnlineScorerRecorder

static NSString *_appID;
static NSString *_secret;
static NSURL *_socketURL;

+ (void)configureAppID:(NSString * _Nonnull)appID secret:(NSString * _Nonnull)secret
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _appID = [appID copy];
        _secret = [secret copy];
    });
}

+ (void)setSocketURL:(NSURL *)socketURL
{
    _socketURL = [socketURL copy];
}

+ (void)setDebugMode:(BOOL)enabled
{
    [EZLogger configLogDestination:enabled ? EZLogDestinationConsole|EZLogDestinationFile : EZLogDestinationNone];
}

+ (void)exportDebugLog:(void (^__nonnull) (NSError *_Nullable error, NSURL *_Nullable logURL))completion
{
    [EZLogger generateCombinedLog:completion];
}

#pragma mark - initializer

- (instancetype _Nullable)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class EZOnlineScorerRecorder"
                                 userInfo:nil];
    return nil;
}

- (instancetype _Nullable)initWithPayload:(id<EZOnlineScorerRecorderPayload> _Nonnull)payload
{
    return [self initWithPayload:payload useSpeex:YES];
}

- (instancetype _Nullable)initWithPayload:(id<EZOnlineScorerRecorderPayload> _Nonnull)payload
                                 useSpeex:(BOOL)useSpeex
{
    if (!_appID || !_secret) {
        return nil;
    }
    
    self = [super init];
    if (self) {
        _payload = payload;
        _useSpeex = useSpeex;
        _onlineScorerRecorderOperationQueue = dispatch_queue_create("com.liulishuo.onlineScorerRecorderOperationQueue",
                                                                    DISPATCH_QUEUE_SERIAL);
        _cachedAudioData = [NSMutableData new];
    }
    return self;
}

- (void)dealloc
{
    self.audioReader.delegate = nil;
    self.audioSocket.delegate = nil;
    [self.audioReader stop];
    [self.audioSocket closeImmediately];
    EZLog(@"EZOnlineScorerRecorder dealloc");
}

#pragma mark - setter & getter

- (BOOL)isRecording
{
    return self.audioReader.isRecording;
}

- (NSURL *)socketURL
{
    if (_socketURL) {
        return _socketURL;
    }
    //return default URL
    return [NSURL URLWithString:@"wss://openapi.llsapp.com/openapi/stream/upload"];
}

#pragma mark - Configuring and Controlling Scoring

- (void)record
{
    NSString *tempPath = NSTemporaryDirectory();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    NSError *error = nil;
    if (![fileManager fileExistsAtPath:tempPath isDirectory:&isDir]) {
        EZLog(@"Directory does not exist at dirPath %@", tempPath);
        
        if (![fileManager createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            EZLog(@"=== error: %@", error.debugDescription);
        }
    }
    NSURL *tempDir = [NSURL fileURLWithPath:tempPath isDirectory:YES];
    NSURL *temporaryAudioURL = [tempDir URLByAppendingPathComponent:@"tempScorerRecord.aac" isDirectory:NO];
    [self recordToURL:temporaryAudioURL];
}

- (void)recordToURL:(NSURL * _Nonnull)fileURL
{
    if (self.recordCalled) return;
    self.recordCalled = true;
    
    NSData *metaData = [self metaData];
    if (!metaData) return;
    
    self.recordURL = fileURL;
    self.audioSocket = [[EZAudioSocket alloc] initWithSocketURL:self.socketURL metaData:metaData useSpeex:self.useSpeex];
    self.processing = YES;
    self.audioSocket.delegate = self;
    self.audioReader = [[EZAudioReader alloc] init];
    self.audioReader.delegate = self;
    [self.audioReader recordToFileURL:fileURL];
}

- (void)stopRecording
{
    if (self.disposal || !self.audioReader || !self.audioReader.isRecording) return;
    
    [self.audioReader stop];
}

- (void)stopScoring
{
    if (self.disposal) return;

    self.disposal = YES;
    self.processing = NO;
    
    [self.audioReader stop];
    [self.audioSocket closeImmediately];
    self.audioReader = nil;
    self.audioSocket = nil;
}

- (void)retry
{
    if (self.disposal || !self.recordCalled || self.recordFailed) return;
    
    self.audioSocket.delegate = nil;
    [self.audioSocket closeImmediately];
    
    self.audioSocket = [[EZAudioSocket alloc] initWithSocketURL:self.socketURL metaData:[self metaData] useSpeex:self.useSpeex];
    self.processing = YES;
    self.audioSocket.delegate = self;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.onlineScorerRecorderOperationQueue, ^{
        typeof(self) strongSelf = weakSelf;
        
        NSError *error;
        if (![strongSelf.audioSocket write:strongSelf.cachedAudioData error:&error]) {
            [strongSelf finishScoringWithErrorCode:EZOnlineScorerRecorderErrorConnectionError underlyingError:error];
            return;
        }
        
        if (strongSelf.recordStopped) {
            [strongSelf.audioSocket close];
        }
    });
}

- (NSData * _Nullable)metaData
{
    NSMutableDictionary *payload = [[self.payload jsonPayload] mutableCopy];
    payload[@"quality"] = self.useSpeex ? @(8) : @(-1);
    
    //salt
    NSInteger timestamp = (NSInteger)[NSDate date].timeIntervalSince1970;
    NSString *salt = [[NSString alloc] initWithFormat:@"%zd:%08x", timestamp, arc4random()];
    
    NSDictionary *metaJSON = @{@"item": payload,
                               @"appID": _appID,
                               @"salt": salt};
    
    NSError *error = nil;
    NSData *metaJSONData = [NSJSONSerialization dataWithJSONObject:metaJSON options:0 error:&error];
    if (error) {
        [self finishScoringWithErrorCode:EZOnlineScorerRecorderErrorInvalidParameter underlyingError:error];
        return nil;
    }
    
    NSString *metaJSONString = [[NSString alloc] initWithData:metaJSONData encoding:NSUTF8StringEncoding];
    NSString *hash = md5HexDigest([[NSString alloc] initWithFormat:@"%@+%@+%@+%@", _appID, metaJSONString, salt, _secret]);
    NSString *metaString = [[NSString alloc] initWithFormat:@"%@;hash=%@", metaJSONString, hash];
    
    return [metaString dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)finishScoringWithErrorCode:(EZOnlineScorerRecorderError)errorCode underlyingError:(NSError * _Nullable)error
{
    if (self.disposal) return;

    self.processing = NO;
    [self.audioSocket closeImmediately];
    self.audioSocket = nil;
    
    if ([self.delegate respondsToSelector:@selector(onlineScorer:didFailWithError:)]) {
        [self.delegate onlineScorer:self didFailWithError:errorForOnlineScorerErrorCode(errorCode, error)];
    }
}

- (void)finishRecordingWithErrorCode:(EZOnlineScorerRecorderError)errorCode underlyingError:(NSError * _Nullable)error
{
    if (self.disposal) return;
    
    [self.audioReader stop];
    self.audioReader = nil;
    
    if ([self.delegate respondsToSelector:@selector(onlineScorer:didFailWithError:)]) {
        [self.delegate onlineScorer:self didFailWithError:errorForOnlineScorerErrorCode(errorCode, error)];
    }
}

#pragma mark - EZAudioSocketDelegate

- (void)audioSocket:(EZAudioSocket * _Nonnull)audioSocket didReceiveData:(id _Nonnull)data
{
    EZLog(@"audioSocket didReceiveData");
    
    if (self.disposal) return;
    self.processing = NO;
    
    if (![data isKindOfClass:[NSDictionary class]]) {
        [self finishScoringWithErrorCode:EZOnlineScorerRecorderErrorResponseJSONError underlyingError:nil];
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(onlineScorer:didGenerateReport:)]) {
        [self.delegate onlineScorer:self didGenerateReport:data];
    }
    
}

- (void)audioSocket:(EZAudioSocket * _Nonnull)audioSocket didFailWithError:(NSError * _Nullable)error
{
    EZLog(@"audioSocket didFailWithError: %@", error);
    
    self.processing = NO;
    self.audioSocket.delegate = nil;
    self.audioSocket = nil;
    if (self.disposal) return;
    
    if ([self.delegate respondsToSelector:@selector(onlineScorer:didFailWithError:)]) {
        [self.delegate onlineScorer:self didFailWithError:errorForOnlineScorerErrorCode(EZOnlineScorerRecorderErrorConnectionError, error)];
    }
}

#pragma mark - EZAudioReaderDelegate

- (void)audioReader:(EZAudioReader * _Nonnull)reader didFailWithError:(NSError * _Nonnull)error
{
    EZLog(@"audioReader didFailWithError: %@", error);
    
    self.recordFailed = YES;
    if (self.disposal) return;

    [self finishRecordingWithErrorCode:EZOnlineScorerRecorderErrorRecorderError underlyingError:error];
}

- (void)audioReaderDidBeginReading:(EZAudioReader * _Nonnull)reader
{
    EZLog(@"audioReaderDidBeginReading");
    
    if (self.disposal) return;

    if ([self.delegate respondsToSelector:@selector(onlineScorerDidBeginRecording:)]) {
        [self.delegate onlineScorerDidBeginRecording:self];
    }
}

- (void)audioReader:(EZAudioReader * _Nonnull)reader didVolumnChange:(float)volumn
{
    if (self.disposal) return;

    if ([self.delegate respondsToSelector:@selector(onlineScorer:didVolumnChange:)]) {
        [self.delegate onlineScorer:self didVolumnChange:volumn];
    }
}

- (void)audioReader:(EZAudioReader * _Nonnull)reader didReceiveAudioData:(NSData * _Nonnull)audioData
{
    if (self.disposal) return;

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.onlineScorerRecorderOperationQueue, ^{
        typeof(self) strongSelf = weakSelf;
        
        [strongSelf.cachedAudioData appendData:audioData];
        NSError *error;
        if (![strongSelf.audioSocket write:audioData error:&error]) {
            [strongSelf finishScoringWithErrorCode:EZOnlineScorerRecorderErrorConnectionError underlyingError:error];
        }
    });
}

- (void)engzoAudioRecorderDidStop:(EZAudioReader * _Nonnull)reader
{
    EZLog(@"engzoAudioRecorderDidStop");
    
    self.recordStopped = YES;
    if (self.disposal) return;

    [self.audioSocket close];
    if ([self.delegate respondsToSelector:@selector(onlineScorerDidFinishRecording:)]) {
        [self.delegate onlineScorerDidFinishRecording:self];
    }
}


@end
