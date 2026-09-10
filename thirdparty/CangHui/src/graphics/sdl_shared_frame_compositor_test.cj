package chui.graphics

import sdl.{Color, DrawIrCommand, Rect, Renderer}

@Test
func sdlSharedFrameUploadPreservesOpaquePixelsAndUnpremultipliesAlpha(): Unit {
    let opaque = [UInt8(1), UInt8(2), UInt8(3), UInt8(255)]
    let unchanged = prepareSdlSharedFrameUpload(1, 1, 4, "opaque", opaque)
    @Expect(!unchanged.blend)
    @Expect(unchanged.pixels, opaque)

    let premultiplied = [UInt8(64), UInt8(32), UInt8(0), UInt8(128)]
    let straight = prepareSdlSharedFrameUpload(
        1, 1, 4, "premultiplied", premultiplied)
    @Expect(straight.blend)
    @Expect(straight.pixels[0], UInt8(128))
    @Expect(straight.pixels[1], UInt8(64))
    @Expect(straight.pixels[2], UInt8(0))
    @Expect(straight.pixels[3], UInt8(128))
    @Expect(premultiplied[0], UInt8(64))
}

@Test
func sdlSharedFrameUploadRejectsUnknownAlphaAndMismatchedRows(): Unit {
    var alphaRejected = false
    try {
        let _ = prepareSdlSharedFrameUpload(
            1, 1, 4, "straight", [UInt8(0), UInt8(0), UInt8(0), UInt8(0)])
    } catch (_: IllegalArgumentException) {
        alphaRejected = true
    }
    @Expect(alphaRejected)

    var rowsRejected = false
    try {
        let _ = prepareSdlSharedFrameUpload(
            2, 2, 8, "opaque", [UInt8(0), UInt8(0), UInt8(0), UInt8(0)])
    } catch (_: IllegalArgumentException) {
        rowsRejected = true
    }
    @Expect(rowsRejected)
}

@Test
func sdlSharedFrameHeadlessMatrixProvesSiblingOverlayClipRoundedOcclusionAndResize(): Unit {
    let renderer = Renderer.recordingHeadless()
    let target = SdlSharedFrameHeadlessTarget(12, 10, clear: Color.rgb(1, 2, 3))
    let source: Array<UInt8> = [
        UInt8(220), UInt8(20), UInt8(30), UInt8(255),
        UInt8(20), UInt8(210), UInt8(40), UInt8(255),
        UInt8(30), UInt8(40), UInt8(200), UInt8(255),
        UInt8(230), UInt8(210), UInt8(30), UInt8(255)
    ]

    renderer.beginScene(12.0, 10.0, Color.rgb(1, 2, 3))
    target.fill(renderer, Rect(0.0, 0.0, 12.0, 10.0), Color.rgb(10, 10, 10), "sibling.before")
    renderer.pushClip(Rect(1.0, 1.0, 7.0, 6.0))
    let composed = target.composite(
        renderer, 2, 2, 8, "opaque", source, Rect(1.0, 1.0, 8.0, 6.0),
        cornerRadius: 2.0, rotationCode: "portrait")
    renderer.popClip()
    target.fill(renderer, Rect(4.0, 3.0, 3.0, 2.0), Color.rgb(240, 100, 20), "overlay")
    target.fill(renderer, Rect(6.0, 2.0, 2.0, 3.0), Color.rgb(20, 180, 230), "sibling.after")
    renderer.endScene()

    @Expect(composed.ok)
    @Expect(composed.code, "accepted-headless-conformance-sample")
    expectHeadlessPixel(target, 0, 0, 10, 10, 10, 255) // outside ancestor clip
    expectHeadlessPixel(target, 1, 1, 10, 10, 10, 255) // removed by rounded corner
    expectHeadlessPixel(target, 2, 2, 220, 20, 30, 255) // sampled shared frame
    expectHeadlessPixel(target, 5, 3, 240, 100, 20, 255) // overlay occludes shared frame
    expectHeadlessPixel(target, 6, 3, 20, 180, 230, 255) // later sibling occludes overlay
    expectHeadlessPixel(target, 8, 3, 10, 10, 10, 255) // destination clipped by ancestor

    let commands = renderer.drawIr()
    let before = firstHeadlessScope(commands, "sibling.before")
    let shared = firstHeadlessScope(commands, "scene3d-shared:portrait")
    let overlay = firstHeadlessScope(commands, "overlay")
    let after = firstHeadlessScope(commands, "sibling.after")
    @Expect(before >= 0)
    @Expect(shared > before)
    @Expect(overlay > shared)
    @Expect(after > overlay)

    // The same target is cleared and reused at a smaller destination. Pixels outside the new
    // bounds stay clear, so resize is proven by the software target rather than receipt wording.
    target.clear(Color.rgb(3, 4, 5))
    renderer.clearDrawIr()
    let resized = target.composite(
        renderer, 2, 2, 8, "opaque", source, Rect(2.0, 2.0, 4.0, 3.0),
        rotationCode: "landscape-clockwise")
    @Expect(resized.ok)
    expectHeadlessPixel(target, 1, 2, 3, 4, 5, 255)
    expectHeadlessPixel(target, 2, 2, 220, 20, 30, 255)
    @Expect(firstHeadlessScope(renderer.drawIr(), "scene3d-shared:landscape-clockwise") >= 0)

    renderer.pushClip(Rect(20.0, 20.0, 1.0, 1.0))
    let hidden = target.composite(
        renderer, 2, 2, 8, "opaque", source, Rect(2.0, 2.0, 4.0, 3.0),
        rotationCode: "landscape-clockwise")
    renderer.popClip()
    @Expect(!hidden.ok)
    @Expect(hidden.code, "shared-frame-fully-occluded")
}

