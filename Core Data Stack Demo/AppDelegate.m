//
//  AppDelegate.m
//  RTCoreDataStack
//
//  Created by Aleksandar Vacić on 13.7.15..
//  Copyright (c) 2015. Radiant Tap. All rights reserved.
//

#import "AppDelegate.h"
#import "RTCoreDataManager.h"
#import "ViewController.h"

@interface AppDelegate ()

@property (nonatomic, strong, readwrite) RTCoreDataManager *coreDataManager;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.backgroundColor = [UIColor whiteColor];

	//	dummy VC, to show while the CDM is being prepared
	ViewController *vc = [[ViewController alloc] init];
	UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:vc];
	self.window.rootViewController = nc;

	//	bring CDM up
	self.coreDataManager = [[RTCoreDataManager alloc] initWithCallback:^{
		[self processCoreDataCallback];
	}];

	return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

	[self.window makeKeyAndVisible];

	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {

}

- (void)applicationDidEnterBackground:(UIApplication *)application {

}

- (void)applicationWillTerminate:(UIApplication *)application {

}

#pragma mark - Core Data callbacks

- (void)processCoreDataCallback {

	//	all is ready, transfer CDM to the top controller
	//	which should then reload its content

	UINavigationController *nc = (UINavigationController *)self.window.rootViewController;
	ViewController *vc = (ViewController *)nc.topViewController;
	vc.coreDataManager = self.coreDataManager;
}


@end
