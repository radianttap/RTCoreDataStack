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

@property (copy) InitCallbackBlock initCallback;

@end

@implementation RTCoreDataManager

- (instancetype)initWithCallback:(InitCallbackBlock)callback {

	if (!(self = [super init])) return nil;

	self.initCallback = callback;

	//	figure out the .momd file name
	NSArray *bundleDataModels = [[NSBundle mainBundle] pathsForResourcesOfType:@"momd" inDirectory:nil];
	NSAssert([bundleDataModels count] == 1, @"%@:%@ Found multiple data models, please use initWithDataModel:callback: to specify which one to use", [self class], NSStringFromSelector(_cmd));
	NSString *dataModelName = [[[bundleDataModels firstObject] lastPathComponent] stringByDeletingPathExtension];
	NSAssert([dataModelName length] > 0, @"%@:%@ Failed to extract data model name, please use initWithDataModel:callback: to specify it", [self class], NSStringFromSelector(_cmd));
	[self initializeCoreDataWithDataModel:dataModelName];

	return self;
}

- (instancetype)initWithDataModel:(NSString *)dataModelName callback:(InitCallbackBlock)callback {
	NSParameterAssert([dataModelName length] > 0);

	if (!(self = [super init])) return nil;

	self.initCallback = callback;
	[self initializeCoreDataWithDataModel:dataModelName];

	return self;
}

- (void)initializeCoreDataWithDataModel:(NSString *)dataModelName {
	if (self.managedObjectContext) return;

	NSURL *modelURL = [[NSBundle mainBundle] URLForResource:dataModelName withExtension:@"momd"];
	NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	NSAssert(mom, @"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));

	NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
	NSAssert(coordinator, @"Failed to initialize coordinator");

	//	private MOC, will be used to actualy write stuff to disk
	self.privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	self.privateContext.persistentStoreCoordinator = coordinator;

	//	main MOC, child of private one, to be used by main thread, for UI & rest
	self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
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
		NSURL *storeURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", dataModelName]];

		NSError *error = nil;
		NSAssert([psc addPersistentStoreWithType:NSSQLiteStoreType
								   configuration:nil
											 URL:storeURL
										 options:options
										   error:&error],
				 @"Error initializing PSC:\n%@", error);

		if (!self.initCallback) return;

		dispatch_sync(dispatch_get_main_queue(), ^{
			[self initCallback]();
		});
	});
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


#pragma mark - Private 



@end
