#import "Esp/ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#include <mach-o/loader.h>
#import "5Toubun/dobby.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/zzz.h"
#import "il2cpp.h"

// ===== KHAI BÁO HÀM DYLD =====
extern uint32_t _dyld_image_count(void);
extern const char* _dyld_get_image_name(uint32_t image_index);
extern const struct mach_header* _dyld_get_image_header(uint32_t image_index);

// ===== MACRO =====
#define OBFUSCATE(s) (s)
#define LOGI(fmt, ...) NSLog((@"[MOD] " fmt), ##__VA_ARGS__)

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale  [UIScreen mainScreen].scale

using namespace IL2CPP;

// ========== BIẾN TOÀN CỤC ==========
bool featureHookToggle = false;
void *instanceBtn = nullptr;
uintptr_t il2cppBase = 0;
bool MenDeal = true;
float SetFieldOfView = 6.0f;

// ========== LẤY ĐỊA CHỈ BASE ==========
static const char* kTargetLibName = OBFUSCATE("UnityFramework");

uintptr_t get_lib_base(const char* libName) {
    uintptr_t base = 0;
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char* name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, libName)) {
            base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
        if (strstr(name, "UnityFramework") && !base) {
            base = (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return base;
}

// ========== GHI BỘ NHỚ ==========
static bool PatchMemory(void* addr, const void* data, size_t len) {
    vm_prot_t old;
    if (vm_protect(mach_task_self(), (vm_address_t)addr, len, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS)
        return false;
    memcpy(addr, data, len);
    return vm_protect(mach_task_self(), (vm_address_t)addr, len, false, VM_PROT_READ | VM_PROT_EXECUTE) == KERN_SUCCESS;
}

// ========== RVA -> ĐỊA CHỈ ==========
static uintptr_t UF(uintptr_t rva) {
    if (il2cppBase == 0) il2cppBase = get_lib_base("UnityFramework");
    return il2cppBase ? il2cppBase + rva : 0;
}

// ==================================================
// ========== 3 HOOK ĐÚNG 100% — AN TOÀN ============
// ==================================================

// 1. GetCameraHeightRateValue(int type) : float
typedef float (*fn_GetCameraHeightRateValue)(void* _this, int type);
fn_GetCameraHeightRateValue orig_GetCameraHeightRateValue = nullptr;

float hook_GetCameraHeightRateValue(void* _this, int type) {
    if (!orig_GetCameraHeightRateValue) {
        return 0.0f;
    }
    float original = orig_GetCameraHeightRateValue(_this, type);
    if (featureHookToggle) {
        return SetFieldOfView;
    }
    return original;
}

// 2. Update() : void
typedef void (*fn_Update)(void* _this);
fn_Update orig_Update = nullptr;

void hook_Update(void* _this) {
    if (!orig_Update) return;
    orig_Update(_this);
}

// 3. OnCameraHeightChanged() : void
typedef void (*fn_OnCameraHeightChanged)(void* _this);
fn_OnCameraHeightChanged orig_OnCameraHeightChanged = nullptr;

void hook_OnCameraHeightChanged(void* _this) {
    if (!orig_OnCameraHeightChanged) return;
    orig_OnCameraHeightChanged(_this);
}

// ========== HOOK THREAD ==========
static void* hack_thread(void*) {
    LOGI(@"Đang tìm UnityFramework...");

    do {
        il2cppBase = get_lib_base(kTargetLibName);
        if (il2cppBase == 0) {
            il2cppBase = get_lib_base("UnityFramework");
        }
        usleep(500000);
    } while (il2cppBase == 0);

    LOGI(@"Tìm thấy UnityFramework");
    sleep(3);
    LOGI(@"Bắt đầu cài đặt hook...");

    dispatch_async(dispatch_get_main_queue(), ^{
        uintptr_t rva_GetCam = 0x51C4048;
        uintptr_t rva_Update  = 0x51C2C04;
        uintptr_t rva_OnCam   = 0x51C46A0;

        void* pGetCam = (void*)UF(rva_GetCam);
        void* pUpdate = (void*)UF(rva_Update);
        void* pOnCam  = (void*)UF(rva_OnCam);

        if (pGetCam && !orig_GetCameraHeightRateValue) {
            DobbyHook(pGetCam, (void*)hook_GetCameraHeightRateValue,
                     (void**)&orig_GetCameraHeightRateValue);
            LOGI(@"Hook Camera OK");
        }
        if (pUpdate && !orig_Update) {
            DobbyHook(pUpdate, (void*)hook_Update,
                     (void**)&orig_Update);
            LOGI(@"Hook Update OK");
        }
        if (pOnCam && !orig_OnCameraHeightChanged) {
            DobbyHook(pOnCam, (void*)hook_OnCameraHeightChanged,
                     (void**)&orig_OnCameraHeightChanged);
            LOGI(@"Hook OnCam OK");
        }
    });

    return nullptr;
}

// ========== IMPLEMENTATION ==========
@implementation ImGuiDrawView

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    _device = MTLCreateSystemDefaultDevice();
    _cmdQueue = [_device newCommandQueue];
    
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    ImGui::StyleColorsDark();
    io.Fonts->AddFontFromMemoryCompressedTTF((void*)zzz_compressed_data, zzz_compressed_size, 18);
    ImGui_ImplMetal_Init(_device);

    pthread_t th;
    pthread_create(&th, nullptr, hack_thread, nullptr);
    pthread_detach(th);

    return self;
}

+ (void)showMenu:(BOOL)open { MenDeal = open; }
+ (void)showChange:(BOOL)open { MenDeal = open; }

- (MTKView *)mtkView { return (MTKView *)self.view; }
- (void)loadView { self.view = [[MTKView alloc] initWithFrame:[UIScreen mainScreen].bounds]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkView.device = _device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0,0,0,0);
}

#pragma mark - Touch Input
- (void)updateIO:(UIEvent *)e {
    NSSet *touches = e.allTouches;
    UITouch *t = touches.anyObject; 
    if (!t) return;
    
    CGPoint p = [t locationInView:self.view];
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2(p.x, p.y);
    io.MouseDown[0] = (t.phase != UITouchPhaseEnded && t.phase != UITouchPhaseCancelled);
    
    // === CHẠM 3 NGÓN TAY → BẬT/TẮT MENU ===
    if (touches.count == 3 && t.phase == UITouchPhaseBegan) {
        MenDeal = !MenDeal;
        LOGI(@"Menu %@", MenDeal ? @"HIỆN" : @"ẨN");
    }
}

- (void)touchesBegan:(NSSet *)t withEvent:(UIEvent *)e { [self updateIO:e]; }
- (void)touchesMoved:(NSSet *)t withEvent:(UIEvent *)e { [self updateIO:e]; }
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e { [self updateIO:e]; }
- (void)touchesCancelled:(NSSet *)t withEvent:(UIEvent *)e { [self updateIO:e]; }

#pragma mark - Render
- (void)drawInMTKView:(MTKView*)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(kWidth, kHeight);
    io.DisplayFramebufferScale = ImVec2(kScale, kScale);
    io.DeltaTime = 1.0f/60.0f;
    self.view.userInteractionEnabled = YES;

    id<MTLCommandBuffer> cmd = [_cmdQueue commandBuffer];
    MTLRenderPassDescriptor* pass = view.currentRenderPassDescriptor;
    if (!pass) return;
    id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];

    ImGui_ImplMetal_NewFrame(pass);
    ImGui::NewFrame();

    // === NÚT DỰ PHÒNG HIỆN MENU ===
    if (!MenDeal) {
        ImGui::SetNextWindowPos(ImVec2(20, 20));
        if (ImGui::Begin("≡", nullptr, ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoDecoration)) {
            if (ImGui::Button("Hiện Menu")) {
                MenDeal = true;
            }
        }
        ImGui::End();
    }

    // === MENU CHÍNH ===
    if (MenDeal && ImGui::Begin("Menu AOV", &MenDeal)) {
        if (ImGui::BeginTabBar("TabBar")) {
            
            if (ImGui::BeginTabItem("Camera")) {
                static bool wasToggle = false;
                ImGui::Checkbox("Enable Hook", &featureHookToggle);
                ImGui::SliderFloat("FOV Value", &SetFieldOfView, 0.1f, 15.0f);
                if (featureHookToggle != wasToggle) {
                    if (featureHookToggle) {
                        LOGI(@"Hook ON");
                    } else {
                        LOGI(@"Hook OFF");
                    }
                    wasToggle = featureHookToggle;
                }
                ImGui::EndTabItem();
            }
            
            if (ImGui::BeginTabItem("Show Ult")) {
                static bool ShowUlt = false;
                static bool wasUlt = false;
                ImGui::Checkbox("Show Enemy Skill", &ShowUlt);
                if (ShowUlt != wasUlt && il2cppBase) {
                    uint32_t pOn  = 0x52800020;
                    uint32_t pOff = 0xD50320C0;
                    PatchMemory((void*)UF(0x5BA7218), ShowUlt ? &pOn : &pOff, 4);
                    PatchMemory((void*)UF(0x6660B80), ShowUlt ? &pOn : &pOff, 4);
                    PatchMemory((void*)UF(0x6660A1C), ShowUlt ? &pOn : &pOff, 4);
                    wasUlt = ShowUlt;
                }
                ImGui::EndTabItem();
            }
            
            if (ImGui::BeginTabItem("Map")) {
                static bool Map = false;
                static bool wasMap = false;
                ImGui::Checkbox("Enable Map", &Map);
                if (Map != wasMap && il2cppBase) {
                    uint32_t pOn  = 0xD2800036;
                    uint32_t pOff = 0xD50320C0;
                    PatchMemory((void*)UF(0x4826BB8), Map ? &pOn : &pOff, 4);
                    wasMap = Map;
                }
                ImGui::EndTabItem();
            }
            
            ImGui::EndTabBar();
        }
        ImGui::End();
    }

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmd, enc);
    [enc endEncoding];
    [cmd presentDrawable:view.currentDrawable];
    [cmd commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}
@end
