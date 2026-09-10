package canghui_style_liquid_glass

import chui.{ButtonRole, ButtonVisualState, Color, MotionLevel, Rect, Renderer, RendererEffectStatus,
    SurfaceState, Theme}

@Test
func liquidGlassThemesExposeAdaptiveTokens(): Unit {
    let light = LiquidGlass.light()
    let dark = LiquidGlass.dark()
    @Expect(Int64(light.bg.r) > Int64(dark.bg.r))
    @Expect(light.controlRadius, 9999.0)
    @Expect(dark.radius, 28.0)
}

@Test
func liquidGlassAccessibilityPreferencesWinOverDecoration(): Unit {
    let preferences = LiquidGlassPreferences(
        reduceTransparency: true,
        increaseContrast: true,
        reduceMotion: true
    )
    let theme = LiquidGlass.dark(preferences: preferences, motionLevel: MotionLevel.Full)
    @Expect(theme.reduceMotion)
    @Expect(theme.borderWidth, 1.5)
    @Expect(Int64(theme.panel.a), 255)
}

@Test
func liquidGlassVariantsAndTintResolveDifferentMaterials(): Unit {
    let theme = Theme.light()
    let regular = LiquidGlass.material(spec: LiquidGlassSpec(
        variant: LiquidGlassVariant.Regular,
        tint: Some(Color.rgb(0, 122, 255))
    )).resolve(theme, SurfaceState())
    let clear = LiquidGlass.material(spec: LiquidGlassSpec(
        variant: LiquidGlassVariant.Clear,
        tint: Some(Color.rgb(0, 122, 255))
    )).resolve(theme, SurfaceState())
    @Expect(Int64(regular.style.fill.a) > Int64(clear.style.fill.a))
    @Expect(regular.style.radius, 9999.0)
}

@Test
func liquidGlassButtonStyleKeepsSemanticRoles(): Unit {
    let theme = LiquidGlass.light()
    let style = LiquidGlass.buttonStyle()
    let normal = style.resolve(theme, ButtonRole.Normal, ButtonVisualState())
    let primary = style.resolve(theme, ButtonRole.Primary, ButtonVisualState(hover: 1.0))
    @Expect(Int64(normal.surface.fill.a) < 255)
    @Expect(Int64(primary.surface.fill.b) > Int64(primary.surface.fill.r))
    @Expect(primary.focusRadius, 9999.0)
}

@Test
func liquidGlassOpticsClampAndDriveMorphingSegmentStyle(): Unit {
    let optics = LiquidGlassOptics(clarity: 2.0, haze: -1.0, deformation: 0.76)
    @Expect(optics.clarity, 1.0)
    @Expect(optics.haze, 0.0)
    let style = LiquidGlass.segmentedControlStyle(spec: LiquidGlassSpec(optics: optics))
    @Expect(style.deformation, 0.76)
    let reduced = LiquidGlass.segmentedControlStyle(spec: LiquidGlassSpec(
        preferences: LiquidGlassPreferences(reduceMotion: true), optics: optics))
    @Expect(reduced.deformation, 0.0)
}

@Test
func liquidGlassSdrPainterEmitsLayeredClearAndVaporCommands(): Unit {
    let renderer = Renderer.recordingHeadless()
    LiquidGlass.paint(renderer, Rect(10.0, 10.0, 180.0, 48.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Clear), stretch: 0.7)
    let clearCount = renderer.drawIr().size
    @Expect(clearCount >= 7)
    renderer.clearDrawIr()
    LiquidGlass.paint(renderer, Rect(10.0, 10.0, 180.0, 48.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Vapor))
    @Expect(renderer.drawIr().size > clearCount)
}

@Test
func liquidGlassReceiptExposesFallbackAndReducedTransparencySkipsEffectRequest(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(240.0, 120.0, Color.rgb(20, 30, 40))
    renderer.clearDrawIr()
    let fallback = LiquidGlass.paintWithReceipt(
        renderer,
        Rect(20.0, 20.0, 160.0, 48.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Clear)
    )
    @Expect(fallback.status, RendererEffectStatus.Unsupported)
    @Expect(fallback.code, "no-effect-adapter")
    var effectCommands: Int64 = 0
    for (command in renderer.drawIr()) {
        if (command.kind == "effect.backdrop") { effectCommands += 1 }
    }
    @Expect(effectCommands, Int64(1))

    renderer.clearDrawIr()
    let opaque = LiquidGlass.paintWithReceipt(
        renderer,
        Rect(20.0, 20.0, 160.0, 48.0),
        spec: LiquidGlassSpec(preferences: LiquidGlassPreferences(reduceTransparency: true))
    )
    @Expect(opaque.status, RendererEffectStatus.Degraded)
    @Expect(opaque.code, "reduced-transparency")
    for (command in renderer.drawIr()) {
        @Expect(command.kind != "effect.backdrop")
    }
    renderer.endScene()
}
