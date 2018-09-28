//
//  RemoteAudioPlayer.m
//  AudioEngine
//
//  Created by JoshuaHsiao on 2018/9/25.
//  Copyright © 2018 Joshua. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RemoteAudioPlayer.h"

static void mAudioFileStreamPropertyListener(void * inClientData,
                                              AudioFileStreamID inAudioFileStream,
                                              AudioFileStreamPropertyID inPropertyID,
                                              UInt32 * ioFlags);
static void mAudioFileStreamPacketsCallback(void * inClientData,
                                             UInt32 inNumberBytes,
                                             UInt32 inNumberPackets,
                                             const void * inInputData,
                                             AudioStreamPacketDescription *inPacketDescriptions);
static void mAudioQueueOutputCallback(void * inUserData,
                                       AudioQueueRef inAQ,
                                       AudioQueueBufferRef inBuffer);
static void mAudioQueueRunningListener(void * inUserData,
                                        AudioQueueRef inAQ,
                                        AudioQueuePropertyID inID);

@interface RemoteAudioPlayer ()<NSURLSessionDelegate>
{
    NSURLConnection *URLConnection;
    struct {
        BOOL stopped;
        BOOL loaded;
    } playerStatus ;
    NSMutableData *bufferData;
    AudioFileStreamID audioFileStreamID;
    AudioQueueRef outputQueue;
    AudioStreamBasicDescription streamDescription;
    NSMutableArray *packets;
    size_t readHead;
}
- (double)packetsPerSecond;
@end

@implementation RemoteAudioPlayer

- (void)dealloc
{
    AudioQueueReset(outputQueue);
    AudioFileStreamClose(audioFileStreamID);
    [URLConnection cancel];
}
- (id)init
{
    self = [super init];
    if (self) {
        playerStatus.stopped = NO;
        packets = [[NSMutableArray alloc] init];
        
        // 第一步：建立 Audio Parser，指定 callback，以及建立 HTTP 連線，
        // 開始下載檔案
        AudioFileStreamOpen((__bridge void * _Nullable)(self),
                            mAudioFileStreamPropertyListener,
                            mAudioFileStreamPacketsCallback,
                            kAudioFileMP3Type, &audioFileStreamID);
        
    }
    return self;
}

-(void)setUrl:(NSURL *)url
{
    self.url = url;
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    NSURLSessionTask *task = [[NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:operationQueue] dataTaskWithRequest:request];
    [task resume];
}

- (id)initWithURL:(NSURL *)inURL
{
    self = [super init];
    if (self) {
        playerStatus.stopped = NO;
        packets = [[NSMutableArray alloc] init];
        
        AudioFileStreamOpen((__bridge void * _Nullable)(self),
                            mAudioFileStreamPropertyListener,
                            mAudioFileStreamPacketsCallback,
                            kAudioFileMP3Type, &audioFileStreamID);
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:inURL];
        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        NSURLSessionTask *task = [[NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:operationQueue] dataTaskWithRequest:request];
        [task resume];
    }
    return self;
}

- (double)packetsPerSecond
{
    if (streamDescription.mFramesPerPacket) {
        return streamDescription.mSampleRate / streamDescription.mFramesPerPacket;
    }
    
    return 44100.0/1152.0;
}

- (void)play
{
    AudioQueueStart(outputQueue, NULL);
}
- (void)pause
{
    AudioQueuePause(outputQueue);
}

#pragma mark NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    
    AudioFileStreamParseBytes(audioFileStreamID, (UInt32)[data length], [data bytes], 0);

}

#pragma mark -
#pragma mark Audio Parser and Audio Queue callbacks

- (void)_enqueueDataWithPacketsCount:(size_t)inPacketCount
{
    if (!outputQueue) {
        return;
    }
    
    if (readHead == [packets count]) {
        if (playerStatus.loaded) {
            AudioQueueStop(outputQueue, false);
            playerStatus.stopped = YES;
            return;
        }
    }
    
    if (readHead + inPacketCount >= [packets count]) {
        inPacketCount = [packets count] - readHead;
    }
    
    UInt32 totalSize = 0;
    UInt32 index;
    
    for (index = 0 ; index < inPacketCount ; index++) {
        NSData *packet = packets[index + readHead];
        totalSize += packet.length;
    }
    
    OSStatus status = 0;
    AudioQueueBufferRef buffer;
    status = AudioQueueAllocateBuffer(outputQueue, totalSize, &buffer);
    assert(status == noErr);
    buffer->mAudioDataByteSize = totalSize;
    buffer->mUserData = (__bridge void * _Nullable)(self);
    
    AudioStreamPacketDescription *packetDescs = calloc(inPacketCount,
                                                       sizeof(AudioStreamPacketDescription));
    
    totalSize = 0;
    for (index = 0 ; index < inPacketCount ; index++) {
        size_t readIndex = index + readHead;
        NSData *packet = packets[readIndex];
        memcpy(buffer->mAudioData + totalSize, packet.bytes, packet.length);
        
        AudioStreamPacketDescription description;
        description.mStartOffset = totalSize;
        description.mDataByteSize = (UInt32)packet.length;
        description.mVariableFramesInPacket = 0;
        totalSize += packet.length;
        memcpy(&(packetDescs[index]), &description, sizeof(AudioStreamPacketDescription));
    }
    status = AudioQueueEnqueueBuffer(outputQueue, buffer, (UInt32)inPacketCount, packetDescs);
    free(packetDescs);
    readHead += inPacketCount;
}

