//
//  EZAudioReader.h
//  EngzoAudioRecorderToolKitDemo
//
//  Created by yangyang on 7/30/14.
//  Copyright (c) 2014 liulishuo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class EZAudioReader;

typedef enum
{
  EZAudioReaderErrorFailedToEnableLevelMetering = 0,
  EZAudioReaderErrorFailedToAllocateAudioBuffer = 1,
  EZAudioReaderErrorFailedToEnqueueAudioBuffer = 2,
  EZAudioReaderErrorFailedToCreateAudioFile = 3,
  EZAudioReaderErrorFailedToOpenAudioReaderQueue = 4,
  EZAudioReaderErrorFailedToGetAudioLevel = 5,
  EZAudioReaderErrorFailedToStartUtterance = 6,
  EZAudioReaderErrorFailedToConvertAudio = 7
} EZAudioReaderError;

extern NSString * _Nullable const kEZAudioReaderErrorDomain;

@protocol EZAudioReaderDelegate <NSObject>
@optional
- (void)audioReader:(EZAudioReader * _Nonnull)reader didFailWithError:(NSError * _Nonnull)error;
- (void)audioReaderDidBeginReading:(EZAudioReader * _Nonnull)reader;
- (void)audioReader:(EZAudioReader * _Nonnull)reader didVolumnChange:(float)volumn;
- (void)audioReader:(EZAudioReader * _Nonnull)reader didReceiveAudioData:(NSData * _Nonnull)audioData;
- (void)engzoAudioRecorderDidStop:(EZAudioReader * _Nonnull)reader;
@end

@interface EZAudioReader : NSObject

@property (nonatomic, weak, nullable) id <EZAudioReaderDelegate> delegate;
@property (nonatomic, readonly) BOOL isRecording;
@property (nonatomic, readonly, assign) CGFloat currentPlayDuration;
@property (nonatomic) BOOL enableLimitDuration;

///EZAudioReader are intended for one-time-use only. -recordToFileURL: should be called once and only once.
- (void)recordToFileURL:(NSURL * _Nonnull)fileURL;
- (void)stop;

@end
