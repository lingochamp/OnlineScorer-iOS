//
//  EZSpeexManager.m
//  EZDeliteScorer
//
//  Created by Johnny on 28/06/2017.
//  Copyright © 2017 LLS. All rights reserved.
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
    SpeexPointer speex;
}

- (void)dealloc
{
    voice_encode_release(speex);
}

- (instancetype)initWithQuality:(int)quality
{
    if (self = [super init]) {
        speex = voice_encode_init(quality);
    }
    return self;
}

- (instancetype)init
{
    return [self initWithQuality:8];
}

- (NSMutableData *)bufferData
{
    if (_bufferData == nil) {
        _bufferData = [NSMutableData data];
    }
    return _bufferData;
}

- (NSData * _Nonnull)appendPcmData:(NSData *)data isEnd:(BOOL)isEnd
{
    [self.bufferData appendData:data];
    
    NSMutableData *encodedData = [NSMutableData data];
    
    while (true) {
      NSInteger length = self.bufferData.length;
      if (length == 0){
        break;
      }
      if (length < frameSize * 2) {       //每次压缩640byte
        if (isEnd) {
          NSData *data = self.bufferData;
          self.bufferData = nil;
          data = [self encode:(Byte *)[data bytes] length:(int)data.length];
          [encodedData appendData:data];
        }
        break;
      } else {
        NSData *data = [self.bufferData subdataWithRange:NSMakeRange(0,  frameSize * 2)];
        self.bufferData = [[self.bufferData subdataWithRange:NSMakeRange(frameSize * 2, self.bufferData.length - frameSize * 2)] mutableCopy];
        data = [self encode:(Byte *)[data bytes] length:(int)data.length];
        [encodedData appendData:data];
      }
    }
  
    return [encodedData copy];
}

- (NSData *)encode:(Byte *)pcmBuffer length:(int)lengthOfByte
{
    for (int i = 0; i < lengthOfByte; i += 2) {
        uint u1 = (uint)pcmBuffer[i] & 0xFF;
        uint u2 =  (uint)pcmBuffer[i + 1] & 0xFF;
        input_frame[i / 2] = (short) (u1 | (u2 << 8));
    }
    int nbBytes = voice_encode(speex, speex->enc_frame_size, input_frame, lengthOfByte / 2, cbits, frameSize * 2);
    return [NSData dataWithBytes:cbits length:nbBytes];
}

@end
