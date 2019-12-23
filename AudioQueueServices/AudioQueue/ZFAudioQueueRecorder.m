//
//  ZFAudioQueueRecorder.m
//  AudioQueueServices
//
//  Created by 钟凡 on 2019/11/20.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import "ZFAudioQueueRecorder.h"
#import <AVFoundation/AVFoundation.h>

static const int kNumberBuffers = 3;

@interface ZFAudioQueueRecorder()

@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) AudioStreamBasicDescription asbd;
@property (nonatomic) AudioQueueRef audioQueue;
@property (nonatomic) BOOL isRunning;
@property (nonatomic) UInt32 bufferSize;
@property (nonatomic, assign) double sampleTime;
@property (nonatomic, assign) double sampleRate;

@end


@implementation ZFAudioQueueRecorder
{
    AudioQueueBufferRef mBuffers[kNumberBuffers];
}
- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("zf.audioRecorder", DISPATCH_QUEUE_SERIAL);
        [self getAudioSessionProperty];
        [self setupAudioFormat];
        dispatch_async(_queue, ^{
            [self setupAudioQueue];
            [self allocateBuffers];
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
    OSStatus status = AudioQueueNewInput(&_asbd, inputCallback, handle, NULL, NULL, 0, &_audioQueue);
    printf("AudioQueueNewInput: %d \n", (int)status);
}
- (void)allocateBuffers {
    _bufferSize = _sampleRate * _sampleTime * _asbd.mBytesPerPacket;
    for (int i = 0; i < kNumberBuffers; ++i) {
        AudioQueueBufferRef buffer;
        OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
        printf("recorder alloc buffer: %d, _bufferSize:%u \n", (int)status, (unsigned int)_bufferSize);
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
- (BOOL)canDeviceOpenMicrophone {
    //判断应用是否有使用麦克风的权限
    NSString *mediaType = AVMediaTypeAudio;//读取媒体类型
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];//读取设备授权状态
    BOOL result = NO;
    switch (authStatus) {
        case AVAuthorizationStatusRestricted:
            result = NO;
            break;
        case AVAuthorizationStatusDenied:
            result = NO;
            break;
        case AVAuthorizationStatusAuthorized:
            result = YES;
            break;
        default:
            result = NO;
            break;
    }
    return result;
}
- (void)checkAudioAuthorization:(void (^)(int code, NSString *message))completeBlock {
    BOOL result = [self canDeviceOpenMicrophone];
    if (result) {
        completeBlock(0, @"可以使用麦克风");
        return;
    }
    dispatch_suspend(_queue);
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
        if (granted == NO) {
            completeBlock(-1, @"用户拒绝使用麦克风");
        }else {
            completeBlock(0, @"可以使用麦克风");
        }
        dispatch_resume(self.queue);
    }];
}
#pragma mark - public
- (void)startRecord {
    [self checkAudioAuthorization:^(int code, NSString *message) {
        NSLog(@"checkAudioAuthorization code: %d, message: %@", code, message);
    }];
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
- (void)stopRecord {
    dispatch_async(_queue, ^{
        //stop audio queue
        OSStatus status = AudioQueueStop(self.audioQueue, true);
        if (status == noErr) {
            self.isRunning = NO;
        }
        printf("AudioQueueStop: %d \n", (int)status);
    });
}
#pragma mark - c functions
static void inputCallback(void * inUserData,
                          AudioQueueRef inAQ,
                          AudioQueueBufferRef inBuffer,
                          const AudioTimeStamp * inStartTime,
                          UInt32 inNumberPacketDescriptions,
                          const AudioStreamPacketDescription *inPacketDescs) {
    ZFAudioQueueRecorder *recorder = (__bridge ZFAudioQueueRecorder *)inUserData;
    if (recorder.isRunning == NO) {
        return;
    }
    //消费音频数据
    if ([recorder.delegate respondsToSelector:@selector(audioRecorder:didRecoredAudioData:length:)]) {
        [recorder.delegate audioRecorder:recorder didRecoredAudioData:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
    }
    //将buffer给audio queue
    OSStatus status = AudioQueueEnqueueBuffer(recorder.audioQueue, inBuffer, 0, NULL);
    if (status != noErr) {
        printf("recorder enqueue buffer: %d \n", (int)status);
    }
}
@end
