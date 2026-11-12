/*
 * 进程退出。
 *
 * 为什么不用 `exit(0)` 或直接让 main 返回：退出阶段 Cangjie 运行时回收
 * 后台线程对象时会踩到已释放内存（PageHeap 全量堆验证抓到的现场在
 * `libcangjie-runtime!CJ_CJThreadFree` 内部，Windows 记为 0xc0000374），
 * 于是每次正常关窗都会「崩溃」并弹 Windows 错误报告。
 *
 * 这里在 UI 收尾完成后直接 `TerminateProcess`：不执行 CRT atexit / 运行时
 * 线程回收，进程以指定退出码干净结束。纹理、渲染器、窗口已由 chui 在
 * `window.close()` 之前释放，所以不会泄漏需要清理的原生资源。
 */
package seline_read.platform

foreign func GetCurrentProcess(): CPointer<Unit>
foreign func TerminateProcess(process: CPointer<Unit>, exitCode: UInt32): Int32

/** 立即结束当前进程，返回码由调用方指定（正常退出传 0）。 */
public func terminateSelf(exitCode: UInt32): Unit {
    let handle = unsafe { GetCurrentProcess() }
    let _ = unsafe { TerminateProcess(handle, exitCode) }
}