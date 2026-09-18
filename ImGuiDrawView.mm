#import "Esp/ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <dyld/dyld_images.h>
#import "5Toubun/dobby.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/zzz.h"
#import "il2cpp.h"

// ===== MACRO OBFUSCATE =====
#define OBFUSCATE_IMPL2(x, y) x##y
#define OBFUSCATE_IMPL1(x, y) OBFUSCATE_IMPL2(x, y)
#define OBFUSCATE(str) __attribute__((section("__TEXT,__obf"))) static const char *OBFUSCATE_IMPL1(s, __LINE__) = str; str

// ===== LOG =====
#define LOGI(fmt, ...) NSLog((@"[MOD] " fmt), ##__VA_ARGS__)

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale  [UIScreen mainScreen].scale

using namespace IL2CPP;

// ========== BIẾN BẠN YÊU CẦU ==========
bool featureHookToggle = false;
void *instanceBtn = nullptr;
uintptr_t il2cppBase = 0;

// ========== HÀM LẤY ĐỊA CHỈ BASE — PHIÊN BẢN iOS ==========
// Thay /proc/self/maps bằng dyld API — phù hợp với iOS
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
        // Thử tên rút gọn
        if (strstr(name, "UnityFramework") && !base) {
            base = (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return base;
}

// ========== HÀM GHI BỘ NHỚ ==========
static bool PatchMemory(void* addr, const void* data, size_t len) {
    vm_prot_t old;
    if (vm_protect(mach_task_self(), (vm_address_t)addr, len, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS)
        return false;
    memcpy(addr, data, len);
    return vm_protect(mach_task_self(), (vm_address_t)addr, len, false, VM_PROT_READ | VM_PROT_EXECUTE) == KERN_SUCCESS;
}

// ========== HÀM TRỢ GIÚP — RVA -> ĐỊA CHỈ ==========
static uintptr_t UF(uintptr_t rva) {
    if (il2cppBase == 0) il2cppBase = get_lib_base("UnityFramework");
    return il2cppBase ? il2cppBase + rva : 0;
}

// ========== CAMERA HOOK ==========
typedef float (*fn_GetCamHeight)(void*);
fn_GetCamHeight orig_GetCamHeight = nullptr;
float hook_GetCamHeight(void* _this) {
    if (featureHookToggle) {
        return 6.0f; // Giá trị tùy chỉnh khi bật hook
    }
    return orig_GetCamHeight ? orig_GetCamHeight(_this) : 2.0f;
}

typedef void (*fn_Update)(void*);
fn_Update orig_Update = nullptr;
void hook_Update(void* _this) {
    if (!featureHookToggle && orig_Update) orig_Update(_this);
}

typedef void (*fn_OnCamChanged)(void*);
fn_OnCamChanged orig_OnCamChanged = nullptr;
void hook_OnCamChanged(void* _this) {
    if (orig_OnCamChanged) orig_OnCamChanged(_this);
}

// ========== HOOK THREAD — CHỜ LIB NẠP XONG ==========
static void* hack_thread(void*) {
    LOGI(@"Hack thread started. Searching for UnityFramework...");

    // Chờ lib được nạp — tương tự logic Android nhưng dùng API iOS
    do {
        il2cppBase = get_lib_base(kTargetLibName);
        if (il2cppBase == 0) {
            il2cppBase = get_lib_base("UnityFramework");
        }
        usleep(500000); // 0.5s
    } while (il2cppBase == 0);

    LOGI(@"✅ UnityFramework tìm thấy tại: 0x%lx", il2cppBase);

    // === Bắt đầu Hook ===
    dispatch_async(dispatch_get_main_queue(), ^{
        uintptr_t rva_GetCam = 0x51C4048;   // Thay RVA thực tế!
        uintptr_t rva_Update  = 0x51C2C04;
        uintptr_t rva_OnCam   = 0x51C46A0;

        void* pGetCam = (void*)UF(rva_GetCam);
        void* pUpdate = (void*)UF(rva_Update);
        void* pOnCam  = (void*)UF(rva_OnCam);

        if (pGetCam) DobbyHook(pGetCam, (void*)hook_GetCamHeight, (void**)&orig_GetCamHeight);
        if (pUpdate) DobbyHook(pUpdate, (void*)hook_Update, (void**)&orig_Update);
        if (pOnCam)  DobbyHook(pOnCam,  (void*)hook_OnCamChanged, (void**)&orig_OnCamChanged);

        LOGI(@"✅ Tất cả hook đã được cài đặt!");
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

    // Khởi động thread chờ lib
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
    UITouch *t = e.allTouches.anyObject; if (!t) return;
    CGPoint p = [t locationInView:self.view];
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2(p.x, p.y);
    io.MouseDown[0] = (t.phase != UITouchPhaseEnded && t.phase != UITouchPhaseCancelled);
}
- (void)touchesBegan:(NSSet *)t withEvent:(UIEvent *)e { [self updateIO:e]; }
- (void)touchesMoved:(NSSet *)t withEvent:(UIEvent *)e { [self updateIO:e]; }
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e { [self updateIO:e]; }
- (void)touchesCancelled:(NSSet *)t withEvent:(UIEvent *)e { [self updateIO:e]; }

#pragma mark - RENDER
- (void)drawInMTKView:(MTKView*)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(kWidth, kHeight);
    io.DisplayFramebufferScale = ImVec2(kScale, kScale);
    io.DeltaTime = 1.0f/60.0f;
    self.view.userInteractionEnabled = MenDeal;

    id<MTLCommandBuffer> cmd = [_cmdQueue commandBuffer];
    MTLRenderPassDescriptor* pass = view.currentRenderPassDescriptor;
    if (!pass) return;
    id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];

    ImGui_ImplMetal_NewFrame(pass);
    ImGui::NewFrame();

    if (MenDeal && ImGui::Begin("Menu AOV", &MenDeal)) {
        if (ImGui::BeginTabBar("TabBar")) {
            
            // === CAMERA / FEATURE TOGGLE ===
            if (ImGui::BeginTabItem("Camera")) {
                static bool wasToggle = false;
                ImGui::Checkbox("🔒 Bật/Tắt Hook", &featureHookToggle);
                static float fovValue = 6.0f;
                ImGui::SliderFloat("📐 Độ cao FOV", &fovValue, 0.1f, 15.0f);
                if (featureHookToggle) {
                    // Cập nhật giá trị FOV khi bật
                    extern float SetFieldOfView;
                    SetFieldOfView = fovValue;
                }
                if (featureHookToggle != wasToggle) {
                    LOGI(featureHookToggle ? @"✅ Hook BẬT" : @"⚠️ Hook TẮT");
                    wasToggle = featureHookToggle;
                }
                ImGui::TextDisabled(@"Base: 0x%lx", il2cppBase);
                ImGui::EndTabItem();
            }
            
            // === SHOW ULT ĐỊCH ===
            if (ImGui::BeginTabItem("Show Ult")) {
                static bool ShowUlt = false;
                static bool wasUlt = false;
                ImGui::Checkbox("👁️ Hiện Kỹ Năng Địch", &ShowUlt);
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
            
            // === MAP ===
            if (ImGui::BeginTabItem("Map")) {
                static bool Map = false;
                static bool wasMap = false;
                ImGui::Checkbox("🗺️ Hack Map", &Map);
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
