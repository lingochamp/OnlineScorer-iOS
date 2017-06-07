//
//  EZASRPayload.m
//  EZOnlineScorer
//
//  Created by Johnny on 07/06/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import "EZASRPayload.h"

@implementation EZASRPayload

- (NSDictionary * _Nonnull)jsonPayload
{
  NSMutableDictionary *payload = [@{@"type": @"asr"} mutableCopy];
  if (self.domain) {
    payload[@"domain"] = self.domain;
  }
  return [payload copy];
}

@end
