#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import "Esp/CaptainHook.h"
#import "Esp/ImGuiDrawView.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/zzz.h"
#include "1110/patch.h"
#import "il2cpp.h"

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale  [UIScreen mainScreen].scale

using namespace IL2CPP;

// ========== BIẾN ==========
bool lockcam = false;
float SetFieldOfView = 2.0f;
bool ShowUlt = false;
bool Map = false;
bool MenDeal = true;

// ========== CAMERA HOOK ==========
float(*orig_GetCamHeight)(void* _this);
float hook_GetCamHeight(void* _this) {
    if (lockcam) return SetFieldOfView;
    return orig_GetCamHeight(_this);
}

void (*orig_Update)(void* _this);
void hook_Update(void* _this) {
    if (lockcam) return; // bỏ gọi gốc khi khóa
    if (orig_Update) orig_Update(_this);
}

void (*orig_OnCamChanged)(void* _this);
void hook_OnCamChanged(void* _this) {
    if (orig_OnCamChanged) orig_OnCamChanged(_this);
}

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> cmdQueue;
@end

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
- (MTKView *)mtkView { return (MTKView *)self.view; }
- (void)loadView { self.view = [[MTKView alloc] initWithFrame:[UIScreen mainScreen].bounds]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkView.device = _device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0,0,0,0);
    
    // === HOOK IL2CPP ===
    @try {
        void Il2CppAttachOld(void);
        Il2CppAttachOld();
        
        // Kiểm tra offset chính xác — nếu vẫn không chạy, gửi mình lại RVA đúng từ file bạn
        HOOK((uint64_t)0x51C4048, hook_GetCamHeight, orig_GetCamHeight);
        HOOK((uint64_t)0x51C2C04, hook_Update, orig_Update);
        HOOK((uint64_t)0x51C46A0, hook_OnCamChanged, orig_OnCamChanged);
    } @catch (NSException *e) {
        NSLog(@"Hook Error: %@", e);
    }
}

#pragma mark - Touch
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
                ImGui::Checkbox("🔒 Khóa Camera", &lockcam);
                ImGui::SliderFloat("📐 Độ Cao", &SetFieldOfView, 0.1f, 10.0f);
                ImGui::TextDisabled("RVA: 0x525BE48");
                ImGui::EndTabItem();
            }
            
            // === SHOW ULTR ĐỊCH ===
            if (ImGui::BeginTabItem("Show Ult Địch")) {
                ImGui::Checkbox("👁️ Hiện Kỹ Năng Địch", &ShowUlt);
                ImGui::TextDisabled("0x5BA7218 | 0x6660B80 | 0x6660A1C");
                ImGui::EndTabItem();
            }
            
            // === MAP ===
            if (ImGui::BeginTabItem("Map")) {
                ImGui::Checkbox("🗺️ Hack Map", &Map);
                ImGui::TextDisabled("RVA: 0x4826BB8");
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }
        ImGui::End();
    }

    // ========== PATCH CODE — ĐỊNH NGHĨA 1 LẦN ==========
    static char fw[] = "Frameworks/UnityFramework.framework/UnityFramework";
    const char *ret = "C0035FD61F2003D51F2003D5"; // ret = ret; ret = ret;
    const char *nop8 = "000080D2C0035FD6";          // nop + ret
    const char *pUlt = "20008052C0035FD6";           // mov w0, #0x20; ret
    const char *pMap = "360080D2";                   // mov w22, #0

    // Antiban — luôn bật
    { char p[] = "C0035FD61F2003D51F2003D5"; ActiveCodePatch(fw, 0x5F88E3C, p); }
    { char p[] = "C0035FD61F2003D51F2003D5"; ActiveCodePatch(fw, 0x4C3E394, p); }
    { char p[] = "000080D2C0035FD6";        ActiveCodePatch(fw, 0x6C46CFC, p); }
    { char p[] = "C0035FD61F2003D51F2003D5"; ActiveCodePatch(fw, 0x6C46220, p); }
    { char p[] = "000080D2C0035FD61F2003D51F2003D5"; ActiveCodePatch(fw, 0x6C45E70, p); }
    { char p[] = "000080D2C0035FD6";        ActiveCodePatch(fw, 0x6C462B8, p); }

    // ========== CAMERA PATCH ==========
    static bool camPatched = false;
    if (lockcam && !camPatched) {
        char p[] = "20008052C0035FD6";
        ActiveCodePatch(fw, 0x525BE48, p);
        camPatched = true;
    } else if (!lockcam && camPatched) {
        DeactiveCodePatch(fw, 0x525BE48, (char*)pUlt);
        camPatched = false;
    }

    // ========== SHOW ULTR ĐỊCH — 3 ĐỊA CHỈ ==========
    static bool ultPatched = false;
    if (ShowUlt && !ultPatched) {
        char p[] = "20008052C0035FD6";
        ActiveCodePatch(fw, 0x5BA7218, p);
        ActiveCodePatch(fw, 0x6660B80, p);
        ActiveCodePatch(fw, 0x6660A1C, p);
        ultPatched = true;
    } else if (!ShowUlt && ultPatched) {
        char p[] = "20008052C0035FD6";
        DeactiveCodePatch(fw, 0x5BA7218, p);
        DeactiveCodePatch(fw, 0x6660B80, p);
        DeactiveCodePatch(fw, 0x6660A1C, p);
        ultPatched = false;
    }

    // ========== HACK MAP ==========
    static bool mapPatched = false;
    if (Map && !mapPatched) {
        char p[] = "360080D2";
        ActiveCodePatch(fw, 0x4826BB8, p);
        mapPatched = true;
    } else if (!Map && mapPatched) {
        char p[] = "360080D2";
        DeactiveCodePatch(fw, 0x4826BB8, p);
        mapPatched = false;
    }

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmd, enc);
    [enc endEncoding];
    [cmd presentDrawable:view.currentDrawable];
    [cmd commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}
@end
