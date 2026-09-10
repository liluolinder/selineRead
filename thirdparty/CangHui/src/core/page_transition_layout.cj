package chui.core

import sdl.{Rect, Size, UiEvent, clampF32}

/**
 * Two-page cross-wipe with interpolated measured size.
 *
 * This is intentionally independent from device posture. It preserves the useful visual
 * transition formerly prototyped in DeviceRotationLayout without pretending a page switch
 * is a physical screen rotation.
 */
public class PageTransitionLayout <: Widget {
    private let first: Widget
    private let second: Widget
    private let showSecond: Bool
    private let animation: AnimationSpec
    private let animator: Animator
    private var frame = Rect.zero()

    public init(
        showSecond!: Bool,
        key!: ?String = None,
        animation!: AnimationSpec = AnimationSpec.automatic(duration: UInt64(260)),
        first!: () -> Unit,
        second!: () -> Unit
    ) {
        this.showSecond = showSecond
        this.animation = animation
        let id = resolveControlKey(key, "PageTransitionLayout")
        this.first = buildKeyedChild("${id}:first", first)
        this.second = buildKeyedChild("${id}:second", second)
        this.animator = localState<Animator>("${id}:page") {
            Animator(if (showSecond) { 1.0 } else { 0.0 })
        }.value
        let inactive = if (showSecond) { this.first } else { this.second }
        for (focusId in inactive.focusableIds()) { unregisterFocusable(focusId) }
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let firstSize = first.measure(ctx, available)
        let secondSize = second.measure(ctx, available)
        let progress = fraction()
        Size(
            pageTransitionInterpolate(firstSize.w, secondSize.w, progress),
            pageTransitionInterpolate(firstSize.h, secondSize.h, progress)
        )
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        first.layout(ctx, rect)
        second.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        let progress = clampF32(animator.animate(ctx, target: if (showSecond) { 1.0 } else { 0.0 },
            spec: animation), 0.0, 1.0)
        let firstWidth = frame.w * (1.0 - progress)
        if (firstWidth > 0.5) {
            ctx.renderer.pushClip(Rect(frame.x, frame.y, firstWidth, frame.h))
            first.draw(ctx)
            ctx.renderer.popClip()
        }
        let secondWidth = frame.w * progress
        if (secondWidth > 0.5) {
            ctx.renderer.pushClip(Rect(frame.right() - secondWidth, frame.y, secondWidth, frame.h))
            second.draw(ctx)
            ctx.renderer.popClip()
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool { activeChild().handle(ctx, event) }
    public func isFlexible(): Bool { activeChild().isFlexible() }
    public func flexWeight(): Float32 { activeChild().flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { activeChild().acceptsStretch(axis) }
    public func participatesInLayout(): Bool { activeChild().participatesInLayout() }
    public func focusableId(): ?String { activeChild().focusableId() }
    public func focusableIds(): Array<String> { activeChild().focusableIds() }
    public func interactionOwnerIds(): Array<String> { activeChild().interactionOwnerIds() }
    public func interactionsEnabled(): Bool { activeChild().interactionsEnabled() }

    private func activeChild(): Widget { if (showSecond) { second } else { first } }
    private func fraction(): Float32 { clampF32(animator.value, 0.0, 1.0) }
}

private func pageTransitionInterpolate(from: Float32, to: Float32, progress: Float32): Float32 {
    from + (to - from) * progress
}
