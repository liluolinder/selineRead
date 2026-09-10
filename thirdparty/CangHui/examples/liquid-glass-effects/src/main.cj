package chui_liquid_glass_effects

import chui.*
import canghui_style_liquid_glass.*

private let FRAME_GRAPH_ACCEPTANCE_STEPS: Int64 = 18

private class FrameGraphAcceptanceModel {
    let phase = State<Int64>(0)
    let animating = State<Bool>(true)
    let sceneVisible = State<Bool>(true)
    let dark = State<Bool>(false)
    let reducedTransparency = State<Bool>(false)

    func tick(controller: Scene3DViewController): Unit {
        if (!animating.value) { return }
        phase.value += 1
        if (phase.value >= FRAME_GRAPH_ACCEPTANCE_STEPS) {
            animating.value = false
            // End the simulated host placement before the widget leaves the tree. Later
            // observation-only frames then prove that the complete stable UI pass can be culled.
            let _ = controller.remove()
            sceneVisible.value = false
        }
    }

    func restart(): Unit {
        phase.value = 0
        sceneVisible.value = true
        animating.value = true
    }

    func preferences(): LiquidGlassPreferences {
        LiquidGlassPreferences(reduceTransparency: reducedTransparency.value)
    }
}

private class FrameGraphAcceptanceSceneFrames <: Scene3DViewFrameSource {
    public func snapshot(clock: Scene3DFrameClock): Scene3DFrameSnapshot {
        Scene3DFrameSnapshot("framegraph-acceptance-${clock.frameId}")
    }
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let model = FrameGraphAcceptanceModel()
    let controller = frameGraphAcceptanceSceneController()
    let app = DesktopApp(
        WindowSpec("CangHui FrameGraph · Liquid Glass", 920, 600, scale: 1.0),
        theme: frameGraphAcceptanceTheme(model)
    )
    app.setMinimumSize(760, 520)
    app.run {
        if (model.animating.value || model.sceneVisible.value) {
            FrameHandler(onFrame: {_ => model.tick(controller)}) {
                effectGallery(model, Some(app), controller)
            }
        }
        if (!model.animating.value && !model.sceneVisible.value) {
            effectGallery(model, Some(app), controller)
        }
    }
    0
}

func effectGallery(): Unit {
    effectGallery(
        FrameGraphAcceptanceModel(),
        None<DesktopApp>,
        frameGraphAcceptanceSceneController())
}

private func effectGallery(
    model: FrameGraphAcceptanceModel,
    app: ?DesktopApp,
    controller: Scene3DViewController
): Unit {
    ZStack {
        backdropMosaic()
        VStack {
            acceptanceToolbar(model, app)
            HStack {
                Spacer().width(frameGraphMotionOffset(model))
                morphingGlassCard(model)
                Spacer()
                if (model.sceneVisible.value) {
                    sceneSharedFrameCard(controller)
                } else {
                    settledSceneCard()
                }
            }.spacing(16.vp).hug().fillWidth()
            stableSibling(model)
        }.spacing(18.vp).padding(28.vp).fillWidth().fillHeight()
    }.fillWidth().fillHeight()
}

private func acceptanceToolbar(model: FrameGraphAcceptanceModel, app: ?DesktopApp): Unit {
    HStack {
        VStack {
            Label("Unified FrameGraph rev1").fontSize(FontSizes.TITLE).bold()
            Label("Liquid Glass deformation · shared Scene3D pixels · deterministic idle cull")
                .muted().fontSize(FontSizes.CAPTION)
        }.spacing(3.vp).hug()
        Spacer()
        IconButton(IconName.Refresh) { model.restart() }.width(36.vp).height(36.vp)
        IconButton(if (model.dark.value) { IconName.Sun } else { IconName.Moon }) {
            model.dark.value = !model.dark.value
            applyFrameGraphAcceptanceTheme(model, app)
        }.width(36.vp).height(36.vp)
        Button(if (model.reducedTransparency.value) { "Opaque" } else { "Glass" }, { =>
            model.reducedTransparency.value = !model.reducedTransparency.value
            applyFrameGraphAcceptanceTheme(model, app)
        }).height(36.vp)
        Button("Rotate +90°", { =>
            match (app) {
                case Some(value) => value.queueDeviceRotation(
                    DeviceRotation.LandscapeClockwise,
                    source: DeviceRotationSource.Synthetic)
                case None => ()
            }
        }).height(36.vp)
    }.spacing(8.vp).padding(12.vp).background(Color.rgba(255, 255, 255, 166), 18.0)
        .fillWidth().height(64.vp)
}

private func morphingGlassCard(model: FrameGraphAcceptanceModel): Unit {
    let radius = 20.0 + Float32(model.phase.value % 7) * 2.0
    let width = 292.0 + Float32(model.phase.value % 9) * 7.0
    let preferences = model.preferences()
    let spec = LiquidGlassSpec(
        variant: LiquidGlassVariant.Clear,
        radius: radius,
        preferences: preferences,
        optics: LiquidGlassOptics(
            clarity: 0.94,
            haze: 0.38,
            edgeEnergy: 0.96,
            deformation: 0.94))
    Surface(
        shape: Shape.rounded(radius),
        material: LiquidGlass.material(spec: spec),
        painter: Some(LiquidGlass.surfacePainter(spec: spec)),
        clip: ClipPolicy.Shape
    ) {
        VStack {
            HStack {
                Badge("UI 2D", kind: BadgeKind.Success)
                Spacer()
                Label("phase ${model.phase.value}").muted().fontSize(FontSizes.CAPTION)
            }.hug().fillWidth()
            Label("Moving + reshaping glass").fontSize(FontSizes.TITLE).bold()
            Label("The card changes geometry for 18 frames, then becomes stable so trace replay can prove culling.")
                .wrap().muted().maxLines(3)
            Spacer()
            HStack {
                Icon(IconName.Refresh, size: 18.vp)
                Label(if (preferences.reduceTransparency) {
                    "deterministic opaque fallback"
                } else {
                    "bounded SDL backdrop request"
                }).fontSize(FontSizes.CAPTION)
            }.spacing(8.vp).hug()
        }.spacing(10.vp).padding(20.vp).width(width).height(210.vp)
    }
}

