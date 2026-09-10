package chui.graphics

import std.collection.ArrayList
import sdl.{Color, Rect, Renderer}

/** Prepared SDL upload. Premultiplied input is normalized for SDL's straight-alpha blend mode. */
protected class SdlSharedFrameUpload {
    public let pixels: Array<UInt8>
    public let blend: Bool

    init(pixels: Array<UInt8>, blend: Bool) {
        this.pixels = pixels
        this.blend = blend
    }
}

/**
 * Software shared-frame compositor used by the SDL FrameGraph provider.
 *
 * The texture is transient to the pass and always released before the action returns. The copied
 * provider bytes are never retained by SDL or placed in graph metadata/trace output.
 */
protected func compositeSdlSharedRgbaFrame(
    renderer: Renderer,
    unifiedPixels: Bool,
    pixelWidth: Int64,
    pixelHeight: Int64,
    rowBytes: Int64,
    alphaMode: String,
    pixels: Array<UInt8>,
    destination: Rect,
    cornerRadius!: Float32 = 0.0,
    rotationCode!: String = "unknown"
): FramePassExecutionResult {
    if (!unifiedPixels) {
        return FramePassExecutionResult(false, "shared-frame-not-unified")
    }
    if (renderer.driverName() == "headless") {
        return FramePassExecutionResult(false, "shared-frame-device-unavailable")
    }
    if (!sdlSharedFrameRotationCodeValid(rotationCode)) {
        return FramePassExecutionResult(false, "shared-frame-rotation-invalid")
    }
    let upload = try {
        prepareSdlSharedFrameUpload(pixelWidth, pixelHeight, rowBytes, alphaMode, pixels)
    } catch (_: Exception) {
        return FramePassExecutionResult(false, "shared-frame-upload-invalid")
    }
    try {
        try (texture = renderer.createStreamingRgbaTexture(
            Int32(pixelWidth), Int32(pixelHeight))) {
            texture.updateRgba(upload.pixels, Int32(rowBytes))
            texture.setAlphaBlending(upload.blend)
            if (cornerRadius > 0.0) {
                renderer.texturedRoundedRect(texture, destination, cornerRadius)
            } else {
                renderer.texture(texture, destination)
            }
        }
        FramePassExecutionResult(true, "accepted-shared-frame-upload")
    } catch (_: Exception) {
        FramePassExecutionResult(false, "shared-frame-upload-failed")
    }
}

/**
 * Deterministic software reference for the recording-headless SDL target.
 *
 * This target proves composition ordering, clipping, rounded masking, scaling and alpha math
 * without a native window. It never calls `present`, never enters the live widget path, and cannot
 * prove native zero-copy, HDR/EDR or a `Presented` release. `rotationCode` identifies the
 * provider-target layout; provider pixels are already in that layout and are not rotated again.
 */
protected class SdlSharedFrameHeadlessTarget {
    public let width: Int64
    public let height: Int64
    private let bytes: Array<UInt8>

    public init(width: Int64, height: Int64, clear!: Color = Color.rgba(0, 0, 0, 0)) {
        if (width <= 0 || height <= 0 || width > Int64.Max / height ||
            width * height > Int64(1048576)) {
            throw IllegalArgumentException("headless shared-frame target geometry is invalid")
        }
        this.width = width
        this.height = height
        let pixels = ArrayList<UInt8>()
        for (_ in 0..(width * height)) {
            pixels.add(clear.r)
            pixels.add(clear.g)
            pixels.add(clear.b)
            pixels.add(clear.a)
        }
        this.bytes = pixels.toArray()
    }

    public func clear(color: Color): Unit {
        for (y in 0..height) {
            for (x in 0..width) { writePixel(x, y, color) }
        }
    }

