//
//  LBYouTubeExtractor.m
//  LBYouTubeView
//
//  Created by Laurin Brandner on 28.09.12.
//
//

#import "LBYouTubeExtractor.h"
#import <JavaScriptCore/JavaScriptCore.h>

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
        //self.extractionExpression = @"(?!\\\\\")http[^\"]*?itag=[^\"]*?(?=\\\\\")";
        self.extractionExpression = @"(\\\\\")http[^\"]*?itag=[^\"]*?(\\\\\")"; //Expresion regular para buscar en el HTML (\\\")http[^\"]*?itag=[^\"]*?(\\\")
//        self.extractionExpression = @"http[^\"]*?itag=[^\"]*?";
		self.signatureExtractionExpression = @"(\\\\\\\"sig\\\\\\\": \\\\\\\"[^\"]+\\\\\")";
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
    NSDate *start = [NSDate date];
    NSArray* videos = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
	NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:start];
    NSLog(@"Time used to get videos : %f", interval);
    
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
        [streamURL replaceOccurrencesOfString:@"\\\"" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, streamURL.length)];
        [streamURL replaceOccurrencesOfString:@"\\\\u0026" withString:@"&" options:NSCaseInsensitiveSearch range:NSMakeRange(0, streamURL.length)];
        [streamURL replaceOccurrencesOfString:@"\\\\\\" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, streamURL.length)];
		
        // Check the signature:
		if ([sigs count] > 0) {
			sigCheckingResult = [sigs objectAtIndex:index];
            NSString* encrSyg = [string substringWithRange:sigCheckingResult.range];
            
            sig_regex = [[NSRegularExpression alloc] initWithPattern:@"(?<=sig\\\\\": \\\\\")[^\"]*?(?=\\\\\")" options:NSRegularExpressionCaseInsensitive error:nil];
            sigCheckingResult = [sig_regex firstMatchInString:encrSyg options:0 range:NSMakeRange(0, encrSyg.length)];
            
            encrSyg = [encrSyg substringWithRange:sigCheckingResult.range];
            
            NSString* sig = nil;
            
            //Get the javascript function used to decode the encoded key!
            NSRegularExpression * regexp = [[NSRegularExpression alloc] initWithPattern:@"signature=([a-zA-Z]+)" options:NSRegularExpressionCaseInsensitive error:error];
            NSRange signature_range = [regexp rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
            
            //If we have a function name refrence, continue trying to pass
            if(signature_range.location != NSNotFound)
            {
                NSString * signature_functionName = [string substringWithRange:NSMakeRange(signature_range.location+10, signature_range.length-10)];
                
                //We need to extrach the javascript part of the HTML document contaning the function.
                NSMutableString* jsCode = [self loadNeededJSFunctions:signature_functionName andContentFile:string andSearchDepth:1];
                
                if(jsCode)
                {
                    JSContext *context = [[JSContext alloc] init];
                    
                    [context evaluateScript:jsCode];
                    
                    JSValue * func = context[signature_functionName];
                    NSArray * args = @[encrSyg];
                    JSValue * ret =[func callWithArguments:args];
                    
                    if([ret isString])
                        sig = [ret toString];
                }
            }

            //if we are unable to grap the json, fall back to static decrypt algo.
            if(!sig){
                NSLog(@"Unable to get decoded key from JSon, falling back to static method");
                sig = [self decryptSignature:encrSyg];
            }
            
			[streamURL appendString:[@"&signature=" stringByAppendingString:sig]];
		}
                
        return [NSURL URLWithString:streamURL];
    }
    
    *error = [NSError errorWithDomain:kLBYouTubePlayerExtractorErrorDomain code:2 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't find the stream URL." forKey:NSLocalizedDescriptionKey]];
    
    return nil;
}

-(NSString *)decryptSignature:(NSString *)signature
{
    NSString * dectyptedString = [self _static_decrypt_signature:signature];
    
    if(dectyptedString){
        return dectyptedString;
    }
    else{
        NSLog(@"Failed to staticly pass the string!");
        return signature;
    }
}