private func sceneSharedFrameCard(controller: Scene3DViewController): Unit {
    VStack {
        HStack {
            Label("Simulated Scene3D resource").bold()
            Spacer()
            Badge("SHARED", kind: BadgeKind.Success)
        }.hug().fillWidth()
        Scene3DView(controller, width: 268.0, height: 116.0)
        Label("CPU RGBA8 lease · ordinary CangHui clip/z-order")
            .fontSize(FontSizes.CAPTION).muted()
    }.spacing(10.vp).padding(16.vp).width(300.vp).height(210.vp)
        .background(Color.rgba(18, 26, 40, 212), 22.0)
}

private func settledSceneCard(): Unit {
    VStack {
        HStack {
            Label("Scene3D composition receipt").bold()
            Spacer()
            Badge("CAPTURED", kind: BadgeKind.Success)
        }.hug().fillWidth()
        Spacer()
        Icon(IconName.Process, size: 34.vp)
        Label("Shared-frame lifecycle observed").fontSize(FontSizes.TITLE).bold()
        Label("Fake CPU provider only; native texture/fence interop remains a field gate.")
            .muted().fontSize(FontSizes.CAPTION)
        Spacer()
    }.spacing(8.vp).padding(16.vp).width(300.vp).height(210.vp)
        .background(Color.rgba(18, 26, 40, 212), 22.0)
}

private func stableSibling(model: FrameGraphAcceptanceModel): Unit {
    HStack {
        VStack {
            Label("STABLE ROOT SENTINEL").fontSize(FontSizes.CAPTION).bold()
            Label("Whole-root idle after phase ${min(model.phase.value, FRAME_GRAPH_ACCEPTANCE_STEPS)}")
                .muted().fontSize(FontSizes.CAPTION)
        }.spacing(2.vp).hug()
        Spacer()
        Label("redraw: full/bounded/idle-cull · SDL present: full/none").fontSize(FontSizes.CAPTION)
        Badge(if (model.animating.value) { "CHANGING" } else { "CULLABLE" },
            kind: if (model.animating.value) { BadgeKind.Warning } else { BadgeKind.Success })
    }.spacing(12.vp).padding(14.vp).background(Color.rgba(255, 255, 255, 176), 18.0)
        .fillWidth().height(58.vp)
}

private func backdropMosaic(): Unit {
    VStack {
        colorBand(Color.rgb(255, 91, 110), Color.rgb(255, 190, 92), "CURRENT FRAME")
        colorBand(Color.rgb(91, 206, 250), Color.rgb(82, 107, 246), "DAMAGE PROPAGATION")
        colorBand(Color.rgb(121, 84, 246), Color.rgb(230, 93, 184), "FULL PRESENT TRUTH")
    }.spacing(0.vp).fillWidth().fillHeight()
}

private func colorBand(start: Color, end: Color, title: String): Unit {
    HStack {
        Label(title).foregroundColor(Color.rgba(255, 255, 255, 178)).fontSize(FontSizes.DISPLAY).bold()
        Spacer()
        Label("CangHui").foregroundColor(Color.rgba(255, 255, 255, 116)).fontSize(48.0).bold()
    }.padding(34.vp).fillWidth().fillHeight().gradientBackground(
        Gradient(start: start, end: end, vertical: false),
        0.0
    )
}

private func frameGraphMotionOffset(model: FrameGraphAcceptanceModel): Float32 {
    6.0 + Float32(model.phase.value % 9) * 5.0
}

private func frameGraphAcceptanceSceneController(): Scene3DViewController {
    let host = FakeScene3DViewHost()
    let controller = Scene3DViewController(
        "framegraph-acceptance-scene",
        host,
        FakeScene3DProvider(),
        Scene3DResource(
            "framegraph-acceptance-resource",
            "memory://framegraph-acceptance",
            "sha256:framegraph-acceptance",
            0),
        FrameGraphAcceptanceSceneFrames(),
        compositionMode: Scene3DCompositionMode.PreferSharedFrame)
    host.publish(NativeSurfaceEvent.Available(NativeSurfaceDescriptor(
        "framegraph-acceptance-surface",
        NativeSurfaceBackend.Software,
        UInt64(1),
        268.0,
        116.0,
        268,
        116,
        1.0,
        1)))
    host.publish(NativeSurfaceEvent.Frame(NativeSurfaceFrame(1, 0, 16)))
    controller
}

private func applyFrameGraphAcceptanceTheme(
    model: FrameGraphAcceptanceModel,
    app: ?DesktopApp
): Unit {
    match (app) {
        case Some(value) => value.transitionTheme(frameGraphAcceptanceTheme(model))
        case None => ()
    }
}

private func frameGraphAcceptanceTheme(model: FrameGraphAcceptanceModel): Theme {
    let preferences = model.preferences()
    if (model.dark.value) {
        LiquidGlass.dark(tint: Color.rgb(72, 156, 255), preferences: preferences)
    } else {
        LiquidGlass.light(tint: Color.rgb(55, 126, 246), preferences: preferences)
    }
}
