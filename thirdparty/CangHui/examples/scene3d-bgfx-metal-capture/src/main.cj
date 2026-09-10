package canghui_scene3d_bgfx_metal_capture

import canghui_scene3d_bgfx.*
import chui.desktop.DesktopCaptureRequest
import chui.scene3d.*
import std.fs.{exists, removeIfExists}

main(): Int64 {
    let capture = match (DesktopCaptureRequest.fromEnvironment()) {
        case Some(request) => request
        case None => throw IllegalStateException("run this example through cuic prnt")
    }
    let tgaBase = capture.path + ".bgfx"
    let tgaPath = tgaBase + ".tga"
    removeIfExists(tgaPath)
    let host = MacOSSdlMetalHost("CangHui Scene3D Metal", 640, 420, identity: UInt64(20260819))
    let surface = host.surface("scene3d-bgfx-metal")
    let driver = Bgfx4cjDriver(host.nativeWindowPointer(), host.identity, clearColor: 0x3A8068FF)
    let provider: Scene3DProvider = DriverScene3DProvider(driver)
    try {
        let attach = provider.attach(surface, clock(0))
        println("attach=${attach.code}")
        if (!attach.ok) { return 10 }

        let load = provider.loadScene(Scene3DResource(
            "metal-debug-cube", "memory://metal-debug-cube", "sha256:embedded-debug-cube", 0
        ))
        println("load=${load.code}")
        if (!load.ok) { return 11 }

        let camera = Scene3DCameraSnapshot(
            7.4, 6.2, 9.1,
            0.1, -0.7, 0.0,
            fieldOfViewY: 48.0
        )
        let snapshot = Scene3DFrameSnapshot("metal-semantic-debug-scene", camera: Some(camera))
        snapshot.add(Scene3DEntitySnapshot(
            "floor", 0.0, -1.2, 0.0, kind: Scene3DEntityKind.Floor,
            scaleX: 3.2, scaleY: 0.16, scaleZ: 2.5, rotationY: 0.08
        ))
        snapshot.add(Scene3DEntitySnapshot(
            "route", 0.0, -0.92, 0.25, kind: Scene3DEntityKind.Route,
            scaleX: 2.3, scaleY: 0.10, scaleZ: 0.18, rotationY: -0.20
        ))
        snapshot.add(Scene3DEntitySnapshot(
            "vehicle", -0.9, -0.62, 0.15, kind: Scene3DEntityKind.Vehicle
        ))
        snapshot.add(Scene3DEntitySnapshot(
            "user", 1.0, -0.38, -0.1, kind: Scene3DEntityKind.UserMarker
        ))
        snapshot.add(Scene3DEntitySnapshot(
            "hidden-sentinel", 0.0, 2.0, 0.0,
            visible: false, kind: Scene3DEntityKind.UserMarker
        ))
        println("camera=non-default transform=non-default")
        var captureRequested = false
        var captured = false
        let totalFrames = capture.settleFrames + UInt64(24)
        var frame: UInt64 = UInt64(1)
        while (frame <= totalFrames) {
            host.pump()
            let currentClock = clock(Int64(frame))
            let submit = provider.submit(snapshot, currentClock)
            let present = provider.present(currentClock)
            if (frame == UInt64(1)) {
                println("submit=${submit.code} detail=${submit.detail} present=${present.code}")
            }
            if (!submit.ok || !present.ok) { return 12 }
            if (!captureRequested && frame >= capture.settleFrames) {
                let request = driver.requestBackbufferCapture(tgaBase)
                println("capture=${request.code}")
                if (!request.ok) { return 13 }
                captureRequested = true
            }
            if (captureRequested && exists(tgaPath)) {
                convertBgfxTgaToBmp(tgaPath, capture.path)
                captured = true
                break
            }
            host.delay(UInt32(16))
            frame += UInt64(1)
        }
        if (!captured) {
            println("capture=missing")
            return 14
        }
        println("renderer=Metal frames=${frame} size=${surface.pixelWidth}x${surface.pixelHeight}")
        removeIfExists(tgaPath)
        0
    } finally {
        let detach = provider.detach(surface.id, surface.generation)
        println("detach=${detach.code}")
        host.close()
    }
}

private func clock(frame: Int64): Scene3DFrameClock {
    let timestamp = frame * 16666667
    Scene3DFrameClock(frame, timestamp, timestamp + 16666667)
}
