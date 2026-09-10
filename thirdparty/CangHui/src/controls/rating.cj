package chui.controls

import sdl.{Key, Pen, Rect, Size, UiEvent}
import chui.core.{Bindable, ControlSemantics, SemanticActionKind, UiContext, Widget, resolveControlKey, drawFocusRing, emit,
    handlePointerClick, recordControlSemantics, registerFocusable}

private let RATING_RADIUS: Float32 = 8.0
private let RATING_STEP: Float32 = 24.0
private let RATING_HEIGHT: Float32 = 24.0

/*
 * A score control shown as a row of filled/hollow dots — filled up to the rating, hollow beyond. It is
 * the input for a whole-number score in 0…count (five dots by default).
 *
 * Interactive by default: clicking a dot sets the rating to that position, clicking the current rating
 * again clears it to zero, and hovering previews the fill. When focused the arrow keys adjust the score
 * (Left/Down down, Right/Up up), Home clears and End fills. Pass `readonly` for a pure display that takes
 * no focus and no input.
 */
public class Rating <: Widget {
    private let value: Bindable<Int64>
    private let count: Int64
    private let readonly: Bool
    private let id: String
    private var semanticLabel: String
    private var frame = Rect.zero()

    public init(value: Bindable<Int64>, count!: Int64 = 5, readonly!: Bool = false, key!: ?String = None) {
        this.value = value
        this.count = max(1, count)
        this.readonly = readonly
        this.id = resolveControlKey(key, "Rating")
        this.semanticLabel = ""
        if (!readonly) {
            registerFocusable(this.id)
        }
        emit(this)
    }

    /** Overrides the semantic name without changing the visible dots. */
    public func accessibilityLabel(value: String): Rating {
        semanticLabel = value
        this
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(ratingWidth(count), RATING_HEIGHT)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func isFlexible(): Bool {
        false
    }

    public func focusableId(): ?String {
        if (readonly) {
            None
        } else {
            Some(id)
        }
    }

    public func draw(ctx: UiContext): Unit {
        let hovered = hoveredIndex(ctx)
        let selectedTo = clampRating(value.get(), count)
        let previewTo = if (hovered >= 0) { hovered + 1 } else { -1 }
        let cy = frame.centerY()
        recordControlSemantics(ctx, frame, "Rating", ControlSemantics(
            "rating", label: semanticLabel, value: "${selectedTo}/${count}",
            action: if (readonly) { "" } else { "Rating.set()" },
            shortcut: if (readonly) { "" } else { "Left|Down|Right|Up|Home|End" },
            actionOwner: id,
            readOnly: Some(readonly),
            typedActions: if (readonly) { [] } else {
                [SemanticActionKind.Focus, SemanticActionKind.Decrement, SemanticActionKind.Increment]
            }
        ))
        for (i in 0..count) {
            let cx = frame.x + RATING_RADIUS + Float32(i) * RATING_STEP
            if (previewTo >= 0 && i < previewTo) {
                ctx.renderer.fillCircle(cx, cy, RATING_RADIUS, ctx.theme.accentSoft)
                ctx.renderer.strokeCircle(cx, cy, RATING_RADIUS,
                    Pen(width: 1.4, color: ctx.theme.accent), segments: 32)
            } else if (previewTo >= 0 && i < selectedTo) {
                ctx.renderer.fillCircle(cx, cy, RATING_RADIUS, ctx.theme.accent.withAlpha(92))
            } else if (i < selectedTo) {
                ctx.renderer.fillCircle(cx, cy, RATING_RADIUS, ctx.theme.accent)
            } else {
                ctx.renderer.strokeCircle(cx, cy, RATING_RADIUS, Pen(width: 1.5, color: ctx.theme.mutedText.withAlpha(150)))
            }
        }
        if (!readonly && ctx.showFocusRing(id)) {
            drawFocusRing(ctx, frame, ctx.theme.smallRadius)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        if (readonly) {
            return false
        }
        for (index in 0..count) {
            let dot = dotFrame(index)
            if (handlePointerClick(ctx, event, dot, "${id}:dot:${index}",
                {=> value.value = ratingValueForClick(value.get(), index + 1)},
                inkFrame: Some(dot), inkRadius: RATING_RADIUS, inkColor: Some(ctx.theme.inkColor()),
                focusTarget: Some(id))) {
                return true
            }
        }
        match (event) {
            case UiEvent.KeyDown(Key.Left, _) => return adjustIfFocused(ctx, -1)
            case UiEvent.KeyDown(Key.Down, _) => return adjustIfFocused(ctx, -1)
            case UiEvent.KeyDown(Key.Right, _) => return adjustIfFocused(ctx, 1)
            case UiEvent.KeyDown(Key.Up, _) => return adjustIfFocused(ctx, 1)
            case UiEvent.KeyDown(Key.Home, _) => return setIfFocused(ctx, 0)
            case UiEvent.KeyDown(Key.End, _) => return setIfFocused(ctx, count)
            case _ => ()
        }
        false
    }

    private func adjustIfFocused(ctx: UiContext, delta: Int64): Bool {
        if (ctx.hasFocus(id)) {
            value.value = clampRating(value.get() + delta, count)
            return true
        }
        false
    }

    private func setIfFocused(ctx: UiContext, target: Int64): Bool {
        if (ctx.hasFocus(id)) {
            value.value = clampRating(target, count)
            return true
        }
        false
    }

    // The dot index under the pointer when hovering an interactive control, or -1.
    private func hoveredIndex(ctx: UiContext): Int64 {
        if (readonly || !frame.contains(ctx.mouseX, ctx.mouseY)) {
            return -1
        }
        ratingIndexAt(ctx.mouseX, frame.x, count)
    }

    private func dotFrame(index: Int64): Rect {
        let cx = frame.x + RATING_RADIUS + Float32(index) * RATING_STEP
        Rect(cx - RATING_RADIUS, frame.centerY() - RATING_RADIUS, RATING_RADIUS * 2.0, RATING_RADIUS * 2.0)
    }
}

// The natural width of a `count`-dot row.
internal func ratingWidth(count: Int64): Float32 {
    Float32(max(1, count) - 1) * RATING_STEP + 2.0 * RATING_RADIUS
}

// The dot index (0-based) at pointer x within a row whose first dot's left edge is `frameX`, or -1 when
// past the last dot.
internal func ratingIndexAt(x: Float32, frameX: Float32, count: Int64): Int64 {
    if (x < frameX) {
        return -1
    }
    let idx = Int64((x - frameX) / RATING_STEP)
    if (idx >= count) {
        -1
    } else {
        idx
    }
}

// Clicking the dot already at the current rating clears to zero; otherwise the rating jumps to the
// clicked (1-based) position.
internal func ratingValueForClick(current: Int64, clickedOneBased: Int64): Int64 {
    if (clickedOneBased == current) {
        0
    } else {
        clickedOneBased
    }
}

internal func clampRating(value: Int64, count: Int64): Int64 {
    if (value < 0) {
        0
    } else if (value > count) {
        count
    } else {
        value
    }
}
