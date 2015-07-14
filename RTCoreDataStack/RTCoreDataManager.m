//
//  RTCoreDataManager.m
//  RTCoreDataStack
//
//  Created by Aleksandar Vacić on 13.7.15..
//  Copyright (c) 2015. Radiant Tap. All rights reserved.
//

#import "RTCoreDataManager.h"

@interface RTCoreDataManager ()

@property (strong, readwrite) NSManagedObjectContext *managedObjectContext;
@property (strong) NSManagedObjectContext *privateContext;
@property (readwrite, getter=isReady) BOOL ready;

@property (copy) InitCallbackBlock initCallback;

@end

@implementation RTCoreDataManager

- (instancetype)initWithCallback:(InitCallbackBlock)callback {

	if (!(self = [super init])) return nil;

	_ready = NO;
	_initCallback = callback;

	//	will merge all models in the bundle
	NSManagedObjectModel *model = [self managedObjectModelNamed:nil];
	[self initializeCoreDataWithModel:model];

	[self commonInit];

	return self;
}

- (instancetype)initWithDataModel:(NSString *)dataModelName callback:(InitCallbackBlock)callback {
	NSParameterAssert([dataModelName length] > 0);

	if (!(self = [super init])) return nil;

	_ready = NO;
	_initCallback = callback;

	NSManagedObjectModel *model = [self managedObjectModelNamed:dataModelName];
	[self initializeCoreDataWithModel:model];

	[self commonInit];

	return self;
}

- (void)commonInit {

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMOCNotification:) name:NSManagedObjectContextDidSaveNotification object:nil];
}

- (void)dealloc {

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Public

//	this creates private MOC, directly attached to PSC
//	use it for background imports
- (NSManagedObjectContext *)importerManagedObjectContext {

	NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;	//	this means that objects in the MOC will override those in the store
	moc.persistentStoreCoordinator = self.privateContext.persistentStoreCoordinator;

	return moc;
}

//	this creates child MOC for the main MOC
//	use it to create new objects to add into (say add new person into Address Book, new document etc)
- (NSManagedObjectContext *)creatorManagedObjectContext {

	NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;	//	this means that objects in this MOC will override those in the parent (main) MOC
	moc.parentContext = self.managedObjectContext;

	return moc;
}

- (void)save {
	if (![self.privateContext hasChanges] && ![self.managedObjectContext hasChanges]) return;

	[self.managedObjectContext performBlockAndWait:^{
		NSError *error = nil;

		NSAssert([self.managedObjectContext save:&error], @"Failed to save main context:\n%@", error);

		[self.privateContext performBlock:^{
			NSError *privateError = nil;
			NSAssert([self.privateContext save:&privateError], @"Error saving private context:\n%@", privateError);
		}];
	}];
}

- (void)saveWithCallback:(void(^)(BOOL success, NSError *error))callback {
	if (![self.privateContext hasChanges] && ![self.managedObjectContext hasChanges]) {
		if (callback)
			callback(YES, nil);
		return;
	}

	[self.managedObjectContext performBlockAndWait:^{
		NSError *error = nil;

		BOOL success = [self.managedObjectContext save:&error];
		if (!success || error) {
			if (callback)
				callback(success, error);
			return;
		}

		[self.privateContext performBlock:^{
			NSError *privateError = nil;
			BOOL privateSuccess = [self.privateContext save:&privateError];
			if (!privateSuccess || privateError) {
				if (callback)
					callback(privateSuccess, privateError);
				return;
			}
		}];
	}];
}


#pragma mark - Private 

- (NSManagedObjectModel *)managedObjectModelNamed:(NSString *)dataModelName {

	NSManagedObjectModel *mom = nil;

	if ([dataModelName length] == 0) {
		//	nothing specified, merge all data models found in the store
		[NSManagedObjectModel mergedModelFromBundles:@[[NSBundle mainBundle]]];

	} else {
		NSURL *modelURL = [[NSBundle mainBundle] URLForResource:dataModelName withExtension:@"momd"];
		mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	}

	return mom;
}

- (void)initializeCoreDataWithModel:(NSManagedObjectModel *)mom {
	if (self.managedObjectContext) {
		self.ready = YES;
		return;
	}

	NSAssert(mom, @"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));

	NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
	NSAssert(coordinator, @"Failed to initialize coordinator");

	//	private MOC, will be used to actualy write stuff to disk
	self.privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	self.privateContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;	//	this means that store takes precedence when resolving conflicts
	self.privateContext.persistentStoreCoordinator = coordinator;

	//	main MOC, child of private one, to be used by main thread, for UI & rest
	self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
	self.managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;	//	this means that parent context takes precedence when resolving conflicts
	self.managedObjectContext.parentContext = self.privateContext;

	//	create / connect with the store on the disk
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		NSPersistentStoreCoordinator *psc = self.privateContext.persistentStoreCoordinator;

		NSDictionary *options = @{
								  NSMigratePersistentStoresAutomaticallyOption: @(YES),
								  NSInferMappingModelAutomaticallyOption: @(YES),
								  NSSQLitePragmasOption: @{ @"journal_mode":@"DELETE" }
								  };

		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSURL *documentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
		NSString *cleanAppName = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] stringByTrimmingCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
		NSURL *storeURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", cleanAppName]];

		NSError *error = nil;
		NSAssert([psc addPersistentStoreWithType:NSSQLiteStoreType
								   configuration:nil
											 URL:storeURL
										 options:options
										   error:&error],
				 @"Error initializing PSC:\n%@", error);

		self.ready = YES;
		if (!self.initCallback) return;

		dispatch_sync(dispatch_get_main_queue(), ^{
			[self initCallback]();
		});
	});
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

	// check if this is from current database
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

@end
