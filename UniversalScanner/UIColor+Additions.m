#import "UIColor+Additions.h"

@implementation UIColor (Additions)
+(UIColor *)fromHex:(unsigned int) hexColor alpha:(CGFloat)alpha{
    return  [UIColor colorWithRed:((CGFloat) ((hexColor & 0xFF0000) >> 16))/255
       green:((CGFloat) ((hexColor & 0xFF00) >> 8))/255
       blue:((CGFloat) (hexColor & 0xFF))/255
       alpha:alpha];
}

+(UIColor *)fromHex:(unsigned int) hexColor{
return  [UIColor colorWithRed:((CGFloat) ((hexColor & 0xFF0000) >> 16))/255
   green:((CGFloat) ((hexColor & 0xFF00) >> 8))/255
   blue:((CGFloat) (hexColor & 0xFF))/255
   alpha:1];
}

-(CGFloat*) getRGBComponents{
    return CGColorGetComponents(self.CGColor);
}

-(CGFloat)getAlphaComponent{
    return CGColorGetAlpha(self.CGColor);
}
@end
