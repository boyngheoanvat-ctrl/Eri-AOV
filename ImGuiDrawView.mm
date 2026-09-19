#include <stdint.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <stdio.h>
#include <string.h>
#include <pthread.h>
#include <dispatch/dispatch.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "5Toubun/dobby.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/zzz.h"

#ifndef OBFUSCATE
#define OBFUSCATE(s) (s)
#endif

#define LOGI(fmt, ...) NSLog((@"[MOD] " fmt), ##__VA_ARGS__)
#define kWidth   [UIScreen mainScreen].bounds.size.width
#define kHeight  [UIScreen mainScreen].bounds.size.height
#define kScale   [UIScreen mainScreen].scale

#ifdef __cplusplus
extern "C" {
#endif
extern uint32_t _dyld_image_count(void);
extern const char* _dyld_get_image_name(uint32_t image_index);
extern const struct mach_header* _dyld_get_image_header(uint32_t image_index);
#ifdef __cplusplus
}
#endif

// ========== BIẾN TOÀN CỤC — CAM KÉO ==========
struct WideView_t {
    float GetFieldOfView;
    float SetFieldOfView;
    bool Active;
} WideView = {0, 0, false};

uintptr_t il2cppBase = 0;
bool MenDeal = false;

// ========== HOOK POINTERS ==========
typedef float (*fn_GetCam)(void *instance, int type);
static fn_GetCam old_GetCameraHeightRateValue = nullptr;

typedef void (*fn_OnHeightChanged)(void *instance);
static fn_OnHeightChanged OnCameraHeightChanged = nullptr;

typedef void (*fn_CamUpdate)(void *instance);
static fn_CamUpdate old_CameraSystemUpdate = nullptr;

// ========== CAM KÉO — LOGIC CHÍNH ==========
float GetCameraHeightRateValue(void *instance, int type) {
    if (instance != NULL) {
        WideView.GetFieldOfView = old_GetCameraHeightRateValue(instance, type);
        if (WideView.SetFieldOfView != 0) {
            WideView.Active = false;
            return WideView.SetFieldOfView + WideView.GetFieldOfView;
        }
        return WideView.GetFieldOfView;
    }
    if (old_GetCameraHeightRateValue)
        return old_GetCameraHeightRateValue(instance, type);
    return 6.0f;
}

void CameraSystemUpdate(void *instance) {
    if (instance != NULL && WideView.Active) {
        if (OnCameraHeightChanged)
            OnCameraHeightChanged(instance);
    }
    if (old_CameraSystemUpdate)
        old_CameraSystemUpdate(instance);
}

// ========== PATCH STRUCT ==========
struct FuncPatch {
    uintptr_t rva;
    const char* hexOn;
    const char* hexOff;
    bool active;
};

