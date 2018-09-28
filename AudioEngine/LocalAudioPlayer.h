//
//  AudioPlayer.h
//  AudioEngine
//
//  Created by JoshuaHsiao on 2018/9/25.
//  Copyright © 2018 Joshua. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface LocalAudioPlayer : NSObject
@property(strong,nonatomic) NSURL *url;
- (id)init;
- (void)play;
- (void)pause;
@end
