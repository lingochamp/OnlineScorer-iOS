//
//  EZStat.m
//  EZOnlineScorer
//
//  Created by Johnny on 27/07/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

@import UIKit;
#import "EZStat.h"
#import "NSString+FilePath.h"
#import "EZOnlineScorerRecorder+Internal.h"
#import "Constants.h"
#import "EZLogger.h"

@implementation EZStat

+ (void)saveStatPoint:(id<EZStatPoint> _Nonnull)statPoint
{
    if (!statPoint) return;
    
    dispatch_async([self logQueue], ^{
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[statPoint generateStatData] options:0 error:&error];
        if (error) {
            EZLog(@"saveStatPoint failed serialization json object: %@", error);
            return;
        }
        [[self logFileHandle] writeData:jsonData];
        //add array seperater
        [[self logFileHandle] writeData:[@"," dataUsingEncoding:NSUTF8StringEncoding]];
        [self triggerStatUpload];
    });
}

+ (void)triggerStatUpload
{
    dispatch_async([self logQueue], ^{
        NSError *error;
        NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self logDestinationURL] includingPropertiesForKeys:nil options:0 error:&error];
        if (error) {
            NSLog(@"enumerate log files failed: %@", error);
            return;
        }
        
        NSMutableArray *stats = [NSMutableArray new];
        for (NSURL *file in files) @autoreleasepool {
            if ([file isEqual:[self currentLogFileURL]]) continue;
            NSString *statString = [NSString stringWithContentsOfFile:file.path encoding:NSUTF8StringEncoding error:NULL];
            NSString *jsonString = [NSString stringWithFormat:@"[%@]", statString];
            NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
            NSArray *statsInFile = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
            [stats addObjectsFromArray:statsInFile];
        }
        //check data existance
        if (stats.count == 0) return;
        
        NSDictionary *requestDictionary = @{
                                            @"deviceId": [[[UIDevice currentDevice] identifierForVendor] UUIDString],
                                            @"appId": [EZOnlineScorerRecorder appID],
                                            @"os": [NSString stringWithFormat:@"iOS %@", [[NSProcessInfo processInfo] operatingSystemVersionString]],
                                            @"version": SDK_VERSION,
                                            @"stats": stats,
                                            };
        EZLog(@"upload stat info: %@", requestDictionary);
        
        //request
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://openapi.llsapp.com/stat"]];
        request.HTTPMethod = @"POST";
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:requestDictionary options:0 error:NULL];
        
        NSURLSessionTask *statTask = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            EZLog(@"upload stat response: %@, error: %@", response, error);
            if (!error) {
                dispatch_async([self logQueue], ^{
                    //remove stat file
                    for (NSURL *file in files) {
                        [[NSFileManager defaultManager] removeItemAtURL:file error:NULL];
                    }
                });
            }
        }];
        [statTask resume];
    });

}

+ (dispatch_queue_t)logQueue
{
    static dispatch_queue_t _logDispatchQueue;
    if (!_logDispatchQueue) {
        _logDispatchQueue = dispatch_queue_create("com.liulishuo.EZStat", DISPATCH_QUEUE_SERIAL);
    }
    return _logDispatchQueue;
}

+ (NSURL *)logDestinationURL
{
    static NSURL *_logDestinationURL;
    if (!_logDestinationURL) {
        //only check once
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.liulishuo.EZStat"];
        _logDestinationURL = [NSURL fileURLWithPath:[tempPath directoryPathWithExistenceCheck] isDirectory:YES];
    }
    return _logDestinationURL;
}

+ (NSURL *)currentLogFileURL
{
    static NSURL *_loggingFileURL;
    if (!_loggingFileURL) {
        NSString *logFileName = [NSString stringWithFormat:@"%zd.log", [[NSDate date] timeIntervalSince1970]];
        _loggingFileURL = [[self logDestinationURL] URLByAppendingPathComponent:logFileName isDirectory:NO];
    }
    return _loggingFileURL;
}

+ (NSFileHandle *)logFileHandle
{
    static NSFileHandle *_logFileHandle;
    if (!_logFileHandle) {
        [[NSFileManager defaultManager] createFileAtPath:[self currentLogFileURL].path contents:nil attributes:nil];
        NSError *error;
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingToURL:[self currentLogFileURL] error:&error];
        if (error) {
            NSLog(@"create log handle failed: %@", error);
        }
        _logFileHandle = handle;
    }
    return _logFileHandle;
}

@end
