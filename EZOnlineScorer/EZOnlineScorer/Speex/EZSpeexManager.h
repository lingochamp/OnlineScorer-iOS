//
//  SpeexMananger.h
//  OpenSpeech
//
//  Created by 邱峰 on 4/14/15.
//  Copyright © 2016 LLS iOS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EZSpeexManager : NSObject


- (void)appendPcmData:(NSData *)data;

- (NSData *)getEncodeData:(BOOL)isEnd;

@end
