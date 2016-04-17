//
//  ServerRequestManager.m
//  tawk@Eaze
//
//  Created by Santosh Narawade on 28/12/15.
//  Copyright (c) 2015 Santosh Narawade. All rights reserved.
//

#import "ServerRequestManager.h"

//#define serverURL @"http://192.168.0.6:8080/api/photo"//local
#define serverURL @"http://99.111.104.82:8080/api/photo"//Live

@interface ServerRequestManager ()

@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSURLSessionDownloadTask *getImageTask;

@property (copy) DownloadProgressBlock progressBlock;

@end

@implementation ServerRequestManager

+ (instancetype)shared
{
  static ServerRequestManager *serverRequestManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    serverRequestManager = [[self alloc] init];
  });
  return serverRequestManager;
}

#pragma mark - Uploading Methods

+ (NSData *)compressedImageSizeOf:(NSData *)orignalData
{
  UIImage *image = [UIImage imageWithData:orignalData];
  //  Determine output size
  CGFloat maxSize = 640.0f;
  CGFloat width = image.size.width;
  CGFloat height = image.size.height;
  CGFloat newWidth = width;
  CGFloat newHeight = height;
  
  //  If any side exceeds the maximun size, reduce the greater side to 1200px and proportionately the other one
  if (width > maxSize || height > maxSize) {
    if (width > height) {
      newWidth = maxSize;
      newHeight = (height*maxSize)/width;
    } else {
      newHeight = maxSize;
      newWidth = (width*maxSize)/height;
    }
  }
  
  //  Resize the image
  CGSize newSize = CGSizeMake(newWidth, newHeight);
  UIGraphicsBeginImageContext(newSize);
  [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
  UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  //  Set maximun compression in order to decrease file size and enable faster uploads & downloads
  NSData *imageData = UIImageJPEGRepresentation(newImage, 0.4f);
  return ((orignalData.length/1024) > 100.0f)?imageData:orignalData;
}

+ (NSURLRequest *)createPostRequestFor:(NSData *)data ofType:(NSString *)d_type{
  
  if ([d_type isEqualToString:@"image"])
    data = [ServerRequestManager compressedImageSizeOf:data];
  
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:serverURL]];
  
  NSString *extensionStr = ([d_type isEqualToString:@"image"])?@"jpg":
  ([d_type isEqualToString:@"video"])?@"mov":
  ([d_type isEqualToString:@"audio"])?@"wav":@"db";
  
  [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
  [request setHTTPShouldHandleCookies:NO];
  [request setTimeoutInterval:60];
  [request setHTTPMethod:@"POST"];
  
  NSString *boundary = @"unique-consistent-string";
  
  // set Content-Type in HTTP header
  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
  [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
  
  // post body
  NSMutableData *body = [NSMutableData data];
  
  // add params (all params are strings)
  [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=%@\r\n\r\n", @"imageCaption"] dataUsingEncoding:NSUTF8StringEncoding]];
  [body appendData:[[NSString stringWithFormat:@"%@\r\n", @"Some Caption"] dataUsingEncoding:NSUTF8StringEncoding]];
  
  // add image data
  if (data) {
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=%@; filename=talk.%@\r\n", @"userPhoto",extensionStr] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:data];
    [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
  }
  
  [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  
  // setting the body of the post to the reqeust
  [request setHTTPBody:body];
  
  // set the content-length
  NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
  [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
  
  return request;
}

#pragma mark - Downloading Methods

- (void)stopDownloading
{
  [_getImageTask cancel];
}

- (void)downloadVideoWithURL:(NSURL *)url progress:(DownloadProgressBlock)downloadProgress complete:(DownloadCompletionBlock)downloadCompletion{
  
  _progressBlock = downloadProgress;
  
  NSURLSessionConfiguration *sessionConfig =
  [NSURLSessionConfiguration defaultSessionConfiguration];
  sessionConfig.timeoutIntervalForRequest = 30.0;
  sessionConfig.timeoutIntervalForResource = 360.0;
  _session =[NSURLSession sessionWithConfiguration:sessionConfig
                                          delegate:nil
                                     delegateQueue:nil];
  
  _getImageTask = [_session downloadTaskWithURL:url
                              completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error)
                   {
                     [self stopListening];
                     NSData *videoData = [NSData dataWithContentsOfURL:location];
                     if (downloadCompletion) {
                       downloadCompletion(videoData, error);
                     }
                   }];
  
  [self listenForProgress];
  [_getImageTask resume];
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isDownloading"];
}

- (void)listenForProgress
{
  [_getImageTask addObserver:self forKeyPath:@"countOfBytesReceived" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:@"countOfBytesReceived"])
  {
    NSNumber *downloaded = change[@"new"];
    if (_progressBlock) {
      _progressBlock(downloaded.longLongValue);
    }
  }
}

- (void)stopListening
{
  [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"isDownloading"];
  [_getImageTask removeObserver:self forKeyPath:@"countOfBytesReceived"];
}

@end
