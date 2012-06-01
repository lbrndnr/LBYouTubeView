# LBYouTubeView

## About
LBYouTubeView is just a small view that is able to display YouTube videos in a `MPMoviePlayerController`. You even have the choice between high-quality and standard quality stream.

How does it work? It just loads the HTML code of YouTube's mobile website and looks for the data in the script tag. LBYouTubeView doesn't use `UIWebView` which makes it faster and look cleaner.

## Setup
LBYouTubeView is dead simple. Just add an instance as a subview to a UIViewControllers view and tell it, what video it should load.
Make sure to import the `MediaPlayer.framework` using `#import <MediaPlayer/MediaPlayer.h>`

### Example
```objc
LBYouTubeView* youTubeView = [[LBYouTubeView alloc] initWithFrame:self.view.bounds];
youTubeView.delegate = self;
youTubeView.highQuality = YES;
[self.view addSubview:youTubeView];
[youTubeView loadYouTubeURL:[NSURL URLWithString:@"http://www.youtube.com/watch?v=1fTIhC1WSew&list=FLEYfH4kbq85W_CiOTuSjf8w&feature=mh_lolz"]];
[youTubeView play];
```

## Requirements

LBYouTubeView requires iOS 5. However it shouldn't be too hard to make it iOS 4 compatible. Also, it is deployed for an ARC environment.

## License
LBYouTubeView is licensed under the [MIT License](http://opensource.org/licenses/mit-license.php). 
