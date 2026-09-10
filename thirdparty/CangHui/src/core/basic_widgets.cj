package chui.core

import sdl.{FontSizes, Rect, Size, SurfaceStyle, UiEvent}

/**
 * An empty, flexible widget: it measures zero and absorbs a share of its stack's leftover space,
 * pushing its siblings apart — the idiomatic way to right-align a row's tail or split a toolbar.
 */
public class Spacer <: Widget {
    public init() {
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func isFlexible(): Bool {
        true
    }
}

/*
 * A push button: a themed surface with a centered title, firing `onClick` when the primary press that
 * started inside is also released inside (dragging off before release cancels). Focusable — Enter and
 * Space activate it while focused. `role` selects semantic coloring (primary accent, danger); `style`
 * overrides the surface entirely. The focus/press identity defaults to a per-build-position value;
 * `key` pins one that survives tree reshapes.
 */
public class Button <: Widget {
    private let title: ?String
    private let child: ?Widget
    private var buttonRole: ButtonRole
    private var customStyle: ?SurfaceStyle
    private var customButtonStyle: ?ButtonStyle
    private var pointSize: Length
    private var contentPaddingOverride: ?LengthInsets
    private var minWidthOverride: ?Float32
    private var minHeightOverride: ?Float32
    private var controlId: String
    private let interactionSurface: InteractionSurface
    private let interactionMaterial: ButtonInteractionMaterial
    private let interaction: InteractionAnimation
    private var animationSpec: AnimationSpec
    private var semanticLabel: String
    private var frame = Rect.zero()

    public init(
        title: String,
        onClick: () -> Unit,
        role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None,
        fontSize!: Length = Length(FontSizes.CONTROL, LengthUnit.Fp)
    ) {
        this.title = Some(title)
        this.child = None
        this.buttonRole = role
        this.customStyle = style
        this.customButtonStyle = None
        this.pointSize = fontSize
        this.contentPaddingOverride = None
        this.minWidthOverride = None
        this.minHeightOverride = None
        this.controlId = focusableControlIdentity("Button:${title}")
        this.interactionMaterial = ButtonInteractionMaterial()
        this.interactionSurface = buildButtonInteractionSurface(onClick, this.controlId)
        this.interaction = localState<InteractionAnimation>("${this.controlId}:interaction") {
            InteractionAnimation()
        }.value
        this.animationSpec = AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate)
        this.semanticLabel = title
        emit(this)
    }

