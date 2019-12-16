//
//  ZFAudioQueuePlayer.m
//  AudioQueueServices
//
//  Created by 钟凡 on 2019/11/20.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import "ZFAudioQueuePlayer.h"
#import <AVFoundation/AVFoundation.h>

static const int kNumberBuffers = 6;

@interface ZFAudioQueuePlayer()

@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) AudioStreamBasicDescription asbd;
@property (nonatomic) AudioQueueRef audioQueue;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) UInt32 bufferSize;
@property (nonatomic, assign) double sampleTime;
@property (nonatomic, assign) double sampleRate;
@property (nonatomic, assign) UInt32 fillIndex;
@property (nonatomic, assign) UInt32 playIndex;

@end


@implementation ZFAudioQueuePlayer
{
    AudioQueueBufferRef mBuffers[kNumberBuffers];
}
- (instancetype)init {
    if (self = [super init]) {
        _playIndex = 0;
        _fillIndex = 0;
        _queue = dispatch_queue_create("zf.audioPlayer", DISPATCH_QUEUE_SERIAL);
        [self setupAudioSession];
        [self setupAudioFormat];
        dispatch_async(_queue, ^{
            [self setupAudioQueue];
            [self setupAudioQueueBuffers];
        });
    }
    return self;
}
- (void)setupAudioFormat {
    UInt32 mChannelsPerFrame = 1;
    _asbd.mFormatID = kAudioFormatLinearPCM;
    _asbd.mSampleRate = _sampleRate;
    _asbd.mChannelsPerFrame = mChannelsPerFrame;
    //pcm数据范围(−2^16 + 1) ～ (2^16 - 1)
    _asbd.mBitsPerChannel = 16;
    //16 bit = 2 byte
    _asbd.mBytesPerPacket = mChannelsPerFrame * 2;
    //下面设置的是1 frame per packet, 所以 frame = packet
    _asbd.mBytesPerFrame = mChannelsPerFrame * 2;
    _asbd.mFramesPerPacket = 1;
    _asbd.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
}
- (void)setupAudioQueue {
    void *handle = (__bridge void *)self;
    OSStatus status = AudioQueueNewOutput(&_asbd, outputCallback, handle, NULL, NULL, 0, &_audioQueue);
    printf("AudioQueueNewOutput: %d \n", (int)status);
}
- (void)setupAudioQueueBuffers {
    _bufferSize = _sampleRate * _sampleTime * _asbd.mBytesPerPacket;
    for (int i = 0; i < kNumberBuffers; ++i) {
        AudioQueueBufferRef buffer;
        OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
        printf("player alloc buffer: %d \n", (int)status);
        buffer->mUserData = (void *)NO;
        buffer->mAudioDataByteSize = _bufferSize;
        mBuffers[i] = buffer;
    }
}
- (void)setupAudioSession {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    NSError *sessionError;
    BOOL result;
    
    result = [audioSession setPreferredIOBufferDuration:_sampleTime error:&sessionError];
    printf("setPreferredIOBufferDuration %d \n", result);
    
    result = [audioSession setPreferredSampleRate:_sampleRate error:&sessionError];
    printf("setPreferredSampleRate %d \n", result);
    
    _sampleTime = audioSession.IOBufferDuration;
    _sampleRate = audioSession.sampleRate;
}
- (void)startPlay {
    dispatch_async(_queue, ^{
        //start audio queue
        OSStatus status = AudioQueueStart(self.audioQueue, NULL);
        if (status == noErr) {
            self.isRunning = YES;
        }
        printf("AudioQueueStart: %d \n", (int)status);
    });
}
- (void)putAudioData:(void *)data length:(UInt32)length {
    if (!_isRunning) {
        return;
    }
    
    if (_fillIndex >= kNumberBuffers) {
        _fillIndex = 0;
    }
    AudioQueueBufferRef fillBuffer = mBuffers[_fillIndex];
    BOOL bufferFiled = (BOOL)fillBuffer->mUserData;
    if (bufferFiled) {
        printf("no buffer to fill \n");
        return;
    }
    memcpy(fillBuffer->mAudioData, data, length);
    fillBuffer->mAudioDataByteSize = length;
    fillBuffer->mUserData = (void *)YES;
    
    OSStatus status = AudioQueueEnqueueBuffer(_audioQueue, fillBuffer, 0, NULL);
    if (status != noErr) {
        printf("play enqueue buffer: %d \n", (int)status);
    }
    
    _fillIndex ++;
}
- (void)stopPlay {
    dispatch_async(_queue, ^{
        //stop audio queue
        OSStatus status = AudioQueueStop(self.audioQueue, true);
        if (status == noErr) {
            self.isRunning = NO;
        }
        printf("AudioQueueStop: %d \n", (int)status);
    });
}
static void outputCallback(void *outUserData,
                           AudioQueueRef outAQ,
                           AudioQueueBufferRef outBuffer) {
    ZFAudioQueuePlayer *player = (__bridge ZFAudioQueuePlayer *)outUserData;
    if (!player.isRunning) {
        return;
    }
    
    outBuffer->mUserData = (void *)NO;
}
@end
