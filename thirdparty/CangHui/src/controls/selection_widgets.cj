package chui.controls

import sdl.{Color, FontSizes, Key, MouseButton, Rect, Size, UiEvent}
import chui.core.{AnimationSpec, Bindable, CUI_SMALL_H, ComponentControlAppearance,
    ComponentControlKind, ComponentControlState, ComponentControlStyle, ControlContentEnvironment, ControlSemantics,
    CursorShape, InteractionAnimation, Motion, ScrollBar, ScrollMotion, ScrollOptions, maxScrollOffset, Spring,
    SemanticActionKind, State, UiContext, Widget, requireControlId,
    advanceScrollMotion, applyWheelScroll, cancelScrollMotion, claimHoverIfInside, clampScrollOffset, drawFocusRing,
    drawSurface, drawVerticalScrollBar, emit, focusableControlIdentity, handlePointerClick, localState,
    recordControlSemantics, resolveComponentControlAppearance, reregisterFocusable, scrollLineIndex,
    scrollLineRemainder}

public class Checkbox <: Widget {
    private let label: ?String
    private let child: ?Widget
    private let checked: Bindable<Bool>
    private var controlId: String
    private let fillSpring: Spring
    private let interaction: InteractionAnimation
    private var customStyle: ?ComponentControlStyle
    private var animationSpec: AnimationSpec
    private var semanticLabel: String
    private var frame = Rect.zero()

