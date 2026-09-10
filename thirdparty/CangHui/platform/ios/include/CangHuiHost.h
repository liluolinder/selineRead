#ifndef CANGHUI_HOST_H
#define CANGHUI_HOST_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int64_t canghui_ios_host_abi_version(void);

/* Compatibility symbol for hosts built before the CangHui identity cutover. */
int64_t cangjiegui_ios_host_abi_version(void);

#ifdef __cplusplus
}
#endif

#endif
