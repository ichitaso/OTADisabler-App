DEBUG = 0
FINALPACKAGE = 1
GO_EASY_ON_ME := 1
ARCHS = arm64 arm64e

TARGET := iphone:clang:13.0:9.0
MIN_IOS_SDK_VERSION = 9.0

TOOL_NAME = dimentio
$(TOOL_NAME)_FILES = dimentio.c libdimentio.c
$(TOOL_NAME)_FRAMEWORKS = IOKit CoreFoundation
$(TOOL_NAME)_CFLAGS = -objc-arc
$(TOOL_NAME)_CODESIGN_FLAGS = -Stfp0.plist

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tool.mk
