//
//  LBYouTubePlayerController.m
//  LBYouTubeView
//
//  Created by Laurin Brandner on 29.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LBYouTubePlayerViewController.h"

@interface LBYouTubePlayerViewController () 

@property (nonatomic, strong) LBYouTubeExtractor* extractor;

@end
@implementation LBYouTubePlayerViewController

#pragma mark Initialization

-(id)initWithYouTubeURL:(NSURL *)youTubeURL quality:(LBYouTubeVideoQuality)quality {
    self = [super initWithContentURL:nil];
    if (self) {
        self.extractor = [[LBYouTubeExtractor alloc] initWithURL:youTubeURL quality:quality];
        self.extractor.delegate = self;
        [self.extractor startExtracting];
    }
    return self;
}

-(id)initWithYouTubeID:(NSString *)youTubeID quality:(LBYouTubeVideoQuality)quality {
    return [self initWithYouTubeURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", youTubeID]] quality:quality];
}

#pragma mark -
#pragma mark LBYouTubeExtractorDelegate

-(void)youTubeExtractor:(LBYouTubeExtractor *)extractor didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    if ([self.delegate respondsToSelector:@selector(youTubePlayerViewController:didSuccessfullyExtractYouTubeURL:)]) {
        [self.delegate youTubePlayerViewController:self didSuccessfullyExtractYouTubeURL:videoURL];
    }
    
    self.moviePlayer.contentURL = videoURL;
    [self.moviePlayer play];
}

-(void)youTubeExtractor:(LBYouTubeExtractor *)extractor failedExtractingYouTubeURLWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(youTubePlayerViewController:failedExtractingYouTubeURLWithError:)]) {
        [self.delegate youTubePlayerViewController:self failedExtractingYouTubeURLWithError:error];
    }
}

#pragma mark -

@end
