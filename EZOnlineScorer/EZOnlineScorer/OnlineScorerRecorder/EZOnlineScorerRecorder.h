//
//  EZOnlineScorerRecorder.h
//  EZOnlineScorerRecorder
//
//  Created by Johnny on 27/03/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EZOnlineScorerRecorderPayload.h"


typedef NS_ENUM(NSUInteger, EZOnlineScorerRecorderError) {
    EZOnlineScorerRecorderErrorRecorderError,
    EZOnlineScorerRecorderErrorConnectionError,
    EZOnlineScorerRecorderErrorResponseJSONError,
    EZOnlineScorerRecorderErrorInvalidParameter,
};


@class EZOnlineScorerRecorder;

@protocol EZOnlineScorerRecorderDelegate <NSObject>

@optional
- (void)onlineScorerDidBeginReading:(EZOnlineScorerRecorder * _Nonnull)reader;
//this method is always called on main thread
- (void)onlineScorer:(EZOnlineScorerRecorder * _Nonnull)reader didVolumnChange:(float)volumn;
- (void)onlineScorerDidStop:(EZOnlineScorerRecorder * _Nonnull)reader;
- (void)onlineScorer:(EZOnlineScorerRecorder * _Nonnull)audioSocket didGenerateReport:(NSDictionary *_Nonnull)report;
- (void)onlineScorer:(EZOnlineScorerRecorder * _Nonnull)reader didFailWithError:(NSError * _Nonnull)error;

@end

@interface EZOnlineScorerRecorder : NSObject

@property (nonnull, readonly, nonatomic) NSURL *socketURL;
@property (nonnull, readonly, nonatomic, copy) NSDictionary *payload;
@property (readonly) BOOL useSpeex;

@property (nullable, nonatomic, weak) id<EZOnlineScorerRecorderDelegate> delegate;

@property (nonnull, readonly, nonatomic) NSURL *recordURL;
@property (readonly, getter=isRecording) BOOL recording;
@property (readonly, getter=isProcessing) BOOL processing;

//only first call to this method has effect.
+ (void)configureAppID:(NSString * _Nonnull)appID secret:(NSString * _Nonnull)secret;
+ (void)setSocketURL:(NSURL * _Nonnull)socketURL;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability"
- (instancetype _Nullable) init NS_UNAVAILABLE;
#pragma clang diagnostic pop

//EZOnlineScorerRecorder will not init if appID or secret not set.
- (instancetype _Nullable)initWithPayload:(id<EZOnlineScorerRecorderPayload> _Nonnull)payload
                                 useSpeex:(BOOL)useSpeex;

//same as -initWithPayload:useSpeex: but use speex by default
- (instancetype _Nullable)initWithPayload:(id<EZOnlineScorerRecorderPayload> _Nonnull)payload;

/**
 record to given location. must set AVAudioSession to currect category (Record or PlayAndRecord)
 and activate AVAudioSession before call this function. Note that you need to request record 
 permission before setup AVAudioSession.

 @param fileURL Destination record URL. Record file format is aac.
 */
- (void)recordToURL:(NSURL * _Nonnull)fileURL;

/**
 record file to a temporary location. 
 @see recordToURL:
 */
- (void)record;

//finish recording and wait for response
- (void)stopRecording;

//close connection and disposal all resource. Will stop recording if is recording.
- (void)stopScoring;

@end
