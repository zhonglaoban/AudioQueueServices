# 使用AVCaptureSession录制音频
在iOS上，AVCaptureSession可以录制音频，使用起来简单。但是不能控制音频采样率、采样间隔等，不支持回音消除。

## 初始化
录制音频和处理音频数据有一些耗时操作，我们这里创建一个队列。然后在另一个线程中处理。
```
- (instancetype)init{
    if (self = [super init]) {
        _queue = dispatch_queue_create("zf.audioRecorder", DISPATCH_QUEUE_SERIAL);
        _session = [[AVCaptureSession alloc] init];
        dispatch_async(_queue, ^{
            [self configureSession];
        });
    }
    
    return self;
}
```
## 设置AVCaptureSession
获取音频采集设备，为AVCaptureSession添加音频输入和数据输出。设置输出的代理为self，线程为我们创建的那个queue所在的线程。
```
- (void)configureSession {
    NSError *error = nil;
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    
    if (error) {
        NSLog(@"Error getting audio input device: %@", error.description);
        return;
    }
    
    [self.session beginConfiguration];
    
    if ([self.session canAddInput:audioInput]) {
        [self.session addInput:audioInput];
    }
    // 配置采集输出，即我们取得音频的接口
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioOutput setSampleBufferDelegate:self queue:_queue];
    
    if ([self.session canAddOutput:self.audioOutput]) {
        [self.session addOutput:self.audioOutput];
    }
    
    [self.session commitConfiguration];
}
```
## 控制AVCaptureSession
这里我们需要使用设备的麦克风，开始采集的时候先请求麦克风权限
权限判断逻辑：
```
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
        dispatch_resume(_queue);
    }];
}
```
AVCaptureSession的开始和结束：
```
- (void)startRecord {
    [self checkAudioAuthorization:^(int code, NSString *message) {
        NSLog(@"checkAudioAuthorization code: %d, message: %@", code, message);
    }];
    dispatch_async(_queue, ^{
        [self.session startRunning];
    });
}
- (void)stopRecord {
    dispatch_async(_queue, ^{
        [self.session stopRunning];
    });
}
```
## 获取音频数据
在回调里面我们会拿到一个引用CMSampleBufferRef，CMSampleBuufer的结构如下：

![CMSampleBuffer的结构图](https://upload-images.jianshu.io/upload_images/3277096-d4c9d1c5cfd2bd69.png?imageMogr2/auto-orient/strip|imageView2/2/w/620)

这里我们取到里面的CMBlockBuffer，然后取里面的音频数据。
```
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    // 这里的sampleBuffer就是采集到的数据了，但它是Video还是Audio的数据，得根据captureOutput来判断
    if (captureOutput != self.audioOutput) {
        return;
    }
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t lengthAtOffset;
    size_t totalLength;
    char *data;
    CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffset, &totalLength, &data);

    if ([_delegate respondsToSelector:@selector(audioRecorder:didRecoredAudioData:length:)]) {
        [_delegate audioRecorder:self didRecoredAudioData:data length:(int)totalLength];
    }
}
```
