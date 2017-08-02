//
//  EZRecordPoint.m
//  EZOnlineScorer
//
//  Created by Johnny on 28/07/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import "EZRecordPoint.h"
#import "EZAudioSocket.h"
#import "EZOnlineScorerRecorder.h"
#import "EZAudioReader.h"
#import "EZSRWebSocket.h"
@import SystemConfiguration;
@import Darwin;

typedef enum {
    ConnectionTypeUnknown,
    ConnectionTypeNone,
    ConnectionType3G,
    ConnectionTypeWiFi
} ConnectionType;

@interface EZRecordPoint ()

@property (nonatomic, assign) ConnectionType connectionType;
@property (nonatomic, nonnull, strong) NSString *audioId;
@property (nonatomic, nonnull, strong) NSString *item;
@property (nonatomic, assign) BOOL isRepeat;
@property (nonatomic, nullable, strong) NSDate *startRecordTime;
@property (nonatomic, nullable, strong) NSDate *endRecordTime;
@property (nonatomic, nullable, strong) NSDate *responseTime;
@property (nonatomic, nullable, strong) NSError *error;

@end

@implementation EZRecordPoint

- (instancetype)initWithAudioId:(NSString *)audioId item:(NSString *)item isRepest:(BOOL)isRepeat
{
    self = [super init];
    if (self) {
        _audioId = audioId;
        _item = item;
        _isRepeat = isRepeat;
        _connectionType = [EZRecordPoint connectionType];
    }
    return self;
}

+ (ConnectionType)connectionType
{
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;

    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;
    BOOL success = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    if (!success) {
        return ConnectionTypeUnknown;
    }
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL isNetworkReachable = (isReachable && !needsConnection);
    
    if (!isNetworkReachable) {
        return ConnectionTypeNone;
    } else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        return ConnectionType3G;
    } else {
        return ConnectionTypeWiFi;
    }
}

- (NSDictionary *)generateStatData
{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithCapacity:7];
    data[@"audioId"] = self.audioId;
    data[@"network"] = self.connectionType == ConnectionTypeWiFi ? @"WLAN" : @"CELLULAR";
    data[@"item"] = self.item;
    data[@"recordStartTime"] = @((long)[self.startRecordTime timeIntervalSince1970]);
    data[@"recordEndTime"] = @((long)[self.endRecordTime timeIntervalSince1970]);
    data[@"responseTime"] = @((long)[self.responseTime timeIntervalSince1970]);
    
    //error code
    NSError *underlyingError = self.error.userInfo[NSUnderlyingErrorKey];
    if ([underlyingError.domain isEqualToString:SRWebSocketErrorDomain]) {
        if (self.error.code == 2132) { //HTTP error
            data[@"error"] = [NSString stringWithFormat:@"http:%@", self.error.userInfo[SRHTTPResponseErrorKey]];
        } else {
            data[@"error"] = [NSString stringWithFormat:@"websocket:%zd", self.error.code];
        }
    } else if (self.error != nil) {
        data[@"error"] = [NSString stringWithFormat:@"lingo:%@", self.error];
    }
    
    return @{@"type": self.isRepeat ? @"retryRecord" : @"onlineRecord",
             @"data": data};
}

@end
