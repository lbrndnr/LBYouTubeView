//
//  LBYouTubeViewController.m
//  LBYouTubeViewController
//
//  Created by Laurin Brandner on 27.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LBYouTubeView.h"
#import <MediaPlayer/MediaPlayer.h>

static NSString* const kUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A334 Safari/7534.48.3";
static NSString* const kLBYouTubeViewErrorDomain = @"LBYouTubeViewErrorDomain";

@interface LBYouTubeView () <NSURLConnectionDelegate> {
    NSURLConnection* connection;
    NSMutableData* htmlData;
    MPMoviePlayerController* controller;
    
    BOOL shouldAutomaticallyStartPlaying;
}

@property (nonatomic, strong) MPMoviePlayerController* controller;
@property (nonatomic, strong) NSURLConnection* connection;
@property (nonatomic, strong) NSMutableData* htmlData;

@property (nonatomic) BOOL shouldAutomaticallyStartPlaying;

-(void)_setupWithURL:(NSURL*)URL;
-(void)_cleanDownloadUp;

-(NSString*)_unescapeString:(NSString*)string;
-(void)_loadVideoWithContentOfURL:(NSURL*)videoURL;

-(void)_controllerPlaybackStateChanged:(NSNotification*)notification;

-(void)_didSuccessfullyExtractYouTubeURL:(NSURL*)videoURL;
-(void)_didStopPlayingYouTubeVideo:(MPMoviePlaybackState)state;
-(void)_failedExtractingYouTubeURLWithError:(NSError*)error;

@end
@implementation LBYouTubeView

@synthesize connection, htmlData, controller, shouldAutomaticallyStartPlaying, highQuality, delegate;

#pragma mark Initialization

+(LBYouTubeView*)youTubeViewWithURL:(NSURL *)URL {
    return [[self alloc] initWithYouTubeURL:URL];
}

-(id)initWithYouTubeURL:(NSURL *)URL {
    self = [super init];
    if (self) {
        [self _setupWithURL:URL];
    }
    return self;
}

-(id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _setupWithURL:nil];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _setupWithURL:nil];
    }
    return self;
}

-(id)init {
    self = [super init];
    if (self) {
        [self _setupWithURL:nil];
    }
    return self;
}

-(void)_setupWithURL:(NSURL *)URL {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_controllerPlaybackStateChanged:) name:MPMoviePlayerPlaybackStateDidChangeNotification object:nil];
    
    self.backgroundColor = [UIColor blackColor];
    
    self.controller = nil;
    self.htmlData = [NSMutableData data];
    
    if (URL) {
        [self loadYouTubeURL:URL];
    }
}

#pragma mark -
#pragma mark Memory

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.connection cancel];
}

-(void)_cleanDownloadUp {
    self.htmlData = nil;
    self.connection = nil;
}

#pragma mark -
#pragma mark Private

// Modified answer from StackOverflow http://stackoverflow.com/questions/2099349/using-objective-c-cocoa-to-unescape-unicode-characters-ie-u1234

-(NSString*)_unescapeString:(NSString*)string {
    // tokenize based on unicode escape char
    NSMutableString* tokenizedString = [NSMutableString string];
    NSScanner* scanner = [NSScanner scannerWithString:string];
    while ([scanner isAtEnd] == NO)
    {
        // read up to the first unicode marker
        // if a string has been scanned, it's a token
        // and should be appended to the tokenized string
        NSString* token = @"";
        [scanner scanUpToString:@"\\u" intoString:&token];
        if (token != nil && token.length > 0)
        {
            [tokenizedString appendString:token];
            continue;
        }
        
        // skip two characters to get past the marker
        // check if the range of unicode characters is
        // beyond the end of the string (could be malformed)
        // and if it is, move the scanner to the end
        // and skip this token
        NSUInteger location = [scanner scanLocation];
        NSInteger extra = scanner.string.length - location - 4 - 2;
        if (extra < 0)
        {
            NSRange range = {location, -extra};
            [tokenizedString appendString:[scanner.string substringWithRange:range]];
            [scanner setScanLocation:location - extra];
            continue;
        }
        
        // move the location pas the unicode marker
        // then read in the next 4 characters
        location += 2;
        NSRange range = {location, 4};
        token = [scanner.string substringWithRange:range];
        
        // we don't need non-ascii because it would break the json (only intrested in urls) 
        if (token.intValue) {
            unichar codeValue = (unichar) strtol([token UTF8String], NULL, 16);
            [tokenizedString appendString:[NSString stringWithFormat:@"%C", codeValue]];
        }
        
        // move the scanner past the 4 characters
        // then keep scanning
        location += 4;
        [scanner setScanLocation:location];
    }
    
    NSString* retString = [tokenizedString stringByReplacingOccurrencesOfString:@"\\\\\"" withString:@""];
    return [retString stringByReplacingOccurrencesOfString:@"\\" withString:@""];
}

-(void)_loadVideoWithContentOfURL:(NSURL *)videoURL {
    self.controller = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
    self.controller.view.frame = self.bounds;
    self.controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.controller prepareToPlay];
    
    [self addSubview:self.controller.view];
    
    if (self.shouldAutomaticallyStartPlaying) {
        [self play];
    }
}

