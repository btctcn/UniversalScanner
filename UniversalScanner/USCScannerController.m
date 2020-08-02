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
#import <VisionKit/VisionKit.h>

@interface USCScannerController ()

typedef NS_ENUM(NSInteger, USCScannerMode){
    USCQRAndBarMode,
    USCCodeMode
};

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureMetadataOutput *output;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) CAShapeLayer *drawLayer;
@property (nonatomic, strong) NSArray *rectangle;
@property (nonatomic, readonly) USCScannerMode scannerMode;
@property (nonatomic, assign) BOOL isScannerInitialized;
@property (nonatomic, strong) NSValue *bounds;
@property (nonatomic, copy) NSString *currentQrOrBarCode;
@property (nonatomic, copy) NSString *currentTextualCode;
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
    
    UITapGestureRecognizer *tapRecognizer = [UITapGestureRecognizer new];
    tapRecognizer.delegate = self;
    [tapRecognizer addTarget:self action:@selector(captureButtonTapped)];
    [self.captureButton addGestureRecognizer:tapRecognizer];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    
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

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if(!self.isScannerInitialized){
        [self setupScanner];
        [self.session startRunning];
        self.isScannerInitialized = YES;
    }
}

- (void) setupScanner;
{
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    self.session = [[AVCaptureSession alloc] init];
    self.output = [[AVCaptureMetadataOutput alloc] init];
    [self.session addOutput:self.output];
    [self.session addInput:self.input];
    
    
//    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
//    videoOutput.videoSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
//    [self.session addOutput:videoOutput];
    //[videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    [self.output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    self.output.metadataObjectTypes = @[AVMetadataObjectTypeUPCECode,
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
    
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    
    AVCaptureConnection *con = self.previewLayer.connection;
    con.videoOrientation = AVCaptureVideoOrientationPortrait;
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    self.drawLayer = [CAShapeLayer layer];
    CGRect parentBox = [self.previewLayer frame];
    [self.drawLayer setFrame:parentBox];
    [self.drawLayer setDelegate:self];
    [self.drawLayer setNeedsDisplay];
    [self.previewLayer addSublayer:self.drawLayer];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskPortrait;
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
    if(metadataObjects.count > 0){
        AVMetadataMachineReadableCodeObject *ro = (AVMetadataMachineReadableCodeObject*)[self.previewLayer transformedMetadataObjectForMetadataObject:metadataObjects[0]];
        self.bounds = [NSValue valueWithCGRect:ro.bounds];
        CGPoint p0;
        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[0], &p0);
        CGPoint p1;
        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[1], &p1);
        CGPoint p2;
        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[2], &p2);
        CGPoint p3;
        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)ro.corners[3], &p3);
        self.rectangle = @[[NSValue valueWithCGPoint:p0],
                           [NSValue valueWithCGPoint:p1],
                           [NSValue valueWithCGPoint:p2],
                           [NSValue valueWithCGPoint:p3]];
        
        if(self.scannerMode == USCQRAndBarMode){
            [self.captureButton setTitle:@"Take" forState:UIControlStateNormal];
            self.captureButton.userInteractionEnabled = YES;
            self.currentQrOrBarCode = ro.stringValue;
        }
    }
    else{
        self.rectangle = nil;
        [self.captureButton setTitle:@"" forState:UIControlStateNormal];
        self.captureButton.userInteractionEnabled = NO;
    }
    
    [self.drawLayer setNeedsDisplay];
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

#pragma mark AVCaptureAudioDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {

//    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    CIImage *image = [CIImage imageWithCVImageBuffer:imageBuffer options:nil];
//    UIImage *uiImage = [UIImage imageWithCIImage:image];
//    CIContext *context = [CIContext contextWithOptions:nil];
//    CGImageRef ref = [context createCGImage:image fromRect:image.extent];
//
//    UIImage * portraitImage = [[UIImage alloc] initWithCGImage: ref
//          scale: 1.0
//    orientation: UIImageOrientationRight];
//    CFRelease(ref);
////
////    self.image.image = portraitImage;
//    self.image.image = portraitImage;
}

- (IBAction)scanTextTouchUpInside:(id)sender {
    VNDocumentCameraViewController *vc = [[VNDocumentCameraViewController alloc]init];
    vc.delegate = self;
    [self presentViewController:vc animated:YES completion:nil];
}
@end
