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

// ==================================================
// BIẾN TOÀN CỤC
// ==================================================
bool featureHookToggle = false;
void *instanceBtn = nullptr;
uintptr_t il2cppBase = 0;
bool MenDeal = false;

bool camHookActive = false;
float SetFieldOfView = 6.0f;
bool camXaActive = false;
static bool s_camXaApplied = false;
bool showUltActive = false;
static bool s_ultApplied = false;
bool mapActive = false;
static bool s_mapApplied = false;

// ==================================================
// TÌM UNITYFRAMEWORK
// ==================================================
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

static const char* const targetLibName = "UnityFramework";
static const char* const kFW = "Frameworks/UnityFramework.framework/UnityFramework";

// ==================================================
// PATCH BỘ NHỚ — AN TOÀN
// ==================================================
static bool PatchMemoryEx(void* addr, const void* data, size_t len) {
    if (!addr) return false;
    if (vm_protect(mach_task_self(), (vm_address_t)addr, len, false,
                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS)
        return false;
    memcpy(addr, data, len);
    return vm_protect(mach_task_self(), (vm_address_t)addr, len, false,
                       VM_PROT_READ | VM_PROT_EXECUTE) == KERN_SUCCESS;
}

static size_t hexToBytes(const char* hexStr, uint8_t* outBuf, size_t maxLen) {
    size_t len = strlen(hexStr);
    if (len >= 2 && hexStr[0] == '0' && (hexStr[1] == 'x' || hexStr[1] == 'X'))
        hexStr += 2;
    len = strlen(hexStr);
    size_t byteCount = 0;
    unsigned int byteVal;
    char byteStr[3] = {0};
    for (size_t i = 0; i < len && byteCount < maxLen; i += 2) {
        byteStr[0] = hexStr[i];
        byteStr[1] = (i+1 < len) ? hexStr[i+1] : '0';
        if (sscanf(byteStr, "%02x", &byteVal) == 1)
            outBuf[byteCount++] = (uint8_t)byteVal;
    }
    return byteCount;
}

void Hook1110(const char* frameworkPath, uintptr_t rva, const char* hex) {
    uintptr_t base = get_lib_base(frameworkPath);
    if (!base || rva == 0) return;
    uint8_t bytes[16] = {0};
    size_t len = hexToBytes(hex, bytes, sizeof(bytes));
    if (len > 0) PatchMemoryEx((void*)(base + rva), bytes, len);
}
void DeactiveCodePatch(const char* frameworkPath, uintptr_t rva, const char* hex) {
    Hook1110(frameworkPath, rva, hex);
}

static uintptr_t UF(uintptr_t rva) {
    return il2cppBase ? il2cppBase + rva : 0;
}
static void ApplyPatch(uintptr_t rva, const char* hex)  { if(il2cppBase) Hook1110(kFW, rva, hex); }
static void RestorePatch(uintptr_t rva, const char* hex) { if(il2cppBase) Hook1110(kFW, rva, hex); }

// ==================================================
// HOOK CAMERA
// ==================================================
typedef float (*fn_cam)(void* _this, int type); static fn_cam _cam = nullptr;
typedef void (*fn_Update)(void* _this);          static fn_Update _Update = nullptr;
typedef void (*fn_highrate)(void* _this);         static fn_highrate _highrate = nullptr;

float cam(void* _this, int type) {
    if (!_cam) return 0.0f;
    return (camHookActive || featureHookToggle) ? SetFieldOfView : _cam(_this, type);
}
void Update(void* _this)     { if (_Update) _Update(_this); }
void highrate(void* _this)   { if (_highrate) _highrate(_this); }

// ==================================================
// ANTIBAN
// ==================================================
static void ApplyAntiBanPatches() {
    if (!il2cppBase) return;
    LOGI(@"=== ÁP DỤNG ANTIBAN ===");
    DeactiveCodePatch(kFW, 0x5F88E3C, "0xC0035FD61F2003D51F2003D5");
    DeactiveCodePatch(kFW, 0x4C3E394, "0xC0035FD61F2003D51F2003D5");
    DeactiveCodePatch(kFW, 0x6C46CFC, "0x000080D2C0035FD6");
    DeactiveCodePatch(kFW, 0x6C46220, "0xC0035FD61F2003D51F2003D5");
    DeactiveCodePatch(kFW, 0x6C45E70, "0x000080D2C0035FD6");
    DeactiveCodePatch(kFW, 0x6C462B8, "0x000080D2C0035FD6");
    LOGI(@"✅ AntiBan đã sẵn sàng");
}

// ==================================================
// KHỞI TẠO — TRÌ HOÃN AN TOÀN
// ==================================================
static bool __attribute__((constructor)) mod_init() {
    LOGI(@"✅ Dylib đã nạp — chờ game khởi động...");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        do {
            il2cppBase = get_lib_base(targetLibName);
            if (il2cppBase == 0) il2cppBase = get_lib_base("UnityFramework");
            if (il2cppBase == 0) usleep(500000);
        } while (il2cppBase == 0);

        LOGI(@"✅ Lib tìm thấy tại: %p", (void*)il2cppBase);
        ApplyAntiBanPatches();
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (UF(0x51C4048)) DobbyHook((void*)UF(0x51C4048), (void*)cam,     (void**)&_cam);
            if (UF(0x51C2C04)) DobbyHook((void*)UF(0x51C2C04), (void*)Update,   (void**)&_Update);
            if (UF(0x51C46A0)) DobbyHook((void*)UF(0x51C46A0), (void*)highrate, (void**)&_highrate);
            LOGI(@"✅ Hook hoàn tất");
        });
    });
    return true;
}

