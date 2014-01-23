//
//  KinveyClient.m
//  KinveyKit
//
//  Created by Brian Wilson on 10/13/11.
//  Copyright (c) 2011-2014 Kinvey. All rights reserved.
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



#import "KCSClient.h"
#import "KinveyUser.h"

#import "NSURL+KinveyAdditions.h"
#import "NSString+KinveyAdditions.h"
#import "KCSReachability.h"
#import "KCSLogManager.h"

#import "KCSStore.h"
#import "KCSClient+ConfigurationTest.h"

#import "KinveyVersion.h"

#import "KCSClientConfiguration.h"
#import "KCSHiddenMethods.h"
#import "KCSBase64.h"
#import "KCSFileUtils.h"

#import "KCSClientConfiguration+KCSInternal.h"


// Anonymous category on KCSClient, used to allow us to redeclare readonly properties
// readwrite.  This keeps KVO notation, while allowing private mutability.
@interface KCSClient ()
// Redeclare private iVars
@property (nonatomic, copy, readwrite) NSString *userAgent;
@property (nonatomic, copy, readwrite) NSString *libraryVersion;
@property (nonatomic, copy, readwrite) NSString *appdataBaseURL;
@property (nonatomic, copy, readwrite) NSString *resourceBaseURL;
@property (nonatomic, copy, readwrite) NSString *userBaseURL;
@property (nonatomic, copy, readwrite) NSString *rpcBaseURL;


@property (nonatomic, strong, readwrite) KCSReachability *networkReachability;
@property (nonatomic, strong, readwrite) KCSReachability *kinveyReachability;

///---------------------------------------------------------------------------------------
/// @name Connection Properties
///---------------------------------------------------------------------------------------

- (void)updateURLs;

@end

@implementation KCSClient

+ (KCSClient *)sharedClient
{
    static KCSClient *sKCSClient;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sKCSClient = [[self alloc] init];
        NSAssert(sKCSClient != nil, @"Unable to instantiate KCSClient");
    });
    
    return sKCSClient;
}

- (instancetype)init
{
    self = [super init];
    
    if (self){
        _libraryVersion = __KINVEYKIT_VERSION__;
        _userAgent = [[NSString alloc] initWithFormat:@"ios-kinvey-http/%@ kcs/%@", self.libraryVersion, MINIMUM_KCS_VERSION_SUPPORTED];
        
        if (![self respondsToSelector:@selector(testCanUseCategories)]) {
            NSException* myException = [NSException exceptionWithName:@"CategoriesNotLoaded" reason:@"KinveyKit setup: Categories could not be loaded. Be sure to set '-ObjC' in the 'Other Linker Flags'." userInfo:nil];
            @throw myException;
        }
    }
    
    return self;
}

- (void) setConfiguration:(KCSClientConfiguration*)configuration
{
    _configuration = configuration;
    
    if (configuration.appKey == nil || [configuration.appKey hasPrefix:@"<"]) {
        [[NSException exceptionWithName:@"KinveyInitializationError" reason:@"`nil` or invalid appKey, cannot use Kinvey Service, no recovery available" userInfo:nil] raise];
    }
    if (configuration.appSecret == nil || [configuration.appSecret hasPrefix:@"<"]) {
        [[NSException exceptionWithName:@"KinveyInitializationError" reason:@"`nil` or invalid appSecret, cannot use Kinvey Service, no recovery available" userInfo:nil] raise];
    }

    [configuration applyConfiguration]; //apply early to set up classes and caches
    
    NSString* oldAppKey = [[KCSAppdataStore caches] cachedAppKey];
    if (oldAppKey != nil && [configuration.appKey isEqualToString:oldAppKey] == NO) {
        //clear the saved user if the kid changes
        [[KCSUser activeUser] logout];
    }

    _networkReachability = [KCSReachability reachabilityForInternetConnection];
    // This next initializer is Async.  It needs to DNS lookup the hostname (in this case the hard coded _serviceHostname)
    // We start this in init in the hopes that it will be (mostly) complete by the time we need to use it.
    // TODO: Investigate being notified of changes in KCS Client

    // We do this here because there is latency on DNS resolution of the hostname.  We need to do this ASAP when the hostname changes
    self.kinveyReachability = [KCSReachability reachabilityWithHostName:[NSString stringWithFormat:@"%@.%@", self.configuration.serviceHostname, configuration.options[@"KCS_HOST_DOMAIN"]]];

    [self updateURLs];
    // Check to make sure appdata URL is good
    NSURL *tmpURL = [NSURL URLWithString:self.appdataBaseURL]; // Will get autoreleased during next drain
    if (!tmpURL){
        [[NSException exceptionWithName:@"KinveyInitializationError" reason:@"App Key contains invalid characters, check to make sure App Key is correct!" userInfo:nil] raise];
    }
    
    if (self.options[KCS_CONNECTION_TIMEOUT]) {
        _connectionTimeout = [self.options[KCS_CONNECTION_TIMEOUT] doubleValue];
    }
    
    KK2(move this over)
    if (self.options[KCS_LOG_SINK] != nil) {
        [KCSLogManager setLogSink:self.options[KCS_LOG_SINK]];
    }
}

