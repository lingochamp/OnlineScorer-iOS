//
//  EZOnlineScorerRecorder.h
//  EZOnlineScorerRecorder
//
//  Created by Johnny on 27/03/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EZOnlineScorerRecorderPayload.h"



/**
 EZOnlineScorerRecorder error type

 - EZOnlineScorerRecorderErrorRecorderError: EZOnlineScorerRecorder fail to record. See NSUnderlyingErrorKey 
 in userInfo for detail.
 - EZOnlineScorerRecorderErrorConnectionError: EZOnlineScorerRecorder fail to communicate with server. 
 See NSUnderlyingErrorKey in userInfo for detail, the underlying error is a EZAudioReaderError.
 - EZOnlineScorerRecorderErrorResponseJSONError: EZOnlineScorerRecorder fail to decode response. 
 Please contact developer if this error occored, the underlying error is a EZAudioSocketError.
 - EZOnlineScorerRecorderErrorInvalidParameter: EZOnlineScorerRecorder input parameters invalid. 
 Please make sure you're using a valid EZOnlineScorerRecorderPayload.
 */
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

/**
 Tell the delegate that the record did begin.

 @param scorer A EZOnlineScorerRecorder object informing the delegate about status change.
 */
- (void)onlineScorerDidBeginRecording:(EZOnlineScorerRecorder * _Nonnull)scorer;

/**
 Tell the delegate that the record volumn did change. -onlineScorer:didVolumnChange: is always called on 
 main thread.

 @param scorer A EZOnlineScorerRecorder object informing the delegate about status change.
 @param volumn A float value calculated form microphone db level, varying from 0 to 1,
 usually used to show recording animation.
 */
- (void)onlineScorer:(EZOnlineScorerRecorder * _Nonnull)scorer didVolumnChange:(float)volumn;

/**
 Tell the delegate that the record did finish.
 
 Note that record finish has no relevance to scoring process. Scoring process may finished earlier because of
 network/authenticate failure, or still communicating with server.

 @param scorer A EZOnlineScorerRecorder object informing the delegate about status change.
 */
- (void)onlineScorerDidFinishRecording:(EZOnlineScorerRecorder * _Nonnull)scorer;


/**
 Tell the delegate that the score report did generate.

 @param scorer A EZOnlineScorerRecorder object informing the delegate about status change.
 @param report A dictionary object containing score report.
 */
- (void)onlineScorer:(EZOnlineScorerRecorder * _Nonnull)scorer didGenerateReport:(NSDictionary *_Nonnull)report;


/**
 Tell the delegate that the EZOnlineScorerRecorder did encounter some error, and record/score may fail.

 @param scorer A EZOnlineScorerRecorder object informing the delegate about error.
 @param error An NSError object. See EZOnlineScorerRecorderError for detial error code info.
 */
- (void)onlineScorer:(EZOnlineScorerRecorder * _Nonnull)scorer didFailWithError:(NSError * _Nonnull)error;

@end


/**
 Main class for EZOnlineScorer. EZOnlineScorer use hardware accelerate to convert record PCM data to output
 m4a file. Using multiple EZOnlineScorerRecorder at once is DISALLOWED. It may cause serious memory issue
 and could crash your app.
 */
@interface EZOnlineScorerRecorder : NSObject

/**
 EZOnlineScorerRecorder's socketURL for online scoring. To change socketURL, use class method +setSocketURL:. 
 Readonly.
 */
@property (nonnull, readonly, nonatomic) NSURL *socketURL;

/**
 EZOnlineScorerRecorderPayload object that used to initiate EZOnlineScorerRecorder. Readonly
 */
@property (nonnull, readonly, nonatomic) id<EZOnlineScorerRecorderPayload> payload;

/**
 Indicate EZOnlineScorerRecorder use speex to compress audio data for not. Readonly.
 */
@property (readonly) BOOL useSpeex;

@property (nullable, nonatomic, weak) id<EZOnlineScorerRecorderDelegate> delegate;

/**
 EZOnlineScorerRecorder record URL. If
 */
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
