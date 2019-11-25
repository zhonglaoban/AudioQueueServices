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
static const double kSampleTime = 0.02;//s
static const int kSampleRate = 44100;

@interface ZFAudioQueuePlayer()

@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) AudioStreamBasicDescription asbd;
@property (nonatomic) AudioQueueRef audioQueue;
@property (nonatomic) BOOL isRunning;
@property (nonatomic) UInt32 bufferSize;

@end


@implementation ZFAudioQueuePlayer
{
    AudioQueueBufferRef mBuffers[kNumberBuffers];
}
- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("zf.audioPlayer", DISPATCH_QUEUE_SERIAL);
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
    _asbd.mSampleRate = kSampleRate;
    _asbd.mChannelsPerFrame = mChannelsPerFrame;
    //pcm数据范围(−2^16 + 1) ～ (2^16 - 1)
    _asbd.mBitsPerChannel = 16;
    //16 bit = 2 byte
    _asbd.mBytesPerPacket = mChannelsPerFrame * 2;
    //下面设置的是1 frame per packet, 所以 frame = packet
    _asbd.mBytesPerFrame = mChannelsPerFrame * 2;
    _asbd.mFramesPerPacket = 1;
    _asbd.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
}
- (void)setupAudioQueue {
    void *handle = (__bridge void *)self;
    OSStatus status = AudioQueueNewOutput(&_asbd, outputCallback, handle, NULL, NULL, 0, &_audioQueue);
    printf("AudioQueueNewOutput: %d \n", (int)status);
}
- (void)setupAudioQueueBuffers {
    _bufferSize = kSampleRate * kSampleTime * _asbd.mBytesPerPacket;
    for (int i = 0; i < kNumberBuffers; ++i) {
        AudioQueueBufferRef buffer;
        OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
        printf("player alloc buffer: %d \n", (int)status);
        buffer->mUserData = (void *)NO;
        mBuffers[i] = buffer;
    }
}
- (void)setupAudioSession {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    NSError *sessionError;
    BOOL result;
    
    result = [audioSession setPreferredIOBufferDuration:kSampleTime error:&sessionError];
    printf("setPreferredIOBufferDuration %d \n", result);
    
    result = [audioSession setPreferredSampleRate:kSampleRate error:&sessionError];

    // Activate the audio session
    result = [audioSession setActive:YES error:&sessionError];
    printf("setActive %d \n", result);
}
- (void)startPlay {
//    [self setupAudioSession];
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
    AudioQueueBufferRef freeBuffer = NULL;
    
    for (int i = 0; i < kNumberBuffers; i++) {
        AudioQueueBufferRef buffer = mBuffers[i];
        BOOL used = (BOOL)buffer->mUserData;
        if (!used) {
            freeBuffer = buffer;
            break;
        }
    }
    if (freeBuffer) {
        memcpy(freeBuffer->mAudioData, data, length);
        freeBuffer->mAudioDataByteSize = length;
        OSStatus status = AudioQueueEnqueueBuffer(_audioQueue, freeBuffer, 0, NULL);
        printf("player enqueue buffer: %d \n", (int)status);
        freeBuffer->mUserData = (void *)YES;
    }else {
        printf("no buffer to use \n");
    }
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
