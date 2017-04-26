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

/**
 EZOnlineScorerRecorder delegate protocol. All method are optional. 
 
 Note that only -onlineScorer:didVolumnChange: promise to be called on main thread.
 */
@protocol EZOnlineScorerRecorderDelegate <NSObject>

@optional
- (void)onlineScorerDidBeginReading:(EZOnlineScorerRecorder * _Nonnull)reader;

/**
 -onlineScorer:didVolumnChange: is always called on main thread.

 @param reader The method caller EZOnlineScorerRecorder object
 @param volumn A float value calculated form microphone db level, varying from 0 to 1,
 usually used to show recording animation.
 */
- (void)onlineScorer:(EZOnlineScorerRecorder * _Nonnull)reader didVolumnChange:(float)volumn;
- (void)onlineScorerDidStop:(EZOnlineScorerRecorder * _Nonnull)reader;
- (void)onlineScorer:(EZOnlineScorerRecorder * _Nonnull)audioSocket didGenerateReport:(NSDictionary *_Nonnull)report;
- (void)onlineScorer:(EZOnlineScorerRecorder * _Nonnull)reader didFailWithError:(NSError * _Nonnull)error;

@end


/**
 Main class for EZOnlineScorer.
 Use multiple EZOnlineScorerRecorder at once is DISALLOWED. It may cause serious memory issue
 and could crash your app.
 */
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


/**
 Designed initializer of EZOnlineScorerRecorder.
 
 Note: Use multiple EZOnlineScorerRecorder at once is DISALLOWED. It may cause serious memory issue
 and could crash your app.
 
 @param payload An object confirm to EZOnlineScorerRecorderPayload protocol, which provide scorer catrgory info.
 @param useSpeex Indicate whether use speex to compress audio data
 @return An EZOnlineScorerRecorder object. EZOnlineScorerRecorder will not init if appID or secret is not set.
 */
- (instancetype _Nullable)initWithPayload:(id<EZOnlineScorerRecorderPayload> _Nonnull)payload
                                 useSpeex:(BOOL)useSpeex;

/**
 Convenience initializer of EZOnlineScorerRecorder. Same as -initWithPayload:useSpeex: but use speex by default.

 @param payload An object confirm to EZOnlineScorerRecorderPayload protocol, which provide scorer catrgory info.
 @return An EZOnlineScorerRecorder object. EZOnlineScorerRecorder will not init if appID or secret is not set.
 */
- (instancetype _Nullable)initWithPayload:(id<EZOnlineScorerRecorderPayload> _Nonnull)payload;

/**
 Record to given location. must set AVAudioSession to currect category (Record or PlayAndRecord)
 and activate AVAudioSession before call this function. 
 
 Note: that you need to request permission before setup AVAudioSession.
 
 Note: EZOnlineScorerRecorder are intended for one-time-use only. -recordToURL: should be called once and only once.

 @param fileURL Destination record URL. Record file format is aac.
 */
- (void)recordToURL:(NSURL * _Nonnull)fileURL;

/**
 Record file to a temporary location.
 
 @see -recordToURL:
 */
- (void)record;

/**
 Finish recording and wait for response
 */
- (void)stopRecording;

/**
 Close connection and disposal all resource. Will stop recording if is recording. Call -stopScoring will mark
 EZOnlineScorerRecorder disposal, and any following method call will fail silently.
 */
- (void)stopScoring;

/**
 In case of record success but online scoring failed, call this method and EZOnlineScorerRecorder 
 will resend audio to server for scoring. Calling this method will dispose current scoring connection(if any).
 You should decide whether to retry according to error message you received.
 */
- (void)retry;

@end
