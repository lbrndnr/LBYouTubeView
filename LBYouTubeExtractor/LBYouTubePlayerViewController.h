//
//  LBYouTubeExtractor.h
//  LBYouTubeView
//
//  Created by Marco Muccinelli on 11/06/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString const *     LBYouTubeExtractorErrorDomain;
extern NSInteger const      LBYouTubeExtractorErrorCodeInvalidHTML;
extern NSInteger const      LBYouTubeExtractorErrorCodeNoStreamURL;
extern NSInteger const      LBYouTubeExtractorErrorCodeNoJSONData;

@interface LBYouTubeExtractor : NSObject
/**
 Original YouTube URL requested for extraction.
 */
@property (nonatomic, strong) NSURL *youTubeURL;
/**
 Extract high quality video URL
 
 Default is `NO`.
 */
@property (nonatomic) BOOL highQuality;
/**
 Extracted URL
 */
@property (nonatomic, strong, readonly) NSURL *extractedURL;
/**
 Handler called when extraction finishes.
 
 If extraction fails, `extractedURL` is `nil`.
 */
@property (nonatomic, copy) void (^completionHandler)(NSURL *extractedURL, NSError *error);
@end


@interface LBYouTubeExtractor (Extraction)
/**
 Check extraction status.
 
 @return `YES` if extraction is in progress.
 */
- (BOOL)isRunning;
/**
 Start extraction.
 
 It checks against isRunning before to start connection.
 */
- (void)start;
/**
 Cancel extraction.
 */
- (void)cancel;
@end


@interface LBYouTubeExtractor (Callbacks)
/**
 Callback for success.
 
 It invokes completionHandler.
 */
- (void)didFinishExtractingURL:(NSURL *)extractedURL;
/**
 Callback for failure.
 
 It invokes completionHandler.
 */
- (void)didFailExtractingURLWithError:(NSError *)error;
@end
