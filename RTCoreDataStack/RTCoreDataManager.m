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

#import "RTCoreDataManager.h"
#import "NSManagedObjectContext+RTCoreDataManager.h"

@interface RTCoreDataManager ()

@property (strong, readwrite) NSManagedObjectContext *managedObjectContext;
@property (strong) NSManagedObjectContext *privateContext;
@property (readwrite, getter=isReady) BOOL ready;

@property (copy) InitCallbackBlock initCallback;

@end

@implementation RTCoreDataManager

//	## two ways to use CDM
//	## the only difference is here in the init, the rest is all the same
//	1. singleton

+ (RTCoreDataManager *)defaultManager {
	static RTCoreDataManager *defaultManager = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		defaultManager = [[RTCoreDataManager alloc] init];
		defaultManager.ready = NO;
		defaultManager.initCallback = nil;
	});

	return defaultManager;
}

- (void)setupWithCallback:(InitCallbackBlock)callback {

	_initCallback = callback;

	//	will use default store path
	NSURL *storeURL = [RTCoreDataManager defaultStoreURL];
	//	will merge all models in the bundle
	NSManagedObjectModel *model = [self managedObjectModelNamed:nil];
	[self initializeCoreDataWithModel:model storeURL:storeURL];

	[self commonInit];
}

