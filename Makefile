ARCHS = arm64
TARGET = iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES = com.nguyen.AOV

# Liên kết thư viện Dobby
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

# Tự cài SDK nếu chưa có
before-all::
	@if [ ! -d "$(THEOS)/sdks/iPhoneOS*.sdk" ]; then \
		echo "==> Downloading SDK..."; \
		$(THEOS)/bin/install-sdk latest; \
	fi

# Tự cài Dobby nếu chưa có
before-all::
	@if [ ! -f "$(THEOS)/lib/libdobby.a" ]; then \
		echo "==> Building Dobby..."; \
		git clone https://github.com/jmpews/Dobby.git -b dev --depth=1 /tmp/Dobby; \
		cd /tmp/Dobby && make libdobby; \
		cp /tmp/Dobby/libdobby.a $(THEOS)/lib/; \
		mkdir -p $(THEOS)/include/dobby; \
		cp /tmp/Dobby/include/*.h $(THEOS)/include/dobby/; \
		echo "==> Dobby installed"; \
	fi

include theos/makefiles/tweak.mk
