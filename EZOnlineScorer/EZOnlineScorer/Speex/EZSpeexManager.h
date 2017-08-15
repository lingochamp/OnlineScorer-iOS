//
//  EZSpeexManager.h
//  EZDeliteScorer
//
//  Created by Johnny on 28/06/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EZSpeexManager : NSObject

- (instancetype _Nonnull)initWithQuality:(int)quality;
- (NSData * _Nonnull)appendPcmData:(NSData * _Nonnull)data isEnd:(BOOL)isEnd;

@end
