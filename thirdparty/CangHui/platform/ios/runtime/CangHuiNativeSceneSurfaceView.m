#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <UIKit/UIKit.h>

#include <math.h>
#include <stdint.h>

#import "CangHuiNativeSceneSurfaceView.h"
#import "CangHuiRuntimeBootstrap.h"

static const int64_t CangHuiNativeSceneTaskTimeoutNanos = 5000000000LL;

typedef struct CangHuiNativeSceneRenderArguments {
    CangHuiNativeSceneRenderFunction renderFunction;
    int64_t widthMilli;
    int64_t heightMilli;
    int64_t eventKind;
    int64_t xMilli;
    int64_t yMilli;
    uint8_t *output;
    int64_t outputCapacity;
    int64_t outputLength;
    int32_t status;
} CangHuiNativeSceneRenderArguments;

static void *CangHuiNativeSceneRenderTask(void *rawArguments) {
    CangHuiNativeSceneRenderArguments *arguments = rawArguments;
    arguments->status = arguments->renderFunction(
        arguments->widthMilli,
        arguments->heightMilli,
        arguments->eventKind,
        arguments->xMilli,
        arguments->yMilli,
        arguments->output,
        arguments->outputCapacity,
        &arguments->outputLength);
    return rawArguments;
}

static CGFloat CangHuiSceneNumber(NSDictionary *data, NSString *key, CGFloat fallback) {
    NSNumber *value = data[key];
    return [value isKindOfClass:NSNumber.class] ? value.doubleValue : fallback;
}

static CGFloat CangHuiSceneChannel(NSNumber *value) {
    if (![value isKindOfClass:NSNumber.class]) {
        return 0.0;
    }
    CGFloat channel = value.doubleValue;
    return channel > 1.0 ? channel / 255.0 : channel;
}

static UIColor *CangHuiSceneColor(NSDictionary *color) {
    if (![color isKindOfClass:NSDictionary.class]) {
        return UIColor.clearColor;
    }
    return [UIColor colorWithRed:CangHuiSceneChannel(color[@"r"])
        green:CangHuiSceneChannel(color[@"g"])
        blue:CangHuiSceneChannel(color[@"b"])
        alpha:CangHuiSceneChannel(color[@"a"])];
}

static void CangHuiSceneSetFillColor(CGContextRef context, NSDictionary *color) {
    CGContextSetFillColorWithColor(context, CangHuiSceneColor(color).CGColor);
}

static void CangHuiSceneSetStrokeColor(
    CGContextRef context,
    NSDictionary *color,
    CGFloat width
) {
    CGContextSetStrokeColorWithColor(context, CangHuiSceneColor(color).CGColor);
    CGContextSetLineWidth(context, MAX(0.5, width));
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
}

static CGRect CangHuiSceneRect(NSDictionary *data) {
    return CGRectMake(
        CangHuiSceneNumber(data, @"x", 0.0),
        CangHuiSceneNumber(data, @"y", 0.0),
        CangHuiSceneNumber(data, @"width", 0.0),
        CangHuiSceneNumber(data, @"height", 0.0));
}

static CGPathRef CangHuiSceneCreateRoundedRectPath(CGRect rect, CGFloat radius) {
    CGFloat bounded = MIN(MAX(0.0, radius), MIN(CGRectGetWidth(rect), CGRectGetHeight(rect)) / 2.0);
    return CGPathCreateWithRoundedRect(rect, bounded, bounded, NULL);
}

static void CangHuiSceneFillRoundedRect(CGContextRef context, CGRect rect, CGFloat radius) {
    CGPathRef path = CangHuiSceneCreateRoundedRectPath(rect, radius);
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    CGPathRelease(path);
}

static void CangHuiSceneStrokeRoundedRect(CGContextRef context, CGRect rect, CGFloat radius) {
    CGPathRef path = CangHuiSceneCreateRoundedRectPath(rect, radius);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGPathRelease(path);
}

static void CangHuiSceneDrawText(CGContextRef context, NSDictionary *data) {
    NSString *value = data[@"text"];
    if (![value isKindOfClass:NSString.class] || value.length == 0) {
        return;
    }
    CGFloat pointSize = CangHuiSceneNumber(data, @"pointSize", 14.0);
    UIFont *font = [data[@"bold"] boolValue]
        ? [UIFont boldSystemFontOfSize:pointSize]
        : [UIFont systemFontOfSize:pointSize];
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: CangHuiSceneColor(data[@"color"]),
    };
    CGContextSaveGState(context);
    UIGraphicsPushContext(context);
    [value drawAtPoint:CGPointMake(
        CangHuiSceneNumber(data, @"x", 0.0),
        CangHuiSceneNumber(data, @"y", 0.0))
        withAttributes:attributes];
    UIGraphicsPopContext();
    CGContextRestoreGState(context);
}