-(NSMutableString *)loadNeededJSFunctions:(NSString *)functionName andContentFile:(NSString *)content andSearchDepth:(int)depth
{
    if(depth > 10)
        return [NSMutableString new];
    
    NSMutableString * jsFunction = [NSMutableString new];
    
    NSRegularExpression* regexp = [[NSRegularExpression alloc] initWithPattern:[NSString stringWithFormat:@"function %@\\(([a-z,]+)\\)\\{([^}]+)\\}", functionName] options:0 error:nil];
    
    NSRange function_range = [regexp rangeOfFirstMatchInString:content options:0 range:NSMakeRange(0, [content length])];
    
    DLog(@"RANGE LOCATION:%d LENGTH: %d", function_range.location, function_range.length);
    
    if(function_range.length != NSNotFound && function_range.length > 0)
    {
        DLog(@"RANGE LOCATION:%d LENGTH: %d", function_range.location, function_range.length);
        
        //We have the function, read it out and check if we need to do recursive call
        jsFunction = [NSMutableString stringWithString:[content substringWithRange:function_range]];
        
        regexp = [[NSRegularExpression alloc] initWithPattern:@"(?<==)[a-zA-z]+(?=\\([0-9a-z,]+\\))" options:NSRegularExpressionCaseInsensitive error:nil];
        
        NSArray *functionCalls = [regexp matchesInString:jsFunction options:0 range:NSMakeRange(0, jsFunction.length)];
        
        if(functionCalls.count > 0)
        {
            //NSLog(@"loadNeededJSFunctions : Number of sub functions = %d", functionCalls.count);
            NSMutableArray *functionNames = [NSMutableArray new];
            for (NSTextCheckingResult* func in functionCalls) {
                NSString * name = [jsFunction substringWithRange:func.range];
                if([functionNames indexOfObject:name] == NSNotFound)
                {
                    [functionNames addObject:name];
                }
            }
            
            for (NSString* func in functionNames)
            {
                [jsFunction appendString:@"\n"];
                
                [jsFunction appendString:[self loadNeededJSFunctions:func andContentFile:content andSearchDepth:depth++]];
            }
            return jsFunction;
        }
        else
            return jsFunction;
    }
    
    NSLog(@"Warning : Unable to extract JS function....");
    return [NSMutableString new];
}



