//
//  LBYouTubeViewController.h
//  LBYouTubeViewController
//
//  Created by Laurin Brandner on 27.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@protocol LBYouTubeViewDelegate;

@interface LBYouTubeView : UIView {
    id <LBYouTubeViewDelegate> __weak delegate;
    BOOL highQuality;
}

@property (nonatomic, strong, readonly) MPMoviePlayerController* controller;
@property (nonatomic, weak) IBOutlet id <LBYouTubeViewDelegate> delegate;
@property (nonatomic) BOOL highQuality;

+(LBYouTubeView*)youTubeViewWithURL:(NSURL*)URL;
-(id)initWithYouTubeURL:(NSURL*)URL;

-(void)loadYouTubeURL:(NSURL*)URL;
-(void)loadYouTubeVideoWithID:(NSString*)videoID;
-(void)play;
-(void)stop;

@end
@protocol LBYouTubeViewDelegate <NSObject>

@optional
-(void)youTubeView:(LBYouTubeView*)youTubeView didSuccessfullyExtractYouTubeURL:(NSURL*)videoURL;
-(void)youTubeView:(LBYouTubeView*)youTubeView didStopPlayingYouTubeVideo:(MPMoviePlaybackState)state;
-(void)youTubeView:(LBYouTubeView*)youTubeView failedExtractingYouTubeURLWithError:(NSError*)error;

@end
