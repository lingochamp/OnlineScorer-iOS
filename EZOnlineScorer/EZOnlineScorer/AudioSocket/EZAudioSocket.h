//
//  EZAudioSocket.h
//  EZOnlineScorerRecorder
//
//  Created by Johnny on 27/03/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, EZAudioSocketError) {
    EZAudioSocketErrorSocketClosed,
    EZAudioSocketErrorReceivedDataTypeMismatch,
    EZAudioSocketErrorReceivedDataTooShort,
    EZAudioSocketErrorConnectionError,
};

@class EZAudioSocket;


@protocol EZAudioSocketDelegate <NSObject>

@optional

///data is either a Dictionary or Array.
- (void)audioSocket:(EZAudioSocket * _Nonnull)audioSocket didReceiveData:(id _Nonnull)data;
- (void)audioSocket:(EZAudioSocket * _Nonnull)audioSocket didFailWithError:(NSError * _Nullable)error;


@end


@interface EZAudioSocket : NSObject

@property (readonly, nonatomic, assign) BOOL useSpeex;
@property (nullable, nonatomic, weak) id<EZAudioSocketDelegate> delegate;

- (instancetype _Nonnull)initWithSocketURL:(NSURL * _Nonnull)socketURL metaData:(NSData * _Nonnull)metaData useSpeex:(BOOL)useSpeex;

- (BOOL)write:(NSData * _Nonnull)data error:(NSError * _Nullable * _Nullable)error;

/// send end of stream to server and wait for response
- (void)close;

/// do not send end of stream and close socket immediately
- (void)closeImmediately;

@end