-(NSString *)_static_decrypt_signature:(NSString *)signature{
    //    if age_gate{
    //        # The videos with age protection use another player, so the
    //        # algorithms can be different.
    //        if len(s) == 86:
    //            return s[2:63] + s[82] + s[64:82] + s[63]
    //    }
    NSLog(@"length %d", signature.length);
    
    switch (signature.length) {
        case 93:
        {
            return [NSString stringWithFormat:@"%@%@%@",
                    [self stringRange:signature andStart:86 andStop:29],
                    [self stringRange:signature charAtIndex:88],
                    [self stringRange:signature andStart:28 andStop:5]];
            //return s[86:29:-1] + s[88] + s[28:5:-1]
        }
            break;
        case 92:
        {
            return [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@",
                    [self stringRange:signature charAtIndex:25],
                    [self stringRange:signature andStart:3 andStop:25],
                    [self stringRange:signature charAtIndex:0],
                    [self stringRange:signature andStart:26 andStop:42],
                    [self stringRange:signature charAtIndex:79],
                    [self stringRange:signature andStart:43 andStop:79],
                    [self stringRange:signature charAtIndex:91],
                    [self stringRange:signature andStart:80 andStop:83]];
        }
            //return s[25] + s[3:25] + s[0] + s[26:42] + s[79] + s[43:79] + s[91] + s[80:83];
            break;
        case 91:
        {
            return [NSString stringWithFormat:@"%@%@%@",
                    [self stringRange:signature andStart:84 andStop:27],
                    [self stringRange:signature charAtIndex:86],
                    [self stringRange:signature andStart:26 andStop:5]];
        }
            //return s[84:27:-1] + s[86] + s[26:5:-1]
            break;
        case 90:
            return [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@",
                    [self stringRange:signature charAtIndex:25],
                    [self stringRange:signature andStart:3 andStop:25],
                    [self stringRange:signature charAtIndex:2],
                    [self stringRange:signature andStart:26 andStop:40],
                    [self stringRange:signature charAtIndex:77],
                    [self stringRange:signature andStart:41 andStop:77],
                    [self stringRange:signature charAtIndex:89],
                    [self stringRange:signature andStart:78 andStop:81]];
            
            //return s[25] + s[3:25] + s[2] + s[26:40] + s[77] + s[41:77] + s[89] + s[78:81]
            break;
        case 89:
            return [NSString stringWithFormat:@"%@%@%@%@%@",
                    [self stringRange:signature andStart:84 andStop:78],
                    [self stringRange:signature charAtIndex:87],
                    [self stringRange:signature andStart:77 andStop:60],
                    [self stringRange:signature charAtIndex:0],
                    [self stringRange:signature andStart:59 andStop:3]];
            //return s[84:78:-1] + s[87] + s[77:60:-1] + s[0] + s[59:3:-1]
            break;
        case 88:
            return [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@",
                    [self stringRange:signature andStart:7 andStop:28],
                    [self stringRange:signature charAtIndex:87],
                    [self stringRange:signature andStart:29 andStop:45],
                    [self stringRange:signature charAtIndex:55],
                    [self stringRange:signature andStart:46 andStop:55],
                    [self stringRange:signature charAtIndex:2],
                    [self stringRange:signature andStart:56 andStop:87],
                    [self stringRange:signature charAtIndex:28]];
            //return s[7:28] + s[87] + s[29:45] + s[55] + s[46:55] + s[2] + s[56:87] + s[28]
            break;
        case  87:
            return [NSString stringWithFormat:@"%@%@%@%@%@%@%@",
                    [self stringRange:signature andStart:6 andStop:27],
                    [self stringRange:signature charAtIndex:4],
                    [self stringRange:signature andStart:28 andStop:39],
                    [self stringRange:signature charAtIndex:27],
                    [self stringRange:signature andStart:40 andStop:59],
                    [self stringRange:signature charAtIndex:2],
                    [self stringRange:signature andStart:60 andStop:87]];
            //return s[6:27] + s[4] + s[28:39] + s[27] + s[40:59] + s[2] + s[60:]
            break;
        case  86:
            return [NSString stringWithFormat:@"%@%@%@%@%@%@%@",
                    [self stringRange:signature andStart:80 andStop:72],
                    [self stringRange:signature charAtIndex:16],
                    [self stringRange:signature andStart:71 andStop:39],
                    [self stringRange:signature charAtIndex:72],
                    [self stringRange:signature andStart:38 andStop:16],
                    [self stringRange:signature charAtIndex:82],
                    [self stringRange:signature andStart:15 andStop:-1]];
            //return s[80:72:-1] + s[16] + s[71:39:-1] + s[72] + s[38:16:-1] + s[82] + s[15::-1]
            break;
        case  85:
            return [NSString stringWithFormat:@"%@%@%@%@%@",
                    [self stringRange:signature andStart:3 andStop:11],
                    [self stringRange:signature charAtIndex:0],
                    [self stringRange:signature andStart:12 andStop:55],
                    [self stringRange:signature charAtIndex:84],
                    [self stringRange:signature andStart:56 andStop:84]];
            //return s[3:11] + s[0] + s[12:55] + s[84] + s[56:84]
            break;
        case  84:
            return [NSString stringWithFormat:@"%@%@%@%@%@%@%@",
                    [self stringRange:signature andStart:78 andStop:70],
                    [self stringRange:signature charAtIndex:14],
                    [self stringRange:signature andStart:69 andStop:37],
                    [self stringRange:signature charAtIndex:70],
                    [self stringRange:signature andStart:36 andStop:14],
                    [self stringRange:signature charAtIndex:80],
                    [self stringRange:signature andStart:13 andStop:-1]];
            //return s[78:70:-1] + s[14] + s[69:37:-1] + s[70] + s[36:14:-1] + s[80] + s[:14][::-1]
            break;
        case  83:
        {
            return [NSString stringWithFormat:@"%@%@%@%@",
                    [self stringRange:signature andStart:80 andStop:63],
                    [self stringRange:signature charAtIndex:0],
                    [self stringRange:signature andStart:62 andStop:0],
                    [self stringRange:signature charAtIndex:63]];
            //return s[80:63:-1] + s[0] + s[62:0:-1] + s[63]
        }
            break;
        case  82:
            return [NSString stringWithFormat:@"%@%@%@%@",
                    [self stringRange:signature charAtIndex:12],
                    [self stringRange:signature andStart:79 andStop:12],
                    [self stringRange:signature charAtIndex:80],
                    [self stringRange:signature andStart:11 andStop:-1]];
            //return s[12] + s[79:12:-1] + s[80] + s[11::-1]
            break;
        case  81:
            return [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@%@%@%@%@%@",
                    [self stringRange:signature charAtIndex:56],
                    [self stringRange:signature andStart:79 andStop:56],
                    [self stringRange:signature charAtIndex:41],
                    [self stringRange:signature andStart:55 andStop:41],
                    [self stringRange:signature charAtIndex:80],
                    [self stringRange:signature andStart:40 andStop:34],
                    [self stringRange:signature charAtIndex:0],
                    [self stringRange:signature andStart:33 andStop:29],
                    [self stringRange:signature charAtIndex:34],
                    [self stringRange:signature andStart:28 andStop:9],
                    [self stringRange:signature charAtIndex:29],
                    [self stringRange:signature andStart:8 andStop:0],
                    [self stringRange:signature charAtIndex:9]];
            //return s[56] + s[79:56:-1] + s[41] + s[55:41:-1] + s[80] + s[40:34:-1] + s[0] + s[33:29:-1] + s[34] + s[28:9:-1] + s[29] + s[8:0:-1] + s[9]
            break;
        case  80:
            return [NSString stringWithFormat:@"%@%@%@%@%@",
                    [self stringRange:signature andStart:1 andStop:19],
                    [self stringRange:signature charAtIndex:0],
                    [self stringRange:signature andStart:20 andStop:68],
                    [self stringRange:signature charAtIndex:19],
                    [self stringRange:signature andStart:69 andStop:80]];
            //return s[1:19] + s[0] + s[20:68] + s[19] + s[69:80]
            break;
        case  79:
            return [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@%@%@%@%@%@",
                    [self stringRange:signature charAtIndex:54],
                    [self stringRange:signature andStart:77 andStop:54],
                    [self stringRange:signature charAtIndex:39],
                    [self stringRange:signature andStart:53 andStop:39],
                    [self stringRange:signature charAtIndex:78],
                    [self stringRange:signature andStart:38 andStop:34],
                    [self stringRange:signature charAtIndex:0],
                    [self stringRange:signature andStart:33 andStop:29],
                    [self stringRange:signature charAtIndex:34],
                    [self stringRange:signature andStart:28 andStop:9],
                    [self stringRange:signature charAtIndex:29],
                    [self stringRange:signature andStart:8 andStop:0],
                    [self stringRange:signature charAtIndex:9]];
            //return s[54] + s[77:54:-1] + s[39] + s[53:39:-1] + s[78] + s[38:34:-1] + s[0] + s[33:29:-1] + s[34] + s[28:9:-1] + s[29] + s[8:0:-1] + s[9]
            break;
            
        default:
            return nil;
            break;
    }
    
}

-(NSString *) stringRange:(NSString *)string andStart:(int)start andStop:(int)stop
{
    if(stop < start)
    {
        NSMutableString *rtr = [NSMutableString new];
        //        unichar buf[1];
        
        if(start <= string.length && stop >= -1)
        {
            while (start > stop) {
                unichar uch = [string characterAtIndex:start--];
                [rtr appendString:[NSString stringWithCharacters:&uch length:1]];
            }
            
            return rtr;
        }
        return [NSString new];
        
    }
    else if(start < string.length && stop <= string.length && stop > start)
    {
        NSMutableString *rtr=[NSMutableString stringWithCapacity:stop-start];
        
        while (start < stop) {
            unichar uch = [string characterAtIndex:start++];
            [rtr appendString:[NSString stringWithCharacters:&uch length:1]];
        }
        return rtr;
    }
    
    return [NSString new];
}

-(NSString *) stringRange:(NSString *)string charAtIndex:(int)index
{
    //NSMutableString *rtr=[NSMutableString new];
    //        unichar buf[1];
    if(index < string.length)
    {
        unichar uch = [string characterAtIndex:index];
        return [NSString stringWithCharacters:&uch length:1];
    }
    return [NSString new];
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
