#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>

#import "CangHuiMetalSurfaceView.h"
#import "CangHuiNativeSurface.h"
#import "CangHuiRuntimeBootstrap.h"

#include <math.h>
#include <stdint.h>

static const int64_t CangHuiSurfaceTaskTimeoutNanos = 5000000000LL;

@interface CangHuiDisplayLinkDriver : NSObject
- (instancetype)initWithGenerationProvider:(int64_t (^)(void))generationProvider
    frameHandler:(void (^)(void))frameHandler;
- (void)start;
- (void)stop;
@end

typedef struct CangHuiAttachArguments {
    int64_t handle;
    int64_t logicalWidth;
    int64_t logicalHeight;
    int64_t pixelWidth;
    int64_t pixelHeight;
    int64_t scale;
    int64_t generation;
} CangHuiAttachArguments;

typedef struct CangHuiResizeArguments {
    int64_t logicalWidth;
    int64_t logicalHeight;
    int64_t pixelWidth;
    int64_t pixelHeight;
    int64_t scale;
    int64_t generation;
} CangHuiResizeArguments;

static void *CangHuiAttachTask(void *rawArguments) {
    CangHuiAttachArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_attach(
        arguments->handle,
        arguments->logicalWidth,
        arguments->logicalHeight,
        arguments->pixelWidth,
        arguments->pixelHeight,
        arguments->scale,
        arguments->generation);
}

static void *CangHuiResizeTask(void *rawArguments) {
    CangHuiResizeArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_resize(
        arguments->logicalWidth,
        arguments->logicalHeight,
        arguments->pixelWidth,
        arguments->pixelHeight,
        arguments->scale,
        arguments->generation);
}

static void *CangHuiDetachTask(void *rawGeneration) {
    return (void *)(intptr_t)canghui_ios_surface_detach((int64_t)(intptr_t)rawGeneration);
}

static void *CangHuiClearColorTask(void *unused) {
    (void)unused;
    return (void *)(intptr_t)canghui_ios_surface_clear_color_argb();
}

@interface CangHuiMetalSurfaceView ()
@property(nonatomic, strong, readwrite) id<MTLDevice> canghuiDevice;
@property(nonatomic, strong, readwrite) id<MTLCommandQueue> canghuiCommandQueue;
@property(nonatomic, strong) CangHuiDisplayLinkDriver *canghuiDisplayLink;
@property(nonatomic, assign) int64_t canghuiGeneration;
@property(nonatomic, assign) BOOL canghuiAttached;
@end

@implementation CangHuiMetalSurfaceView

+ (Class)layerClass {
    return CAMetalLayer.class;
}

- (CAMetalLayer *)canghuiMetalLayer {
    return (CAMetalLayer *)self.layer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _canghuiDevice = MTLCreateSystemDefaultDevice();
        _canghuiCommandQueue = [_canghuiDevice newCommandQueue];
        CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
        metalLayer.device = _canghuiDevice;
        metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        metalLayer.framebufferOnly = YES;
        __weak CangHuiMetalSurfaceView *weakSelf = self;
        _canghuiDisplayLink = [[CangHuiDisplayLinkDriver alloc]
            initWithGenerationProvider:^int64_t {
                return weakSelf.canghuiSurfaceGeneration;
            }
            frameHandler:^{
                [weakSelf canghuiDrawFrame];
            }];
    }
    return self;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window != nil) {
        [self canghuiAttachIfReady];
        [self canghuiForwardTraits];
        [self.canghuiDisplayLink start];
    } else {
        [self.canghuiDisplayLink stop];
        [self canghuiDetach];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    CGFloat scale = self.window.screen.scale;
    if (scale <= 0.0) {
        scale = UIScreen.mainScreen.scale;
    }
    metalLayer.contentsScale = scale;
    metalLayer.drawableSize = CGSizeMake(
        MAX(1.0, self.bounds.size.width * scale),
        MAX(1.0, self.bounds.size.height * scale));
    if (!self.canghuiAttached) {
        [self canghuiAttachIfReady];
    } else {
        [self canghuiResize];
    }
}

