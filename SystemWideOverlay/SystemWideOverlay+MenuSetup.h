// SystemWideOverlay+MenuSetup.h

#import "SystemWideOverlay.h"

@interface SystemWideOverlay (MenuSetup) <UITableViewDataSource, UITableViewDelegate>

- (void)setupMenuView;
- (void)updatePageVisibility;
- (void)updateTopBarButtonsAppearance;
- (UIView *)createPageViewWithFrame:(CGRect)frame title:(NSString *)title;
- (UIView *)createCustomAlertViewWithTitle:(NSString *)title message:(NSString *)message;

@end
