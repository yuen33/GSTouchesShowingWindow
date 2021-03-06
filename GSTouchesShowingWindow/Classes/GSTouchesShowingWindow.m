//
//  GSAppPreviewTouchesWindow.m
//  Routes
//
//  Created by Lukas Petr on 16/08/14.
//  Copyright (c) 2014 Glimsoft. All rights reserved.
//

#import "GSTouchesShowingWindow.h"

#define TOUCH_IMAGE_NAME        @"GSTouchImageBlue.png"
#define SHORT_TAP_TRESHOLD_DURATION             0.11
#define SHORT_TAP_INITIAL_CIRCLE_RADIUS         22
#define SHORT_TAP_FINAL_CIRCLE_RADIUS           57

@interface GSTouchImageViewQueue : NSObject

- (id)initWithTouchesCount:(NSUInteger)count;

- (UIImageView *)popTouchImageView;
- (void)pushTouchImageView:(UIImageView *)touchImageView;

@end


@interface GSTouchesShowingWindow () {
    GSTouchImageViewQueue *_touchImgViewQueue;
    NSMutableDictionary *_touchImgViewsDict;
}

@property (nonatomic, readonly) GSTouchImageViewQueue *touchImgViewQueue;
@property (nonatomic, strong) NSMutableDictionary *touchImgViewsDict;
@property (nonatomic, strong) NSMapTable *touchesStartDatesMapTable;

@end



@implementation GSTouchesShowingWindow


- (void)sendEvent:(UIEvent *)event {
    
	NSSet *touches = [event allTouches];
    
    for (UITouch *touch in touches) {
        
		switch ([touch phase]) {
                
			case UITouchPhaseBegan:
                [self touchBegan:touch];
				break;
                
			case UITouchPhaseMoved:
                [self touchMoved:touch];
				break;
                
            case UITouchPhaseEnded:
			case UITouchPhaseCancelled:
				[self touchEnded:touch];
				break;
                
			default:
				break;
		}
	}
    [super sendEvent:event];
}

- (void)touchBegan:(UITouch *)touch {
    UIImageView *touchImgView = [self.touchImgViewQueue popTouchImageView];
    touchImgView.center = [touch locationInView:self];
    [self addSubview:touchImgView];
    touchImgView.alpha = 0.0;
    touchImgView.transform = CGAffineTransformMakeScale(1.13, 1.13);
    [self setTouchImageView:touchImgView forTouch:touch];
    
    [UIView animateWithDuration:0.1 animations:^{
        touchImgView.alpha = 1.0f;
        touchImgView.transform = CGAffineTransformMakeScale(1, 1);
    }];
    
    [self.touchesStartDatesMapTable setObject:[NSDate date] forKey:touch];
}

- (void)touchMoved:(UITouch *)touch {
    UIImageView *touchImgView = [self touchImageViewForTouch:touch];
    touchImgView.center = [touch locationInView:self];
}

- (void)touchEnded:(UITouch *)touch {
    
    NSDate *touchStartDate = [self.touchesStartDatesMapTable objectForKey:touch];
    NSTimeInterval touchDuration = [[NSDate date] timeIntervalSinceDate:touchStartDate];
    [self.touchesStartDatesMapTable removeObjectForKey:touch];
    
    if (touchDuration < SHORT_TAP_TRESHOLD_DURATION) {
        [self showExpandingCircleAtPosition:[touch locationInView:self]];
    }
    
    UIImageView *touchImgView = [self touchImageViewForTouch:touch];
    [UIView animateWithDuration:0.1
                     animations:^{
                         touchImgView.alpha = 0.0f;
                         touchImgView.transform = CGAffineTransformMakeScale(1.13, 1.13);
                     } completion:^(BOOL finished) {
                         [touchImgView removeFromSuperview];
                         touchImgView.alpha = 1.0;
                         [self.touchImgViewQueue pushTouchImageView:touchImgView];
                         [self removeTouchImageViewForTouch:touch];
                     }];
}

