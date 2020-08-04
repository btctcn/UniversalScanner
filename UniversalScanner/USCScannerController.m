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
#import "USCDataService.h"

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

@property (nonatomic, readonly) CAShapeLayer *drawLayer;
@property (nonatomic, strong) NSArray *rectangle;
@property (nonatomic, assign) USCScannerMode scannerMode;
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
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) NSMutableArray<CAShapeLayer*>* boxLayer;
@property (nonatomic, weak) id<USCDataService> dataService;

@end

@implementation USCScannerController

- (instancetype)initWithDataService:(id<USCDataService>)dataService
{
    self = [super init];
    if (self) {
        self.tabBarItem = [[UITabBarItem alloc]initWithTitle:@"Scanner" image:[UIImage imageNamed:@"gallery_selected"] tag:0];
    }
    self.dataService = dataService;
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
    self.photoOutput = [AVCapturePhotoOutput new];
    self.boxLayer = [NSMutableArray<CAShapeLayer*> new];
    
    dispatch_async(self.captureSessionQueue, ^{
        [self setupCamera];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self calculateRegionOfInterest:self.scannerMode];
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
    [self calculateRegionOfInterest:self.scannerMode];
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    [self updateCutout];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.drawLayer.delegate = self;
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    [self.drawLayer setNeedsDisplay];
}

-(CAShapeLayer *)drawLayer{
    return self.previewView.drawLayer;
}

-(void)updateCutout{
    CGAffineTransform roiRectTransform = CGAffineTransformConcat(self.bottomToTopTransform, self.uiRotationTransform);
    CGRect cutout = [self.previewView.videoPreviewLayer rectForMetadataOutputRectOfInterest:CGRectApplyAffineTransform(self.regionOfInterest, roiRectTransform)];
    self.drawLayer.frame = cutout;
    
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
    
    [self.metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    if([self.captureSession canAddOutput:self.metadataOutput]){
        [self.captureSession addOutput:self.metadataOutput];
        [self.metadataOutput connectionWithMediaType:AVMediaTypeVideo].preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeOff;
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
    
    if([self.captureSession canAddOutput:self.photoOutput]){
        [self.captureSession addOutput:self.photoOutput];
    } else {
        NSLog(@"Could not add photo output");
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

-(void) calculateRegionOfInterest:(USCScannerMode)mode{
    CGFloat desiredHeightRatio;
    CGFloat desiredWidthRatio;
    CGFloat maxPortraitWidth;
    
    switch (mode) {
        case USCQRAndBarMode:
            desiredHeightRatio = desiredWidthRatio = maxPortraitWidth = 0.9;
            break;
        case USCCodeMode:
            desiredHeightRatio = 0.15;
            desiredWidthRatio = 0.6;
            maxPortraitWidth = 0.8;
            break;
        default:
            break;
    }
    
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
        [self.dataService addEntry:self.currentQrOrBarCode];
    }
    else{
        [self.dataService addEntry:self.currentTextualCode];
    }
}

- (IBAction)segmentedControlValueChanged:(id)sender {
    self.scannerMode = self.segmentedControl.selectedSegmentIndex == 0 ? USCQRAndBarMode : USCCodeMode;
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
    [self calculateRegionOfInterest:self.scannerMode];
}

-(void)changeCaptureRectangleVisibility{
    [self.drawLayer setNeedsDisplay];
}

#pragma mark AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    if(self.scannerMode != USCQRAndBarMode) return;
    
    if(metadataObjects.count > 0){
        for(AVMetadataObject *obj in metadataObjects){
            AVMetadataMachineReadableCodeObject *ro = (AVMetadataMachineReadableCodeObject*)[self.previewView.videoPreviewLayer transformedMetadataObjectForMetadataObject:obj];
            
            self.bounds = [NSValue valueWithCGRect:ro.bounds];
            if(!CGRectContainsPoint(ro.bounds, CGPointMake(CGRectGetMidX(self.drawLayer.frame), CGRectGetMidY(self.drawLayer.frame)))){
                self.rectangle = nil;
                [self setUIEnabled:NO];
                break;
            }
            CGPoint p0, p1, p2, p3;
            CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[0], &p0);
            CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[1], &p1);
            CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[2], &p2);
            CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[3], &p3);
            self.rectangle = @[[NSValue valueWithCGPoint:p0],
                               [NSValue valueWithCGPoint:p1],
                               [NSValue valueWithCGPoint:p2],
                               [NSValue valueWithCGPoint:p3]];
            self.currentQrOrBarCode = ro.stringValue;
            [self setUIEnabled:YES];
        }
    }
    else{
        self.rectangle = nil;
        [self setUIEnabled:NO];
    }
    [self.drawLayer setNeedsDisplay];
}

