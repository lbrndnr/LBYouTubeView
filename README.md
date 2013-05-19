# LBYouTubeView

## About
LBYouTubeView is just a small view that is able to display YouTube videos in a `MPMoviePlayerController`. You even have the choice between high-quality and standard quality stream.

How does it work? It just loads the HTML code of YouTube's mobile website and looks for the data in the script tag. LBYouTubeView doesn't use `UIWebView` which makes it faster and look cleaner.

## Usage
LBYouTubeView is dead simple. Just add an instance as a subview to a UIViewControllers view and tell it, what video it should load.

## Installation
1. Drag the `LBYouTubeView` folder into your project.
2. Import the `MediaPlayer.framework`.
3. If you need to support iOS 4, add `JSONKit` to your project and set `-fno-objc-arc` compiler flag to `JSONKit.m`.

### Example

```objc
LBYouTubePlayerViewController* controller = [[LBYouTubePlayerViewController alloc] initWithYouTubeURL:[NSURL URLWithString:@"http://www.youtube.com/watch?v=1fTIhC1WSew&list=FLEYfH4kbq85W_CiOTuSjf8w&feature=mh_lolz"] quality:LBYouTubeVideoQualityLarge];
controller.delegate = self;
controller.view.frame = CGRectMake(0.0f, 0.0f, 200.0f, 200.0f);
controller.view.center = self.view.center;
[self.view addSubview:self.controller.view];
```

You can also only extract video URL without to use `LBYouTubePlayerViewController` directly:

```objc
LBYouTubeExtractor* extractor = [[LBYouTubeExtractor alloc] initWithURL:URL quality:quality];
extractor.delegate = self;
[extractor startExtracting];
```

## Requirements
LBYouTubeView requires iOS 4. Also, it is deployed for an ARC environment.

## License
LBYouTubeView is licensed under the [MIT License](http://opensource.org/licenses/mit-license.php). 

## YouTube EULA
As stated in Google's [Monetization Guidelines](https://developers.google.com/youtube/creating_monetizable_applications) that attempting to play a YouTube video outside of either the YouTube embedded, custom or chromeless player is strictly prohibited by the API Terms of Service.
LBYouTubeView most likely does violate those guidelines. However, it seems like Apple lets your app pass through their review. 
Anyway, use it on your own risk.