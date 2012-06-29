//
//  LBViewController.h
//  LBYouTubeView
//
//  Created by Laurin Brandner on 27.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LBYouTubePlayerViewController.h"

@interface LBViewController : UIViewController <LBYouTubePlayerControllerDelegate> {
    LBYouTubePlayerViewController* controller;
}

@property (nonatomic, strong) LBYouTubePlayerViewController* controller;

@end