@Test
func sdlSharedFrameHeadlessMatrixKeepsProviderReadyPixelsAcrossSignedRotationLayouts(): Unit {
    let renderer = Renderer.recordingHeadless()
    let target = SdlSharedFrameHeadlessTarget(8, 8, clear: Color.rgb(0, 0, 0))
    let source: Array<UInt8> = [UInt8(90), UInt8(120), UInt8(150), UInt8(255)]

    // Device posture changes rebuild layout before acquisition. These four cases correspond to
    // +90, +180, -90 and -180 transitions; the provider-ready pixel remains upright because the
    // shared-frame compositor must not rotate a freshly rendered target-layout frame twice.
    expectHeadlessRotationLayout(target, renderer, source, "landscape-clockwise", Rect(1.0, 1.0, 6.0, 4.0))
    expectHeadlessRotationLayout(target, renderer, source, "portrait-upside-down", Rect(1.0, 1.0, 4.0, 6.0))
    expectHeadlessRotationLayout(target, renderer, source, "landscape-counter-clockwise", Rect(1.0, 1.0, 6.0, 4.0))
    expectHeadlessRotationLayout(target, renderer, source, "portrait", Rect(1.0, 1.0, 4.0, 6.0))
}

@Test
func sdlSharedFrameHeadlessReferenceBlendsPremultipliedSdrWithoutPresentationClaim(): Unit {
    let renderer = Renderer.recordingHeadless()
    let target = SdlSharedFrameHeadlessTarget(1, 1, clear: Color.rgb(255, 255, 255))
    let result = target.composite(
        renderer,
        1,
        1,
        4,
        "premultiplied",
        [UInt8(128), UInt8(0), UInt8(0), UInt8(128)],
        Rect(0.0, 0.0, 1.0, 1.0),
        rotationCode: "portrait")
    @Expect(result.ok)
    @Expect(result.code, "accepted-headless-conformance-sample")
    expectHeadlessPixel(target, 0, 0, 255, 127, 127, 255)
    @Expect(!result.code.contains("presented"))
}

private func expectHeadlessRotationLayout(
    target: SdlSharedFrameHeadlessTarget,
    renderer: Renderer,
    source: Array<UInt8>,
    rotationCode: String,
    destination: Rect
): Unit {
    target.clear(Color.rgb(0, 0, 0))
    renderer.clearDrawIr()
    let result = target.composite(
        renderer, 1, 1, 4, "opaque", source, destination, rotationCode: rotationCode)
    @Expect(result.ok)
    @Expect(firstHeadlessScope(renderer.drawIr(), "scene3d-shared:${rotationCode}") >= 0)
    expectHeadlessPixel(target, Int64(destination.x), Int64(destination.y), 90, 120, 150, 255)
    expectHeadlessPixel(target, 0, 0, 0, 0, 0, 255)
}

private func firstHeadlessScope(commands: Array<DrawIrCommand>, scope: String): Int64 {
    for (i in 0..commands.size) {
        if (commands[i].scope == scope) { return i }
    }
    -1
}

private func expectHeadlessPixel(
    target: SdlSharedFrameHeadlessTarget,
    x: Int64,
    y: Int64,
    r: Int64,
    g: Int64,
    b: Int64,
    a: Int64
): Unit {
    let pixel = target.pixel(x, y)
    @Expect(Int64(pixel.r), r)
    @Expect(Int64(pixel.g), g)
    @Expect(Int64(pixel.b), b)
    @Expect(Int64(pixel.a), a)
}
