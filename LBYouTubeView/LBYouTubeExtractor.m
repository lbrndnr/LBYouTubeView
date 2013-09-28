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

static NSString* algoJson = @"[80, 79, 78, 77, 76, 75, 74, 73, 72, 71, 70, 69, 68, 67, 66, 65, 64, 0, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 63]";

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
		self.signatureExtractionExpression = @"(?<=sig\\\\\": \\\\\")[^\"]*?(?=\\\\\")";
		self.signAlgo = [NSJSONSerialization JSONObjectWithData:[algoJson dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
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
	NSRegularExpression* sig_regex = [[NSRegularExpression alloc] initWithPattern:self.signatureExtractionExpression options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray* videos = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
	NSArray* sigs = [sig_regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
    
    if (videos.count > 0) {
        NSTextCheckingResult* checkingResult = nil;
		NSTextCheckingResult* sigCheckingResult = nil;
		unsigned int index = 0;
        
        if (self.quality == LBYouTubeVideoQualityLarge) {
            index = 0;
        }
        else if (self.quality == LBYouTubeVideoQualityMedium) {
             index = MIN(videos.count-1, 1U);
        }
        else {
			index = [videos count] - 1;
        }
		checkingResult = [videos objectAtIndex:index];
		
        
        NSMutableString* streamURL = [NSMutableString stringWithString: [string substringWithRange:checkingResult.range]];
        [streamURL replaceOccurrencesOfString:@"\\\\u0026" withString:@"&" options:NSCaseInsensitiveSearch range:NSMakeRange(0, streamURL.length)];
        [streamURL replaceOccurrencesOfString:@"\\\\\\" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, streamURL.length)];

		// Check the signature:
		if ([sigs count] > 0) {
			sigCheckingResult = [sigs objectAtIndex:index];
			NSString* encrSyg = [string substringWithRange:sigCheckingResult.range];
			NSString* sig = [self decryptSignature:encrSyg];
			[streamURL appendString:[@"&signature=" stringByAppendingString:sig]];
		}
                
        return [NSURL URLWithString:streamURL];
    }
    
    *error = [NSError errorWithDomain:kLBYouTubePlayerExtractorErrorDomain code:2 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't find the stream URL." forKey:NSLocalizedDescriptionKey]];
    
    return nil;
}

-(NSString *)decryptSignature:(NSString *)signature
{
	NSMutableString* res = [NSMutableString string];
	for (int i=0; i<[self.signAlgo count]; i++) {
		NSNumber* index = [self.signAlgo objectAtIndex:i];
		NSRange range = {[index integerValue], 1};
		[res insertString:[signature substringWithRange:range] atIndex:i];
	}
	return [NSString stringWithString:res];
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
