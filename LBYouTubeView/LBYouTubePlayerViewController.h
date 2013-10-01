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

@interface LBYouTubePlayerViewController : MPMoviePlayerViewController <LBYouTubeExtractorDelegate>

@property (nonatomic, strong, readonly) LBYouTubeExtractor* extractor;
@property (nonatomic, weak) IBOutlet id <LBYouTubePlayerControllerDelegate> delegate;

-(id)initWithYouTubeURL:(NSURL*)youTubeURL quality:(LBYouTubeVideoQuality)quality;
-(id)initWithYouTubeURL:(NSURL*)youTubeURL quality:(LBYouTubeVideoQuality)quality extractionExpression:(NSString*)expression;
-(id)initWithYouTubeID:(NSString*)youTubeID quality:(LBYouTubeVideoQuality)quality;
-(id)initWithYouTubeID:(NSString*)youTubeID quality:(LBYouTubeVideoQuality)quality extractionExpression:(NSString*)expression;

@end
@protocol LBYouTubePlayerControllerDelegate <NSObject>

-(void)youTubePlayerViewController:(LBYouTubePlayerViewController *)controller didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL;
-(void)youTubePlayerViewController:(LBYouTubePlayerViewController *)controller failedExtractingYouTubeURLWithError:(NSError *)error;

@end
