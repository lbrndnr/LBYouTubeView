//
//  LBYouTubePlayerController.m
//  LBYouTubeView
//
//  Created by Laurin Brandner on 29.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LBYouTubePlayerController.h"

@interface LBYouTubePlayerController () 

@property (nonatomic, strong) MPMoviePlayerController* controller;

-(void)_setup;

@end
@implementation LBYouTubePlayerController

@synthesize controller;

#pragma mark Initialization

-(id)init {
    self = [super init];
    if (self) {
        [self _setup];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _setup];
    }
    return self;
}

-(id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _setup];
    }
    return self;
}

-(void)_setup {
    self.backgroundColor = [UIColor blackColor];
}

#pragma mark -
#pragma mark Other Methods

-(void)loadYouTubeVideo:(NSURL *)URL {
    if (self.controller) {
        [self.controller.view removeFromSuperview];
    }
    
    self.controller = [[MPMoviePlayerController alloc] initWithContentURL:URL];
    [self.controller prepareToPlay];
    self.controller.view.frame = self.bounds;
    self.controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.controller.view];
}

#pragma mark -

@end
