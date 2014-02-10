//
//  KCSNSURLSessionFileOperation.m
//  KinveyKit
//
//  Created by Michael Katz on 9/24/13.
//  Copyright (c) 2013-2014 Kinvey. All rights reserved.
//
// This software is licensed to you under the Kinvey terms of service located at
// http://www.kinvey.com/terms-of-use. By downloading, accessing and/or using this
// software, you hereby accept such terms of service  (and any agreement referenced
// therein) and agree that you have read, understand and agree to be bound by such
// terms of service and are of legal age to agree to such terms with Kinvey.
//
// This software contains valuable confidential and proprietary information of
// KINVEY, INC and is subject to applicable licensing agreements.
// Unauthorized reproduction, transmission or distribution of this file and its
// contents is a violation of applicable laws.
//

#import "KCSNSURLSessionFileOperation.h"

#import "KinveyCoreInternal.h"
#import "KinveyDataStoreInternal.h"

@interface KCSNSURLSessionFileOperation () <NSURLSessionDelegate, NSURLSessionDownloadDelegate, NSURLSessionTaskDelegate>
@property (nonatomic, retain) NSURL* localFile;
@property (nonatomic, retain) NSURLSession* session;
@property (nonatomic, retain) NSURLSessionTask* task;
@property (nonatomic, strong) NSMutableURLRequest* request;
@property (nonatomic, strong) NSError* error;
@property (nonatomic, strong) NSDictionary* returnVals;
@property (nonatomic) BOOL done;
@property (nonatomic, strong) id context;
@property (nonatomic) BOOL isUpload;
@end

@implementation KCSNSURLSessionFileOperation

- (instancetype) initWithRequest:(NSMutableURLRequest*)request output:(NSURL*)fileHandle  context:(id)context
{
    self = [super init];
    if (self) {
        _request = request;
        _localFile = fileHandle;
        _bytesWritten = 0;
        _context = context;
        
    }
    return self;
}


-(void)start {
    if (self.isCancelled == YES) {
        return;
    }
    
    @autoreleasepool {
        [super start];

        NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        
        if (_localFile) {
            NSData* resumeData = nil;
            NSNumber* alreadyWritten = (NSNumber*)self.context;
            if (alreadyWritten != nil) {
                resumeData = [NSData dataWithContentsOfURL:self.localFile];
                //TODO: figure this one out
                //        unsigned long long written = [_outputHandle seekToEndOfFile];
                unsigned long long written = [alreadyWritten unsignedLongLongValue];
                if ([alreadyWritten unsignedLongLongValue] == written) {
                    KCSLogInfo(KCS_LOG_CONTEXT_NETWORK, @"Download was already in progress. Resuming from byte %@.", alreadyWritten);
                    //                [request addValue:[NSString stringWithFormat:@"bytes=%llu-", written] forHTTPHeaderField:@"Range"];
                    //        } else {
                    //            //if they don't match start from begining
                    //            [_outputHandle seekToFileOffset:0];
                }
            }
            
            
            
            if (resumeData == nil) {
                _task = [_session downloadTaskWithRequest:_request];
            } else {
                _task = [_session downloadTaskWithResumeData:resumeData];
            }
        } else {
            _isUpload = YES;
            
            _task = [_session uploadTaskWithStreamedRequest:_request];
        }
        
        [_task resume];
    }
}

- (void)setFinished:(BOOL)isFinished
{
    [self willChangeValueForKey:@"isFinished"];
    _done = isFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isFinished
{
    return ([self isCancelled] ? YES : _done);
}

- (BOOL)isExecuting
{
    return YES;//![self isFinished];
}

- (void)cancel
{
    if (!_isUpload) {
        [(NSURLSessionDownloadTask*)self.task cancelByProducingResumeData:^(NSData *resumeData) {
            self.resumeData = resumeData;
            [super cancel];
        }];
    }
}

- (BOOL)isReady
{
    return YES;
}

- (void) complete:(NSError*)error
{
    //TODO: figure this out vvv
//    if (_response && _response.statusCode >= 400) {
//        //is an error just get the data locally
//        //TODO: handle this!!  [_responseData appendData:data];
//    }
// resume data
    if (error) {
        NSData* resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
        [KCSFileUtils writeData:resumeData toURL:self.localFile];
    }
    
    
    NSMutableDictionary* results = [NSMutableDictionary dictionary];
    setIfValNotNil(results[KCSFileMimeType], [self contentType]);
    setIfValNotNil(results[kBytesWritten], @(_bytesWritten));
    self.returnVals = [results copy];
    //SET finished _completionBlock(NO, returnVals, error);
    
    self.finished = YES;
}

#pragma mark - info

- (NSString*) contentType
{
    return self.request.allHTTPHeaderFields[kHeaderContentType];
}

#pragma mark - delegate methods

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    [self complete:error];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        self.error = error;
    }
    [self complete:self.error];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSInteger responseCode = [(NSHTTPURLResponse*)downloadTask.response statusCode];
    NSError* error = nil;
    
    if (responseCode >= 400) {
        NSString* errorStr = [NSString stringWithContentsOfURL:location encoding:NSUTF8StringEncoding error:&error];
        ifNil(errorStr, @"");
        NSDictionary* userInfo = @{NSLocalizedDescriptionKey : @"Download from GCS Failed",
                                   NSLocalizedFailureReasonErrorKey : errorStr,
                                   NSURLErrorFailingURLErrorKey : self.request.URL};
        if (error) {
            userInfo = [userInfo dictionaryByAddingDictionary:@{NSUnderlyingErrorKey : error}];
        }
        error = [NSError createKCSError:KCSFileStoreErrorDomain
                                   code:responseCode
                               userInfo:userInfo];
        self.error = error;
    } else {
        error = [KCSFileUtils moveFile:location to:self.localFile];
        if (error) {
            self.error = error;
        }
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NSInteger responseCode = [(NSHTTPURLResponse*)downloadTask.response statusCode];    
    if (responseCode < 400) {
        KCSLogDebug(KCS_LOG_CONTEXT_NETWORK, @"downloaded %lld bytes from file service", bytesWritten);
        
        _bytesWritten += bytesWritten;
        if (self.progressBlock) {
            //            NSUInteger downloadedAmount = [_outputHandle offsetInFile];
            //                    _intermediateFile.length = downloadedAmount;
            //
            double progress = (double)totalBytesWritten / (double) totalBytesExpectedToWrite;
            //#warning fix this, please
            self.progressBlock(@[], progress, @{});
        }
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    //TODO: do something here
}

#pragma mark - upload

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *))completionHandler
{
    completionHandler(_request.HTTPBodyStream);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    if (!_isUpload) {
        return;
    }
    
    KCSLogDebug(KCS_LOG_CONTEXT_NETWORK, @"Uploaded %llu bytes (%ld / %ld)", bytesSent, (long)totalBytesSent, (long)totalBytesExpectedToSend);
    
    double progress = (double) totalBytesSent / (double) totalBytesExpectedToSend;
    if (_progressBlock) {
        _progressBlock(nil, progress, @{});
    }

}

@end
