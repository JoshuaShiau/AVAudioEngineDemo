//
//  AudioPlayer.h
//  AudioEngine
//
//  Created by JoshuaHsiao on 2018/9/25.
//  Copyright © 2018 Joshua. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface RemoteAudioPlayer : NSObject
- (id)init;
- (id)initWithURL:(NSURL *)inURL;
- (void)play;
- (void)pause;
@property (readonly, getter=isStopped) BOOL stopped;
@property(strong,nonatomic) NSURL *url;
@end
