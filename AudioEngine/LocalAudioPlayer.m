//
//  AudioPlayer.m
//  AudioEngine
//
//  Created by JoshuaHsiao on 2018/9/25.
//  Copyright © 2018 Joshua. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LocalAudioPlayer.h"
@import AVFoundation;
@interface LocalAudioPlayer()
@property(strong,nonatomic) AVAudioEngine *engine;
@property(strong,nonatomic) AVAudioPlayerNode *playerNode;
@property(strong,nonatomic) AVAudioPCMBuffer *buffer;
@property(strong,nonatomic) AVAudioCompressedBuffer *streamBuffer;
@end

@implementation LocalAudioPlayer

- (id)init
{
    self = [super init];
    if (self) {
      
       
    }
    return self;
}
-(void)setUrl:(NSURL *)url
{
    _url = url;
    NSLog(@"url:%@",url);
    _engine = [[AVAudioEngine alloc] init];
    _playerNode = [[AVAudioPlayerNode alloc] init];
    [self.engine attachNode:_playerNode];
    AVAudioMixerNode *mixer = self.engine.mainMixerNode;
    [self.engine connect:_playerNode to:mixer format:[mixer outputFormatForBus:0]];
    NSError *error;
    if (![self.engine startAndReturnError:&error]) {
        NSLog(@"error:%@",error);
        return;
    }
    NSLog(@"no error:%@",error);
    AVAudioFile *file = [[AVAudioFile alloc] initForReading:url error:&error];
    NSLog(@"file error:%@",error);
    AVAudioFormat *format = file.processingFormat;
    NSLog(@"format:%@",format);
    AVAudioFrameCount capacity = (AVAudioFrameCount)file.length;
    _buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:capacity];
    
    [file readIntoBuffer:self.buffer error:&error];
    NSLog(@"readIntoBuffer error:%@",error);
    [_playerNode scheduleBuffer:self.buffer completionHandler:^{
    }];
    
}

-(void)play
{
    [_playerNode play];
}

-(void)pause
{
    [_playerNode pause];
}

@end
