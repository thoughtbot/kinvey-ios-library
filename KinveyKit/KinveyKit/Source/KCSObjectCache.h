//
//  KCSObjectCache.h
//  KinveyKit
//
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


#import <Foundation/Foundation.h>

@class KCSQuery2;
@protocol KCSPersistable;
@protocol KCSOfflineUpdateDelegate;

@interface KCSObjectCache : NSObject

@property (nonatomic) BOOL preCalculatesResults;
@property (nonatomic) BOOL updatesLocalWithUnconfirmedSaves;
@property (nonatomic) BOOL offlineUpdateEnabled;

- (void) setOfflineUpdateDelegate:(id<KCSOfflineUpdateDelegate>)offlineUpdateDelegate;

- (NSArray*) pullQuery:(KCSQuery2*)query route:(NSString*)route collection:(NSString*)collection;
- (NSArray*) setObjects:(NSArray*)jsonArray forQuery:(KCSQuery2*)query route:(NSString*)route collection:(NSString*)collection;

- (void) updateObject:(id<KCSPersistable>)object route:(NSString*)route collection:(NSString*)collection;
- (void) updateCacheForObject:(NSString*)objId withEntity:(NSDictionary*)entity atRoute:(NSString*)route collection:(NSString*)collection;

- (void) deleteObject:(NSString*)objId route:(NSString*)route collection:(NSString*)collection;

- (NSString*) addUnsavedObject:(id<KCSPersistable>)object entity:(NSDictionary*)entity route:(NSString*)route collection:(NSString*)collection method:(NSString*)method headers:(NSDictionary*)headers error:(NSError*)error;
 

//destructive
- (void) clear;
@end