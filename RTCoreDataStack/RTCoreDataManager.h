//
//  RTCoreDataManager.h
//  RTCoreDataStack
//
//  Created by Aleksandar Vacić on 13.7.15..
//  Copyright (c) 2015. Radiant Tap. All rights reserved.
//

@import Foundation;
@import CoreData;

typedef void (^InitCallbackBlock)(void);

@interface RTCoreDataManager : NSObject

@property (strong, readonly) NSManagedObjectContext *managedObjectContext;

//	init
- (instancetype)initWithCallback:(InitCallbackBlock)callback;
- (instancetype)initWithDataModel:(NSString *)dataModelName callback:(InitCallbackBlock)callback;

//	helpers
- (NSManagedObjectContext *)siblingManagedObjectContext;

//	actions
- (void)save;

@end
