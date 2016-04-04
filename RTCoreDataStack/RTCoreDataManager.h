/*
 RTCoreDataManager.h
 Radiant Tap Essentials
 
 Created by Aleksandar Vacić on 11.2.15.
 Copyright (c) 2015. Radiant Tap. All rights reserved.

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
#import "NSManagedObjectContext+RTCoreDataManager.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RTCoreDataManagerDidMergeNotification;

typedef void (^InitCallbackBlock)(void);

NS_CLASS_AVAILABLE(10_7, 7_0)
@interface RTCoreDataManager : NSObject

/**
 *	Until this is YES, data store is not available. Do not attempt to access any of the MOCs until isReady=YES
 */
@property (readonly, nonatomic, getter=isReady) BOOL ready;


//	## init scenario 1: (static shared manager across the app)
#pragma mark - Singleton init/setup

/**
 *	Singleton for all your Core Data needs across the app. Recommended for just about most apps.
 *
 *	@return an instance of RTCoreDataManager
 */
+ (RTCoreDataManager *)defaultManager;

/**
 *	Sets up the the whole stack.
 *	Uses mergedModelFromBundles: over mainBundle to create data model.
 *	Uses canonicalized app name ("CFBundleName") as name of the store file on disk, with .sqlite extension, in app's Documents folder.
 *
 *	This is recommended for most newly created apps.
 *
 *	@param callback	A block to call once setup is completed. RTCoreDataManager.isReady is set to YES before callback is executed.
 */
- (void)setupWithCallback:(InitCallbackBlock)callback;

/**
 *	Sets up the the whole stack.
 *	Uses canonicalized app name ("CFBundleName") as name of the store file on disk, with .sqlite extension, in app's Documents folder.
 *
 *	Possible use: you are publishing an update to an existing app but are completely changing app's data model. It makes sense to instantiate two Core Data stacks, one for old and one for new data model and then copy stuff over in controlled manner.
 *	(Can be much less headache inducing than writing migration models.)
 *
 *	@param dataModelName Name of the data model you want to use (this is
 *	@param callback	A block to call once setup is completed. RTCoreDataManager.isReady is set to YES before callback is executed.
 */
- (void)setupWithDataModelNamed:(NSString *)dataModelName callback:(InitCallbackBlock)callback;

/**
 *	Sets up the the whole stack, giving you full control over what model to use and where the resulting file should be.
 *
 *	Possible use: when you want to setup the store file into completely custom location. Like say shared container in App Group.
 *
 *	@param dataModelName
 *	@param storeURL
 *	@param callback	A block to call once setup is completed. RTCoreDataManager.isReady is set to YES before callback is executed.
 */
- (void)setupWithDataModelNamed:(nullable NSString *)dataModelName storeURL:(NSURL *)storeURL callback:(InitCallbackBlock)callback;

//	## init scenario 2: no singleton, but locally retained object



#pragma mark - Regular init/setup
/**
 *	Sets up the the whole stack.
 *	Uses mergedModelFromBundles: over mainBundle to create data model.
 *	Uses canonicalized app name ("CFBundleName") as name of the store file on disk, with .sqlite extension, in app's Documents folder.
 *
 *	This is recommended for most newly created apps.
 *
 *	@param callback	A block to call once setup is completed. RTCoreDataManager.isReady is set to YES before callback is executed.
 *
 *	@return A fully setup instance of RTCoreDataManager, with isReady=YES
 */
- (instancetype)initWithCallback:(InitCallbackBlock)callback;

/**
 *	Sets up the the whole stack.
 *	Uses canonicalized app name ("CFBundleName") as name of the store file on disk, with .sqlite extension, in app's Documents folder.
 *
 *	Possible use: you are publishing an update to an existing app but are completely changing app's data model. It makes sense to instantiate two Core Data stacks, one for old and one for new data model and then copy stuff over in controlled manner.
 *	(Can be much less headache inducing than writing migration models.)
 *
 *	@param dataModelName Name of the data model you want to use (this is
 *	@param callback	A block to call once setup is completed. RTCoreDataManager.isReady is set to YES before callback is executed.
 *
 *	@return A fully setup instance of RTCoreDataManager, with isReady=YES
 */
- (instancetype)initWithDataModelNamed:(NSString *)dataModelName callback:(InitCallbackBlock)callback;