    public init(label: String, checked: Bindable<Bool>) {
        this.label = Some(label)
        this.child = None
        this.checked = checked
        this.controlId = focusableControlIdentity("Checkbox:${label}")
        // The check fill scales in when ticked. Retained across rebuilds and started at the
        // current state, so a static first frame is settled (snapshot-stable).
        let checkStart: Float32 = if (checked.value) {
            1.0
        } else {
            0.0
        }
        this.fillSpring = localState<Spring>("${this.controlId}:fill") {Spring(checkStart)}.value
        this.interaction = localState<InteractionAnimation>("${this.controlId}:interaction") {
            InteractionAnimation()
        }.value
        this.customStyle = None
        this.animationSpec = AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate)
        this.semanticLabel = label
        emit(this)
    }

    /** Creates a checkbox with framework-owned indicator and arbitrary decorative label content. */
    public init(checked: Bindable<Bool>, body!: () -> Unit) {
        this.label = None
        this.checked = checked
        this.controlId = focusableControlIdentity("Checkbox:content")
        this.child = Some(buildDecorativeControlChild(body))
        let checkStart: Float32 = if (checked.value) { 1.0 } else { 0.0 }
        this.fillSpring = localState<Spring>("${this.controlId}:fill") {Spring(checkStart)}.value
        this.interaction = localState<InteractionAnimation>("${this.controlId}:interaction") {
            InteractionAnimation()
        }.value
        this.customStyle = None
        this.animationSpec = AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate)
        this.semanticLabel = ""
        emit(this)
    }

    /**
     * Sets an explicit focus and press identity; defaults are unique per build.
     * Throws `IllegalArgumentException` when `value` is empty.
     */
    public func key(value: String): Checkbox {
        requireControlId(value, "Checkbox")
        reregisterFocusable(controlId, value)
        controlId = value
        this
    }

    /** Overrides the component theme's state-aware control style. */
    public func controlStyle(value: ComponentControlStyle): Checkbox {
        customStyle = Some(value)
        this
    }

    /** Applies an automatic or exact interaction animation property. */
    public func animation(value: AnimationSpec): Checkbox {
        animationSpec = value
        this
    }

    /** Names decorative checkbox content for accessibility and headless semantic inspection. */
    public func accessibilityLabel(value: String): Checkbox {
        semanticLabel = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let spacing = ctx.theme.components.spacing
        let insets = ctx.resolve(spacing.selectionPadding)
        let gap = ctx.resolve(spacing.inlineGap)
        let pointSize = max(1.0, ctx.resolve(ctx.theme.components.typography.control))
        let content = match (label) {
            case Some(value) => Size(ctx.renderer.textWidth(value, pointSize: pointSize),
                ctx.renderer.textHeight(pointSize: pointSize))
            case None => match (child) {
                case Some(value) => value.measure(ctx, Size(
                    max(0.0, available.w - insets.horizontal() - spacing.indicatorSize - gap),
                    max(0.0, available.h - insets.vertical())))
                case None => Size.zero()
            }
        }
        Size(min(available.w, insets.horizontal() + spacing.indicatorSize + gap + content.w),
            min(available.h, max(spacing.controlMinHeight,
                insets.vertical() + max(spacing.indicatorSize, content.h))))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        match (child) {
            case Some(value) => value.layout(ctx, labelFrame(ctx))
            case None => ()
        }
    }

    public func draw(ctx: UiContext): Unit {
        let goal: Float32 = if (checked.value) {
            1.0
        } else {
            0.0
        }
        let t = fillSpring.animate(ctx, target: goal)
        let progress = interaction.animate(ctx, ctx.isHovered(controlId), ctx.isPressed(controlId), animationSpec)
        let appearance = resolveComponentControlAppearance(ctx.theme, ComponentControlKind.Checkbox,
            ComponentControlState(hover: progress.hover, press: progress.press,
                focused: ctx.hasFocus(controlId), selected: checked.value), styleOverride: customStyle)
        let box = indicatorFrame(ctx)
        drawSurface(ctx, box, appearance.surface)
        recordControlSemantics(ctx, frame, "Checkbox", ControlSemantics(
            "checkbox", label: semanticLabel, action: "Checkbox.toggle()",
            actionOwner: controlId, selected: Some(checked.value),
            typedActions: [SemanticActionKind.Focus, SemanticActionKind.Activate]
        ))
        // The fill grows from the centre to fill the box as it is ticked.
        if (t > 0.001) {
            let full = box.inset(4.0)
            let w = full.w * t
            let h = full.h * t
            let mark = Rect(full.centerX() - w / 2.0, full.centerY() - h / 2.0, w, h)
            ctx.renderer.fillRoundedRect(mark, appearance.focusRadius * t, appearance.indicator)
        }
        match (label) {
            case Some(value) =>
                let pointSize = max(1.0, ctx.resolve(ctx.theme.components.typography.control))
                let content = labelFrame(ctx)
                let textY = content.centerY() - ctx.renderer.textHeight(pointSize: pointSize) / 2.0
                ctx.renderer.text(value, content.x, textY, appearance.foreground, pointSize: pointSize)
            case None => match (child) {
                case Some(value) => ctx.withControlContentEnvironment(ControlContentEnvironment(
                    appearance.foreground,
                    role: "checkbox",
                    interactionOwner: controlId,
                    selected: checked.value,
                    focused: ctx.hasFocus(controlId),
                    hovered: progress.hover > 0.0,
                    pressed: progress.press > 0.0
                )) {=> value.draw(ctx)}
                case None => ()
            }
        }
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, box, appearance.focusRadius)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let appearance = currentAppearance(ctx)
        let box = indicatorFrame(ctx)
        if (handlePointerClick(ctx, event, frame, controlId, {=> checked.value = !checked.value},
            inkFrame: Some(box), inkRadius: appearance.focusRadius, inkColor: Some(appearance.ink))) {
            return true
        }
        match (event) {
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(controlId)) {
                    ctx.startInkRipple(controlId, box, box.centerX(), box.centerY(),
                        color: Some(appearance.ink), cornerRadius: appearance.focusRadius)
                    checked.value = !checked.value
                    return true
                }
            case UiEvent.KeyDown(Key.Space, _) =>
                if (ctx.hasFocus(controlId)) {
                    ctx.startInkRipple(controlId, box, box.centerX(), box.centerY(),
                        color: Some(appearance.ink), cornerRadius: appearance.focusRadius)
                    checked.value = !checked.value
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    private func indicatorFrame(ctx: UiContext): Rect {
        let insets = ctx.resolve(ctx.theme.components.spacing.selectionPadding)
        let size = ctx.theme.components.spacing.indicatorSize
        let legacy = checkboxIndicatorFrame(frame)
        Rect(legacy.x + insets.left, frame.y + insets.top, size, size)
    }

    private func labelFrame(ctx: UiContext): Rect {
        let insets = ctx.resolve(ctx.theme.components.spacing.selectionPadding)
        let indicator = indicatorFrame(ctx)
        let gap = ctx.resolve(ctx.theme.components.spacing.inlineGap)
        Rect(indicator.right() + gap, frame.y + insets.top,
            max(0.0, frame.right() - insets.right - indicator.right() - gap),
            max(0.0, frame.h - insets.vertical()))
    }

    private func currentAppearance(ctx: UiContext): ComponentControlAppearance {
        resolveComponentControlAppearance(ctx.theme, ComponentControlKind.Checkbox,
            ComponentControlState(
                hover: if (ctx.isHovered(controlId)) { 1.0 } else { 0.0 },
                press: if (ctx.isPressed(controlId)) { 1.0 } else { 0.0 },
                focused: ctx.hasFocus(controlId),
                selected: checked.value
            ), styleOverride: customStyle)
    }
}

