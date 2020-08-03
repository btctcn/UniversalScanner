//
//  USCScannerController.m
//  UniversalScanner
//
//  Created by Andrey Butcitcyn on 31.07.2020.
//  Copyright © 2020 Andrey Butcitcyn. All rights reserved.
//

#import "USCScannerController.h"
#import <AVKit/AVKit.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <Vision/Vision.h>


AVCaptureVideoOrientation avCaptureVideoOrientationFromUIDeviceOrientation(UIDeviceOrientation deviceOrientation){
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeRight;
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeLeft;
        default:
            return -1;
    }
}

@interface USCScannerController ()

typedef NS_ENUM(NSInteger, USCScannerMode){
    USCQRAndBarMode,
    USCCodeMode
};

@property (nonatomic, strong) CAShapeLayer *drawLayer;
@property (nonatomic, strong) NSArray *rectangle;
@property (nonatomic, readonly) USCScannerMode scannerMode;
@property (nonatomic, assign) BOOL isScannerInitialized;
@property (nonatomic, strong) NSValue *bounds;
@property (nonatomic, copy) NSString *currentQrOrBarCode;
@property (nonatomic, copy) NSString *currentTextualCode;

@property (nonatomic, strong) dispatch_queue_t captureSessionQueue;
@property (nonatomic, strong) dispatch_queue_t videoDataOutputQueue;
@property (nonatomic, strong) CAShapeLayer *maskLayer;
@property (nonatomic, assign) UIDeviceOrientation currentOrientation;
@property (nonatomic, assign) CGAffineTransform bottomToTopTransform;
@property (nonatomic, assign) CGAffineTransform uiRotationTransform;
@property (nonatomic, assign) CGRect regionOfInterest;
@property (nonatomic, assign) double bufferAspectRatio;
@property (nonatomic, assign) CGAffineTransform roiToGlobalTransform;
@property (nonatomic, assign) CGImagePropertyOrientation textOrientation;
@property (nonatomic, assign) CGAffineTransform visionToAVFTransform;
@property (nonatomic, strong) AVCaptureDevice *captureDevice;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;
@property (nonatomic, strong) VNRecognizeTextRequest *request;

@end

@implementation USCScannerController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.tabBarItem = [[UITabBarItem alloc]initWithTitle:@"Scanner" image:[UIImage imageNamed:@"gallery_selected"] tag:0];
    }
    return self;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    self.captureSessionQueue = dispatch_queue_create("CaptureSessionQueue", nil);
    self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", nil);
    self.cutoutView.backgroundColor = [UIColor.grayColor colorWithAlphaComponent:0.5];
    self.maskLayer = [CAShapeLayer new];
    self.maskLayer.backgroundColor = UIColor.clearColor.CGColor;
    self.maskLayer.fillRule = kCAFillRuleEvenOdd;
    self.cutoutView.layer.mask = self.maskLayer;
    self.bottomToTopTransform = CGAffineTransformTranslate(CGAffineTransformMakeScale(1, -1), 0, -1);
    self.uiRotationTransform = CGAffineTransformIdentity;
    self.regionOfInterest = CGRectMake(0, 0, 1, 1);
    self.roiToGlobalTransform = CGAffineTransformIdentity;
    self.textOrientation = kCGImagePropertyOrientationUp;
    self.visionToAVFTransform = CGAffineTransformIdentity;
    self.captureSession = [AVCaptureSession new];
    self.videoDataOutput = [AVCaptureVideoDataOutput new];
    self.metadataOutput = [AVCaptureMetadataOutput new];
    UITapGestureRecognizer *tapGestureRecognizer = [UITapGestureRecognizer new];
    [tapGestureRecognizer addTarget:self action:@selector(handleTap)];
    [self.numberView addGestureRecognizer:tapGestureRecognizer];
    self.request = [[VNRecognizeTextRequest alloc]initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        [self recognizeTextHandler:request error:error];
    }];
    self.previewView.session = self.captureSession;
    
    dispatch_async(self.captureSessionQueue, ^{
        [self setupCamera];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self calculateRegionOfInterest];
        });
    });
    
    //init capture button
    UITapGestureRecognizer *tapRecognizer = [UITapGestureRecognizer new];
    tapRecognizer.delegate = self;
    [tapRecognizer addTarget:self action:@selector(captureButtonTapped)];
    [self.captureButton addGestureRecognizer:tapRecognizer];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
    if(UIDeviceOrientationIsPortrait(deviceOrientation) || UIDeviceOrientationIsLandscape(deviceOrientation)){
        self.currentOrientation = deviceOrientation;
    }
    
    AVCaptureVideoOrientation newOrientation = avCaptureVideoOrientationFromUIDeviceOrientation(deviceOrientation);
    if(newOrientation >= AVCaptureVideoOrientationPortrait){
        self.previewView.videoPreviewLayer.connection.videoOrientation = newOrientation;
    }
    
    [self calculateRegionOfInterest];
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    [self updateCutout];
}

