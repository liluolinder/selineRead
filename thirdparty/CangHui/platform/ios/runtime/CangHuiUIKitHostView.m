#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#import "CangHuiNativeSurface.h"
#import "CangHuiRuntimeBootstrap.h"
#import "CangHuiUIKitHostView.h"

#include <math.h>
#include <stdint.h>

static const int64_t CangHuiTaskTimeoutNanos = 5000000000LL;

typedef struct CangHuiSafeAreaArguments {
    int64_t top;
    int64_t right;
    int64_t bottom;
    int64_t left;
} CangHuiSafeAreaArguments;

typedef struct CangHuiTouchArguments {
    int64_t phase;
    int64_t identifier;
    int64_t x;
    int64_t y;
    int64_t timestamp;
    int64_t generation;
} CangHuiTouchArguments;

typedef struct CangHuiPointerArguments {
    int64_t phase;
    int64_t identifier;
    int64_t x;
    int64_t y;
    int64_t timestamp;
    int64_t kind;
    int64_t generation;
} CangHuiPointerArguments;

typedef struct CangHuiTraitArguments {
    int64_t style;
    int64_t horizontalSizeClass;
    int64_t verticalSizeClass;
    int64_t scale;
} CangHuiTraitArguments;

static void *CangHuiSafeAreaTask(void *rawArguments) {
    CangHuiSafeAreaArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_safe_area(
        arguments->top, arguments->right, arguments->bottom, arguments->left);
}

static void *CangHuiLifecycleTask(void *rawState) {
    return (void *)(intptr_t)canghui_ios_surface_lifecycle((int64_t)(intptr_t)rawState);
}

static void *CangHuiTouchTask(void *rawArguments) {
    CangHuiTouchArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_touch(
        arguments->phase,
        arguments->identifier,
        arguments->x,
        arguments->y,
        arguments->timestamp,
        arguments->generation);
}

static void *CangHuiPointerTask(void *rawArguments) {
    CangHuiPointerArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_pointer(
        arguments->phase,
        arguments->identifier,
        arguments->x,
        arguments->y,
        arguments->timestamp,
        arguments->kind,
        arguments->generation);
}

static void *CangHuiTraitTask(void *rawArguments) {
    CangHuiTraitArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_traits(
        arguments->style,
        arguments->horizontalSizeClass,
        arguments->verticalSizeClass,
        arguments->scale);
}

@implementation CangHuiUIKitHostView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        [self canghuiConfigureInputAndLifecycle];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self != nil) {
        [self canghuiConfigureInputAndLifecycle];
    }
    return self;
}

- (void)canghuiConfigureInputAndLifecycle {
    self.multipleTouchEnabled = YES;
    self.userInteractionEnabled = YES;
    if (@available(iOS 13.0, *)) {
        UIHoverGestureRecognizer *hover = [[UIHoverGestureRecognizer alloc]
            initWithTarget:self action:@selector(canghuiHandleHover:)];
        [self addGestureRecognizer:hover];
    }
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(canghuiApplicationDidBecomeActive:)
        name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(canghuiApplicationWillResignActive:)
        name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(canghuiApplicationDidEnterBackground:)
        name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(canghuiApplicationWillTerminate:)
        name:UIApplicationWillTerminateNotification object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (int64_t)canghuiSurfaceGeneration {
    return 0;
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    UIEdgeInsets insets = self.safeAreaInsets;
    CangHuiSafeAreaArguments arguments = {
        .top = llround(insets.top * 1000.0),
        .right = llround(insets.right * 1000.0),
        .bottom = llround(insets.bottom * 1000.0),
        .left = llround(insets.left * 1000.0),
    };
    (void)canghui_runtime_run_task(CangHuiSafeAreaTask, &arguments, CangHuiTaskTimeoutNanos);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self canghuiForwardTraits];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self canghuiForwardTouches:touches phase:CANGHUI_IOS_TOUCH_BEGAN];
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self canghuiForwardTouches:touches phase:CANGHUI_IOS_TOUCH_MOVED];
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self canghuiForwardTouches:touches phase:CANGHUI_IOS_TOUCH_ENDED];
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self canghuiForwardTouches:touches phase:CANGHUI_IOS_TOUCH_CANCELLED];
    [super touchesCancelled:touches withEvent:event];
}

- (void)canghuiForwardTouches:(NSSet<UITouch *> *)touches phase:(int64_t)phase {
    int64_t generation = self.canghuiSurfaceGeneration;
    if (generation <= 0) {
        return;
    }
    for (UITouch *touch in touches) {
        CGPoint point = [touch locationInView:self];
        CangHuiTouchArguments arguments = {
            .phase = phase,
            .identifier = (int64_t)(intptr_t)(__bridge void *)touch,
            .x = llround(point.x * 1000.0),
            .y = llround(point.y * 1000.0),
            .timestamp = llround(touch.timestamp * 1000.0),
            .generation = generation,
        };
        (void)canghui_runtime_run_task(CangHuiTouchTask, &arguments, CangHuiTaskTimeoutNanos);
        if (touch.type == UITouchTypePencil) {
            [self canghuiForwardPointerForTouch:touch phase:phase];
        }
    }
}

