// SystemWideOverlay+Layout.h

#import "SystemWideOverlay.h"

@interface SystemWideOverlay (Layout)

- (void)performLayoutUpdate;
- (void)updateLayoutFromTimer;
- (CGRect)getDesktopBounds;

@end