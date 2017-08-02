//
//  EZOnlineScorerRecorderPayload.h
//  EZOnlineScorerRecorder
//
//  Created by Johnny on 05/04/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#ifndef EZOnlineScorerRecorderPayload_h
#define EZOnlineScorerRecorderPayload_h

@protocol EZOnlineScorerRecorderPayload <NSObject>

- (NSDictionary * _Nonnull)jsonPayload;
- (NSString * _Nonnull)type;

@end

#endif /* EZOnlineScorerRecorderPayload_h */
