/*
 * 画卷本体：一个把整幅青绿山水绘进自身矩形的自定义控件。
 *
 * 绘制次序即景深：绢底天光 → 远三重山（立于水后）→ 江面（渐变水色 + 网巾纹涟漪 + 流水
 * 长曲）→ 近两重山（低谷沉入水下，山群成岛、江水穿行其间；水下压一抹倒影）→ 雾锁江腰 →
 * 乌篷小舟（只落在开阔江面）→ 山脊松簇（虬干平顶针冠）→ 天际飞鸟 → 引首题字与朱印。
 * 场景完全静态：不请求帧、不吞事件，首帧绘出后渲染循环即回到空闲。
 */
package chui_cangcui

import chui.{Color, Pen, Rect, Renderer, Size, UiContext, UiEvent, Widget, emit}
import std.math.sin

// 山体竖条宽（逻辑像素）：足够细以显山形，整幅约三千条渐变矩形，网格缓存轻松承载。
let STRIP_W: Float32 = 2.0

class ScrollPainting <: Widget {
    private var frame = Rect.zero()

    init() {
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        paintScene(ctx.renderer, frame)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

func paintScene(r: Renderer, frame: Rect): Unit {
    let w = frame.w
    let h = frame.h
    let x0 = frame.x
    let y0 = frame.y
    let waterTop = y0 + Float32(WATER_FRAC) * h
    // 绢底天光：上暖下淡。
    r.fillRoundedRectGradient(Rect(x0, y0, w, h), 0.0, SILK_TOP, SILK_HORIZON)
    // 远三重山立于水后（山脚由水面覆盖），第二、三重山脚各横一道雾带。
    for (layer in 0..3) {
        paintFarMountains(r, layer, x0, y0, w, h)
        if (layer >= 1) {
            let mistY = y0 + Float32(MOUNTAINS[layer].baseFrac) * h - 24.0
            r.fillRoundedRectSoft(Rect(x0 - 40.0, mistY, w + 80.0, 42.0), 21.0, MIST, feather: 18.0)
        }
    }
    paintWater(r, x0, y0, w, h, waterTop)
    // 近两重山：竖条钳到水线，低谷沉入江中，山群成岛。
    paintIslandMountains(r, 3, x0, y0, w, h, waterTop)
    // 一道薄雾横锁江腰，衬出前后岛群的远近。
    r.fillRoundedRectSoft(Rect(x0 - 40.0, waterTop - 12.0, w + 80.0, 34.0), 17.0, MIST, feather: 16.0)
    paintIslandMountains(r, 4, x0, y0, w, h, waterTop)
    paintBoats(r, x0, y0, w, h, waterTop)
    paintPines(r, x0, y0, w, h, waterTop)
    paintBirds(r, x0, y0, w, h)
    paintTitle(r, x0, y0, w, h)
}

// 远山：逐竖条画到画底（水面随后覆盖山脚），石青罩顶、石绿铺底，脊线淡描。
private func paintFarMountains(r: Renderer, layer: Int64, x0: Float32, y0: Float32, w: Float32, h: Float32): Unit {
    let m = MOUNTAINS[layer]
    var x: Float32 = 0.0
    while (x < w) {
        let stripW = min(STRIP_W, w - x)
        let top = ridgeY(layer, x + stripW / 2.0, w, h)
        let capDepth = min(h - top, h * 0.30)
        r.fillRoundedRectGradient(Rect(x0 + x, y0 + top, stripW, capDepth), 0.0, m.cap, m.base)
        if (h - top > capDepth) {
            r.fillRoundedRect(Rect(x0 + x, y0 + top + capDepth, stripW, h - top - capDepth), 0.0, m.base)
        }
        x += STRIP_W
    }
    strokeRidge(r, layer, x0, y0, w, h, y0 + h, Pen(width: 1.0, color: Color.rgba(96, 124, 132, 90)))
}

/*
 * 近山成岛：竖条只画到水线——山脊沉到水下的横段不落一笔，江水由此穿过山群；
 * 岛身之下再压一抹随山形的淡倒影。脊线以墨青勾勒，入水即止。
 */
private func paintIslandMountains(
    r: Renderer,
    layer: Int64,
    x0: Float32,
    y0: Float32,
    w: Float32,
    h: Float32,
    waterTop: Float32
): Unit {
    let m = MOUNTAINS[layer]
    var x: Float32 = 0.0
    while (x < w) {
        let stripW = min(STRIP_W, w - x)
        let top = y0 + ridgeY(layer, x + stripW / 2.0, w, h)
        if (top < waterTop - 0.5) {
            let visible = waterTop - top
            let capDepth = min(visible, h * 0.30)
            r.fillRoundedRectGradient(Rect(x0 + x, top, stripW, capDepth), 0.0, m.cap, m.base)
            if (visible > capDepth) {
                r.fillRoundedRect(Rect(x0 + x, top + capDepth, stripW, visible - capDepth), 0.0, m.base)
            }
            // 倒影：山愈高影愈长，最多没入水下 20px，色取罩顶而淡。
            let depth = min(visible * 0.22, 20.0)
            r.fillRoundedRect(Rect(x0 + x, waterTop, stripW, depth), 0.0, m.cap.withAlpha(46))
        }
        x += STRIP_W
    }
    strokeRidge(r, layer, x0, y0, w, h, waterTop, Pen(width: 1.2, color: Color.rgba(31, 62, 74, 150)))
}

// 沿脊勾勒轮廓（勾线填色技法，也平滑竖条边缘）；线段两端都沉到 limit 之下时不落笔。
private func strokeRidge(
    r: Renderer,
    layer: Int64,
    x0: Float32,
    y0: Float32,
    w: Float32,
    h: Float32,
    limit: Float32,
    pen: Pen
): Unit {
    let step: Float32 = 6.0
    var cx: Float32 = 0.0
    var prevY = y0 + ridgeY(layer, 0.0, w, h)
    while (cx < w) {
        let nx = min(cx + step, w)
        let ny = y0 + ridgeY(layer, nx, w, h)
        if (min(prevY, ny) < limit) {
            r.strokeLine(x0 + cx, min(prevY, limit), x0 + nx, min(ny, limit), pen)
        }
        prevY = ny
        cx = nx
    }
}

// 江面：渐变水色、岸线、网巾纹涟漪弧与穿行山间的流水长曲。
private func paintWater(r: Renderer, x0: Float32, y0: Float32, w: Float32, h: Float32, waterTop: Float32): Unit {
    let depth = y0 + h - waterTop
    r.fillRoundedRectGradient(Rect(x0, waterTop, w, depth), 0.0, WATER_TOP, WATER_DEEP)
    r.strokeLine(x0, waterTop, x0 + w, waterTop, Pen(width: 1.0, color: Color.rgba(40, 80, 66, 70)))
    let pen = Pen(width: 1.1, color: WAVE_INK)
    for ((tx, row) in RIPPLE_SPOTS) {
        let rx = x0 + Float32(tx) * w
        let ry = waterTop + 10.0 + Float32(row) * (depth - 20.0) / 4.0
        paintRipple(r, rx, ry, 30.0 + Float32(row) * 4.0, pen)
    }
    for ((tx, row) in STREAM_SPOTS) {
        paintStream(r, x0 + Float32(tx) * w, waterTop + 16.0 + Float32(row) * 14.0, pen)
    }
}

// 一道下弯的涟漪弧（网巾纹）：四段折线近似浅弧。
private func paintRipple(r: Renderer, cx: Float32, cy: Float32, width: Float32, pen: Pen): Unit {
    let q = width / 4.0
    r.strokeLine(cx, cy, cx + q, cy + 1.4, pen)
    r.strokeLine(cx + q, cy + 1.4, cx + 2.0 * q, cy + 1.9, pen)
    r.strokeLine(cx + 2.0 * q, cy + 1.9, cx + 3.0 * q, cy + 1.4, pen)
    r.strokeLine(cx + 3.0 * q, cy + 1.4, cx + width, cy, pen)
}

// 一条 S 形流水长曲：八段折线沿正弦摆动，写「潺潺流水」的走势。
private func paintStream(r: Renderer, sx: Float32, sy: Float32, pen: Pen): Unit {
    let seg: Float32 = 13.0
    var px = sx
    var py = sy
    for (i in 1..9) {
        let nx = sx + Float32(i) * seg
        let phase = Float64(i) * 0.9
        let ny = sy + 3.2 * Float32(sin(phase))
        r.strokeLine(px, py, nx, ny, pen)
        px = nx
        py = ny
    }
}

// 乌篷小舟：月牙船身两端上翘、竹篷拱起，船尾渔翁执篙，身下两笔倒影。
// 仅当候选位置两重近山都沉于水下（开阔江面）才落舟。
private func paintBoats(r: Renderer, x0: Float32, y0: Float32, w: Float32, h: Float32, waterTop: Float32): Unit {
    let depth = y0 + h - waterTop
    let hullPen = Pen(width: 1.9, color: INK)
    let finePen = Pen(width: 1.2, color: INK)
    let ghost = Pen(width: 1.0, color: Color.rgba(35, 66, 58, 80))
    for (tb in BOAT_SPOTS) {
        let bx = Float32(tb) * w
        if (y0 + ridgeY(3, bx, w, h) < waterTop + 4.0 || y0 + ridgeY(4, bx, w, h) < waterTop + 4.0) {
            continue
        }
        let cx = x0 + bx
        let cy = waterTop + depth * 0.40
        // 月牙船身：两端上翘的四段弧。
        r.strokeLine(cx - 19.0, cy - 5.0, cx - 12.0, cy + 1.0, hullPen)
        r.strokeLine(cx - 12.0, cy + 1.0, cx + 2.0, cy + 3.0, hullPen)
        r.strokeLine(cx + 2.0, cy + 3.0, cx + 13.0, cy + 1.0, hullPen)
        r.strokeLine(cx + 13.0, cy + 1.0, cx + 20.0, cy - 5.0, hullPen)
        // 竹篷：三段拱弧覆在船身中前段。
        r.strokeLine(cx - 11.0, cy - 1.0, cx - 7.0, cy - 7.0, finePen)
        r.strokeLine(cx - 7.0, cy - 7.0, cx + 1.0, cy - 7.5, finePen)
        r.strokeLine(cx + 1.0, cy - 7.5, cx + 5.0, cy - 1.5, finePen)
        // 渔翁：斗笠一点、身躯一笔，执篙斜入水。
        r.fillCircle(cx + 10.5, cy - 9.0, 2.0, INK)
        r.strokeLine(cx + 10.5, cy - 7.0, cx + 9.5, cy - 1.0, finePen)
        r.strokeLine(cx + 12.0, cy - 12.0, cx + 16.5, cy + 6.0, finePen)
        // 倒影两笔。
        r.strokeLine(cx - 10.0, cy + 8.0, cx + 1.0, cy + 8.0, ghost)
        r.strokeLine(cx + 5.0, cy + 11.0, cx + 13.0, cy + 11.0, ghost)
    }
}

// 松簇：虬曲三折的主干 + 三层平顶针冠 + 一支旁逸侧枝；植于山脊且山脊须高出水线。
private func paintPines(r: Renderer, x0: Float32, y0: Float32, w: Float32, h: Float32, waterTop: Float32): Unit {
    for (tp in PINE_SPOTS) {
        paintPineCluster(r, x0, y0, w, h, waterTop, Float32(tp), 3, h * 0.052)
    }
    for (tp in PINE_SPOTS_NEAR) {
        paintPineCluster(r, x0, y0, w, h, waterTop, Float32(tp), 4, h * 0.066)
    }
}

private func paintPineCluster(
    r: Renderer,
    x0: Float32,
    y0: Float32,
    w: Float32,
    h: Float32,
    waterTop: Float32,
    t: Float32,
    layer: Int64,
    size: Float32
): Unit {
    let baseY = y0 + ridgeY(layer, t * w, w, h)
    if (baseY > waterTop - size * 1.3) {
        return
    }
    // 一正一欹两株为一簇。
    paintPine(r, x0 + t * w, baseY, size, 0.0)
    paintPine(r, x0 + t * w + size * 0.8, y0 + ridgeY(layer, t * w + size * 0.8, w, h), size * 0.72, 0.22)
}

/*
 * 一株中国画式的松：主干虬曲三折（lean 控制欹侧之势），顶冠与两层横向针冠如平伸的云片，
 * 中段旁逸一枝、枝端另起小冠——取法工笔松的「平顶偃盖」。
 */
private func paintPine(r: Renderer, px: Float32, py: Float32, size: Float32, lean: Float32): Unit {
    let trunk = Pen(width: 1.7, color: INK)
    let needle = Pen(width: 1.3, color: INK)
    let s = size
    let l = lean * s
    // 主干三折。
    let x1 = px + l * 0.3
    let y1 = py - s * 0.36
    let x2 = px - s * 0.06 + l * 0.7
    let y2 = py - s * 0.70
    let x3 = px + s * 0.08 + l
    let y3 = py - s
    r.strokeLine(px, py + 1.0, x1, y1, trunk)
    r.strokeLine(x1, y1, x2, y2, trunk)
    r.strokeLine(x2, y2, x3, y3, trunk)
    // 顶冠与两层针冠：横向云片，愈下愈宽，两端微垂。
    paintNeedleTier(r, x3, y3, s * 0.34, needle)
    paintNeedleTier(r, x2 + (x3 - x2) * 0.3, y2 - s * 0.06, s * 0.46, needle)
    paintNeedleTier(r, x1 + (x2 - x1) * 0.3, y1 - s * 0.05, s * 0.40, needle)
    // 旁逸侧枝与枝端小冠。
    let bx = x1 - s * 0.42
    let by = y1 - s * 0.10
    r.strokeLine(x1, y1, bx, by, needle)
    paintNeedleTier(r, bx, by - s * 0.03, s * 0.26, needle)
}

// 一层横向针冠：中枝平伸、两端下垂三笔，如覆盖的云片。
private func paintNeedleTier(r: Renderer, cx: Float32, cy: Float32, half: Float32, pen: Pen): Unit {
    r.strokeLine(cx - half, cy + half * 0.22, cx, cy, pen)
    r.strokeLine(cx, cy, cx + half, cy + half * 0.22, pen)
    r.strokeLine(cx - half * 0.55, cy + half * 0.10, cx - half * 0.30, cy - half * 0.16, pen)
    r.strokeLine(cx + half * 0.30, cy - half * 0.16, cx + half * 0.55, cy + half * 0.10, pen)
}

// 飞鸟：天际的人字两笔。
private func paintBirds(r: Renderer, x0: Float32, y0: Float32, w: Float32, h: Float32): Unit {
    let pen = Pen(width: 1.3, color: Color.rgba(35, 66, 58, 170))
    for ((tx, ty) in BIRD_SPOTS) {
        let bx = x0 + Float32(tx) * w
        let by = y0 + Float32(ty) * h
        r.strokeLine(bx - 5.0, by, bx, by - 3.0, pen)
        r.strokeLine(bx, by - 3.0, bx + 5.0, by, pen)
    }
}

// 引首：右上竖排「苍翠」大字、旁注小字与朱印（手卷自右展开，题字置于卷首）。
// 题字与印文用系统安装的霞鹜文楷（楷体笔锋自足，不加粗）；印文按实测宽高在印面内取中。
private func paintTitle(r: Renderer, x0: Float32, y0: Float32, w: Float32, _: Float32): Unit {
    let titleX = x0 + w - 92.0
    var charY = y0 + 30.0
    for (ch in "苍翠".toRuneArray()) {
        r.text("${ch}", titleX, charY, INK, pointSize: 38.0, font: WENKAI)
        charY += 52.0
    }
    var subY = y0 + 40.0
    for (ch in "千里江山".toRuneArray()) {
        r.text("${ch}", titleX + 52.0, subY, Color.rgba(35, 66, 58, 190), pointSize: 13.0, font: WENKAI)
        subY += 18.0
    }
    let sealSize: Float32 = 27.0
    let sealX = titleX + 4.0
    let sealY = charY + 12.0
    r.fillRoundedRect(Rect(sealX, sealY, sealSize, sealSize), 3.0, SEAL_RED)
    let glyph = "翠"
    let glyphW = r.textWidth(glyph, pointSize: 16.0, font: WENKAI)
    let glyphH = r.textHeight(pointSize: 16.0, font: WENKAI)
    // 行高含下行留白，几何居中会显得偏上；按光学中心再下移一点半像素。
    r.text(glyph, sealX + (sealSize - glyphW) / 2.0, sealY + (sealSize - glyphH) / 2.0 + 1.5, SEAL_TEXT,
        pointSize: 16.0, font: WENKAI)
}
