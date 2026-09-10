#ifndef CANGHUI_METAL_SURFACE_VIEW_H
#define CANGHUI_METAL_SURFACE_VIEW_H

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#import "CangHuiUIKitHostView.h"

NS_ASSUME_NONNULL_BEGIN

/** Reusable CAMetalLayer host that owns the CangHui surface lifecycle. */
@interface CangHuiMetalSurfaceView : CangHuiUIKitHostView
@property(nonatomic, strong, readonly) id<MTLDevice> canghuiDevice;
@property(nonatomic, strong, readonly) id<MTLCommandQueue> canghuiCommandQueue;
@property(nonatomic, readonly) CAMetalLayer *canghuiMetalLayer;

/** Subclasses override this frame hook while retaining the shared lifecycle. */
- (void)canghuiDrawFrame;
@end

NS_ASSUME_NONNULL_END

#endif
