//
//  LBYouTubePlayerController.h
//  LBYouTubeView
//
//  Created by Marco Muccinelli on 11/06/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LBYouTubePlayerController.h"

extern NSString* const LBYouTubePlayerControllerErrorDomain;
extern NSInteger const LBYouTubePlayerControllerErrorCodeInvalidHTML;
extern NSInteger const LBYouTubePlayerControllerErrorCodeNoStreamURL;
extern NSInteger const LBYouTubePlayerControllerErrorCodeNoJSONData;

@protocol LBYouTubePlayerControllerDelegate;

@interface LBYouTubePlayerViewController : NSObject {
    BOOL highQuality;
    NSURL* youTubeURL;
    NSURL* extractedURL;
    LBYouTubePlayerController* view;
    id <LBYouTubePlayerControllerDelegate> __unsafe_unretained delegate;
}

@property (nonatomic) BOOL highQuality;
@property (nonatomic, strong, readonly) NSURL* youTubeURL;
@property (nonatomic, strong, readonly) NSURL *extractedURL;
@property (nonatomic, strong, readonly) LBYouTubePlayerController* view;
@property (nonatomic, unsafe_unretained) IBOutlet id <LBYouTubePlayerControllerDelegate> delegate;

-(id)initWithYouTubeURL:(NSURL*)youTubeURL;
-(id)initWithYouTubeID:(NSString*)youTubeID;

@end
@protocol LBYouTubePlayerControllerDelegate <NSObject>

-(void)youTubePlayerViewController:(LBYouTubePlayerViewController *)controller didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL;
-(void)youTubePlayerViewController:(LBYouTubePlayerViewController *)controller failedExtractingYouTubeURLWithError:(NSError *)error;

@end
