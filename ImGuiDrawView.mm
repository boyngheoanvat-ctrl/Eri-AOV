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
#import <stdio.h>
#import <string.h>

// ===== KHAI BÁO HÀM =====
#ifdef __cplusplus
extern "C" {
#endif

void Hook1110(const char* frameworkPath, uintptr_t rva, const char* originalHex);
void DeactiveCodePatch(const char* frameworkPath, uintptr_t rva, const char* originalHex);

#ifdef __cplusplus
}
#endif

extern uint32_t _dyld_image_count(void);
extern const char* _dyld_get_image_name(uint32_t image_index);
extern const struct mach_header* _dyld_get_image_header(uint32_t image_index);

#ifndef OBFUSCATE
#define OBFUSCATE(s) (s)
#endif

#define LOGI(fmt, ...) NSLog((@"[MOD] " fmt), ##__VA_ARGS__)

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale  [UIScreen mainScreen].scale

using namespace IL2CPP;

// ===== BIẾN BẠN YÊU CẦU =====
bool featureHookToggle = false;   // ✅ Đã thêm
void *instanceBtn = nullptr;      // ✅ Đã thêm
uintptr_t il2cppBase = 0;         // ✅ Đã thêm — toàn cục như cũ

// ===== HÀM TÌM BASE — FIX ẨN LIB (phiên bản iOS) =====
uintptr_t get_lib_base(const char* libName) {
    uintptr_t base = 0;
    uint32_t cnt = _dyld_image_count();
    for (uint32_t i = 0; i < cnt; i++) {
        const char* name = _dyld_get_image_name(i);
        if (!name) continue;
        // Tìm chính xác hoặc tên rút gọn
        if (strstr(name, libName)) {
            base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }
    return base;
}

static const char* const targetLibName = "UnityFramework";
static const char* const kFW = "Frameworks/UnityFramework.framework/UnityFramework";

// ===== HÀM HỖ TRỢ PATCH =====
static bool PatchMemoryEx(void* addr, const void* data, size_t len) {
    vm_prot_t old;
    if (vm_protect(mach_task_self(), (vm_address_t)addr, len, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS)
        return false;
    memcpy(addr, data, len);
    return vm_protect(mach_task_self(), (vm_address_t)addr, len, false, VM_PROT_READ | VM_PROT_EXECUTE) == KERN_SUCCESS;
}

static size_t hexToBytes(const char* hexStr, uint8_t* outBuf, size_t maxLen) {
    size_t len = strlen(hexStr);
    if (len >= 2 && hexStr[0] == '0' && (hexStr[1] == 'x' || hexStr[1] == 'X')) hexStr += 2;
    len = strlen(hexStr);
    
    size_t byteCount = 0;
    unsigned int byteVal;
    char byteStr[3] = {0};
    for (size_t i = 0; i < len && byteCount < maxLen; i += 2) {
        byteStr[0] = hexStr[i];
        byteStr[1] = hexStr[i+1] ? hexStr[i+1] : '0';
        if (sscanf(byteStr, "%02x", &byteVal) == 1) {
            outBuf[byteCount++] = (uint8_t)byteVal;
        }
    }
    return byteCount;
}

void Hook1110(const char* frameworkPath, uintptr_t rva, const char* originalHex) {
    uintptr_t base = get_lib_base(frameworkPath);
    if (!base) return;
    uint8_t bytes[16] = {0};
    size_t len = hexToBytes(originalHex, bytes, sizeof(bytes));
    if (len > 0) PatchMemoryEx((void*)(base + rva), bytes, len);
}

void DeactiveCodePatch(const char* frameworkPath, uintptr_t rva, const char* originalHex) {
    uintptr_t base = get_lib_base(frameworkPath);
    if (!base) return;
    uint8_t bytes[16] = {0};
    size_t len = hexToBytes(originalHex, bytes, sizeof(bytes));
    if (len > 0) PatchMemoryEx((void*)(base + rva), bytes, len);
}

// ===== TRỞ ĐỊA CHỈ + RVA =====
static uintptr_t UF(uintptr_t rva) {
    return il2cppBase ? il2cppBase + rva : 0;
}

static void ApplyPatch(uintptr_t rva, const char* hex) {
    Hook1110(kFW, rva, hex);
}
static void RestorePatch(uintptr_t rva, const char* hex) {
    DeactiveCodePatch(kFW, rva, hex);
}

// ========== BIẾN MODULE ==========
bool MenDeal = false;
bool camHookActive = false;
float SetFieldOfView = 6.0f;
bool showUltActive = false;
static bool s_ultApplied = false;
bool mapActive = false;
static bool s_mapApplied = false;
bool camXaActive = false;
static bool s_camXaApplied = false;

typedef float (*fn_cam)(void* _this, int type);
static fn_cam _cam = nullptr;
typedef void (*fn_Update)(void* _this);
static fn_Update _Update = nullptr;
typedef void (*fn_highrate)(void* _this);
static fn_highrate _highrate = nullptr;

// ========== CAMERA HOOK ==========
float cam(void* _this, int type) {
    if (!_cam) return 0.0f;
    return (camHookActive || featureHookToggle) ? SetFieldOfView : _cam(_this, type);
}
void Update(void* _this) { if (_Update) _Update(_this); }
void highrate(void* _this) { if (_highrate) _highrate(_this); }

// ========== ANTIBAN ==========
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

// ========== HACK THREAD — GIỮ LOGIC CỦA BẠN ==========
void *hack_thread(void *) {
    LOGI(OBFUSCATE("Hack thread started. Searching for lib..."));

    // Vòng lặp quét lib cho đến khi tìm thấy — Fix ẩn/nạp muộn
    do {
        il2cppBase = get_lib_base(targetLibName);
        if (il2cppBase == 0) {
            // Thử tên rút gọn nếu game đổi tên
            il2cppBase = get_lib_base("UnityFramework");
        }
        usleep(500000);
    } while (il2cppBase == 0);

    LOGI(OBFUSCATE("Lib found at: %p"), (void*)il2cppBase);

    ApplyAntiBanPatches();
    
    sleep(2);
    dispatch_async(dispatch_get_main_queue(), ^{
        DobbyHook((void*)UF(0x51C4048), (void*)cam, (void**)&_cam);
        DobbyHook((void*)UF(0x51C2C04), (void*)Update, (void**)&_Update);
        DobbyHook((void*)UF(0x51C46A0), (void*)highrate, (void**)&_highrate);
        LOGI(@"✅ Camera hooks đã sẵn sàng");
    });
    return nullptr;
}

// ========== INTERFACE ==========
@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, assign) BOOL touchDown;
@end

@implementation ImGuiDrawView

+ (void)showMenu:(BOOL)open { MenDeal = open; }
+ (void)showChange:(BOOL)open { MenDeal = open; }

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    [self commonInit];
    return self;
}