- (void)setupWithDataModelNamed:(NSString *)dataModelName callback:(InitCallbackBlock)callback {

	_initCallback = callback;

	//	will use default store path
	NSURL *storeURL = [RTCoreDataManager defaultStoreURL];

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

	_ready = NO;
	_initCallback = callback;

	//	will use default store path
	NSURL *storeURL = [RTCoreDataManager defaultStoreURL];
	NSString *cleanAppName = [self cleanAppName];
	storeURL = [storeURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", cleanAppName]];
	//	will merge all models in the bundle
	NSManagedObjectModel *model = [self managedObjectModelNamed:nil];
	[self initializeCoreDataWithModel:model storeURL:storeURL];

	[self commonInit];

	return self;
}

- (instancetype)initWithDataModelNamed:(NSString *)dataModelName callback:(InitCallbackBlock)callback {

	//	will use default store path
	NSURL *storeURL = [RTCoreDataManager defaultStoreURL];
	NSString *cleanAppName = [self cleanAppName];
	storeURL = [storeURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", cleanAppName]];
	return [self initWithDataModelNamed:dataModelName storeURL:storeURL callback:callback];
}

- (instancetype)initWithDataModelNamed:(NSString *)dataModelName storeURL:(NSURL *)storeURL callback:(InitCallbackBlock)callback {

	NSParameterAssert([dataModelName length] > 0);

	if (!(self = [super init])) return nil;

	_ready = NO;
	_initCallback = callback;

	NSManagedObjectModel *model = [self managedObjectModelNamed:dataModelName];
	[self initializeCoreDataWithModel:model storeURL:storeURL];

	[self commonInit];

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
	if (self.managedObjectContext) {
		self.ready = YES;
		return;
	}

	//	is model is not supplied, give up
	NSAssert(mom, @"E | %@:%@/%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd), @(__LINE__));

	//	is PSC init failed, give up
	NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
	NSAssert(coordinator, @"E | %@:%@/%@ Failed to initialize coordinator", [self class], NSStringFromSelector(_cmd), @(__LINE__));

	//	make sure storeURL is usable URL
	BOOL isDirectory = NO;
	NSURL *directoryURL = [storeURL URLByDeletingLastPathComponent];
	BOOL doesDirectoryExists = [[NSFileManager defaultManager] fileExistsAtPath:[directoryURL path] isDirectory:&isDirectory];
	NSAssert(doesDirectoryExists, @"E | %@:%@/%@ StoreURL param points to non-existing directory", [self class], NSStringFromSelector(_cmd), @(__LINE__));

	//	private MOC, will be used to actualy write stuff to disk
	self.privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	self.privateContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;	//	this means that store takes precedence when resolving conflicts
	self.privateContext.persistentStoreCoordinator = coordinator;

	//	main MOC, child of private one, to be used by main thread, for UI & rest
	self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
	self.managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;	//	this means that parent context takes precedence when resolving conflicts
	self.managedObjectContext.parentContext = self.privateContext;

	//	create / connect with the store on the disk
	NSPersistentStoreCoordinator *psc = self.privateContext.persistentStoreCoordinator;

	NSDictionary *options = @{
							  NSMigratePersistentStoresAutomaticallyOption: @(YES),
							  NSInferMappingModelAutomaticallyOption: @(YES),
							  NSSQLitePragmasOption: @{ @"journal_mode":@"DELETE" }
							  };

	NSError *error = nil;
	NSAssert([psc addPersistentStoreWithType:NSSQLiteStoreType
							   configuration:nil
										 URL:storeURL
									 options:options
									   error:&error],
			 @"E | %@:%@/%@ Error initializing PSC:\n%@", [self class], NSStringFromSelector(_cmd), @(__LINE__), error);

	self.ready = YES;
	NSLog(@"I | %@:%@/%@ Core Data initialized with storeURL = %@", [self class], NSStringFromSelector(_cmd), @(__LINE__), [storeURL path]);

	if (!self.initCallback) return;
	[self initCallback]();
}

- (void)handleMOCNotification:(NSNotification *)notification {

	NSManagedObjectContext *savedContext = [notification object];

	// ignore change notifications from the main MOC
	if ([self.managedObjectContext isEqual:savedContext]) {
		return;
	}

	// ignore change notifications from the direct child MOC
	if ([self.managedObjectContext isEqual:savedContext.parentContext]) {
		return;
	}

	// ignore change notifications from the parent MOC
	if ([self.managedObjectContext.parentContext isEqual:savedContext]) {
		return;
	}

	// ignore if not from current database
	if (![self.privateContext.persistentStoreCoordinator isEqual:savedContext.persistentStoreCoordinator]) {
		return;
	}

	NSArray *inserted = [notification.userInfo objectForKey:NSInsertedObjectsKey];
	NSArray *updated = [notification.userInfo objectForKey:NSUpdatedObjectsKey];
	NSArray *deleted = [notification.userInfo objectForKey:NSDeletedObjectsKey];
	if ([inserted count] == 0 && [updated count] == 0 && [deleted count] == 0) return;

	[self.managedObjectContext performSelectorOnMainThread:@selector(mergeChangesFromContextDidSaveNotification:)
												withObject:notification
											 waitUntilDone:YES];
}




#pragma mark - Public

//	this creates private MOC, directly attached to PSC
//	use it for background imports
//	its mergePolicy is set to favor items in memory versus those on disk, which means newly imported objects take precedence
- (NSManagedObjectContext *)importerManagedObjectContext {

	NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;	//	this means that objects in the MOC will override those in the store
	moc.persistentStoreCoordinator = self.privateContext.persistentStoreCoordinator;

	return moc;
}

//	this creates private MOC, directly attached to PSC
//	use it for temporary objects, since NSManagedObject does not have copy attribute
//	its mergePolicy is set so that data on disk is never altered
- (NSManagedObjectContext *)temporaryManagedObjectContext {

	NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	moc.mergePolicy = NSRollbackMergePolicy;	//	this means that any changes to the objects in the MOC will be discarded
	moc.persistentStoreCoordinator = self.privateContext.persistentStoreCoordinator;

	return moc;
}

//	this creates child MOC for the main MOC
//	use it to create new objects to add into (say add new person into Address Book, new document etc)
//	its mergePolicy is set to favor items in memory versus those on disk, which means newly created objects take precedence
- (NSManagedObjectContext *)creatorManagedObjectContext {

	NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;	//	this means that objects in this MOC will override those in the parent (main) MOC
	moc.parentContext = self.managedObjectContext;

	return moc;
}

- (void)saveMainContext {
	if (![self.privateContext hasChanges] && ![self.managedObjectContext hasChanges]) {
		NSLog(@"D | %@:%@/%@ Nothing to save in either main or private MOC", [self class], NSStringFromSelector(_cmd), @(__LINE__));
		return;
	}

	[self.managedObjectContext saveWithCallback:^(BOOL success, NSError *error) {

		if (!success || error) {
			//	error during the save
			NSLog(@"E | %@:%@/%@ Main/Private MOC save failed with error\n%@", [self class], NSStringFromSelector(_cmd), @(__LINE__), error);
			return;
		}

		NSLog(@"D | %@:%@/%@ Main/Private MOC saved.", [self class], NSStringFromSelector(_cmd), @(__LINE__));
	}];
}


@end