    public func pixel(x: Int64, y: Int64): Color {
        ensurePoint(x, y)
        let offset = (y * width + x) * 4
        Color(bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }

    /** Paints an ordinary later/earlier sibling into the same software target and Draw IR order. */
    public func fill(renderer: Renderer, rect: Rect, color: Color, scope: String): Unit {
        if (renderer.driverName() != "headless" || !renderer.drawIrEnabled() || scope.isEmpty()) {
            throw IllegalArgumentException("headless shared-frame fill requires recording SDL target")
        }
        renderer.pushDrawIrScope(scope)
        renderer.fill(rect, color)
        renderer.popDrawIrScope()
        for (y in 0..height) {
            for (x in 0..width) {
                let px = Float32(x) + 0.5
                let py = Float32(y) + 0.5
                if (rect.contains(px, py) && pointInsideActiveClip(renderer, px, py)) {
                    blend(x, y, color, true)
                }
            }
        }
    }

    public func composite(
        renderer: Renderer,
        pixelWidth: Int64,
        pixelHeight: Int64,
        rowBytes: Int64,
        alphaMode: String,
        pixels: Array<UInt8>,
        destination: Rect,
        cornerRadius!: Float32 = 0.0,
        rotationCode!: String = "unknown"
    ): FramePassExecutionResult {
        if (renderer.driverName() != "headless" || !renderer.drawIrEnabled()) {
            return FramePassExecutionResult(false, "shared-frame-headless-target-required")
        }
        if (!sdlSharedFrameRotationCodeValid(rotationCode)) {
            return FramePassExecutionResult(false, "shared-frame-rotation-invalid")
        }
        if (destination.w <= 0.0 || destination.h <= 0.0 || cornerRadius < 0.0) {
            return FramePassExecutionResult(false, "shared-frame-destination-invalid")
        }
        let upload = try {
            prepareSdlSharedFrameUpload(pixelWidth, pixelHeight, rowBytes, alphaMode, pixels)
        } catch (_: Exception) {
            return FramePassExecutionResult(false, "shared-frame-upload-invalid")
        }

        var samples: Int64 = 0
        renderer.pushDrawIrScope("scene3d-shared:${rotationCode}")
        try {
            for (y in 0..height) {
                for (x in 0..width) {
                    let px = Float32(x) + 0.5
                    let py = Float32(y) + 0.5
                    if (!pointInsideRounded(destination, cornerRadius, px, py) ||
                        !pointInsideActiveClip(renderer, px, py)) {
                        continue
                    }
                    let sourceX = min(pixelWidth - 1,
                        Int64((px - destination.x) / destination.w * Float32(pixelWidth)))
                    let sourceY = min(pixelHeight - 1,
                        Int64((py - destination.y) / destination.h * Float32(pixelHeight)))
                    if (sourceX < 0 || sourceY < 0) { continue }
                    let offset = sourceY * rowBytes + sourceX * 4
                    let color = Color(
                        upload.pixels[offset],
                        upload.pixels[offset + 1],
                        upload.pixels[offset + 2],
                        if (upload.blend) { upload.pixels[offset + 3] } else { UInt8(255) })
                    blend(x, y, color, upload.blend)
                    // Per-sample commands keep Draw IR exact; the target is capped at 1M pixels.
                    renderer.fill(Rect(Float32(x), Float32(y), 1.0, 1.0), color)
                    samples += 1
                }
            }
        } finally {
            renderer.popDrawIrScope()
        }
        if (samples <= 0) {
            FramePassExecutionResult(false, "shared-frame-fully-occluded")
        } else {
            FramePassExecutionResult(true, "accepted-headless-conformance-sample")
        }
    }

    private func ensurePoint(x: Int64, y: Int64): Unit {
        if (x < 0 || y < 0 || x >= width || y >= height) {
            throw IllegalArgumentException("headless shared-frame pixel is outside target")
        }
    }

    private func writePixel(x: Int64, y: Int64, color: Color): Unit {
        let offset = (y * width + x) * 4
        bytes[offset] = color.r
        bytes[offset + 1] = color.g
        bytes[offset + 2] = color.b
        bytes[offset + 3] = color.a
    }

    private func blend(x: Int64, y: Int64, source: Color, enabled: Bool): Unit {
        if (!enabled || source.a == UInt8(255)) {
            writePixel(x, y, Color(source.r, source.g, source.b, UInt8(255)))
            return
        }
        let destination = pixel(x, y)
        let sourceAlpha = Int64(source.a)
        let destinationAlpha = Int64(destination.a)
        let inverse = Int64(255) - sourceAlpha
        let outAlpha = sourceAlpha + (destinationAlpha * inverse + 127) / 255
        if (outAlpha <= 0) {
            writePixel(x, y, Color.rgba(0, 0, 0, 0))
            return
        }
        writePixel(x, y, Color.rgba(
            straightSourceOverChannel(source.r, sourceAlpha, destination.r, destinationAlpha, inverse, outAlpha),
            straightSourceOverChannel(source.g, sourceAlpha, destination.g, destinationAlpha, inverse, outAlpha),
            straightSourceOverChannel(source.b, sourceAlpha, destination.b, destinationAlpha, inverse, outAlpha),
            outAlpha))
    }
}

private func straightSourceOverChannel(
    source: UInt8,
    sourceAlpha: Int64,
    destination: UInt8,
    destinationAlpha: Int64,
    inverse: Int64,
    outAlpha: Int64
): Int64 {
    let destinationTerm = (Int64(destination) * destinationAlpha * inverse + 127) / 255
    (Int64(source) * sourceAlpha + destinationTerm + outAlpha / 2) / outAlpha
}

private func pointInsideActiveClip(renderer: Renderer, x: Float32, y: Float32): Bool {
    match (renderer.currentClip()) {
        case Some(rect) => rect.w > 0.0 && rect.h > 0.0 && rect.contains(x, y)
        case None => true
    }
}

private func pointInsideRounded(rect: Rect, radius: Float32, x: Float32, y: Float32): Bool {
    if (!rect.contains(x, y)) { return false }
    let r = min(max(0.0, radius), min(rect.w, rect.h) / 2.0)
    if (r <= 0.0) { return true }
    let left = rect.x + r
    let right = rect.right() - r
    let top = rect.y + r
    let bottom = rect.bottom() - r
    var dx: Float32 = 0.0
    var dy: Float32 = 0.0
    if (x < left) { dx = x - left }
    else if (x > right) { dx = x - right }
    if (y < top) { dy = y - top }
    else if (y > bottom) { dy = y - bottom }
    dx * dx + dy * dy <= r * r
}

private func sdlSharedFrameRotationCodeValid(value: String): Bool {
    value == "unknown" || value == "portrait" || value == "landscape-clockwise" ||
        value == "portrait-upside-down" || value == "landscape-counter-clockwise"
}

protected func prepareSdlSharedFrameUpload(
    pixelWidth: Int64,
    pixelHeight: Int64,
    rowBytes: Int64,
    alphaMode: String,
    pixels: Array<UInt8>
): SdlSharedFrameUpload {
    if (pixelWidth <= 0 || pixelHeight <= 0 || pixelWidth > Int64(Int32.Max) ||
        pixelHeight > Int64(Int32.Max) || pixelWidth > Int64.Max / 4 ||
        rowBytes <= 0 || rowBytes > Int64(Int32.Max)) {
        throw IllegalArgumentException("SDL shared-frame upload geometry is invalid")
    }
    if (rowBytes < pixelWidth * 4 || pixelHeight > Int64.Max / rowBytes ||
        pixels.size != pixelHeight * rowBytes) {
        throw IllegalArgumentException("SDL shared-frame upload row stride is invalid")
    }
    if (alphaMode == "opaque") {
        return SdlSharedFrameUpload(pixels, false)
    }
    if (alphaMode != "premultiplied") {
        throw IllegalArgumentException("SDL shared-frame alpha mode is unsupported")
    }

    let straight = pixels.clone()
    for (y in 0..pixelHeight) {
        let row = y * rowBytes
        for (x in 0..pixelWidth) {
            let offset = row + x * 4
            let alpha = Int64(straight[offset + 3])
            if (alpha == 0) {
                straight[offset] = UInt8(0)
                straight[offset + 1] = UInt8(0)
                straight[offset + 2] = UInt8(0)
            } else {
                straight[offset] = unpremultiplySdlSharedFrameChannel(straight[offset], alpha)
                straight[offset + 1] = unpremultiplySdlSharedFrameChannel(straight[offset + 1], alpha)
                straight[offset + 2] = unpremultiplySdlSharedFrameChannel(straight[offset + 2], alpha)
            }
        }
    }
    SdlSharedFrameUpload(straight, true)
}

private func unpremultiplySdlSharedFrameChannel(value: UInt8, alpha: Int64): UInt8 {
    UInt8(min(Int64(255), (Int64(value) * 255 + alpha / 2) / alpha))
}
