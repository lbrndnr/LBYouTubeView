//
//  LBYouTubePlayerController.m
//  LBYouTubeView
//
//  Created by Marco Muccinelli on 11/06/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LBYouTubePlayerViewController.h"
#import "JSONKit.h"

static NSString* const kUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A334 Safari/7534.48.3";
NSString* const kLBYouTubePlayerControllerErrorDomain = @"LBYouTubePlayerControllerErrorDomain";

NSInteger const LBYouTubePlayerControllerErrorCodeInvalidHTML  =    1;
NSInteger const LBYouTubePlayerControllerErrorCodeNoStreamURL  =    2;
NSInteger const LBYouTubePlayerControllerErrorCodeNoJSONData   =    3;

@interface LBYouTubePlayerViewController () {
    NSURLConnection* connection;
    NSMutableData* buffer;
}

@property (nonatomic, strong) NSURLConnection* connection;
@property (nonatomic, strong) NSMutableData* buffer;

@property (nonatomic, strong) NSURL* youTubeURL;
@property (nonatomic, strong) NSURL *extractedURL;
@property (nonatomic, strong) LBYouTubePlayerController* view;

-(void)_setupWithYouTubeURL:(NSURL*)URL;

-(void)_closeConnection;
-(void)_startConnection;

-(NSString*)_unescapeString:(NSString*)string;
-(NSURL*)_extractYouTubeURLFromFile:(NSString*)html error:(NSError**)error;
-(void)_loadVideoWithContentOfURL:(NSURL*)videoURL;

-(void)_didSuccessfullyExtractYouTubeURL:(NSURL*)videoURL;
-(void)_failedExtractingYouTubeURLWithError:(NSError*)error;

@end
@implementation LBYouTubePlayerViewController

@synthesize youTubeURL, quality, extractedURL, view, delegate, buffer, connection;

#pragma mark

-(LBYouTubePlayerController*)view {
    if (view) {
        return view;
    }
    self.view = [LBYouTubePlayerController new];
    return view;
}

#pragma mark -
#pragma mark Initialization

-(id)initWithYouTubeURL:(NSURL *)URL {
    self = [super init];
    if (self) {
        [self _setupWithYouTubeURL:URL];
    }
    return self;
}

-(id)initWithYouTubeID:(NSString *)youTubeID {
    self = [super init];
    if (self) {
        [self _setupWithYouTubeURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", youTubeID]]];
    }
    return self;
}

-(void)_setupWithYouTubeURL:(NSURL *)URL {
    self.youTubeURL = URL;
    self.extractedURL = nil;
    self.view = nil;
    self.delegate = nil;
    
    [self _startConnection];
}

#pragma mark - 
#pragma mark Private

-(void)_closeConnection {
    [self.connection cancel];
    self.connection = nil;
    self.buffer = nil;
}

-(void)_startConnection {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.youTubeURL];
    [request setValue:(NSString *)kUserAgent forHTTPHeaderField:@"User-Agent"];
    
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [self.connection start];
}

// Modified answer from StackOverflow http://stackoverflow.com/questions/2099349/using-objective-c-cocoa-to-unescape-unicode-characters-ie-u1234

