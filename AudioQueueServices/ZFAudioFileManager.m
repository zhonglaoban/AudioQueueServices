//
//  ZFAudioFileManager.m
//  AVCaptureSessionAudioRecorder
//
//  Created by 钟凡 on 2019/10/31.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import "ZFAudioFileManager.h"

@interface ZFAudioFileManager()

@property (nonatomic, assign) AudioStreamBasicDescription asbd;

@end


@implementation ZFAudioFileManager
{
    AudioFileTypeID _fileType;
    AudioFileID _audioFile;
    UInt32 _currentPacket;
}
- (instancetype)initWithAsbd:(AudioStreamBasicDescription)asbd {
    self = [super init];
    if (self) {
        _asbd = asbd;
        _fileType = kAudioFileCAFType;
        [self setAudioFormat];
    }
    return self;
}
- (void)setAudioFormat {
    
}
- (void)creatAudioFile {
    CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation(NULL,(const UInt8*)self.filePath.UTF8String, strlen(self.filePath.UTF8String), false);
    
    OSStatus status = AudioFileCreateWithURL(audioFileURL,
                                             _fileType,
                                             &_asbd,
                                             kAudioFileFlags_EraseFile,
                                             &_audioFile);
    printf("create audio file: %d \n", (int)status);
}
- (void)writeData:(void *)data length:(int)length {
    UInt32 inNumPackets = 0;
    if (_asbd.mBytesPerPacket != 0) {
        inNumPackets = length / _asbd.mBytesPerPacket;
    }
    
    OSStatus status = AudioFileWritePackets(_audioFile, false, length, nil, _currentPacket, &inNumPackets, data);
    if (status == noErr){
        _currentPacket += inNumPackets;
    }
    printf("write date to file: %u\n", _currentPacket);
}
- (void)openFileWithFilePath:(NSString *)filePath {
    CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation(NULL,(const UInt8*)filePath.UTF8String, strlen(filePath.UTF8String), false);
    _currentPacket = 0;
    OSStatus status = AudioFileCreateWithURL(audioFileURL, _fileType, &_asbd, kAudioFileFlags_EraseFile, &_audioFile);
    printf("create audio file: %d \n", (int)status);
}
- (void)closeFile {
    OSStatus status = AudioFileClose(_audioFile);
    printf("close audio file: %d \n", (int)status);
}
- (void)readDataFromFile:(NSString *)filePath {
    
}

@end
