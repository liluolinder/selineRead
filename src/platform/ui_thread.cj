/*
 * 在**固定原生线程**上运行 UI 主循环。
 *
 * 仓颉运行时是 M:N 调度：一个仓颉线程可能在多个 OS 线程之间迁移。
 * 而 CangHui 的窗口有硬要求 —— **创建、轮询、绘制、请求文本输入
 * 必须是同一个原生线程**。一旦运行时把线程挪走，下一帧就会抛：
 *
 *     IllegalStateException: text input requires the open window's native UI owner
 *
 * 解决办法：用 Win32 `CreateThread` 建一条**不是仓颉运行时创建**的线程，
 * 再从 `@C` 入口回到仓颉。这种线程的原生栈属于它自己，运行时不参与调度，
 * 也就不会把它挪到别的 OS 线程上。
 *
 * 主线程只负责 `WaitForSingleObject` 等它结束，因此进程生命周期与 UI 生命周期一致。
 */
package seline_read.platform

/** `CreateThread` 的返回值：线程句柄。 */
@C
foreign func CreateThread(
    attributes: CPointer<Unit>,
    stackSize: UIntNative,
    startAddress: CPointer<Unit>,
    parameter: CPointer<Unit>,
    flags: UInt32,
    threadId: CPointer<UInt32>
): CPointer<Unit>

@C
foreign func WaitForSingleObject(handle: CPointer<Unit>, milliseconds: UInt32): UInt32

/** `INFINITE`。 */
private let WAIT_INFINITE: UInt32 = 0xFFFFFFFF

/**
 * UI 线程要跑的东西。
 *
 * 放在模块级变量里是因为 `@C` 入口点不能捕获闭包 —— 它只能从 C 拿一个参数。
 * 这也意味着同一进程只能有一个 UI 主循环，对一个桌面应用是合理约束。
 */
private var uiBootstrap: () -> Unit = {=> ()}

/** C 在新线程上调用的入口。 */
@C
func uiThreadEntry(_: CPointer<Unit>): UInt32 {
    uiBootstrap()
    0
}

/**
 * 在专用原生线程上执行 `bootstrap`，等它返回。
 *
 * 创建线程失败时**退回调用线程**执行：能启动但线程保证弱一点，
 * 好过直接不启动。
 */
public func runUiOnNativeThread(bootstrap: () -> Unit): Unit {
    uiBootstrap = bootstrap
    let start = CPointer<Unit>(uiThreadEntry)
    let handle = unsafe {
        CreateThread(CPointer<Unit>(), 0, start, CPointer<Unit>(), 0, CPointer<UInt32>())
    }
    if (handle.isNull()) {
        bootstrap()
        return
    }
    let _ = unsafe { WaitForSingleObject(handle, WAIT_INFINITE) }
}
