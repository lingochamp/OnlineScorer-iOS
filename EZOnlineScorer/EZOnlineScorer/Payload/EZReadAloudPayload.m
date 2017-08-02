//
//  ReadAloudPayload.m
//  EZOnlineScorerRecorder
//
//  Created by Johnny on 05/04/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import "EZReadAloudPayload.h"

@interface EZReadAloudPayload ()

@property (nonnull, nonatomic, copy) NSString *referenceText;

@end

@implementation EZReadAloudPayload

- (instancetype _Nonnull)initWithReferenceText:(NSString * _Nonnull)referenceText
{
    self = [super init];
    if (self) {
        _referenceText = [referenceText copy];
    }
    return self;
}

- (NSDictionary * _Nonnull)jsonPayload
{
    return @{@"type": @"readaloud",
             @"reftext": self.referenceText};
}

- (NSString *)type
{
    return @"readaloud";
}

@end