-(void) setUIEnabled:(BOOL)enabled{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.captureButton.userInteractionEnabled = enabled;
        NSString *title = enabled ? @"Take" : @"";
        [self.captureButton setTitle:title forState:UIControlStateNormal];
    });
}

#pragma mark CALayerDelegate
- (void)drawLayer:(CALayer*)layer inContext:(CGContextRef)ctx {
    //draw aim
    if(self.scannerMode == USCQRAndBarMode){
        if(!_rectangle) {
            CGContextClearRect(ctx, layer.bounds);
        }
        else{
            CGPoint p0 = [self.rectangle[0] CGPointValue];
            CGPoint p1 = [self.rectangle[1] CGPointValue];
            CGPoint p2 = [self.rectangle[2] CGPointValue];
            CGPoint p3 = [self.rectangle[3] CGPointValue];
            [self drawPath:p0 p1:p1 p2:p2 p3:p3 andContext:ctx];
        }
    }
    else {
//        CGRect layerRect = self.drawLayer.bounds;
//        CGRect rect = CGRectMake(40, layerRect.size.height / 2 - 40, layerRect.size.width - 80, 80);
//        [self drawRoundedRect:rect andContext:ctx];
    }
    [self drawAim:layer.bounds andContext:ctx];
}

-(void) drawAim:(CGRect)rect andContext :(CGContextRef)ctx{
    CGFloat midX = CGRectGetMidX(rect);
    CGFloat midY = CGRectGetMidY(rect);
    CGContextSetRGBStrokeColor(ctx, 255, 0, 0, 1.0);
    CGContextSetLineWidth(ctx, 1);
    CGContextMoveToPoint(ctx, midX - 60, midY);
    CGContextAddLineToPoint(ctx, midX + 60, midY);
    CGContextClosePath(ctx);
    CGContextDrawPath(ctx, kCGPathStroke);
    CGContextMoveToPoint(ctx, midX, midY - 30);
    CGContextAddLineToPoint(ctx, midX, midY + 30);
    CGContextClosePath(ctx);
    CGContextDrawPath(ctx, kCGPathStroke);
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
    if(self.scannerMode != USCCodeMode) return;
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
        int maximumCandidates = 1;
        for(VNRecognizedTextObservation *visionResult in request.results){
            NSArray *candidates = [visionResult topCandidates:maximumCandidates];
            if(candidates.count == 0) continue;
            VNRecognizedText *candidate = candidates[0];
            NSRange range = [candidate.string rangeOfString:@"[0-9]+\\.[0-9]+" options:NSRegularExpressionSearch];
            if(range.location == NSNotFound)            {
                continue;
            }
            NSString *code = [candidate.string substringWithRange:range];
            self.currentTextualCode = code;
            CGRect box = [candidate boundingBoxForRange:range error:nil].boundingBox;
            [self drawCodeBox:box];
            [self setUIEnabled:YES];
        }
        return;
    }
    [self drawCodeBox:CGRectZero];
    //self.currentTextualCode = @"";
    [self setUIEnabled:NO];
}

-(void)drawCodeBox:(CGRect)boxRect{
    dispatch_async(dispatch_get_main_queue(), ^{
        AVCaptureVideoPreviewLayer *videoPreviewLayer = self.previewView.videoPreviewLayer;
        [self removeBoxes];
        CGRect rect = [videoPreviewLayer rectForMetadataOutputRectOfInterest:CGRectApplyAffineTransform(boxRect, self.visionToAVFTransform)];
        
        CAShapeLayer *layer = [CAShapeLayer new];
        layer.opacity = 0.5;
        layer.borderColor = UIColor.redColor.CGColor;
        layer.borderWidth = 3;
        layer.frame = rect;
        [self.boxLayer addObject:layer];
        [self.previewView.videoPreviewLayer insertSublayer:layer atIndex:1];
    });
}

-(void)removeBoxes{
    for(CAShapeLayer *layer in self.boxLayer){
        [layer removeFromSuperlayer];
    }
    [self.boxLayer removeAllObjects];
}
@end


