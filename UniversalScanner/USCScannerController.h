//
//  USCScannerController.h
//  UniversalScanner
//
//  Created by Andrey Butcitcyn on 31.07.2020.
//  Copyright © 2020 Andrey Butcitcyn. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import "USCCaptureButton.h"
#import "USCPreviewView.h"
#import "USCDataService.h"

NS_ASSUME_NONNULL_BEGIN

@interface USCScannerController : UIViewController <AVCaptureMetadataOutputObjectsDelegate, CALayerDelegate, UIGestureRecognizerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
- (IBAction)segmentedControlValueChanged:(id)sender;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property (weak, nonatomic) IBOutlet USCCaptureButton *captureButton;
@property (weak, nonatomic) IBOutlet USCPreviewView *previewView;
@property (weak, nonatomic) IBOutlet UIView *cutoutView;
@property (weak, nonatomic) IBOutlet UILabel *numberView;

- (instancetype)initWithDataService:(id<USCDataService>)dataService;

@end



NS_ASSUME_NONNULL_END
