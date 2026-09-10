/*
 * cui_native_shim — UI 主循环原生线程钉扎
 *
 * 背景：Cangjie 绿色线程调度器会在主绿线程 park（如 sleep/锁等待）后把它
 * 迁移到其他 OS 线程。Win32 窗口消息队列绑定在创建窗口的原 OS 线程上，
 * 迁移后 SDL_PollEvent 在新线程上永远收不到消息 → 窗口 5 秒无人泵消息，
 * Windows 判定「未响应」，输入全部丢失（v13~v15 write-ring 实锤链的根因）。
 *
 * 方案：用 CreateThread 创建 1:1 原生 OS 线程执行 Cangjie 侧的 UI 主函数
 * （窗口创建 + 事件泵 + 渲染主循环）。绿色线程调度器不管理原生线程，
 * 主循环从此钉死在一个 OS 线程上，消息队列归属永不变。
 *
 * 调用约定：cui_start_native(cb) 阻塞到 cb 返回（窗口关闭）才回 main。
 */
#include <windows.h>

typedef void (*cui_native_cb_t)(void);

static DWORD WINAPI cui_thread_body(LPVOID param) {
    cui_native_cb_t cb = (cui_native_cb_t)param;
    cb();
    return 0;
}

void cui_start_native(cui_native_cb_t cb) {
    HANDLE thread = CreateThread(NULL, 0, cui_thread_body, (LPVOID)cb, 0, NULL);
    if (thread != NULL) {
        WaitForSingleObject(thread, INFINITE);
        CloseHandle(thread);
    }
}
