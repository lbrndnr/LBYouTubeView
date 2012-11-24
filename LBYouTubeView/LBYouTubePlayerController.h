//
//  LBYouTubePlayerController.h
//  LBYouTubeView
//
//  Created by Laurin Brandner on 29.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "LBYouTubeExtractor.h"

@protocol LBYouTubePlayerControllerDelegate;

@interface LBYouTubePlayerController : MPMoviePlayerController <LBYouTubeExtractorDelegate> {
    LBYouTubeExtractor* extractor;
    id <LBYouTubePlayerControllerDelegate> __unsafe_unretained delegate;
}

@property (nonatomic, strong, readonly) LBYouTubeExtractor* extractor;
@property (nonatomic, unsafe_unretained) IBOutlet id <LBYouTubePlayerControllerDelegate> delegate;

-(id)initWithYouTubeURL:(NSURL*)youTubeURL quality:(LBYouTubeVideoQuality)quality;
-(id)initWithYouTubeID:(NSString*)youTubeID quality:(LBYouTubeVideoQuality)quality;

@end
@protocol LBYouTubePlayerControllerDelegate <NSObject>

-(void)youTubePlayerViewController:(LBYouTubePlayerController *)controller didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL;
-(void)youTubePlayerViewController:(LBYouTubePlayerController *)controller failedExtractingYouTubeURLWithError:(NSError *)error;

@end
