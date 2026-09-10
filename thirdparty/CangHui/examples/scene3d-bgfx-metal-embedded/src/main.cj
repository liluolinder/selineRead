package canghui_scene3d_bgfx_metal_embedded

import canghui_scene3d_bgfx.*
import chui.*
import std.fs.{exists, removeIfExists}

private class EmbeddedProofFrames <: Scene3DViewFrameSource {
    private let requestClose: () -> Unit
    private let driver: Bgfx4cjDriver
    private let capture: ?DesktopCaptureRequest
    private var frames: Int64 = 0
    private var captureRequested = false

    init(requestClose: () -> Unit, driver: Bgfx4cjDriver, capture: ?DesktopCaptureRequest) {
        this.requestClose = requestClose
        this.driver = driver
        this.capture = capture
    }

    public func snapshot(clock: Scene3DFrameClock): Scene3DFrameSnapshot {
        frames += 1
        if (!captureRequested && frames >= 12) {
            match (capture) {
                case Some(request) =>
                    let result = driver.requestBackbufferCapture(request.path + ".embedded")
                    print("nativeCapture=${result.code}\n", flush: true)
                    captureRequested = result.ok
                case None => ()
            }
        }
        if (capture.isNone() && frames >= 300) { requestClose() }
        let camera = Scene3DCameraSnapshot(7.4, 6.2, 9.1, 0.1, -0.7, 0.0, fieldOfViewY: 48.0)
        let snapshot = Scene3DFrameSnapshot("embedded-metal-${clock.frameId}", camera: Some(camera))
        snapshot.add(Scene3DEntitySnapshot("floor", 0.0, -1.2, 0.0, kind: Scene3DEntityKind.Floor,
            scaleX: 3.2, scaleY: 0.16, scaleZ: 2.5, rotationY: 0.08))
        snapshot.add(Scene3DEntitySnapshot("route", 0.0, -0.92, 0.25, kind: Scene3DEntityKind.Route,
            scaleX: 2.3, scaleY: 0.10, scaleZ: 0.18, rotationY: -0.20))
        snapshot.add(Scene3DEntitySnapshot("vehicle", -0.9, -0.62, 0.15, kind: Scene3DEntityKind.Vehicle))
        snapshot.add(Scene3DEntitySnapshot("user", 1.0, -0.38, -0.1, kind: Scene3DEntityKind.UserMarker))
        snapshot
    }
}

main(): Int64 {
    let capture = DesktopCaptureRequest.fromEnvironment()
    let app = DesktopApp(WindowSpec("CangHui Embedded Scene3DView", 900, 600, scale: 1.0),
        theme: Theme.dark())
    let initial = Scene3DViewPlacement("embedded-scene", 18.0, 94.0, 620.0, 470.0, 1.0)
    let host = app.withBorrowedPlatformWindow {
        window => MacOSEmbeddedMetalHost(window, initial, identity: UInt64(20260825))
    }
    let driver = Bgfx4cjDriver(host.nativeLayerPointer(), host.surfaceIdentity(), clearColor: 0x162A35FF)
    let provider: Scene3DProvider = DriverScene3DProvider(driver)
    let controller = Scene3DViewController("embedded-scene", host, provider,
        Scene3DResource("embedded-debug", "memory://embedded-debug", "sha256:embedded-debug", 0),
        EmbeddedProofFrames({ => app.requestWindowClose() }, driver, capture))
    app.manage(host)

    print("presentation=embedded-surface childAttached=${host.isChildAttached()}\n",
        flush: true)
    print("attach=${controller.lifecycleReceipt().code} renderer=Metal\n", flush: true)
    app.run {
        VStack {
            HStack {
                VStack {
                    Label("CangHui Scene3DView").fontSize(24.fp).bold()
                    Label("同一窗口 · CAMetalLayer 子表面 · 聚焦后接收手柄", muted: true)
                }.spacing(3.vp).hug()
                Spacer()
                Badge("METAL", kind: BadgeKind.Success)
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            HStack {
                Scene3DView(controller, width: 620.0, height: 470.0)
                Panel(flexible: false) {
                    VStack {
                        Label("Native surface").fontSize(18.fp).bold()
                        Label("EmbeddedSurface", muted: true)
                        Divider()
                        Label("输入归属", muted: true)
                        Label("点击场景取得焦点")
                        Label("手柄轴与按钮按位置语义路由").muted().maxLines(3)
                        Spacer()
                        Label("CangHui Multiplatform", muted: true).fontSize(FontSizes.CAPTION)
                    }.spacing(10.vp)
                }.contentPadding(16.vp).width(226.0).height(470.0)
            }.spacing(16.vp).hug()
        }.spacing(14.vp).padding(18.vp)
    }
    print("detach=${controller.lifecycleReceipt().code}\n", flush: true)
    match (capture) {
        case Some(request) =>
            let tga = request.path + ".embedded.tga"
            if (!exists(tga)) {
                print("nativeCapture=missing\n", flush: true)
                return 20
            }
            convertBgfxTgaToBmp(tga, request.path + ".native.bmp")
            removeIfExists(tga)
            print("nativeCapture=ready\n", flush: true)
        case None => ()
    }
    0
}
