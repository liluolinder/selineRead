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
import seline_ui.*

/** 书本封面比例：宽 / 高 = 2 / 3。 */
let BOOK_COVER_ASPECT: Float32 = 2.0 / 3.0

/** 画一张网络封面（未就绪时画占位块）。 */
func drawBookCover(ctx: UiContext, state: AppState, url: String, frame: Rect,
    radius: Float32): Unit {
    let palette = selineTheme().palette
    paintSurface(ctx.renderer, frame, palette.surfaceSunken, radius)
    if (frame.w <= 0.0 || frame.h <= 0.0) {
        return
    }
    // 先铺默认封面图：加载中/没有封面/解码失败时这就是最终显示。
    // 用拉伸铺满而不是等比 Contain：默认封面是 256x362，而卡片里的封面框是 2:3，
    // 等比会上下各留一条缝（看起来像"图片顶部缺了一块"）。
    match (state.placeholderCoverTexture(ctx)) {
        case Some(texture) =>
            texture.draw(ctx.renderer, frame)
        case None => ()
    }
    if (url.isEmpty()) {
        return
    }
    // 1) 纹理已就绪
    match (state.coverTexture(url)) {
        case Some(texture) =>
            drawFittedTexture(ctx.renderer, texture, frame)
            return
        case None => ()
    }
    // 2) 后台已解出像素 → 本帧上传纹理（每帧限量，避免一帧上传几十张造成卡顿）
    if (state.canUploadTextureThisFrame()) {
        match (state.takeDecodedImage(url)) {
            case Some(image) =>
                state.noteTextureUpload()
                let texture = SelineImageTexture(ctx.renderer, image)
                state.rememberCoverTexture(url, texture)
                drawFittedTexture(ctx.renderer, texture, frame)
                return
            case None => ()
        }
    }
    // 3) 都没有 → 确保后台任务已排上
    let _ = state.imagePath(url, SelineImageKind.Cover)
}

/** 等比放进矩形（Contain），多余部分留白。 */
private func drawFittedTexture(renderer: Renderer, texture: SelineImageTexture,
    frame: Rect): Unit {
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
    texture.draw(renderer, target)
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
    var result = "…"
    var end = Int64(runes.size) - 1
    while (end > 0) {
        var candidate = ""
        var index: Int64 = 0
        for (rune in runes) {
            if (index >= end) {
                break
            }
            candidate += rune.toString()
            index += 1
        }
        let withEllipsis = candidate + "…"
        if (ctx.renderer.textWidth(withEllipsis, pointSize: pointSize, style: style,
            font: fontValue) <= maxWidth) {
            result = withEllipsis
            break
        }
        end -= 1
    }
    result
}
