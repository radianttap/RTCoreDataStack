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

#import "NSManagedObjectContext+RTCoreDataManager.h"

@implementation NSManagedObjectContext (RTCoreDataManager)

- (void)saveWithCallback:(void(^)(BOOL success, NSError *error))callback {

	if (![self hasChanges]) {
		NSLog(@"D | %@:%@/%@ Main MOC has no changes to save", [self class], NSStringFromSelector(_cmd), @(__LINE__));
		if (callback)
			callback(YES, nil);
		return;
	}

	//	performBlock* makes sure that anything inside is executed on the receiver's thread
	[self performBlockAndWait:^{
		NSError *error = nil;

		BOOL success = [self save:&error];
		if (!success || error) {
			NSLog(@"E | %@:%@/%@ Main MOC save failed with error\n%@", [self class], NSStringFromSelector(_cmd), @(__LINE__), error);
			if (callback)
				callback(success, error);
			return;
		}

		if (callback)
			callback(YES, nil);

		//	if there's parent Context, then save it asynchronously on its thread
		if (!self.parentContext) return;

		[self.parentContext performBlock:^{
			NSError *privateError = nil;
			BOOL privateSuccess = [self.parentContext save:&privateError];
			if (!privateSuccess || privateError) {
				NSLog(@"E | %@:%@/%@ Private MOC save failed with error\n%@", [self class], NSStringFromSelector(_cmd), @(__LINE__), privateError);
			}
		}];
	}];
}

@end
