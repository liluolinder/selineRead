package chui.core

import sdl.{Color, Rect, SurfaceStyle}

/** Continuous interaction state supplied to a state-aware button style. */
public struct ButtonVisualState {
    public let hover: Float32
    public let press: Float32
    public let focused: Bool

    public init(hover!: Float32 = 0.0, press!: Float32 = 0.0, focused!: Bool = false) {
        this.hover = max(0.0, min(1.0, hover))
        this.press = max(0.0, min(1.0, press))
        this.focused = focused
    }
}

/** Complete outer paint result for a button; slot content keeps ownership of its own foreground. */
public struct ButtonAppearance {
    public let surface: SurfaceStyle
    public let foreground: Color
    public let ink: Color
    public let focusRadius: Float32

    public init(
        surface!: SurfaceStyle,
        foreground!: Color,
        ink!: Color,
        focusRadius!: Float32
    ) {
        this.surface = surface
        this.foreground = foreground
        this.ink = ink
        this.focusRadius = max(0.0, focusRadius)
    }
}

/** Resolves one button appearance from semantic role and live interaction state. */
public class ButtonStyle {
    private let resolver: (Theme, ButtonRole, ButtonVisualState) -> ButtonAppearance

    public init(resolve!: (Theme, ButtonRole, ButtonVisualState) -> ButtonAppearance) {
        this.resolver = resolve
    }

    public func resolve(theme: Theme, role: ButtonRole, state: ButtonVisualState): ButtonAppearance {
        resolver(theme, role, state)
    }

    /**
     * Borderless command style for compact rows. Idle chrome is transparent; hover and press keep
     * visible theme-derived feedback, while focus remains owned by Button/IconButton.
     */
    public static func quiet(): ButtonStyle {
        ButtonStyle(resolve: {
            theme, role, state =>
            let clear = Color.rgba(0, 0, 0, 0)
            let hoverFill = clear.lerp(theme.fieldActive, state.hover)
            let fill = hoverFill.lerp(theme.accentSoft, state.press)
            let foreground = match (role) {
                case ButtonRole.Normal => theme.text
                case ButtonRole.Primary => theme.accent
                case ButtonRole.Danger => theme.danger
            }
            ButtonAppearance(
                surface: SurfaceStyle(fill, radius: theme.controlRadius),
                foreground: foreground,
                ink: theme.inkColor(role: role),
                focusRadius: theme.controlRadius
            )
        })
    }
}

/** Layout anatomy shared by title and slot-based buttons. */
public struct ButtonLayoutStyle {
    public let contentPadding: LengthInsets
    public let minWidth: Float32
    public let minHeight: Float32

    public init(
        contentPadding!: LengthInsets = LengthInsets(12.vp, 0.vp),
        minWidth!: Float32 = 72.0,
        minHeight!: Float32 = CUI_CONTROL_H
    ) {
        this.contentPadding = contentPadding
        this.minWidth = max(0.0, minWidth)
        this.minHeight = max(0.0, minHeight)
    }
}

/** Non-button component families that share one state-aware appearance resolver. */
public enum ComponentControlKind {
    | Chip
    | Checkbox
    | Dropdown
    | AccordionHeader
}

/** Continuous interaction and semantic state supplied to a component control style. */
public struct ComponentControlState {
    public let hover: Float32
    public let press: Float32
    public let focused: Bool
    public let selected: Bool
    public let selection: Float32
    public let expanded: Bool

    public init(
        hover!: Float32 = 0.0,
        press!: Float32 = 0.0,
        focused!: Bool = false,
        selected!: Bool = false,
        selection!: ?Float32 = None,
        expanded!: Bool = false
    ) {
        this.hover = max(0.0, min(1.0, hover))
        this.press = max(0.0, min(1.0, press))
        this.focused = focused
        this.selected = selected
        this.selection = match (selection) {
            case Some(value) => max(0.0, min(1.0, value))
            case None => if (selected) { 1.0 } else { 0.0 }
        }
        this.expanded = expanded
    }
}

/** Outer paint and indicator colors shared by selectable and disclosure controls. */
public struct ComponentControlAppearance {
    public let surface: SurfaceStyle
    public let foreground: Color
    public let indicator: Color
    public let ink: Color
    public let focusRadius: Float32