    /**
     * Creates a button whose face is arbitrary decorative CangHui content. The outer button remains the
     * sole focus and activation owner; focusable descendants are removed from the Tab ring and do not
     * receive events. Use this for icon/text/badge composition, not for nested interactive controls.
     */
    public init(
        onClick!: () -> Unit,
        role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None,
        body!: () -> Unit
    ) {
        this.title = None
        let focusStart = focusableCountNow()
        this.child = Some(buildChild(body))
        for (id in focusablesSince(focusStart)) {
            unregisterFocusable(id)
        }
        this.buttonRole = role
        this.customStyle = style
        this.customButtonStyle = None
        this.pointSize = Length(FontSizes.CONTROL, LengthUnit.Fp)
        this.contentPaddingOverride = None
        this.minWidthOverride = None
        this.minHeightOverride = None
        this.controlId = focusableControlIdentity("Button:content")
        this.interactionMaterial = ButtonInteractionMaterial()
        this.interactionSurface = buildButtonInteractionSurface(onClick, this.controlId)
        this.interaction = localState<InteractionAnimation>("${this.controlId}:interaction") {
            InteractionAnimation()
        }.value
        this.animationSpec = AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate)
        this.semanticLabel = ""
        emit(this)
    }

    /**
     * Sets an explicit focus and press identity. Defaults are already unique per build;
     * set one when identity must survive tree reshapes (for example a button that moves
     * between containers). Throws `IllegalArgumentException` when `value` is empty.
     */
    public func key(value: String): Button {
        requireControlId(value, "Button")
        let _ = interactionSurface.key(value)
        controlId = value
        this
    }

    /** Applies semantic button coloring. */
    public func role(value: ButtonRole): Button {
        buttonRole = value
        this
    }

    /** Names a slot-based button for accessibility and headless semantic inspection. */
    public func accessibilityLabel(value: String): Button {
        semanticLabel = value
        this
    }

    /** Overrides the theme-derived button surface. */
    public func style(value: SurfaceStyle): Button {
        customStyle = Some(value)
        customButtonStyle = None
        this
    }

    /** Overrides the theme's state-aware button style for this button. */
    public func buttonStyle(value: ButtonStyle): Button {
        customButtonStyle = Some(value)
        customStyle = None
        this
    }

    /** Overrides the content inset used by title and slot-based buttons. */
    public func contentPadding(value: LengthInsets): Button {
        contentPaddingOverride = Some(value)
        this
    }

    /** Overrides the minimum control size while retaining content-based measurement. */
    public func minControlSize(width!: Float32, height!: Float32): Button {
        minWidthOverride = Some(max(0.0, width))
        minHeightOverride = Some(max(0.0, height))
        this
    }

    /** Sets the label font size, e.g. `.fontSize(15.fp)`. */
    public func fontSize(value: Length): Button {
        pointSize = value
        this
    }

    /** Sets the label font size in font pixels. */
    public func fontSize(value: Float32): Button {
        fontSize(Length(value, LengthUnit.Fp))
    }

    /** Applies an automatic or explicit hover/press animation property. */
    public func animation(value: AnimationSpec): Button {
        animationSpec = value
        this
    }

    /** Applies an exact playback duration and curve. */
    public func animation(duration: UInt64, easing!: Easing = Motion.standard): Button {
        animation(AnimationSpec(duration: duration, easing: easing))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let layoutStyle = ctx.theme.components.buttonLayout
        let insets = ctx.resolve(match (contentPaddingOverride) {
            case Some(value) => value
            case None => layoutStyle.contentPadding
        })
        let minWidth = match (minWidthOverride) {
            case Some(value) => value
            case None => layoutStyle.minWidth
        }
        let minHeight = match (minHeightOverride) {
            case Some(value) => value
            case None => layoutStyle.minHeight
        }
        let contentSize = match (title) {
            case Some(value) => Size(ctx.renderer.textWidth(value, pointSize: max(1.0, ctx.resolve(pointSize))),
                ctx.renderer.textHeight(pointSize: max(1.0, ctx.resolve(pointSize))))
            case None => match (child) {
                case Some(value) => value.measure(ctx, Size(max(0.0, available.w - insets.horizontal()),
                    max(0.0, available.h - insets.vertical())))
                case None => Size.zero()
            }
        }
        Size(min(available.w, max(minWidth, contentSize.w + insets.horizontal())),
            min(available.h, max(minHeight, contentSize.h + insets.vertical())))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        interactionSurface.layout(ctx, rect)
        match (child) {
            case Some(value) => value.layout(ctx, frame.inset(ctx.resolve(match (contentPaddingOverride) {
                case Some(padding) => padding
                case None => ctx.theme.components.buttonLayout.contentPadding
            })))
            case None => ()
        }
    }

    public func draw(ctx: UiContext): Unit {
        let progress = interaction.animate(ctx, ctx.isHovered(controlId), ctx.isPressed(controlId), animationSpec)
        let state = ButtonVisualState(hover: progress.hover, press: progress.press,
            focused: ctx.hasFocus(controlId))
        let appearance = buttonAppearance(ctx, state)
        let visualFrame = match (title) {
            case Some(_) => animatedButtonFrame(frame, ctx.theme.motionLevel, progress)
            case None => frame
        }
        drawSurface(ctx, visualFrame, appearance.surface)
        recordControlSemantics(ctx, visualFrame, "Button", ControlSemantics(
            "button", label: semanticLabel, action: "Button.activate()",
            actionOwner: controlId,
            typedActions: [SemanticActionKind.Focus, SemanticActionKind.Activate]
        ))
        match (title) {
            case Some(value) => ctx.renderer.textCenter(value, visualFrame, appearance.foreground,
                pointSize: max(1.0, ctx.resolve(pointSize)))
            case None => match (child) {
                case Some(value) => ctx.withControlContentEnvironment(ControlContentEnvironment(
                    appearance.foreground,
                    role: "button",
                    interactionOwner: controlId,
                    focused: state.focused,
                    hovered: state.hover > 0.0,
                    pressed: state.press > 0.0
                )) {=> value.draw(ctx)}
                case None => ()
            }
        }
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, visualFrame, appearance.focusRadius)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let appearance = buttonAppearance(ctx, ButtonVisualState(
            hover: if (ctx.isHovered(controlId)) { 1.0 } else { 0.0 },
            press: if (ctx.isPressed(controlId)) { 1.0 } else { 0.0 },
            focused: ctx.hasFocus(controlId)
        ))
        syncButtonInteractionSurface(interactionSurface, interactionMaterial, appearance)
        interactionSurface.handle(ctx, event)
    }

    public func focusableId(): ?String {
        interactionSurface.focusableId()
    }

    /**
     * Buttons may fill a column's width, but a tall horizontal row must not enlarge
     * their hit target by accident. `.height(...)` and `.fillHeight()` remain explicit
     * opt-ins through the normal modifier layer.
     */
    public func acceptsStretch(axis: Axis): Bool {
        match (axis) {
            case Axis.Horizontal => true
            case Axis.Vertical => false
        }
    }

    private func buttonAppearance(ctx: UiContext, state: ButtonVisualState): ButtonAppearance {
        resolveButtonAppearance(ctx.theme, buttonRole, state,
            styleOverride: customButtonStyle, surfaceOverride: customStyle)
    }
}

