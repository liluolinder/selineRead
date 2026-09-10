package chui_device_rotation

import chui.*
import chui.kmode.macros.*

@CuiProbe["device-rotation.layout"]
func deviceRotationLayoutProbe(script: String): String {
    ComponentProbe("device-rotation.layout", width: 620.0, height: 340.0).run(script) {
        let rotation = DeviceRotation.LandscapeClockwise
        DeviceRotationLayout(
            rotation: rotation,
            key: "rotation-probe",
            portrait: { => portraitDashboard(rotation) },
            landscape: { => landscapeDashboard(rotation) }
        ).probe("rotation-layout", "DeviceRotationLayout",
            [ProbeProperty("rotation", deviceRotationName(rotation))])
    }
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let app = DesktopApp(
        WindowSpec("CangHui 设备旋转布局", 760, 520, scale: 1.5),
        theme: Theme.dark()
    )
    app.setMinimumSize(520, 420)
    // Deterministic first capture. A real mobile host calls postDeviceRotation from
    // its sensor/orientation callback after it has normalized and debounced posture.
    app.queueDeviceRotation(DeviceRotation.Portrait, source: DeviceRotationSource.Synthetic)
    app.run {
        rotationDemo(app)
    }
    return 0
}

private func rotationDemo(app: DesktopApp): Unit {
    let rotation = app.deviceRotation()
    VStack(spacing: 14.vp) {
        HStack(spacing: 8.vp, flexible: false) {
            VStack(spacing: 3.vp, flexible: false) {
                Label("设备旋转").fontSize(FontSizes.TITLE).bold()
                Label("方向事件 → 整页旋转 → 自适应布局").muted().fontSize(FontSizes.CAPTION)
            }.crossAxisAlignment(CrossAxisAlignment.Start)
            Spacer()
            Button("0°", { =>
                app.queueDeviceRotation(DeviceRotation.Portrait, source: DeviceRotationSource.Synthetic)
            }).height(32.vp)
            Button("+90°", { =>
                app.queueDeviceRotation(DeviceRotation.LandscapeClockwise,
                    source: DeviceRotationSource.Synthetic)
            }).height(32.vp)
            Button("180°", { =>
                app.queueDeviceRotation(DeviceRotation.PortraitUpsideDown,
                    source: DeviceRotationSource.Synthetic)
            }).height(32.vp)
            Button("-90°", { =>
                app.queueDeviceRotation(DeviceRotation.LandscapeCounterClockwise,
                    source: DeviceRotationSource.Synthetic)
            }).height(32.vp)
        }.crossAxisAlignment(CrossAxisAlignment.Center)

        DeviceRotationLayout(
            rotation: rotation,
            key: "rotation-demo",
            portrait: { => portraitDashboard(rotation) },
            landscape: { => landscapeDashboard(rotation) }
        ).probe(
            "rotation-layout",
            "DeviceRotationLayout",
            [ProbeProperty("rotation", deviceRotationName(rotation))]
        ).fillWidth().layoutWeight()
    }.padding(20.vp)
}

private func portraitDashboard(rotation: DeviceRotation): Unit {
    Panel {
        VStack(spacing: 12.vp) {
            postureTitle("竖屏布局", rotation)
            metricCard("本日行程", "3 项")
            metricCard("同步设备", "2 台")
            metricCard("待处理", "7 条")
        }.crossAxisAlignment(CrossAxisAlignment.Stretch)
    }.contentPadding(18.vp)
}

private func landscapeDashboard(rotation: DeviceRotation): Unit {
    HStack(spacing: 12.vp) {
        Panel {
            VStack(spacing: 8.vp) {
                postureTitle("横屏布局", rotation)
                Label("更宽的视口把摘要移到侧栏。").muted().wrap()
            }.crossAxisAlignment(CrossAxisAlignment.Start)
        }.contentPadding(18.vp).layoutWeight()
        VStack(spacing: 12.vp) {
            metricCard("本日行程", "3 项")
            metricCard("同步设备", "2 台")
            metricCard("待处理", "7 条")
        }.crossAxisAlignment(CrossAxisAlignment.Stretch).layoutWeight()
    }
}

private func postureTitle(title: String, rotation: DeviceRotation): Unit {
    Label(title).fontSize(FontSizes.TITLE).bold()
    Label(deviceRotationName(rotation)).muted().fontSize(FontSizes.CAPTION)
}

private func metricCard(label: String, value: String): Unit {
    HStack(spacing: 10.vp, flexible: false) {
        Label(label)
        Spacer()
        Label(value).bold()
    }.padding(14.vp).background(Color.rgba(255, 255, 255, 14), 10.vp)
}