    public init(
        surface!: SurfaceStyle,
        foreground!: Color,
        indicator!: Color,
        ink!: Color,
        focusRadius!: Float32
    ) {
        this.surface = surface
        this.foreground = foreground
        this.indicator = indicator
        this.ink = ink
        this.focusRadius = max(0.0, focusRadius)
    }
}

/** Resolves Chip, Checkbox, Dropdown and Accordion-header appearance from live state. */
public class ComponentControlStyle {
    private let resolver: (Theme, ComponentControlKind, ComponentControlState) -> ComponentControlAppearance

    public init(resolve!: (Theme, ComponentControlKind, ComponentControlState) -> ComponentControlAppearance) {
        this.resolver = resolve
    }

    public func resolve(
        theme: Theme,
        kind: ComponentControlKind,
        state: ComponentControlState
    ): ComponentControlAppearance {
        resolver(theme, kind, state)
    }
}

/** Semantic text sizes used by stock controls without changing application typography. */
public struct ComponentTypography {
    public let control: Length

    public init(control!: Length = 15.fp) {
        this.control = control
    }
}

/** Shared component rhythm for compact selectors, ordinary controls and indicator rows. */
public struct ComponentSpacing {
    public let compactPadding: LengthInsets
    public let controlPadding: LengthInsets
    public let selectionPadding: LengthInsets
    public let inlineGap: Length
    public let compactMinHeight: Float32
    public let controlMinHeight: Float32
    public let indicatorSize: Float32

    public init(
        compactPadding!: LengthInsets = LengthInsets(12.vp, 0.vp),
        controlPadding!: LengthInsets = LengthInsets(10.vp, 0.vp),
        selectionPadding!: LengthInsets = LengthInsets(
            top: 7.vp, right: 8.vp, bottom: 7.vp, left: 0.vp),
        inlineGap!: Length = 8.vp,
        compactMinHeight!: Float32 = 28.0,
        controlMinHeight!: Float32 = CUI_CONTROL_H,
        indicatorSize!: Float32 = 18.0
    ) {
        this.compactPadding = compactPadding
        this.controlPadding = controlPadding
        this.selectionPadding = selectionPadding
        this.inlineGap = inlineGap
        this.compactMinHeight = max(0.0, compactMinHeight)
        this.controlMinHeight = max(0.0, controlMinHeight)
        this.indicatorSize = max(0.0, indicatorSize)
    }
}

/** Optional component radii; omitted values inherit the semantic Theme radii. */
public struct ComponentShape {
    public let smallRadius: ?Float32
    public let controlRadius: ?Float32
    public let pillRadius: ?Float32

    public init(
        smallRadius!: ?Float32 = None,
        controlRadius!: ?Float32 = None,
        pillRadius!: ?Float32 = None
    ) {
        this.smallRadius = normalizeRadius(smallRadius)
        this.controlRadius = normalizeRadius(controlRadius)
        this.pillRadius = normalizeRadius(pillRadius)
    }

    public func resolvedSmall(theme: Theme): Float32 {
        match (smallRadius) {
            case Some(value) => value
            case None => theme.smallRadius
        }
    }

    public func resolvedControl(theme: Theme): Float32 {
        match (controlRadius) {
            case Some(value) => value
            case None => theme.controlRadius
        }
    }

    public func resolvedPill(): Float32 {
        match (pillRadius) {
            case Some(value) => value
            case None => 9999.0
        }
    }
}

/** Live geometry supplied to a custom segmented-control indicator painter. */
public struct SegmentedControlVisualState {
    public let animatedIndex: Float32
    public let targetIndex: Int64
    public let stretch: Float32
    public let movingForward: Bool

    public init(
        animatedIndex!: Float32,
        targetIndex!: Int64,
        stretch!: Float32,
        movingForward!: Bool
    ) {
        this.animatedIndex = animatedIndex
        this.targetIndex = targetIndex
        this.stretch = max(0.0, min(1.0, stretch))
        this.movingForward = movingForward
    }
}

