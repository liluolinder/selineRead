package chui.controls

import sdl.{Color, FontSizes, Key, MouseButton, Pen, Rect, Size, UiEvent}
import chui.core.{AnimationSpec, Animator, Bindable, CUI_CONTROL_H, ControlSemantics, CursorShape, Motion, Spring,
    SemanticActionKind, UiContext, Widget, requireControlId, claimHoverIfInside, drawFocusRing, drawSurface, emit,
    focusableControlIdentity, handlePointerClick, localState, recordControlSemantics, reregisterFocusable,
    registerFocusable, resolveControlKey}

private let SWITCH_TRACK_W: Float32 = 40.0
private let SWITCH_TRACK_H: Float32 = 22.0
private let PICKER_MIN_W: Float32 = 120.0
private let PICKER_BUTTON_W: Float32 = 34.0
private let STEPPER_BUTTON_W: Float32 = 36.0

private class DirectionalTextMotion {
    private var currentText: String
    private var previousText: String
    private var direction: Float32 = 1.0
    private let animator = Animator(1.0)

    init(text: String) {
        currentText = text
        previousText = text
    }

    func change(next: String, delta: Int64): Unit {
        if (next == currentText) {
            return
        }
        previousText = currentText
        currentText = next
        direction = if (delta >= 0) { 1.0 } else { -1.0 }
        animator.reset(0.0)
    }

    func sync(next: String): Unit {
        if (next != currentText && animator.settled()) {
            currentText = next
            previousText = next
            animator.reset(1.0)
        }
    }

    func draw(ctx: UiContext, frame: Rect, color: Color): Unit {
        sync(currentText)
        let t = animator.animate(ctx, target: 1.0,
            spec: AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate))
        if (t >= 0.999) {
            drawTextAt(ctx, currentText, frame, frame.centerY(), color)
            return
        }
        let travel = min(18.0, frame.h * 0.5)
        drawTextAt(ctx, previousText, frame, frame.centerY() - direction * travel * t,
            color.withAlpha(Int64(255.0 * (1.0 - t))))
        drawTextAt(ctx, currentText, frame, frame.centerY() + direction * travel * (1.0 - t),
            color.withAlpha(Int64(255.0 * min(1.0, 0.35 + t))))
    }

    private func drawTextAt(ctx: UiContext, text: String, frame: Rect, centerY: Float32, color: Color): Unit {
        let width = ctx.renderer.textWidth(text, pointSize: FontSizes.CONTROL)
        let height = ctx.renderer.textHeight(pointSize: FontSizes.CONTROL)
        ctx.renderer.text(text, frame.centerX() - width / 2.0, centerY - height / 2.0,
            color, pointSize: FontSizes.CONTROL)
    }
}

/** A binary desktop switch bound to a Boolean state. */
public class Switch <: Widget {
    private let label: String
    private let checked: Bindable<Bool>
    private var controlId: String
    private var semanticLabel: String
    private let knobSpring: Spring
    private var frame = Rect.zero()

    public init(label: String, checked: Bindable<Bool>) {
        this.label = label
        this.checked = checked
        let cid = focusableControlIdentity("Switch:${label}")
        this.controlId = cid
        this.semanticLabel = label
        // The knob position animates between 0 (off) and 1 (on). Retained so the slide
        // survives per-frame rebuilds; started at the current state so a static first frame
        // is already settled (no animation, snapshot-stable).
        let start: Float32 = if (checked.value) {
            1.0
        } else {
            0.0
        }
        this.knobSpring = localState<Spring>("${cid}:knob") {Spring(start)}.value
        emit(this)
    }

    /** Sets an explicit focus and press identity; defaults are unique per build. */
    public func key(value: String): Switch {
        validateControlId(value, "Switch")
        reregisterFocusable(controlId, value)
        controlId = value
        this
    }

