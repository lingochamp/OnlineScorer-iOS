//
//  EZLogger.m
//  EZOnlineScorer
//
//  Created by Johnny on 26/07/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import "EZLogger.h"
#import "NSString+FilePath.h"

static EZLogDestination _logDestination = EZLogDestinationNone;

@implementation EZLogger

+ (dispatch_queue_t)logQueue
{
    static dispatch_queue_t _logDispatchQueue;
    if (!_logDispatchQueue) {
        _logDispatchQueue = dispatch_queue_create("com.liulishuo.EZLogger", DISPATCH_QUEUE_SERIAL);
    }
    return _logDispatchQueue;
}

+ (void)configLogDestination:(EZLogDestination)logDestination
{
    _logDestination = logDestination;
}

+ (NSURL *)logDestinationURL
{
    static NSURL *_logDestinationURL;
    if (!_logDestinationURL) {
        //only check once
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.liulishuo.EZLogger"];
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

+ (void)generateCombinedLog:(void (^__nonnull) (NSError *_Nullable error, NSURL *_Nullable logURL))completion
{
    dispatch_async([self logQueue], ^{
        NSURL *combinedLogURL = [[self logDestinationURL] URLByAppendingPathComponent:@"ezlogger.log"];
        [[NSFileManager defaultManager] removeItemAtURL:combinedLogURL error:NULL];
        NSError *error;
        NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self logDestinationURL] includingPropertiesForKeys:nil options:0 error:&error];
        if (error) {
            NSLog(@"enumerate log files failed: %@", error);
            completion(error, nil);
            return;
        }
        //sort by date
        files = [files sortedArrayUsingComparator:^NSComparisonResult(NSURL *_Nonnull obj1, NSURL *_Nonnull obj2) {
            return [obj1.path compare:obj2.path];
        }];
        
        [[NSFileManager defaultManager] createFileAtPath:combinedLogURL.path contents:nil attributes:nil];
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingToURL:combinedLogURL error:&error];
        if (error) {
            NSLog(@"create log handle failed: %@", error);
            completion(error, nil);
            return;
        }
        for (NSURL *file in files) {
            if ([file isEqual:[self currentLogFileURL]] || [file isEqual:combinedLogURL]) {
                continue;
            }
            [handle writeData:[NSData dataWithContentsOfURL:file]];
            [[NSFileManager defaultManager] removeItemAtURL:file error:NULL];
        }
        [handle closeFile];
        completion(nil, combinedLogURL);
    });
}

@end

void EZLog(NSString * _Nonnull format, ...) {
    va_list args;
    if (_logDestination & EZLogDestinationFile) {
        va_start(args, format);
        NSString *logString = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        logString = [NSString stringWithFormat:@"%@ %@", [NSDate date], logString];
        dispatch_async([EZLogger logQueue], ^{
            [[EZLogger logFileHandle] writeData:[logString dataUsingEncoding:NSUTF8StringEncoding]];
        });
    }
    if (_logDestination & EZLogDestinationConsole) {
        va_start(args, format);
        NSLogv(format, args);
        va_end(args);
    }
}
