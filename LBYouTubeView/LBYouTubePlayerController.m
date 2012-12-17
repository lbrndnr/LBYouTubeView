//
//  LBYouTubePlayerController.m
//  LBYouTubeView
//
//  Created by Laurin Brandner on 29.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LBYouTubePlayerController.h"

@interface LBYouTubePlayerController () 

@property (nonatomic, strong) LBYouTubeExtractor* extractor;

-(void)_setupWithYouTubeURL:(NSURL*)URL quality:(LBYouTubeVideoQuality)quality;

-(void)_didSuccessfullyExtractYouTubeURL:(NSURL*)videoURL;
-(void)_failedExtractingYouTubeURLWithError:(NSError*)error;

@end
@implementation LBYouTubePlayerController

@synthesize delegate, extractor;

#pragma mark Initialization

-(id)initWithYouTubeURL:(NSURL *)URL quality:(LBYouTubeVideoQuality)quality {
    self = [super init];
    if (self) {
        [self _setupWithYouTubeURL:URL quality:quality];
    }
    return self;
}

-(id)initWithYouTubeID:(NSString *)youTubeID quality:(LBYouTubeVideoQuality)quality {
    self = [super init];
    if (self) {
        NSURL *youtubeURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", youTubeID]];
        [self _setupWithYouTubeURL:youtubeURL quality:quality];
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)_setupWithYouTubeURL:(NSURL *)URL quality:(LBYouTubeVideoQuality)quality {
    self.delegate = nil;
    
    self.extractor = [[LBYouTubeExtractor alloc] initWithURL:URL quality:quality];
    self.extractor.delegate = self;
    [self.extractor startExtracting];
}

#pragma mark -
#pragma mark Delegate Calls

-(void)_preparedToPlayMedia:(NSURL *)videoURL {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if ([self.delegate respondsToSelector:@selector(youTubePlayerViewControllerPreparedToPlayMedia:)]) {
        [self.delegate youTubePlayerViewControllerPreparedToPlayMedia:self];
    }
}

-(void)_didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    if ([self.delegate respondsToSelector:@selector(youTubePlayerViewController:didSuccessfullyExtractYouTubeURL:)]) {
        [self.delegate youTubePlayerViewController:self didSuccessfullyExtractYouTubeURL:videoURL];
    }
}

-(void)_failedExtractingYouTubeURLWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(youTubePlayerViewController:failedExtractingYouTubeURLWithError:)]) {
        [self.delegate youTubePlayerViewController:self failedExtractingYouTubeURLWithError:error];
    }
}

#pragma mark -
#pragma mark LBYouTubeExtractorDelegate

-(void)youTubeExtractor:(LBYouTubeExtractor *)extractor didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    [self _didSuccessfullyExtractYouTubeURL:videoURL];
    
    self.contentURL = videoURL;
    [self play];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_preparedToPlayMedia:)
                                                 name:MPMediaPlaybackIsPreparedToPlayDidChangeNotification
                                               object:nil];
    
}

-(void)youTubeExtractor:(LBYouTubeExtractor *)extractor failedExtractingYouTubeURLWithError:(NSError *)error {
    [self _failedExtractingYouTubeURLWithError:error];
}

#pragma mark -

@end
