//
//  KCSAsyncConnection2.m
//  KinveyKit
//
//  Created by Michael Katz on 5/23/13.
//  Copyright (c) 2013 Kinvey. All rights reserved.
//

#import "KCSAsyncConnection2.h"

//TODO check these --
#import "KCSAsyncConnection.h"
//--

#import "KCSConnectionResponse.h"
#import "KCSConnectionProgress.h"
#import "KCSErrorUtilities.h"
#import "KinveyErrorCodes.h"
#import "KCSLogManager.h"
#import "KCSClient.h"

#import "NSDictionary+KinveyAdditions.h"


#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

@interface KCSAsyncConnection2()
{
#if TARGET_OS_IPHONE
    UIBackgroundTaskIdentifier _bgTask;
#endif
    RunBlock_t _blockToRun;
}

@property (copy) KCSConnectionCompletionBlock completionBlock;
@property (copy) KCSConnectionFailureBlock    failureBlock;
@property (copy) KCSConnectionProgressBlock   progressBlock;
@property (nonatomic, strong) NSMutableData *downloadedData;
@property (strong) NSURLConnection *connection;
@property (nonatomic, readwrite) NSInteger contentLength;
@property double lastPercentage;
@property (nonatomic) BOOL followRedirects;
@end

@implementation KCSAsyncConnection2


/* NOTES:
 
 Lifecycle:
 KCSConnections are designed to be reusable and to live in a connection pool, this means
 that the normal lifecycle of alloc -> release isn't followed, but there will be multiple
 uses for each connection (assumed), so the following is the expected life cycle
 1. Alloc/init
 ...
 2. [self performRequest]
 3. NSURLConnection Delegate Sequence
 4. ConnectionDidFinishLoading/ConnectionDidFail
 5. cleanUp
 ...
 6. dealloc
 
 Where 2 through 5 are called repeatedly.
 
 Step 5 needs to pay close attention to any copy parameters, otherwise calling the setter for the member and
 assinging to nil should free the memory.
 
 */


#pragma mark - Constructors
- (instancetype)initWithConnection:(NSURLConnection *)theConnection
{
    self = [self init]; // Note that in the test environment we don't need credentials
    if (self){
        self.connection = theConnection; // Otherwise this value is nil...
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self){
        _downloadedData = nil;
        _lastResponse = nil;
        _request = nil;
        _connection = nil;
        _percentNotificationThreshold = .01; // Default to 1%
        _lastPercentage = 0; // Start @ 0%
        self.followRedirects = YES;
        _blockToRun = nil;
    }
    return self;
}

#pragma mark -
#pragma mark Setters/Getters

// Getter for percentComplete
- (double)percentComplete
{
    if (self.contentLength <= 0){
        return 0;
    } else {
        return (([self.downloadedData length] * 1.0) / self.contentLength);
    }
    
}

#pragma mark -
#pragma mark Primary Interface

- (void)performRequest:(NSURLRequest *)theRequest
         progressBlock:(KCSConnectionProgressBlock)onProgress
       completionBlock:(KCSConnectionCompletionBlock)onCompletion
          failureBlock:(KCSConnectionFailureBlock)onFailure
{
    self.request = theRequest;
    self.progressBlock = onProgress;
    self.failureBlock = onFailure;
    self.completionBlock = onCompletion;
    
    KCSLogNetwork(@"Request URL:%@", self.request.URL);
    KCSLogNetwork(@"Request Method:%@", self.request.HTTPMethod);
    KCSLogNetwork(@"Request Headers:%@", [self.request.allHTTPHeaderFields stripKeys:@[@"Authorization"]]);
    
    
    // If our connection has been cleaned up, then we need to make sure that we get it back before using it.
    if (self.connection == nil){ //TODO: use piplining"
        self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];  // Retained due to accessor
    } else {
        // This method only starts the connection if it's not been started, if we somehow end up here
        // without a started connection... well... we need to start it.
        [self.connection start];
    }
    
    if (self.connection) {
        // Create the NSMutableData to hold the received data.
        // receivedData is an instance variable declared elsewhere.
        // This is released by the cleanup method called when the connection completes or fails
        self.downloadedData = [NSMutableData data];
    } else {
        KCSLogNetwork(@"KCSConnection: Connection unabled to be created.");
        NSDictionary *userInfo = [KCSErrorUtilities createErrorUserDictionaryWithDescription:@"Unable to create network connection.s"
                                                                           withFailureReason:@"connectionWithRequest:delegate: returned nil connection."
                                                                      withRecoverySuggestion:@"Retry request."
                                                                         withRecoveryOptions:nil];
        
        NSError *error = [NSError errorWithDomain:KCSNetworkErrorDomain
                                             code:KCSUnderlyingNetworkConnectionCreationFailureError
                                         userInfo:userInfo];
        self.failureBlock(error);
    }
    
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
#endif
}

- (void)cleanUp
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Cause all members to release their current object and reset to the nil state.
    
    _request = nil;
    _connection = nil;
    _lastResponse = nil;
    _downloadedData = nil;
    _progressBlock = NULL;
    _completionBlock = NULL;
    _failureBlock = NULL;
    
    self.lastPercentage = 0; // Reset
}

#pragma mark -
#pragma mark Download support (NSURLConnectionDelegate)

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    return YES;
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    KCSLogTrace(@"connection:didCancelAuthenticationChallenge:");
    KCSLogError(@"*** This is very unexpected and a serious error, please contact support@kinvey.com (%@)", challenge);
}


- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
    // Right now this might need to be implemented to support Ivan's Stuff
    return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Update downloaded data with new data
    [self.downloadedData appendData:data];
    
    
    // Update download percent and call the progress block
    double downloadPercent = self.percentComplete;
    // TODO: Need to check percent complete threshold...
    if (self.progressBlock != NULL && [(NSHTTPURLResponse *)self.lastResponse statusCode] < 300 &&
        ((self.lastPercentage + self.percentNotificationThreshold) <= downloadPercent)){
        // Probably want to handle this differently, since now the caller needs to know what's going
        // on, but I think that at a minimum, we need progress + data.
        self.lastPercentage = downloadPercent; // Update to the current value
        KCSConnectionProgress* progress = [[KCSConnectionProgress alloc] init];
        progress.percentComplete = downloadPercent;
        progress.data = data;
        self.progressBlock(progress);
    }
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    double downloadPercent = totalBytesWritten / (double) totalBytesExpectedToWrite;
    if (self.progressBlock != NULL &&
        ((self.lastPercentage + self.percentNotificationThreshold) <= downloadPercent)){
        self.lastPercentage = downloadPercent; // Update to the current value
        KCSConnectionProgress* progress = [[KCSConnectionProgress alloc] init];
        //min the percent in the case where the command is sometimes sent twice (automatically)
        progress.percentComplete = MIN(downloadPercent, 1.0);
        self.progressBlock(progress);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // Need to set content lenght field and lastResponse fields...
    self.lastResponse = response; // This properly updates our last response
    
    // All connections are HTTP connections, so a valid response is HTTP
    NSDictionary *header = [(NSHTTPURLResponse *)response allHeaderFields];
    NSString *contentLengthString = [header valueForKey:@"Content-Length"];
    
    // This means we have a valid content-length
    if (contentLengthString != nil){
        self.contentLength = [contentLengthString integerValue];
    } else {
        self.contentLength = -1;
    }
}

#if TARGET_OS_IPHONE

- (void) runBlockInForeground:(RunBlock_t)block
{
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        block();
    } else {
        _blockToRun = [block copy];
    }
}

#else

- (void) runBlockInForeground:(RunBlock_t)block
{
    block();
}

#endif

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self invalidateBgTask]; //TODO: combine
    
    [self runBlockInForeground:^{
        KCSLogError(@"Connection failed! Error - %@ %@",
                    [error localizedDescription],
                    [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
        
        NSError* error2 = [KCSErrorUtilities createError:@{} description:[error localizedDescription] errorCode:[error code] domain:KCSNetworkErrorDomain requestId:nil sourceError:error];
        
        // Notify client that the operation failed!
        self.failureBlock(error2);
        
        [self cleanUp];
    }];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self invalidateBgTask];
    
    [self runBlockInForeground:^{
        NSInteger statusCode = [(NSHTTPURLResponse *)self.lastResponse statusCode];
        NSDictionary *headers = [(NSHTTPURLResponse *)self.lastResponse allHeaderFields];
        KCSLogNetwork(@"Response completed with code %d and response headers: %@", statusCode, [headers stripKeys:@[@"Authorization"]]);
        KCSLogRequestId(@"Kinvey Request ID: %@", [headers objectForKey:@"X-Kinvey-Request-Id"]);
        self.completionBlock([KCSConnectionResponse connectionResponseWithCode:statusCode responseData:self.downloadedData headerData:headers userData:nil]);
        
        [self cleanUp];
    }];
}

// Don't honor the redirect, just grab the location and move on...
-(NSURLRequest *)connection:(NSURLConnection *)connection
            willSendRequest:(NSURLRequest *)request
           redirectResponse:(NSURLResponse *)redirectResponse
{
    NSURLRequest *newRequest = request;
    if (redirectResponse != nil) {
        if (self.followRedirects && [[newRequest HTTPMethod] isEqualToString:@"GET"]) {
            //Test that the if the redirect host is not Kinvey,
            //create a new url request that does not copy over the headers (bug with connecting to azure with iOS 4.3, where authentication was copied over).
            NSURL* newurl = request.URL;
            NSString* newHost = newurl.host;
            NSString* resourceURLString = [[KCSClient sharedClient] resourceBaseURL];
            NSURL* resourceURL = [NSURL URLWithString:resourceURLString];
            if (![newHost isEqualToString:[resourceURL host]]) {
                newRequest = [[NSMutableURLRequest alloc] initWithURL:newurl];
                //get date from old request
                NSString* date = [[request allHTTPHeaderFields] objectForKey:@"Date"];
                [(NSMutableURLRequest*)newRequest setValue:date forHTTPHeaderField:@"Date"];
                // Let the server know that we support GZip.
                [(NSMutableURLRequest*)newRequest setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
            }
        } else {
            newRequest = nil;
        }
    }
    return newRequest;
}

#pragma mark - Background Handling

#if TARGET_OS_IPHONE

- (void) didEnterBackground:(NSNotification*)note
{
    UIApplication* application = [UIApplication sharedApplication];
    _bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you.
        // stopped or ending the task outright.
        [self.connection cancel];
        [self invalidateBgTask];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void) invalidateBgTask
{
    UIApplication* application = [UIApplication sharedApplication];
    [application endBackgroundTask:_bgTask];
    _bgTask = UIBackgroundTaskInvalid;
}

- (void) didBecomeActive:(NSNotification*)note
{
    if (_blockToRun != nil) {
        //check for nil first in case the app went to the background during transmission. This is only needed if the background happens after the completion delegate methods.
        //to keep app from being killed by watchdog.
        RunBlock_t block = [_blockToRun copy];
        block();
    }
}

#else
- (void) invalidateBgTask
{
}

#endif
@end