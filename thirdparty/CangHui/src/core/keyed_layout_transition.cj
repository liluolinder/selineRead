package chui.core

import sdl.{Rect, Size, UiEvent}

/** Paint clipping used while a keyed child travels between layout rectangles. */
public enum LayoutTransitionClip {
    /** Let the moving child paint normally, including across sibling cell boundaries. */
    | NoClip
    /** Clip the child to its current animated rectangle. */
    | AnimatedBounds
    /** Clip the child to the final rectangle assigned by its parent. */
    | TargetBounds
}

/** A deterministic readout of one keyed layout transition. */
public struct LayoutTransitionGeometry {
    /** Rectangle currently used for painting. */
    public let current: Rect
    /** Final rectangle owned by the parent layout and ordinary input. */
    public let target: Rect
    /** Whether all four geometry tracks reached `target`. */
    public let settled: Bool

    public init(current: Rect, target: Rect, settled: Bool) {
        this.current = current
        this.target = target
        this.settled = settled
    }
}

/* Retained per-key geometry. Four Animator tracks make an interrupted re-layout continue from the
 * current visible rectangle instead of restarting from an obsolete First rectangle. */
private class KeyedLayoutMotion {
    private let x = Animator(0.0)
    private let y = Animator(0.0)
    private let width = Animator(0.0)
    private let height = Animator(0.0)
    private var initialized = false
    private var targetRect = Rect.zero()
    private var currentRect = Rect.zero()

    func assign(rect: Rect): Unit {
        let safe = Rect(rect.x, rect.y, max(0.0, rect.w), max(0.0, rect.h))
        targetRect = safe
        if (!initialized) {
            initialized = true
            currentRect = safe
            x.reset(safe.x)
            y.reset(safe.y)
            width.reset(safe.w)
            height.reset(safe.h)
        }
    }

    func advance(ctx: UiContext, spec: AnimationSpec): Rect {
        if (!initialized) { return Rect.zero() }
        currentRect = Rect(
            x.animate(ctx, target: targetRect.x, spec: spec),
            y.animate(ctx, target: targetRect.y, spec: spec),
            max(0.0, width.animate(ctx, target: targetRect.w, spec: spec)),
            max(0.0, height.animate(ctx, target: targetRect.h, spec: spec))
        )
        currentRect
    }

    func geometry(): LayoutTransitionGeometry {
        LayoutTransitionGeometry(currentRect, targetRect,
            x.settled() && y.settled() && width.settled() && height.settled())
    }
}

/**
 * Preserves visible geometry continuity when a keyed subtree is reordered or re-laid out.
 *
 * The parent immediately owns the new target rectangle (Last). The retained previous visible
 * rectangle supplies First/Invert, and four retargetable `Animator` tracks Play toward Last. During
 * paint the child is temporarily laid out at the current visual rectangle, then restored to the
 * target before input dispatch. This keeps focus, hit testing and parent layout attached to the final
 * structure without exposing `UiContext` or renderer internals to applications.
 *
 * First appearance is settled. Removing the node removes its retained state, so exit animation needs
 * a separate future retained-snapshot primitive rather than being implied here.
 */
public class KeyedLayoutTransition <: Widget {
    private let child: Widget
    private let animation: AnimationSpec
    private let clip: LayoutTransitionClip
    private let motion: KeyedLayoutMotion
    private var targetFrame = Rect.zero()

    public init(
        key: String,
        animation!: AnimationSpec = AnimationSpec.automatic(duration: Motion.normal),
        clip!: LayoutTransitionClip = LayoutTransitionClip.NoClip,
        content!: () -> Unit
    ) {
        requireControlId(key, "KeyedLayoutTransition")
        this.animation = animation
        this.clip = clip
        this.motion = localState<KeyedLayoutMotion>("KeyedLayoutTransition:${key}:motion") {
            KeyedLayoutMotion()
        }.value
        this.child = buildKeyedChild("KeyedLayoutTransition:${key}:content", content)
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        targetFrame = Rect(rect.x, rect.y, max(0.0, rect.w), max(0.0, rect.h))
        motion.assign(targetFrame)
        child.layout(ctx, targetFrame)
    }

    public func draw(ctx: UiContext): Unit {
        let visual = motion.advance(ctx, animation)
        let state = motion.geometry()
        if (state.settled) {
            child.draw(ctx)
            return
        }

        let clipped = match (clip) {
            case LayoutTransitionClip.NoClip => false
            case LayoutTransitionClip.AnimatedBounds =>
                ctx.renderer.pushClip(visual)
                true
            case LayoutTransitionClip.TargetBounds =>
                ctx.renderer.pushClip(targetFrame)
                true
        }
        try {
            child.layout(ctx, visual)
            child.draw(ctx)
        } finally {
            child.layout(ctx, targetFrame)
            if (clipped) { ctx.renderer.popClip() }
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool { child.handle(ctx, event) }
    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }
    public func stackingIndex(): Int64 { child.stackingIndex() }
    public func focusableId(): ?String { child.focusableId() }
    public func focusableIds(): Array<String> { child.focusableIds() }
    public func interactionOwnerIds(): Array<String> { child.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { child.interactionsEnabled() }

    /** Current paint/target geometry for deterministic tests and probes. */
    public func geometry(): LayoutTransitionGeometry { motion.geometry() }
}
