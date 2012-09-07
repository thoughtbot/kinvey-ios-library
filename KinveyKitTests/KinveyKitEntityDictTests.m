//
//  KinveyKitEntityDictTests.m
//  KinveyKit
//
//  Created by Brian Wilson on 1/5/12.
//  Copyright (c) 2012 Kinvey. All rights reserved.
//

#import "KinveyKitEntityDictTests.h"
#import "KCSEntityDict.h"
#import "SBJson.h"
#import "KCSKeyChain.h"
#import "KinveyUser.h"
#import "KCSConnectionResponse.h"
#import "KCSConnection.h"
#import "KCSConnectionPool.h"
#import "KCSMockConnection.h"

typedef BOOL(^SuccessAction)(NSArray *);
typedef BOOL(^FailureAction)(NSError *);
typedef BOOL(^InfoSuccessAction)(int);

@interface KinveyKitEntityDictTests ()
@property (nonatomic) BOOL testPassed;
@property (retain, nonatomic) NSString *testID;
@property (retain, nonatomic) SuccessAction onSuccess;
@property (retain, nonatomic) FailureAction onFailure;
@property (retain, nonatomic) InfoSuccessAction onInfoSuccess;
@property (retain, nonatomic) NSString *message;

@property (retain, nonatomic) KCS_SBJsonParser *parser;
@property (retain, nonatomic) KCS_SBJsonWriter *writer;

@end



@implementation KinveyKitEntityDictTests


@synthesize testID = _testID;
@synthesize onFailure = _onFailure;
@synthesize onSuccess = _onSuccess;
@synthesize onInfoSuccess = _onInfoSuccess;
@synthesize testPassed = _testPassed;
@synthesize message = _message;
@synthesize parser = _parser;
@synthesize writer = _writer;

- (void)setUp
{
    _testID = nil;
    
    // Provide default FALSE implementations
    _onFailure = ^(NSError *err){return NO;};
    _onSuccess = ^(NSArray *res){return NO;};
    _onInfoSuccess = ^(int res){return NO;};
    
    _testPassed = NO;
    _message = nil;
    
    // Ensure that KCSClient is alive
    KCSClient *client = [KCSClient sharedClient];
    [client setServiceHostname:@"baas"];
    [client initializeKinveyServiceForAppKey:@"kid1234" withAppSecret:@"1234" usingOptions:nil];
    
    
    // Fake Auth
    [KCSKeyChain setString:@"kinvey" forKey:@"username"];
    [KCSKeyChain setString:@"12345" forKey:@"password"];
    
    // Needed, otherwise we burn a connection later...
    [KCSUser initCurrentUser];
    
    
    _writer = [[[KCS_SBJsonWriter alloc] init] retain];
    _parser = [[[KCS_SBJsonParser alloc] init] retain];
}

- (void)tearDown
{
    [[[KCSClient sharedClient] currentUser] logout];    
}


- (void)testSet
{
    KCSEntityDict *d = [[KCSEntityDict alloc] init];
    [d setValue:@"test" forProperty:@"test"];
    // CHEAT
    NSString *str = [[d performSelector:@selector(entityProperties)] objectForKey:@"test"];
    assertThat(str, is(equalTo(@"test")));
    
    
    // Verify that we're acting like a dictionary
    STAssertThrows([d setValue:nil forProperty:@"nilTest"], @"Expected throw for nil in dictionary, did not get");
    
    [d setValue:[NSNull null] forProperty:@"nilTest"];
    // CHEAT
    NSNull *n = [[d performSelector:@selector(entityProperties)] objectForKey:@"nilTest"];
    assertThat(n, is(equalTo([NSNull null])));
    
    // Number
    NSNumber *tn = [NSNumber numberWithDouble:3.14159];
    [d setValue:tn forProperty:@"test"];
    // CHEAT
    NSNumber *nmb = [[d performSelector:@selector(entityProperties)] objectForKey:@"test"];
    assertThat(nmb, is(equalTo(tn)));
    
    // Bool
    tn = [NSNumber numberWithBool:YES];
    [d setValue:tn forProperty:@"test"];
    // CHEAT
    nmb = [[d performSelector:@selector(entityProperties)] objectForKey:@"test"];
    assertThat(nmb, is(equalTo(tn)));

    // Array
    NSArray *t = [NSArray arrayWithObjects:@"one", @"two", @"three", nil];
    [d setValue:t forProperty:@"test"];
    // CHEAT
    NSArray *array = [[d performSelector:@selector(entityProperties)] objectForKey:@"test"];
    assertThat(array, is(equalTo(t)));

    // Dict
    NSDictionary *td = [NSDictionary dictionaryWithObjectsAndKeys:@"1", @"one", @"2", @"two", nil];
    [d setValue:td forProperty:@"test"];
    // CHEAT
    NSDictionary *dict = [[d performSelector:@selector(entityProperties)] objectForKey:@"test"];
    assertThat(dict, is(equalTo(td)));
    
}

