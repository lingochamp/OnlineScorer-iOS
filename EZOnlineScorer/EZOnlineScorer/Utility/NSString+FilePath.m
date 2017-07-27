//
//  NSString+FilePath.m
//  EZDeliteScorer
//
//  Created by Johnny on 23/06/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

#import "NSString+FilePath.h"

@implementation NSString (FilePath)

- (NSString *)directoryPathWithExistenceCheck
{
    BOOL isDirectory;
    NSError *error = nil;
    BOOL fileExist = [[NSFileManager defaultManager] fileExistsAtPath:self isDirectory:&isDirectory];
    if (fileExist && !isDirectory) {
        if (![[NSFileManager defaultManager] removeItemAtPath:self error:&error]) {
#if DEBUG
            NSLog(@"remove non-directory file failed. === error: %@", error.debugDescription);
#endif
        }
        fileExist = NO;
    }
    if (!fileExist) {
#if DEBUG
        NSLog(@"Directory does not exist at dirPath %@", self);
#endif
        if (![[NSFileManager defaultManager] createDirectoryAtPath:self withIntermediateDirectories:YES attributes:nil error:&error]) {
#if DEBUG
            NSLog(@"=== error: %@", error.debugDescription);
#endif
        }
    }
    
    return self;
}

@end