- (int64_t)canghuiSurfaceGeneration {
    return self.canghuiAttached ? self.canghuiGeneration : 0;
}

- (void)canghuiAttachIfReady {
    if (self.canghuiAttached || self.window == nil || self.canghuiDevice == nil ||
        self.bounds.size.width <= 0.0 || self.bounds.size.height <= 0.0) {
        return;
    }
    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    self.canghuiGeneration += 1;
    CangHuiAttachArguments arguments = [self canghuiAttachArgumentsForLayer:metalLayer];
    CangHuiRuntimeTaskResult result = canghui_runtime_run_task(
        CangHuiAttachTask, &arguments, CangHuiSurfaceTaskTimeoutNanos);
    self.canghuiAttached = result.status == 0 &&
        (int64_t)(intptr_t)result.value == CANGHUI_IOS_BRIDGE_ACCEPTED;
}

- (void)canghuiResize {
    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    CangHuiAttachArguments current = [self canghuiAttachArgumentsForLayer:metalLayer];
    CangHuiResizeArguments arguments = {
        .logicalWidth = current.logicalWidth,
        .logicalHeight = current.logicalHeight,
        .pixelWidth = current.pixelWidth,
        .pixelHeight = current.pixelHeight,
        .scale = current.scale,
        .generation = current.generation,
    };
    (void)canghui_runtime_run_task(CangHuiResizeTask, &arguments, CangHuiSurfaceTaskTimeoutNanos);
}

- (void)canghuiReplayCurrentResize {
    if (self.canghuiAttached) {
        [self canghuiResize];
    }
}

- (void)canghuiDetach {
    if (!self.canghuiAttached) {
        return;
    }
    int64_t generation = self.canghuiGeneration;
    CangHuiRuntimeTaskResult result = canghui_runtime_run_task(
        CangHuiDetachTask, (void *)(intptr_t)generation, CangHuiSurfaceTaskTimeoutNanos);
    if (result.status == 0 &&
        (int64_t)(intptr_t)result.value == CANGHUI_IOS_BRIDGE_ACCEPTED) {
        self.canghuiAttached = NO;
    }
}

- (CangHuiAttachArguments)canghuiAttachArgumentsForLayer:(CAMetalLayer *)metalLayer {
    CGFloat scale = metalLayer.contentsScale > 0.0 ? metalLayer.contentsScale : 1.0;
    return (CangHuiAttachArguments){
        .handle = (int64_t)(intptr_t)(__bridge void *)metalLayer,
        .logicalWidth = llround(self.bounds.size.width * 1000.0),
        .logicalHeight = llround(self.bounds.size.height * 1000.0),
        .pixelWidth = llround(metalLayer.drawableSize.width),
        .pixelHeight = llround(metalLayer.drawableSize.height),
        .scale = llround(scale * 1000.0),
        .generation = self.canghuiGeneration,
    };
}

- (void)canghuiDrawFrame {
    if (!self.canghuiAttached || self.canghuiCommandQueue == nil) {
        return;
    }
    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
    if (drawable == nil) {
        return;
    }
    CangHuiRuntimeTaskResult colorResult = canghui_runtime_run_task(
        CangHuiClearColorTask, NULL, CangHuiSurfaceTaskTimeoutNanos);
    uint32_t argb = colorResult.status == 0 ? (uint32_t)(uintptr_t)colorResult.value : 0xFF3478F6u;
    MTLRenderPassDescriptor *pass = MTLRenderPassDescriptor.renderPassDescriptor;
    pass.colorAttachments[0].texture = drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(
        ((argb >> 16) & 0xFFu) / 255.0,
        ((argb >> 8) & 0xFFu) / 255.0,
        (argb & 0xFFu) / 255.0,
        ((argb >> 24) & 0xFFu) / 255.0);
    id<MTLCommandBuffer> commandBuffer = [self.canghuiCommandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
    [encoder endEncoding];
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

@end
