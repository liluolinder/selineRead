package chui.core

import std.math.abs
import sdl.{Color, Rect, Size, SurfaceStyle, UiEvent}

/** Geometry shared by a surface's paint and an interaction surface's ink. */
public struct Shape {
    private let radius: Float32

    private init(radius: Float32) {
        this.radius = max(0.0, radius)
    }

    /** A rectangular surface. */
    public static func rectangle(): Shape { Shape(0.0) }

    /** A rounded rectangle with `radius` logical pixels at every corner. */
    public static func rounded(radius: Float32): Shape { Shape(radius) }

    /** The resolved corner radius used by the current rectangle/rounded contract. */
    public func cornerRadius(): Float32 { radius }
}

/** Whether a surface should bound its content to its shape's outer rectangle. */
public enum ClipPolicy {
    | Unclipped
    | Shape
}

/** Read-only state supplied to a theme-resolved material provider. */
public struct SurfaceState {
    public let enabled: Bool
    public let readOnly: Bool
    public let selected: Bool
    public let expanded: Bool
    public let focused: Bool
    public let hovered: Bool
    public let pressed: Bool

    public init(
        enabled!: Bool = true,
        readOnly!: Bool = false,
        selected!: Bool = false,
        expanded!: Bool = false,
        focused!: Bool = false,
        hovered!: Bool = false,
        pressed!: Bool = false
    ) {
        this.enabled = enabled
        this.readOnly = readOnly
        this.selected = selected
        this.expanded = expanded
        this.focused = focused
        this.hovered = hovered
        this.pressed = pressed
    }
}

/** Complete theme-resolved paint and inherited foreground for one surface. */
public struct SurfaceMaterial {
    public let style: SurfaceStyle
    public let foreground: Color
    public let supportingForeground: Color
    public let ink: Color

    public init(
        style: SurfaceStyle,
        foreground: Color,
        supportingForeground!: ?Color = None,
        ink!: ?Color = None
    ) {
        this.style = style
        this.foreground = foreground
        this.supportingForeground = match (supportingForeground) {
            case Some(value) => value
            case None => foreground.withAlpha(Int64(foreground.a) * 3 / 4)
        }
        this.ink = match (ink) {
            case Some(value) => value
            case None => foreground.withAlpha(72)
        }
    }
}

/** Resolves rendering from theme and interaction state without owning events or focus. */
public interface MaterialProvider {
    func resolve(theme: Theme, state: SurfaceState): SurfaceMaterial
}

/** Optional low-level paint hook for effect packages while Surface keeps layout and content ownership. */
public class SurfacePainter {
    private let painter: (UiContext, Rect, Shape, SurfaceMaterial) -> Unit

    public init(paint!: (UiContext, Rect, Shape, SurfaceMaterial) -> Unit) {
        painter = paint
    }

    public func paint(ctx: UiContext, frame: Rect, shape: Shape, material: SurfaceMaterial): Unit {
        painter(ctx, frame, shape, material)
    }
}

private class ResolvingMaterialProvider <: MaterialProvider {
    private let resolver: (Theme, SurfaceState) -> SurfaceMaterial

    init(resolver: (Theme, SurfaceState) -> SurfaceMaterial) {
        this.resolver = resolver
    }

    public func resolve(theme: Theme, state: SurfaceState): SurfaceMaterial {
        resolver(theme, state)
    }
}

/** Built-in material providers. Platform effects can implement `MaterialProvider` independently. */
public class Materials {
    /** A fixed solid fill whose foreground defaults to the active theme text color. */
    public static func solid(fill: Color, foreground!: ?Color = None): MaterialProvider {
        ResolvingMaterialProvider({theme, _ =>
            let resolvedForeground = match (foreground) {
                case Some(value) => value
                case None => theme.text
            }
            SurfaceMaterial(SurfaceStyle(fill), resolvedForeground, ink: Some(theme.inkColor()))
        })
    }

    /** A fixed `SurfaceStyle` whose foreground defaults to the active theme text color. */
    public static func solid(style: SurfaceStyle, foreground!: ?Color = None): MaterialProvider {
        ResolvingMaterialProvider({theme, _ =>
            let resolvedForeground = match (foreground) {
                case Some(value) => value
                case None => theme.text
            }
            SurfaceMaterial(style, resolvedForeground, ink: Some(theme.inkColor()))
        })
    }

    /** The theme's ordinary raised panel material. */
    public static func themeSurface(): MaterialProvider {
        ResolvingMaterialProvider({theme, _ =>
            SurfaceMaterial(theme.panelSurface(), theme.text, ink: Some(theme.inkColor()))
        })
    }

