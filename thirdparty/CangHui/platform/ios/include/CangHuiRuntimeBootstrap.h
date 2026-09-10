#ifndef CANGHUI_RUNTIME_BOOTSTRAP_H
#define CANGHUI_RUNTIME_BOOTSTRAP_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *(*CangHuiRuntimeTaskFunction)(void *arguments);

typedef struct CangHuiRuntimeBootstrapResult {
    int32_t runtime_status;
    int32_t scheduler_thread_status;
    int32_t scheduler_ready;
    int32_t library_status;
} CangHuiRuntimeBootstrapResult;

typedef struct CangHuiRuntimeTaskResult {
    int32_t status;
    void *value;
} CangHuiRuntimeTaskResult;

/*
 * Starts the process-wide Cangjie runtime and fixed UI scheduler, then
 * initializes the static package registered under executable_name.
 *
 * Call this once from a background queue before invoking any @C entry point.
 * Later calls return the first process-wide result.
 */
CangHuiRuntimeBootstrapResult canghui_runtime_bootstrap_start(
    const char *executable_name,
    int64_t scheduler_ready_timeout_ns);

/* Runs an @C entry point through the Cangjie foreign-thread task gate. */
CangHuiRuntimeTaskResult canghui_runtime_run_task(
    CangHuiRuntimeTaskFunction task,
    void *arguments,
    int64_t timeout_ns);

#ifdef __cplusplus
}
#endif

#endif
