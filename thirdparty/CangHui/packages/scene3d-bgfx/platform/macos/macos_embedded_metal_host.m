#import <Cocoa/Cocoa.h>
#import <QuartzCore/CAMetalLayer.h>

// bgfx/bimg/bx are C++ archives; carry their runtime requirement with the
// provider-owned native host so a CJPM consumer does not duplicate -lc++.
__asm__(".linker_option \"-lc++\"");

@interface CangHuiEmbeddedSurfaceView : NSView
@end

@implementation CangHuiEmbeddedSurfaceView

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

@end

static NSRect chui_embedded_frame(NSView *parent, double x, double y, double width, double height) {
    return NSMakeRect(x, NSHeight(parent.bounds) - y - height, width, height);
}

void *chui_macos_embedded_metal_create(
    void *parent_window,
    double x,
    double y,
    double width,
    double height,
    double scale
) {
    NSWindow *window = (__bridge NSWindow *)parent_window;
    NSView *parent = window.contentView;
    if (parent == nil || width <= 0.0 || height <= 0.0 || scale <= 0.0) {
        return NULL;
    }
    NSView *view = [[CangHuiEmbeddedSurfaceView alloc]
        initWithFrame:chui_embedded_frame(parent, x, y, width, height)];
    view.wantsLayer = YES;
    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.contentsScale = scale;
    layer.drawableSize = CGSizeMake(width * scale, height * scale);
    view.layer = layer;
    [parent addSubview:view positioned:NSWindowAbove relativeTo:nil];
    return (__bridge_retained void *)view;
}

void *chui_macos_embedded_metal_layer(void *view_handle) {
    NSView *view = (__bridge NSView *)view_handle;
    return (__bridge void *)view.layer;
}

bool chui_macos_embedded_metal_place(
    void *view_handle,
    double x,
    double y,
    double width,
    double height,
    double scale
) {
    NSView *view = (__bridge NSView *)view_handle;
    NSView *parent = view.superview;
    if (view == nil || parent == nil || width <= 0.0 || height <= 0.0 || scale <= 0.0) {
        return false;
    }
    view.frame = chui_embedded_frame(parent, x, y, width, height);
    CAMetalLayer *layer = (CAMetalLayer *)view.layer;
    layer.contentsScale = scale;
    layer.drawableSize = CGSizeMake(width * scale, height * scale);
    return true;
}

void chui_macos_embedded_metal_destroy(void *view_handle) {
    if (view_handle == NULL) {
        return;
    }
    NSView *view = (__bridge_transfer NSView *)view_handle;
    [view removeFromSuperview];
}

bool chui_macos_embedded_metal_is_attached(void *view_handle) {
    NSView *view = (__bridge NSView *)view_handle;
    return view != nil && view.superview != nil && view.window != nil && [view.layer isKindOfClass:CAMetalLayer.class];
}
