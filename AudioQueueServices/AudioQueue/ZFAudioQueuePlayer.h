//
//  ZFAudioQueuePlayer.h
//  AudioQueueServices
//
//  Created by 钟凡 on 2019/11/20.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZFAudioQueuePlayer : NSObject

- (void)startPlay;
- (void)putAudioData:(void *)data length:(UInt32)length;
- (void)stopPlay;

@end

NS_ASSUME_NONNULL_END
