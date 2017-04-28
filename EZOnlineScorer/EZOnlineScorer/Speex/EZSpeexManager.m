//
//  SpeexMananger.m
//  OpenSpeech
//
//  Created by 邱峰 on 4/14/15.
//  Copyright © 2016 LLS iOS Team. All rights reserved.
//

#import "EZSpeexManager.h"
#import "voice.h"

@interface EZSpeexManager()

@property (nonatomic, strong) NSMutableData *bufferData;

@end

const int frameSize = 320;

@implementation EZSpeexManager
{
  short input_frame[frameSize];
  char cbits[frameSize * 2];
}

- (instancetype)init
{
    if (self = [super init]) {
        voice_encode_init();
    }
    return self;
}

- (NSMutableData *)bufferData
{
    if (_bufferData == nil) {
        _bufferData = [NSMutableData data];
    }
    return _bufferData;
}


- (void)appendPcmData:(NSData *)data
{
    [self.bufferData appendData:data];
}

- (NSData *)getEncodeData:(BOOL)isEnd
{
    NSMutableData *decodedData = [NSMutableData data];
    
    //self.bufferData
    
    while (true) {
        NSInteger length = self.bufferData.length;
        if (length == 0){
            break;
        }
        if (length < frameSize * 2) {       //每次压缩640byte。。。大坑。。
            if (isEnd) {
                NSData *data = self.bufferData;
                self.bufferData = nil;
                data = [self encode:(Byte *)[data bytes] length:(int)data.length];
                [decodedData appendData:data];
            }
            break;
        }
        else {
            NSData *data = [self.bufferData subdataWithRange:NSMakeRange(0,  frameSize * 2)];
            self.bufferData = [[self.bufferData subdataWithRange:NSMakeRange(frameSize * 2, self.bufferData.length - frameSize * 2)] mutableCopy];
            data = [self encode:(Byte *)[data bytes] length:(int)data.length];
            [decodedData appendData:data];
        }
    }
    return decodedData;
}

- (NSData *)encode:(Byte *)pcmBuffer length:(int)lengthOfByte
{
    for (int i = 0; i < lengthOfByte; i += 2) {
        uint u1 = (uint)pcmBuffer[i] & 0xFF;
        uint u2 =  (uint)pcmBuffer[i + 1] & 0xFF;
        input_frame[i / 2] = (short) (u1 | (u2 << 8));
    }
    int nbBytes = voice_encode(input_frame, lengthOfByte / 2, cbits, frameSize * 2);
    return [NSData dataWithBytes:cbits length:nbBytes];
}

@end