/**
 *	Sets up the the whole stack, giving you full control over what model to use and where the resulting file should be.
 *
 *	Possible use: when you want to setup the store file into completely custom location. Like say shared container in App Group.
 *
 *	@param dataModelName
 *	@param storeURL
 *	@param callback	A block to call once setup is completed. RTCoreDataManager.isReady is set to YES before callback is executed.
 *
 *	@return A fully setup instance of RTCoreDataManager, with isReady=YES
 */
- (instancetype)initWithDataModelNamed:(nullable NSString *)dataModelName storeURL:(NSURL *)storeURL callback:(InitCallbackBlock)callback;




#pragma mark - Main MOC
/**
 *	Main thread's MOC, use it for all the UI work. Has no parentContext, connects directly to PSC.
 *	By default, its mergePolicy is set to favor the store (values on disk) in case of any save conflicts; without conflicts it will perform the usual save.
 *	However, if you set mainMOCReadOnly=YES, it will force the mergePolicy to NSRollbackMergePolicy which means it will silently ignore any save attempts you make.
 *
 *	RTCoreDataManager will listen for ContextDidSaveNotification from wherever and will _usually_ merge any incoming objects. So NSFRC and friends will continue working as expected.
 *	However, you can override this as needed by setting mergeIncomingSavedObjects to NO (see that property for extended discussion).
 *
 *	@return MOC with concurrency=NSMainQueueConcurrencyType and mergePolicy=NSMergeByPropertyStoreTrumpMergePolicy
 */
@property (nonatomic, strong, readonly) NSManagedObjectContext *mainManagedObjectContext;

/**
 *	If YES, main MOC will not be able to save any of its changes. RTCoreDataManager will ignore save attempts (see mainManagedObjectContext for extended discussion)
 *
 *	Default: NO
 */
@property (nonatomic, getter=isMainMOCReadOnly) BOOL mainMOCReadOnly;

/**
 *	If YES, main MOC will listen for ContextDidSaveNotification from wherever and will usually merge any incoming objects. So NSFRC and friends will continue working as expected.
 *	If NO, main MOC will not merge those objects, but will instead fire RTCoreDataManagerDidMergeNotification. You listen to it and do NSFRC.performFetch to get newly received objects
 *
 *	Default: YES
 */
@property (nonatomic, getter=shouldMergeIncomingSavedObjects) BOOL mergeIncomingSavedObjects;




#pragma mark - Helper MOCs
/**
 *	Importer MOC is your best path to import large amounts of data in the background. Its mergePolicy is set to favor objects in memory versus those in the store, thus in case of conflicts newly imported data will trump whatever is on disk.
 *	Its private NSPersistentStoreCoordinator is created during RTCoreDataManager init/setup and kept alive as Writer PSC.
 *
 *	@return MOC with concurrency=NSPrivateQueueConcurrencyType and mergePolicy=NSMergeByPropertyObjectTrumpMergePolicy, shares PSC with main MOC
 */
- (NSManagedObjectContext *)importerManagedObjectContext;


/**
 *	Use temporary MOC is for cases where you need short-lived managed objects. Whatever you do in here is never saved, as its mergePolicy is set to NSRollbackMergePolicy
 *	This is useful for cases where you need to copy NSManagedObject instance to temporary adjust some of its values but don't need them saved
 *
 *	@return MOC with concurrency=NSPrivateQueueConcurrencyType and mergePolicy=NSRollbackMergePolicy, with the same PSC as mainManagedObjectContext
 */
- (NSManagedObjectContext *)temporaryManagedObjectContext;


/**
 *	Use creator MOC for all cases where you need to allow the customer to create new objects that will be saved to disk. For example, to "add new" / "edit existing" contact in contact management app.
 *	It is always set to use mainManagedObjectContext as its parentContext, so any saves are transfered to your main MOC and thus available to the UI.
 *	You must make sure that mainMOC is not read-only when calling this method (assert is run and if it is read-only your app will crash).
 *
 *	@return MOC with concurrency=NSPrivateQueueConcurrencyType and mergePolicy=NSMergeByPropertyObjectTrumpMergePolicy and parentContext=mainManagedObjectContext
 */
- (NSManagedObjectContext *)creatorManagedObjectContext;

@end

NS_ASSUME_NONNULL_END
