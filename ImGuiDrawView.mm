#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import "Esp/CaptainHook.h"
#import "Esp/ImGuiDrawView.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/zzz.h"
#import "Esp/MonoString.h"
#include "Esp/dbdef.h"
#include "1110/patch.h"
#import "il2cpp.h"
#import "linh_tinh/spam.h"

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].scale

using namespace IL2CPP;

// ========== BIẾN TOÀN CỤC ==========
bool lockcam = false;
float SetFieldOfView = 2.0f;
bool ShowUlt = false;   // 3 địa chỉ chung 1 nút
bool Map = false;
bool MenDeal = true;

// ========== CAM KÉO ==========
float(*cam)(void* _this);
float _cam(void* _this) {
    if (lockcam) return SetFieldOfView;
    return cam(_this);
}

void (*highrate)(void *instance);
void _highrate(void *instance) {
    highrate(instance);
}

void (*Update)(void *instance);
void _Update(void *instance) {
    if (instance != NULL) {
        _highrate(instance);
    }
    if (lockcam) return;
    return Update(instance);
}

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@end

@implementation ImGuiDrawView

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) return nil;
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
    if (!self.device) return nil;

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    ImGui::StyleColorsClassic();
    ImFont* font = io.Fonts->AddFontFromMemoryCompressedTTF(
        (void*)zzz_compressed_data, zzz_compressed_size, 24.0f,
        NULL, io.Fonts->GetGlyphRangesVietnamese());
    ImGui_ImplMetal_Init(_device);
    return self;
}

+ (void)showChange:(BOOL)open { MenDeal = open; }
- (MTKView *)mtkView { return (MTKView *)self.view; }
- (void)loadView {
    self.view = [[MTKView alloc] initWithFrame:[UIScreen mainScreen].bounds];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    Spam *spam = [[Spam alloc] init];
    [spam startSpam];
    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0,0,0,0);
    self.mtkView.backgroundColor = [UIColor clearColor];

    @try {
        void Il2CppAttachOld();
        Il2CppAttachOld();
        HOOK((uint64_t)0x51C4048, _cam, cam);
        HOOK((uint64_t)0x51C2C04, _Update, Update);
        HOOK((uint64_t)0x51C46A0, _highrate, highrate);
    } @catch (NSException *e) {
        NSLog(@"Hook lỗi: %@", e);
    }
}

#pragma mark - Touch
- (void)updateIOWithTouchEvent:(UIEvent *)event {
    UITouch *t = event.allTouches.anyObject;
    if (!t) return;
    CGPoint p = [t locationInView:self.view];
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2(p.x, p.y);
    io.MouseDown[0] = (t.phase != UITouchPhaseEnded && t.phase != UITouchPhaseCancelled);
}
- (void)touchesBegan:(NSSet *)t withEvent:(UIEvent *)e { [self updateIOWithTouchEvent:e]; }
- (void)touchesMoved:(NSSet *)t withEvent:(UIEvent *)e { [self updateIOWithTouchEvent:e]; }
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e { [self updateIOWithTouchEvent:e]; }
- (void)touchesCancelled:(NSSet *)t withEvent:(UIEvent *)e { [self updateIOWithTouchEvent:e]; }

