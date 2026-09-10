#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

#import "CangHuiHost.h"
#import "CangHuiNativeSurface.h"
#import "CangHuiRuntimeBootstrap.h"

static const int64_t CangHuiProbeTimeoutNanos = 5000000000LL;

typedef struct CangHuiSurfaceSnapshot {
    int64_t generation;
    int64_t attached;
    int64_t attaches;
    int64_t resizes;
    int64_t detaches;
    int64_t frames;
    int64_t touches;
    int64_t pointers;
    int64_t traits;
} CangHuiSurfaceSnapshot;

static void *read_canghui_abi(void *unused) {
    (void)unused;
    return (void *)(intptr_t)canghui_ios_host_abi_version();
}

static void *read_canghui_surface(void *rawSnapshot) {
    CangHuiSurfaceSnapshot *snapshot = rawSnapshot;
    snapshot->generation = canghui_ios_surface_generation();
    snapshot->attached = canghui_ios_surface_is_attached();
    snapshot->attaches = canghui_ios_surface_attach_count();
    snapshot->resizes = canghui_ios_surface_resize_count();
    snapshot->detaches = canghui_ios_surface_detach_count();
    snapshot->frames = canghui_ios_surface_frame_count();
    snapshot->touches = canghui_ios_surface_touch_count();
    snapshot->pointers = canghui_ios_surface_pointer_count();
    snapshot->traits = canghui_ios_surface_trait_count();
    return rawSnapshot;
}

static void *write_canghui_probe_touch(void *rawGeneration) {
    int64_t generation = (int64_t)(intptr_t)rawGeneration;
    return (void *)(intptr_t)canghui_ios_surface_touch(
        CANGHUI_IOS_TOUCH_BEGAN, 1, 120000, 180000, 1000, generation);
}

static void *write_canghui_probe_pointer(void *rawGeneration) {
    int64_t generation = (int64_t)(intptr_t)rawGeneration;
    return (void *)(intptr_t)canghui_ios_surface_pointer(
        CANGHUI_IOS_POINTER_BEGAN, 2, 220000, 320000, 1200,
        CANGHUI_IOS_POINTER_KIND_PENCIL, generation);
}

static void *write_canghui_probe_traits(void *unused) {
    (void)unused;
    return (void *)(intptr_t)canghui_ios_surface_traits(
        CANGHUI_IOS_TRAIT_STYLE_DARK,
        CANGHUI_IOS_TRAIT_SIZE_REGULAR,
        CANGHUI_IOS_TRAIT_SIZE_REGULAR,
        2000);
}

@interface CangHuiMetalSurfaceView : UIView
- (int64_t)canghuiSurfaceGeneration;
- (void)canghuiReplayCurrentResize;
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UIViewController *rootController;
@property(nonatomic, strong) UIView *statusPanel;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) CangHuiMetalSurfaceView *surfaceView;
@property(nonatomic, assign) BOOL drawableObserved;
@end

@implementation AppDelegate

- (void)runBootstrapProbe {
    const char *executableName =
        NSBundle.mainBundle.executableURL.lastPathComponent.UTF8String;
    CangHuiRuntimeBootstrapResult bootstrap =
        canghui_runtime_bootstrap_start(executableName, CangHuiProbeTimeoutNanos);
    CangHuiRuntimeTaskResult task =
        canghui_runtime_run_task(read_canghui_abi, NULL, CangHuiProbeTimeoutNanos);
    int64_t abi = task.status == 0 ? (int64_t)(intptr_t)task.value : -1;
    BOOL passed = bootstrap.runtime_status == 0 &&
        bootstrap.scheduler_ready == 1 && bootstrap.library_status == 0 &&
        task.status == 0 && abi == 1;

    fprintf(stderr,
        "CANGHUI_IOS_PROBE result runtime=%d scheduler=%s library=%d task=%d abi=%" PRId64 "\n",
        bootstrap.runtime_status,
        bootstrap.scheduler_ready == 1 ? "ready" : "null",
        bootstrap.library_status,
        task.status,
        abi);
    fflush(stderr);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!passed) {
            self.statusLabel.textColor = UIColor.systemRedColor;
            self.statusLabel.text = @"CangHui iOS native surface\n"
                "Runtime bootstrap failed\n"
                "Probe only - CangHui scene not mounted";
            return;
        }
        [self installSurfaceView];
        [self scheduleDetachReattachReplay];
    });
}

- (void)installSurfaceView {
    if (self.surfaceView == nil) {
        self.surfaceView = [[CangHuiMetalSurfaceView alloc] initWithFrame:CGRectZero];
        self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    [self.rootController.view insertSubview:self.surfaceView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.rootController.view.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.rootController.view.trailingAnchor],
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.rootController.view.topAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.rootController.view.bottomAnchor]
    ]];
    [self.rootController.view layoutIfNeeded];
}