-(NSString *)_unescapeString:(NSString *)string {
    // will cause trouble if you have "abc\\\\uvw"
    // \u   --->    \U
    NSString *esc1 = [string stringByReplacingOccurrencesOfString:@"\\u" withString:@"\\U"];
    
    // "    --->    \"
    NSString *esc2 = [esc1 stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    
    // \\"  --->    \"
    NSString *esc3 = [esc2 stringByReplacingOccurrencesOfString:@"\\\\\"" withString:@"\\\""];
    
    NSString *quoted = [[@"\"" stringByAppendingString:esc3] stringByAppendingString:@"\""];
    NSData *data = [quoted dataUsingEncoding:NSUTF8StringEncoding];
    
    //  NSPropertyListFormat format = 0;
    //  NSString *errorDescr = nil;
    NSString *unesc = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
    
    if ([unesc isKindOfClass:[NSString class]]) {
        // \U   --->    \u
        return [unesc stringByReplacingOccurrencesOfString:@"\\U" withString:@"\\u"];
    }
    
    return nil;
}

-(NSURL*)_extractYouTubeURLFromFile:(NSString *)html error:(NSError *__autoreleasing *)error {
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
        NSDictionary* JSONCode = nil;
        
        // First try to invoke NSJSONSerialization (Thanks Mattt Thompson)
        
        id NSJSONSerializationClass = NSClassFromString(@"NSJSONSerialization");
        SEL NSJSONSerializationSelector = NSSelectorFromString(@"dataWithJSONObject:options:error:");
        if (NSJSONSerializationClass && [NSJSONSerializationClass respondsToSelector:NSJSONSerializationSelector]) { 
            JSONCode = [NSJSONSerialization JSONObjectWithData:[JSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&decodingError];
        }
        else {
            JSONCode = [JSON objectFromJSONStringWithParseOptions:JKParseOptionNone error:&decodingError];
        }
        
        if (decodingError) {
            // Failed
            
            *error = decodingError;
        }
        else {
            // Success
            
            NSArray* videos = [[[JSONCode objectForKey:@"content"] objectForKey:@"video"] objectForKey:@"fmt_stream_map"];
            NSString* streamURL = nil;
            if (videos.count) {
                NSString* streamURLKey = @"url";
                
                if (self.quality == LBYouTubePlayerQualityLarge) {
                    streamURL = [[videos objectAtIndex:0] objectForKey:streamURLKey];
                }
                else if (self.quality == LBYouTubePlayerQualityMedium) {
                    unsigned int index = MAX(0, videos.count-2);
                    streamURL = [[videos objectAtIndex:index] objectForKey:streamURLKey];
                }
                else {
                    streamURL = [[videos lastObject] objectForKey:streamURLKey];
                }
            }
            
            if (streamURL) {
                return [NSURL URLWithString:streamURL];
            }
            else {
                *error = [NSError errorWithDomain:kLBYouTubePlayerControllerErrorDomain code:2 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't find the stream URL." forKey:NSLocalizedDescriptionKey]];
            }
        }
    }
    else {
        *error = [NSError errorWithDomain:kLBYouTubePlayerControllerErrorDomain code:3 userInfo:[NSDictionary dictionaryWithObject:@"The JSON data could not be found." forKey:NSLocalizedDescriptionKey]];
    }
    
    return nil;
}

-(void)_loadVideoWithContentOfURL:(NSURL *)videoURL {
    [self.view loadYouTubeVideo:videoURL];
}

#pragma mark -
#pragma mark Other Methods

-(void)loadYouTubeURL:(NSURL *)URL {
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
    
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    [connection start];
}

#pragma mark
#pragma mark Delegate Calls

-(void)_didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    if ([self.delegate respondsToSelector:@selector(youTubePlayerViewController:didSuccessfullyExtractYouTubeURL:)]) {
        [self.delegate youTubePlayerViewController:self didSuccessfullyExtractYouTubeURL:videoURL];
    }
}

-(void)_failedExtractingYouTubeURLWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(youTubePlayerViewController:failedExtractingYouTubeURLWithError:)]) {
        [self.delegate youTubePlayerViewController:self failedExtractingYouTubeURLWithError:error];
    }
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSUInteger capacity;
    if (response.expectedContentLength != NSURLResponseUnknownLength) {
        capacity = response.expectedContentLength;
    }
    else {
        capacity = 0;
    }
    
    self.buffer = [[NSMutableData alloc] initWithCapacity:capacity];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.buffer appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *) connection {        
    NSString* html = [[NSString alloc] initWithData:self.buffer encoding:NSUTF8StringEncoding];
    [self _closeConnection];
    
    if (html.length <= 0) {
        [self _failedExtractingYouTubeURLWithError:[NSError errorWithDomain:kLBYouTubePlayerControllerErrorDomain code:1 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't download the HTML source code. URL might be invalid." forKey:NSLocalizedDescriptionKey]]];
        return;
    }
    
    NSError* error = nil;
    self.extractedURL = [self _extractYouTubeURLFromFile:html error:&error];
    if (error) {
        [self _failedExtractingYouTubeURLWithError:error];
    }
    else {
        [self _didSuccessfullyExtractYouTubeURL:self.extractedURL];
        [self _loadVideoWithContentOfURL:self.extractedURL];
    }
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {      
    [self _closeConnection];
    [self _failedExtractingYouTubeURLWithError:error];
}

#pragma mark -

@end
