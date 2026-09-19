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
// CẤU TRÚC PATCH — GIỐNG HỆT ANDROID + CAM KÉO
// ==================================================
struct My_Patches {
    uintptr_t Hackmap;
    uintptr_t Cam1, Cam2, Cam3;
    uintptr_t CamKéo1, CamKéo2, CamKéo3; // ✅ Thêm Cam Kéo
    uintptr_t Unti1, Unti2, Unti3;
    uintptr_t Lds;
    uintptr_t An;
    
    const char* Hackmap_hex;
    const char* Cam1_hex;
    const char* Cam2_hex;
    const char* Cam3_hex;
    const char* CamKéo1_hex;
    const char* CamKéo2_hex;
    const char* CamKéo3_hex;
    const char* Unti1_hex;
    const char* Unti2_hex;
    const char* Unti3_hex;
    const char* Lds_hex;
    const char* An_hex;
    
    bool Hackmap_active;
    bool Cam3Nac_active;
    bool CamKéo_active;
    bool Unti_active;
    bool Lds_active;
    bool An_active;
} hexPatches;

uintptr_t il2cppBase = 0;
bool MenDeal = false;

// ==================================================
// TÌM LIB
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

#define targetLibName OBFUSCATE("UnityFramework")

// ==================================================
// PATCH BỘ NHỚ
// ==================================================
static bool PatchBytes(uintptr_t addr, const char* hexStr) {
    if (!addr || !hexStr) return false;
    
    uint8_t bytes[32] = {0};
    size_t len = strlen(hexStr);
    size_t byteCount = 0;
    unsigned int byteVal;
    char byteStr[3] = {0};
    
    for (size_t i = 0; i < len && byteCount < 32; i++) {
        if (hexStr[i] == ' ') continue;
        if (i+1 >= len) break;
        byteStr[0] = hexStr[i];
        byteStr[1] = hexStr[i+1];
        if (sscanf(byteStr, "%02x", &byteVal) == 1)
            bytes[byteCount++] = (uint8_t)byteVal;
        i++;
    }
    
    if (byteCount == 0) return false;
    
    if (vm_protect(mach_task_self(), (vm_address_t)addr, byteCount, false,
                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS)
        return false;
    memcpy((void*)addr, bytes, byteCount);
    return vm_protect(mach_task_self(), (vm_address_t)addr, byteCount, false,
                       VM_PROT_READ | VM_PROT_EXECUTE) == KERN_SUCCESS;
}

// ==================================================
// HACK THREAD — OFFSET BẠN CUNG CẤP
// ==================================================
void *hack_thread(void *) {
    LOGI(@"🔍 Đang tìm UnityFramework...");

    do {
        il2cppBase = get_lib_base(targetLibName);
        usleep(500000);
    } while (il2cppBase == 0);

    LOGI(@"✅ Tìm thấy tại: %p", (void*)il2cppBase);

    // ========== ANTIBAN ==========
    PatchBytes(il2cppBase + 0x844D79C, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x70783C4, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x70785C4, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x9004E34, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x9004384, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x90047B8, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x900497C, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x9004B34, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x844E26C, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x844E0A0, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x844DBC4, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x844D82C, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x726CFE8, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x726CEAC, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x726DB54, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x9005C4C, "00 00 80 D2 C0 03 5F D6");
    PatchBytes(il2cppBase + 0x900503C, "C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x9004C2C, "00 00 80 D2 C0 03 5F D6 1F 20 03 D5 1F 20 03 D5");
    PatchBytes(il2cppBase + 0x90050B0, "00 00 80 D2 C0 03 5F D6");

    // ========== HACKMAP ==========
    hexPatches.Hackmap     = il2cppBase + 0x4826BB8;
    hexPatches.Hackmap_hex = "36 00 80 D2";

    // ========== CAM 3 NẤC ==========
    hexPatches.Cam1        = il2cppBase + 0x525BE48;
    hexPatches.Cam1_hex    = "20 00 80 D2 C0 03 5F D6";
    hexPatches.Cam2        = il2cppBase + 0x76CB578;
    hexPatches.Cam2_hex    = "00 00 A8 52 00 00 27 1E C0 03 5F D6";
    hexPatches.Cam3        = il2cppBase + 0x77A4410;
    hexPatches.Cam3_hex    = "00 00 A8 52 00 00 27 1E C0 03 5F D6";

    // ========== CAM KÉO ✅ MỚI THÊM ==========
    hexPatches.CamKéo1     = il2cppBase + 0x78198BC;
    hexPatches.CamKéo1_hex = "20 00 80 D2 C0 03 5F D6";
    hexPatches.CamKéo2     = il2cppBase + 0x76CB578;
    hexPatches.CamKéo2_hex = "00 00 A8 52 00 00 27 1E C0 03 5F D6";
    hexPatches.CamKéo3     = il2cppBase + 0x77A4410;
    hexPatches.CamKéo3_hex = "00 00 A8 52 00 00 27 1E C0 03 5F D6";

    // ========== SHOW ULT ==========
    hexPatches.Unti1       = il2cppBase + 0x5BA7218;
    hexPatches.Unti1_hex   = "20 00 80 D2 C0 03 5F D6";
    hexPatches.Unti2       = il2cppBase + 0x6660B80;
    hexPatches.Unti2_hex   = "20 00 80 D2 C0 03 5F D6";
    hexPatches.Unti3       = il2cppBase + 0x6660A1C;
    hexPatches.Unti3_hex   = "20 00 80 D2 C0 03 5F D6";

    // ========== SHOW LSĐ ==========
    hexPatches.Lds         = il2cppBase + 0x57931E4;
    hexPatches.Lds_hex     = "20 00 80 D2 C0 03 5F D6";

    // ========== KHÓA TIA ELSU ==========
    hexPatches.An          = il2cppBase + 0x5C5B628;
    hexPatches.An_hex      = "20 00 80 D2 C0 03 5F D6";

    // Trạng thái ban đầu
    hexPatches.Hackmap_active = false;
    hexPatches.Cam3Nac_active = false;
    hexPatches.CamKéo_active  = false;
    hexPatches.Unti_active    = false;
    hexPatches.Lds_active     = false;
    hexPatches.An_active      = false;

    LOGI(@"✅ Tất cả offset đã nạp!");
    return NULL;
}

// ==================================================
// KHỞI TẠO
// ==================================================
__attribute__((constructor))
void lib_main() {
    LOGI(@"✅ Dylib đã nạp — chờ game...");
    pthread_t ptid;
    pthread_create(&ptid, NULL, hack_thread, NULL);
    pthread_detach(ptid);
}

// ==================================================
// MENU ImGui
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

    if (MenDeal && il2cppBase) {
        ImGui::SetNextWindowPos(ImVec2(20, 80), ImGuiCond_FirstUseEver);
        if (ImGui::Begin("Eri Lỏ *_*", &MenDeal)) {
            
            ImGui::TextColored(ImVec4(0,1,0,1), "✅ AntiCheat + Xoá Tố Cáo: Đã bật");
            ImGui::Separator();
            
            // Hackmap
            bool bHack = hexPatches.Hackmap_active;
            if (ImGui::Checkbox("Hackmap", &bHack)) {
                hexPatches.Hackmap_active = bHack;
                PatchBytes(hexPatches.Hackmap, bHack ? hexPatches.Hackmap_hex : "36 00 80 D2");
            }
            
            // Cam 3 Nấc
            bool bCam3 = hexPatches.Cam3Nac_active;
            if (ImGui::Checkbox("Cam 3 Nấc", &bCam3)) {
                hexPatches.Cam3Nac_active = bCam3;
                if (bCam3) {
                    PatchBytes(hexPatches.Cam1, hexPatches.Cam1_hex);
                    PatchBytes(hexPatches.Cam2, hexPatches.Cam2_hex);
                    PatchBytes(hexPatches.Cam3, hexPatches.Cam3_hex);
                } else {
                    PatchBytes(hexPatches.Cam1, "20 00 80 D2 C0 03 5F D6");
                    PatchBytes(hexPatches.Cam2, "00 00 A8 52 00 00 27 1E C0 03 5F D6");
                    PatchBytes(hexPatches.Cam3, "00 00 A8 52 00 00 27 1E C0 03 5F D6");
                }
            }
            
            // Cam Kéo ✅ MỚI
            bool bCamK = hexPatches.CamKéo_active;
            if (ImGui::Checkbox("Cam Kéo", &bCamK)) {
                hexPatches.CamKéo_active = bCamK;
                if (bCamK) {
                    PatchBytes(hexPatches.CamKéo1, hexPatches.CamKéo1_hex);
                    PatchBytes(hexPatches.CamKéo2, hexPatches.CamKéo2_hex);
                    PatchBytes(hexPatches.CamKéo3, hexPatches.CamKéo3_hex);
                } else {
                    PatchBytes(hexPatches.CamKéo1, "20 00 80 D2 C0 03 5F D6");
                    PatchBytes(hexPatches.CamKéo2, "00 00 A8 52 00 00 27 1E C0 03 5F D6");
                    PatchBytes(hexPatches.CamKéo3, "00 00 A8 52 00 00 27 1E C0 03 5F D6");
                }
            }
            
            // Show Kỹ Năng
            bool bUnti = hexPatches.Unti_active;
            if (ImGui::Checkbox("Show Kỹ Năng", &bUnti)) {
                hexPatches.Unti_active = bUnti;
                if (bUnti) {
                    PatchBytes(hexPatches.Unti1, hexPatches.Unti1_hex);
                    PatchBytes(hexPatches.Unti2, hexPatches.Unti2_hex);
                    PatchBytes(hexPatches.Unti3, hexPatches.Unti3_hex);
                } else {
                    PatchBytes(hexPatches.Unti1, "20 00 80 D2 C0 03 5F D6");
                    PatchBytes(hexPatches.Unti2, "20 00 80 D2 C0 03 5F D6");
                    PatchBytes(hexPatches.Unti3, "20 00 80 D2 C0 03 5F D6");
                }
            }
            
            // Show LSĐ
            bool bLds = hexPatches.Lds_active;
            if (ImGui::Checkbox("Show LSĐ", &bLds)) {
                hexPatches.Lds_active = bLds;
                PatchBytes(hexPatches.Lds, bLds ? hexPatches.Lds_hex : "20 00 80 D2 C0 03 5F D6");
            }
            
            // Khóa Tia Elsu
            bool bAn = hexPatches.An_active;
            if (ImGui::Checkbox("Khóa Tia Elsu", &bAn)) {
                hexPatches.An_active = bAn;
                PatchBytes(hexPatches.An, bAn ? hexPatches.An_hex : "20 00 80 D2 C0 03 5F D6");
            }
            
            ImGui::End();
        }
    } else if (!il2cppBase) {
        ImGui::SetNextWindowPos(ImVec2(20, 80), ImGuiCond_FirstUseEver);
        if (ImGui::Begin("Đang chờ...", NULL)) {
            ImGui::TextColored(ImVec4(1,1,0,1), "Đang tìm UnityFramework...");
            ImGui::Text("Chờ vài giây rồi chạm 3 ngón tay mở menu");
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
