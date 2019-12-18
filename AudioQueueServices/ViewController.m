//
//  ViewController.m
//  AudioQueuePlayer
//
//  Created by 钟凡 on 2019/11/20.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import "ViewController.h"
#import "ZFAudioQueueRecorder.h"
#import "ZFAudioQueuePlayer.h"
#import "ZFAudioSession.h"
#import "ZFAudioFileManager.h"

@interface ViewController ()<ZFAudioQueueRecorderDelegate>

@property (strong, nonatomic) ZFAudioQueueRecorder *audioRecorder;
@property (strong, nonatomic) ZFAudioQueuePlayer *audioPlayer;
@property (strong, nonatomic) ZFAudioFileManager *audioWriter;

@end

@implementation ViewController
- (IBAction)playAndRecord:(UIButton *)sender {
    [sender setSelected:!sender.isSelected];
    if (sender.isSelected) {
        [_audioRecorder startRecord];
        [_audioPlayer startPlay];
    }else {
        [_audioRecorder stopRecord];
        [_audioPlayer stopPlay];
        [_audioWriter closeFile];
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [ZFAudioSession setPlayAndRecord];
    
    _audioRecorder = [[ZFAudioQueueRecorder alloc] init];
    _audioRecorder.delegate = self;
    
    _audioPlayer = [[ZFAudioQueuePlayer alloc] init];
    
    AudioStreamBasicDescription absd = {0};
    absd.mSampleRate = 44100;
    absd.mFormatID = kAudioFormatLinearPCM;
    absd.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    absd.mBytesPerPacket = 2;
    absd.mFramesPerPacket = 1;
    absd.mBytesPerFrame = 2;
    absd.mChannelsPerFrame = 1;
    absd.mBitsPerChannel = 16;
    
    NSString *directory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *filePath = [NSString stringWithFormat:@"%@/test.aif", directory];
    NSLog(@"%@", filePath);
    _audioWriter = [[ZFAudioFileManager alloc] initWithAsbd:absd];
    [_audioWriter openFileWithFilePath:filePath];
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    [_audioRecorder stopRecord];
//    [_audioPlayer stopPlay];
}

- (void)audioRecorder:(ZFAudioQueueRecorder *)audioRecorder didRecoredAudioData:(void *)data length:(UInt32)length {
    [_audioPlayer putAudioData:data length:length];
//    [_audioWriter writeData:data length:length];
}
@end
