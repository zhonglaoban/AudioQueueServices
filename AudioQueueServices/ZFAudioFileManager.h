//
//  ZFAudioFileManager.h
//  AVCaptureSessionAudioRecorder
//
//  Created by 钟凡 on 2019/10/31.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZFAudioFileManager : NSObject

@property(copy, nonatomic) NSString* filePath;

- (instancetype)initWithAsbd:(AudioStreamBasicDescription)asbd;
- (void)openFileWithFilePath:(NSString *)filePath;
- (void)writeData:(void *)data length:(int)length;
- (void)closeFile;

@end

NS_ASSUME_NONNULL_END
