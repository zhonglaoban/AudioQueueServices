//
//  ZFAudioQueueRecorder.h
//  AudioQueueServices
//
//  Created by 钟凡 on 2019/11/20.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ZFAudioQueueRecorder;

@protocol ZFAudioQueueRecorderDelegate <NSObject>

///采集到音频数据
- (void)audioRecorder:(ZFAudioQueueRecorder *)audioRecorder didRecoredAudioData:(void *)data length:(UInt32)length;

@end

@interface ZFAudioQueueRecorder : NSObject

@property (nonatomic, weak) id<ZFAudioQueueRecorderDelegate> delegate;

- (void)startRecord;
- (void)stopRecord;

@end

NS_ASSUME_NONNULL_END
