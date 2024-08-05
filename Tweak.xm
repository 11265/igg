// Tweak.xm

#import <UIKit/UIKit.h>
#import <substrate.h>
#import "SystemWideOverlay/SystemWideOverlay.h"
#import "Utilities/LogManager.h"
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBApplication.h>

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [LogManager log:@"SpringBoard 启动完成，正在初始化 SystemWideOverlay"];
    SystemWideOverlay *overlay = [SystemWideOverlay sharedInstance];
    [overlay makeKeyAndVisible];
    [LogManager log:@"SystemWideOverlay 已初始化并设置为可见"];
}

- (void)_updateHomeScreenDockStatus {
    %orig;
    [LogManager log:@"主屏幕状态更新，检查是否需要关闭菜单"];
    [[SystemWideOverlay sharedInstance] checkAndCloseMenuIfNeeded];
}

%end

%hook UIApplication

- (UIInterfaceOrientationMask)supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    if ([window isKindOfClass:[SystemWideOverlay class]]) {
        [LogManager log:@"返回 SystemWideOverlay 的横屏方向掩码"];
        UIInterfaceOrientationMask mask = UIInterfaceOrientationMaskLandscape;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            SystemWideOverlay *overlay = (SystemWideOverlay *)window;
            [overlay closeMenu];
            [LogManager log:@"已关闭悬浮菜单"];
        });
        
        return mask;
    }
    return %orig;
}

%end

%ctor {
    %init;
    [LogManager log:@"igg 插件已初始化"];
}