internal func checkboxIndicatorFrame(frame: Rect): Rect {
    Rect(frame.x, frame.y + 7.0, 18.0, 18.0)
}

public class ListView <: Widget {
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private var scrollStateValue: State<Float32>
    private let controlId: String
    private let scrollBar: ScrollBar
    private let scrollMotion: ScrollMotion
    private var scrollPolicy = ScrollOptions.web()
    // The selection last scrolled into view, retained across rebuilds. Draw reveals the selected
    // row only when it differs — so a changed selection (however it changed) scrolls into view,
    // but plain wheel/drag scrolling (selection unchanged) is left alone.
    private let lastRevealed: State<Int64>
    private var frame = Rect.zero()

    public init(
        items: Array<String>,
        selected: Bindable<Int64>,
        scroll!: ?State<Float32> = None,
        key!: ?String = None
    ) {
        this.items = items
        this.selected = selected
        // Identity is optional and auto-derived by build order by default (like SegmentedControl and
        // TabView); pass `key` to give it a stable, addressable identity — e.g. to keep scroll/selection
        // state across a structural change or to coordinate scroll externally. Non-empty when given.
        let base = match (key) {
            case Some(value) =>
                requireControlId(value, "ListView")
                value
            case None => "ListView"
        }
        let cid = focusableControlIdentity(base)
        this.controlId = cid
        // Without an external scroll state, retain the offset across the per-frame rebuild via
        // localState keyed by control id — a fresh State each frame would reset the offset, so
        // wheel/drag scrolling would spring back every frame.
        let initialScroll = match (scroll) {
            case Some(value) => value
            case None => localState<Float32>("${cid}:scroll") {0.0}
        }
        this.scrollStateValue = initialScroll
        this.scrollBar = ScrollBar("ListView:${cid}:thumb")
        this.scrollMotion = localState<ScrollMotion>("${cid}:scroll-motion") {
            ScrollMotion(initialScroll.value)
        }.value
        this.lastRevealed = localState<Int64>("${cid}:revealed") {Int64.Min}
        emit(this)
    }

    /** Uses an externally owned scroll offset, enabling restoration and coordination. */
    public func scrollState(value: State<Float32>): ListView {
        scrollStateValue = value
        this
    }

    /** Selects smooth/immediate wheel motion, wheel step, duration and easing. */
    public func scrollOptions(value: ScrollOptions): ListView {
        scrollPolicy = value
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        advanceScrollMotion(ctx, scrollMotion, scrollStateValue, listContentHeight(items), listViewport(rect).h,
            scrollPolicy)
    }

