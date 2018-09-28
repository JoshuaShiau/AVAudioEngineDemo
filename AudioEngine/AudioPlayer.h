//
//  AudioPlayer.h
//  AudioEngine
//
//  Created by JoshuaHsiao on 2018/9/25.
//  Copyright © 2018 Joshua. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
enum ID_PLAYER_MODE
{
    PLAYER_MODE_LOCAL_PLAY = 0,
    PLAYER_MODE_REMOTE
    
};
@interface AudioPlayer : NSObject
@property (nonatomic, assign) enum ID_PLAYER_MODE playerMode;
@property(strong,nonatomic) NSURL *url;
- (void)play;
- (void)pause;
@end
