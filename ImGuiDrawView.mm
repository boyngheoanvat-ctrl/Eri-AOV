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

// ========== BIẾN TOÀN CỤC ==========
uintptr_t il2cppBase = 0;
bool MenDeal = false;
float SetFieldOfView = 6.0f;
bool lockcam = false;

// ========== PATCH STRUCT ==========
struct PatchItem {
    uintptr_t rva;
    const char* hex;
    bool active;
    uint8_t original[32];
    size_t len;
} antiBan[6] = {
    {0x5F88E3C, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5", false, {0}, 8},
    {0x4C3E394, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5", false, {0}, 8},
    {0x6C46CFC, "00 00 80 D2 C0 03 5F D6", false, {0}, 6},
    {0x6C46220, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5", false, {0}, 8},
    {0x6C45E70, "00 00 80 D2 C0 03 5F D6 1F 20 03 D5 1F 20 03 D5", false, {0}, 10},
    {0x6C462B8, "00 00 80 D2 C0 03 5F D6", false, {0}, 6},
};

struct FuncPatch {
    uintptr_t rva;
    const char* hexOn;
    const char* hexOff;
    bool active;
} cam3nat = {0x525BE48, "20 00 80 D2 C0 03 5F D6", "20 00 80 52 C0 03 5F D6", false};
struct FuncPatch showU1 = {0x5BA7218, "20 00 80 D2 C0 03 5F D6", "20 00 80 52 C0 03 5F D6", false};
struct FuncPatch showU2 = {0x6660B80, "20 00 80 D2 C0 03 5F D6", "20 00 80 52 C0 03 5F D6", false};
struct FuncPatch showU3 = {0x6660A1C, "20 00 80 D2 C0 03 5F D6", "20 00 80 52 C0 03 5F D6", false};
struct FuncPatch mapPch = {0x4826BB8, "36 00 80 D2", "36 00 80 D2", false};

// ========== CAM HOOK ==========
typedef float (*fn_cam)(void* _this, int type);
static fn_cam orig_cam = nullptr;
float hook_cam(void* _this, int type) {
    if (lockcam) return SetFieldOfView;
    return orig_cam ? orig_cam(_this, type) : 6.0f;
}

typedef void (*fn_Update)(void* _this);
static fn_Update orig_Update = nullptr;
void hook_Update(void* _this) {
    if (orig_Update && !lockcam) orig_Update(_this);
}

typedef void (*fn_HighRate)(void* _this);
static fn_HighRate orig_HighRate = nullptr;
void hook_HighRate(void* _this) {
    if (orig_HighRate) orig_HighRate(_this);
}

// ========== UTIL ==========
uintptr_t get_lib_base(const char* libName) {
    uintptr_t base = 0;
    uint32_t cnt = _dyld_image_count();
    for (uint32_t i = 0; i < cnt; i++) {
        const char* name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, libName)) { base = (uintptr_t)_dyld_get_image_header(i); break; }
    }
    return base;
}

static bool ParseHex(const char* str, uint8_t* out, size_t maxLen, size_t* outLen) {
    size_t len = strlen(str), cnt = 0;
    char buf[3] = {0};
    for (size_t i = 0; i < len && cnt < maxLen; i++) {
        if (str[i] == ' ') continue;
        if (i+1 >= len) break;
        buf[0] = str[i]; buf[1] = str[i+1];
        unsigned int v;
        if (sscanf(buf, "%02x", &v) == 1) out[cnt++] = (uint8_t)v;
        i++;
    }
    *outLen = cnt;
    return cnt > 0;
}

static bool PatchHex(uintptr_t addr, const char* hexStr) {
    if (!addr) return false;
    uint8_t bytes[32]; size_t len;
    if (!ParseHex(hexStr, bytes, sizeof(bytes), &len)) return false;
    vm_protect(mach_task_self(), addr, len, false, VM_PROT_READ|VM_PROT_WRITE|VM_PROT_COPY);
    memcpy((void*)addr, bytes, len);
    return vm_protect(mach_task_self(), addr, len, false, VM_PROT_READ|VM_PROT_EXECUTE) == KERN_SUCCESS;
}

static bool TogglePatch(struct FuncPatch* p, bool on) {
    if (!il2cppBase) return false;
    p->active = on;
    return PatchHex(il2cppBase + p->rva, on ? p->hexOn : p->hexOff);
}

// ========== HACK THREAD ==========
static void* hack_thread(void*) {
    do { il2cppBase = get_lib_base("UnityFramework"); usleep(500000); } while (!il2cppBase);
    LOGI(@"✅ UnityFramework: %p", (void*)il2cppBase);

    // AntiBan — chỉ áp khi bật, không tự patch lúc khởi động
    for (int i = 0; i < 6; i++) antiBan[i].active = false;

    // Hook Cam Kéo
    dispatch_async(dispatch_get_main_queue(), ^{
        void* pCam = (void*)(il2cppBase + 0x51C4048);
        void* pUpd = (void*)(il2cppBase + 0x51C2C04);
        void* pHig = (void*)(il2cppBase + 0x51C46A0);
        if (pCam) DobbyHook(pCam, (void*)hook_cam, (void**)&orig_cam);
        if (pUpd) DobbyHook(pUpd, (void*)hook_Update, (void**)&orig_Update);
        if (pHig) DobbyHook(pHig, (void*)hook_HighRate, (void**)&orig_HighRate);
        LOGI(@"✅ Cam Hook OK");
    });
    return nullptr;
}

__attribute__((constructor))
void lib_main() {
    pthread_t th; pthread_create(&th, nullptr, hack_thread, nullptr); pthread_detach(th);
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
            ImGuiDrawView* o = [[ImGuiDrawView alloc] initWithFrame:[UIScreen mainScreen].bounds];
            o.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            [[[UIApplication sharedApplication] keyWindow] addSubview:o];
        });
    });
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) [self commonInit];
    return self;
}

