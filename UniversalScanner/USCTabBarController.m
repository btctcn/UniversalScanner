//
//  USCTabBarController.m
//  UniversalScanner
//
//  Created by Andrey Butcitcyn on 31.07.2020.
//  Copyright © 2020 Andrey Butcitcyn. All rights reserved.
//

#import "USCTabBarController.h"
#import "USCScannerController.h"
#import "USCHistoryController.h"

@interface USCTabBarController ()

@end

@implementation USCTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    USCHistoryController *historyController = [USCHistoryController new];
    USCScannerController *scannerController = [[USCScannerController alloc] initWithDataService:historyController];
    self.viewControllers = @[
        scannerController,
        historyController
    ];
    
    self.selectedIndex = 0;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskPortrait;
}


@end
