//
//  EZSpeexManager.h
//  EZDeliteScorer
//
//  Created by Johnny on 28/06/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class EZSpeexManager;

@protocol EZSpeexManagerDelegate <NSObject>

- (void)speexManager:(EZSpeexManager * _Nonnull)speexManager didGenerateSpeexData:(NSData * _Nonnull)data;

@end

@interface EZSpeexManager : NSObject

@property (nullable, nonatomic, weak) id<EZSpeexManagerDelegate> delegate;

- (instancetype _Nonnull)initWithQuality:(int)quality;
- (void)appendPcmData:(NSData * _Nonnull)data isEnd:(BOOL)isEnd;

@end
