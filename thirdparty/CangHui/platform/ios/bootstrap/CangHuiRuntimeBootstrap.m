#import "CangHuiRuntimeBootstrap.h"

#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stddef.h>
#include <unistd.h>

extern int InitCJRuntime(void *params);
extern void *InitUIScheduler(void);
extern int RunUIScheduler(unsigned long long timeout);
extern int InitCJLibrary(const char *name);
extern void *RunCJTask(CangHuiRuntimeTaskFunction task, void *arguments);
extern int GetTaskRetWithTimeout(void *handle, void **result, int64_t timeout);
extern void ReleaseHandle(void *handle);

typedef union CangHuiRuntimeParamsStorage {
    max_align_t alignment;
    unsigned char bytes[4096];
} CangHuiRuntimeParamsStorage;

static dispatch_once_t bootstrap_once;
static dispatch_semaphore_t scheduler_ready_signal;
static void *scheduler_handle;
static CangHuiRuntimeBootstrapResult bootstrap_result = {-1, -1, 0, -1};

static void *canghui_scheduler_main(void *unused) {
    (void)unused;

    for (int attempt = 0; attempt < 5000 && scheduler_handle == NULL; attempt++) {
        scheduler_handle = InitUIScheduler();
        if (scheduler_handle == NULL) {
            usleep(1000);
        }
    }
    dispatch_semaphore_signal(scheduler_ready_signal);

    if (scheduler_handle != NULL) {
        for (;;) {
            (void)RunUIScheduler(1000000);
            usleep(1000);
        }
    }
    return NULL;
}

CangHuiRuntimeBootstrapResult canghui_runtime_bootstrap_start(
    const char *executable_name,
    int64_t scheduler_ready_timeout_ns) {
    dispatch_once(&bootstrap_once, ^{
        if (executable_name == NULL || executable_name[0] == '\0') {
            bootstrap_result.runtime_status = -2;
            return;
        }

        scheduler_ready_signal = dispatch_semaphore_create(0);
        pthread_t scheduler_thread;
        bootstrap_result.scheduler_thread_status = pthread_create(
            &scheduler_thread, NULL, canghui_scheduler_main, NULL);
        if (bootstrap_result.scheduler_thread_status == 0) {
            pthread_detach(scheduler_thread);
        }

        static CangHuiRuntimeParamsStorage runtime_params;
        bootstrap_result.runtime_status = InitCJRuntime(&runtime_params);

        if (bootstrap_result.scheduler_thread_status == 0) {
            int64_t timeout = scheduler_ready_timeout_ns > 0
                ? scheduler_ready_timeout_ns
                : 5000000000LL;
            long wait_status = dispatch_semaphore_wait(
                scheduler_ready_signal,
                dispatch_time(DISPATCH_TIME_NOW, timeout));
            bootstrap_result.scheduler_ready =
                wait_status == 0 && scheduler_handle != NULL ? 1 : 0;
        }

        if (bootstrap_result.runtime_status == 0 &&
            bootstrap_result.scheduler_thread_status == 0 &&
            bootstrap_result.scheduler_ready == 1) {
            bootstrap_result.library_status = InitCJLibrary(executable_name);
        }
    });

    return bootstrap_result;
}

CangHuiRuntimeTaskResult canghui_runtime_run_task(
    CangHuiRuntimeTaskFunction task,
    void *arguments,
    int64_t timeout_ns) {
    CangHuiRuntimeTaskResult result = {-1, NULL};
    if (task == NULL || bootstrap_result.library_status != 0) {
        return result;
    }

    void *handle = RunCJTask(task, arguments);
    if (handle == NULL) {
        result.status = -2;
        return result;
    }

    int64_t timeout = timeout_ns > 0 ? timeout_ns : 5000000000LL;
    result.status = GetTaskRetWithTimeout(handle, &result.value, timeout);
    ReleaseHandle(handle);
    return result;
}
