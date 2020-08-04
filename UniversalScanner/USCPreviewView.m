//
//  USCPreviewView.m
//  UniversalScanner
//
//  Created by Andrey Butcitcyn on 02.08.2020.
//  Copyright © 2020 Andrey Butcitcyn. All rights reserved.
//

#import "USCPreviewView.h"


@implementation USCPreviewView

@synthesize drawLayer=_drawLayer;

-(AVCaptureVideoPreviewLayer *) videoPreviewLayer{
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

-(CAShapeLayer *) drawLayer{
    if(!_drawLayer){
        _drawLayer = [CAShapeLayer new];
        [self.layer addSublayer:_drawLayer];
        _drawLayer.bounds = self.layer.bounds;
    }
    return _drawLayer;
}

+ (Class)layerClass{
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session{
    return self.videoPreviewLayer.session;
}

-(void) setSession:(AVCaptureSession *)session{
    self.videoPreviewLayer.session = session;
}

- (void)layoutSubviews{
    self.drawLayer.bounds = self.layer.bounds;
}

@end
