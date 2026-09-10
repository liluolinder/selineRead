#ifndef CANGHUI_HARMONY_XCOMPONENT_HOST_H
#define CANGHUI_HARMONY_XCOMPONENT_HOST_H

#include <stdint.h>

#define CANGHUI_HARMONY_XCOMPONENT_HOST_ABI_VERSION 1

#ifdef __cplusplus
extern "C" {
#endif

int64_t canghui_harmony_xcomponent_host_abi_version(void);
int64_t canghui_harmony_surface_attach(
    int64_t native_window,
    int64_t pixel_width,
    int64_t pixel_height,
    int64_t scale_milli,
    int64_t generation);
int64_t canghui_harmony_surface_resize(
    int64_t pixel_width,
    int64_t pixel_height,
    int64_t scale_milli,
    int64_t generation);
int64_t canghui_harmony_surface_detach(int64_t generation);
int64_t canghui_harmony_surface_frame(
    int64_t timestamp_nanos,
    int64_t target_timestamp_nanos,
    int64_t generation);

#ifdef __cplusplus
}
#endif

#endif
