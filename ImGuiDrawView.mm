#import "Esp/ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#include <mach-o/loader.h>
#import "5Toubun/dobby.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/zzz.h"
#import "il2cpp.h"

// ===== KHAI BÁO HÀM & MACRO =====
extern void Hook1110(const char* frameworkPath, uintptr_t rva, const char* originalHex);
extern void DeactiveCodePatch(const char* frameworkPath, uintptr_t rva, const char* originalHex);

extern uint32_t _dyld_image_count(void);
extern const char* _dyld_get_image_name(uint32_t image_index);
extern const struct mach_header* _dyld_get_image_header(uint32_t image_index);

#ifndef ENCRYPTOFFSET
#define ENCRYPTOFFSET(hexStr) ((uintptr_t)strtoull((hexStr) + 2, NULL, 16))
#endif

// ✅ SỬA: Định nghĩa macro HOOK — dùng DobbyHook trực tiếp
#ifndef HOOK
#define HOOK(addrVar, origFuncPtr, newFunc) \
    DobbyHook((void*)UF(addrVar), (void*)newFunc, (void**)&origFuncPtr)
#endif

#define OBFUSCATE(s) (s)
#define LOGI(fmt, ...) NSLog((@"[MOD] " fmt), ##__VA_ARGS__)

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale  [UIScreen mainScreen].scale

using namespace IL2CPP;

// ========== BIẾN TOÀN CỤC ==========
bool MenDeal = false;

// Camera
bool camHookActive = false;
float SetFieldOfView = 6.0f;

// Show Ult
bool showUltActive = false;
static bool s_ultApplied = false;

// Map
bool mapActive = false;
static bool s_mapApplied = false;

// Cam Xa 3 Nấc
bool camXaActive = false;
static bool s_camXaApplied = false;

// Cam Kéo — dùng HOOK
typedef float (*fn_cam)(void* _this, int type);
static fn_cam _cam = nullptr;
typedef void (*fn_Update)(void* _this);
static fn_Update _Update = nullptr;
typedef void (*fn_highrate)(void* _this);
static fn_highrate _highrate = nullptr;

static const char* const kFW = "Frameworks/UnityFramework.framework/UnityFramework";

// ========== LẤY BASE ==========
uintptr_t get_lib_base(const char* libName) {
    uintptr_t base = 0;
    uint32_t cnt = _dyld_image_count();
    for (uint32_t i = 0; i < cnt; i++) {
        const char* name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, libName) || strstr(name, "UnityFramework")) {
            base = (uintptr_t)_dyld_get_image_header(i);
            if (strstr(name, libName)) break;
        }
    }
    return base;
}

static uintptr_t il2cppBase = 0;
static uintptr_t UF(uintptr_t rva) {
    if (!il2cppBase) il2cppBase = get_lib_base("UnityFramework");
    return il2cppBase ? il2cppBase + rva : 0;
}

// ========== HÀM ÁP DỤNG / KHÔI PHỤC ==========
static void ApplyPatch(uintptr_t rva, const char* hex) {
    Hook1110(kFW, rva, hex);
}
static void RestorePatch(uintptr_t rva, const char* hex) {
    DeactiveCodePatch(kFW, rva, hex);
}

// ========== CAMERA HOOK ==========
float cam(void* _this, int type) {
    if (!_cam) return 0.0f;
    return camHookActive ? SetFieldOfView : _cam(_this, type);
}
void Update(void* _this) { if (_Update) _Update(_this); }
void highrate(void* _this) { if (_highrate) _highrate(_this); }

// ========== ÁP DỤNG ANTIBAN TỰ ĐỘNG ==========
static void ApplyAntiBanPatches() {
    LOGI(@"=== ÁP DỤNG ANTIBAN ===");
    DeactiveCodePatch(kFW, 0x5F88E3C, "0xC0035FD61F2003D51F2003D5");
    DeactiveCodePatch(kFW, 0x4C3E394, "0xC0035FD61F2003D51F2003D5");
    DeactiveCodePatch(kFW, 0x6C46CFC, "0x000080D2C0035FD6");
    DeactiveCodePatch(kFW, 0x6C46220, "0xC0035FD61F2003D51F2003D5");
    DeactiveCodePatch(kFW, 0x6C45E70, "0x000080D2C0035FD6");
    DeactiveCodePatch(kFW, 0x6C462B8, "0x000080D2C0035FD6");
    LOGI(@"✅ AntiBan đã áp dụng tự động");
}

// ========== HOOK THREAD ==========
static void* hack_thread(void*) {
    do { il2cppBase = get_lib_base("UnityFramework"); usleep(500000); } while (!il2cppBase);
    LOGI(@"UnityFramework OK");
    
    ApplyAntiBanPatches();
    
    sleep(2);
    dispatch_async(dispatch_get_main_queue(), ^{
        // ✅ SỬA: Dùng số trực tiếp thay vì ENCRYPTOFFSET trong macro
        DobbyHook((void*)UF(0x51C4048), (void*)cam, (void**)&_cam);
        DobbyHook((void*)UF(0x51C2C04), (void*)Update, (void**)&_Update);
        DobbyHook((void*)UF(0x51C46A0), (void*)highrate, (void**)&_highrate);
        LOGI(@"✅ Camera hooks đã sẵn sàng");
    });
    return nullptr;
}

