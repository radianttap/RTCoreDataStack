/*
 RTCoreDataManager.m
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

#import "RTCoreDataManager.h"

NSString *const RTCoreDataManagerDidMergeNotification = @"RTCoreDataManagerDidMergeNotification";

@interface RTCoreDataManager ()

@property (readwrite, nonatomic, getter=isReady) BOOL ready;

@property (nonatomic, strong, readwrite) NSManagedObjectContext *mainManagedObjectContext;

@property (nonatomic, strong, readwrite) NSPersistentStoreCoordinator *mainPSC;
@property (nonatomic, strong, readwrite) NSPersistentStoreCoordinator *writerPSC;	//	used for importerMOC, background writes

@property (copy) InitCallbackBlock initCallback;

@end

@implementation RTCoreDataManager

+ (RTCoreDataManager *)defaultManager {
	static RTCoreDataManager *defaultManager = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		defaultManager = [[RTCoreDataManager alloc] init];
		defaultManager.ready = NO;
		defaultManager.initCallback = nil;
		defaultManager.mainMOCReadOnly = NO;
		defaultManager.mergeIncomingSavedObjects = YES;
	});

	return defaultManager;
}

- (void)setupWithCallback:(InitCallbackBlock)callback {

	_initCallback = callback;

	//	will use default store path
	NSURL *storeURL = [RTCoreDataManager defaultStoreURL];
	NSString *cleanAppName = [self cleanAppName];
	storeURL = [storeURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", cleanAppName]];

	//	will merge all models in the bundle
	NSManagedObjectModel *model = [self managedObjectModelNamed:nil];
	[self initializeCoreDataWithModel:model storeURL:storeURL];

	[self commonInit];
}

- (void)setupWithDataModelNamed:(NSString *)dataModelName callback:(InitCallbackBlock)callback {

	_initCallback = callback;

	//	will use default store path
	NSURL *storeURL = [RTCoreDataManager defaultStoreURL];
	NSString *cleanAppName = [self cleanAppName];
	storeURL = [storeURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", cleanAppName]];

	NSManagedObjectModel *model = [self managedObjectModelNamed:dataModelName];
	[self initializeCoreDataWithModel:model storeURL:storeURL];

	[self commonInit];
}

- (void)setupWithDataModelNamed:(NSString *)dataModelName storeURL:(NSURL *)storeURL callback:(InitCallbackBlock)callback {

	_initCallback = callback;

	NSManagedObjectModel *model = [self managedObjectModelNamed:dataModelName];
	[self initializeCoreDataWithModel:model storeURL:storeURL];

	[self commonInit];
}


//	2. an ordinary object kept by AppDelegate

- (instancetype)initWithCallback:(InitCallbackBlock)callback {

	if (!(self = [super init])) return nil;

	_initCallback = callback;

	//	will use default store path
	NSURL *storeURL = [RTCoreDataManager defaultStoreURL];
	NSString *cleanAppName = [self cleanAppName];
	storeURL = [storeURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", cleanAppName]];

	//	will merge all models in the bundle
	NSManagedObjectModel *model = [self managedObjectModelNamed:nil];

	[self initializeCoreDataWithModel:model storeURL:storeURL];

	return self;
}

- (instancetype)initWithDataModelNamed:(NSString *)dataModelName callback:(InitCallbackBlock)callback {

	_initCallback = callback;

	//	will use default store path
	NSURL *storeURL = [RTCoreDataManager defaultStoreURL];
	NSString *cleanAppName = [self cleanAppName];
	storeURL = [storeURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", cleanAppName]];

	return [self initWithDataModelNamed:dataModelName storeURL:storeURL callback:callback];
}

- (instancetype)initWithDataModelNamed:(NSString *)dataModelName storeURL:(NSURL *)storeURL callback:(InitCallbackBlock)callback {

	NSAssert([dataModelName length] > 0, @"E | %@:%@/%@ Data Model name not suppilied", [self class], NSStringFromSelector(_cmd), @(__LINE__));
	if (!(self = [super init])) return nil;

	_initCallback = callback;

	NSManagedObjectModel *model = [self managedObjectModelNamed:dataModelName];

	[self initializeCoreDataWithModel:model storeURL:storeURL];

	return self;
}

- (void)commonInit {

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMOCNotification:) name:NSManagedObjectContextDidSaveNotification object:nil];
}

- (void)dealloc {

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Private

- (NSString *)cleanAppName {

	NSString *str = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]
					 stringByTrimmingCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
	return str;
}

+ (NSURL *)defaultStoreURL {

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSURL *documentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
	return documentsURL;
}

- (NSManagedObjectModel *)managedObjectModelNamed:(NSString *)dataModelName {

	NSManagedObjectModel *mom = nil;

	if ([dataModelName length] == 0) {
		//	nothing specified, merge all data models found in the store
		mom = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle mainBundle]]];

	} else {
		NSURL *modelURL = [[NSBundle mainBundle] URLForResource:dataModelName withExtension:@"momd"];
		mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	}

	return mom;
}

- (void)initializeCoreDataWithModel:(NSManagedObjectModel *)mom storeURL:(NSURL *)storeURL {

	_ready = NO;
	_mainMOCReadOnly = NO;
	_mergeIncomingSavedObjects = YES;

	//	is model is not supplied, give up
	NSAssert(mom, @"E | %@:%@/%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd), @(__LINE__));

	//	make sure storeURL is usable URL
	BOOL isDirectory = NO;
	NSURL *directoryURL = [storeURL URLByDeletingLastPathComponent];
	BOOL doesDirectoryExists = [[NSFileManager defaultManager] fileExistsAtPath:[directoryURL path] isDirectory:&isDirectory];
	NSAssert(doesDirectoryExists, @"E | %@:%@/%@ StoreURL param points to non-existing directory", [self class], NSStringFromSelector(_cmd), @(__LINE__));

	//	## Persistance Store Coordinators

	//	use options that allow automatic model migrations
	NSDictionary *options = @{
							  NSMigratePersistentStoresAutomaticallyOption: @(YES),
							  NSInferMappingModelAutomaticallyOption: @(YES)
							  };
	//	block that will connect NSPSC to the store file on disk
	void (^connectPSC)(NSPersistentStoreCoordinator *) = ^void(NSPersistentStoreCoordinator *psc) {
		NSError *error = nil;
		NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType
													 configuration:nil
															   URL:storeURL
														   options:options
															 error:&error];
		NSAssert(store, @"E | %@:%@/%@ Error initializing PSC with a store:\n%@", [self class], NSStringFromSelector(_cmd), @(__LINE__), error);
	};

	//	is mainPSC init failed, give up
	{
		NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
		NSAssert(coordinator, @"E | %@:%@/%@ Failed to initialize coordinator", [self class], NSStringFromSelector(_cmd), @(__LINE__));
		connectPSC(coordinator);
		self.mainPSC = coordinator;
	}

	//	is writerPSC init failed, give up (should we?)
	{
		NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
		NSAssert(coordinator, @"E | %@:%@/%@ Failed to initialize coordinator", [self class], NSStringFromSelector(_cmd), @(__LINE__));
		connectPSC(coordinator);
		self.writerPSC = coordinator;
	}

	//	main MOC
	{
		NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
		moc.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;	//	this means that in case of conflicts, disk will override memory
		moc.persistentStoreCoordinator = self.mainPSC;
		self.mainManagedObjectContext = moc;
	}

	self.ready = YES;
	NSLog(@"I | %@:%@/%@ Core Data initialized with storeURL = %@", [self class], NSStringFromSelector(_cmd), @(__LINE__), [storeURL path]);

	[self commonInit];

	if (!self.initCallback) return;
	self.initCallback();
}

/**
 *	Listens for save notifications and merges them into mainMOC, so UI can use them
 *
 *	@param notification	Incoming NSManagedObjectContextDidSaveNotification notification
 */
