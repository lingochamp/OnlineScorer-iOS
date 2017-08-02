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
 in userInfo for detail, the underlying error is a EZAudioReaderError.
 - EZOnlineScorerRecorderErrorConnectionError: EZOnlineScorerRecorder fail to communicate with server. See
 NSUnderlyingErrorKey in userInfo for detail, the underlying error is a EZAudioSocketError.
 - EZOnlineScorerRecorderErrorResponseJSONError: EZOnlineScorerRecorder fail to decode response. Please
 contact developer if this error occored.
 - EZOnlineScorerRecorderErrorInvalidParameter: EZOnlineScorerRecorder input parameters invalid. Please make
 sure you're using a valid EZOnlineScorerRecorderPayload and create a new EZOnlineScorerRecorder.
 */
typedef NS_ENUM(NSUInteger, EZOnlineScorerRecorderError) {
    EZOnlineScorerRecorderErrorRecorderError,
    EZOnlineScorerRecorderErrorConnectionError,
    EZOnlineScorerRecorderErrorResponseJSONError,
    EZOnlineScorerRecorderErrorInvalidParameter,
};

extern NSString * _Nullable const kEZOnlineScorerRecorderErrorDomain;

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
 
 通知 delegate EZOnlineScorerRecorder 出现了错误，录音或打分过程有可能失败了。查看 EZOnlineScorerRecorderError 获取
 更多信息。

 @param scorer A EZOnlineScorerRecorder object informing the delegate about error.
 
 @param error An NSError object. See EZOnlineScorerRecorderError for detial error code info.
 */
- (void)onlineScorer:(EZOnlineScorerRecorder * _Nonnull)scorer didFailWithError:(NSError * _Nonnull)error;

@end


/**
 Main class for EZOnlineScorer. EZOnlineScorerRecorder use hardware accelerate to convert record PCM data to
 output m4a file. Using multiple EZOnlineScorerRecorder at once is DISALLOWED. It may cause serious memory 
 issue and could crash your app.
 
 EZOnlineScorer 的主类。EZOnlineScorerRecorder 使用硬件音频编码机制，因此不允许同时使用多个 EZOnlineScorerRecorder。
 */
@interface EZOnlineScorerRecorder : NSObject

/**
 EZOnlineScorerRecorder's socketURL for online scoring. To change socketURL, use class method +setSocketURL:. 
 Readonly.
 
 EZOnlineScorerRecorder 的在线打分服务器地址。想要修改 socketURL 需要调用类方法 +setSocketURL:，设置会在新初始化的 
 EZOnlineScorerRecorder 中生效。只读。
 */
@property (nonnull, readonly, nonatomic) NSURL *socketURL;

/**
 EZOnlineScorerRecorderPayload object that used to initiate EZOnlineScorerRecorder. Readonly
 
 初始化时使用的 EZOnlineScorerRecorderPayload 对象。只读。
 */
@property (nonnull, readonly, nonatomic) id<EZOnlineScorerRecorderPayload> payload;

/**
 Indicate EZOnlineScorerRecorder use speex to compress audio data for not. Readonly.
 
 EZOnlineScorerRecorder 是否使用 speex 压缩音频数据。只读。
 */
@property (readonly) BOOL useSpeex;

@property (nullable, nonatomic, weak) id<EZOnlineScorerRecorderDelegate> delegate;

/**
 Record location of EZOnlineScorerRecorder. Readonly.
 
 EZOnlineScorerRecorder 的录音位置。只读。
 */
@property (nonnull, readonly, nonatomic) NSURL *recordURL;

/**
 Indicate whether EZOnlineScorerRecorder is recording. Readonly.
 
 EZOnlineScorerRecorder 是否正在和服务器通信。只读。
 */
@property (readonly, getter=isRecording) BOOL recording;

/**
 Indicate whether EZOnlineScorerRecorder is communicating with server. Readonly.
 
 EZOnlineScorerRecorder 是否正在和服务器通信。只读。
 */
@property (readonly, getter=isProcessing) BOOL processing;

/**
 configure AppID and secret. Note that only first call to this method has effect.

 @param appID OnlineScorer appID
 @param secret OnlineScorer secret
 */
+ (void)configureAppID:(NSString * _Nonnull)appID secret:(NSString * _Nonnull)secret;
+ (void)setSocketURL:(NSURL * _Nonnull)socketURL;

/**
 Enable debug mode will print scorer log to console & temp log file.

 @param enabled enable log file or not.
 */
+ (void)setDebugMode:(BOOL)enabled;