-(void)updateCutout{
    CGAffineTransform roiRectTransform = CGAffineTransformConcat(self.bottomToTopTransform, self.uiRotationTransform);
    CGRect cutout = [self.previewView.videoPreviewLayer rectForMetadataOutputRectOfInterest:CGRectApplyAffineTransform(self.regionOfInterest, roiRectTransform)];
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.cutoutView.frame];
    [path appendPath:[UIBezierPath bezierPathWithRect:cutout]];
    self.maskLayer.path = path.CGPath;
    
    CGRect numFrame = cutout;
    numFrame.origin.y += numFrame.size.height;
    self.numberView.frame = numFrame;
}

- (void) setupCamera{
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if(!captureDevice) {
        NSLog(@"Could not create capture device.");
        return;
    }
    self.captureDevice = captureDevice;
    if([captureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset3840x2160]){
        self.captureSession.sessionPreset = AVCaptureSessionPreset3840x2160;
        self.bufferAspectRatio = 3840.0 / 2160.0;
    }
    else{
        self.captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
        self.bufferAspectRatio = 1920.0 / 1080.0;
    }
    
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
    if(!deviceInput){
        NSLog(@"Could not create device input.");
        return;
    }
    
    if([self.captureSession canAddInput:deviceInput]){
        [self.captureSession addInput:deviceInput];
    }
    
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
    self.videoDataOutput.videoSettings = @{(NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    if([self.captureSession canAddOutput:self.videoDataOutput]){
        [self.captureSession addOutput:self.videoDataOutput];
        [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo].preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeOff;
    } else {
        NSLog(@"Could not add VDO output");
        return;
    }
    
    [self.metadataOutput setMetadataObjectsDelegate:self queue:self.videoDataOutputQueue];
    
    if([self.captureSession canAddOutput:self.metadataOutput]){
        [self.captureSession addOutput:self.metadataOutput];
        //[self.metadataOutput connectionWithMediaType:AVMediaTypeVideo].preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeOff;
        self.metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeUPCECode,
                                            AVMetadataObjectTypeCode39Code,
                                            AVMetadataObjectTypeCode39Mod43Code,
                                            AVMetadataObjectTypeEAN13Code,
                                            AVMetadataObjectTypeEAN8Code,
                                            AVMetadataObjectTypeCode93Code,
                                            AVMetadataObjectTypeCode128Code,
                                            AVMetadataObjectTypePDF417Code,
                                            AVMetadataObjectTypeQRCode,
                                            AVMetadataObjectTypeAztecCode,
                                            AVMetadataObjectTypeInterleaved2of5Code,
                                            AVMetadataObjectTypeITF14Code,
                                            AVMetadataObjectTypeDataMatrixCode
        ];
    } else {
        NSLog(@"Could not add metadata output");
        return;
    }
    
    @try {
        [self.captureDevice lockForConfiguration:nil];
        self.captureDevice.videoZoomFactor = 2;
        self.captureDevice.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear;
        [self.captureDevice unlockForConfiguration];
    } @catch (NSException *exception) {
        NSLog(@"Could not set zoom level due to error %@", exception);
    }
    
    [self.captureSession startRunning];
}

-(void)showString:(NSString *)string{
    dispatch_sync(self.captureSessionQueue, ^{
        [self.captureSession stopRunning];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.numberView.text = string;
            self.numberView.hidden = NO;
        });
    });
}

-(void)handleTap{
    dispatch_async(self.captureSessionQueue, ^{
        if(!self.captureSession.isRunning){
            [self.captureSession startRunning];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.numberView.hidden = YES;
        });
    });
}

-(void) calculateRegionOfInterest{
    CGFloat desiredHeightRatio = 0.15;
    CGFloat desiredWidthRatio = 0.6;
    CGFloat maxPortraitWidth = 0.8;
    
    CGSize size;
    
    if(UIDeviceOrientationIsPortrait(self.currentOrientation) || self.currentOrientation == UIDeviceOrientationUnknown){
        size = CGSizeMake(MIN(desiredWidthRatio * self.bufferAspectRatio, maxPortraitWidth), desiredHeightRatio / self.bufferAspectRatio);
    }
    else{
        size = CGSizeMake(desiredWidthRatio, desiredHeightRatio);
    }
    
    CGRect rect = {CGPointMake((1 - size.width) / 2, (1 - size.height) / 2), size};
    self.regionOfInterest = rect;
    
    [self setupOrientationAndTransform];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCutout];
    });
}