static void CangHuiSceneDrawSymbol(CGContextRef context, NSDictionary *data) {
    NSString *provider = data[@"provider"];
    NSString *name = data[@"name"];
    if (![provider isEqualToString:@"sf"] ||
        ![name isKindOfClass:NSString.class] || name.length == 0) {
        return;
    }
    UIImage *image = [[UIImage systemImageNamed:name]
        imageWithTintColor:CangHuiSceneColor(data[@"color"])
        renderingMode:UIImageRenderingModeAlwaysOriginal];
    if (image == nil) {
        return;
    }
    CGContextSaveGState(context);
    UIGraphicsPushContext(context);
    [image drawInRect:CangHuiSceneRect(data)];
    UIGraphicsPopContext();
    CGContextRestoreGState(context);
}

static void CangHuiSceneDrawCommand(
    CGContextRef context,
    NSDictionary *command,
    NSInteger *clipDepth
) {
    NSString *kind = command[@"kind"];
    NSDictionary *data = command[@"data"];
    if (![kind isKindOfClass:NSString.class] || ![data isKindOfClass:NSDictionary.class]) {
        return;
    }
    if ([kind isEqualToString:@"scene.begin"]) {
        CangHuiSceneSetFillColor(context, data[@"color"]);
        CGContextFillRect(context, CGRectMake(0.0, 0.0,
            CangHuiSceneNumber(data, @"width", 0.0),
            CangHuiSceneNumber(data, @"height", 0.0)));
    } else if ([kind isEqualToString:@"paint.clear"]) {
        CangHuiSceneSetFillColor(context, data[@"color"]);
        CGContextFillRect(context, CGContextGetClipBoundingBox(context));
    } else if ([kind isEqualToString:@"clip.push"]) {
        CGContextSaveGState(context);
        CGContextClipToRect(context, CangHuiSceneRect(data));
        *clipDepth += 1;
    } else if ([kind isEqualToString:@"clip.pop"]) {
        if (*clipDepth > 0) {
            CGContextRestoreGState(context);
            *clipDepth -= 1;
        }
    } else if ([kind isEqualToString:@"paint.fill"] ||
        [kind isEqualToString:@"paint.rect"]) {
        CangHuiSceneSetFillColor(context, data[@"color"]);
        CGRect rect = CangHuiSceneRect(data);
        if ([kind isEqualToString:@"paint.rect"]) {
            CangHuiSceneSetStrokeColor(context, data[@"color"], 1.0);
            CGContextStrokeRect(context, rect);
        } else {
            CGContextFillRect(context, rect);
        }
    } else if ([kind isEqualToString:@"paint.fill-rounded-rect"] ||
        [kind isEqualToString:@"paint.fill-rounded-soft"] ||
        [kind isEqualToString:@"paint.fill-rounded-gradient"] ||
        [kind isEqualToString:@"paint.fill-per-corner-rounded-rect"]) {
        NSDictionary *color = data[@"color"] ?: data[@"start"];
        CangHuiSceneSetFillColor(context, color);
        CangHuiSceneFillRoundedRect(context, CangHuiSceneRect(data),
            CangHuiSceneNumber(data, @"radius", 8.0));
    } else if ([kind isEqualToString:@"paint.stroke-rounded-rect"] ||
        [kind isEqualToString:@"paint.stroke-rounded-rect-dashed"]) {
        CangHuiSceneSetStrokeColor(context, data[@"color"],
            CangHuiSceneNumber(data, @"strokeWidth",
                CangHuiSceneNumber(data, @"width", 1.0)));
        CangHuiSceneStrokeRoundedRect(context, CangHuiSceneRect(data),
            CangHuiSceneNumber(data, @"radius", 8.0));
    } else if ([kind isEqualToString:@"paint.line"] ||
        [kind isEqualToString:@"paint.stroke-line"]) {
        CangHuiSceneSetStrokeColor(context, data[@"color"],
            CangHuiSceneNumber(data, @"width", 1.0));
        CGContextMoveToPoint(context,
            CangHuiSceneNumber(data, @"x1", 0.0), CangHuiSceneNumber(data, @"y1", 0.0));
        CGContextAddLineToPoint(context,
            CangHuiSceneNumber(data, @"x2", 0.0), CangHuiSceneNumber(data, @"y2", 0.0));
        CGContextStrokePath(context);
    } else if ([kind isEqualToString:@"paint.fill-circle"]) {
        CangHuiSceneSetFillColor(context, data[@"color"]);
        CGFloat radius = CangHuiSceneNumber(data, @"radius", 0.0);
        CGContextFillEllipseInRect(context, CGRectMake(
            CangHuiSceneNumber(data, @"cx", 0.0) - radius,
            CangHuiSceneNumber(data, @"cy", 0.0) - radius,
            radius * 2.0, radius * 2.0));
    } else if ([kind isEqualToString:@"paint.circle"] ||
        [kind isEqualToString:@"paint.stroke-circle"]) {
        CangHuiSceneSetStrokeColor(context, data[@"color"],
            CangHuiSceneNumber(data, @"width", 1.0));
        CGFloat radius = CangHuiSceneNumber(data, @"radius", 0.0);
        CGContextStrokeEllipseInRect(context, CGRectMake(
            CangHuiSceneNumber(data, @"cx", 0.0) - radius,
            CangHuiSceneNumber(data, @"cy", 0.0) - radius,
            radius * 2.0, radius * 2.0));
    } else if ([kind isEqualToString:@"paint.point"]) {
        CangHuiSceneSetFillColor(context, data[@"color"]);
        CGFloat x = CangHuiSceneNumber(data, @"x", 0.0);
        CGFloat y = CangHuiSceneNumber(data, @"y", 0.0);
        CGContextFillEllipseInRect(context, CGRectMake(x - 2.0, y - 2.0, 4.0, 4.0));
    } else if ([kind isEqualToString:@"paint.ripple"]) {
        CangHuiSceneSetFillColor(context, data[@"color"]);
        CGFloat radius = CangHuiSceneNumber(data, @"rippleRadius", 0.0);
        CGContextFillEllipseInRect(context, CGRectMake(
            CangHuiSceneNumber(data, @"cx", 0.0) - radius,
            CangHuiSceneNumber(data, @"cy", 0.0) - radius,
            radius * 2.0, radius * 2.0));
    } else if ([kind isEqualToString:@"text"]) {
        CangHuiSceneDrawText(context, data);
    } else if ([kind isEqualToString:@"symbol"]) {
        CangHuiSceneDrawSymbol(context, data);
    } else if ([kind isEqualToString:@"transform.scale"]) {
        CGContextScaleCTM(context,
            CangHuiSceneNumber(data, @"x", 1.0), CangHuiSceneNumber(data, @"y", 1.0));
    }
}

