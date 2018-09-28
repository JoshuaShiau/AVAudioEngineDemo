//
//  AudioPlayer.m
//  AudioEngine
//
//  Created by JoshuaHsiao on 2018/9/25.
//  Copyright © 2018 Joshua. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioPlayer.h"
#import "LocalAudioPlayer.h"
#import "RemoteAudioPlayer.h"
@import AVFoundation;
@interface AudioPlayer()
@property (nonatomic, strong) LocalAudioPlayer *localPlayer;
@property (nonatomic, strong) RemoteAudioPlayer *remotePlayer;
@end

@implementation AudioPlayer

- (id)init
{
    self = [super init];
    if (self) {
        if (nil == _localPlayer)
        {
            _localPlayer = [[LocalAudioPlayer alloc] init];
        }
        if (nil ==  _remotePlayer)
        {
            _remotePlayer = [[RemoteAudioPlayer alloc] init];
        }
    }
    return self;
}

-(void)setUrl:(NSURL *)url
{
    if (PLAYER_MODE_LOCAL_PLAY == self.playerMode)
    {
        [_localPlayer setUrl:url];
    }
    else
    {
        [_remotePlayer setUrl:url];
    }
}

-(void)play
{
    if (PLAYER_MODE_LOCAL_PLAY == self.playerMode)
    {
        [_localPlayer play];
    }
    else
    {
        [_remotePlayer play];
    }
}

-(void)pause
{
    if (PLAYER_MODE_LOCAL_PLAY == self.playerMode)
    {
        [_localPlayer pause];
    }
    else
    {
        [_remotePlayer pause];
    }
}

@end
