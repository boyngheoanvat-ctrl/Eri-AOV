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
uintptr_t il2cppBase = 0;
bool MenDeal = false;
float SetFieldOfView = 6.0f;

// ===== ESP SETTINGS =====
bool ESP_Enable = false;
bool ESP_ShowName = true;
bool ESP_ShowDistance = true;
bool ESP_ShowBox = true;
bool ESP_ShowLine = true;

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

static uintptr_t UF(uintptr_t rva) {
    if (il2cppBase == 0) il2cppBase = get_lib_base("UnityFramework");
    return il2cppBase ? il2cppBase + rva : 0;
}

// ==================================================
// ========== CAMERA HOOK ============
// ==================================================
typedef float (*fn_GetCameraHeightRateValue)(void* _this, int type);
fn_GetCameraHeightRateValue orig_GetCameraHeightRateValue = nullptr;

float hook_GetCameraHeightRateValue(void* _this, int type) {
    if (!orig_GetCameraHeightRateValue) return 0.0f;
    float original = orig_GetCameraHeightRateValue(_this, type);
    if (featureHookToggle) return SetFieldOfView;
    return original;
}

typedef void (*fn_Update)(void* _this);
fn_Update orig_Update = nullptr;
void hook_Update(void* _this) { if (orig_Update) orig_Update(_this); }

typedef void (*fn_OnCameraHeightChanged)(void* _this);
fn_OnCameraHeightChanged orig_OnCameraHeightChanged = nullptr;
void hook_OnCameraHeightChanged(void* _this) { if (orig_OnCameraHeightChanged) orig_OnCameraHeightChanged(_this); }

// ========== HOOK THREAD ==========
static void* hack_thread(void*) {
    do {
        il2cppBase = get_lib_base(kTargetLibName);
        usleep(500000);
    } while (il2cppBase == 0);

    LOGI(@"UnityFramework OK");
    sleep(3);

    dispatch_async(dispatch_get_main_queue(), ^{
        uintptr_t rva_GetCam = 0x51C4048;
        uintptr_t rva_Update = 0x51C2C04;
        uintptr_t rva_OnCam  = 0x51C46A0;

        void* pGetCam = (void*)UF(rva_GetCam);
        void* pUpdate = (void*)UF(rva_Update);
        void* pOnCam  = (void*)UF(rva_OnCam);

        if (pGetCam && !orig_GetCameraHeightRateValue)
            DobbyHook(pGetCam, (void*)hook_GetCameraHeightRateValue, (void**)&orig_GetCameraHeightRateValue);
        if (pUpdate && !orig_Update)
            DobbyHook(pUpdate, (void*)hook_Update, (void**)&orig_Update);
        if (pOnCam && !orig_OnCameraHeightChanged)
            DobbyHook(pOnCam, (void*)hook_OnCameraHeightChanged, (void**)&orig_OnCameraHeightChanged);
    });
    return nullptr;
}

// ========== HÀM VẼ ESP ==========
static void DrawESP() {
    if (!ESP_Enable || !il2cppBase) return;
    
    ImDrawList* drawList = ImGui::GetForegroundDrawList();
    if (!drawList) return;

    // === VÍ DỤ ESP — Vẽ đường kẻ + khung tham chiếu ===
    // Khi có địa chỉ lấy tọa độ thực, thay phần này bằng dữ liệu từ game
    static float demoAngle = 0.0f;
    demoAngle += 0.02f;
    
    // Vị trí trung tâm màn hình
    ImVec2 center = ImVec2(kWidth / 2.0f, kHeight / 2.0f);
    
    // Vẽ demo: 3 "kẻ địch" di chuyển tròn — thay bằng vòng lặp lấy từ danh sách thật
    float enemyPositions[3][2] = {
        {center.x + cosf(demoAngle) * 200, center.y + sinf(demoAngle) * 150},
        {center.x + cosf(demoAngle + 2.094f) * 250, center.y + sinf(demoAngle + 2.094f) * 180},
        {center.x + cosf(demoAngle + 4.188f) * 180, center.y + sinf(demoAngle + 4.188f) * 220}
    };
    const char* enemyNames[3] = {"敌1", "敌2", "敌3"};
    float enemyDistances[3] = {15.5f, 22.3f, 18.7f};

    for (int i = 0; i < 3; i++) {
        ImVec2 pos = ImVec2(enemyPositions[i][0], enemyPositions[i][1]);
        
        // Đường kẻ từ tâm màn hình đến địch
        if (ESP_ShowLine) {
            drawList->AddLine(center, pos, IM_COL32(255, 50, 50, 200), 2.0f);
        }
        
        // Khung bao quanh địch
        if (ESP_ShowBox) {
            ImVec2 boxMin = ImVec2(pos.x - 30, pos.y - 45);
            ImVec2 boxMax = ImVec2(pos.x + 30, pos.y + 45);
            drawList->AddRect(boxMin, boxMax, IM_COL32(255, 50, 50, 220), 3.0f, 0, 2.0f);
        }
        
        // Tên
        if (ESP_ShowName) {
            char nameBuf[64];
            snprintf(nameBuf, sizeof(nameBuf), "%s", enemyNames[i]);
            drawList->AddText(ImVec2(pos.x - 25, pos.y - 60), IM_COL32(255, 255, 255, 255), nameBuf);
        }
        
        // Khoảng cách
        if (ESP_ShowDistance) {
            char distBuf[64];
            snprintf(distBuf, sizeof(distBuf), "%.1fm", enemyDistances[i]);
            drawList->AddText(ImVec2(pos.x - 20, pos.y + 50), IM_COL32(100, 255, 100, 255), distBuf);
        }
    }
}

