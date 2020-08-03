//
//  USCPreviewView.m
//  UniversalScanner
//
//  Created by Andrey Butcitcyn on 02.08.2020.
//  Copyright © 2020 Andrey Butcitcyn. All rights reserved.
//

#import "USCPreviewView.h"

@implementation USCPreviewView

-(AVCaptureVideoPreviewLayer *) videoPreviewLayer{
    return (AVCaptureVideoPreviewLayer *)self.layer;
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

@end