- (NSString *)serviceHostname
{
    return self.configuration.serviceHostname;
}

- (NSDictionary *)options
{
    return self.configuration.options;
}

- (NSString*) appKey
{
    return self.configuration.appKey;
}
- (NSString *)appSecret
{
    return self.configuration.appSecret;
}
- (NSURLCacheStoragePolicy) cachePolicy
{
    return [self.configuration.options[KCS_URL_CACHE_POLICY] unsignedIntegerValue];
}
- (NSString *)dateStorageFormatString
{
    return self.configuration.options[KCS_DATE_FORMAT];
}

#pragma mark INITS

- (void) initializeWithConfiguration:(KCSClientConfiguration*)configuration
{
    self.configuration = configuration;
}

- (instancetype) initializeKinveyServiceForAppKey:(NSString *)appKey withAppSecret:(NSString *)appSecret usingOptions:(NSDictionary *)options
{
    [self initializeWithConfiguration:[KCSClientConfiguration configurationWithAppKey:appKey secret:appSecret options:options]];
    return self;
}

- (instancetype) initializeKinveyServiceWithPropertyList
{
    [self initializeWithConfiguration:[KCSClientConfiguration configurationFromPlist:@"KinveyOptions"]];
    return self;
}

- (void)updateURLs
{
    NSString* protocol = self.configuration.options[@"KCS_HOST_PROTOCOL"];
    NSString* hostname = self.configuration.serviceHostname;
    NSString* hostdomain = self.configuration.options[@"KCS_HOST_DOMAIN"];
    NSString* port = self.configuration.options[@"KCS_HOST_PORT"];
    NSString* host = [NSString stringWithFormat:@"%@://%@.%@%@", protocol, hostname, hostdomain, port];
    self.appdataBaseURL  = [NSString stringWithFormat:@"%@/appdata/%@/", host, self.appKey];
    self.resourceBaseURL = [NSString stringWithFormat:@"%@/blob/%@/", host, self.appKey];
    self.userBaseURL     = [NSString stringWithFormat:@"%@/user/%@/", host, self.appKey];
    //rpc/:kid/:username/user-password-reset-initiate
    self.rpcBaseURL      = [NSString stringWithFormat:@"%@/rpc/%@/", host, self.appKey];

}

#pragma mark - User

- (void) setCurrentUser:(KCSUser *)currentUser
{
    KCSUser* oldUser = _currentUser;
    _currentUser = currentUser;
    BOOL sameUser = (_currentUser == oldUser) || [[currentUser  userId] isEqualToString:[oldUser userId]];
    if (!sameUser) {
        [[KCSAppdataStore caches] cacheActiveUser:(id)currentUser];
#warning handle main thread note events
        [[NSNotificationCenter defaultCenter] postNotificationName:KCSActiveUserChangedNotification object:oldUser];
    }
}

#pragma mark - Logging


+ (void)configureLoggingWithNetworkEnabled: (BOOL)networkIsEnabled
                              debugEnabled: (BOOL)debugIsEnabled
                              traceEnabled: (BOOL)traceIsEnabled
                            warningEnabled: (BOOL)warningIsEnabled
                              errorEnabled: (BOOL)errorIsEnabled
{
    [[KCSLogManager sharedLogManager] configureLoggingWithNetworkEnabled:networkIsEnabled
                                                            debugEnabled:debugIsEnabled
                                                            traceEnabled:traceIsEnabled
                                                          warningEnabled:warningIsEnabled
                                                            errorEnabled:errorIsEnabled];
}


#pragma mark - Utilites
- (void)clearCache
{
    [[KCSAppdataStore caches] clear];
}

#pragma mark - KinveyKit 1.5
//TODO cleanup
- (NSString *)authString
{
    KCSLogDebug(@"Using app key/app secret for auth: (%@, <APP_SECRET>) => XXXXXXXXX", self.configuration.appKey);
    return KCSbasicAuthString(self.configuration.appKey, self.configuration.appSecret);
    
}

#pragma mark - KinveyKit2
- (NSString*) kid
{
    return self.configuration.appKey;
}

- (NSString*) baseURL
{
    NSString* protocol = self.configuration.options[@"KCS_HOST_PROTOCOL"];
    NSString* hostname = self.configuration.serviceHostname;
    NSString* hostdomain = self.configuration.options[@"KCS_HOST_DOMAIN"];
    NSString* port = self.configuration.options[@"KCS_HOST_PORT"];
    return [NSString stringWithFormat:@"%@://%@.%@%@/", protocol, hostname, hostdomain, port];
}

#pragma mark - Data Protection
- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)application
{
    KCSLogTrace(@"Did became avaialble");
    [KCSFileUtils dataDidBecomeAvailable];
}

- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application
{
    KCSLogTrace(@"Did became unavailable");
    [KCSFileUtils dataDidBecomeUnavailable];
}

@end
