//
//  EZRecordPoint.h
//  EZOnlineScorer
//
//  Created by Johnny on 28/07/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EZStat.h"

@interface EZRecordPoint : NSObject<EZStatPoint>

- (instancetype _Nonnull)initWithAudioId:(NSString * _Nonnull)audioId item:(NSString * _Nonnull)item isRepest:(BOOL)isRepeat;
- (void)setStartRecordTime:(NSDate * _Nonnull)startRecordTime;
- (void)setEndRecordTime:(NSDate * _Nonnull)endRecordTime;
- (void)setResponseTime:(NSDate * _Nonnull)responseTime;
- (void)setError:(NSError * _Nullable)error;

@end
