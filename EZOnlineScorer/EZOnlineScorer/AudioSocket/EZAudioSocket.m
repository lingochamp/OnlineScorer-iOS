//
//  EZAudioSocket.m
//  EZOnlineScorerRecorder
//
//  Created by Johnny on 27/03/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import "EZAudioSocket.h"
#import "EZSRWebSocket.h"
#import "EZSpeexManager.h"
#import "EZLogger.h"

NSString *const kEZAudioSocketErrorDomain = @"EZAudioSocketError";
NSString *const kEZAudioSocketErrorSocketClosedDescription = @"Audio socket failed to send data because socket connnection already closed.";
NSString *const kEZAudioSocketErrorReceivedDataTypeMismatchDescription = @"Audio socket failed to allocate audio buffers.";
NSString *const kEZAudioSocketErrorReceivedDataTooShortDescription = @"Audio socket received data too short.";
NSString *const kEZAudioSocketErrorConnectionErrorDescription = @"Audio socket web socket error.";

static NSError *errorForAudioSocketErrorCode(EZAudioSocketError errorCode, NSError *underlineError) {
    NSString *errorDescription;
    switch (errorCode) {
        case EZAudioSocketErrorSocketClosed:
            errorDescription = kEZAudioSocketErrorSocketClosedDescription;
            break;
        case EZAudioSocketErrorReceivedDataTooShort:
            errorDescription = kEZAudioSocketErrorReceivedDataTooShortDescription;
            break;
        case EZAudioSocketErrorReceivedDataTypeMismatch:
            errorDescription = kEZAudioSocketErrorReceivedDataTypeMismatchDescription;
            break;
        case EZAudioSocketErrorConnectionError:
            errorDescription = kEZAudioSocketErrorConnectionErrorDescription;
            break;
    }
    
    NSMutableDictionary *userInfo = [@{NSLocalizedDescriptionKey: errorDescription} mutableCopy];
    if (underlineError) {
        userInfo[NSUnderlyingErrorKey] = underlineError;
    }
    NSError *error = [NSError errorWithDomain:kEZAudioSocketErrorDomain
                                         code:errorCode
                                     userInfo:userInfo];
    
    return error;
}

@interface EZAudioSocket () <EZSRWebSocketDelegate, EZSpeexManagerDelegate>

@property (nonnull, nonatomic, strong) NSURL *socketURL;
@property (nonnull, nonatomic, strong) EZSRWebSocket *webSocket;
@property (nonnull, nonatomic, copy) NSData *metaData;
@property (nonnull, nonatomic, strong) EZSpeexManager *speexManager;
@property (nonatomic, assign) BOOL readyToClose;
@property (nonatomic, assign) BOOL messageSent;
@property (nonatomic, assign) BOOL metaSent;
@property (nonatomic, assign) BOOL allDataReceived;
@property (nonnull, nonatomic, strong) NSMutableData *audioBuffer;

@end

//AudioSocket can process PCM audio data to speex (optional) and send to sesame server
@implementation EZAudioSocket

- (void)dealloc
{
    [self closeImmediately];
    EZLog(@"AudioSocket dealloc");
}

- (instancetype _Nonnull)initWithSocketURL:(NSURL * _Nonnull)socketURL metaData:(NSData * _Nonnull)metaData useSpeex:(BOOL)useSpeex
{
    self = [super init];
    if (self) {
        _socketURL = socketURL;
        _metaData = metaData;
        _useSpeex = useSpeex;
        _audioBuffer = [NSMutableData new];
        _webSocket = [[EZSRWebSocket alloc] initWithURL:socketURL];
        _webSocket.delegate = self;
        [_webSocket open];
        
        //SR_CONNECTING timeout
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            if (weakSelf.webSocket && weakSelf.webSocket.readyState == SR_CONNECTING) {
                [self.delegate audioSocket:self didFailWithError:errorForAudioSocketErrorCode(EZAudioSocketErrorConnectionError, nil)];
                [weakSelf closeImmediately];
            }
        });
    }
    return self;
}

#pragma mark - Business logic


- (BOOL)write:(NSData * _Nonnull)data error:(NSError * _Nullable * _Nullable)error
{
    if (self.webSocket.readyState == SR_CLOSING || self.webSocket.readyState == SR_CLOSED) {
        *error = errorForAudioSocketErrorCode(EZAudioSocketErrorSocketClosed, nil);
        return NO;
    }
    
    [self.audioBuffer appendData:data];
    
    if (self.webSocket.readyState == SR_OPEN) {
        [self sendPendingData];
    }
    
    return YES;
}

/// send end of stream to server and wait for response
- (void)close
{
    self.allDataReceived = YES;
    [self sendEndOfStream];
}

/// do not send end of stream and close socket immediately
- (void)closeImmediately
{
    self.readyToClose = YES;
    [self.webSocket close];
}

- (void)sendPendingData
{
    if (self.webSocket.readyState != SR_OPEN) return;
    
    if (self.useSpeex) {
        [self.speexManager appendPcmData:self.audioBuffer isEnd:NO];
    } else if (self.audioBuffer.length != 0) {
        [self.webSocket send:self.audioBuffer];
    }
    
    self.audioBuffer.length = 0;//clear up data
}

- (void)sendMetaData
{
    NSData *base64Data = [self.metaData base64EncodedDataWithOptions:0];
    
    uint32_t metaLength = CFSwapInt32HostToBig((uint32_t)base64Data.length);
    
    //meta length
    NSMutableData *metaData = [[NSMutableData alloc] initWithBytes:&metaLength length:sizeof(uint32_t)];
    
    //meta
    [metaData appendData:base64Data];
    [self.webSocket send:metaData];
    self.metaSent = YES;
}

