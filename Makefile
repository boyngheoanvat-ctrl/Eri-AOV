ARCHS = arm64

# Tự động lấy SDK có sẵn mới nhất
SDKVERSION := $(notdir $(patsubst %/,%,$(dir $(firstword $(wildcard $(THEOS)/sdks/iPhoneOS*.sdk/)))))
SDKVERSION := $(patsubst iPhoneOS%,%,$(SDKVERSION))
TARGET := iphone:clang:$(SDKVERSION):14.0

INSTALL_TARGET_PROCESSES = com.nguyen.AOV

LDFLAGS += -ldobby

include theos/makefiles/common.mk

TWEAK_NAME = 34306jit

34306jit_FILES = \
    ImGuiDrawView.mm \
    Esp/JHPP.m \
    Esp/ImGuiLoad.m \
    Esp/JHUIViewControllerDecoupler.m \
    Esp/PubgLoad.mm \
    IMGUI/Il2cpp.cpp \
    IMGUI/imgui.cpp \
    IMGUI/imgui_draw.cpp \
    IMGUI/imgui_demo.cpp

34306jit_CFLAGS = -std=c++17 -fobjc-arc
34306jit_FRAMEWORKS = UIKit Metal MetalKit

# Tự cài Dobby
before-all::
	@if [ ! -f "$(THEOS)/lib/libdobby.a" ]; then \
		echo "==> Building Dobby..."; \
		git clone https://github.com/jmpews/Dobby.git -b dev --depth=1 /tmp/Dobby; \
		cd /tmp/Dobby && make libdobby; \
		mkdir -p $(THEOS)/lib $(THEOS)/include/dobby; \
		cp /tmp/Dobby/libdobby.a $(THEOS)/lib/; \
		cp /tmp/Dobby/include/*.h $(THEOS)/include/dobby/; \
		echo "==> Dobby ready"; \
	fi

include theos/makefiles/tweak.mk
