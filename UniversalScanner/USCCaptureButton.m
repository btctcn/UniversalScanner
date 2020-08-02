//
//  USCCaptureButton.m
//  UniversalScanner
//
//  Created by Andrey Butcitcyn on 01.08.2020.
//  Copyright © 2020 Andrey Butcitcyn. All rights reserved.
//

#import "USCCaptureButton.h"

@implementation USCCaptureButton

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat innerWidth = 5;
    [[UIColor whiteColor] setStroke];
    CGContextSetLineWidth(ctx, innerWidth);
    CGContextAddEllipseInRect(ctx, CGRectInset(rect, innerWidth, innerWidth));
    CGContextStrokePath(ctx);
    CGFloat delta = self.isPressed ? 6 : 4;
    CGContextAddEllipseInRect(ctx, CGRectInset(rect, innerWidth + delta, innerWidth + delta));
    [[UIColor whiteColor] setFill];
    CGContextFillPath(ctx);
}

@end