- (void) setupOrientationAndTransform{
    CGRect roi = self.regionOfInterest;
    
    self.roiToGlobalTransform = CGAffineTransformScale(CGAffineTransformMakeTranslation(roi.origin.x, roi.origin.y), roi.size.width, roi.size.height);
    
    switch (self.currentOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            self.textOrientation = kCGImagePropertyOrientationUp;
            self.uiRotationTransform = CGAffineTransformIdentity;
            break;
        case UIDeviceOrientationLandscapeRight:
            self.textOrientation = kCGImagePropertyOrientationDown;
            self.uiRotationTransform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(1,1), M_PI);
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            self.textOrientation = kCGImagePropertyOrientationLeft;
            self.uiRotationTransform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(1,0), M_PI/2);
            break;
        default:
            self.textOrientation = kCGImagePropertyOrientationRight;
            self.uiRotationTransform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(0,1), -M_PI/2);
            break;
    }
    
    self.visionToAVFTransform = CGAffineTransformConcat(CGAffineTransformConcat(self.roiToGlobalTransform, self.bottomToTopTransform), self.uiRotationTransform);
}

-(void)captureButtonTapped{
    self.captureButton.isPressed = YES;
    [self.captureButton setNeedsDisplay];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^(void){
        self.captureButton.isPressed = NO;
        [self.captureButton setNeedsDisplay];
    });
    if(self.scannerMode == USCQRAndBarMode){
        //save self.currentQrOrBarCode
    }
    else{
        //        UIGraphicsBeginImageContext(CGSizeMake(self.view.frame.size.width, self.view.frame.size.height));
        //        [self.view drawViewHierarchyInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) afterScreenUpdates:NO];
        //        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        //        UIGraphicsEndImageContext();
        
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
            UIGraphicsBeginImageContextWithOptions(UIApplication.sharedApplication.windows[0].bounds.size, NO, [UIScreen mainScreen].scale);
        } else {
            UIGraphicsBeginImageContext(UIApplication.sharedApplication.windows[0].bounds.size);
        }
        
        [UIApplication.sharedApplication.windows[0].layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        CIImage *ciImage = image.CIImage;
        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeRectangle
                                                  context:nil
                                                  options:@{CIDetectorAccuracy:CIDetectorAccuracyLow,
                                                            CIDetectorTracking:@YES,
                                                            CIDetectorMinFeatureSize:@.5f}];
        
        NSArray<CIRectangleFeature *> *rectangleFeatures = (NSArray<CIRectangleFeature *> *)[detector featuresInImage:ciImage];
        for (CIRectangleFeature *rect in rectangleFeatures)
        {
            //find a proper rect, like card's width / height = 4:3
            //following procedure is just an example, adjust it to fit your real needs.
            CGFloat width = fabs(rect.topRight.x - rect.topLeft.x);
            CGFloat height = fabs(rect.topLeft.y - rect.bottomLeft.y);
            if ((width / height - 4 / 3) <= 0.1) {
                CIImage *cardImage = [ciImage imageByCroppingToRect:rect.bounds]; //or create a custom rect to crop if it's not good.
                CGRect greenRect = CGRectMake(0, rect.bounds.size.height * 0.8, rect.bounds.size.width, rect.bounds.size.height * 0.2); //in image coordinates
                CIImage *greenRectCIImage = [cardImage imageByCroppingToRect:greenRect];
                
                UIImage *greenRectImage = [[UIImage alloc] initWithCIImage:greenRectCIImage];
                //use greenRectImage for OCR
                return;
            }
        }
        
    }
}


-(USCScannerMode)scannerMode{
    return self.segmentedControl.selectedSegmentIndex == 0 ? USCQRAndBarMode : USCCodeMode;
}

- (IBAction)segmentedControlValueChanged:(id)sender {
    [self changeCaptureRectangleVisibility];
    if(self.scannerMode == USCQRAndBarMode){
        self.rectangle = nil;
        [self.captureButton setTitle:@"" forState:UIControlStateNormal];
        self.captureButton.userInteractionEnabled = NO;
    }
    else{
        self.rectangle = nil;
        [self.captureButton setTitle:@"Take" forState:UIControlStateNormal];
        self.captureButton.userInteractionEnabled = YES;
    }
}

-(void)changeCaptureRectangleVisibility{
    [self.drawLayer setNeedsDisplay];
}

#pragma mark AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    if(metadataObjects.count > 0)
        NSLog(@"AVCaptureMetadataOutputObjectsDelegate");