- (void)testGet
{
    KCSEntityDict *d = [[KCSEntityDict alloc] init];
    [d setValue:@"test" forProperty:@"test"];
    NSString *str = [d getValueForProperty:@"test"];
    assertThat(str, is(equalTo(@"test")));
    
    
    // Verify that we're acting like a dictionary
    STAssertThrows([d setValue:nil forProperty:@"nilTest"], @"Expected throw for nil in dictionary, did not get");
    
    [d setValue:[NSNull null] forProperty:@"nilTest"];
    NSNull *n = [d getValueForProperty:@"nilTest"];
    assertThat(n, is(equalTo([NSNull null])));
    
    // Number
    NSNumber *tn = [NSNumber numberWithDouble:3.14159];
    [d setValue:tn forProperty:@"test"];
    NSNumber *nmb = [d getValueForProperty:@"test"];
    assertThat(nmb, is(equalTo(tn)));
    
    // Bool
    tn = [NSNumber numberWithBool:YES];
    [d setValue:tn forProperty:@"test"];
    nmb = [d getValueForProperty:@"test"];
    assertThat(nmb, is(equalTo(tn)));
    
    // Array
    NSArray *t = [NSArray arrayWithObjects:@"one", @"two", @"three", nil];
    [d setValue:t forProperty:@"test"];
    NSArray *array = [d getValueForProperty:@"test"];
    assertThat(array, is(equalTo(t)));
    
    // Dict
    NSDictionary *td = [NSDictionary dictionaryWithObjectsAndKeys:@"1", @"one", @"2", @"two", nil];
    [d setValue:td forProperty:@"test"];
    NSDictionary *dict = [d getValueForProperty:@"test"];
    assertThat(dict, is(equalTo(td)));
    
   
}

- (void)testSerialize
{
//    KCSConnectionResponse *response = [KCSConnectionResponse connectionResponseWithCode:200
//                                                                           responseData:[self.writer dataWithObject:dict]
//                                                                             headerData:nil
//                                                                               userData:nil];
//    
//    KCSMockConnection *conn = [[KCSMockConnection alloc] init];
//    conn.responseForSuccess = response;
//    
//    conn.connectionShouldFail = NO;
//    conn.connectionShouldReturnNow = YES;
//    
//    self.onSuccess = ^(NSArray *results){
//        
//        self.message = [NSString stringWithFormat:@"Received: %@\n\n\nExpected: %@", actual, expected];
//        BOOL areTheyEqual = [actual isEqualToArray:expected];
//        return areTheyEqual;
//    };
//    
//    [[KCSConnectionPool sharedPool] topPoolsWithConnection:conn];
//    
//    
//    STAssertTrue(self.testPassed, self.message);
//    [conn release];

    
}

- (void)testCRUD
{
    
}

// All code under test must be linked into the Unit Test bundle
- (void)testEntityDictUnimplemented{
    STFail(@"Entity Dicts are not yet implemented");
}

@end