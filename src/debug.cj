/*
 * 调试日志。
 *
 * 程序是 Windows 子系统：stdout 没有接收方，重定向到文件也拿不到内容
 * （这点在 seline_bili 里踩过）。诊断信息写 `%TEMP%/seline_read_debug.log`。
 */
package seline_read

import std.convert.*
import std.env.getVariable
import std.fs.{File, Path, exists}

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
    let custom = customAssetsDir()
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

/*
 * 调试专用的运行时覆盖项。
 *
 * 每个都提供 debug / release 两版实现：release 版直接返回默认值，
 * 调用点不携带环境变量名字符串，产物里搜不到这些探针。
 */
@When[debug]
public func offlineMode(): Bool {
    (getVariable("SELINE_READ_OFFLINE") ?? "") == "1"
}

@When[!debug]
public func offlineMode(): Bool {
    false
}

/** 滚动动画模式覆盖（`immediate` 关闭弹簧）。 */
@When[debug]
public func scrollModeOverride(): String {
    getVariable("SELINE_READ_SCROLL") ?? ""
}

@When[!debug]
public func scrollModeOverride(): String {
    ""
}

/** 自定义资源目录（`SELINE_READ_ASSETS`）。 */
@When[debug]
public func customAssetsDir(): String {
    getVariable("SELINE_READ_ASSETS") ?? ""
}

@When[!debug]
public func customAssetsDir(): String {
    ""
}

/** 自定义 CJK 回退字体（`SELINE_READ_FALLBACK_FONT`）。 */
@When[debug]
public func customFallbackFont(): String {
    getVariable("SELINE_READ_FALLBACK_FONT") ?? ""
}

@When[!debug]
public func customFallbackFont(): String {
    ""
}
/** 主题过渡时长（debug 可用 `SELINE_READ_THEME_MS` 覆盖，release 固定 620ms）。 */
@When[debug]
public func themeTransitionMs(): Int64 {
    Int64.parse(getVariable("SELINE_READ_THEME_MS") ?? "620")
}

@When[!debug]
public func themeTransitionMs(): Int64 {
    620
}