- (void)sendEndOfStream
{
    if (!self.metaSent || self.readyToClose) return;
    
    [self sendPendingData];
    self.readyToClose = YES;
    
    const unsigned char bytes[] = {0x45, 0x4f, 0x53};
    NSData *eof = [[NSData alloc] initWithBytes:bytes length:sizeof(bytes)];
    [self.webSocket send:eof];
    
    //socketCloseTimeout
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (strongSelf.webSocket.readyState == SR_OPEN && strongSelf.messageSent) {
            [strongSelf forceSendMessage:@"socket waiting to close timeout"];
        }
    });
    
}

- (BOOL)handleReceivedData:(NSData *)message error:(NSError * _Nullable * _Nullable)error
{
    self.messageSent = YES;
    
    NSData *dataMessage = message;
    if (dataMessage.length < sizeof(uint32_t)) {
        *error = errorForAudioSocketErrorCode(EZAudioSocketErrorReceivedDataTooShort, nil);
        [self closeImmediately];
        return NO;
    }
    
    uint32_t metaLength = 0;
    [dataMessage getBytes:&metaLength range:NSMakeRange(0, sizeof(uint32_t))];
    metaLength = CFSwapInt32HostToBig(metaLength);
    
    if (metaLength > dataMessage.length + sizeof(uint32_t)) {
        *error = errorForAudioSocketErrorCode(EZAudioSocketErrorReceivedDataTooShort, nil);
        [self closeImmediately];
        return NO;
    }
    
    NSData *metaData = [dataMessage subdataWithRange:NSMakeRange(sizeof(uint32_t), metaLength)];
    
    NSError *jsonError = nil;
    
    //NOTE: can't sure report is a dictionary here, so need type check below
    NSDictionary *meta = [NSJSONSerialization JSONObjectWithData:metaData options:0 error:&jsonError];
    if (jsonError
        || ![meta isKindOfClass:[NSDictionary class]]
        || ![meta[@"status"] isKindOfClass:[NSNumber class]]
        || ![meta[@"msg"] isKindOfClass:[NSString class]]
        || ![meta[@"result"] isKindOfClass:[NSString class]]) {
        *error = errorForAudioSocketErrorCode(EZAudioSocketErrorReceivedDataTypeMismatch, jsonError);
        [self closeImmediately];
        return NO;
    }
    
    NSInteger statusCode = [meta[@"status"] integerValue];
    
    if (statusCode != 0)
    {
        NSString *message = meta[@"msg"];
        *error = [NSError errorWithDomain:kEZAudioSocketErrorDomain
                                             code:statusCode
                                         userInfo:@{NSLocalizedDescriptionKey: message}];
        [self closeImmediately];
        return NO;
    }

    NSData *decodeData = [[NSData alloc] initWithBase64EncodedString:meta[@"result"] options:0];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:decodeData options:0 error:&jsonError];
    if (jsonError) {
        *error = errorForAudioSocketErrorCode(EZAudioSocketErrorReceivedDataTypeMismatch, nil);
        [self closeImmediately];
        return NO;
    }
    
    
    if ([self.delegate respondsToSelector:@selector(audioSocket:didReceiveData:)]) {
        [self.delegate audioSocket:self didReceiveData:result];
    }
    
    [self closeImmediately];
    return YES;
}

- (void)forceSendMessage:(NSString * _Nonnull)message
{
    if (self.messageSent) return;
    
    NSString *wholeMessage = [NSString stringWithFormat:@"{\"status\":-10,\"msg\":\"%@\",\"result\":null}", message];
    NSData *responseData = [wholeMessage dataUsingEncoding:NSUTF8StringEncoding];
    if ([self.delegate respondsToSelector:@selector(audioSocket:didReceiveData:)]) {
        [self.delegate audioSocket:self didReceiveData:responseData];
    }
    
    [self closeImmediately];
}

#pragma mark - getter & setter

- (EZSpeexManager *)speexManager
{
    if (!_speexManager) {
        _speexManager = [EZSpeexManager new];
        _speexManager.delegate = self;
    }
    return _speexManager;
}

#pragma mark - EZSRWebSocketDelegate

- (void)webSocketDidOpen:(EZSRWebSocket *)webSocket
{
    [self sendMetaData];
    if (self.allDataReceived) {
        [self sendEndOfStream];
    } else {
        [self sendPendingData];
    }
}

- (void)webSocket:(EZSRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSError *error = nil;
    if (![message isKindOfClass:[NSData class]] || ![self handleReceivedData:message error:&error]) {
        [self.delegate audioSocket:self didFailWithError:error];
    }
}

- (void)webSocket:(EZSRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    if (!self.readyToClose) {
        [self.delegate audioSocket:self didFailWithError:errorForAudioSocketErrorCode(EZAudioSocketErrorConnectionError, error)];
        [self closeImmediately];
    }
}

- (void)webSocket:(EZSRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    self.readyToClose = YES;
    EZLog(@"webSocket closed with code: %zd reason: %@ wasClean: %i", code, reason, wasClean);
}

#pragma mark - EZSpeexManagerDelegate

- (void)speexManager:(EZSpeexManager *)speexManager didGenerateSpeexData:(NSData *)data
{
    if (self.webSocket.readyState != SR_OPEN) return;
    [self.webSocket send:data];
}

@end
