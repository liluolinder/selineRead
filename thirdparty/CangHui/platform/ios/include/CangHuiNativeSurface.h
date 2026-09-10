#ifndef CANGHUI_NATIVE_SURFACE_H
#define CANGHUI_NATIVE_SURFACE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
enum {
    CANGHUI_IOS_BRIDGE_ACCEPTED = 0,
    CANGHUI_IOS_BRIDGE_INVALID_ARGUMENT = -1,
    CANGHUI_IOS_BRIDGE_STALE_GENERATION = -2,
    CANGHUI_IOS_BRIDGE_REJECTED = -3
};

enum {
    CANGHUI_IOS_LIFECYCLE_LAUNCHING = 0,
    CANGHUI_IOS_LIFECYCLE_ACTIVE = 1,
    CANGHUI_IOS_LIFECYCLE_INACTIVE = 2,
    CANGHUI_IOS_LIFECYCLE_BACKGROUND = 3,
    CANGHUI_IOS_LIFECYCLE_SUSPENDED = 4,
    CANGHUI_IOS_LIFECYCLE_TERMINATING = 5
};

enum {
    CANGHUI_IOS_TOUCH_BEGAN = 0,
    CANGHUI_IOS_TOUCH_MOVED = 1,
    CANGHUI_IOS_TOUCH_ENDED = 2,
    CANGHUI_IOS_TOUCH_CANCELLED = 3
};

enum {
    CANGHUI_IOS_POINTER_BEGAN = 0,
    CANGHUI_IOS_POINTER_MOVED = 1,
    CANGHUI_IOS_POINTER_ENDED = 2
};

enum {
    CANGHUI_IOS_POINTER_KIND_INDIRECT = 0,
    CANGHUI_IOS_POINTER_KIND_PENCIL = 1
};

enum {
    CANGHUI_IOS_TRAIT_STYLE_UNSPECIFIED = 0,
    CANGHUI_IOS_TRAIT_STYLE_LIGHT = 1,
    CANGHUI_IOS_TRAIT_STYLE_DARK = 2
};

enum {
    CANGHUI_IOS_TRAIT_SIZE_UNSPECIFIED = 0,
    CANGHUI_IOS_TRAIT_SIZE_COMPACT = 1,
    CANGHUI_IOS_TRAIT_SIZE_REGULAR = 2
};

int64_t canghui_ios_surface_attach(
    int64_t handle,
    int64_t logical_width_milli,
    int64_t logical_height_milli,
    int64_t pixel_width,
    int64_t pixel_height,
    int64_t scale_milli,
    int64_t generation);
int64_t canghui_ios_surface_resize(
    int64_t logical_width_milli,
    int64_t logical_height_milli,
    int64_t pixel_width,
    int64_t pixel_height,
    int64_t scale_milli,
    int64_t generation);
int64_t canghui_ios_surface_detach(int64_t generation);
int64_t canghui_ios_surface_safe_area(
    int64_t top_milli,
    int64_t right_milli,
    int64_t bottom_milli,
    int64_t left_milli);
int64_t canghui_ios_surface_lifecycle(int64_t state);
int64_t canghui_ios_surface_touch(
    int64_t phase,
    int64_t id,
    int64_t x_milli,
    int64_t y_milli,
    int64_t timestamp_millis,
    int64_t generation);
int64_t canghui_ios_surface_pointer(
    int64_t phase,
    int64_t id,
    int64_t x_milli,
    int64_t y_milli,
    int64_t timestamp_millis,
    int64_t kind,
    int64_t generation);
int64_t canghui_ios_surface_traits(
    int64_t style,
    int64_t horizontal_size_class,
    int64_t vertical_size_class,
    int64_t scale_milli);
int64_t canghui_ios_surface_frame(
    int64_t timestamp_nanos,
    int64_t target_timestamp_nanos,
    int64_t generation);

int64_t canghui_ios_surface_generation(void);
int64_t canghui_ios_surface_is_attached(void);
int64_t canghui_ios_surface_handle(void);
int64_t canghui_ios_surface_attach_count(void);
int64_t canghui_ios_surface_resize_count(void);
int64_t canghui_ios_surface_detach_count(void);
int64_t canghui_ios_surface_frame_count(void);
int64_t canghui_ios_surface_touch_count(void);
int64_t canghui_ios_surface_last_touch_phase(void);
int64_t canghui_ios_surface_pointer_count(void);
int64_t canghui_ios_surface_last_pointer_phase(void);
int64_t canghui_ios_surface_last_pointer_kind(void);
int64_t canghui_ios_surface_trait_count(void);
int64_t canghui_ios_surface_last_trait_style(void);
int64_t canghui_ios_surface_last_trait_horizontal_size_class(void);
int64_t canghui_ios_surface_last_trait_vertical_size_class(void);
int64_t canghui_ios_surface_last_trait_scale_milli(void);
int64_t canghui_ios_surface_last_frame_nanos(void);
int64_t canghui_ios_surface_clear_color_argb(void);

#ifdef __cplusplus
}
#endif

#endif
