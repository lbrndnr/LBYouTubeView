//
//  LBYouTubeExtractor.m
//  LBYouTubeView
//
//  Created by Laurin Brandner on 28.09.12.
//
//

#import "LBYouTubeExtractor.h"
#import "AFHTTPRequestOperationManager.h"

static NSString* const kUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A334 Safari/7534.48.3";

NSString* const kLBYouTubePlayerExtractorErrorDomain = @"LBYouTubeExtractorErrorDomain";

NSInteger const LBYouTubePlayerExtractorErrorCodeInvalidHTML  =    1;
NSInteger const LBYouTubePlayerExtractorErrorCodeNoStreamURL  =    2;
NSInteger const LBYouTubePlayerExtractorErrorCodeNoJSONData   =    3;

@interface LBYouTubeExtractor ()

@property (nonatomic, strong) NSURLConnection* connection;
@property (nonatomic, strong) NSMutableData* buffer;
@property (nonatomic, strong) AFHTTPRequestOperationManager *manager;
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
        self.extractionExpression = @"(?<=\\\\\")http[^\"]*?itag=[^\"]*?(?=\\\\\")";
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
    self.extractedURL = nil;
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [cookieStorage cookies];
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.domain rangeOfString:@"youtube"].location != NSNotFound) {
            [cookieStorage deleteCookie:cookie];
        }
    }
    [self.manager GET:self.youTubeURL.absoluteString
           parameters:nil
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  NSString *htmlString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                  [self extractYouTubeURLFromFile:htmlString
                                       completion:^(NSURL *videoURL, NSError *error) {
                                           self.extractedURL = videoURL;
                                           if (error) {
                                               [self failedExtractingYouTubeURLWithError:error];
                                           } else {
                                               [self didSuccessfullyExtractYouTubeURL:self.extractedURL];
                                           }
                                       }];
              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  [self failedExtractingYouTubeURLWithError:[NSError errorWithDomain:kLBYouTubePlayerExtractorErrorDomain code:1 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't download the HTML source code. URL might be invalid." forKey:NSLocalizedDescriptionKey]]];
              }];
}

-(AFHTTPRequestOperationManager*)manager {
    if (!_manager) {
        _manager = [AFHTTPRequestOperationManager manager];
        AFHTTPRequestSerializer *requestSeralizer = [[AFHTTPRequestSerializer alloc] init];
        [requestSeralizer setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
        [requestSeralizer setValue:@"text/html" forHTTPHeaderField:@"Content-Type"];
        [_manager setRequestSerializer:requestSeralizer];
        AFHTTPResponseSerializer *responseSerializer = [[AFHTTPResponseSerializer alloc] init];
        [responseSerializer setAcceptableContentTypes:[NSSet setWithObject:@"text/html"]];
        [_manager setResponseSerializer:responseSerializer];
    }
    return _manager;
}


- (void)extractVideoURLWithCompletionBlock:(LBYouTubeExtractorCompletionBlock)completionBlock {
    self.completionBlock = completionBlock;
    [self startExtracting];
}

#pragma mark -
#pragma mark Private

-(void)extractYouTubeURLFromFile:(NSString *)html completion:(void(^)(NSURL *videoURL, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSError *error = nil;
        
        //Background Thread
#if DEBUG
        NSDate *startTime = [NSDate date];
#endif
        
        NSRegularExpression* regex = [[NSRegularExpression alloc] initWithPattern:self.extractionExpression options:NSRegularExpressionCaseInsensitive error:&error];
        NSArray* videos = [regex matchesInString:html options:0 range:NSMakeRange(0, [html length])];
        
        if (videos.count > 0) {
            NSTextCheckingResult* checkingResult = nil;
            
            if (self.quality == LBYouTubeVideoQualityLarge) {
                checkingResult = [videos objectAtIndex:0];
            }
            else if (self.quality == LBYouTubeVideoQualityMedium) {
                unsigned int index = (unsigned int)MIN(videos.count-1, 1U);
                checkingResult= [videos objectAtIndex:index];
            }
            else {
                checkingResult = [videos lastObject];
            }
            
            NSMutableString* streamURL = [NSMutableString stringWithString: [html substringWithRange:checkingResult.range]];
            [streamURL replaceOccurrencesOfString:@"\\\\u0026" withString:@"&" options:NSCaseInsensitiveSearch range:NSMakeRange(0, streamURL.length)];
            [streamURL replaceOccurrencesOfString:@"\\\\\\" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, streamURL.length)];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                completion([NSURL URLWithString:streamURL], error);
            });
        } else {
            error = [NSError errorWithDomain:kLBYouTubePlayerExtractorErrorDomain code:2 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't find the stream URL." forKey:NSLocalizedDescriptionKey]];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                completion(nil, error);
            });
        }
        DLog(@"EXTRACTION TIME %.0f ms", (-[startTime timeIntervalSinceDate:[NSDate date]] * 1000));
    });
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

@end
