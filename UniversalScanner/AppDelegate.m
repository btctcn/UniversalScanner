//
//  AppDelegate.m
//  UniversalScanner
//
//  Created by Andrey Butcitcyn on 31.07.2020.
//  Copyright © 2020 Andrey Butcitcyn. All rights reserved.
//

#import "AppDelegate.h"
#import "USCTabBarController.h"
#import "UIColor+Additions.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    UITabBar.appearance.barTintColor = UIColor.whiteColor;
    UITabBar.appearance.tintColor = [UIColor fromHex:0x101010];
    
    self.window = [[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];
    [self.window makeKeyAndVisible];
    self.window.rootViewController = [USCTabBarController new];
    
    return YES;
}


@end
