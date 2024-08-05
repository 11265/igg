// JHDragView.m

#import "JHDragView.h"
#import "Utilities/UIConstants.h"
#import "Utilities/LogManager.h"

@implementation JHDragView

- (instancetype)initWithFrame:(CGRect)frame {
    CGSize defaultSize = CGSizeMake(kFloatingButtonSize * 0.7, kFloatingButtonSize * 0.7);
    
    if (CGRectGetWidth(frame) <= 0 || CGRectGetHeight(frame) <= 0) {
        frame = [self defaultFrameWithSize:defaultSize];
    } else {
        frame = [self adjustedFrameWithSize:defaultSize originalFrame:frame];
    }
    
    self = [super initWithFrame:frame];
    if (self) {
        [self setupAppearance];
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
    }
    return self;
}

- (CGRect)defaultFrameWithSize:(CGSize)size {
    return CGRectMake([UIScreen mainScreen].bounds.size.width - 70, 130, size.width, size.height);
}

- (CGRect)adjustedFrameWithSize:(CGSize)size originalFrame:(CGRect)originalFrame {
    CGPoint center = CGPointMake(CGRectGetMidX(originalFrame), CGRectGetMidY(originalFrame));
    return CGRectMake(center.x - size.width / 2, center.y - size.height / 2, size.width, size.height);
}

- (void)setupAppearance {
    self.layer.borderColor = [[UIColor colorWithRed:1.0 green:0.00 blue:0.00 alpha:0.50] CGColor];
    self.layer.borderWidth = 0.95f;
    self.backgroundColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:0.50];
    self.clipsToBounds = YES;
    self.layer.cornerRadius = CGRectGetWidth(self.bounds) / 2;
    self.alpha = 1.0f;
    self.userInteractionEnabled = YES;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.isDragging = YES;
            break;
        case UIGestureRecognizerStateChanged:
            self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
            [gesture setTranslation:CGPointZero inView:self.superview];
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            self.isDragging = NO;
            [self resetFrameIfNeeded];
            break;
        default:
            break;
    }
}

- (void)resetFrameIfNeeded {
    CGRect superviewBounds = self.superview.bounds;
    CGRect frame = self.frame;

    frame.origin.x = MAX(0, MIN(frame.origin.x, superviewBounds.size.width - frame.size.width));
    frame.origin.y = MAX(0, MIN(frame.origin.y, superviewBounds.size.height - frame.size.height));

    [UIView animateWithDuration:0.25 animations:^{
        self.frame = frame;
    } completion:^(BOOL finished) {
        if (finished && [self.superview.superview isKindOfClass:NSClassFromString(@"SystemWideOverlay")]) {
            [self.superview.superview setValue:[NSValue valueWithCGPoint:self.frame.origin] forKey:@"initialFloatingButtonPosition"];
        }
    }];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    return (hitView == self) ? hitView : nil;
}

@end