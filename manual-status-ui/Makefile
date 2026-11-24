ARCHS = arm64
TARGET = iphone:clang:15.6:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = ClassicManual
ClassicManual_FILES = CMRootListController.m
ClassicManual_FRAMEWORKS = Foundation UIKit CoreFoundation
ClassicManual_PRIVATE_FRAMEWORKS = Preferences
ClassicManual_INSTALL_PATH = /Library/PreferenceBundles
ClassicManual_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/bundle.mk
TOOL_NAME = classic-lpm
classic-lpm_FILES = classic-lpm.m
classic-lpm_FRAMEWORKS = Foundation
classic-lpm_INSTALL_PATH = /usr/local/bin
classic-lpm_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tool.mk
