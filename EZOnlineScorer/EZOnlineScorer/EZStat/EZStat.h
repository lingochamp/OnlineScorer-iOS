//
//  EZStat.h
//  EZOnlineScorer
//
//  Created by Johnny on 27/07/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol EZStatPoint <NSObject>

- (NSDictionary * _Nullable)generateStatData;

@end

@interface EZStat : NSObject

+ (void)saveStatPoint:(id<EZStatPoint> _Nonnull)statPoint;
+ (void)triggerStatUpload;

@end
