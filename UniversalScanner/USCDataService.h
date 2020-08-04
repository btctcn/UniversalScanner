//
//  USCDataService.h
//  UniversalScanner
//
//  Created by Andrey Butcitcyn on 04.08.2020.
//  Copyright © 2020 Andrey Butcitcyn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol USCDataService <NSObject>

@required
-(void)addEntry:(NSString*)entry;

@end

NS_ASSUME_NONNULL_END
