//
//  KCSOfflineStoreTests.m
//  KinveyKit
//
//  Created by Michael Katz on 8/7/12.
//  Copyright (c) 2012-2013 Kinvey. All rights reserved.
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


#import "KCSOfflineStoreTests.h"
#import "TestUtils.h"
#import <KinveyKit/KinveyKit.h>
#import "ASTTestClass.h"
#import "KCSHiddenMethods.h"

//@interface KCSSaveQueues;
//+ (KCSSaveQueues*)sharedQueues;
//- (void)persistQueues;
//- (NSDictionary*)cachedQueues;
//@end
@interface KCSAppdataStore ()
- (void) setReachable:(BOOL)r;
@end

@interface KCSOfflineStoreTests ()
{
    BOOL _shouldSaveCalled;
    BOOL _testShouldSave;
    BOOL _shouldSaveReturn;
    BOOL _willSaveCalled;
    BOOL _didSaveCalled;
    NSError* _errorCalled;
    NSUInteger _didSaveCount;
    NSUInteger _expSaveCount;
}

@end

@implementation KCSOfflineStoreTests

- (void)setUp
{
    BOOL up = [TestUtils setUpKinveyUnittestBackend];
    STAssertTrue(up, @"should be setup");
    
    _shouldSaveCalled = NO;
    _testShouldSave = NO;
    _shouldSaveReturn = YES;
    _willSaveCalled = NO;
    _errorCalled = nil;
    _didSaveCalled = NO;
    _didSaveCount = 0;
    _expSaveCount = 1;
}

- (void) testErrorOnOffline
{
    NSLog(@"---------- starting");
    
    ASTTestClass* obj = [[ASTTestClass alloc] init];
    obj.date = [NSDate date];
    obj.objCount = 79000;
    
    KCSCollection* c = [TestUtils randomCollection:[ASTTestClass class]];
    KCSAppdataStore* store = [KCSAppdataStore storeWithCollection:c options:@{}];
    
    [store setReachable:NO];
    
    self.done = NO;
    [store saveObject:obj withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
        STAssertError(errorOrNil, KCSKinveyUnreachableError);
        NSArray* objs = [[errorOrNil userInfo] objectForKey:KCS_ERROR_UNSAVED_OBJECT_IDS_KEY];
        STAssertEquals((NSUInteger)1, (NSUInteger) objs.count, @"should have one unsaved obj, from above");
        self.done = YES;
    } withProgressBlock:^(NSArray *objects, double percentComplete) {
        NSLog(@"%f", percentComplete);
    }];
    
    [self poll];
}

- (void) testWillSaveWhenGoBackOnline
{
    ASTTestClass* obj = [[ASTTestClass alloc] init];
    obj.date = [NSDate date];
    obj.objCount = 79000;
    
    KCSCollection* c = [TestUtils randomCollection:[ASTTestClass class]];
    KCSOfflineStoreTests* o = self;
    KCSAppdataStore* store = [KCSAppdataStore storeWithCollection:c options:@{}];
    
    [store setReachable:NO];
    
    self.done = NO;
    [store saveObject:obj withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
        STAssertError(errorOrNil, KCSKinveyUnreachableError);
        NSArray* objs = [[errorOrNil userInfo] objectForKey:KCS_ERROR_UNSAVED_OBJECT_IDS_KEY];
        STAssertEquals((int)1, (int)objs.count, @"should have one unsaved obj, from above");
        self.done = YES;
    } withProgressBlock:^(NSArray *objects, double percentComplete) {
        NSLog(@"%f", percentComplete);
    }];
    
    [self poll];
    
    self.done = NO;
    _testShouldSave = YES;
    [store setReachable:YES];
    
    [self poll];
    
    STAssertTrue(_shouldSaveCalled, @"shouldsave: should have been called");
    STAssertTrue(_willSaveCalled, @"willsave: should have been called");
    STAssertTrue(_didSaveCalled, @"didsave: should have been called");
    STAssertNil(_errorCalled, @"should have had a nil error %@", _errorCalled);
}

- (void) testSaveMultiple
{
    ASTTestClass* obj1 = [[ASTTestClass alloc] init];
    obj1.date = [NSDate date];
    obj1.objCount = 79000;
    
    ASTTestClass* obj2 = [[ASTTestClass alloc] init];
    obj2.date = [NSDate date];
    obj2.objCount = 10;
    
    ASTTestClass* obj3 = [[ASTTestClass alloc] init];
    obj3.date = [NSDate date];
    obj3.objCount = 1279000;
    
    KCSCollection* c = [TestUtils randomCollection:[ASTTestClass class]];
    KCSOfflineStoreTests* o = self;
    KCSAppdataStore* store = [KCSAppdataStore storeWithCollection:c options:@{}];
    
    [store setReachable:NO];
    
    self.done = NO;
    [store saveObject:@[obj1,obj2,obj3] withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
        STAssertError(errorOrNil, KCSKinveyUnreachableError);
        NSArray* objs = [[errorOrNil userInfo] objectForKey:KCS_ERROR_UNSAVED_OBJECT_IDS_KEY];
        STAssertEquals((int)3, (int)objs.count, @"should have one unsaved obj, from above");
        self.done = YES;
    } withProgressBlock:^(NSArray *objects, double percentComplete) {
        NSLog(@"%f", percentComplete);
    }];
    [self poll];
    
    self.done = NO;
    _expSaveCount = 3;
    [store setReachable:YES];
    
    [self poll];
    STAssertEquals((int)3, (int)_didSaveCount, @"Should have been called for each item");
}

- (void) testPersist
{
//    KCSSaveQueues* qs = [KCSSaveQueues sharedQueues];
//    KCSCollection* c = [TestUtils randomCollection:[ASTTestClass class]];
//
//    KCSAppdataStore* store = [KCSAppdataStore storeWithCollection:c options:@{}];
//    [store setReachable:NO];
//    ASTTestClass* obj = [[ASTTestClass alloc] init];
//    obj.date = [NSDate date];
//    obj.objCount = 79000;
//    [store saveObject:obj withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
//        self.done = YES;
//    } withProgressBlock:nil];
//    [self poll];
//    
//    [qs persistQueues];
    
    STFail(@"fix this");
//    NSDictionary* d = [qs cachedQueues];
//    KCSSaveQueue* s = [d objectForKey:@"x4"];
//    STAssertNotNil(s, @"should have saved an x4");
//    int count = [s count];
//    STAssertEquals((int)1, count, @"should have loaded one object");
//    KCSSaveQueueItem* t = [[s array] objectAtIndex:0];
//    ASTTestClass* atc = (ASTTestClass*)[t object];
//    STAssertEquals((int)79000, (int)atc.objCount, @"should match");
}

#pragma mark - Offline Save Delegate
- (BOOL)shouldSave:(id<KCSPersistable>)entity lastSaveTime:(NSDate *)timeSaved
{
    _shouldSaveCalled = YES;
    if (_testShouldSave) {
        ASTTestClass* obj = (ASTTestClass*) entity;
        STAssertEquals((int)79000, obj.objCount, @"should have the right obj to save");
    }
    
    return _shouldSaveReturn;
}

- (void) willSave:(id<KCSPersistable>)entity lastSaveTime:(NSDate *)timeSaved
{
    _willSaveCalled = YES;
}

- (void) didSave:(id<KCSPersistable>)entity
{
    _didSaveCalled = YES;
    _didSaveCount++;
    self.done = _expSaveCount == _didSaveCount;
}

- (void) errorSaving:(id<KCSPersistable>)entity error:(NSError *)error
{
    _errorCalled = error;
    self.done = YES;
}

@end