- (void)handleMOCNotification:(NSNotification *)notification {

	NSArray *inserted = [notification.userInfo objectForKey:NSInsertedObjectsKey];
	NSArray *updated = [notification.userInfo objectForKey:NSUpdatedObjectsKey];
	NSArray *deleted = [notification.userInfo objectForKey:NSDeletedObjectsKey];
	//	is there anything to merge?
	if ([inserted count] == 0 && [updated count] == 0 && [deleted count] == 0) return;

	NSManagedObjectContext *savedContext = [notification object];

	// ignore change notifications from the main MOC
	if ([self.mainManagedObjectContext isEqual:savedContext]) {
		return;
	}

	// ignore change notifications from the direct child MOC. this will happen automatically
	if ([self.mainManagedObjectContext isEqual:savedContext.parentContext]) {
		return;
	}

	// ignore stuff from unknown PSCs
	if (![savedContext.persistentStoreCoordinator isEqual:self.mainPSC] && ![savedContext.persistentStoreCoordinator isEqual:self.writerPSC]) {
		return;
	}

	if (self.shouldMergeIncomingSavedObjects) {
		[self.mainManagedObjectContext performBlock:^{
			[self.mainManagedObjectContext mergeChangesFromContextDidSaveNotification:notification];
		}];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter] postNotificationName:RTCoreDataManagerDidMergeNotification object:self];
		});
	}
}



#pragma mark - Public

- (void)setMainMOCReadOnly:(BOOL)mainMOCReadOnly {

	if (_mainMOCReadOnly == mainMOCReadOnly) return;
	_mainMOCReadOnly = mainMOCReadOnly;

	self.mainManagedObjectContext.mergePolicy = (mainMOCReadOnly) ? NSMergeByPropertyStoreTrumpMergePolicy : NSRollbackMergePolicy;
}

- (NSManagedObjectContext *)importerManagedObjectContext {

	NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;	//	this means that objects in the MOC will override those in the store
	moc.persistentStoreCoordinator = self.writerPSC;

	return moc;
}

- (NSManagedObjectContext *)temporaryManagedObjectContext {

	NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	moc.mergePolicy = NSRollbackMergePolicy;	//	this means that any changes to the objects in the MOC will be discarded
	moc.persistentStoreCoordinator = self.mainPSC;

	return moc;
}

- (NSManagedObjectContext *)creatorManagedObjectContext {

	NSAssert(!self.isMainMOCReadOnly, @"E | %@:%@/%@ Can't use creatorMOC when RTCoreDataManager.mainMOCReadOnly is set to YES. Set it temporary to NO, make your changes, save them using saveWithCallback: and revert to YES inside the callback block.", [self class], NSStringFromSelector(_cmd), @(__LINE__));

	NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;	//	this means that objects in this MOC will override those in the parent (main) MOC
	moc.parentContext = self.mainManagedObjectContext;

	return moc;
}

@end
