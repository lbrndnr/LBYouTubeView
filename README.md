# LBYouTubeView

## About
LBYouTubeView is just a small view that is able to display YouTube videos in a `MPMoviePlayerController`. You even have the choice between high-quality and standard quality stream.

How does it work? It just loads the HTML code of YouTube's mobile website and looks for the data in the script tag. LBYouTubeView doesn't use `UIWebView` which makes it faster and look cleaner.

## Usage
LBYouTubeView is dead simple. Just add an instance as a subview to a UIViewControllers view and tell it, what video it should load.

## Installation
1. Drag into your your project `LBYouTubeExtractor` folder, `LBYouTubeView` folder and `Submodules/JSONKit` folder.
2. Import the `MediaPlayer.framework`.
3. Set `-fno-objc-arc` compiler flag to `JSONKit.m`.

### Example

```objc
LBYouTubeView *youTubeView = [[LBYouTubeView alloc] initWithFrame:self.view.bounds];
youTubeView.delegate = self;
youTubeView.highQuality = YES;
[self.view addSubview:youTubeView];
[youTubeView loadYouTubeURL:[NSURL URLWithString:@"http://www.youtube.com/watch?v=1fTIhC1WSew&list=FLEYfH4kbq85W_CiOTuSjf8w&feature=mh_lolz"]];
[youTubeView play];
```

You can also only extract video URL without to use `LBYouTubeView` directly:

```objc
LBYouTubeExtractor *extractor = [[LBYouTubeExtractor alloc] init];
extractor.completionHandler = ^(NSURL *extractedURL, NSError *error) {
	// Do something with extractedURL...
};

extractor.highQuality = YES;
extractor.youTubeURL = [NSURL URLWithString:@"http://www.youtube.com/watch?v=1fTIhC1WSew&list=FLEYfH4kbq85W_CiOTuSjf8w&feature=mh_lolz"];

[extractor start];
```

## Requirements
LBYouTubeView requires iOS 4. Also, it is deployed for an ARC environment.

## License
LBYouTubeView is licensed under the [MIT License](http://opensource.org/licenses/mit-license.php). 
