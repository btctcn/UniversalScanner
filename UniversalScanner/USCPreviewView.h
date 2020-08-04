//
//  USCPreviewView.h
//  UniversalScanner
//
//  Created by Andrey Butcitcyn on 02.08.2020.
//  Copyright © 2020 Andrey Butcitcyn. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface USCPreviewView : UIView

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, readonly) CAShapeLayer *drawLayer;

@end

NS_ASSUME_NONNULL_END
