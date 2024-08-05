// SystemWideOverlay+Layout.m

#import "SystemWideOverlay+Layout.h"
#import "Utilities/UIConstants.h"
#import "Utilities/LogManager.h"

@implementation SystemWideOverlay (Layout)

- (void)performLayoutUpdate {
    [LogManager log:@"Updating layout"];
    UIEdgeInsets safeAreaInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeAreaInsets = self.safeAreaInsets;
    }

    CGFloat width = MAX(self.desktopBounds.size.width, self.desktopBounds.size.height);
    CGFloat height = MIN(self.desktopBounds.size.width, self.desktopBounds.size.height);

    self.frame = CGRectMake(0, 0, width, height);
    self.menuContainerView.frame = self.bounds;

    [self updateTopBarLayout:safeAreaInsets width:width];
    [self updateContentViewLayout:safeAreaInsets width:width height:height];
    [self updateFloatingButtonLayout:safeAreaInsets width:width height:height];

    [LogManager log:@"Layout updated"];
}

- (void)updateTopBarLayout:(UIEdgeInsets)safeAreaInsets width:(CGFloat)width {
    UIView *topBar = self.menuContainerView.subviews.firstObject;
    topBar.frame = CGRectMake(safeAreaInsets.left, safeAreaInsets.top, width - safeAreaInsets.left - safeAreaInsets.right, kTopBarHeight);

    CGFloat buttonWidth = topBar.bounds.size.width / kTopBarButtonCount;
    for (NSInteger i = 0; i < kTopBarButtonCount; i++) {
        UIButton *button = [topBar.subviews objectAtIndex:i];
        button.frame = CGRectMake(i * buttonWidth, 0, buttonWidth, kTopBarHeight);
    }
}

- (void)updateContentViewLayout:(UIEdgeInsets)safeAreaInsets width:(CGFloat)width height:(CGFloat)height {
    self.contentView.frame = CGRectMake(safeAreaInsets.left,
                                        safeAreaInsets.top + kTopBarHeight,
                                        width - safeAreaInsets.left - safeAreaInsets.right,
                                        height - safeAreaInsets.top - safeAreaInsets.bottom - kTopBarHeight);

    for (UIView *pageView in self.contentView.subviews) {
        pageView.frame = self.contentView.bounds;
    }
}

- (void)updateFloatingButtonLayout:(UIEdgeInsets)safeAreaInsets width:(CGFloat)width height:(CGFloat)height {
    CGFloat floatingButtonSize = kFloatingButtonSize * 0.7;
    CGFloat floatingButtonX = self.initialFloatingButtonPosition.x;
    CGFloat floatingButtonY = self.initialFloatingButtonPosition.y;

    floatingButtonX = MAX(safeAreaInsets.left, MIN(floatingButtonX, width - floatingButtonSize - safeAreaInsets.right));
    floatingButtonY = MAX(safeAreaInsets.top, MIN(floatingButtonY, height - floatingButtonSize - safeAreaInsets.bottom));

    self.floatingButton.frame = CGRectMake(floatingButtonX, floatingButtonY, floatingButtonSize, floatingButtonSize);
    self.floatingButton.layer.cornerRadius = floatingButtonSize / 2;

    [LogManager log:@"Floating button position updated: (%.2f, %.2f)", floatingButtonX, floatingButtonY];
}

- (void)updateLayoutFromTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect newDesktopBounds = [self getDesktopBounds];
        if (!CGRectEqualToRect(newDesktopBounds, self.desktopBounds)) {
            self.desktopBounds = newDesktopBounds;
            [self performLayoutUpdate];
            [LogManager log:@"Layout updated from timer"];
        }
    });
}

- (CGRect)getDesktopBounds {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    return CGRectMake(0, 0, MIN(screenBounds.size.width, screenBounds.size.height), MAX(screenBounds.size.width, screenBounds.size.height));
}

@end