//    if(metadataObjects.count > 0){
//        AVMetadataMachineReadableCodeObject *ro = (AVMetadataMachineReadableCodeObject*)[self.previewLayer transformedMetadataObjectForMetadataObject:metadataObjects[0]];
//        self.bounds = [NSValue valueWithCGRect:ro.bounds];
//        CGPoint p0;
//        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[0], &p0);
//        CGPoint p1;
//        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[1], &p1);
//        CGPoint p2;
//        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[2], &p2);
//        CGPoint p3;
//        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[3], &p3);
//        self.rectangle = @[[NSValue valueWithCGPoint:p0],
//                           [NSValue valueWithCGPoint:p1],
//                           [NSValue valueWithCGPoint:p2],
//                           [NSValue valueWithCGPoint:p3]];
//
//        if(self.scannerMode == USCQRAndBarMode){
//            [self.captureButton setTitle:@"Take" forState:UIControlStateNormal];
//            self.captureButton.userInteractionEnabled = YES;
//            self.currentQrOrBarCode = ro.stringValue;
//        }
//    }
//    else{
//        self.rectangle = nil;
//        [self.captureButton setTitle:@"" forState:UIControlStateNormal];
//        self.captureButton.userInteractionEnabled = NO;
//    }
//
//    [self.drawLayer setNeedsDisplay];
}

#pragma mark CALayerDelegate
- (void)drawLayer:(CALayer*)layer inContext:(CGContextRef)ctx {
    if(self.scannerMode == USCQRAndBarMode){
        if(!_rectangle) {
            CGContextClearRect(ctx, layer.bounds);
            return;
        }
        //        CGPoint origin = [self.rectangle[0] CGPointValue];
        //        CGPoint bottomRight = [self.rectangle[2] CGPointValue];
        //        CGSize size = CGSizeMake(bottomRight.x - origin.x, bottomRight.y - origin.y);
        //        [self drawRoundedRect:CGRectMake(origin.x, origin.y, size.width, size.height) andContext:ctx];
        //        [self drawRoundedRect:[self.bounds CGRectValue]  andContext:ctx];
        
        CGPoint p0 = [self.rectangle[0] CGPointValue];
        CGPoint p1 = [self.rectangle[1] CGPointValue];
        CGPoint p2 = [self.rectangle[2] CGPointValue];
        CGPoint p3 = [self.rectangle[3] CGPointValue];
        
        [self drawPath:p0 p1:p1 p2:p2 p3:p3 andContext:ctx];
    }
    else {
        CGRect layerRect = self.drawLayer.bounds;
        CGRect rect = CGRectMake(40, layerRect.size.height / 2 - 40, layerRect.size.width - 80, 80);
        [self drawRoundedRect:rect andContext:ctx];
    }
}

-(void)drawRoundedRect:(CGRect)rect andContext :(CGContextRef)ctx{
    
    CGContextSetRGBStrokeColor(ctx, 255, 255, 0, 1.0);
    CGContextSetLineWidth(ctx, 5);
    
    CGRect rrect = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    CGFloat radius = 10.0;
    CGFloat minx = CGRectGetMinX(rrect), midx = CGRectGetMidX(rrect), maxx = CGRectGetMaxX(rrect);
    CGFloat miny = CGRectGetMinY(rrect), midy = CGRectGetMidY(rrect), maxy = CGRectGetMaxY(rrect);
    CGContextMoveToPoint(ctx, minx, midy);
    CGContextAddArcToPoint(ctx, minx, miny, midx, miny, radius);
    CGContextAddArcToPoint(ctx, maxx, miny, maxx, midy, radius);
    CGContextAddArcToPoint(ctx, maxx, maxy, midx, maxy, radius);
    CGContextAddArcToPoint(ctx, minx, maxy, minx, midy, radius);
    CGContextClosePath(ctx);
    CGContextDrawPath(ctx, kCGPathStroke);
}

-(void)drawPath:(CGPoint)p0 p1:(CGPoint)p1 p2:(CGPoint)p2 p3:(CGPoint)p3 andContext :(CGContextRef)ctx{
    
    CGContextSetRGBStrokeColor(ctx, 255, 255, 0, 1.0);
    CGContextSetLineWidth(ctx, 5);
    
    CGContextMoveToPoint(ctx, p0.x, p0.y);
    CGContextAddLineToPoint(ctx, p1.x, p1.y);
    CGContextAddLineToPoint(ctx, p2.x, p2.y);
    CGContextAddLineToPoint(ctx, p3.x, p3.y);
    CGContextClosePath(ctx);
    CGContextDrawPath(ctx, kCGPathStroke);
}

#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    self.request.recognitionLevel = VNRequestTextRecognitionLevelFast;
    self.request.usesLanguageCorrection = NO;
    self.request.regionOfInterest = self.regionOfInterest;
    VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer orientation:self.textOrientation options:@{}];
    @try {
        [requestHandler performRequests:@[self.request] error:nil];
    } @catch (NSException *exception) {
        NSLog(@"%@", exception);
    }
}

-(void) recognizeTextHandler:(VNRequest * _Nonnull)request error:(NSError * _Nullable) error{
    if(request.results.count > 0){
    NSLog(@"recognizeTextHandler %@", request.results);
    }
}
@end


