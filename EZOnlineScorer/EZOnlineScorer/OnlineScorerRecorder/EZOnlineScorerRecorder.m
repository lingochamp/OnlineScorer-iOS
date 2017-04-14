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
#import <CommonCrypto/CommonDigest.h>

NSString *const kEZOnlineScorerRecorderErrorDomain = @"EZOnlineScorerRecorderError";
NSString *const kEZOnlineScorerRecorderErrorRecorderErrorDescription = @"Audio reader failed to enable audio meter levels.";
NSString *const kEZOnlineScorerRecorderErrorConnectionErrorDescription = @"Audio reader failed to enqueue audio buffers.";
NSString *const kEZOnlineScorerRecorderErrorInvalidParameterDescription = @"Audio reader failed to create the audio file at the designated URL.";
NSString *const kEZOnlineScorerRecorderErrorResponseJSONErrorDescription = @"Audio reader failed to create the audio file at the designated URL.";


static NSError *errorForOnlineScorerErrorCode(EZOnlineScorerRecorderError errorCode, NSError *underlineError) {
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
    if (underlineError) {
        userInfo[NSUnderlyingErrorKey] = underlineError;
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

@end


@implementation EZOnlineScorerRecorder {
    BOOL _disposal;
}

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

#pragma mark - initializer

- (instancetype _Nullable)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class Foo"
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
        _payload = [payload jsonPayload];
        _useSpeex = useSpeex;
    }
    return self;
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
    return [NSURL URLWithString:@"wss://rating.llsstaging.com/openapi/stream/upload"];
}

#pragma mark - Configuring and Controlling Scoring

- (void)record
{
    NSString *tempPath = NSTemporaryDirectory();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    NSError *error = nil;
    if (![fileManager fileExistsAtPath:tempPath isDirectory:&isDir]) {
        NSLog(@"Directory does not exist at dirPath %@", tempPath);
        BOOL success = [fileManager createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (!success) {
            NSLog(@"=== error: %@", error.debugDescription);
        }
    }
    NSURL *tempDir = [NSURL fileURLWithPath:tempPath isDirectory:YES];
    NSURL *temporaryAudioURL = [tempDir URLByAppendingPathComponent:@"tempScorerRecord.aac" isDirectory:NO];
    [self recordToURL:temporaryAudioURL];
}

- (void)recordToURL:(NSURL * _Nonnull)fileURL
{
    if (_disposal) return;
  
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
    if (_disposal) return;

    if (!self.audioReader || !self.audioReader.isRecording) return;
    
    [self.audioReader stop];
}

- (void)stopScoring
{
    if (_disposal) return;

    _disposal = YES;
    self.processing = NO;
    
    [self.audioReader stop];
    [self.audioSocket closeImmediately];
    self.audioReader = nil;
    self.audioSocket = nil;
}

- (NSData * _Nullable)metaData
{
    NSMutableDictionary *payload = [self.payload mutableCopy];
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
        [self finishScorerWithErrorCode:EZOnlineScorerRecorderErrorInvalidParameter underlineError:error];
        return nil;
    }
    
    NSString *metaJSONString = [[NSString alloc] initWithData:metaJSONData encoding:NSUTF8StringEncoding];
    NSString *hash = md5HexDigest([[NSString alloc] initWithFormat:@"%@+%@+%@+%@", _appID, metaJSONString, salt, _secret]);
    NSString *metaString = [[NSString alloc] initWithFormat:@"%@;hash=%@", metaJSONString, hash];
    
    return [metaString dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)finishScorerWithErrorCode:(EZOnlineScorerRecorderError)errorCode underlineError:(NSError * _Nullable)error
{
    if (_disposal) return;

    [self stopScoring];
    
    if ([self.delegate respondsToSelector:@selector(onlineScorer:didFailWithError:)]) {
        [self.delegate onlineScorer:self didFailWithError:errorForOnlineScorerErrorCode(errorCode, error)];
    }

}

#pragma mark - EZAudioSocketDelegate

- (void)audioSocket:(EZAudioSocket * _Nonnull)audioSocket didReceiveData:(id _Nonnull)data
{
    NSLog(@"audioSocket didReceiveData");
    
    if (_disposal) return;
    self.processing = NO;
    
    if (![data isKindOfClass:[NSDictionary class]]) {
        [self finishScorerWithErrorCode:EZOnlineScorerRecorderErrorResponseJSONError underlineError:nil];
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(onlineScorer:didGenerateReport:)]) {
        [self.delegate onlineScorer:self didGenerateReport:data];
    }
    
}

- (void)audioSocket:(EZAudioSocket * _Nonnull)audioSocket didFailWithError:(NSError * _Nullable)error
{
    NSLog(@"audioSocket didFailWithError: %@", error);
    
    if (_disposal) return;
    self.processing = NO;
    
    if ([self.delegate respondsToSelector:@selector(onlineScorer:didFailWithError:)]) {
        [self.delegate onlineScorer:self didFailWithError:errorForOnlineScorerErrorCode(EZOnlineScorerRecorderErrorConnectionError, error)];
    }
}

#pragma mark - EZAudioReaderDelegate

- (void)audioReader:(EZAudioReader * _Nonnull)reader didFailWithError:(NSError * _Nonnull)error
{
    NSLog(@"audioReader didFailWithError: %@", error);
    
    if (_disposal) return;

    [self finishScorerWithErrorCode:EZOnlineScorerRecorderErrorRecorderError underlineError:error];
}

- (void)audioReaderDidBeginReading:(EZAudioReader * _Nonnull)reader
{
    NSLog(@"audioReaderDidBeginReading");
    
    if (_disposal) return;

    if ([self.delegate respondsToSelector:@selector(onlineScorerDidBeginReading:)]) {
        [self.delegate onlineScorerDidBeginReading:self];
    }
}

- (void)audioReader:(EZAudioReader * _Nonnull)reader didVolumnChange:(float)volumn
{
    if (_disposal) return;

    if ([self.delegate respondsToSelector:@selector(onlineScorer:didVolumnChange:)]) {
        [self.delegate onlineScorer:self didVolumnChange:volumn];
    }
}

- (void)audioReader:(EZAudioReader * _Nonnull)reader didReceiveAudioData:(NSData * _Nonnull)audioData
{
    if (_disposal) return;

    NSError *error;
    if (![self.audioSocket write:audioData error:&error]) {
        [self finishScorerWithErrorCode:EZOnlineScorerRecorderErrorConnectionError underlineError:error];
    }
}

- (void)engzoAudioRecorderDidStop:(EZAudioReader * _Nonnull)reader
{
    NSLog(@"engzoAudioRecorderDidStop");
    
    if (_disposal) return;

    [self.audioSocket close];
    if ([self.delegate respondsToSelector:@selector(onlineScorerDidStop:)]) {
        [self.delegate onlineScorerDidStop:self];
    }
}


@end
