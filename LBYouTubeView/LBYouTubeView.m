//
//  LBYouTubeViewController.m
//  LBYouTubeViewController
//
//  Created by Laurin Brandner on 27.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LBYouTubeView.h"
#import "LBYouTubeExtractor.h"
#import <MediaPlayer/MediaPlayer.h>

@interface LBYouTubeView ()
@property (nonatomic, strong) MPMoviePlayerController* controller;
@property (nonatomic, strong) LBYouTubeExtractor *extractor;
@property (nonatomic) BOOL shouldAutomaticallyStartPlaying;

-(void)_setupWithURL:(NSURL*)URL;

-(void)_loadVideoWithContentOfURL:(NSURL*)videoURL;

-(void)_controllerPlaybackStateChanged:(NSNotification*)notification;

-(void)_didSuccessfullyExtractYouTubeURL:(NSURL*)videoURL;
-(void)_didStopPlayingYouTubeVideo:(MPMoviePlaybackState)state;
-(void)_failedExtractingYouTubeURLWithError:(NSError*)error;

@end


@implementation LBYouTubeView
@synthesize extractor = extractor_;
@synthesize controller, shouldAutomaticallyStartPlaying, highQuality, delegate;

#pragma mark Initialization

-(id)initWithYouTubeURL:(NSURL *)URL {
    self = [super init];
    if (self) {
        [self _setupWithURL:URL];
    }
    return self;
}

-(id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _setupWithURL:nil];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _setupWithURL:nil];
    }
    return self;
}

-(id)init {
    self = [super init];
    if (self) {
        [self _setupWithURL:nil];
    }
    return self;
}

-(void)_setupWithURL:(NSURL *)URL {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_controllerPlaybackStateChanged:) name:MPMoviePlayerPlaybackStateDidChangeNotification object:nil];
    
    self.backgroundColor = [UIColor blackColor];
    
    self.controller = nil;
    
    if (URL) {
        [self loadYouTubeURL:URL];
    }
}

#pragma mark -
#pragma mark Memory

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.extractor.completionHandler = nil;
    [self.extractor cancel];
}

#pragma mark -
#pragma mark Private

-(void)_loadVideoWithContentOfURL:(NSURL *)videoURL {
    self.controller = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
    self.controller.view.frame = self.bounds;
    self.controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.controller prepareToPlay];
    
    [self addSubview:self.controller.view];
    
    if (self.shouldAutomaticallyStartPlaying) {
        [self play];
    }
}

-(void)_controllerPlaybackStateChanged:(NSNotification *)__unused notification {
    MPMoviePlaybackState currentState = self.controller.playbackState;
    if (currentState == MPMoviePlaybackStateStopped || currentState == MPMoviePlaybackStatePaused || currentState == MPMoviePlaybackStateInterrupted) {
        [self _didStopPlayingYouTubeVideo:currentState];
    }
}

-(void)_didStopPlayingYouTubeVideo:(MPMoviePlaybackState)state {
    if ([self.delegate respondsToSelector:@selector(youTubeView:didStopPlayingYouTubeVideo:)]) {
        [self.delegate youTubeView:self didStopPlayingYouTubeVideo:state];
    }
}

#pragma mark -
#pragma mark Other Methods

-(void)loadYouTubeVideoWithID:(NSString*)videoID {
    [self loadYouTubeURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", videoID]]];
}

-(void)loadYouTubeURL:(NSURL *)URL {
    // Lazy load extractor or stop it
    if (self.extractor == nil) {
        self.extractor = [[LBYouTubeExtractor alloc] init];
        
        // Attach completion handler
        __unsafe_unretained LBYouTubeView *weakSelf = self;
        self.extractor.completionHandler = ^(NSURL *extractedURL, NSError *error)
        {
            if (extractedURL) {
                [weakSelf _didSuccessfullyExtractYouTubeURL:extractedURL];
                [weakSelf _loadVideoWithContentOfURL:extractedURL];
            }
            else {
                [weakSelf _failedExtractingYouTubeURLWithError:error];
            }
        };
    }
    else {
        [self.extractor cancel];
    }
    
    // Setup extractor
    self.extractor.youTubeURL = URL;
    self.extractor.highQuality = self.highQuality;
    
    // Start extractor
    [self.extractor start];
}

-(void)play {
    if (self.controller) {
        [self.controller play];
    }
    else {
        self.shouldAutomaticallyStartPlaying = YES;
    }
}

-(void)stop {
    if (self.controller) {
        [self.controller stop];
    }
    else {
        self.shouldAutomaticallyStartPlaying = NO;
    }
}

#pragma mark
#pragma mark Delegate Calls

-(void)_didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    if ([self.delegate respondsToSelector:@selector(youTubeView:didSuccessfullyExtractYouTubeURL:)]) {
        [self.delegate youTubeView:self didSuccessfullyExtractYouTubeURL:videoURL];
    }
}

-(void)_failedExtractingYouTubeURLWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(youTubeView:failedExtractingYouTubeURLWithError:)]) {
        [self.delegate youTubeView:self failedExtractingYouTubeURLWithError:error];
    }
}

@end
