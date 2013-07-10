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

// Modified answer from StackOverflow http://stackoverflow.com/questions/2099349/using-objective-c-cocoa-to-unescape-unicode-characters-ie-u1234

static NSString *UnescapeString(NSString *string) {
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
    }
    return self;
}

-(id)initWithID:(NSString *)videoID quality:(LBYouTubeVideoQuality)videoQuality {
    return [self initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", videoID]] quality:videoQuality];
}

#pragma mark -
#pragma mark Other Methods

-(void)startExtracting {
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
    NSString* JSONStart = nil;
    NSString *JSONStartFull = @"bootstrap_data = \")]}'";
   
    NSString* JSONStartShrunk = [JSONStartFull stringByReplacingOccurrencesOfString:@" " withString:@""];
    if ([html rangeOfString:JSONStartFull].location != NSNotFound) {
        JSONStart = JSONStartFull;
    }
    else if ([html rangeOfString:JSONStartShrunk].location != NSNotFound) {
        JSONStart = JSONStartShrunk;
    }
    if (JSONStart != nil) {
        NSScanner* scanner = [NSScanner scannerWithString:html];
        [scanner scanUpToString:JSONStart intoString:nil];
        [scanner scanString:JSONStart intoString:nil];
        
        NSString* JSON = nil;
        [scanner scanUpToString:@"}\";" intoString:&JSON];
        JSON = [NSString stringWithFormat:@"%@}",JSON]; // Add closing bracket } to get vallid JSON again
        
        JSON = UnescapeString(JSON);
        NSError* decodingError = nil;
        NSDictionary* JSONCode = [NSJSONSerialization JSONObjectWithData:[JSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&decodingError];

        if (decodingError) {
            *error = decodingError;
        }
        else {
            NSArray* videos = [[[JSONCode objectForKey:@"content"] objectForKey:@"video"] objectForKey:@"fmt_stream_map"];
            NSString* streamURL = nil;
            if (videos.count) {
                NSString* streamURLKey = @"url";
                
                if (self.quality == LBYouTubeVideoQualityLarge) {
                    streamURL = [[videos objectAtIndex:0] objectForKey:streamURLKey];
                }
                else if (self.quality == LBYouTubeVideoQualityMedium) {
                    unsigned int index = MIN(videos.count-1, 1U);
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
                *error = [NSError errorWithDomain:kLBYouTubePlayerExtractorErrorDomain code:2 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't find the stream URL." forKey:NSLocalizedDescriptionKey]];
            }
        }
    }
    else {
        *error = [NSError errorWithDomain:kLBYouTubePlayerExtractorErrorDomain code:3 userInfo:[NSDictionary dictionaryWithObject:@"The JSON data could not be found." forKey:NSLocalizedDescriptionKey]];
    }
    
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
