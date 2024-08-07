// SystemWideOverlay.h

#import <UIKit/UIKit.h>
#import "JHDragView/JHDragView.h"

@interface SystemWideOverlay : UIWindow

@property (nonatomic, strong, readonly) JHDragView *floatingButton;
@property (nonatomic, assign, readwrite) BOOL isMenuOpen;

@property (nonatomic, strong, readwrite) UIView *menuContainerView;
@property (nonatomic, strong, readwrite) UIView *contentView;
@property (nonatomic, strong, readwrite) NSArray<UIView *> *pageViews;
@property (nonatomic, assign, readwrite) NSInteger currentPageIndex;
@property (nonatomic, assign, readwrite) CGRect desktopBounds;
@property (nonatomic, assign, readwrite) CGPoint initialFloatingButtonPosition;

+ (instancetype)sharedInstance;
- (void)toggleMenu;
- (void)closeMenu;
- (void)updateLayout;
- (void)checkAndCloseMenuIfNeeded;

@end