protected class ButtonInteractionMaterial <: MaterialProvider {
    private var value: ?SurfaceMaterial = None

    func update(appearance: ButtonAppearance): Unit {
        value = Some(SurfaceMaterial(appearance.surface, appearance.foreground, ink: Some(appearance.ink)))
    }

    public func resolve(theme: Theme, _: SurfaceState): SurfaceMaterial {
        match (value) {
            case Some(current) => current
            case None => SurfaceMaterial(theme.panelSurface(), theme.text, ink: Some(theme.inkColor()))
        }
    }
}

private class ButtonInteractionSurfaceCapture {
    var value: ?InteractionSurface = None
}

/*
 * Builds the interaction owner in an isolated declaration block so the delegate does not become a
 * visible sibling of the Button recipe. Button and IconButton retain their existing rendering and
 * semantics while sharing InteractionSurface's focus, release-inside, cancellation and Ink protocol.
 */
protected func buildButtonInteractionSurface(action: () -> Unit, id: String): InteractionSurface {
    let captured = ButtonInteractionSurfaceCapture()
    let _ = buildChild({=>
        let value = InteractionSurface(action: action, key: Some(id)) { Spacer() }
        captured.value = Some(value)
    })
    captured.value.getOrThrow()
}

/** Keeps the delegated Ink material and geometry equal to the current ButtonStyle appearance. */
protected func syncButtonInteractionSurface(
    interactionSurface: InteractionSurface,
    interactionMaterial: ButtonInteractionMaterial,
    appearance: ButtonAppearance
): Unit {
    interactionMaterial.update(appearance)
    let _ = interactionSurface.surface(
        Shape.rounded(appearance.focusRadius),
        interactionMaterial,
        clip: ClipPolicy.Shape
    )
}

protected func animatedButtonFrame(frame: Rect, level: MotionLevel, progress: InteractionProgress): Rect {
    let amount = level.amplitude()
    let lift = progress.hover * amount * 0.9
    let inset = progress.press * amount * 0.75
    Rect(frame.x + inset, frame.y - lift + inset, max(0.0, frame.w - inset * 2.0),
        max(0.0, frame.h - inset * 2.0))
}
