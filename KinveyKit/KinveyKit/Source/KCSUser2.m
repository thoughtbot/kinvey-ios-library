//
//  KCSUser2.m
//  KinveyKit
//
//  Created by Michael Katz on 12/10/13.
//  Copyright (c) 2013 Kinvey. All rights reserved.
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

#import "KCSUser2.h"

#import "KCSHiddenMethods.h"
#import "KinveyCollection.h"
#import "KinveyUser.h"

#import "KinveyCoreInternal.h"
#import "KinveyDataStoreInternal.h"
#import "KinveyUserService.h"

#define KCSUserAttributeOAuthTokens @"_oauth"


@interface KCSUser2()
@property (nonatomic, strong) NSMutableDictionary *userAttributes;
@end

@implementation KCSUser2

- (instancetype) init
{
    self = [super init];
    if (self){
        _username = @"";
        _userId = @"";
        _userAttributes = [NSMutableDictionary dictionary];
    }
    return self;
}


+ (NSDictionary *)kinveyObjectBuilderOptions
{
    static NSDictionary *options = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        options = @{KCS_USE_DICTIONARY_KEY : @(YES),
                    KCS_DICTIONARY_NAME_KEY : @"userAttributes"};
    });
    
    return options;
}

- (NSDictionary *)hostToKinveyPropertyMapping
{
    static NSDictionary *mappedDict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mappedDict = @{@"userId" : KCSEntityKeyId,
                       //                       @"push" : @"_push",
                       @"username" : KCSUserAttributeUsername,
                       @"email" : KCSUserAttributeEmail,
                       @"givenName" : KCSUserAttributeGivenname,
                       @"surname" : KCSUserAttributeSurname,
                       @"metadata" : KCSEntityKeyMetadata,
//                       @"oauthTokens" : KCSUserAttributeOAuthTokens,
                       };
    });
    
    return mappedDict;
}

#warning FIx THESE:

- (NSString *)authString
{
    NSString* token = [KCSKeychain2 kinveyTokenForUserId:self.userId];
    NSString *authString = nil;
    if (token) {
        authString = [@"Kinvey " stringByAppendingString: token];
        KCSLogInfo(KCS_LOG_CONTEXT_USER, @"Current user found, using sessionauth (%@) => XXXXXXXXX", self.username);
    } else {
        KCSLogError(KCS_LOG_CONTEXT_USER, @"No session auth for current user found (%@)", self.username);
    }
    return authString;
}

 - (void) refreshFromServer:(KCSCompletionBlock)completionBlock
{
    completionBlock(@[self],nil);
#if NEVER
    if ([KCSUser activeUser] != self) {
        KCSLogError(@"Error: Attempting to refresh a non-activeUser");
        NSDictionary* errorInfo = [KCSErrorUtilities createErrorUserDictionaryWithDescription:@"User refresh is not on active user" withFailureReason:@"" withRecoverySuggestion:@"" withRecoveryOptions:@[]];
        NSError* error = [NSError errorWithDomain:KCSUserErrorDomain code:KCSUserObjectNotActiveError userInfo:errorInfo];
        completionBlock(nil, error);
        return;
    }
    if (self.userId == nil) {
        KCSLogError(@"Error refreshing user, no user id.");
        NSDictionary* errorInfo = [KCSErrorUtilities createErrorUserDictionaryWithDescription:@"User refresh is not on active user" withFailureReason:@"" withRecoverySuggestion:@"" withRecoveryOptions:@[]];
        NSError* error = [NSError errorWithDomain:KCSUserErrorDomain code:KCSUserObjectNotActiveError userInfo:errorInfo];
        completionBlock(nil, error);
        return;
    }
    [lastBGUpdate cancel];
    
    lastBGUpdate = [KCSRESTRequest requestForResource:[[[KCSClient sharedClient] userBaseURL] stringByAppendingFormat:@"%@", self.userId] usingMethod:kGetRESTMethod];
    [lastBGUpdate setContentType:KCS_JSON_TYPE];
    
    // Set up our callbacks
    KCSConnectionCompletionBlock cBlock = ^(KCSConnectionResponse *response){
        lastBGUpdate = nil;
        
        if ([KCSUser activeUser] != self) {
            KCSLogError(@"Error: Attempting to refresh a non-activeUser");
            NSDictionary* errorInfo = [KCSErrorUtilities createErrorUserDictionaryWithDescription:@"User refresh is not on active user" withFailureReason:@"" withRecoverySuggestion:@"" withRecoveryOptions:@[]];
            NSError* error = [NSError errorWithDomain:KCSUserErrorDomain code:KCSUserObjectNotActiveError userInfo:errorInfo];
            completionBlock(nil, error);
            return;
        }
        
        // Ok, we're really auth'd
        if ([response responseCode] < 300) {
            NSDictionary *dictionary = (NSDictionary*) [response jsonResponseValue];
            [KCSUser setupCurrentUser:self properties:dictionary password:nil username:self.username completionBlock:^(KCSUser *user, NSError *errorOrNil, KCSUserActionResult result) {
                completionBlock(@[user], errorOrNil);
            }];
        } else {
            KCSLogError(@"Internal Error Updating user: %@", [response jsonResponseValue]);
            NSError* error = [KCSErrorUtilities createError:[response jsonResponseValue] description:@"Error updating active User" errorCode:response.responseCode domain:KCSUserErrorDomain requestId:response.requestId];
            completionBlock(@[self], error);
        }
    };
    
    KCSConnectionFailureBlock fBlock = ^(NSError *error){
        lastBGUpdate = nil;
        KCSLogError(@"Internal Error Updating user: %@", error);
        completionBlock(nil, error);
    };
    
    [lastBGUpdate withCompletionAction:cBlock failureAction:fBlock progressAction:nil];
    [lastBGUpdate start];
#endif
}

- (void) logout
{
    [KCSUser2 logoutUser:self];
}

@end