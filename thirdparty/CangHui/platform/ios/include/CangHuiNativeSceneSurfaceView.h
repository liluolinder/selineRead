#ifndef CANGHUI_NATIVE_SCENE_SURFACE_VIEW_H
#define CANGHUI_NATIVE_SCENE_SURFACE_VIEW_H

#include <stdint.h>

#import "CangHuiMetalSurfaceView.h"

typedef int32_t (*CangHuiNativeSceneRenderFunction)(
    int64_t width_milli,
    int64_t height_milli,
    int64_t event_kind,
    int64_t x_milli,
    int64_t y_milli,
    uint8_t * _Nullable output,
    int64_t output_capacity,
    int64_t * _Nonnull output_length);

typedef NS_ENUM(int64_t, CangHuiNativeSceneEventKind) {
    CangHuiNativeSceneEventNone = 0,
    CangHuiNativeSceneEventPress = 1,
    CangHuiNativeSceneEventMove = 2,
    CangHuiNativeSceneEventRelease = 3,
    CangHuiNativeSceneEventCancel = 4,
    CangHuiNativeSceneEventActivate = 5,
};

NS_ASSUME_NONNULL_BEGIN

/** Generic UIKit/Metal presenter for `canghui.native-scene.v0` Draw IR. */
@interface CangHuiNativeSceneSurfaceView : CangHuiMetalSurfaceView
@property(nonatomic, readonly) NSInteger canghuiPresentedSceneFrameCount;
@property(nonatomic, readonly) int64_t canghuiLatestInputCount;
@property(nonatomic, copy, readonly) NSString *canghuiLatestSelectedAction;
@property(nonatomic, copy, readonly, nullable) NSData *canghuiLatestSceneReport;

- (instancetype)initWithFrame:(CGRect)frame
    renderFunction:(CangHuiNativeSceneRenderFunction)renderFunction;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)canghuiMarkNativeSceneDirty;
- (void)canghuiEnqueueNativeSceneEvent:(CangHuiNativeSceneEventKind)eventKind
    atPoint:(CGPoint)point;
- (void)canghuiReplayNativeSceneTapAtPoint:(CGPoint)point;
- (BOOL)canghuiHasPresentedNativeScene;
@end

NS_ASSUME_NONNULL_END

#endif