static const struct {
    uintptr_t rva;
    const char* hex;
} antiBanPatches[] = {
    {0x5F88E3C, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5"},
    {0x4C3E394, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5"},
    {0x6C46CFC, "00 00 80 D2 C0 03 5F D6"},
    {0x6C46220, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5"},
    {0x6C45E70, "00 00 80 D2 C0 03 5F D6 1F 20 03 D5 1F 20 03 D5"},
    {0x6C462B8, "00 00 80 D2 C0 03 5F D6"},
};
static const int antiBanCount = sizeof(antiBanPatches)/sizeof(antiBanPatches[0]);

static struct FuncPatch cam3nat  = {0x525BE48, "20 00 80 D2 C0 03 5F D6", "20 00 80 52 C0 03 5F D6", false};
static struct FuncPatch showU1   = {0x5BA7218, "20 00 80 D2 C0 03 5F D6", "20 00 80 52 C0 03 5F D6", false};
static struct FuncPatch showU2   = {0x6660B80, "20 00 80 D2 C0 03 5F D6", "20 00 80 52 C0 03 5F D6", false};
static struct FuncPatch showU3   = {0x6660A1C, "20 00 80 D2 C0 03 5F D6", "20 00 80 52 C0 03 5F D6", false};
static struct FuncPatch mapPch   = {0x4826BB8, "36 00 80 D2", "36 00 80 D2", false};

// ========== UTIL ==========
uintptr_t get_lib_base(const char* libName) {
    uintptr_t base = 0;
    uint32_t cnt = _dyld_image_count();
    for (uint32_t i = 0; i < cnt; i++) {
        const char* name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, libName)) {
            base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }
    return base;
}

static bool ParseHex(const char* str, uint8_t* out, size_t maxLen, size_t* outLen) {
    size_t len = strlen(str), cnt = 0;
    char buf[3] = {0};
    for (size_t i = 0; i < len && cnt < maxLen; i++) {
        if (str[i] == ' ') continue;
        if (i + 1 >= len) break;
        buf[0] = str[i]; buf[1] = str[i+1];
        unsigned int v;
        if (sscanf(buf, "%02x", &v) == 1)
            out[cnt++] = (uint8_t)v;
        i++;
    }
    *outLen = cnt;
    return cnt > 0;
}

static bool PatchHex(uintptr_t addr, const char* hexStr) {
    if (!addr || !hexStr) return false;
    uint8_t bytes[32];
    size_t len;
    if (!ParseHex(hexStr, bytes, sizeof(bytes), &len)) return false;
    
    kern_return_t kr = vm_protect(mach_task_self(), addr, len, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) return false;
    
    memcpy((void*)addr, bytes, len);
    
    kr = vm_protect(mach_task_self(), addr, len, false, VM_PROT_READ | VM_PROT_EXECUTE);
    return kr == KERN_SUCCESS;
}

static bool TogglePatch(struct FuncPatch* p, bool on) {
    if (!il2cppBase) return false;
    p->active = on;
    return PatchHex(il2cppBase + p->rva, on ? p->hexOn : p->hexOff);
}

// ========== HACK THREAD — HOOK CAM KÉO ==========
static void* hack_thread(void*) {
    do {
        il2cppBase = get_lib_base("UnityFramework");
        usleep(500000);
    } while (!il2cppBase);
    
    LOGI(@"✅ UnityFramework: %p", (void*)il2cppBase);

    // Lấy địa chỉ hàm OnCameraHeightChanged
    OnCameraHeightChanged = (fn_OnHeightChanged)(il2cppBase + 0x107A3BC);
    LOGI(@"✅ OnHeightChanged: %p", (void*)OnCameraHeightChanged);

    // Hook Cam Kéo
    void* pCamFunc  = (void*)(il2cppBase + 0x107A2FC);
    DobbyHook(pCamFunc, (void*)GetCameraHeightRateValue, (void**)&old_GetCameraHeightRateValue);
    DobbyHook(pCamFunc, (void*)CameraSystemUpdate,    (void**)&old_CameraSystemUpdate);
    LOGI(@"✅ Cam Kéo Hook OK");

    return nullptr;
}

__attribute__((constructor))
void lib_main() {
    LOGI(@"✅ Dylib đã nạp — chờ game...");
    pthread_t th;
    pthread_create(&th, nullptr, hack_thread, nullptr);
    pthread_detach(th);
}

// ========== MENU ==========
@interface ImGuiDrawView : UIView <MTKViewDelegate>
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, assign) BOOL touchDown;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> cmdQueue;
@end

@implementation ImGuiDrawView

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            ImGuiDrawView* overlay = [[ImGuiDrawView alloc] initWithFrame:[UIScreen mainScreen].bounds];
            overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [[[UIApplication sharedApplication] keyWindow] addSubview:overlay];
        });
    });
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) [self commonInit];
    return self;
}

