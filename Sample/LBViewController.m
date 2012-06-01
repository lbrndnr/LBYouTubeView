//
//  LBViewController.m
//  LBYouTubeView
//
//  Created by Laurin Brandner on 27.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LBViewController.h"

@implementation LBViewController

@synthesize youTubeView;

-(void)viewDidLoad {
    [super viewDidLoad];
	
    self.youTubeView.delegate = self;
    self.youTubeView.highQuality = YES;
    [self.youTubeView loadYouTubeURL:[NSURL URLWithString:@"http://www.youtube.com/watch?v=1fTIhC1WSew&list=FLEYfH4kbq85W_CiOTuSjf8w&feature=mh_lolz"]];
    [self.youTubeView play];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - LBYouTubeViewDelegate

-(void)youTubeView:(LBYouTubeView *)youTubeView didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    NSLog(@"Did extract video source:%@", videoURL);
}

-(void)youTubeView:(LBYouTubeView *)youTubeView failedExtractingYouTubeURLWithError:(NSError *)error {
    NSLog(@"Failed loading video due to error:%@", error);
}

-(void)youTubeView:(LBYouTubeView *)youTubeView didStopPlayingYouTubeVideo:(MPMoviePlaybackState)state {
    NSLog(@"Did finish playing YouTube video");
}

@end