/**
 * Optional painter for SegmentedControl and TabView selection lenses.
 *
 * Geometry remains owned by the stock control. `deformation` only lets its independently animated
 * leading and trailing edges stretch the indicator while it travels; the painter receives that
 * resolved rectangle and can add material-specific optical layers without reimplementing input,
 * focus, semantics or layout.
 */
public class SegmentedControlStyle {
    public let deformation: Float32
    private let indicatorPainter: (UiContext, Rect, SegmentedControlVisualState) -> Unit
    private let foregroundResolver: (Theme, Bool) -> Color

    public init(
        deformation!: Float32 = 0.0,
        paintIndicator!: (UiContext, Rect, SegmentedControlVisualState) -> Unit,
        foreground!: (Theme, Bool) -> Color
    ) {
        this.deformation = max(0.0, min(1.0, deformation))
        this.indicatorPainter = paintIndicator
        this.foregroundResolver = foreground
    }

    public func paintIndicator(ctx: UiContext, rect: Rect, state: SegmentedControlVisualState): Unit {
        indicatorPainter(ctx, rect, state)
    }

    public func foreground(theme: Theme, selected: Bool): Color {
        foregroundResolver(theme, selected)
    }
}

/** Component-scoped theme overrides layered on top of the semantic palette. */
public struct ComponentTheme {
    public let buttonStyle: ?ButtonStyle
    public let buttonLayout: ButtonLayoutStyle
    public let panelSurface: ?SurfaceStyle
    public let controlStyle: ?ComponentControlStyle
    public let typography: ComponentTypography
    public let spacing: ComponentSpacing
    public let shape: ComponentShape
    public let segmentedControlStyle: ?SegmentedControlStyle

    public init(
        buttonStyle!: ?ButtonStyle = None,
        buttonLayout!: ButtonLayoutStyle = ButtonLayoutStyle(),
        panelSurface!: ?SurfaceStyle = None,
        controlStyle!: ?ComponentControlStyle = None,
        typography!: ComponentTypography = ComponentTypography(),
        spacing!: ComponentSpacing = ComponentSpacing(),
        shape!: ComponentShape = ComponentShape(),
        segmentedControlStyle!: ?SegmentedControlStyle = None
    ) {
        this.buttonStyle = buttonStyle
        this.buttonLayout = buttonLayout
        this.panelSurface = panelSurface
        this.controlStyle = controlStyle
        this.typography = typography
        this.spacing = spacing
        this.shape = shape
        this.segmentedControlStyle = segmentedControlStyle
    }
}

protected func resolveComponentControlAppearance(
    theme: Theme,
    kind: ComponentControlKind,
    state: ComponentControlState,
    styleOverride!: ?ComponentControlStyle = None
): ComponentControlAppearance {
    match (styleOverride) {
        case Some(value) => return value.resolve(theme, kind, state)
        case None => ()
    }
    match (theme.components.controlStyle) {
        case Some(value) => value.resolve(theme, kind, state)
        case None => defaultComponentControlAppearance(theme, kind, state)
    }
}

