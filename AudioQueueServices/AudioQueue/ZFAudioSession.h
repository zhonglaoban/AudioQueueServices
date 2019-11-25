//
//  ZFAudioSession.h
//  AudioQueueServices
//
//  Created by 钟凡 on 2019/11/21.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZFAudioSession : NSObject

+ (void)setPlayAndRecord;
+ (void)setPlayback;

@end

NS_ASSUME_NONNULL_END
