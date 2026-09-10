package SelineRead

import chui.*
import std.fs.*

// 本地封面显示：封面由 covers.cj 后台下载并用 stb 解码转成 BMP
// （chui 的 ImageView 原生支持），这里只做存在性检查与展示，
// 任何解码/写盘都不在 UI 线程执行。

// 把 RGBA 像素写成 24 位 BMP（行倒序、BGR）
func writeBmp(path: String, width: Int32, height: Int32, rgba: Array<UInt8>): Bool {
    let w = Int64(width)
    let h = Int64(height)
    let rowRaw = w * 3
    let rowStride = (rowRaw + 3) / 4 * 4 // 4 字节对齐
    let pixelBytes = rowStride * h
    let fileSize = 54 + pixelBytes

    let header = Array<UInt8>(54, repeat: 0)
    header[0] = UInt8(66)  // 'B'
    header[1] = UInt8(77)  // 'M'
    writeU32(header, 2, UInt32(fileSize))
    writeU32(header, 10, UInt32(54))
    writeU32(header, 14, UInt32(40))
    writeU32(header, 18, UInt32(width))
    writeU32(header, 22, UInt32(height))
    header[26] = UInt8(1) // planes
    header[28] = UInt8(24) // bpp
    writeU32(header, 34, UInt32(pixelBytes))

    let pixels = Array<UInt8>(pixelBytes, repeat: 0)
    var y: Int64 = 0
    while (y < h) {
        let srcRow = y * w * 4
        // BMP 行自下而上
        let dstRow = (h - 1 - y) * rowStride
        var x: Int64 = 0
        while (x < w) {
            let s = srcRow + x * 4
            let d = dstRow + x * 3
            pixels[d] = rgba[s + 2]     // B
            pixels[d + 1] = rgba[s + 1] // G
            pixels[d + 2] = rgba[s]     // R
            x += 1
        }
        y += 1
    }

    try {
        let f = File(path, Write)
        f.write(header)
        f.write(pixels)
        f.flush()
        f.close()
        return true
    } catch (_: Exception) {
        return false
    }
}

private func writeU32(target: Array<UInt8>, offset: Int64, value: UInt32) {
    target[offset] = UInt8(value & UInt32(0xFF))
    target[offset + 1] = UInt8((value >> 8) & UInt32(0xFF))
    target[offset + 2] = UInt8((value >> 16) & UInt32(0xFF))
    target[offset + 3] = UInt8((value >> 24) & UInt32(0xFF))
}

// 盒式滤波降采样 RGBA：目标宽 targetW，等比缩高（只缩小不放大）。
// 仅在 worker 线程调用——把封面缩成缩略图后 BMP 只有 ~250KB，
// UI 线程首次 draw 的读盘+纹理上传不再拖慢帧循环（快速滚动冻结的根因）。
func downscaleRgba(width: Int32, height: Int32, rgba: Array<UInt8>,
    targetW: Int64): (Int32, Int32, Array<UInt8>) {
    let w = Int64(width)
    let h = Int64(height)
    if (w <= targetW || w <= 0 || h <= 0) {
        return (width, height, rgba)
    }
    let nw = targetW
    let nh = max(Int64(1), h * targetW / w)
    let out = Array<UInt8>(nw * nh * 4, repeat: 0)
    let sx = Float64(w) / Float64(nw)
    let sy = Float64(h) / Float64(nh)
    var y: Int64 = 0
    while (y < nh) {
        // 每个目标像素平均其覆盖的源像素盒
        let y0 = Int64(Float64(y) * sy)
        let y1 = min(h, max(y0 + 1, Int64(Float64(y + 1) * sy)))
        var x: Int64 = 0
        while (x < nw) {
            let x0 = Int64(Float64(x) * sx)
            let x1 = min(w, max(x0 + 1, Int64(Float64(x + 1) * sx)))
            var r: Int64 = 0
            var g: Int64 = 0
            var b: Int64 = 0
            var a: Int64 = 0
            var n: Int64 = 0
            var yy = y0
            while (yy < y1) {
                var xx = x0
                while (xx < x1) {
                    let p = (yy * w + xx) * 4
                    r += Int64(rgba[p])
                    g += Int64(rgba[p + 1])
                    b += Int64(rgba[p + 2])
                    a += Int64(rgba[p + 3])
                    n += 1
                    xx += 1
                }
                yy += 1
            }
            let d = (y * nw + x) * 4
            out[d] = UInt8(r / n)
            out[d + 1] = UInt8(g / n)
            out[d + 2] = UInt8(b / n)
            out[d + 3] = UInt8(a / n)
            x += 1
        }
        y += 1
    }
    (Int32(nw), Int32(nh), out)
}

// 后台调用：把已下载的原始封面解码、降采样成缩略图后转 BMP
// （先写临时文件再原子改名）。返回是否成功；失败时删除坏原始文件，
// 等待下次重新下载。
func convertCoverOnce(id: UInt64): Bool {
    let raw = coverFilePath(id)
    let finalBmp = coverBmpPath(id)
    let tmpBmp = "${finalBmp}.tmp"
    match (decodeImageFile(raw)) {
        case Some(result) =>
            let (w0, h0, pixels0) = result
            if (w0 <= 0 || h0 <= 0) {
                return false
            }
            // 缩略图：宽 240 足够 4 列卡片清晰显示
            let (w, h, pixels) = downscaleRgba(w0, h0, pixels0, 240)
            if (!writeBmp(tmpBmp, w, h, pixels)) {
                return false
            }
            try {
                rename(Path(tmpBmp), to: Path(finalBmp), overwrite: true)
                return true
            } catch (_: Exception) {
                return false
            }
        case None =>
            // 解码失败可能是下载不完整，删掉坏文件等下次重下
            try {
                remove(Path(raw))
            } catch (_: Exception) {
                ()
            }
            return false
    }
}

// 封面视图：BMP 已就绪且本帧揭示预算允许时显示真图（Cover 裁切），
// 否则首字占位。只做内存查询，保持 UI 线程轻量。
// fillWidth=true 时撑满可用宽度（网格卡片），否则按 width 固定宽（列表行）。
func coverView(app: DesktopApp, state: AppState, id: UInt64, title: String,
    width: Float64, height: Float64, fillWidth!: Bool = false) {
    if (id != UInt64(0) && coverBmpReady(id) && requestCoverReveal(id, state)) {
        ImageView(coverBmpPath(id), fit: ImageFit.Cover,
            preferredWidth: if (fillWidth) { None } else { Some(width.vp) },
            preferredHeight: height.vp)
    } else {
        coverPlaceholder(state, title, width, height, fillWidth: fillWidth)
    }
}

func coverPlaceholder(state: AppState, title: String, width: Float64, height: Float64, fillWidth!: Bool = false) {
    let box = Panel {
        VStack(spacing: 2.0.vp) {
            Spacer()
            Label(coverInitial(title)).bold().fontSize(18.0)
                .foregroundColor(BRAND_COLOR).textAlign(TextAlign.Center)
            Spacer()
        }.fillWidth()
    }.contentPadding(4.0.vp).height(height.vp).background(coverBg(state.themeMode.value), 10.0.vp)
    if (fillWidth) {
        box.fillWidth()
    } else {
        box.width(width.vp)
    }
}
