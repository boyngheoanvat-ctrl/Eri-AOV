ARCHS = arm64
TARGET = iphone:clang:15.0:14.0
INSTALL_TARGET_PROCESSES = com.nguyen.AOV

# ==== THÊM 2 DÒNG NÀY ====
LDFLAGS += -ldobby
# =========================

include theos/makefiles/common.mk

TWEAK_NAME = 34306jit
34306jit_FILES = ImGuiDrawView.mm Esp/JHPP.m Esp/ImGuiLoad.m Esp/JHUIViewControllerDecoupler.m Esp/PubgLoad.mm IMGUI/Il2cpp.cpp IMGUI/imgui.cpp IMGUI/imgui_draw.cpp IMGUI/imgui_demo.cpp
34306jit_CFLAGS = -std=c++17 -fobjc-arc
34306jit_FRAMEWORKS = UIKit Metal MetalKit

include theos/makefiles/tweak.mk