@interface CangHuiNativeSceneSurfaceView ()
@property(nonatomic, assign) CangHuiNativeSceneRenderFunction canghuiRenderFunction;
@property(nonatomic, assign) BOOL canghuiSceneDirty;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *canghuiPendingSceneEvents;
@property(nonatomic, strong, nullable) NSData *canghuiPendingSceneReport;
@property(nonatomic, readwrite) NSInteger canghuiPresentedSceneFrameCount;
@property(nonatomic, readwrite) int64_t canghuiLatestInputCount;
@property(nonatomic, copy, readwrite) NSString *canghuiLatestSelectedAction;
@property(nonatomic, copy, readwrite, nullable) NSData *canghuiLatestSceneReport;
@end

@implementation CangHuiNativeSceneSurfaceView

- (instancetype)initWithFrame:(CGRect)frame
    renderFunction:(CangHuiNativeSceneRenderFunction)renderFunction {
    NSParameterAssert(renderFunction != NULL);
    self = [super initWithFrame:frame];
    if (self != nil) {
        _canghuiRenderFunction = renderFunction;
        _canghuiSceneDirty = YES;
        _canghuiPendingSceneEvents = [NSMutableArray array];
        _canghuiLatestSelectedAction = @"";
        self.canghuiMetalLayer.framebufferOnly = NO;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self canghuiMarkNativeSceneDirty];
}

- (void)canghuiMarkNativeSceneDirty {
    self.canghuiSceneDirty = YES;
}

