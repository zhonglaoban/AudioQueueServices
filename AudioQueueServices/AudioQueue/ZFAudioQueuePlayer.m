//
//  ZFAudioQueuePlayer.m
//  AudioQueueServices
//
//  Created by 钟凡 on 2019/11/20.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import "ZFAudioQueuePlayer.h"
#import <AVFoundation/AVFoundation.h>

static const int kNumberBuffers = 3;

@interface ZFAudioQueuePlayer()

@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) AudioStreamBasicDescription asbd;
@property (nonatomic) AudioQueueRef audioQueue;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) int bufferSize;
@property (nonatomic, assign) double sampleTime;
@property (nonatomic, assign) double sampleRate;
@property (nonatomic, assign) int playIndex;

@end


@implementation ZFAudioQueuePlayer
{
    AudioQueueBufferRef mBuffers[kNumberBuffers];
}
- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("zf.audioPlayer", DISPATCH_QUEUE_SERIAL);
        [self getAudioSessionProperty];
        [self setupAudioFormat];
        dispatch_async(_queue, ^{
            [self setupAudioQueue];
            [self setVolume:1.0];
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
- (void)setVolume:(float)volume {
    OSStatus status = AudioQueueSetParameter(_audioQueue, kAudioQueueParam_Volume, volume);
    printf("set volume: %d \n", (int)status);
}
- (void)setupAudioQueueBuffers {
    _bufferSize = _sampleRate * _sampleTime * _asbd.mBytesPerPacket;
    for (int i = 0; i < kNumberBuffers; ++i) {
        AudioQueueBufferRef buffer;
        OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
        printf("player alloc buffer: %d, _bufferSize:%u \n", (int)status, (unsigned int)_bufferSize);
        buffer->mUserData = (void *)NO;
        buffer->mAudioDataByteSize = _bufferSize;
        mBuffers[i] = buffer;
    }
}
- (void)enqueueBuffers {
    for (int i = 0; i < kNumberBuffers; ++i) {
        AudioQueueBufferRef buffer = mBuffers[i];
        //需要将创建好的buffer给audio queue
        OSStatus status = AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL);
        printf("AudioQueueEnqueueBuffer: %d \n", (int)status);
    }
}
- (void)getAudioSessionProperty {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    _sampleTime = audioSession.IOBufferDuration;
    _sampleRate = audioSession.sampleRate;
    
    printf("_sampleTime %f \n", _sampleTime);
    printf("_sampleTime %f \n", _sampleRate);
}
- (void)startPlay {
    dispatch_async(_queue, ^{
        [self enqueueBuffers];
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
    
    //这里处理的有点粗糙，音频数据可能会乱
    AudioQueueBufferRef fillBuffer = NULL;
    for (int i = 0; i < kNumberBuffers; ++i) {
        AudioQueueBufferRef buffer = mBuffers[i];
        BOOL bufferFiled = (BOOL)buffer->mUserData;
        if (!bufferFiled) {
            fillBuffer = buffer;
            break;
        }
    }
    if (fillBuffer == NULL) {
        printf("没有可用buffer, 执行丢帧 \n");
        return;
    }
    memcpy(fillBuffer->mAudioData, data, length);
    fillBuffer->mAudioDataByteSize = length;
    fillBuffer->mUserData = (void *)YES;
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
    if (player.playIndex >= kNumberBuffers) {
        player.playIndex = 0;
    }
    AudioQueueBufferRef filledBuffer = player->mBuffers[player.playIndex];
    memcpy(outBuffer->mAudioData, filledBuffer->mAudioData, filledBuffer->mAudioDataByteSize);
    outBuffer->mUserData = (void *)NO;
    OSStatus status = AudioQueueEnqueueBuffer(player.audioQueue, outBuffer, 0, NULL);
    if (status != noErr) {
        printf("play enqueue buffer: %d \n", (int)status);
    }
    player.playIndex ++;
}
@end