    public func draw(ctx: UiContext): Unit {
        // Clamp writes only on change: this runs every frame, and the offset may be an
        // externally owned state whose observers should not fire for no-op writes.
        let clampedScroll = clampScrollOffset(scrollStateValue.value, listContentHeight(items),
            listViewport(frame).h)
        if (clampedScroll != scrollStateValue.value) {
            scrollStateValue.value = clampedScroll
            cancelScrollMotion(scrollMotion, scrollStateValue)
        }
        // Reveal the selected row when the selection changed since the last frame — this catches
        // selections driven from outside the list (e.g. app-level key routing) that never reached
        // this widget's own key handling. Unchanged selection (plain scrolling) is left untouched.
        if (selected.value != lastRevealed.value) {
            revealRow(selected.value)
            lastRevealed.value = selected.value
        }
        let semanticValue = if (selected.value >= 0 && selected.value < items.size) {
            items[selected.value]
        } else {
            ""
        }
        recordControlSemantics(ctx, frame, "ListView", ControlSemantics(
            "list", value: semanticValue, action: "", shortcut: "", actionOwner: controlId,
            typedActions: [SemanticActionKind.Focus]
        ))
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(controlId)))

        let viewport = listViewport(frame)
        ctx.renderer.pushClip(viewport)
        var i = scrollLineIndex(scrollStateValue.value)
        var y = viewport.y - scrollLineRemainder(scrollStateValue.value)
        while (i < items.size && y < viewport.bottom()) {
            drawRow(ctx, i, Rect(viewport.x, y, viewport.w, CUI_SMALL_H))
            y += CUI_SMALL_H
            i += 1
        }
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, frame, scrollStateValue.value, listContentHeight(items), viewport.h,
            active: scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, controlId, CursorShape.Interactive)
        let contentH = listContentHeight(items)
        let viewportH = listViewport(frame).h
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (scrollBar.press(ctx, frame, scrollStateValue, contentH, viewportH, x, y)) {
                    cancelScrollMotion(scrollMotion, scrollStateValue)
                    return true
                }
                if (frame.contains(x, y)) {
                    ctx.focus(controlId)
                    // Presses on the chrome inset around the rows are consumed without
                    // selecting; row math is only valid inside the viewport.
                    let viewport = listViewport(frame)
                    if (viewport.contains(x, y)) {
                        let idx = Int64((y - viewport.y + scrollStateValue.value) / CUI_SMALL_H)
                        if (idx >= 0 && idx < items.size) {
                            selected.value = idx
                        }
                    }
                    return true
                }
            case UiEvent.MouseMove(_, y) =>
                if (scrollBar.drag(ctx, frame, scrollStateValue, contentH, viewportH, y)) {
                    cancelScrollMotion(scrollMotion, scrollStateValue)
                    return true
                }
            case UiEvent.MouseWheel(_, wheelY, pointerX, pointerY) =>
                // Content that fits leaves the wheel to an enclosing scroller (no dead zone).
                if (frame.contains(pointerX, pointerY) && maxScrollOffset(contentH, viewportH) > 0.0) {
                    applyWheelScroll(ctx, scrollMotion, scrollStateValue, wheelY, contentH, viewportH, scrollPolicy)
                    return true
                }
            case UiEvent.KeyDown(Key.Up, _) => return moveSelection(ctx, -1)
            case UiEvent.KeyDown(Key.Down, _) => return moveSelection(ctx, 1)
            case UiEvent.KeyDown(Key.Home, _) => return setSelection(ctx, 0)
            case UiEvent.KeyDown(Key.End, _) => return setSelection(ctx, items.size - 1)
            case _ => ()
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    // Arrow/Home/End move the selection when the list holds keyboard focus, keeping the new
    // row scrolled into view.
    private func moveSelection(ctx: UiContext, delta: Int64): Bool {
        if (!ctx.hasFocus(controlId) || items.isEmpty()) {
            return false
        }
        applySelection(clampIndex(selected.value + delta))
        true
    }

    private func setSelection(ctx: UiContext, index: Int64): Bool {
        if (!ctx.hasFocus(controlId) || items.isEmpty()) {
            return false
        }
        applySelection(clampIndex(index))
        true
    }

    private func clampIndex(index: Int64): Int64 {
        if (items.size <= 0) {
            0
        } else if (index < 0) {
            0
        } else if (index >= items.size) {
            items.size - 1
        } else {
            index
        }
    }

    private func applySelection(index: Int64): Unit {
        selected.value = index
        // Scroll immediately (this frame's handle) and sync lastRevealed so draw does not redo it.
        revealRow(index)
        lastRevealed.value = index
    }

    // Scrolls the given row's band just into view, adjusting the offset minimally.
    private func revealRow(index: Int64): Unit {
        let viewportH = listViewport(frame).h
        let rowTop = Float32(index) * CUI_SMALL_H
        let rowBottom = rowTop + CUI_SMALL_H
        var scroll = scrollStateValue.value
        if (rowTop < scroll) {
            scroll = rowTop
        } else if (rowBottom > scroll + viewportH) {
            scroll = rowBottom - viewportH
        }
        scrollStateValue.value = clampScrollOffset(scroll, listContentHeight(items), viewportH)
        cancelScrollMotion(scrollMotion, scrollStateValue)
    }

    private func drawRow(ctx: UiContext, i: Int64, row: Rect): Unit {
        if (i == selected.value) {
            ctx.renderer.fillRoundedRect(row.inset(2.0), ctx.theme.smallRadius, ctx.theme.accent)
            drawRowText(ctx, items[i], row, ctx.theme.accentText)
        } else {
            drawRowText(ctx, items[i], row, ctx.theme.text)
        }
    }
}

private func drawRowText(ctx: UiContext, text: String, row: Rect, color: Color): Unit {
    let textY = row.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.BODY) / 2.0
    ctx.renderer.text(text, row.x + 6.0, textY, color, pointSize: FontSizes.BODY)
}

private func listContentHeight(items: Array<String>): Float32 {
    Float32(items.size) * CUI_SMALL_H
}

private func listViewport(frame: Rect): Rect {
    Rect(frame.x + 4.0, frame.y + 6.0, max(0.0, frame.w - 12.0), max(0.0, frame.h - 12.0))
}
