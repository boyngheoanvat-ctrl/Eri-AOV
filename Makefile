# Kiến trúc hỗ trợ TOÀN BỘ máy 64-bit
ARCHS = arm64 arm64e
TARGET = iphone:clang:15.6:14.0

FINALPACKAGE = 1
FOR_RELEASE = 1
WARNINGS = 1
SDKVERSION = 15.6

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = 34306jit

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation Security QuartzCore CoreGraphics CoreText AVFoundation Accelerate GLKit SystemConfiguration GameController
$(TWEAK_NAME)_CCFLAGS = -fno-rtti -fvisibility=hidden -DNDEBUG -std=c++11
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -DHAVE_INTTYPES_H -DHAVE_PKCRYPT -DHAVE_STDINT_H -DHAVE_WZAES -DHAVE_ZLIB
$(TWEAK_NAME)_LDFLAGS += -lresolv -lz -liconv lib/libdaubuoi.a lib/libmonostring.a linh_tinh/spam.a
$(TWEAK_NAME)_FILES = ImGuiDrawView.mm $(wildcard Esp/*.mm) $(wildcard Esp/*.m) $(wildcard IMGUI/*.cpp) $(wildcard IMGUI/*.mm)

include $(THEOS_MAKE_PATH)/tweak.mk