- (void)commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    _device = MTLCreateSystemDefaultDevice();
    _cmdQueue = [_device newCommandQueue];
    
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    ImGuiIO& io = ImGui::GetIO();
    io.Fonts->AddFontFromMemoryCompressedTTF(zzz_compressed_data, zzz_compressed_size, 18.0f);
    ImGui_ImplMetal_Init(_device);
    
    _mtkView = [[MTKView alloc] initWithFrame:self.bounds];
    _mtkView.device = _device;
    _mtkView.delegate = self;
    _mtkView.clearColor = MTLClearColorMake(0,0,0,0);
    _mtkView.opaque = NO;
    _mtkView.framebufferOnly = NO;
    [self addSubview:_mtkView];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [[touches anyObject] locationInView:self];
    if (touches.count >= 3) { MenDeal = !MenDeal; return; }
    if (MenDeal) {
        ImGuiIO& io = ImGui::GetIO();
        io.MousePos = ImVec2(p.x, p.y);
        io.MouseDown[0] = _touchDown = YES;
        return;
    }
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (MenDeal && _touchDown) {
        CGPoint p = [[touches anyObject] locationInView:self];
        ImGui::GetIO().MousePos = ImVec2(p.x, p.y);
        return;
    }
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (MenDeal) {
        ImGui::GetIO().MouseDown[0] = _touchDown = NO;
        return;
    }
    [super touchesEnded:touches withEvent:event];
}

- (void)drawInMTKView:(MTKView *)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(kWidth, kHeight);
    io.DisplayFramebufferScale = ImVec2(kScale, kScale);
    io.DeltaTime = 1.0f / 60.0f;

    MTLRenderPassDescriptor* pass = view.currentRenderPassDescriptor;
    if (!pass) return;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;

    id<MTLCommandBuffer> cmd = [_cmdQueue commandBuffer];
    id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];

    ImGui_ImplMetal_NewFrame(pass);
    ImGui::NewFrame();

    if (MenDeal && il2cppBase) {
        if (ImGui::Begin("Eri Lỏ *_*", &MenDeal)) {
            ImGui::TextColored(ImVec4(0,1,0,1), "✅ Cam Kéo Hooked");
            ImGui::Separator();

            // AntiBan
            static bool antiBanOn = false;
            if (ImGui::Checkbox("AntiBan + Xoá Tố Cáo", &antiBanOn)) {
                if (antiBanOn) {
                    for (int i = 0; i < antiBanCount; i++) {
                        PatchHex(il2cppBase + antiBanPatches[i].rva, antiBanPatches[i].hex);
                    }
                }
            }

            // ========== CAM KÉO ==========
            ImGui::Checkbox("Kéo Camera", &WideView.Active);
            float val = WideView.SetFieldOfView / 0.0362f;
            if (ImGui::SliderFloat(OBFUSCATE("2_SeekBar_Cam xa_1_100"), &val, 1.0f, 100.0f)) {
                WideView.SetFieldOfView = val * 0.0362f;
                WideView.Active = true;
            }
            ImGui::Text("Giá trị FOV: %.2f", WideView.SetFieldOfView);

            // Cam 3 Nấc
            static bool cam3On = false;
            if (ImGui::Checkbox("Cam 3 Nấc", &cam3On)) {
                TogglePatch(&cam3nat, cam3On);
            }

            // Show Kỹ Năng
            static bool showUOn = false;
            if (ImGui::Checkbox("Show Kỹ Năng", &showUOn)) {
                TogglePatch(&showU1, showUOn);
                TogglePatch(&showU2, showUOn);
                TogglePatch(&showU3, showUOn);
            }

            // Hackmap
            static bool mapOn = false;
            if (ImGui::Checkbox("Hackmap", &mapOn)) {
                TogglePatch(&mapPch, mapOn);
            }

            ImGui::End();
        }
    } else if (!il2cppBase) {
        if (ImGui::Begin("Đang chờ...", NULL)) {
            ImGui::TextColored(ImVec4(1,1,0,1), "Đang nạp UnityFramework...");
            ImGui::Text("Chạm 3 ngón tay mở menu");
            ImGui::End();
        }
    }

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmd, enc);
    [enc endEncoding];
    [cmd presentDrawable:view.currentDrawable];
    [cmd commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}

@end
