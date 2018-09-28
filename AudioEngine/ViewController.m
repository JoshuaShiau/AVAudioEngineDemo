//
//  ViewController.m
//  AudioEngine
//
//  Created by JoshuaHsiao on 2018/9/24.
//  Copyright © 2018 Joshua. All rights reserved.
//

#import "ViewController.h"
#import "AudioPlayer.h"
#import "LocalAudioPlayer.h"
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>

@import AVFoundation;
@import MediaPlayer;
@interface ViewController ()<NSURLSessionDelegate>
{
    AudioFileStreamID audioFileStream;
}
@property(strong,nonatomic) AVAudioEngine *engine;
@property(strong,nonatomic) AVAudioPlayerNode *playerNode;
@property(strong,nonatomic) AVAudioPCMBuffer *buffer;
@property(strong,nonatomic) AVAudioFile *file;
@property(strong,nonatomic) AudioPlayer *player;
@property(strong,nonatomic) NSString *online;
@property(strong,nonatomic) NSMutableData* bufferdata;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioRouteChangeListenerCallback:)
                                                 name:AVAudioSessionRouteChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(otherAppAudioSessionCallBack:)
                                                 name:AVAudioSessionSilenceSecondaryAudioHintNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(systermAudioSessionCallBack:)
                                                 name:AVAudioSessionInterruptionNotification object:nil];
    
    [self becomeFirstResponder];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
//    _online = @"https://www.dl-sounds.com/wp-content/uploads/edd/2018/09/Listz-Consolation-No-3-preview.mp3";
    NSURL *url = [[NSBundle mainBundle] URLForAuxiliaryExecutable:@"audio.mp3"];

    _engine = [[AVAudioEngine alloc] init];
    // 2. Create a player node
    _playerNode = [[AVAudioPlayerNode alloc] init];
    
    // 3. Attach node to the engine
    [self.engine attachNode:_playerNode];
    // 4. Connect player node to engine's main mixer
    AVAudioMixerNode *mixer = self.engine.mainMixerNode;
    [self.engine connect:_playerNode to:mixer format:[mixer outputFormatForBus:0]];
    
    // 5. Start engine
    NSError *error;
    if (![self.engine startAndReturnError:&error]) {
        // handle error
    }

    _file = [[AVAudioFile alloc] initForReading:url error:nil];
    AVAudioFormat *format = _file.processingFormat;
    AVAudioFrameCount capacity = (AVAudioFrameCount)_file.length;
    _buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:capacity];
    // Read AVAudioFile -> AVAudioPCMBuffer
    [_file readIntoBuffer:self.buffer error:nil];
    
    [self.playerNode scheduleBuffer:self.buffer completionHandler:^{
        
    }];
    
    NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
    
    [dict setObject:_file.url.lastPathComponent forKey:MPMediaItemPropertyTitle];
    [dict setObject:@(_file.length/_file.fileFormat.sampleRate) forKey:MPMediaItemPropertyPlaybackDuration];
    [dict setObject:self.playerNode.isPlaying ? @1.0f : @0.0f forKey:MPNowPlayingInfoPropertyPlaybackRate];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:dict];
    
}

- (IBAction)playAction:(id)sender {
    
    if(self.playerNode.isPlaying)
    {
        [self.playerNode pause];
        [(UIButton *)sender setTitle:@"Play" forState:UIControlStateNormal];
    }
    else
    {
        [self.playerNode play];
        [(UIButton *)sender setTitle:@"Pause" forState:UIControlStateNormal];
    }
}
- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent
{
    NSLog(@"receivedEvent.type:%ld",receivedEvent.type);
    if (receivedEvent.type == UIEventTypeRemoteControl)
    {
        NSLog(@"receivedEvent.subtype:%ld",receivedEvent.subtype);
        
        switch (receivedEvent.subtype)
        {
            case UIEventSubtypeRemoteControlTogglePlayPause:
                
                break;
            case UIEventSubtypeRemoteControlPlay:
                [self.playerNode play];
                break;
            case UIEventSubtypeRemoteControlPause:
                if(self.playerNode.isPlaying)
                    [self.playerNode pause];
                else
                    [self.playerNode play];
                break;
            case UIEventSubtypeRemoteControlNextTrack:
                break;
            case UIEventSubtypeRemoteControlPreviousTrack:
                break;
            default:
                break;
        }
    }
}


-(BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)audioRouteChangeListenerCallback:(NSNotification*)notification {
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:{
            NSLog(@"headset input");
            break;
        }
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:{
            NSLog(@"pause play when headset output");
            
            break;
        }
        case AVAudioSessionRouteChangeReasonCategoryChange:
            NSLog(@"AVAudioSessionRouteChangeReasonCategoryChange");
            break;
    }
}


- (void)otherAppAudioSessionCallBack:(NSNotification *)notification {
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger interuptType = [[interuptionDict valueForKey:AVAudioSessionSilenceSecondaryAudioHintTypeKey] integerValue];
    switch (interuptType) {
        case AVAudioSessionSilenceSecondaryAudioHintTypeBegin:{
            [self.playerNode pause];
            NSLog(@"pause play when other app occupied session");
            break;
        }
        case AVAudioSessionSilenceSecondaryAudioHintTypeEnd:{
             if(_engine.isRunning)
                 [self.playerNode play];
            NSLog(@"occupied session");
            break;
        }
        default:
            break;
    }
}


- (void)systermAudioSessionCallBack:(NSNotification *)notification {
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger interuptType = [[interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    
    switch (interuptType) {
        case AVAudioSessionInterruptionTypeBegan:{
            [self.playerNode pause];
            [self.engine pause];
            NSLog(@"pause play when phone call or alarm :%@",_engine);
            break;
        }
        case AVAudioSessionInterruptionTypeEnded:{
            NSLog(@"AVAudioSessionInterruptionTypeEnded:%@",_engine);
            dispatch_async(dispatch_get_main_queue(), ^{
                if(self.engine.isRunning)
                    [self.playerNode play];
                else{
                    [self.engine startAndReturnError:nil];
                    //[self.playerNode play];
                }
                
            });
            
            break;
        }
        default:
            break;
    }
}

@end
