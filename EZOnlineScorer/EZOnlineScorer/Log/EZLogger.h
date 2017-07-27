//
//  EZLogger.h
//  EZOnlineScorer
//
//  Created by Johnny on 26/07/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, EZLogDestination) {
  EZLogDestinationNone = 0,
  EZLogDestinationConsole = 1 << 0,
  EZLogDestinationFile = 1 << 1,
};

void EZLog(NSString * _Nonnull format, ...) NS_FORMAT_FUNCTION(1,2) NS_NO_TAIL_CALL;

@interface EZLogger : NSObject

+ (void)configLogDestination:(EZLogDestination)logDestination;
+ (void)generateCombinedLog:(void (^__nonnull) (NSError *_Nullable error, NSURL *_Nullable logURL))completion;

@end