- (void)commonInit {
    self.backgroundColor = UIColor.clearColor; self.opaque = NO;
    _device = MTLCreateSystemDefaultDevice(); _cmdQueue = [_device newCommandQueue];
    ImGui::CreateContext(); ImGui::StyleColorsDark();
    ImGuiIO& io = ImGui::GetIO();
    io.Fonts->AddFontFromMemoryCompressedTTF(zzz_compressed_data, zzz_compressed_size, 18);
    ImGui_ImplMetal_Init(_device);
    _mtkView = [[MTKView alloc] initWithFrame:self.bounds];
    _mtkView.device = _device; _mtkView.delegate = self;
    _mtkView.clearColor = MTLClearColorMake(0,0,0,0); _mtkView.opaque = NO;
    _mtkView.framebufferOnly = NO;
    [self addSubview:_mtkView];
}

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
    CGPoint p = [[touches anyObject] locationInView:self];
    if (touches.count >= 3) { MenDeal = !MenDeal; return; }
    if (MenDeal) { ImGui::GetIO().MousePos = ImVec2(p.x,p.y); ImGui::GetIO().MouseDown[0] = _touchDown = YES; return; }
    [super touchesBegan:touches withEvent:event];
}
- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event {
    if (MenDeal && _touchDown) { CGPoint p = [[touches anyObject] locationInView:self]; ImGui::GetIO().MousePos = ImVec2(p.x,p.y); return; }
    [super touchesMoved:touches withEvent:event];
}
- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
    if (MenDeal) { ImGui::GetIO().MouseDown[0] = _touchDown = NO; return; }
    [super touchesEnded:touches withEvent:event];
}

- (void)drawInMTKView:(MTKView*)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(kWidth,kHeight); io.DisplayFramebufferScale = ImVec2(kScale,kScale); io.DeltaTime = 1/60.0f;
    MTLRenderPassDescriptor* pass = view.currentRenderPassDescriptor; if (!pass) return;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    id<MTLCommandBuffer> cmd = [_cmdQueue commandBuffer];
    id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];
    ImGui_ImplMetal_NewFrame(pass); ImGui::NewFrame();

    if (MenDeal && il2cppBase) {
        if (ImGui::Begin("Eri Lỏ *_*", &MenDeal)) {
            ImGui::TextColored(ImVec4(0,1,0,1), "UnityFramework OK");
            ImGui::Separator();

            // AntiBan
            static bool antiOn = false;
            if (ImGui::Checkbox("AntiBan + Xoá Tố Cáo", &antiOn)) {
                for (int i = 0; i < 6; i++) {
                    if (antiOn) PatchHex(il2cppBase + antiBan[i].rva, antiBan[i].hex);
                    antiBan[i].active = antiOn;
                }
            }

            // Cam Kéo (Hook)
            ImGui::Checkbox("Cam Kéo (Lock)", &lockcam);
            ImGui::SliderFloat("FOV Value", &SetFieldOfView, 0.1f, 15.0f);

            // Cam 3 Nấc
            static bool cam3On = false;
            if (ImGui::Checkbox("Cam 3 Nấc", &cam3On)) TogglePatch(&cam3nat, cam3On);

            // Show Kỹ Năng
            static bool showUOn = false;
            if (ImGui::Checkbox("Show Kỹ Năng", &showUOn)) {
                TogglePatch(&showU1, showUOn);
                TogglePatch(&showU2, showUOn);
                TogglePatch(&showU3, showUOn);
            }

            // Hackmap
            static bool mapOn = false;
            if (ImGui::Checkbox("Hackmap", &mapOn)) TogglePatch(&mapPch, mapOn);

            ImGui::End();
        }
    } else if (!il2cppBase) {
        if (ImGui::Begin("Đang chờ...", NULL)) {
            ImGui::TextColored(ImVec4(1,1,0,1), "Đang nạp UnityFramework...");
            ImGui::End();
        }
    }

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmd, enc);
    [enc endEncoding]; [cmd presentDrawable:view.currentDrawable]; [cmd commit];
}
- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}
@end
