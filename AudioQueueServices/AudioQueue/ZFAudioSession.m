//
//  ZFAudioSession.m
//  AudioQueueServices
//
//  Created by 钟凡 on 2019/11/21.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import "ZFAudioSession.h"
#import <AVFoundation/AVFoundation.h>

@implementation ZFAudioSession

+ (void)setPlayAndRecord {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    NSError *sessionError;
    BOOL result;
    result = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                           withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker |
              AVAudioSessionCategoryOptionAllowBluetooth |
              AVAudioSessionCategoryOptionMixWithOthers
                                 error:&sessionError];
    
    printf("setCategory %d \n", result);
    // Activate the audio session
    result = [audioSession setActive:YES error:&sessionError];
    printf("setActive %d \n", result);
}
+ (void)setPlayback {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    NSError *sessionError;
    BOOL result;
    result = [audioSession setCategory:AVAudioSessionCategoryPlayback
                           withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionAllowBluetooth
                                 error:&sessionError];
    
    printf("setCategory %d \n", result);
    // Activate the audio session
    result = [audioSession setActive:YES error:&sessionError];
    printf("setActive %d \n", result);
}
@end
