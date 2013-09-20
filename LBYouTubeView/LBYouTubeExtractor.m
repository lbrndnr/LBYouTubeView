//
//  LBYouTubeExtractor.m
//  LBYouTubeView
//
//  Created by Laurin Brandner on 28.09.12.
//
//

#import "LBYouTubeExtractor.h"

static NSString* const kUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A334 Safari/7534.48.3";

NSString* const kLBYouTubePlayerExtractorErrorDomain = @"LBYouTubeExtractorErrorDomain";

NSInteger const LBYouTubePlayerExtractorErrorCodeInvalidHTML  =    1;
NSInteger const LBYouTubePlayerExtractorErrorCodeNoStreamURL  =    2;
NSInteger const LBYouTubePlayerExtractorErrorCodeNoJSONData   =    3;

@interface LBYouTubeExtractor ()

@property (nonatomic, strong) NSURLConnection* connection;
@property (nonatomic, strong) NSMutableData* buffer;

@property (nonatomic, strong) NSURL* youTubeURL;
@property (nonatomic, strong) NSURL* extractedURL;
@property (nonatomic) LBYouTubeVideoQuality quality;

@end

@implementation LBYouTubeExtractor

#pragma mark Initialization

-(id)initWithURL:(NSURL *)videoURL quality:(LBYouTubeVideoQuality)videoQuality {
    self = [super init];
    if (self) {
        self.youTubeURL = videoURL;
        self.quality = videoQuality;
        self.extractionExpression = @"(?!\\\\\")http[^\"]*?itag=[^\"]*?(?=\\\\\")";
    }
    return self;
}

-(id)initWithID:(NSString *)videoID quality:(LBYouTubeVideoQuality)videoQuality {
    NSURL* URL = (videoID) ? [NSURL URLWithString:[NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", videoID]] : nil;
    return [self initWithURL:URL quality:videoQuality];
}

#pragma mark -
#pragma mark Other Methods

-(void)startExtracting {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [cookieStorage cookies];
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.domain rangeOfString:@"youtube"].location != NSNotFound) {
            [cookieStorage deleteCookie:cookie];
        }
    }
    
    if (!self.buffer || !self.extractedURL) {
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:self.youTubeURL];
        [request setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
        
        self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
        [self.connection start];
    }
}

-(void)stopExtracting {
    [self closeConnection];
}

- (void)extractVideoURLWithCompletionBlock:(LBYouTubeExtractorCompletionBlock)completionBlock {
    self.completionBlock = completionBlock;
    [self startExtracting];
}

#pragma mark -
#pragma mark Private

-(void)closeConnection {
    [self.connection cancel];
    self.connection = nil;
    self.buffer = nil;
}

-(NSURL*)extractYouTubeURLFromFile:(NSString *)html error:(NSError *__autoreleasing *)error {
    NSString* string = html;
    
    NSRegularExpression* regex = [[NSRegularExpression alloc] initWithPattern:self.extractionExpression options:NSRegularExpressionCaseInsensitive error:error];
    NSArray* videos = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
    
    if (videos.count > 0) {
        NSTextCheckingResult* checkingResult = nil;
        
        if (self.quality == LBYouTubeVideoQualityLarge) {
            checkingResult = [videos objectAtIndex:0];
        }
        else if (self.quality == LBYouTubeVideoQualityMedium) {
            unsigned int index = MIN(videos.count-1, 1U);
            checkingResult= [videos objectAtIndex:index];
        }
        else {
            checkingResult = [videos lastObject];
        }
        
        NSMutableString* streamURL = [NSMutableString stringWithString: [string substringWithRange:checkingResult.range]];
        [streamURL replaceOccurrencesOfString:@"\\\\u0026" withString:@"&" options:NSCaseInsensitiveSearch range:NSMakeRange(0, streamURL.length)];
        [streamURL replaceOccurrencesOfString:@"\\\\\\" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, streamURL.length)];
                
        return [NSURL URLWithString:streamURL];
    }
    
    *error = [NSError errorWithDomain:kLBYouTubePlayerExtractorErrorDomain code:2 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't find the stream URL." forKey:NSLocalizedDescriptionKey]];
    
    return nil;
}

-(void)didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    if (self.delegate) {
        [self.delegate youTubeExtractor:self didSuccessfullyExtractYouTubeURL:videoURL];
    }

    if(self.completionBlock) {
        self.completionBlock(videoURL, nil);
    }
}

-(void)failedExtractingYouTubeURLWithError:(NSError *)error {
    if (self.delegate) {
        [self.delegate youTubeExtractor:self failedExtractingYouTubeURLWithError:error];
    }

    if(self.completionBlock) {
        self.completionBlock(nil, error);
    }
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    long long capacity;
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
    [self closeConnection];

    if (html.length <= 0) {
        [self failedExtractingYouTubeURLWithError:[NSError errorWithDomain:kLBYouTubePlayerExtractorErrorDomain code:1 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't download the HTML source code. URL might be invalid." forKey:NSLocalizedDescriptionKey]]];
        return;
    }
    
    NSError* error = nil;
    self.extractedURL = [self extractYouTubeURLFromFile:html error:&error];
    if (error) {
        [self failedExtractingYouTubeURLWithError:error];
    }
    else {
        [self didSuccessfullyExtractYouTubeURL:self.extractedURL];
    }
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self closeConnection];
    [self failedExtractingYouTubeURLWithError:error];
}

#pragma mark -

@end