- (void)showExpandingCircleAtPosition:(CGPoint)position {
    CAShapeLayer *circleLayer = [CAShapeLayer layer];
    CGFloat initialRadius = SHORT_TAP_INITIAL_CIRCLE_RADIUS;
    CGFloat finalRadius = SHORT_TAP_FINAL_CIRCLE_RADIUS;
    circleLayer.position = CGPointMake(position.x - initialRadius, position.y - initialRadius);
    
    UIBezierPath *startPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, initialRadius * 2, initialRadius * 2)
                                                         cornerRadius:initialRadius];
    CGFloat endPathOrigin = initialRadius - finalRadius;
    UIBezierPath *endPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(endPathOrigin, endPathOrigin, finalRadius * 2, finalRadius * 2)
                                                       cornerRadius:finalRadius];
    circleLayer.path = startPath.CGPath;
    circleLayer.fillColor = [UIColor clearColor].CGColor;
    circleLayer.strokeColor = [UIColor colorWithRed:0./255 green:135./255 blue:244./255 alpha:0.8].CGColor;
    circleLayer.lineWidth = 2.0f;
    [self.layer addSublayer:circleLayer];
    
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        [circleLayer removeFromSuperlayer];
    }];
    
    // Expanding animation
    CABasicAnimation *expandingAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    expandingAnimation.fromValue = (__bridge id)startPath.CGPath;
    expandingAnimation.toValue = (__bridge id)endPath.CGPath;
    expandingAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    expandingAnimation.duration = 0.4;
    expandingAnimation.repeatCount = 1.0;
    [circleLayer addAnimation:expandingAnimation forKey:@"expandingAnimation"];
    circleLayer.path = endPath.CGPath;
    
    // Delayed fade out animation
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CABasicAnimation *fadingOutAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadingOutAnimation.fromValue = @1.0f;
        fadingOutAnimation.toValue = @0.0f;
        fadingOutAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        fadingOutAnimation.duration = 0.15;
        [circleLayer addAnimation:fadingOutAnimation forKey:@"fadeOutAnimation"];
        circleLayer.opacity = 0.0f;
    });
    
    [CATransaction commit];
}


- (UIImageView *)touchImageViewForTouch:(UITouch *)touch {
    NSString *touchStringHash = [NSString stringWithFormat:@"%lu", (unsigned long)[touch hash]];
    return self.touchImgViewsDict[touchStringHash];
}

- (void)setTouchImageView:(UIImageView *)imgView forTouch:(UITouch *)touch {
    NSString *touchStringHash = [NSString stringWithFormat:@"%lu", (unsigned long)[touch hash]];
    [self.touchImgViewsDict setObject:imgView forKey:touchStringHash];
}

- (void)removeTouchImageViewForTouch:(UITouch *)touch {
    NSString *touchStringHash = [NSString stringWithFormat:@"%lu", (unsigned long)[touch hash]];
    [self.touchImgViewsDict removeObjectForKey:touchStringHash];
}

- (GSTouchImageViewQueue *)touchImgViewQueue {
    if (_touchImgViewQueue == nil) {
        _touchImgViewQueue = [[GSTouchImageViewQueue alloc] initWithTouchesCount:8];
    }
    return _touchImgViewQueue;
}

- (NSMutableDictionary *)touchImgViewsDict {
    if (_touchImgViewsDict == nil) {
        _touchImgViewsDict = [[NSMutableDictionary alloc] init];
    }
    return _touchImgViewsDict;
}

- (NSMapTable *)touchesStartDatesMapTable {
    if (_touchesStartDatesMapTable == nil) {
        _touchesStartDatesMapTable = [[NSMapTable alloc] init];
    }
    return _touchesStartDatesMapTable;
}

@end



@interface GSTouchImageViewQueue ()

@property (nonatomic, strong) NSMutableArray *backingArray;

@end


@implementation GSTouchImageViewQueue

- (id)initWithTouchesCount:(NSUInteger)count {
    if (self = [super init]) {
        self.backingArray = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < count; i++) {
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            UIImageView *imgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:TOUCH_IMAGE_NAME inBundle:bundle compatibleWithTraitCollection:nil]];
            [self.backingArray addObject:imgView];
        }
    }
    return self;
}

- (UIImageView *)popTouchImageView {
    UIImageView *touchImageView = [self.backingArray firstObject];
    [self.backingArray removeObjectAtIndex:0];
    return touchImageView;
}

- (void)pushTouchImageView:(UIImageView *)touchImageView {
    [self.backingArray addObject:touchImageView];
}

@end