- (void)_createAudioQueueWithAudioStreamDescription:(AudioStreamBasicDescription *)audioStreamBasicDescription
{
    memcpy(&streamDescription, audioStreamBasicDescription, sizeof(AudioStreamBasicDescription));
    OSStatus status = AudioQueueNewOutput(audioStreamBasicDescription,
                                          mAudioQueueOutputCallback,
                                          (__bridge void * _Nullable)(self),
                                          CFRunLoopGetCurrent(),
                                          kCFRunLoopCommonModes, 0, &outputQueue);
    assert(status == noErr);
    status = AudioQueueAddPropertyListener(outputQueue,
                                           kAudioQueueProperty_IsRunning,
                                           mAudioQueueRunningListener,
                                           (__bridge void * _Nullable)(self));
    AudioQueuePrime(outputQueue, 0, NULL);
    AudioQueueStart(outputQueue, NULL);
}

- (void)_storePacketsWithNumberOfBytes:(UInt32)inNumberBytes
                       numberOfPackets:(UInt32)inNumberPackets
                             inputData:(const void *)inInputData
                    packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions
{
    for (int i = 0; i < inNumberPackets; ++i) {
        SInt64 packetStart = inPacketDescriptions[i].mStartOffset;
        UInt32 packetSize = inPacketDescriptions[i].mDataByteSize;
        assert(packetSize > 0);
        NSData *packet = [NSData dataWithBytes:inInputData + packetStart length:packetSize];
        [packets addObject:packet];
    }
    
    if (readHead == 0 && [packets count] > (int)([self packetsPerSecond] * 10)) {
        AudioQueueStart(outputQueue, NULL);
        [self _enqueueDataWithPacketsCount: (int)([self packetsPerSecond] * 10)];
    }
}

- (void)_audioQueueDidStart
{
    NSLog(@"Audio Queue did start");
}

- (void)_audioQueueDidStop
{
    NSLog(@"Audio Queue did stop");
    playerStatus.stopped = YES;
}

#pragma mark Properties

- (BOOL)isStopped
{
    return playerStatus.stopped;
}

@end

void mAudioFileStreamPropertyListener(void * inClientData,
                                       AudioFileStreamID inAudioFileStream,
                                       AudioFileStreamPropertyID inPropertyID,
                                       UInt32 * ioFlags)
{
    RemoteAudioPlayer *self = (__bridge RemoteAudioPlayer *)inClientData;
    if (inPropertyID == kAudioFileStreamProperty_DataFormat) {
        UInt32 dataSize     = 0;
        OSStatus status = 0;
        AudioStreamBasicDescription audioStreamDescription;
        Boolean writable = false;
        status = AudioFileStreamGetPropertyInfo(inAudioFileStream,
                                                kAudioFileStreamProperty_DataFormat,
                                                &dataSize, &writable);
        status = AudioFileStreamGetProperty(inAudioFileStream,
                                            kAudioFileStreamProperty_DataFormat,
                                            &dataSize, &audioStreamDescription);
        
        NSLog(@"mSampleRate: %f", audioStreamDescription.mSampleRate);
        NSLog(@"mFormatID: %u", audioStreamDescription.mFormatID);
        NSLog(@"mFormatFlags: %u", audioStreamDescription.mFormatFlags);
        NSLog(@"mBytesPerPacket: %u", audioStreamDescription.mBytesPerPacket);
        NSLog(@"mFramesPerPacket: %u", audioStreamDescription.mFramesPerPacket);
        NSLog(@"mBytesPerFrame: %u", audioStreamDescription.mBytesPerFrame);
        NSLog(@"mChannelsPerFrame: %u", audioStreamDescription.mChannelsPerFrame);
        NSLog(@"mBitsPerChannel: %u", audioStreamDescription.mBitsPerChannel);
        NSLog(@"mReserved: %u", audioStreamDescription.mReserved);
        
        [self _createAudioQueueWithAudioStreamDescription:&audioStreamDescription];
    }
}

void mAudioFileStreamPacketsCallback(void * inClientData,
                                      UInt32 inNumberBytes,
                                      UInt32 inNumberPackets,
                                      const void * inInputData,
                                      AudioStreamPacketDescription *inPacketDescriptions)
{

    RemoteAudioPlayer *self = (__bridge RemoteAudioPlayer *)inClientData;
    [self _storePacketsWithNumberOfBytes:inNumberBytes
                         numberOfPackets:inNumberPackets
                               inputData:inInputData
                      packetDescriptions:inPacketDescriptions];
}

static void mAudioQueueOutputCallback(void * inUserData,
                                       AudioQueueRef inAQ,AudioQueueBufferRef inBuffer)
{
    AudioQueueFreeBuffer(inAQ, inBuffer);
    RemoteAudioPlayer *self = (__bridge RemoteAudioPlayer *)inUserData;
    [self _enqueueDataWithPacketsCount:(int)([self packetsPerSecond] * 5)];
}

static void mAudioQueueRunningListener(void * inUserData,
                                        AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
    RemoteAudioPlayer *self = (__bridge RemoteAudioPlayer *)inUserData;
    UInt32 dataSize;
    OSStatus status = 0;
    status = AudioQueueGetPropertySize(inAQ, inID, &dataSize);
    if (inID == kAudioQueueProperty_IsRunning) {
        UInt32 running;
        status = AudioQueueGetProperty(inAQ, inID, &running, &dataSize);
        running ? [self _audioQueueDidStart] : [self _audioQueueDidStop];
    }
}
