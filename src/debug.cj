/*
 * 调试日志。
 *
 * 程序是 Windows 子系统：stdout 没有接收方，重定向到文件也拿不到内容
 * （这点在 seline_bili 里踩过）。诊断信息写 `%TEMP%/seline_read_debug.log`。
 */
package seline_read

import std.env.getVariable
import std.fs.{File, Path}

/** 系统临时目录（Windows 即 `%TEMP%`）。 */
public func getTempRoot(): String {
    getVariable("TEMP") ?? "."
}

/** 追加一行调试日志（失败静默：日志不该影响主流程）。 */
public func writeDebugLog(text: String): Unit {
    try {
        let temp = getVariable("TEMP") ?? "."
        File.appendTo(Path("${temp}/seline_read_debug.log"), (text + "\n").toArray())
    } catch (_: Exception) {
        ()
    }
}
