//
//  EZASRPayload.h
//  EZOnlineScorer
//
//  Created by Johnny on 07/06/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EZOnlineScorerRecorderPayload.h"

@interface EZASRPayload : NSObject<EZOnlineScorerRecorderPayload>

@property (nullable, nonatomic, copy) NSString *domain;

@end
