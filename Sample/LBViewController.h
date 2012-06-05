//
//  LBViewController.h
//  LBYouTubeView
//
//  Created by Laurin Brandner on 27.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LBYouTubeView.h"

@interface LBViewController : UIViewController <LBYouTubeViewDelegate>

@property (nonatomic, strong) IBOutlet LBYouTubeView* youTubeView;
@property (weak, nonatomic) IBOutlet LBYouTubeView *youTubeView2;

@end
