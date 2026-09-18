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
bool ShowUlt = false;
bool ShowName = false;
bool ShowHP = false;
bool Map = false;
bool MenDeal = true;

// ========== CAMERA HOOK ==========
float(*cam)(void* _this);
float _cam(void* _this) {
    if (lockcam) return SetFieldOfView;
    if (cam) return cam(_this);
    return 2.0f;
}

void (*highrate)(void *instance);
void _highrate(void *instance) {
    if (highrate) highrate(instance);
}

void (*Update)(void *instance);
void _Update(void *instance) {
    if (instance != NULL) {
        _highrate(instance);
    }
    if (lockcam) {
        return;
    }
    if (Update) Update(instance);
}

// ========== MAP HOOK ==========
typedef bool (*SetVisible_t)(void* self, int camp, bool bVisible, bool forceSync);
SetVisible_t orig_SetVisible = NULL;
bool hook_SetVisible(void* self, int camp, bool bVisible, bool forceSync) {
    if (Map) return true;
    if (orig_SetVisible)
        return orig_SetVisible(self, camp, bVisible, forceSync);
    return bVisible;
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
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor clearColor];

    // ========== GẮN IL2CPP & HOOK ==========
    @try {
        void Il2CppAttachOld();
        Il2CppAttachOld();
        
        Il2CppMethod methodAccessSystem2("Project.Plugins_d.dll");
        uint64_t setVisibleOffset = methodAccessSystem2
            .getClass("NucleusDrive.Logic", "LVActorLinker")
            .getMethod("SetVisible", 3);
        if (setVisibleOffset) {
            HOOK(setVisibleOffset, hook_SetVisible, orig_SetVisible);
        }

        // ========== CAMERA HOOK — ĐÚNG OFFSET BẠN CUNG CẤP ==========
        HOOK(ENCRYPTOFFSET("0x51C4048"), _cam, cam);
        HOOK(ENCRYPTOFFSET("0x51C2C04"), _Update, Update);
        HOOK(ENCRYPTOFFSET("0x51C46A0"), _highrate, highrate);
        
    } @catch (NSException *e) {
        NSLog(@"Hook lỗi: %@", e);
    }
}

#pragma mark - Touch
- (void)updateIOWithTouchEvent:(UIEvent *)event {
    UITouch *touch = event.allTouches.anyObject;
    if (!touch) return;
    CGPoint pos = [touch locationInView:self.view];
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2(pos.x, pos.y);
    BOOL down = (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled);
    io.MouseDown[0] = down;
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
    io.DeltaTime = 1.0f / 60.0f;

    self.view.userInteractionEnabled = MenDeal;
    
    id<MTLCommandBuffer> cmd = [_commandQueue commandBuffer];
    MTLRenderPassDescriptor* pass = view.currentRenderPassDescriptor;
    if (!pass) return;
    
    id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:pass];
    
    ImGui_ImplMetal_NewFrame(pass);
    ImGui::NewFrame();
    ImGui::GetFont()->Scale = 15.f / ImGui::GetFont()->FontSize;

    ImGui::SetNextWindowPos(ImVec2((kWidth-380)/2, (kHeight-320)/2), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(380, 320), ImGuiCond_FirstUseEver);

    if (MenDeal) {
        if (ImGui::Begin("Menu AOV", &MenDeal)) {
            if (ImGui::BeginTabBar("TabBar")) {
                
                // === TAB CHỐNG CẤM ===
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

                // === TAB CAMERA ===
                if (ImGui::BeginTabItem("Camera")) {
                    ImGui::Checkbox("🔒 Khóa Camera", &lockcam);
                    ImGui::SliderFloat("📐 Độ Cao", &SetFieldOfView, 0.1f, 10.0f);
                    ImGui::TextDisabled("Patch: 0x525BE48 Auto");
                    ImGui::EndTabItem();
                }

                // === TAB ESP ===
                if (ImGui::BeginTabItem("ESP")) {
                    ImGui::Checkbox("👁️ Hiện Kỹ Năng", &ShowUlt);
                    ImGui::TextDisabled("Patch: 0x5BA7218 Auto");
                    ImGui::Checkbox("🏷️ Hiện Tên", &ShowName);
                    ImGui::TextDisabled("Patch: 0x6660A1C Auto");
                    ImGui::Checkbox("❤️ Hiện Máu", &ShowHP);
                    ImGui::TextDisabled("Patch: 0x6660B80 Auto");
                    ImGui::EndTabItem();
                }

                // === TAB MAP ===
                if (ImGui::BeginTabItem("Map")) {
                    ImGui::Checkbox("🗺️ Hack Map", &Map);
                    ImGui::TextDisabled("Patch: 0x4826BB8 Auto");
                    ImGui::EndTabItem();
                }

                ImGui::EndTabBar();
            }
        }
        ImGui::End();
    }

    // ========== PATCH — TỰ ĐỘNG BẬT/TẮT THEO CHECKBOX ==========
    static const char* fw = "Frameworks/UnityFramework.framework/UnityFramework";
    
    // ANTIBAN — LUÔN BẬT
    ActiveCodePatch(fw, 0x5F88E3C,   "C0035FD61F2003D51F2003D5");
    ActiveCodePatch(fw, 0x4C3E394,   "C0035FD61F2003D51F2003D5");
    ActiveCodePatch(fw, 0x6C46CFC,   "000080D2C0035FD6");
    ActiveCodePatch(fw, 0x6C46220,   "C0035FD61F2003D51F2003D5");
    ActiveCodePatch(fw, 0x6C45E70,   "000080D2C0035FD61F2003D51F2003D5");
    ActiveCodePatch(fw, 0x6C462B8,   "000080D2C0035FD6");
    
    // CAM XA
    static bool camActive = false;
    if (lockcam && !camActive) {
        ActiveCodePatch(fw, 0x525BE48, "20008052C0035FD6");
        camActive = true;
    } else if (!lockcam && camActive) {
        DeactiveCodePatch(fw, 0x525BE48, "20008052C0035FD6");
        camActive = false;
    }
    
    // SHOW ULT
    static bool ultActive = false;
    if (ShowUlt && !ultActive) {
        ActiveCodePatch(fw, 0x5BA7218, "20008052C0035FD6");
        ultActive = true;
    } else if (!ShowUlt && ultActive) {
        DeactiveCodePatch(fw, 0x5BA7218, "20008052C0035FD6");
        ultActive = false;
    }
    
    // SHOW HP
    static bool hpActive = false;
    if (ShowHP && !hpActive) {
        ActiveCodePatch(fw, 0x6660A1C, "20008052C0035FD6");
        hpActive = true;
    } else if (!ShowHP && hpActive) {
        DeactiveCodePatch(fw, 0x6660A1C, "20008052C0035FD6");
        hpActive = false;
    }
    
    // SHOW NAME / RANK
    static bool rankActive = false;
    if (ShowName && !rankActive) {
        ActiveCodePatch(fw, 0x6660B80, "20008052C0035FD6");
        rankActive = true;
    } else if (!ShowName && rankActive) {
        DeactiveCodePatch(fw, 0x6660B80, "20008052C0035FD6");
        rankActive = false;
    }
    
    // MAP
    static bool mapActive = false;
    if (Map && !mapActive) {
        ActiveCodePatch(fw, 0x4826BB8, "360080D2");
        mapActive = true;
    } else if (!Map && mapActive) {
        DeactiveCodePatch(fw, 0x4826BB8, "360080D2");
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
