//
//  SemiOpenPayload.m
//  EZOnlineScorerRecorder
//
//  Created by Johnny on 05/04/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import "EZSemiOpenPayload.h"

@interface EZSemiOpenPayload ()

@property (nonnull, nonatomic, copy) NSArray<NSString *> *referenceAnswers;
@property (nonatomic, assign) EZSemiOpenPayloadQuestionType questionType;
@property (nonatomic, assign) EZSemiOpenPayloadTargetAudience targetAudience;

@end

@implementation EZSemiOpenPayload

- (instancetype _Nonnull)initWithReferenceAnswers:(NSArray<NSString *> * _Nonnull)referenceAnswers
                                     questionType:(EZSemiOpenPayloadQuestionType)questionType
                                   targetAudience:(EZSemiOpenPayloadTargetAudience)targetAudience
{
    self = [super init];
    if (self) {
        _referenceAnswers = [referenceAnswers copy];
        _questionType = questionType;
        _targetAudience = targetAudience;
    }
    return self;
}

- (NSDictionary * _Nonnull)jsonPayload
{
    
    return @{@"type": @"semiopen",
             @"refAnswers": [self.referenceAnswers componentsJoinedByString:@" | "],
             @"questionType": [NSString stringWithFormat:@"%zd", self.questionType],
             @"targetAudience": [NSString stringWithFormat:@"%zd", self.targetAudience]};
}


@end
