//
//  LBViewController.h
//  LBYouTubeView
//
//  Created by Laurin Brandner on 27.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LBYouTube.h"

@interface LBViewController : UIViewController <LBYouTubePlayerControllerDelegate> {
    LBYouTubePlayerController* controller;
}

@property (nonatomic, strong) LBYouTubePlayerController* controller;

@end