#pragma mark - RENDER
- (void)drawInMTKView:(MTKView*)view
{
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(kWidth, kHeight);
    io.DisplayFramebufferScale = ImVec2(kScale, kScale);
    io.DeltaTime = 1.0f/60.0f;
    self.view.userInteractionEnabled = MenDeal;

    id<MTLCommandBuffer> cmd = [_commandQueue commandBuffer];
    MTLRenderPassDescriptor* pass = view.currentRenderPassDescriptor;
    if (!pass) return;
    id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];

    ImGui_ImplMetal_NewFrame(pass);
    ImGui::NewFrame();
    ImGui::GetFont()->Scale = 15.f / ImGui::GetFont()->FontSize;

    ImGui::SetNextWindowPos(ImVec2((kWidth-340)/2, (kHeight-300)/2), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(340, 300), ImGuiCond_FirstUseEver);

    if (MenDeal) {
        if (ImGui::Begin("Menu AOV", &MenDeal)) {
            if (ImGui::BeginTabBar("TabBar")) {
                
                // === CHỐNG CẤM ===
                if (ImGui::BeginTabItem("Chống Cấm")) {
                    ImGui::TextDisabled("Antiban Auto Bật");
                    ImGui::Separator();
                    ImGui::TextUnformatted("0x5F88E3C ✅");
                    ImGui::TextUnformatted("0x4C3E394 ✅");
                    ImGui::TextUnformatted("0x6C46CFC ✅");
                    ImGui::TextUnformatted("0x6C46220 ✅");
                    ImGui::TextUnformatted("0x6C45E70 ✅");
                    ImGui::TextUnformatted("0x6C462B8 ✅");
                    ImGui::EndTabItem();
                }

                // === CAMERA ===
                if (ImGui::BeginTabItem("Camera")) {
                    ImGui::Checkbox("🔒 Khóa Camera", &lockcam);
                    ImGui::SliderFloat("📐 Độ Cao", &SetFieldOfView, 0.1f, 10.0f);
                    ImGui::TextDisabled("Patch: 0x525BE48 ✅");
                    ImGui::EndTabItem();
                }

                // === SHOW UNT ĐỊCH — 3 MÃ CHUNG ===
                if (ImGui::BeginTabItem("Show Ult Địch")) {
                    ImGui::Checkbox("👁️ Hiện Kỹ Năng Địch", &ShowUlt);
                    ImGui::TextDisabled("0x5BA7218 | 0x6660B80 | 0x6660A1C ✅");
                    ImGui::EndTabItem();
                }

                // === MAP ===
                if (ImGui::BeginTabItem("Map")) {
                    ImGui::Checkbox("🗺️ Hack Map", &Map);
                    ImGui::TextDisabled("Patch: 0x4826BB8 ✅");
                    ImGui::EndTabItem();
                }

                ImGui::EndTabBar();
            }
        }
        ImGui::End();
    }

    static char fw[] = "Frameworks/UnityFramework.framework/UnityFramework";
    char codeUlt[] = "20008052C0035FD6";
    char codeCam[] = "20008052C0035FD6";
    char codeMap[] = "360080D2";

    // ========== ANTIBAN — LUÔN BẬT ==========
    { char p[] = "C0035FD61F2003D51F2003D5"; ActiveCodePatch(fw, 0x5F88E3C, p); }
    { char p[] = "C0035FD61F2003D51F2003D5"; ActiveCodePatch(fw, 0x4C3E394, p); }
    { char p[] = "000080D2C0035FD6";        ActiveCodePatch(fw, 0x6C46CFC, p); }
    { char p[] = "C0035FD61F2003D51F2003D5"; ActiveCodePatch(fw, 0x6C46220, p); }
    { char p[] = "000080D2C0035FD61F2003D51F2003D5"; ActiveCodePatch(fw, 0x6C45E70, p); }
    { char p[] = "000080D2C0035FD6";        ActiveCodePatch(fw, 0x6C462B8, p); }
    
    // ========== CAM KÉO ==========
    static bool camActive = false;
    if (lockcam && !camActive) {
        ActiveCodePatch(fw, 0x525BE48, codeCam);
        camActive = true;
    } else if (!lockcam && camActive) {
        DeactiveCodePatch(fw, 0x525BE48, codeCam);
        camActive = false;
    }
    
    // ========== SHOW UNT ĐỊCH — 3 ĐỊA CHỈ CÙNG 1 NÚT ==========
    static bool ultActive = false;
    if (ShowUlt && !ultActive) {
        ActiveCodePatch(fw, 0x5BA7218, codeUlt);
        ActiveCodePatch(fw, 0x6660B80, codeUlt);
        ActiveCodePatch(fw, 0x6660A1C, codeUlt);
        ultActive = true;
    } else if (!ShowUlt && ultActive) {
        DeactiveCodePatch(fw, 0x5BA7218, codeUlt);
        DeactiveCodePatch(fw, 0x6660B80, codeUlt);
        DeactiveCodePatch(fw, 0x6660A1C, codeUlt);
        ultActive = false;
    }
    
    // ========== HACK MAP ==========
    static bool mapActive = false;
    if (Map && !mapActive) {
        ActiveCodePatch(fw, 0x4826BB8, codeMap);
        mapActive = true;
    } else if (!Map && mapActive) {
        DeactiveCodePatch(fw, 0x4826BB8, codeMap);
        mapActive = false;
    }

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmd, enc);
    [enc endEncoding];
    [cmd presentDrawable:view.currentDrawable];
    [cmd commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}

@end
