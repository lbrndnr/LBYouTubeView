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
@synthesize youTubeView2;

-(void)viewDidLoad {
    [super viewDidLoad];
	
    for (LBYouTubeView *v in [NSArray arrayWithObjects:self.youTubeView,self.youTubeView2, nil]) {
        v.delegate = self;
        v.highQuality = YES;
       //[v loadYouTubeVideoWithID:@"1fTIhC1WSew"];
        //[v play];
    }
    [self.youTubeView loadYouTubeURL:[NSURL URLWithString:@"http://www.youtube.com/watch?v=1fTIhC1WSew&list=FLEYfH4kbq85W_CiOTuSjf8w&feature=mh_lolz"]];
    [self.youTubeView2 loadYouTubeURL:[NSURL URLWithString:@"http://www.youtube.com/watch?v=CC3Qr4VC2MI&feature=g-all-lik"]];

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

- (void)viewDidUnload {
    [self setYouTubeView2:nil];
    [super viewDidUnload];
}
@end
