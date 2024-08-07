// SystemWideOverlay+MenuSetup.h

#import "SystemWideOverlay.h"

@interface SystemWideOverlay (MenuSetup)

- (void)setupMenuView;
- (void)updatePageVisibility;
- (void)updateTopBarButtonsAppearance;
- (void)closeMenuFromCategory;

@end