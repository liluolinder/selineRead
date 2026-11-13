/*
 * 给进程挂一个**隐藏的控制台**。
 *
 * 程序是 Windows 子系统（`cjpm.toml` 的 `--subsystem windows`），双击不弹黑框。
 * 代价是进程没有控制台；而 Windows 对控制台子进程的规则是「父进程有控制台就继承，
 * 没有就新分配一个」。将来若用 `std.process` 起外部工具（打开下载目录、阅读器），
 * 就会闪一个黑框。所以启动时 `AllocConsole()` 再立刻 `ShowWindow(SW_HIDE)`。
 *
 * 从终端启动时进程已有控制台，`AllocConsole` 失败 —— 这时绝不能动用户那个窗口。
 */
package seline_read.platform

import std.env.getVariable
import std.core.sleep

/** kernel32：给自己分配一个控制台；已经有就返回 0。 */
foreign func AllocConsole(): Int32

/** kernel32：当前进程的控制台窗口句柄；没有控制台时为空。 */
foreign func GetConsoleWindow(): CPointer<Unit>

/** user32：设置窗口显示状态。 */
foreign func ShowWindow(window: CPointer<Unit>, command: Int32): Int32

/** `SW_HIDE`。 */
private let SW_HIDE: Int32 = 0

/** 分配一个隐藏控制台（幂等：已有控制台时什么都不做）。 */
public func attachHiddenConsole(): Unit {
    if (hiddenConsoleDisabled()) {
        return
    }
    let created = unsafe { AllocConsole() }
    if (created == 0) {
        return
    }
    let first = unsafe { GetConsoleWindow() }
    if (!unsafe { first.isNull() }) {
        let _ = unsafe { ShowWindow(first, SW_HIDE) }
    }
    let _ = spawn {=>
        var attempt: Int64 = 0
        while (attempt < 100) {
            let window = unsafe { GetConsoleWindow() }
            if (!unsafe { window.isNull() }) {
                let _ = unsafe { ShowWindow(window, SW_HIDE) }
            }
            attempt += 1
            sleep(Duration.millisecond * 20)
        }
    }
}

/** 是否禁止挂隐藏控制台（`SELINE_READ_NO_HIDDEN_CONSOLE`，仅 debug 构建支持）。 */
@When[debug]
private func hiddenConsoleDisabled(): Bool {
    match (getVariable("SELINE_READ_NO_HIDDEN_CONSOLE")) {
        case Some(value) => value == "1"
        case None => false
    }
}

@When[!debug]
private func hiddenConsoleDisabled(): Bool {
    false
}
