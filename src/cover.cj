/*
 * 图书封面绘制。
 *
 * 与 seline_bili 的 `NetworkCover` 同一套管线，拆成函数而不是控件：
 * 书本卡片、详情页大封面都用它，各自决定矩形与圆角。
 *
 *   URL ──后台──► 磁盘文件 ──后台──► RGBA 像素 ──UI 线程──► 纹理 ──► 屏幕
 *
 * 渲染器只存在于 `draw` 的 `UiContext` 里，所以「上传纹理」只能在绘制期做。
 */
package seline_read

import chui.*
import std.env.getVariable
import seline_ui.*

/** 书本封面比例：宽 / 高 = 2 / 3。 */
let BOOK_COVER_ASPECT: Float32 = 2.0 / 3.0

/** 画一张网络封面（未就绪时画占位块）。 */
func drawBookCover(ctx: UiContext, state: AppState, url: String, frame: Rect,
    radius: Float32, backdrop!: Bool = true): Unit {
    let t0 = PerformanceClock.ticksNanoseconds()
    drawBookCoverImpl(ctx, state, url, frame, radius, backdrop)
    state.diagCoverMs += Float32(Int64(PerformanceClock.ticksNanoseconds() - t0)) / 1000000.0
}

private func drawBookCoverImpl(ctx: UiContext, state: AppState, url: String, frame: Rect,
    radius: Float32, backdrop: Bool): Unit {
    let palette = selineTheme().palette
    if (frame.w <= 0.0 || frame.h <= 0.0) {
        return
    }
    // 有真封面：只画"底板 + 真图"两次，**不再先铺占位图再盖上去**。
    // chui 的每次 textured/rounded 绘制都会分配一批几何数据（实测单次 ~40~80KB），
    // 一屏 69 张封面就是 3 次绘制/张 ≈ 13MB/帧 的分配量 —— 直接喂给 GC，
    // 交互中就会出现 200~350ms 的停顿。少画一次就是少一份分配。
    if (!url.isEmpty()) {
        match (state.coverTexture(url)) {
            case Some(texture) =>
                if (backdrop) {
                    paintSurface(ctx.renderer, frame, palette.surfaceSunken, radius)
                }
                drawFittedTexture(ctx.renderer, texture, frame, radius)
                return
            case None => ()
        }
        if (state.canUploadTextureThisFrame()) {
            match (state.takeDecodedImage(url)) {
                case Some(image) =>
                    state.noteTextureUpload()
                    state.diagUploadCount += 1
                    let texture = SelineImageTexture(ctx.renderer, image)
                    state.rememberCoverTexture(url, texture)
                    if (backdrop) {
                        paintSurface(ctx.renderer, frame, palette.surfaceSunken, radius)
                    }
                    drawFittedTexture(ctx.renderer, texture, frame, radius)
                    return
                case None => ()
            }
        }
    }
    // 没有真封面（加载中/没有封面/解码失败）：底板 + 默认封面图
    if (backdrop) {
        paintSurface(ctx.renderer, frame, palette.surfaceSunken, radius)
    }
    match (state.placeholderCoverTexture(ctx)) {
        case Some(texture) =>
            texture.draw(ctx.renderer, frame)
        case None => ()
    }
    if (!url.isEmpty()) {
        // 确保后台任务已排上
        let _ = state.imagePath(url, SelineImageKind.Cover)
    }
}

/** 等比放进矩形（Contain），多余部分留白。 */
private func drawFittedTexture(renderer: Renderer, texture: SelineImageTexture,
    frame: Rect, radius: Float32): Unit {
    let sourceW = Float32(texture.width)
    let sourceH = Float32(texture.height)
    if (sourceW <= 0.0 || sourceH <= 0.0) {
        return
    }
    var scale = frame.w / sourceW
    if (frame.h / sourceH < scale) {
        scale = frame.h / sourceH
    }
    let w = sourceW * scale
    let h = sourceH * scale
    let target = Rect(frame.x + (frame.w - w) * 0.5, frame.y + (frame.h - h) * 0.5, w, h)
    if (radius > 0.5) {
        texture.drawRounded(renderer, target, radius)
    } else {
        texture.draw(renderer, target)
    }
}

/**
 * 把文本按可用宽度截断（超出加省略号）。
 *
 * 用逐字符收缩而不是按字符数估算：中文/英文/数字宽度差异很大，
 * 估算会把标题截得过短或仍然溢出。
 */
func fitTextWidth(ctx: UiContext, text: String, maxWidth: Float32, pointSize: Float32,
    style: FontStyle, family: String): String {
    if (text.isEmpty() || maxWidth <= 0.0) {
        return ""
    }
    let fontValue: ?String = if (family.isEmpty()) {
        None<String>
    } else {
        Some(family)
    }
    if (ctx.renderer.textWidth(text, pointSize: pointSize, style: style,
        font: fontValue) <= maxWidth) {
        return text
    }
    let runes = text.toRuneArray()
    // **二分**找"最长能放下的前缀"。
    //
    // 旧实现是从整段文本开始逐字符收缩：每收缩一次都要重建候选字符串（O(n)）
    // 再跑一遍完整 shaping（`renderer.textWidth`），整体是 O(n²)。
    // 一段 400 字的书单简介在首次出现时能跑到 100~400ms —— 这就是"网络请求
    // 刚结束那一下卡死"的真凶（新一页的文字第一次需要精确截断，每帧只测 2 段，
    // 每段却要几百毫秒，于是连着几帧都是 200~330ms）。
    //
    // 二分只需 log2(n) ≈ 9 次 shaping，成本从"几百毫秒"降到"几毫秒"，而且
    // 结果和逐字符收缩完全一致（宽度随长度单调不减）。
    var lo: Int64 = 0
    var hi: Int64 = Int64(runes.size)
    while (lo < hi) {
        let mid = (lo + hi + 1) / 2
        let candidate = textPrefix(runes, mid) + "…"
        if (ctx.renderer.textWidth(candidate, pointSize: pointSize, style: style,
            font: fontValue) <= maxWidth) {
            lo = mid
        } else {
            hi = mid - 1
        }
    }
    if (lo <= 0) {
        return "…"
    }
    textPrefix(runes, lo) + "…"
}

/** 取前 `count` 个 rune 组成的字符串（二分里只调用 log2(n) 次）。 */
private func textPrefix(runes: Array<Rune>, count: Int64): String {
    if (count <= 0) {
        return ""
    }
    let builder = StringBuilder()
    var index: Int64 = 0
    for (rune in runes) {
        if (index >= count) {
            break
        }
        builder.append(rune)
        index += 1
    }
    builder.toString()
}
