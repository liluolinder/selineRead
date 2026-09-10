package canghui_style_liquid_glass

import chui.*

/** Visual density of the optional glass material. */
public enum LiquidGlassVariant {
    | Regular
    | Clear
    | Vapor
}

/** Optical controls shared by the optional backdrop request and deterministic SDR fallback. */
public struct LiquidGlassOptics {
    public let clarity: Float32
    public let haze: Float32
    public let edgeEnergy: Float32
    public let chromaticEdge: Float32
    public let deformation: Float32

    public init(
        clarity!: Float32 = 0.86,
        haze!: Float32 = 0.34,
        edgeEnergy!: Float32 = 0.88,
        chromaticEdge!: Float32 = 0.22,
        deformation!: Float32 = 0.82
    ) {
        this.clarity = clampUnit(clarity)
        this.haze = clampUnit(haze)
        this.edgeEnergy = clampUnit(edgeEnergy)
        this.chromaticEdge = clampUnit(chromaticEdge)
        this.deformation = clampUnit(deformation)
    }
}

/** User and host preferences that must win over decorative transparency and motion. */
public struct LiquidGlassPreferences {
    public let reduceTransparency: Bool
    public let increaseContrast: Bool
    public let reduceMotion: Bool

    public init(
        reduceTransparency!: Bool = false,
        increaseContrast!: Bool = false,
        reduceMotion!: Bool = false
    ) {
        this.reduceTransparency = reduceTransparency
        this.increaseContrast = increaseContrast
        this.reduceMotion = reduceMotion
    }
}

/** Immutable configuration shared by material, component and theme recipes. */
public struct LiquidGlassSpec {
    public let variant: LiquidGlassVariant
    public let tint: ?Color
    public let interactive: Bool
    public let radius: Float32
    public let preferences: LiquidGlassPreferences
    public let optics: LiquidGlassOptics

    public init(
        variant!: LiquidGlassVariant = LiquidGlassVariant.Regular,
        tint!: ?Color = None,
        interactive!: Bool = false,
        radius!: Float32 = 9999.0,
        preferences!: LiquidGlassPreferences = LiquidGlassPreferences(),
        optics!: LiquidGlassOptics = LiquidGlassOptics()
    ) {
        this.variant = variant
        this.tint = tint
        this.interactive = interactive
        this.radius = max(0.0, radius)
        this.preferences = preferences
        this.optics = optics
    }

    public func shape(): Shape { Shape.rounded(radius) }
}

/** Public Liquid Glass-inspired recipes with capability-gated backdrop effects and safe fallback. */
public class LiquidGlass {
    /** A material for `Surface`; state-aware tinting is enabled only when `spec.interactive` is true. */
    public static func material(spec!: LiquidGlassSpec = LiquidGlassSpec()): MaterialProvider {
        LiquidGlassMaterial(spec)
    }

    /** State-aware style for `Button` and `IconButton`. */
    public static func buttonStyle(spec!: LiquidGlassSpec = LiquidGlassSpec(interactive: true)): ButtonStyle {
        ButtonStyle(resolve: {theme, role, state => glassButtonAppearance(theme, role, state, spec)})
    }

    /** Morphing selection-lens style for the stock `SegmentedControl` and `TabView`. */
    public static func segmentedControlStyle(
        spec!: LiquidGlassSpec = LiquidGlassSpec(
            variant: LiquidGlassVariant.Clear,
            interactive: true
        )
    ): SegmentedControlStyle {
        SegmentedControlStyle(
            deformation: if (spec.preferences.reduceMotion) { 0.0 } else { spec.optics.deformation },
            paintIndicator: {ctx, rect, state =>
                let _ = paintOpticalGlass(ctx.renderer, rect, isDark(ctx.theme), spec, state.stretch)
            },
            foreground: {theme, selected =>
                if (selected) { theme.text } else { theme.mutedText }
            }
        )
    }

    /** Draws the first-version SDR optical approximation into an arbitrary rectangle. */
    public static func paint(
        renderer: Renderer,
        rect: Rect,
        dark!: Bool = false,
        spec!: LiquidGlassSpec = LiquidGlassSpec(),
        stretch!: Float32 = 0.0
    ): Unit {
        let _ = paintOpticalGlass(renderer, rect, dark, spec, clampUnit(stretch))
    }

