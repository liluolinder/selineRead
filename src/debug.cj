/*
 * 调试日志。
 *
 * 程序是 Windows 子系统：stdout 没有接收方，重定向到文件也拿不到内容
 * （这点在 seline_bili 里踩过）。诊断信息写 `%TEMP%/seline_read_debug.log`。
 */
package seline_read

import std.env.getVariable
import std.fs.{File, Path, exists}

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

/**
 * 解析随 exe 分发的资源文件（`assets/` 下）。
 *
 * 三种运行方式都要能找到：
 * - 双击/直接运行：当前目录就是 exe 目录 → `assets/xxx.png`；
 * - 从仓库根运行：`target/release/bin/assets/xxx.png`；
 * - 验收/自定义：`SELINE_READ_ASSETS` 显式指向资源目录。
 *
 * 返回空串表示没找到（调用方回退到占位/默认绘制）。
 */
public func findAsset(name: String): String {
    let custom = getVariable("SELINE_READ_ASSETS") ?? ""
    if (!custom.isEmpty()) {
        let path = Path(custom).join(name).toString()
        if (exists(Path(path))) {
            return path
        }
    }
    let candidates = [
        Path("assets").join(name).toString(),
        Path("target").join("release").join("bin").join("assets").join(name).toString(),
        name
    ]
    for (candidate in candidates) {
        if (exists(Path(candidate))) {
            return candidate
        }
    }
    ""
}