- (void)commonInit {
    self.device = MTLCreateSystemDefaultDevice();
    self.cmdQueue = [self.device newCommandQueue];
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    ImGuiIO& io = ImGui::GetIO();
    io.Fonts->AddFontFromMemoryCompressedTTF(zzz_compressed_data, zzz_compressed_size, 18.0f);
    ImGui_ImplMetal_Init(self.device);
    
    pthread_t th; pthread_create(&th, nullptr, hack_thread, nullptr); pthread_detach(th);
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkView = [[MTKView alloc] initWithFrame:self.view.bounds];
    self.mtkView.device = self.device;
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
        self.touchDown = YES;
        return;
    }
    [super touchesBegan:touches withEvent:event];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint p = [[touches anyObject] locationInView:self.view];
    if (MenDeal && self.touchDown) {
        ImGui::GetIO().MousePos = ImVec2(p.x, p.y);
        return;
    }
    [super touchesMoved:touches withEvent:event];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (MenDeal) {
        ImGui::GetIO().MouseDown[0] = NO;
        self.touchDown = NO;
        return;
    }
    [super touchesEnded:touches withEvent:event];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

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

    id<MTLCommandBuffer> cmd = [self.cmdQueue commandBuffer];
    id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];

    ImGui_ImplMetal_NewFrame(pass);
    ImGui::NewFrame();

    if (MenDeal) {
        ImGui::SetNextWindowSizeConstraints(ImVec2(280,200), ImVec2(kWidth*0.95f, kHeight*0.9f));
        if (ImGui::Begin("Menu AOV", &MenDeal)) {
            if (ImGui::BeginTabBar("TabBar")) {
                
                // === CAM KÉO + featureHookToggle ===
                if (ImGui::BeginTabItem("Cam Kéo")) {
                    ImGui::Checkbox("Kéo Camera", &camHookActive);
                    ImGui::Checkbox("Feature Toggle", &featureHookToggle); // ✅ Đã thêm
                    ImGui::SliderFloat("FOV", &SetFieldOfView, 0.1f, 15.0f);
                    ImGui::EndTabItem();
                }
                
                // === CAM XA ===
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
