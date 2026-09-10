#import <QuartzCore/CADisplayLink.h>
#import <UIKit/UIKit.h>

#import "CangHuiNativeSurface.h"
#import "CangHuiRuntimeBootstrap.h"

#include <math.h>
#include <stdint.h>

static const int64_t CangHuiFrameTaskTimeoutNanos = 5000000000LL;

typedef struct CangHuiFrameArguments {
    int64_t timestamp;
    int64_t targetTimestamp;
    int64_t generation;
} CangHuiFrameArguments;

static void *CangHuiFrameTask(void *rawArguments) {
    CangHuiFrameArguments *arguments = rawArguments;
    return (void *)(intptr_t)canghui_ios_surface_frame(
        arguments->timestamp, arguments->targetTimestamp, arguments->generation);
}

@interface CangHuiDisplayLinkDriver : NSObject
@property(nonatomic, copy) int64_t (^generationProvider)(void);
@property(nonatomic, copy) void (^frameHandler)(void);
@property(nonatomic, strong) CADisplayLink *displayLink;
- (instancetype)initWithGenerationProvider:(int64_t (^)(void))generationProvider
    frameHandler:(void (^)(void))frameHandler;
- (void)start;
- (void)stop;
@end

@implementation CangHuiDisplayLinkDriver

- (instancetype)initWithGenerationProvider:(int64_t (^)(void))generationProvider
    frameHandler:(void (^)(void))frameHandler {
    self = [super init];
    if (self != nil) {
        _generationProvider = [generationProvider copy];
        _frameHandler = [frameHandler copy];
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (void)start {
    if (self.displayLink != nil) {
        return;
    }
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(canghuiTick:)];
    link.preferredFramesPerSecond = 0;
    [link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    self.displayLink = link;
}

- (void)stop {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)canghuiTick:(CADisplayLink *)link {
    int64_t generation = self.generationProvider != nil ? self.generationProvider() : 0;
    if (generation <= 0) {
        return;
    }
    CangHuiFrameArguments arguments = {
        .timestamp = llround(link.timestamp * 1000000000.0),
        .targetTimestamp = llround(link.targetTimestamp * 1000000000.0),
        .generation = generation,
    };
    CangHuiRuntimeTaskResult result = canghui_runtime_run_task(
        CangHuiFrameTask, &arguments, CangHuiFrameTaskTimeoutNanos);
    if (result.status == 0 &&
        (int64_t)(intptr_t)result.value == CANGHUI_IOS_BRIDGE_ACCEPTED &&
        self.frameHandler != nil) {
        self.frameHandler();
    }
}

@end
