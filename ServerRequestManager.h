//
//  ServerRequestManager.h
//  tawk@Eaze
//
//  Created by Santosh Narawade on 28/12/15.
//  Copyright (c) 2015 Santosh Narawade. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVAssetExportSession.h>
#import <AVFoundation/AVMediaFormat.h>
#import <AVFoundation/AVAssetWriterInput.h>

typedef void (^DownloadCompletionBlock)(NSData *data, NSError *error);
typedef void (^DownloadProgressBlock)(int64_t downloaded);

@interface ServerRequestManager : NSObject

+ (instancetype)shared;
+ (NSURLRequest *)createPostRequestFor:(NSData *)data ofType:(NSString *)d_type;

- (void)stopDownloading;
- (void)downloadVideoWithURL:(NSURL *)url progress:(DownloadProgressBlock)downloadProgress complete:(DownloadCompletionBlock)downloadCompletion;

@end
