/*
 Licensed under the MIT License

 Copyright (c) 2015 Aleksandar Vacić, RadiantTap.com

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

@import Foundation;
@import CoreData;

typedef void (^InitCallbackBlock)(void);

@interface RTCoreDataManager : NSObject

//	init 1: (all defaults, static shared manager across the app)
+ (RTCoreDataManager *)defaultManager;
- (void)setupWithCallback:(InitCallbackBlock)callback;
- (void)setupWithDataModelNamed:(NSString *)dataModelName callback:(InitCallbackBlock)callback;
- (void)setupWithDataModelNamed:(NSString *)dataModelName storeURL:(NSURL *)storeURL callback:(InitCallbackBlock)callback;	//	storeURL must exist

//	init 2: (varying custom setup, local object)
- (instancetype)initWithCallback:(InitCallbackBlock)callback;
- (instancetype)initWithDataModelNamed:(NSString *)dataModelName callback:(InitCallbackBlock)callback;
- (instancetype)initWithDataModelNamed:(NSString *)dataModelName storeURL:(NSURL *)storeURL callback:(InitCallbackBlock)callback;	//	storeURL must exist

//	until this is YES, data store is not available
@property (readonly, getter=isReady) BOOL ready;

//	main MOC, use it for main thread
@property (strong, readonly) NSManagedObjectContext *managedObjectContext;
//	various useful MOCs
- (NSManagedObjectContext *)importerManagedObjectContext;	//	use on background threads to import large amounts of data, attached to PSC
- (NSManagedObjectContext *)temporaryManagedObjectContext;	//	use for temporary views, changes will ever be saved, attached to PSC
- (NSManagedObjectContext *)creatorManagedObjectContext;	//	use when creating/editing objects from MOC, attached to mainMOC

//	this will save main MOC plus private MOC (main's parentContext) as well (to save to disk)
- (void)saveMainContext;

@end
