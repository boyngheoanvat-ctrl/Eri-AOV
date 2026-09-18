#import "Esp/ImGuiDrawView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import "5Toubun/dobby.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/zzz.h"
#import "il2cpp.h"
#import <mach/mach.h>
#import <mach/vm_map.h>

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale  [UIScreen mainScreen].scale

using namespace IL2CPP;

// ========== BIẾN TOÀN CỤC ==========
bool lockcam = false;
float SetFieldOfView = 2.0f;
bool ShowUlt = false;
bool Map = false;
bool MenDeal = true;

// ========== HÀM TRỢ GIÚP LẤY ĐỊA CHỈ ==========
static uintptr_t g_ufBase = 0;
static void* GetImageBase(const char* name) {
    void* h = dlopen(name, RTLD_LAZY);
    if (!h) return nullptr;
    return dlsym(h, "_mh_execute_header");
}
static uintptr_t UF(uintptr_t rva) {
    if (!g_ufBase) g_ufBase = (uintptr_t)GetImageBase("/Frameworks/UnityFramework.framework/UnityFramework");
    return g_ufBase + rva;
}

// ========== GHI TRỰC TIẾP VÀO BỘ NHỚ ==========
static bool PatchMemory(void* addr, const void* data, size_t len) {
    vm_prot_t old;
    if (vm_protect(mach_task_self(), (vm_address_t)addr, len, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS)
        return false;
    memcpy(addr, data, len);
    return vm_protect(mach_task_self(), (vm_address_t)addr, len, false, VM_PROT_READ | VM_PROT_EXECUTE) == KERN_SUCCESS;
}

// ========== CAMERA HOOK ==========
typedef float (*fn_GetCamHeight)(void*);
fn_GetCamHeight orig_GetCamHeight = nullptr;
float hook_GetCamHeight(void* _this) {
    if (lockcam) return SetFieldOfView;
    return orig_GetCamHeight ? orig_GetCamHeight(_this) : 0.0f;
}

typedef void (*fn_Update)(void*);
fn_Update orig_Update = nullptr;
void hook_Update(void* _this) {
    if (!lockcam && orig_Update) orig_Update(_this);
}

typedef void (*fn_OnCamChanged)(void*);
fn_OnCamChanged orig_OnCamChanged = nullptr;
void hook_OnCamChanged(void* _this) {
    if (orig_OnCamChanged) orig_OnCamChanged(_this);
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
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DobbyHook((void*)UF(0x51C4048), (void*)hook_GetCamHeight, (void**)&orig_GetCamHeight);
        DobbyHook((void*)UF(0x51C2C04), (void*)hook_Update, (void**)&orig_Update);
        DobbyHook((void*)UF(0x51C46A0), (void*)hook_OnCamChanged, (void**)&orig_OnCamChanged);
        NSLog(@"✅ Hook thành công!");
    });
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
            
            // === CAMERA ===
            if (ImGui::BeginTabItem("Camera")) {
                static bool wasLock = false;
                ImGui::Checkbox("🔒 Khóa Camera", &lockcam);
                ImGui::SliderFloat("📐 Độ Cao", &SetFieldOfView, 0.1f, 10.0f);
                if (lockcam != wasLock) {
                    uint32_t pOn  = 0x52800020; // mov w0, #0x20
                    uint32_t pOff = 0xD50320C0; // ret
                    PatchMemory((void*)UF(0x525BE48), lockcam ? &pOn : &pOff, 4);
                    wasLock = lockcam;
                }
                ImGui::TextDisabled("RVA: 0x525BE48");
                ImGui::EndTabItem();
            }
            
            // === SHOW ULT ĐỊCH ===
            if (ImGui::BeginTabItem("Show Ult Địch")) {
                static bool wasUlt = false;
                ImGui::Checkbox("👁️ Hiện Kỹ Năng Địch", &ShowUlt);
                if (ShowUlt != wasUlt) {
                    uint32_t pOn  = 0x52800020;
                    uint32_t pOff = 0xD50320C0;
                    PatchMemory((void*)UF(0x5BA7218), ShowUlt ? &pOn : &pOff, 4);
                    PatchMemory((void*)UF(0x6660B80), ShowUlt ? &pOn : &pOff, 4);
                    PatchMemory((void*)UF(0x6660A1C), ShowUlt ? &pOn : &pOff, 4);
                    wasUlt = ShowUlt;
                }
                ImGui::TextDisabled("0x5BA7218 | 0x6660B80 | 0x6660A1C");
                ImGui::EndTabItem();
            }
            
            // === MAP ===
            if (ImGui::BeginTabItem("Map")) {
                static bool wasMap = false;
                ImGui::Checkbox("🗺️ Hack Map", &Map);
                if (Map != wasMap) {
                    uint32_t pOn  = 0xD2800036; // mov w22, #0
                    uint32_t pOff = 0xD50320C0;
                    PatchMemory((void*)UF(0x4826BB8), Map ? &pOn : &pOff, 4);
                    wasMap = Map;
                }
                ImGui::TextDisabled("RVA: 0x4826BB8");
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