    /** Overrides the semantic name without changing the visible label. */
    public func accessibilityLabel(value: String): Switch {
        semanticLabel = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(min(available.w, SWITCH_TRACK_W + 12.0 + ctx.renderer.textWidth(label)), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let goal: Float32 = if (checked.value) {
            1.0
        } else {
            0.0
        }
        let t = knobSpring.animate(ctx, target: goal)

        recordControlSemantics(ctx, frame, "Switch", ControlSemantics(
            "switch", label: semanticLabel,
            value: if (checked.value) { "on" } else { "off" },
            action: "Switch.toggle()", actionOwner: controlId,
            selected: Some(checked.value),
            typedActions: [SemanticActionKind.Focus, SemanticActionKind.Activate]
        ))

        let track = trackFrame()
        // Track colour and knob position share the spring, so both cross together smoothly.
        ctx.renderer.fillRoundedRect(track, SWITCH_TRACK_H / 2.0, ctx.theme.panelEdge.lerp(ctx.theme.accent, t))
        let offX = track.x + 11.0
        let onX = track.right() - 11.0
        let knobX = offX + (onX - offX) * t
        ctx.renderer.fillCircle(knobX, track.centerY() + 1.0, 8.5, ctx.theme.shadow.withAlpha(28))
        ctx.renderer.fillCircle(knobX, track.centerY(), 8.0, ctx.theme.panelRaised)
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(label, track.right() + 12.0, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, track, SWITCH_TRACK_H / 2.0)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let track = trackFrame()
        toggleInteraction(ctx, event, frame, controlId, {=> checked.value = !checked.value},
            track, SWITCH_TRACK_H / 2.0)
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    private func trackFrame(): Rect {
        switchTrackFrame(frame)
    }
}

internal func switchTrackFrame(frame: Rect): Rect {
    Rect(frame.x, frame.centerY() - SWITCH_TRACK_H / 2.0, SWITCH_TRACK_W, SWITCH_TRACK_H)
}

/** One option in a mutually exclusive integer-valued selection group. */
public class RadioButton <: Widget {
    private let label: String
    private let selected: Bindable<Int64>
    private let optionValue: Int64
    private var controlId: String
    private var semanticLabel: String
    private let dotSpring: Spring
    private var frame = Rect.zero()

    public init(label: String, selected: Bindable<Int64>, value: Int64) {
        this.label = label
        this.selected = selected
        this.optionValue = value
        this.controlId = focusableControlIdentity("RadioButton:${label}:${value}")
        this.semanticLabel = label
        // The inner dot scales in when this option becomes selected. Retained across rebuilds and
        // started at the current state, so a static first frame is settled (snapshot-stable).
        let dotStart: Float32 = if (selected.value == value) {
            1.0
        } else {
            0.0
        }
        this.dotSpring = localState<Spring>("${this.controlId}:dot") {Spring(dotStart)}.value
        emit(this)
    }

    /** Sets an explicit focus and press identity; defaults are unique per build. */
    public func key(value: String): RadioButton {
        validateControlId(value, "RadioButton")
        reregisterFocusable(controlId, value)
        controlId = value
        this
    }

    /** Overrides the semantic name without changing the visible label. */
    public func accessibilityLabel(value: String): RadioButton {
        semanticLabel = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(min(available.w, ctx.renderer.textWidth(label) + 34.0), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let goal: Float32 = if (isSelected()) {
            1.0
        } else {
            0.0
        }
        let t = dotSpring.animate(ctx, target: goal)
        recordControlSemantics(ctx, frame, "RadioButton", ControlSemantics(
            "radio", label: semanticLabel, value: optionValue.toString(),
            action: "RadioButton.select()", actionOwner: controlId,
            selected: Some(isSelected()),
            typedActions: [SemanticActionKind.Focus, SemanticActionKind.Activate]
        ))
        let centerX = frame.x + 9.0
        let centerY = frame.centerY()
        ctx.renderer.fillCircle(centerX, centerY, 9.0, ctx.theme.field)
        ctx.renderer.strokeCircle(centerX, centerY, 8.5,
            Pen(width: 1.5, color: ctx.theme.panelEdge.lerp(ctx.theme.accent, t)), segments: 32)
        // Grows from nothing to the full 4.5-radius dot as the option is selected.
        if (t > 0.001) {
            ctx.renderer.fillCircle(centerX, centerY, 4.5 * t, ctx.theme.accent)
        }
        let textY = centerY - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(label, frame.x + 26.0, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, Rect(centerX - 9.0, centerY - 9.0, 18.0, 18.0), 9.0)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let indicator = Rect(frame.x, frame.centerY() - 9.0, 18.0, 18.0)
        toggleInteraction(ctx, event, frame, controlId, {=> selected.value = optionValue}, indicator, 9.0)
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    private func isSelected(): Bool {
        selected.value == optionValue
    }
}

/** A compact previous/next picker for a finite string collection. */
public class Picker <: Widget {
    private let id: String
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private let textMotion: DirectionalTextMotion
    private var semanticLabel: String
    private var frame = Rect.zero()

    public init(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None) {
        this.id = resolveControlKey(key, "Picker")
        this.items = items
        this.selected = selected
        let initial = if (items.isEmpty()) { "—" } else { items[clampControlIndex(selected.value, items.size)] }
        this.textMotion = localState<DirectionalTextMotion>("Picker:${this.id}:text-motion") {
            DirectionalTextMotion(initial)
        }.value
        this.semanticLabel = ""
        registerFocusable(this.id)
        emit(this)
    }

    /** Names this picker for accessibility and headless semantic inspection. */
    public func accessibilityLabel(value: String): Picker {
        semanticLabel = value
        this
    }

    // Content-adaptive width: wide enough for the longest item between the two chevron
    // zones (stable across selection changes), instead of a fixed generous default.
    public func measure(ctx: UiContext, available: Size): Size {
        var textW: Float32 = 0.0
        for (item in items) {
            textW = max(textW, ctx.renderer.textWidth(item, pointSize: FontSizes.CONTROL))
        }
        let natural = max(PICKER_MIN_W, textW + PICKER_BUTTON_W * 2.0 + 16.0)
        Size(min(available.w, natural), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(id)))
        let label = if (items.isEmpty()) {
            "—"
        } else {
            items[currentIndex()]
        }
        recordControlSemantics(ctx, frame, "Picker", ControlSemantics(
            "combobox", label: if (semanticLabel.isEmpty()) { label } else { semanticLabel },
            value: label, action: "Picker.move()", shortcut: "Left|Right",
            actionOwner: id,
            typedActions: [SemanticActionKind.Focus, SemanticActionKind.Decrement,
                SemanticActionKind.Increment]
        ))
        textMotion.sync(label)
        // Item text comes from application data; clip it so a long item cannot paint
        // over the chevrons or escape the control surface.
        let buttonW = pickerButtonWidth()
        let labelArea = Rect(frame.x + buttonW, frame.y, max(0.0, frame.w - buttonW * 2.0), frame.h)
        ctx.renderer.pushClip(labelArea)
        textMotion.draw(ctx, labelArea, ctx.theme.text)
        ctx.renderer.popClip()
        ctx.renderer.textCenter("‹", leftButton(), ctx.theme.mutedText, pointSize: FontSizes.TITLE)
        ctx.renderer.textCenter("›", rightButton(), ctx.theme.mutedText, pointSize: FontSizes.TITLE)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        if (handlePointerClick(ctx, event, leftButton(), "${id}:previous", {=> move(-1)},
            inkRadius: ctx.theme.controlRadius, inkColor: Some(ctx.theme.inkColor()), focusTarget: Some(id))) {
            return true
        }
        if (handlePointerClick(ctx, event, rightButton(), "${id}:next", {=> move(1)},
            inkRadius: ctx.theme.controlRadius, inkColor: Some(ctx.theme.inkColor()), focusTarget: Some(id))) {
            return true
        }
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(id)
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) =>
                if (ctx.hasFocus(id)) {
                    move(-1)
                    return true
                }
            case UiEvent.KeyDown(Key.Right, _) =>
                if (ctx.hasFocus(id)) {
                    move(1)
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    private func move(delta: Int64): Unit {
        if (items.isEmpty()) {
            return
        }
        let next = (currentIndex() + delta + items.size) % items.size
        textMotion.change(items[next], delta)
        selected.value = next
    }

    private func currentIndex(): Int64 {
        clampControlIndex(selected.value, items.size)
    }

    private func leftButton(): Rect {
        let width = pickerButtonWidth()
        Rect(frame.x, frame.y, width, frame.h)
    }

    private func rightButton(): Rect {
        let width = pickerButtonWidth()
        Rect(frame.right() - width, frame.y, width, frame.h)
    }

    private func pickerButtonWidth(): Float32 {
        min(PICKER_BUTTON_W, max(0.0, frame.w / 2.0))
    }
}

/** An integer value editor with decrement/increment buttons and keyboard support. */
public class Stepper <: Widget {
    private let id: String
    private let value: Bindable<Int64>
    private var lowerBound: Int64 = Int64.Min
    private var upperBound: Int64 = Int64.Max
    private var stepSize: Int64 = 1
    private let textMotion: DirectionalTextMotion
    private var semanticLabel: String
    private var frame = Rect.zero()

    public init(
        value: Bindable<Int64>,
        key!: ?String = None,
        lower!: Int64 = Int64.Min,
        upper!: Int64 = Int64.Max,
        step!: Int64 = 1
    ) {
        if (step <= 0) {
            throw IllegalArgumentException("Stepper step must be greater than zero")
        }
        this.id = resolveControlKey(key, "Stepper")
        this.value = value
        this.lowerBound = min(lower, upper)
        this.upperBound = max(lower, upper)
        this.stepSize = step
        this.textMotion = localState<DirectionalTextMotion>("Stepper:${this.id}:text-motion") {
            DirectionalTextMotion("${value.value}")
        }.value
        this.semanticLabel = ""
        registerFocusable(this.id)
        // Clamp the initial value into range, like range() does (write-on-change to avoid churn).
        let clamped = clampInt(value.value)
        if (clamped != value.value) {
            value.value = clamped
        }
        emit(this)
    }

    /** Names this numeric editor for accessibility and headless semantic inspection. */
    public func accessibilityLabel(value: String): Stepper {
        semanticLabel = value
        this
    }

    /** Sets the inclusive range and immediately clamps the current value. */
    public func range(lower: Int64, upper: Int64): Stepper {
        lowerBound = min(lower, upper)
        upperBound = max(lower, upper)
        // Write only when clamping changes the value: this runs on every frame's rebuild,
        // and an unconditional write would notify the bound state's observers each frame.
        let clamped = clampInt(value.value)
        if (clamped != value.value) {
            value.value = clamped
        }
        this
    }

    /** Sets a positive increment. Throws `IllegalArgumentException` for non-positive values. */
    public func step(value: Int64): Stepper {
        if (value <= 0) {
            throw IllegalArgumentException("Stepper step must be greater than zero")
        }
        stepSize = value
        this
    }

    // Content-adaptive width: the value area fits the current number (with a floor so one
    // or two digits stay stable and uncramped), plus the two step buttons.
    public func measure(ctx: UiContext, available: Size): Size {
        let valueW = max(40.0, ctx.renderer.textWidth("${value.value}", pointSize: FontSizes.CONTROL) + 20.0)
        Size(min(available.w, valueW + STEPPER_BUTTON_W * 2.0), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(id)))
        recordControlSemantics(ctx, frame, "Stepper", ControlSemantics(
            "spinbutton", label: semanticLabel, value: value.value.toString(),
            action: "Stepper.adjust()", shortcut: "Left|Right|Up|Down",
            actionOwner: id,
            typedActions: [SemanticActionKind.Focus, SemanticActionKind.Decrement,
                SemanticActionKind.Increment]
        ))
        ctx.renderer.textCenter("−", decrementButton(), ctx.theme.text, pointSize: FontSizes.TITLE)
        let valueArea = valueFrame()
        textMotion.sync("${value.value}")
        ctx.renderer.pushClip(valueArea)
        textMotion.draw(ctx, valueArea, ctx.theme.text)
        ctx.renderer.popClip()
        ctx.renderer.textCenter("+", incrementButton(), ctx.theme.text, pointSize: FontSizes.TITLE)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        if (handlePointerClick(ctx, event, decrementButton(), "${id}:decrement", {=> decrement()},
            inkRadius: ctx.theme.controlRadius, inkColor: Some(ctx.theme.inkColor()), focusTarget: Some(id))) {
            return true
        }
        if (handlePointerClick(ctx, event, incrementButton(), "${id}:increment", {=> increment()},
            inkRadius: ctx.theme.controlRadius, inkColor: Some(ctx.theme.inkColor()), focusTarget: Some(id))) {
            return true
        }
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(id)
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) =>
                if (ctx.hasFocus(id)) {
                    decrement()
                    return true
                }
            case UiEvent.KeyDown(Key.Down, _) =>
                if (ctx.hasFocus(id)) {
                    decrement()
                    return true
                }
            case UiEvent.KeyDown(Key.Right, _) =>
                if (ctx.hasFocus(id)) {
                    increment()
                    return true
                }
            case UiEvent.KeyDown(Key.Up, _) =>
                if (ctx.hasFocus(id)) {
                    increment()
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    private func decrement(): Unit {
        // Saturate at Int64.Min before clamping so a step near the low extreme cannot underflow;
        // clampInt then applies the range floor. (`lowerBound + stepSize` could itself overflow
        // when the range sits within a step of Int64.Max.)
        let next = clampInt(if (value.value < Int64.Min + stepSize) {
            Int64.Min
        } else {
            value.value - stepSize
        })
        if (next != value.value) {
            textMotion.change("${next}", -1)
            value.value = next
        }
    }

    private func increment(): Unit {
        // Saturate at Int64.Max before clamping so a step near the high extreme cannot overflow;
        // clampInt then applies the range ceiling. (`upperBound - stepSize` could itself underflow
        // when the range sits within a step of Int64.Min.)
        let next = clampInt(if (value.value > Int64.Max - stepSize) {
            Int64.Max
        } else {
            value.value + stepSize
        })
        if (next != value.value) {
            textMotion.change("${next}", 1)
            value.value = next
        }
    }

    private func clampInt(candidate: Int64): Int64 {
        min(upperBound, max(lowerBound, candidate))
    }

    private func decrementButton(): Rect {
        let width = stepperButtonWidth()
        Rect(frame.x, frame.y, width, frame.h)
    }

    private func incrementButton(): Rect {
        let width = stepperButtonWidth()
        Rect(frame.right() - width, frame.y, width, frame.h)
    }

    private func valueFrame(): Rect {
        let buttonW = stepperButtonWidth()
        Rect(frame.x + buttonW, frame.y, max(0.0, frame.w - buttonW * 2.0), frame.h)
    }

    private func stepperButtonWidth(): Float32 {
        min(STEPPER_BUTTON_W, max(0.0, frame.w / 2.0))
    }
}

private func toggleInteraction(
    ctx: UiContext,
    event: UiEvent,
    frame: Rect,
    id: String,
    activate: () -> Unit,
    inkFrame: Rect,
    inkRadius: Float32
): Bool {
    if (handlePointerClick(ctx, event, frame, id, activate, inkFrame: Some(inkFrame),
        inkRadius: inkRadius, inkColor: Some(ctx.theme.inkColor()))) {
        return true
    }
    match (event) {
        case UiEvent.KeyDown(Key.Enter, _) =>
            if (ctx.hasFocus(id)) {
                ctx.startInkRipple(id, inkFrame, inkFrame.centerX(), inkFrame.centerY(),
                    color: Some(ctx.theme.inkColor()), cornerRadius: inkRadius)
                activate()
                return true
            }
        case UiEvent.KeyDown(Key.Space, _) =>
            if (ctx.hasFocus(id)) {
                ctx.startInkRipple(id, inkFrame, inkFrame.centerX(), inkFrame.centerY(),
                    color: Some(ctx.theme.inkColor()), cornerRadius: inkRadius)
                activate()
                return true
            }
        case _ => ()
    }
    false
}

/** Throws `IllegalArgumentException` when a focusable control receives an empty ID. */
private func validateControlId(id: String, kind: String): Unit {
    requireControlId(id, kind)
}

private func clampControlIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0 || index < 0) {
        0
    } else if (index >= count) {
        count - 1
    } else {
        index
    }
}