- (void)scheduleDetachReattachReplay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500000000), dispatch_get_main_queue(), ^{
        int64_t generation = self.surfaceView.canghuiSurfaceGeneration;
        (void)canghui_runtime_run_task(
            write_canghui_probe_touch,
            (void *)(intptr_t)generation,
            CangHuiProbeTimeoutNanos);
        [self.surfaceView removeFromSuperview];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150000000), dispatch_get_main_queue(), ^{
            [self installSurfaceView];
            [self.surfaceView canghuiReplayCurrentResize];
            (void)canghui_runtime_run_task(
                write_canghui_probe_traits, NULL, CangHuiProbeTimeoutNanos);
            (void)canghui_runtime_run_task(
                write_canghui_probe_pointer,
                (void *)(intptr_t)self.surfaceView.canghuiSurfaceGeneration,
                CangHuiProbeTimeoutNanos);
            [self reportSurfaceWhenReadyWithAttempts:100];
        });
    });
}

- (void)reportSurfaceWhenReadyWithAttempts:(NSInteger)attempts {
    CangHuiSurfaceSnapshot snapshot = {0};
    CangHuiRuntimeTaskResult readback = canghui_runtime_run_task(
        read_canghui_surface, &snapshot, CangHuiProbeTimeoutNanos);
    CAMetalLayer *layer = [self.surfaceView.layer isKindOfClass:CAMetalLayer.class]
        ? (CAMetalLayer *)self.surfaceView.layer
        : nil;
    BOOL metalReady = layer != nil && layer.device != nil;
    if (!self.drawableObserved && metalReady) {
        self.drawableObserved = [layer nextDrawable] != nil;
    }
    BOOL passed = readback.status == 0 && metalReady && self.drawableObserved &&
        snapshot.attached == 1 && snapshot.attaches >= 2 && snapshot.detaches >= 1 &&
        snapshot.generation >= 2 && snapshot.resizes >= 1 && snapshot.frames >= 1 &&
        snapshot.touches >= 1 && snapshot.pointers >= 1 && snapshot.traits >= 1;
    if (!passed && attempts > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100000000), dispatch_get_main_queue(), ^{
            [self reportSurfaceWhenReadyWithAttempts:attempts - 1];
        });
        return;
    }

    fprintf(stderr,
        "CANGHUI_IOS_SURFACE result passed=%d metal=%s drawable=%s attached=%" PRId64
        " attaches=%" PRId64 " resizes=%" PRId64 " detaches=%" PRId64
        " generation=%" PRId64 " frames=%" PRId64 " touches=%" PRId64
        " pointers=%" PRId64 " traits=%" PRId64 "\n",
        passed ? 1 : 0,
        metalReady ? "ready" : "null",
        self.drawableObserved ? "ready" : "null",
        snapshot.attached,
        snapshot.attaches,
        snapshot.resizes,
        snapshot.detaches,
        snapshot.generation,
        snapshot.frames,
        snapshot.touches,
        snapshot.pointers,
        snapshot.traits);
    fflush(stderr);

    self.statusLabel.textColor = passed ? UIColor.whiteColor : UIColor.systemRedColor;
    self.statusLabel.text = passed
        ? [NSString stringWithFormat:
            @"CangHui iOS native surface\n"
             "PASS - Metal + lifecycle + frames (%lld)\n"
             "Probe only - CangHui scene not mounted",
            (long long)snapshot.frames]
        : @"CangHui iOS native surface\n"
           "Probe failed\n"
           "CangHui scene not mounted";
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;

    self.rootController = [UIViewController new];
    self.rootController.view.backgroundColor = UIColor.systemBackgroundColor;

    UIView *panel = [UIView new];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.90];
    panel.layer.cornerRadius = 12.0;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    self.statusPanel = panel;
    [self.rootController.view addSubview:panel];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightSemibold];
    label.textColor = UIColor.whiteColor;
    label.text = @"CangHui iOS native surface\n"
        "Starting runtime...\n"
        "Probe only - CangHui scene not mounted";
    label.accessibilityLabel = @"CangHui iOS native surface diagnostic probe";
    self.statusLabel = label;
    [panel addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [panel.centerXAnchor constraintEqualToAnchor:self.rootController.view.centerXAnchor],
        [panel.centerYAnchor constraintEqualToAnchor:self.rootController.view.centerYAnchor],
        [panel.leadingAnchor constraintGreaterThanOrEqualToAnchor:
            self.rootController.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [panel.trailingAnchor constraintLessThanOrEqualToAnchor:
            self.rootController.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [label.topAnchor constraintEqualToAnchor:panel.topAnchor constant:18],
        [label.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18],
        [label.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22],
        [label.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22]
    ]];

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = self.rootController;
    [self.window makeKeyAndVisible];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self runBootstrapProbe];
    });
    return YES;
}

@end

int main(int argc, char **argv) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class));
    }
}