- (void)canghuiEnqueueNativeSceneEvent:(CangHuiNativeSceneEventKind)eventKind
    atPoint:(CGPoint)point {
    [self.canghuiPendingSceneEvents addObject:@{
        @"kind": @(eventKind),
        @"x": @(point.x),
        @"y": @(point.y),
    }];
    [self canghuiMarkNativeSceneDirty];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    UITouch *touch = touches.anyObject;
    if (touch != nil) {
        [self canghuiEnqueueNativeSceneEvent:CangHuiNativeSceneEventPress
            atPoint:[touch locationInView:self]];
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    UITouch *touch = touches.anyObject;
    if (touch != nil) {
        [self canghuiEnqueueNativeSceneEvent:CangHuiNativeSceneEventMove
            atPoint:[touch locationInView:self]];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    UITouch *touch = touches.anyObject;
    if (touch != nil) {
        [self canghuiEnqueueNativeSceneEvent:CangHuiNativeSceneEventRelease
            atPoint:[touch locationInView:self]];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    UITouch *touch = touches.anyObject;
    CGPoint point = touch == nil ? CGPointZero : [touch locationInView:self];
    [self canghuiEnqueueNativeSceneEvent:CangHuiNativeSceneEventCancel atPoint:point];
}

- (NSData *)canghuiReportForEventKind:(CangHuiNativeSceneEventKind)eventKind
    point:(CGPoint)point
    eventCommitted:(BOOL *)eventCommitted {
    if (eventCommitted != NULL) {
        *eventCommitted = NO;
    }
    if (self.canghuiRenderFunction == NULL ||
        self.bounds.size.width <= 0.0 || self.bounds.size.height <= 0.0) {
        return nil;
    }
    CangHuiNativeSceneRenderArguments arguments = {
        .renderFunction = self.canghuiRenderFunction,
        .widthMilli = llround(self.bounds.size.width * 1000.0),
        .heightMilli = llround(self.bounds.size.height * 1000.0),
        .eventKind = eventKind,
        .xMilli = llround(point.x * 1000.0),
        .yMilli = llround(point.y * 1000.0),
        .output = NULL,
        .outputCapacity = 0,
        .outputLength = 0,
        .status = -1,
    };
    CangHuiRuntimeTaskResult sizeResult = canghui_runtime_run_task(
        CangHuiNativeSceneRenderTask, &arguments, CangHuiNativeSceneTaskTimeoutNanos);
    if (sizeResult.status != 0 || arguments.status != -2 || arguments.outputLength <= 0) {
        return nil;
    }
    if (eventCommitted != NULL && eventKind != CangHuiNativeSceneEventNone) {
        *eventCommitted = YES;
    }
    NSMutableData *buffer = [NSMutableData dataWithLength:(NSUInteger)arguments.outputLength];
    arguments.output = buffer.mutableBytes;
    arguments.outputCapacity = arguments.outputLength;
    arguments.outputLength = 0;
    arguments.status = -1;
    // The sizing callback commits the input once; the copy callback snapshots the resulting scene.
    arguments.eventKind = CangHuiNativeSceneEventNone;
    CangHuiRuntimeTaskResult renderResult = canghui_runtime_run_task(
        CangHuiNativeSceneRenderTask, &arguments, CangHuiNativeSceneTaskTimeoutNanos);
    if (renderResult.status != 0 || arguments.status != 0 || arguments.outputLength <= 0 ||
        arguments.outputLength > (int64_t)buffer.length) {
        return nil;
    }
    return [NSData dataWithBytes:buffer.bytes length:(NSUInteger)arguments.outputLength];
}

- (void)canghuiReplayNativeSceneTapAtPoint:(CGPoint)point {
    NSData *report = [self canghuiReportForEventKind:CangHuiNativeSceneEventActivate
        point:point eventCommitted:NULL];
    if (report != nil) {
        self.canghuiPendingSceneReport = report;
    }
    [self canghuiMarkNativeSceneDirty];
}

- (BOOL)canghuiDecodeSceneReport:(NSData *)reportData
    intoContext:(CGContextRef)context
    commandCount:(NSUInteger *)commandCount {
    NSError *error = nil;
    NSDictionary *report = [NSJSONSerialization JSONObjectWithData:reportData options:0 error:&error];
    NSArray *frames = [report isKindOfClass:NSDictionary.class] ? report[@"frames"] : nil;
    NSDictionary *frame = [frames isKindOfClass:NSArray.class] ? frames.lastObject : nil;
    NSArray *commands = [frame isKindOfClass:NSDictionary.class] ? frame[@"drawIr"] : nil;
    if (error != nil || ![commands isKindOfClass:NSArray.class] || commands.count == 0) {
        return NO;
    }
    NSInteger clipDepth = 0;
    for (NSDictionary *command in commands) {
        if ([command isKindOfClass:NSDictionary.class]) {
            CangHuiSceneDrawCommand(context, command, &clipDepth);
        }
    }
    while (clipDepth > 0) {
        CGContextRestoreGState(context);
        clipDepth -= 1;
    }
    self.canghuiLatestInputCount = [frame[@"inputCount"] longLongValue];
    NSString *selectedAction = frame[@"selectedAction"];
    self.canghuiLatestSelectedAction = [selectedAction isKindOfClass:NSString.class]
        ? selectedAction : @"";
    self.canghuiLatestSceneReport = reportData;
    if (commandCount != NULL) {
        *commandCount = commands.count;
    }
    return YES;
}

- (void)canghuiDrawFrame {
    if (!self.canghuiSceneDirty || self.canghuiCommandQueue == nil || self.canghuiDevice == nil) {
        return;
    }
    self.canghuiSceneDirty = NO;
    NSData *reportData = self.canghuiPendingSceneReport;
    self.canghuiPendingSceneReport = nil;
    NSArray<NSDictionary *> *events = [self.canghuiPendingSceneEvents copy];
    [self.canghuiPendingSceneEvents removeAllObjects];
    NSUInteger eventIndex = 0;
    for (NSDictionary *event in events) {
        CGPoint point = CGPointMake([event[@"x"] doubleValue], [event[@"y"] doubleValue]);
        BOOL eventCommitted = NO;
        reportData = [self canghuiReportForEventKind:[event[@"kind"] longLongValue]
            point:point eventCommitted:&eventCommitted];
        if (reportData == nil) {
            NSUInteger pendingIndex = eventCommitted ? eventIndex + 1 : eventIndex;
            if (pendingIndex < events.count) {
                [self.canghuiPendingSceneEvents addObjectsFromArray:[events
                    subarrayWithRange:NSMakeRange(pendingIndex, events.count - pendingIndex)]];
            }
            self.canghuiSceneDirty = YES;
            return;
        }
        eventIndex += 1;
    }
    if (reportData == nil) {
        reportData = [self canghuiReportForEventKind:CangHuiNativeSceneEventNone
            point:CGPointZero eventCommitted:NULL];
    }
    if (reportData == nil) {
        self.canghuiSceneDirty = YES;
        return;
    }

    CAMetalLayer *metalLayer = self.canghuiMetalLayer;
    NSUInteger pixelWidth = (NSUInteger)MAX(1.0, metalLayer.drawableSize.width);
    NSUInteger pixelHeight = (NSUInteger)MAX(1.0, metalLayer.drawableSize.height);
    NSMutableData *pixels = [NSMutableData dataWithLength:pixelWidth * pixelHeight * 4];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(
        pixels.mutableBytes, pixelWidth, pixelHeight, 8, pixelWidth * 4,
        colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL) {
        self.canghuiSceneDirty = YES;
        return;
    }
    CGFloat scale = metalLayer.contentsScale > 0.0 ? metalLayer.contentsScale : 1.0;
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, 0.0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    NSUInteger commandCount = 0;
    BOOL rendered = [self canghuiDecodeSceneReport:reportData
        intoContext:context commandCount:&commandCount];
    CGContextRelease(context);
    if (!rendered) {
        self.canghuiSceneDirty = YES;
        return;
    }

    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
        width:pixelWidth height:pixelHeight mipmapped:NO];
    descriptor.storageMode = MTLStorageModeShared;
    descriptor.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> source = [self.canghuiDevice newTextureWithDescriptor:descriptor];
    if (source == nil) {
        self.canghuiSceneDirty = YES;
        return;
    }
    [source replaceRegion:MTLRegionMake2D(0, 0, pixelWidth, pixelHeight)
        mipmapLevel:0 withBytes:pixels.bytes bytesPerRow:pixelWidth * 4];
    id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
    if (drawable == nil) {
        self.canghuiSceneDirty = YES;
        return;
    }
    id<MTLCommandBuffer> commandBuffer = [self.canghuiCommandQueue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
    [blit copyFromTexture:source sourceSlice:0 sourceLevel:0
        sourceOrigin:MTLOriginMake(0, 0, 0)
        sourceSize:MTLSizeMake(pixelWidth, pixelHeight, 1)
        toTexture:drawable.texture destinationSlice:0 destinationLevel:0
        destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blit endEncoding];
    [commandBuffer presentDrawable:drawable];
    __weak CangHuiNativeSceneSurfaceView *weakSelf = self;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completedBuffer) {
        if (completedBuffer.status != MTLCommandBufferStatusCompleted || commandCount <= 8) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.canghuiPresentedSceneFrameCount += 1;
        });
    }];
    [commandBuffer commit];
}

- (BOOL)canghuiHasPresentedNativeScene {
    return self.canghuiPresentedSceneFrameCount > 0;
}

@end