// ==================================================
// MENU & GIAO DIỆN
// ==================================================
@interface ImGuiDrawView : UIView <MTKViewDelegate>
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, assign) BOOL touchDown;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> cmdQueue;
@end

@implementation ImGuiDrawView

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ImGuiDrawView *overlay = [[ImGuiDrawView alloc] initWithFrame:[UIScreen mainScreen].bounds];
            overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [[[UIApplication sharedApplication] keyWindow] addSubview:overlay];
        });
    });
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    self.userInteractionEnabled = YES;
    
    self.device = MTLCreateSystemDefaultDevice();
    self.cmdQueue = [self.device newCommandQueue];
    
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    ImGuiIO& io = ImGui::GetIO();
    io.Fonts->AddFontFromMemoryCompressedTTF(zzz_compressed_data, zzz_compressed_size, 18.0f);
    ImGui_ImplMetal_Init(self.device);
    
    self.mtkView = [[MTKView alloc] initWithFrame:self.bounds];
    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0,0,0,0);
    self.mtkView.opaque = NO;
    self.mtkView.userInteractionEnabled = NO;
    self.mtkView.framebufferOnly = NO;
    self.mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.mtkView];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [[touches anyObject] locationInView:self];
    if (touches.count >= 3) { MenDeal = !MenDeal; return; }
    if (MenDeal) {
        ImGuiIO& io = ImGui::GetIO();
        io.MousePos = ImVec2(p.x, p.y);
        io.MouseDown[0] = true;
        self.touchDown = YES;
        return;
    }
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [[touches anyObject] locationInView:self];
    if (MenDeal && self.touchDown) {
        ImGui::GetIO().MousePos = ImVec2(p.x, p.y);
        return;
    }
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (MenDeal) {
        ImGui::GetIO().MouseDown[0] = false;
        self.touchDown = NO;
        return;
    }
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

- (void)drawInMTKView:(MTKView *)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(kWidth, kHeight);
    io.DisplayFramebufferScale = ImVec2(kScale, kScale);
    io.DeltaTime = 1.0f / 60.0f;

    MTLRenderPassDescriptor* pass = view.currentRenderPassDescriptor;
    if (!pass) return;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,0);

    id<MTLCommandBuffer> cmd = [self.cmdQueue commandBuffer];
    id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];

    ImGui_ImplMetal_NewFrame(pass);
    ImGui::NewFrame();

    if (MenDeal) {
        ImGui::SetNextWindowPos(ImVec2(20, 80), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSizeConstraints(ImVec2(280, 200), ImVec2(kWidth*0.95f, kHeight*0.9f));
        
        if (ImGui::Begin("Menu AOV", &MenDeal)) {
            if (ImGui::BeginTabBar("TabBar")) {
                
                if (ImGui::BeginTabItem("Cam Kéo")) {
                    ImGui::Checkbox("Kéo Camera", &camHookActive);
                    ImGui::Checkbox("Feature Toggle", &featureHookToggle);
                    ImGui::SliderFloat("FOV", &SetFieldOfView, 0.1f, 15.0f);
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("Cam Xa")) {
                    if (ImGui::Checkbox("Cam Xa 3 Nấc", &camXaActive)) {
                        if (camXaActive) {
                            ApplyPatch(0x525BE48, "0x20008052C0035FD6");
                            s_camXaApplied = true;
                        } else if (s_camXaApplied) {
                            RestorePatch(0x525BE48, "0x20008052C0035FD6");
                            s_camXaApplied = false;
                        }
                    }
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("Show Ult")) {
                    if (ImGui::Checkbox("Hiện Kỹ Năng", &showUltActive)) {
                        if (showUltActive) {
                            ApplyPatch(0x5BA7218, "0x20008052C0035FD6");
                            ApplyPatch(0x6660B80, "0x20008052C0035FD6");
                            ApplyPatch(0x6660A1C, "0x20008052C0035FD6");
                            s_ultApplied = true;
                        } else if (s_ultApplied) {
                            RestorePatch(0x5BA7218, "0x20008052C0035FD6");
                            RestorePatch(0x6660B80, "0x20008052C0035FD6");
                            RestorePatch(0x6660A1C, "0x20008052C0035FD6");
                            s_ultApplied = false;
                        }
                    }
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("Map")) {
                    if (ImGui::Checkbox("Map Toàn Cục", &mapActive)) {
                        if (mapActive) {
                            ApplyPatch(0x4826BB8, "0x360080D2");
                            s_mapApplied = true;
                        } else if (s_mapApplied) {
                            RestorePatch(0x4826BB8, "0x360080D2");
                            s_mapApplied = false;
                        }
                    }
                    ImGui::EndTabItem();
                }
                
                ImGui::EndTabBar();
            }
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