- (void)canghuiForwardPointerForTouch:(UITouch *)touch phase:(int64_t)touchPhase {
    int64_t generation = self.canghuiSurfaceGeneration;
    if (generation <= 0) {
        return;
    }
    int64_t pointerPhase = touchPhase == CANGHUI_IOS_TOUCH_BEGAN
        ? CANGHUI_IOS_POINTER_BEGAN
        : touchPhase == CANGHUI_IOS_TOUCH_ENDED || touchPhase == CANGHUI_IOS_TOUCH_CANCELLED
            ? CANGHUI_IOS_POINTER_ENDED
            : CANGHUI_IOS_POINTER_MOVED;
    CGPoint point = [touch locationInView:self];
    CangHuiPointerArguments arguments = {
        .phase = pointerPhase,
        .identifier = (int64_t)(intptr_t)(__bridge void *)touch,
        .x = llround(point.x * 1000.0),
        .y = llround(point.y * 1000.0),
        .timestamp = llround(touch.timestamp * 1000.0),
        .kind = CANGHUI_IOS_POINTER_KIND_PENCIL,
        .generation = generation,
    };
    (void)canghui_runtime_run_task(CangHuiPointerTask, &arguments, CangHuiTaskTimeoutNanos);
}

- (void)canghuiHandleHover:(UIHoverGestureRecognizer *)recognizer {
    int64_t generation = self.canghuiSurfaceGeneration;
    if (generation <= 0) {
        return;
    }
    int64_t pointerPhase = recognizer.state == UIGestureRecognizerStateBegan
        ? CANGHUI_IOS_POINTER_BEGAN
        : recognizer.state == UIGestureRecognizerStateEnded ||
            recognizer.state == UIGestureRecognizerStateCancelled
            ? CANGHUI_IOS_POINTER_ENDED
            : CANGHUI_IOS_POINTER_MOVED;
    int64_t pointerKind = CANGHUI_IOS_POINTER_KIND_INDIRECT;
    if (@available(iOS 16.1, *)) {
        if (recognizer.zOffset > 0.0) {
            pointerKind = CANGHUI_IOS_POINTER_KIND_PENCIL;
        }
    }
    if (@available(iOS 16.4, *)) {
        if (recognizer.altitudeAngle > 0.0) {
            pointerKind = CANGHUI_IOS_POINTER_KIND_PENCIL;
        }
    }
    CGPoint point = [recognizer locationInView:self];
    CangHuiPointerArguments arguments = {
        .phase = pointerPhase,
        .identifier = (int64_t)(intptr_t)(__bridge void *)recognizer,
        .x = llround(point.x * 1000.0),
        .y = llround(point.y * 1000.0),
        .timestamp = llround(CACurrentMediaTime() * 1000.0),
        .kind = pointerKind,
        .generation = generation,
    };
    (void)canghui_runtime_run_task(CangHuiPointerTask, &arguments, CangHuiTaskTimeoutNanos);
}

- (void)canghuiForwardTraits {
    UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified;
    if (@available(iOS 12.0, *)) {
        style = self.traitCollection.userInterfaceStyle;
    }
    NSInteger horizontal = self.traitCollection.horizontalSizeClass;
    NSInteger vertical = self.traitCollection.verticalSizeClass;
    CGFloat scale = self.window.screen.scale;
    if (scale <= 0.0) {
        scale = UIScreen.mainScreen.scale;
    }
    CangHuiTraitArguments arguments = {
        .style = style == UIUserInterfaceStyleLight
            ? CANGHUI_IOS_TRAIT_STYLE_LIGHT
            : style == UIUserInterfaceStyleDark
                ? CANGHUI_IOS_TRAIT_STYLE_DARK
                : CANGHUI_IOS_TRAIT_STYLE_UNSPECIFIED,
        .horizontalSizeClass = horizontal == UIUserInterfaceSizeClassCompact
            ? CANGHUI_IOS_TRAIT_SIZE_COMPACT
            : horizontal == UIUserInterfaceSizeClassRegular
                ? CANGHUI_IOS_TRAIT_SIZE_REGULAR
                : CANGHUI_IOS_TRAIT_SIZE_UNSPECIFIED,
        .verticalSizeClass = vertical == UIUserInterfaceSizeClassCompact
            ? CANGHUI_IOS_TRAIT_SIZE_COMPACT
            : vertical == UIUserInterfaceSizeClassRegular
                ? CANGHUI_IOS_TRAIT_SIZE_REGULAR
                : CANGHUI_IOS_TRAIT_SIZE_UNSPECIFIED,
        .scale = llround(scale * 1000.0),
    };
    (void)canghui_runtime_run_task(CangHuiTraitTask, &arguments, CangHuiTaskTimeoutNanos);
}

- (void)canghuiApplicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    [self canghuiSendLifecycle:CANGHUI_IOS_LIFECYCLE_ACTIVE];
}

- (void)canghuiApplicationWillResignActive:(NSNotification *)notification {
    (void)notification;
    [self canghuiSendLifecycle:CANGHUI_IOS_LIFECYCLE_INACTIVE];
}

- (void)canghuiApplicationDidEnterBackground:(NSNotification *)notification {
    (void)notification;
    [self canghuiSendLifecycle:CANGHUI_IOS_LIFECYCLE_BACKGROUND];
}

- (void)canghuiApplicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self canghuiSendLifecycle:CANGHUI_IOS_LIFECYCLE_TERMINATING];
}

- (void)canghuiSendLifecycle:(int64_t)state {
    (void)canghui_runtime_run_task(
        CangHuiLifecycleTask, (void *)(intptr_t)state, CangHuiTaskTimeoutNanos);
}

@end