    /** The theme's primary action material, including hover/press and semantic ink colors. */
    public static func themePrimary(): MaterialProvider {
        ResolvingMaterialProvider({theme, state =>
            let appearance = resolveButtonAppearance(theme, ButtonRole.Primary, ButtonVisualState(
                hover: if (state.hovered) {1.0} else {0.0},
                press: if (state.pressed) {1.0} else {0.0},
                focused: state.focused
            ))
            SurfaceMaterial(appearance.surface, appearance.foreground, ink: Some(appearance.ink))
        })
    }
}

/**
 * A decorative composition surface. It paints material and supplies inherited foreground state, but
 * owns no focus, press or semantic action; input and focus identities remain those of its child.
 */
public class Surface <: Widget {
    private let child: Widget
    private var surfaceShape: Shape
    private var materialProvider: MaterialProvider
    private var customPainter: ?SurfacePainter
    private var clipPolicy: ClipPolicy
    private var frame = Rect.zero()

    public init(
        shape!: Shape = Shape.rectangle(),
        material!: MaterialProvider = Materials.themeSurface(),
        painter!: ?SurfacePainter = None,
        clip!: ClipPolicy = ClipPolicy.Unclipped,
        body!: () -> Unit
    ) {
        this.child = buildChild(body)
        this.surfaceShape = shape
        this.materialProvider = material
        this.customPainter = painter
        this.clipPolicy = clip
        emit(this)
    }

    public func shape(value: Shape): Surface {
        surfaceShape = value
        this
    }

    public func material(value: MaterialProvider): Surface {
        materialProvider = value
        this
    }

    /** Overrides only the background paint; Surface still owns material foreground and child layout. */
    public func painter(value: SurfacePainter): Surface {
        customPainter = Some(value)
        this
    }

    public func clip(value: ClipPolicy): Surface {
        clipPolicy = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size { child.measure(ctx, available) }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, rect)
    }

    /**
     * A shape-clipped Surface bounds every descendant to its frame. Only framework-created material
     * providers are eligible: an arbitrary provider can change paint extent behind the interface and
     * therefore stays fail-full. Fixed framework styles include their actual shadow displacement.
     */
    internal func retainedPaintProof(ctx: UiContext, frame: Rect): ?RetainedPaintProof {
        match (customPainter) {
            case Some(_) => return None
            case None => ()
        }
        match (clipPolicy) {
            case ClipPolicy.Unclipped => return None
            case ClipPolicy.Shape => ()
        }
        let material = match (materialProvider as ResolvingMaterialProvider) {
            case Some(provider) => provider.resolve(
                ctx.theme, SurfaceState(enabled: ctx.interactionsEnabled()))
            case None => return None
        }
        let offset = if (Int64(material.style.shadow.a) > 0) {
            material.style.shadowOffsetY
        } else {
            Float32(0.0)
        }
        // A finite, bounded displacement has a conservative symmetric proof. Unknown/NaN/extreme
        // values intentionally decline the proof so retained damage promotes to the full root.
        if (offset != offset || offset < -1000000.0 || offset > 1000000.0) { return None }
        Some(RetainedPaintProof(
            frame,
            effectRadius: CUI_SHADOW_CLEARANCE + abs(offset),
            proven: true))
    }

    public func draw(ctx: UiContext): Unit {
        let state = SurfaceState(enabled: ctx.interactionsEnabled())
        let material = materialProvider.resolve(ctx.theme, state)
        match (customPainter) {
            case Some(value) => value.paint(ctx, frame, surfaceShape, material)
            case None => drawMaterialSurface(ctx, frame, surfaceShape, material)
        }
        ctx.withControlContentEnvironment(ControlContentEnvironment(
            material.foreground,
            supportingForeground: Some(material.supportingForeground),
            enabled: state.enabled
        )) {=>
            withSurfaceClip(ctx, frame, clipPolicy) {=> child.draw(ctx)}
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool { child.handle(ctx, event) }
    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }
    public func focusableId(): ?String { child.focusableId() }
    public func focusableIds(): Array<String> { child.focusableIds() }
    public func interactionOwnerIds(): Array<String> { child.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { child.interactionsEnabled() }
}

protected func drawMaterialSurface(
    ctx: UiContext,
    frame: Rect,
    shape: Shape,
    material: SurfaceMaterial
): Unit {
    let style = material.style
    drawSurface(ctx, frame, SurfaceStyle(
        style.fill,
        border: style.border,
        radius: shape.cornerRadius(),
        borderWidth: style.borderWidth,
        shadow: style.shadow,
        shadowOffsetY: style.shadowOffsetY
    ))
}

protected func withSurfaceClip(ctx: UiContext, frame: Rect, policy: ClipPolicy, body: () -> Unit): Unit {
    match (policy) {
        case ClipPolicy.Unclipped => body()
        case ClipPolicy.Shape =>
            ctx.renderer.pushClip(frame)
            try { body() } finally { ctx.renderer.popClip() }
    }
}