private func defaultComponentControlAppearance(
    theme: Theme,
    kind: ComponentControlKind,
    state: ComponentControlState
): ComponentControlAppearance {
    let shape = theme.components.shape
    let amount = theme.motionLevel.amplitude()
    let baseRadius = match (kind) {
        case ComponentControlKind.Chip => shape.resolvedPill()
        case ComponentControlKind.Checkbox => shape.resolvedSmall(theme)
        case _ => shape.resolvedControl(theme)
    }
    let selected = state.selected || state.expanded || state.selection > 0.001
    let baseSurface = match (kind) {
        case ComponentControlKind.Chip => if (selected) {
            SurfaceStyle(theme.accent, border: theme.accent, radius: baseRadius, borderWidth: theme.borderWidth)
        } else {
            SurfaceStyle(theme.field, border: theme.panelEdge, radius: baseRadius, borderWidth: theme.borderWidth)
        }
        case ComponentControlKind.Checkbox => SurfaceStyle(theme.field,
            border: theme.panelEdge.lerp(theme.accent, if (selected) { 1.0 } else { 0.0 }),
            radius: baseRadius, borderWidth: theme.borderWidth)
        case ComponentControlKind.Dropdown => surfaceWithRadius(
            theme.fieldSurface(state.focused || state.expanded), baseRadius)
        case ComponentControlKind.AccordionHeader => SurfaceStyle(
            theme.field.lerp(theme.fieldActive, state.selection), radius: baseRadius)
    }
    let hoverFill = match (kind) {
        case ComponentControlKind.Chip => if (selected) {
            baseSurface.fill.lerp(theme.accentText, min(0.12, 0.06 * amount))
        } else {
            theme.fieldActive
        }
        case ComponentControlKind.Checkbox => baseSurface.fill.lerp(theme.fieldActive, 0.65)
        case _ => theme.fieldActive
    }
    let pressFill = match (kind) {
        case ComponentControlKind.Chip => if (selected) {
            baseSurface.fill.lerp(theme.bg, min(0.22, 0.12 * amount))
        } else {
            theme.accentSoft
        }
        case ComponentControlKind.Checkbox => baseSurface.fill.lerp(theme.accentSoft, 0.6)
        case _ => theme.accentSoft
    }
    let hovered = baseSurface.fill.lerp(hoverFill, state.hover)
    let surface = baseSurface.withFill(hovered.lerp(pressFill, state.press))
    ComponentControlAppearance(
        surface: surface,
        foreground: match (kind) {
            case ComponentControlKind.Chip => if (selected) { theme.accentText } else { theme.text }
            case _ => theme.text
        },
        indicator: match (kind) {
            case ComponentControlKind.Checkbox => theme.accent
            case _ => if (selected) { theme.accent } else { theme.mutedText }
        },
        ink: theme.inkColor(),
        focusRadius: baseRadius
    )
}

private func normalizeRadius(value: ?Float32): ?Float32 {
    match (value) {
        case Some(radius) => Some(max(0.0, radius))
        case None => None
    }
}

private func surfaceWithRadius(value: SurfaceStyle, radius: Float32): SurfaceStyle {
    SurfaceStyle(
        value.fill,
        border: value.border,
        radius: radius,
        borderWidth: value.borderWidth,
        shadow: value.shadow,
        shadowOffsetY: value.shadowOffsetY
    )
}

protected func resolveButtonAppearance(
    theme: Theme,
    role: ButtonRole,
    state: ButtonVisualState,
    styleOverride!: ?ButtonStyle = None,
    surfaceOverride!: ?SurfaceStyle = None
): ButtonAppearance {
    match (styleOverride) {
        case Some(value) => return value.resolve(theme, role, state)
        case None => ()
    }
    match (surfaceOverride) {
        case Some(value) => return defaultButtonAppearance(theme, role, state, base: value)
        case None => ()
    }
    match (theme.components.buttonStyle) {
        case Some(value) => value.resolve(theme, role, state)
        case None => defaultButtonAppearance(theme, role, state)
    }
}

private func defaultButtonAppearance(
    theme: Theme,
    role: ButtonRole,
    state: ButtonVisualState,
    base!: ?SurfaceStyle = None
): ButtonAppearance {
    let surface = match (base) {
        case Some(value) => value
        case None => theme.buttonSurface(role)
    }
    ButtonAppearance(
        surface: animatedButtonSurface(theme, surface, role, state),
        foreground: match (role) {
            case ButtonRole.Normal => theme.text
            case _ => theme.accentText
        },
        ink: theme.inkColor(role: role),
        focusRadius: surface.radius
    )
}

protected func animatedButtonSurface(
    theme: Theme,
    base: SurfaceStyle,
    role: ButtonRole,
    state: ButtonVisualState
): SurfaceStyle {
    let amount = theme.motionLevel.amplitude()
    let hoverFill = match (role) {
        case ButtonRole.Normal => theme.fieldActive
        case _ => base.fill.lerp(theme.accentText, min(0.16, 0.08 * amount))
    }
    let pressFill = match (role) {
        case ButtonRole.Normal => theme.accentSoft
        case _ => base.fill.lerp(theme.bg, min(0.24, 0.14 * amount))
    }
    let hovered = base.fill.lerp(hoverFill, state.hover)
    base.withFill(hovered.lerp(pressFill, state.press))
}