    /** Paints the same material and returns the native-effect or fallback reason for diagnostics. */
    public static func paintWithReceipt(
        renderer: Renderer,
        rect: Rect,
        dark!: Bool = false,
        spec!: LiquidGlassSpec = LiquidGlassSpec(),
        stretch!: Float32 = 0.0
    ): RendererEffectReceipt {
        paintOpticalGlass(renderer, rect, dark, spec, clampUnit(stretch))
    }

    /** Optical background hook for the stock `Surface`; content and layout stay Surface-owned. */
    public static func surfacePainter(
        spec!: LiquidGlassSpec = LiquidGlassSpec()
    ): SurfacePainter {
        SurfacePainter(paint: {ctx, rect, shape, _ =>
            let resolved = LiquidGlassSpec(
                variant: spec.variant,
                tint: spec.tint,
                interactive: spec.interactive,
                radius: min(spec.radius, shape.cornerRadius()),
                preferences: spec.preferences,
                optics: spec.optics
            )
            let _ = paintOpticalGlass(ctx.renderer, rect, isDark(ctx.theme), resolved, 0.0)
        })
    }

    /** Component-wide recipe for buttons, chips, checkboxes, dropdowns, panels and control rhythm. */
    public static func components(
        spec!: LiquidGlassSpec = LiquidGlassSpec(interactive: true)
    ): ComponentTheme {
        ComponentTheme(
            buttonStyle: Some(buttonStyle(spec: spec)),
            buttonLayout: ButtonLayoutStyle(
                contentPadding: LengthInsets(15.vp, 0.vp),
                minWidth: 70.0,
                minHeight: 40.0
            ),
            controlStyle: Some(ComponentControlStyle(resolve: {
                theme, kind, state => glassControlAppearance(theme, kind, state, spec)
            })),
            typography: ComponentTypography(control: 15.fp),
            spacing: ComponentSpacing(
                compactPadding: LengthInsets(12.vp, 0.vp),
                controlPadding: LengthInsets(12.vp, 0.vp),
                selectionPadding: LengthInsets(top: 8.vp, right: 10.vp, bottom: 8.vp, left: 0.vp),
                inlineGap: 8.vp,
                compactMinHeight: 30.0,
                controlMinHeight: 40.0,
                indicatorSize: 18.0
            ),
            shape: ComponentShape(smallRadius: Some(10.0), controlRadius: Some(9999.0),
                pillRadius: Some(9999.0)),
            segmentedControlStyle: Some(segmentedControlStyle(spec: LiquidGlassSpec(
                variant: LiquidGlassVariant.Clear,
                tint: spec.tint,
                interactive: true,
                preferences: spec.preferences,
                optics: spec.optics
            )))
        )
    }

    /** Light content palette with glass component defaults. */
    public static func light(
        tint!: Color = Color.rgb(0, 122, 255),
        preferences!: LiquidGlassPreferences = LiquidGlassPreferences(),
        motionLevel!: MotionLevel = MotionLevel.Standard
    ): Theme {
        let spec = LiquidGlassSpec(tint: Some(tint), interactive: true, preferences: preferences)
        Theme(
            bg: Color.rgb(226, 235, 246),
            panel: glassFill(false, LiquidGlassVariant.Regular, preferences),
            panelEdge: glassEdge(false, preferences),
            text: Color.rgb(24, 29, 38),
            mutedText: Color.rgb(83, 92, 108),
            accent: tint,
            accentText: Color.rgb(255, 255, 255),
            danger: Color.rgb(224, 54, 64),
            field: Color.rgba(255, 255, 255, if (preferences.reduceTransparency) { 255 } else { 116 }),
            fieldActive: tint.withAlpha(if (preferences.reduceTransparency) { 44 } else { 56 }),
            panelRaised: Color.rgba(255, 255, 255, if (preferences.reduceTransparency) { 255 } else { 166 }),
            accentSoft: tint.withAlpha(46),
            shadow: Color.rgba(26, 43, 69, 42),
            radius: 28.0,
            smallRadius: 10.0,
            controlRadius: 9999.0,
            borderWidth: if (preferences.increaseContrast) { 1.5 } else { 1.0 },
            motionLevel: motionLevel,
            reduceMotion: preferences.reduceMotion,
            components: components(spec: spec)
        )
    }

    /** Dark content palette with glass component defaults. */
    public static func dark(
        tint!: Color = Color.rgb(72, 156, 255),
        preferences!: LiquidGlassPreferences = LiquidGlassPreferences(),
        motionLevel!: MotionLevel = MotionLevel.Standard
    ): Theme {
        let spec = LiquidGlassSpec(tint: Some(tint), interactive: true, preferences: preferences)
        Theme(
            bg: Color.rgb(13, 18, 28),
            panel: glassFill(true, LiquidGlassVariant.Regular, preferences),
            panelEdge: glassEdge(true, preferences),
            text: Color.rgb(247, 249, 252),
            mutedText: Color.rgb(174, 183, 198),
            accent: tint,
            accentText: Color.rgb(6, 18, 34),
            danger: Color.rgb(255, 105, 112),
            field: Color.rgba(50, 58, 72, if (preferences.reduceTransparency) { 255 } else { 150 }),
            fieldActive: tint.withAlpha(if (preferences.reduceTransparency) { 54 } else { 68 }),
            panelRaised: Color.rgba(56, 64, 79, if (preferences.reduceTransparency) { 255 } else { 176 }),
            accentSoft: tint.withAlpha(52),
            shadow: Color.rgba(0, 0, 0, 92),
            radius: 28.0,
            smallRadius: 10.0,
            controlRadius: 9999.0,
            borderWidth: if (preferences.increaseContrast) { 1.5 } else { 1.0 },
            motionLevel: motionLevel,
            reduceMotion: preferences.reduceMotion,
            components: components(spec: spec)
        )
    }
}

private class LiquidGlassMaterial <: MaterialProvider {
    private let spec: LiquidGlassSpec

    init(spec: LiquidGlassSpec) { this.spec = spec }

    public func resolve(theme: Theme, state: SurfaceState): SurfaceMaterial {
        let style = surfaceStyle(theme, state, spec)
        SurfaceMaterial(style, theme.text, supportingForeground: Some(theme.mutedText),
            ink: Some(theme.inkColor()))
    }
}

private func surfaceStyle(theme: Theme, state: SurfaceState, spec: LiquidGlassSpec): SurfaceStyle {
    let dark = isDark(theme)
    var fill = glassFill(dark, spec.variant, spec.preferences)
    match (spec.tint) {
        case Some(value) => fill = fill.lerp(value.withAlpha(fillAlpha(fill)), tintStrength(spec.variant))
        case None => ()
    }
    if (spec.interactive) {
        let hover: Float32 = if (state.hovered) { 0.14 } else { 0.0 }
        let press: Float32 = if (state.pressed) { 0.22 } else { 0.0 }
        fill = fill.lerp(theme.text.withAlpha(fillAlpha(fill)), hover)
        fill = fill.lerp(theme.accent.withAlpha(fillAlpha(fill)), press)
    }
    SurfaceStyle(
        fill,
        border: glassEdge(dark, spec.preferences),
        radius: spec.radius,
        borderWidth: if (spec.preferences.increaseContrast) { 1.5 } else { 1.0 },
        shadow: if (spec.preferences.reduceTransparency) {
            Color.rgba(0, 0, 0, 26)
        } else if (dark) {
            Color.rgba(0, 0, 0, 82)
        } else {
            Color.rgba(31, 50, 79, 46)
        },
        shadowOffsetY: match (spec.variant) {
            case LiquidGlassVariant.Clear => 3.0
            case LiquidGlassVariant.Regular => 5.0
            case LiquidGlassVariant.Vapor => 6.0
        }
    )
}

private func glassButtonAppearance(
    theme: Theme,
    role: ButtonRole,
    state: ButtonVisualState,
    spec: LiquidGlassSpec
): ButtonAppearance {
    let surfaceState = SurfaceState(focused: state.focused, hovered: state.hover > 0.001,
        pressed: state.press > 0.001)
    var style = surfaceStyle(theme, surfaceState, spec)
    let foreground = match (role) {
        case ButtonRole.Normal => theme.text
        case ButtonRole.Primary => theme.accentText
        case ButtonRole.Danger => theme.accentText
    }
    match (role) {
        case ButtonRole.Normal => ()
        case ButtonRole.Primary => style = style.withFill(theme.accent.withAlpha(
            if (spec.preferences.reduceTransparency) { 255 } else { 218 }))
        case ButtonRole.Danger => style = style.withFill(theme.danger.withAlpha(
            if (spec.preferences.reduceTransparency) { 255 } else { 218 }))
    }
    let ink = match (role) {
        case ButtonRole.Normal => theme.accent
        case _ => theme.accentText.withAlpha(84)
    }
    ButtonAppearance(surface: style, foreground: foreground,
        ink: ink,
        focusRadius: spec.radius)
}

private func glassControlAppearance(
    theme: Theme,
    kind: ComponentControlKind,
    state: ComponentControlState,
    spec: LiquidGlassSpec
): ComponentControlAppearance {
    let selected = state.selected || state.expanded || state.selection > 0.001
    let radius: Float32 = match (kind) {
        case ComponentControlKind.Checkbox => 10.0
        case _ => spec.radius
    }
    var style = surfaceStyle(theme, SurfaceState(selected: selected, expanded: state.expanded,
        focused: state.focused, hovered: state.hover > 0.001, pressed: state.press > 0.001),
        LiquidGlassSpec(variant: spec.variant, tint: spec.tint, interactive: spec.interactive,
            radius: radius, preferences: spec.preferences, optics: spec.optics))
    let acceptsSelectedFill = match (kind) {
        case ComponentControlKind.Dropdown => false
        case _ => true
    }
    if (selected && acceptsSelectedFill) {
        style = style.withFill(theme.accent.withAlpha(if (spec.preferences.reduceTransparency) { 255 } else { 206 }))
    }
    ComponentControlAppearance(
        surface: style,
        foreground: match (kind) {
            case ComponentControlKind.Chip => if (selected) { theme.accentText } else { theme.text }
            case _ => theme.text
        },
        indicator: if (selected) { theme.accentText } else { theme.accent },
        ink: theme.inkColor(),
        focusRadius: radius
    )
}

private func glassFill(dark: Bool, variant: LiquidGlassVariant, preferences: LiquidGlassPreferences): Color {
    if (preferences.reduceTransparency) {
        return if (dark) { Color.rgb(43, 50, 63) } else { Color.rgb(244, 247, 251) }
    }
    match (variant) {
        case LiquidGlassVariant.Regular => if (dark) {
            Color.rgba(62, 70, 86, 166)
        } else {
            Color.rgba(255, 255, 255, 164)
        }
        case LiquidGlassVariant.Clear => if (dark) {
            Color.rgba(82, 90, 106, 98)
        } else {
            Color.rgba(255, 255, 255, 92)
        }
        case LiquidGlassVariant.Vapor => if (dark) {
            Color.rgba(92, 102, 122, 126)
        } else {
            Color.rgba(246, 250, 255, 122)
        }
    }
}

private func glassEdge(dark: Bool, preferences: LiquidGlassPreferences): Color {
    if (preferences.increaseContrast) {
        if (dark) { Color.rgba(255, 255, 255, 118) } else { Color.rgba(61, 76, 98, 112) }
    } else if (dark) {
        Color.rgba(255, 255, 255, 62)
    } else {
        Color.rgba(255, 255, 255, 206)
    }
}

private func isDark(theme: Theme): Bool {
    Int64(theme.bg.r) + Int64(theme.bg.g) + Int64(theme.bg.b) < 384
}

private func fillAlpha(value: Color): Int64 { Int64(value.a) }

private func tintStrength(variant: LiquidGlassVariant): Float32 {
    match (variant) {
        case LiquidGlassVariant.Regular => 0.10
        case LiquidGlassVariant.Clear => 0.16
        case LiquidGlassVariant.Vapor => 0.12
    }
}

private func paintOpticalGlass(
    renderer: Renderer,
    rect: Rect,
    dark: Bool,
    spec: LiquidGlassSpec,
    stretch: Float32
): RendererEffectReceipt {
    let radius = min(spec.radius, rect.h / 2.0 + stretch * 3.0)
    if (spec.preferences.reduceTransparency) {
        renderer.fillRoundedRect(rect, radius, glassFill(dark, spec.variant, spec.preferences))
        renderer.strokeRoundedRect(rect.inset(0.5), max(0.0, radius - 0.5),
            Pen(width: if (spec.preferences.increaseContrast) { 1.5 } else { 1.0 },
                color: glassEdge(dark, spec.preferences)))
        return RendererEffectReceipt(
            RendererEffectStatus.Degraded,
            "backdrop",
            "reduced-transparency",
            frameGeneration: renderer.effectFrameGeneration(),
            detail: "opaque accessibility material selected without backdrop sampling"
        )
    }

    let optics = spec.optics
    let effectReceipt = renderer.applyBackdropEffect(BackdropEffectRequest(
        rect,
        cornerRadius: radius,
        blurRadius: 6.0 + optics.haze * 18.0,
        refraction: 0.12 + optics.clarity * 0.42,
        edgeResponse: optics.edgeEnergy
    ))
    let haloAlpha = Int64(24.0 + 44.0 * optics.edgeEnergy)
    let halo = if (dark) { Color.rgba(118, 169, 255, haloAlpha) } else {
        Color.rgba(255, 255, 255, haloAlpha)
    }
    renderer.fillRoundedRectSoft(
        Rect(rect.x - 2.0, rect.y - 2.0, rect.w + 4.0, rect.h + 5.0),
        radius + 2.0,
        halo,
        feather: 5.0 + 4.0 * optics.haze
    )

    if (optics.chromaticEdge > 0.01) {
        let chromaAlpha = Int64(34.0 * optics.chromaticEdge)
        renderer.strokeRoundedRect(Rect(rect.x - 0.8, rect.y, rect.w, rect.h), radius,
            Pen(width: 1.1, color: Color.rgba(102, 180, 255, chromaAlpha)))
        renderer.strokeRoundedRect(Rect(rect.x + 0.8, rect.y, rect.w, rect.h), radius,
            Pen(width: 1.1, color: Color.rgba(255, 128, 179, chromaAlpha)))
    }

    let base = glassFill(dark, spec.variant, spec.preferences)
    let tint = match (spec.tint) {
        case Some(value) => value
        case None => if (dark) { Color.rgb(126, 174, 255) } else { Color.rgb(210, 231, 255) }
    }
    let topAlpha = Int64(38.0 + 74.0 * optics.haze)
    let bottomAlpha = Int64(22.0 + 68.0 * (1.0 - optics.clarity))
    let top = base.lerp(Color.rgba(255, 255, 255, topAlpha), 0.56)
    let bottom = base.lerp(tint.withAlpha(bottomAlpha), 0.34)
    match (spec.variant) {
        case LiquidGlassVariant.Vapor =>
            // A large translucent gradient can expose the portable renderer's triangle fan on
            // dark SDR targets. Vapor favours a seamless body plus local mist bands instead.
            renderer.fillRoundedRect(rect, radius, top.lerp(bottom, 0.52))
        case _ => renderer.fillRoundedRectGradient(rect, radius, top, bottom)
    }

    match (spec.variant) {
        case LiquidGlassVariant.Vapor =>
            let mistInset = max(2.0, min(rect.w, rect.h) * 0.06)
            let mist = Rect(rect.x + mistInset, rect.y + mistInset,
                max(1.0, rect.w - mistInset * 2.0), min(42.0, max(8.0, rect.h * 0.09)))
            renderer.fillRoundedRectSoft(mist, mist.h / 2.0,
                Color.rgba(255, 255, 255, Int64(16.0 + 32.0 * optics.haze)),
                feather: 10.0 + 10.0 * optics.haze)
        case _ => ()
    }

    let edgeAlpha = Int64(84.0 + 128.0 * optics.edgeEnergy)
    renderer.strokeRoundedRect(rect.inset(0.6), max(0.0, radius - 0.6),
        Pen(width: if (spec.preferences.increaseContrast) { 1.8 } else { 1.25 },
            color: Color.rgba(255, 255, 255, edgeAlpha)))
    let inner = rect.inset(2.0)
    renderer.strokeRoundedRect(inner, max(0.0, radius - 2.0),
        Pen(width: 0.8, color: if (dark) {
            Color.rgba(15, 23, 42, Int64(54.0 * optics.edgeEnergy))
        } else {
            Color.rgba(88, 111, 145, Int64(34.0 * optics.edgeEnergy))
        }))

    // Keep the highlight as edge energy, not as an opaque white slab on large surfaces.
    // The width still grows with the live lens deformation so motion changes the optics too.
    let gleamW = min(180.0, max(1.0, rect.w * (0.42 + stretch * 0.14)))
    let gleamH = min(8.0, max(2.0, rect.h * 0.08))
    let gleam = Rect(rect.x + min(18.0, rect.w * 0.12), rect.y + 1.0, gleamW, gleamH)
    renderer.fillRoundedRectSoft(gleam, gleam.h / 2.0,
        Color.rgba(255, 255, 255, Int64(38.0 + 54.0 * optics.edgeEnergy)),
        feather: 4.0)
    effectReceipt
}

private func clampUnit(value: Float32): Float32 {
    max(0.0, min(1.0, value))
}
