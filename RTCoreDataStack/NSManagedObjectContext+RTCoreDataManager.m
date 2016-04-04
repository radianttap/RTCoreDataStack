/*
 NSManagedObjectContext+RTCoreDataManager.m
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

#import "NSManagedObjectContext+RTCoreDataManager.h"

@implementation NSManagedObjectContext (RTCoreDataManager)

/**
 *	IMPORTANT: Until this notice is removed, consider this method very lightly tested
 *	Works well for main=parent / creator=child MOC combination. Other uses not tested in real life situation.
 */
- (void)saveWithCallback:(void(^)(BOOL success, NSError *error))callback {

	if (![self hasChanges]) {
		NSLog(@"D | %@:%@/%@ MOC has no changes to save", [self class], NSStringFromSelector(_cmd), @(__LINE__));
		if (callback)
			callback(YES, nil);
		return;
	}

	if (self.concurrencyType == NSPrivateQueueConcurrencyType) {
		//	this is SYNC call, so can only be used on background thread.
		//	if used on main thread, it will lock up your app

		//	why use this here? to prevent "optimistic locking failure" error if you have multiple concurrent background saves
		[self performBlockAndWait:^{
			NSError *error = nil;

			BOOL success = [self save:&error];
			if (!success || error) {
				NSLog(@"E | %@:%@/%@ MOC save failed with error\n%@", [self class], NSStringFromSelector(_cmd), @(__LINE__), error);
				if (callback)
					callback(success, error);
				return;
			}

			if (self.parentContext) {
				[self.parentContext saveWithCallback:callback];
				return;
			}

			if (callback)
				callback(YES, nil);
		}];

	} else {
		//	performBlockAndWait: is a sync call and should not be used on main thread
		//	so falling back to async call if on main thread
		//	(same goes for older thread confinement MOC, which you should not be using anw)
		[self performBlock:^{
			NSError *error = nil;

			BOOL success = [self save:&error];
			if (!success || error) {
				NSLog(@"E | %@:%@/%@ MOC save failed with error\n%@", [self class], NSStringFromSelector(_cmd), @(__LINE__), error);
				if (callback)
					callback(success, error);
				return;
			}

			if (self.parentContext) {
				[self.parentContext saveWithCallback:callback];
				return;
			}

			if (callback)
				callback(YES, nil);
		}];
	}
}

@end
