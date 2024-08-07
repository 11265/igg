export THEOS_DEVICE_IP = 192.168.3.11
ARCHS = arm64
THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:11.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = igg

igg_FILES = Tweak.xm \
            SystemWideOverlay/ProcessManager.m  \
            SystemWideOverlay/ProcessPageView.m \
            SystemWideOverlay/SearchPageView.m  \
            SystemWideOverlay/LogPageView.m \
            SystemWideOverlay/MemoryPageView.m  \
            SystemWideOverlay/SettingsPageView.m    \
            SystemWideOverlay/SystemWideOverlay.m \
            SystemWideOverlay/SystemWideOverlay+Layout.m \
            SystemWideOverlay/SystemWideOverlay+MenuSetup.m \
            JHDragView/JHDragView.m \
            Utilities/UIConstants.m \
            Utilities/LogManager.m\
            Crossprocess/ProcessModule.mm


igg_CFLAGS = -fobjc-arc
igg_FRAMEWORKS = UIKit
igg_PRIVATE_FRAMEWORKS = SpringBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk


