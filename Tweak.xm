// Tweak.xm

#import <UIKit/UIKit.h>
#import <substrate.h>
#import "SystemWideOverlay/SystemWideOverlay.h"
#import "Utilities/LogManager.h"
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBApplication.h>

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application { // 应用程序启动完成时调用
    %orig; // 调用原始实现
    [LogManager log:@"SpringBoard 启动完成，正在初始化 SystemWideOverlay"]; // 记录日志
    SystemWideOverlay *overlay = [SystemWideOverlay sharedInstance]; // 获取 SystemWideOverlay 单例
    [overlay makeKeyAndVisible]; // 将 overlay 设置为主窗口并可见
    [LogManager log:@"SystemWideOverlay 已初始化并设置为可见"]; // 记录日志
}

- (void)_updateHomeScreenDockStatus { // 主屏幕状态更新时调用
    %orig; // 调用原始实现
    [LogManager log:@"主屏幕状态更新，检查是否需要关闭菜单"]; // 记录日志
    [[SystemWideOverlay sharedInstance] checkAndCloseMenuIfNeeded]; // 获取单例并检查是否需要关闭菜单
}

%end

%hook UIApplication

- (UIInterfaceOrientationMask)supportedInterfaceOrientationsForWindow:(UIWindow *)window { // 返回窗口支持的屏幕方向掩码
    if ([window isKindOfClass:[SystemWideOverlay class]]) { // 如果窗口是 SystemWideOverlay 类的实例
        [LogManager log:@"返回 SystemWideOverlay 的横屏方向掩码"]; // 记录日志
        UIInterfaceOrientationMask mask = UIInterfaceOrientationMaskLandscape; // 设置横屏方向掩码
        
       // dispatch_async(dispatch_get_main_queue(), ^{ // 异步执行以下操作
            //SystemWideOverlay *overlay = (SystemWideOverlay *)window; // 获取 SystemWideOverlay 实例
            //[overlay closeMenu]; // 关闭悬浮菜单
           // [LogManager log:@"已关闭悬浮菜单"]; // 记录日志
       // });
        
        return mask; // 返回横屏方向掩码
    }
    return %orig; // 否则，调用原始实现并返回结果
}

%end


%ctor {
    %init;
    [LogManager log:@"igg 插件已初始化"];
}