/**
 Export debug log file. You can provide log file to SDK developer for help.

 @param completion Scorer will call completion on background thread when error occoured or log file generated.
 */
+ (void)exportDebugLog:(void (^__nonnull) (NSError *_Nullable error, NSURL *_Nullable logURL))completion;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability"
- (instancetype _Nullable) init NS_UNAVAILABLE;
#pragma clang diagnostic pop


/**
 Designed initializer of EZOnlineScorerRecorder.
 
 Note: Use multiple EZOnlineScorerRecorder at once is DISALLOWED. It may cause serious memory issue
 and could crash your app.
 
 注意：严禁同时使用多个 EZOnlineScorerRecorder。这会导致严重的内存泄露问题并有可能使 App 崩溃。
 
 @param payload An object confirm to EZOnlineScorerRecorderPayload protocol, which provide scorer catrgory info. 符合 EZOnlineScorerRecorderPayload 协议的对象，提供打分需要的元信息。
 @param useSpeex Indicate whether use speex to compress audio data. 是否使用 speex 进行音频传输压缩。建议设置为 YES.
 @return An EZOnlineScorerRecorder object. EZOnlineScorerRecorder will not init if appID or secret is not set. EZOnlineScorerRecorder 对象。当 appID 或 secret 没有设置的情况下会返回 nil.
 */
- (instancetype _Nullable)initWithPayload:(id<EZOnlineScorerRecorderPayload> _Nonnull)payload
                                 useSpeex:(BOOL)useSpeex;

/**
 Convenience initializer of EZOnlineScorerRecorder. Same as -initWithPayload:useSpeex: but use speex by default.

 EZOnlineScorerRecorder 的 Convenience initializer。和 -initWithPayload:useSpeex: 相同但默认使用 speex。
 
 @param payload An object confirm to EZOnlineScorerRecorderPayload protocol, which provide scorer catrgory info. 符合 EZOnlineScorerRecorderPayload 协议的对象，提供打分需要的元信息。
 @return An EZOnlineScorerRecorder object. EZOnlineScorerRecorder will not init if appID or secret is not set. EZOnlineScorerRecorder 对象。当 appID 或 secret 没有设置的情况下会返回 nil.
 */
- (instancetype _Nullable)initWithPayload:(id<EZOnlineScorerRecorderPayload> _Nonnull)payload;

/**
 Record to given location. Must set AVAudioSession to currect category (Record or PlayAndRecord)
 and activate AVAudioSession before call this function. 
 
 Note: You need to request permission before setup AVAudioSession.
 
 Note: EZOnlineScorerRecorder are intended for one-time-use only. -recordToURL: should be called once and only once.
 
 录音到指定文件并进行在线打分。录音前必须正确设置 AVAudioSession 的 category (Record 或 PlayAndRecord)，并在录音前激活
 AVAudioSession。
 
 注意：设置 AVAudioSession 前你需要自行申请录音权限。
 
 注意：EZOnlineScorerRecorder 是为一次性使用设计的。-recordToURL: 方法只应被调用一次（之后的调用会静默失败）。

 @param fileURL Destination record URL. Record file format is m4a. 录音文件保存位置。录音格式是 m4a.
 */
- (void)recordToURL:(NSURL * _Nonnull)fileURL;

/**
 Record file to a temporary location. Old temporary record file will be overwrited.
 
 录音到临时文件并进行在线打分。会覆盖上一次的临时录音文件。
 
 @see -recordToURL:
 */
- (void)record;

/**
 Finish recording and wait for response
 
 结束录音并等待服务器返回打分结果。
 */
- (void)stopRecording;

/**
 Close connection and dispose all resource. Will stop recording if is recording. Call -stopScoring will mark
 EZOnlineScorerRecorder disposal, and any following method call will fail silently.
 
 关闭打分连接并清理所有的资源。如果当前正在录音，录音也会终止。调用 -stopScoring 后 EZOnlineScorerRecorder 会标记为废弃状态
 之后所有的方法调用都会静默失败。
 */
- (void)stopScoring;

/**
 In case of record success but online scoring failed, call this method and EZOnlineScorerRecorder 
 will resend audio to server for scoring. Calling this method will dispose current scoring connection(if any).
 You should decide whether to retry according to error message you received.
 
 当录音成功但在线打分失败时，调用该方法 EZOnlineScorerRecorder 会重发音频数据到服务器进行打分。如果当前有未完成的打分操作，
 调用 -retry 会取消目前的打分连接。通常在 delegate 收到 -onlineScorer:didFailWithError: 调用后，开发者根据 error 信息
 自行决定是否需要重试
 */
- (void)retry;

@end
