//
//  AppDelegate.h
//  RTCoreDataStack
//
//  Created by Aleksandar Vacić on 13.7.15..
//  Copyright (c) 2015. Radiant Tap. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RTCoreDataManager;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong, readonly) RTCoreDataManager *coreDataManager;

@end