-(void)_controllerPlaybackStateChanged:(NSNotification *)__unused notification {
    MPMoviePlaybackState currentState = self.controller.playbackState;
    if (currentState == MPMoviePlaybackStateStopped || currentState == MPMoviePlaybackStatePaused || currentState == MPMoviePlaybackStateInterrupted) {
        [self _didStopPlayingYouTubeVideo:currentState];
    }
}

-(void)_didStopPlayingYouTubeVideo:(MPMoviePlaybackState)state {
    if ([self.delegate respondsToSelector:@selector(youTubeView:didStopPlayingYouTubeVideo:)]) {
        [self.delegate youTubeView:self didStopPlayingYouTubeVideo:state];
    }
}

#pragma mark -
#pragma mark Other Methods

-(void)loadYouTubeVideoWithID:(NSString*)videoID {
    [self loadYouTubeURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", videoID]]];
}

-(void)loadYouTubeURL:(NSURL *)URL {
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
    
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    [connection start];
}

-(void)play {
    if (self.controller) {
        [self.controller play];
    }
    else {
        self.shouldAutomaticallyStartPlaying = YES;
    }
}

-(void)stop {
    if (self.controller) {
        [self.controller stop];
    }
    else {
        self.shouldAutomaticallyStartPlaying = NO;
    }
}

#pragma mark
#pragma mark Delegate Calls

-(void)_didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    if ([self.delegate respondsToSelector:@selector(youTubeView:didSuccessfullyExtractYouTubeURL:)]) {
        [self.delegate youTubeView:self didSuccessfullyExtractYouTubeURL:videoURL];
    }
}

-(void)_failedExtractingYouTubeURLWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(youTubeView:failedExtractingYouTubeURLWithError:)]) {
        [self.delegate youTubeView:self failedExtractingYouTubeURLWithError:error];
    }
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

-(void)connection:(NSURLConnection *)__unused connection didReceiveData:(NSData *)data {
    [self.htmlData appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)__unused connection {        
    NSString* html = [[NSString alloc] initWithData:self.htmlData encoding:NSUTF8StringEncoding];
    if (html.length <= 0) {
        [self _failedExtractingYouTubeURLWithError:[NSError errorWithDomain:kLBYouTubeViewErrorDomain code:1 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't download the HTML source code. URL might be invalid." forKey:NSLocalizedDescriptionKey]]];
        return;
    }

    NSString *JSONStart = nil;
    NSString *JSONStartFull = @"ls.setItem('PIGGYBACK_DATA', \")]}'";
    NSString *JSONStartShrunk = [JSONStartFull stringByReplacingOccurrencesOfString:@" " withString:@""];
    if ([html rangeOfString:JSONStartFull].location != NSNotFound)
        JSONStart = JSONStartFull;
    else if ([html rangeOfString:JSONStartShrunk].location != NSNotFound)
        JSONStart = JSONStartShrunk;

    if (JSONStart != nil) {
        NSScanner* scanner = [NSScanner scannerWithString:html];
        [scanner scanUpToString:JSONStart intoString:nil];
        [scanner scanString:JSONStart intoString:nil];
        
        NSString *JSON = nil;
        [scanner scanUpToString:@"\");" intoString:&JSON];  
        JSON = [self _unescapeString:JSON];
        
        NSError* decodingError = nil;
        NSDictionary* JSONCode = [NSJSONSerialization JSONObjectWithData:[JSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&decodingError];
        
        if (decodingError) {
            // Failed
            
            [self _failedExtractingYouTubeURLWithError:decodingError];
        }
        else {
            // Success
            
            NSDictionary* video = [[JSONCode objectForKey:@"content"] objectForKey:@"video"];
            NSString* streamURL = nil;
            NSString* streamURLKey = @"stream_url";
            
            if (self.highQuality) {
                streamURL = [video objectForKey:[NSString stringWithFormat:@"hq_%@", streamURLKey]];
                if (!streamURL) {
                    streamURL = [video objectForKey:streamURLKey];
                }
            }
            else {
                streamURL = [video objectForKey:streamURLKey];
            }
            
            if (streamURL) {
                NSURL* finalVideoURL = [NSURL URLWithString:streamURL];
                
                [self _didSuccessfullyExtractYouTubeURL:finalVideoURL];
                [self _loadVideoWithContentOfURL:finalVideoURL];
            }
            else {
                [self _failedExtractingYouTubeURLWithError:[NSError errorWithDomain:kLBYouTubeViewErrorDomain code:2 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't find the stream URL." forKey:NSLocalizedDescriptionKey]]];
            }
        }
    }
    else {
        [self _failedExtractingYouTubeURLWithError:[NSError errorWithDomain:kLBYouTubeViewErrorDomain code:3 userInfo:[NSDictionary dictionaryWithObject:@"The JSON data could not be found." forKey:NSLocalizedDescriptionKey]]];
    }

    [self _cleanDownloadUp];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {      
    [self _cleanDownloadUp];
    [self _failedExtractingYouTubeURLWithError:error];
}

#pragma mark -

@end
