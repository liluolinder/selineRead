package chui.controls

import sdl.{Key, Rect, Size, UiEvent}
import chui.core.{AnimationSpec, Bindable, ComponentControlAppearance, ComponentControlKind, ComponentControlState,
    ComponentControlStyle, ControlContentEnvironment, ControlSemantics, InteractionAnimation, Motion,
    SemanticActionKind, UiContext, Widget, drawFocusRing, drawSurface, emit, handlePointerClick, localState,
    recordControlSemantics,
    registerFocusable, resolveComponentControlAppearance, resolveControlKey}

/*
 * A selectable filter tag — a rounded pill bound to a `Bindable<Bool>`. Clicking (or Space/Enter while
 * focused) toggles it; selected it fills with the accent, unselected it is an outlined field. A row of
 * chips forms a set of toggle filters.
 */
public class Chip <: Widget {
    private let text: ?String
    private let child: ?Widget
    private let selected: Bindable<Bool>
    private let id: String
    private let interaction: InteractionAnimation
    private var customStyle: ?ComponentControlStyle
    private var animationSpec: AnimationSpec
    private var semanticLabel: String
    private var frame = Rect.zero()

    public init(text: String, selected: Bindable<Bool>, key!: ?String = None) {
        this.text = Some(text)
        this.child = None
        this.selected = selected
        this.id = resolveControlKey(key, "Chip")
        registerFocusable(this.id)
        this.interaction = localState<InteractionAnimation>("${this.id}:interaction") {
            InteractionAnimation()
        }.value
        this.customStyle = None
        this.animationSpec = AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate)
        this.semanticLabel = text
        emit(this)
    }

    /** Creates a selectable chip with arbitrary decorative content. */
    public init(selected: Bindable<Bool>, key!: ?String = None, body!: () -> Unit) {
        this.text = None
        this.selected = selected
        this.id = resolveControlKey(key, "Chip")
        registerFocusable(this.id)
        this.child = Some(buildDecorativeControlChild(body))
        this.interaction = localState<InteractionAnimation>("${this.id}:interaction") {
            InteractionAnimation()
        }.value
        this.customStyle = None
        this.animationSpec = AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate)
        this.semanticLabel = ""
        emit(this)
    }

    /** Overrides the component theme's state-aware control style. */
    public func controlStyle(value: ComponentControlStyle): Chip {
        customStyle = Some(value)
        this
    }

    /** Applies an automatic or exact interaction animation property. */
    public func animation(value: AnimationSpec): Chip {
        animationSpec = value
        this
    }

    /** Names decorative chip content for accessibility and headless semantic inspection. */
    public func accessibilityLabel(value: String): Chip {
        semanticLabel = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let spacing = ctx.theme.components.spacing
        let insets = ctx.resolve(spacing.compactPadding)
        let pointSize = max(1.0, ctx.resolve(ctx.theme.components.typography.control))
        let content = match (text) {
            case Some(value) => Size(ctx.renderer.textWidth(value, pointSize: pointSize),
                ctx.renderer.textHeight(pointSize: pointSize))
            case None => match (child) {
                case Some(value) => value.measure(ctx, Size(max(0.0, available.w - insets.horizontal()),
                    max(0.0, available.h - insets.vertical())))
                case None => Size.zero()
            }
        }
        Size(min(available.w, content.w + insets.horizontal()),
            min(available.h, max(spacing.compactMinHeight, content.h + insets.vertical())))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        match (child) {
            case Some(value) => value.layout(ctx, frame.inset(ctx.resolve(ctx.theme.components.spacing.compactPadding)))
            case None => ()
        }
    }

    public func isFlexible(): Bool {
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    public func draw(ctx: UiContext): Unit {
        let on = selected.get()
        let progress = interaction.animate(ctx, ctx.isHovered(id), ctx.isPressed(id), animationSpec)
        let appearance = resolveComponentControlAppearance(ctx.theme, ComponentControlKind.Chip,
            ComponentControlState(hover: progress.hover, press: progress.press,
                focused: ctx.hasFocus(id), selected: on), styleOverride: customStyle)
        drawSurface(ctx, frame, appearance.surface)
        recordControlSemantics(ctx, frame, "Chip", ControlSemantics(
            "checkbox", label: semanticLabel, action: "Chip.toggle()",
            actionOwner: id, selected: Some(on),
            typedActions: [SemanticActionKind.Focus, SemanticActionKind.Activate]
        ))
        if (ctx.showFocusRing(id)) {
            drawFocusRing(ctx, frame, appearance.focusRadius)
        }
        match (text) {
            case Some(value) =>
                let pointSize = max(1.0, ctx.resolve(ctx.theme.components.typography.control))
                let tw = ctx.renderer.textWidth(value, pointSize: pointSize)
                let ty = frame.centerY() - ctx.renderer.textHeight(pointSize: pointSize) / 2.0
                ctx.renderer.text(value, frame.centerX() - tw / 2.0, ty, appearance.foreground,
                    pointSize: pointSize)
            case None => match (child) {
                case Some(value) => ctx.withControlContentEnvironment(ControlContentEnvironment(
                    appearance.foreground,
                    role: "checkbox",
                    interactionOwner: id,
                    selected: on,
                    focused: ctx.hasFocus(id),
                    hovered: progress.hover > 0.0,
                    pressed: progress.press > 0.0
                )) {=> value.draw(ctx)}
                case None => ()
            }
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let appearance = currentAppearance(ctx)
        if (handlePointerClick(ctx, event, frame, id, {=> toggle()},
            inkRadius: appearance.focusRadius, inkColor: Some(appearance.ink))) {
            return true
        }
        match (event) {
            case UiEvent.KeyDown(Key.Space, _) => return toggleIfFocused(ctx)
            case UiEvent.KeyDown(Key.Enter, _) => return toggleIfFocused(ctx)
            case _ => ()
        }
        false
    }

    private func toggle(): Unit {
        selected.value = !selected.get()
    }

    private func toggleIfFocused(ctx: UiContext): Bool {
        if (ctx.hasFocus(id)) {
            let appearance = currentAppearance(ctx)
            ctx.startInkRipple(id, frame, frame.centerX(), frame.centerY(),
                color: Some(appearance.ink), cornerRadius: appearance.focusRadius)
            toggle()
            return true
        }
        false
    }

    private func currentAppearance(ctx: UiContext): ComponentControlAppearance {
        resolveComponentControlAppearance(ctx.theme, ComponentControlKind.Chip,
            ComponentControlState(
                hover: if (ctx.isHovered(id)) { 1.0 } else { 0.0 },
                press: if (ctx.isPressed(id)) { 1.0 } else { 0.0 },
                focused: ctx.hasFocus(id),
                selected: selected.get()
            ), styleOverride: customStyle)
    }
}
