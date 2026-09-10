package SelineRead

/*
 * 入口：不再在 main 线程创建窗口/跑主循环。
 *
 * 根因链（v13~v15 write-ring/看门狗实锤）：Cangjie 绿色线程调度器会在主绿
 * 线程 park 后把它迁移到其他 OS 线程；Win32 窗口消息队列绑定在创建窗口的
 * 原 OS 线程上，迁移后 SDL_PollEvent 在新线程永远收不到消息 → Windows 判
 * 「未响应」。main 线程恰恰是 Cangjie 主绿线程的宿主，最容易被迁移。
 *
 * 方案：窗口创建 + 事件泵 + 渲染主循环整体搬进 CreateThread 创建的 1:1
 * 原生 OS 线程（native/cuishim.c + src/native_ui.cj 的 uiThreadMain），
 * 调度器不管理原生线程，消息队列归属永不变。main 阻塞等待窗口关闭。
 */
main(): Int64 {
    gAppState = Some(AppState())
    unsafe { cui_start_native(uiThreadMain) }
    return 0
}