// ========== IMPLEMENTATION ==========
@implementation ImGuiDrawView

// ✅ SỬA: Thêm hàm showChange bị thiếu trong .h
+ (void)showMenu:(BOOL)open { MenDeal = open; }
+ (void)showChange:(BOOL)open { MenDeal = open; }

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    [self commonInit];
    return self;
}

- (void)commonInit {
    _device = MTLCreateSystemDefaultDevice();
    _cmdQueue = [_device newCommandQueue];
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    ImGuiIO& io = ImGui::GetIO();
    io.Fonts->AddFontFromMemoryCompressedTTF(zzz_compressed_data, zzz_compressed_size, 18.0f);
    ImGui_ImplMetal_Init(_device);
    pthread_t th; pthread_create(&th, nullptr, hack_thread, nullptr); pthread_detach(th);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkView = [[MTKView alloc] initWithFrame:self.view.bounds];
    self.mtkView.device = _device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0,0,0,0);
    self.mtkView.opaque = NO;
    self.mtkView.userInteractionEnabled = YES;
    self.mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.mtkView];
}

#pragma mark - XỬ LÝ CHẠM
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [[touches anyObject] locationInView:self.view];
    if (touches.count >= 3) { MenDeal = !MenDeal; return; }
    if (MenDeal) {
        ImGuiIO& io = ImGui::GetIO();
        io.MousePos = ImVec2(p.x, p.y);
        io.MouseDown[0] = YES;
        return;
    }
    [super touchesBegan:touches withEvent:event];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!MenDeal) { [super touchesMoved:touches withEvent:event]; return; }
    ImGui::GetIO().MousePos = ImVec2([[touches anyObject] locationInView:self.view].x, [[touches anyObject] locationInView:self.view].y);
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (MenDeal) { ImGui::GetIO().MouseDown[0] = NO; return; }
    [super touchesEnded:touches withEvent:event];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self touchesEnded:touches withEvent:event]; }

#pragma mark - RENDER
- (void)drawInMTKView:(MTKView *)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(kWidth, kHeight);
    io.DisplayFramebufferScale = ImVec2(kScale, kScale);
    io.DeltaTime = 1.0f/60.0f;

    MTLRenderPassDescriptor* pass = view.currentRenderPassDescriptor;
    if (!pass) return;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,0);

    id<MTLCommandBuffer> cmd = [_cmdQueue commandBuffer];
    id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];

    ImGui_ImplMetal_NewFrame(pass);
    ImGui::NewFrame();

    if (MenDeal) {
        ImGui::SetNextWindowSizeConstraints(ImVec2(280,200), ImVec2(kWidth*0.95f, kHeight*0.9f));
        if (ImGui::Begin("Menu AOV", &MenDeal)) {
            if (ImGui::BeginTabBar("TabBar")) {
                
                // === CAM KÉO ===
                if (ImGui::BeginTabItem("Cam Kéo")) {
                    ImGui::Checkbox("Kéo Camera", &camHookActive);
                    ImGui::SliderFloat("FOV", &SetFieldOfView, 0.1f, 15.0f);
                    ImGui::EndTabItem();
                }
                
                // === CAM XA 3 NẤC ===
                if (ImGui::BeginTabItem("Cam Xa")) {
                    bool newCamXa = camXaActive;
                    if (ImGui::Checkbox("Cam Xa 3 Nấc", &newCamXa)) {
                        if (newCamXa != camXaActive) {
                            camXaActive = newCamXa;
                            if (camXaActive) {
                                ApplyPatch(0x525BE48, "0x20008052C0035FD6");
                                s_camXaApplied = true;
                            } else if (s_camXaApplied) {
                                RestorePatch(0x525BE48, "0x20008052C0035FD6");
                                s_camXaApplied = false;
                            }
                        }
                    }
                    ImGui::EndTabItem();
                }
                
                // === SHOW ULT ===
                if (ImGui::BeginTabItem("Show Ult")) {
                    bool newUlt = showUltActive;
                    if (ImGui::Checkbox("Hiện Kỹ Năng", &newUlt)) {
                        if (newUlt != showUltActive) {
                            showUltActive = newUlt;
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
                    }
                    ImGui::EndTabItem();
                }
                
                // === MAP ===
                if (ImGui::BeginTabItem("Map")) {
                    bool newMap = mapActive;
                    if (ImGui::Checkbox("Map Toàn Cục", &newMap)) {
                        if (newMap != mapActive) {
                            mapActive = newMap;
                            if (mapActive) {
                                ApplyPatch(0x4826BB8, "0x360080D2");
                                s_mapApplied = true;
                            } else if (s_mapApplied) {
                                RestorePatch(0x4826BB8, "0x360080D2");
                                s_mapApplied = false;
                            }
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
