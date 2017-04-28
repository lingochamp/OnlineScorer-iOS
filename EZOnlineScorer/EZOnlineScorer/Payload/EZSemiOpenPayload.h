//
//  SemiOpenPayload.h
//  EZOnlineScorerRecorder
//
//  Created by Johnny on 05/04/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EZOnlineScorerRecorderPayload.h"

typedef NS_ENUM(NSUInteger, EZSemiOpenPayloadQuestionType) {
    EZSemiOpenPayloadQuestionTypeReadParagraph,
    EZSemiOpenPayloadQuestionTypeQuestionAndAnswers,
    EZSemiOpenPayloadQuestionTypeStoryRetell,
    EZSemiOpenPayloadQuestionTypePictureTalk,
    EZSemiOpenPayloadQuestionTypeOralEssay,
};

typedef NS_ENUM(NSUInteger, EZSemiOpenPayloadTargetAudience) {
    EZSemiOpenPayloadTargetAudienceElementarySchool,
    EZSemiOpenPayloadTargetAudienceMiddleSchool,
    EZSemiOpenPayloadTargetAudienceHighSchool,
    EZSemiOpenPayloadTargetAudienceCollege,
};


/**
 EZSemiOpenPayload is not supported by server side currently.
 */
@interface EZSemiOpenPayload : NSObject<EZOnlineScorerRecorderPayload>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability"
- (instancetype _Nullable) init NS_UNAVAILABLE;
#pragma clang diagnostic pop

- (instancetype _Nonnull)initWithReferenceAnswers:(NSArray<NSString *> * _Nonnull)referenceAnswers
                                     questionType:(EZSemiOpenPayloadQuestionType)questionType
                                   targetAudience:(EZSemiOpenPayloadTargetAudience)targetAudience;

@end
