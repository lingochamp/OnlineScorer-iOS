//
//  ReadAloudPayload.h
//  EZOnlineScorerRecorder
//
//  Created by Johnny on 05/04/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EZOnlineScorerRecorderPayload.h"

@interface EZReadAloudPayload : NSObject<EZOnlineScorerRecorderPayload>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability"
- (instancetype _Nullable) init NS_UNAVAILABLE;
#pragma clang diagnostic pop

- (instancetype _Nonnull)initWithReferenceText:(NSString * _Nonnull)referenceText;

@end