// ========== IMPLEMENTATION ==========
@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) MTKView *mtkView;
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
    _device = MTLCreateSystemDefaultDevice();
    _cmdQueue = [_device newCommandQueue];
    
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    ImGui::StyleColorsDark();
    io.Fonts->AddFontFromMemoryCompressedTTF(zzz_compressed_data, zzz_compressed_size, 18.0f);
    ImGui_ImplMetal_Init(_device);

    pthread_t th;
    pthread_create(&th, nullptr, hack_thread, nullptr);
    pthread_detach(th);
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mtkView = [[MTKView alloc] initWithFrame:self.view.bounds];
    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.opaque = NO;
    self.mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.mtkView];
}

#pragma mark - CHẠM 3 NGÓN → BẬT/TẮT MENU
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (touches.count >= 3) {
        MenDeal = !MenDeal;
        LOGI(@"Menu: %@", MenDeal ? @"HIỆN" : @"ẨN");
    }
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
}

#pragma mark - RENDER
- (void)drawInMTKView:(MTKView *)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(kWidth, kHeight);
    io.DisplayFramebufferScale = ImVec2(kScale, kScale);
    io.DeltaTime = 1.0f / 60.0f;

    self.mtkView.userInteractionEnabled = MenDeal;

    MTLRenderPassDescriptor* pass = view.currentRenderPassDescriptor;
    if (!pass) return;

    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);

    id<MTLCommandBuffer> cmd = [self.cmdQueue commandBuffer];
    id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];

    ImGui_ImplMetal_NewFrame(pass);
    ImGui::NewFrame();

    // === VẼ ESP — LUÔN VẼ KHI BẬT ===
    DrawESP();

    // === MENU CHÍNH ===
    if (MenDeal) {
        ImGui::SetNextWindowSizeConstraints(
            ImVec2(280, 200),
            ImVec2(kWidth * 0.95f, kHeight * 0.9f)
        );

        if (ImGui::Begin("Menu AOV", &MenDeal)) {
            if (ImGui::BeginTabBar("TabBar")) {
                
                if (ImGui::BeginTabItem("Camera")) {
                    ImGui::Checkbox("Enable Hook", &featureHookToggle);
                    ImGui::SliderFloat("FOV Value", &SetFieldOfView, 0.1f, 15.0f);
                    ImGui::EndTabItem();
                }

                // === TAB ESP MỚI ===
                if (ImGui::BeginTabItem("ESP")) {
                    ImGui::Checkbox("Enable ESP", &ESP_Enable);
                    ImGui::Separator();
                    ImGui::Checkbox("Show Name", &ESP_ShowName);
                    ImGui::Checkbox("Show Distance", &ESP_ShowDistance);
                    ImGui::Checkbox("Show Box", &ESP_ShowBox);
                    ImGui::Checkbox("Show Line", &ESP_ShowLine);
                    ImGui::Spacing();
                    ImGui::TextColored(ImVec4(1, 1, 0, 1), "⚠️ Demo mode — hiển thị mẫu");
                    ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1), "Khi có địa chỉ lấy tọa độ sẽ cập nhật thật");
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("Show Ult")) {
                    static bool ShowUlt = false, wasUlt = false;
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
                    static bool Map = false, wasMap = false;
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
    }

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmd, enc);
    [enc endEncoding];
    [cmd presentDrawable:view.currentDrawable];
    [cmd commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}
@end
