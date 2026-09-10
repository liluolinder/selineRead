package chui.controls

import sdl.{Color, FontSizes, Pen, Rect, Size, UiEvent}
import chui.core.{AnimationSpec, Animator, ControlSemantics, InteractionAnimation, InteractionProgress, Motion,
    UiContext, Widget, resolveControlKey, emit, handlePointerClick, localState, recordControlSemantics}

private let STEP_CIRCLE_R: Float32 = 14.0
private let STEP_EDGE_PAD: Float32 = 44.0
private let STEP_LABEL_GAP: Float32 = 8.0
private let STEP_LABEL_H: Float32 = 18.0
private let STEP_TOP_PAD: Float32 = 4.0

/**
 * A horizontal step progress indicator for multi-step flows (checkout, onboarding, wizards). It shows a
 * row of numbered nodes joined by a connector, with everything before `current` marked done (filled and
 * checked), `current` highlighted, and later steps dimmed. Each step's label sits beneath its node.
 *
 * It is display-first: the flow's own Back/Next controls drive `current`. An `onSelect` callback makes
 * the already-reached steps (index ≤ current) clickable, so the user can jump back to a completed step.
 */
public class StepIndicator <: Widget {
    private let id: String
    private let steps: Array<String>
    private let current: Int64
    private let onSelect: ?(Int64) -> Unit
    private var semanticLabel: String
    private let currentAnimation: Animator
    private let nodeAnimations: Array<InteractionAnimation>
    private var animationSpec: AnimationSpec
    private var frame = Rect.zero()

    public init(
        steps: Array<String>,
        current: Int64,
        onSelect!: ?(Int64) -> Unit = None,
        key!: ?String = None,
        animation!: AnimationSpec = AnimationSpec.automatic(duration: Motion.normal, easing: Motion.standard)
    ) {
        let ident = resolveControlKey(key, "StepIndicator")
        this.id = ident
        this.steps = steps
        this.current = current
        this.onSelect = onSelect
        this.semanticLabel = joinStepLabels(steps)
        this.currentAnimation = localState<Animator>("${ident}:current-motion") {
            Animator(Float32(clampStepIndex(steps.size, current)))
        }.value
        this.nodeAnimations = Array<InteractionAnimation>(steps.size, {index =>
            localState<InteractionAnimation>("${ident}:node-motion:${index}") {InteractionAnimation()}.value
        })
        this.animationSpec = animation
        emit(this)
    }

    /** Overrides the semantic name without changing the visible step labels. */
    public func accessibilityLabel(value: String): StepIndicator {
        semanticLabel = value
        this
    }

    /** Applies an automatic or exact progress animation property. */
    public func animation(value: AnimationSpec): StepIndicator {
        animationSpec = value
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, STEP_CIRCLE_R * 2.0 + STEP_TOP_PAD + STEP_LABEL_GAP + STEP_LABEL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let n = steps.size
        if (n == 0) {
            return
        }
        let cy = frame.y + STEP_TOP_PAD + STEP_CIRCLE_R
        let xs = stepCenters()
        let normalizedCurrent = clampStepIndex(n, current)
        recordControlSemantics(ctx, frame, "StepIndicator", ControlSemantics(
            "stepindicator", label: semanticLabel,
            value: "step ${normalizedCurrent + 1} of ${n}",
            action: "", shortcut: "",
            actionOwner: id
        ))
        let animatedCurrent = currentAnimation.animate(ctx, target: Float32(normalizedCurrent), spec: animationSpec)
        // Connectors first, behind the nodes: done segments accent, the rest neutral.
        var i = 0
        while (i < n - 1) {
            let startX = xs[i] + STEP_CIRCLE_R
            let endX = xs[i + 1] - STEP_CIRCLE_R
            ctx.renderer.strokeLine(startX, cy, endX, cy, Pen(width: 2.5, color: ctx.theme.panelEdge))
            let fill = max(0.0, min(1.0, animatedCurrent - Float32(i)))
            if (fill > 0.001) {
                ctx.renderer.strokeLine(startX, cy, startX + (endX - startX) * fill, cy,
                    Pen(width: 2.5, color: ctx.theme.accent))
            }
            i += 1
        }
        for (step in 0..n) {
            drawNode(ctx, xs[step], cy, step, animatedCurrent)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (onSelect) {
            case Some(callback) =>
                let cy = frame.y + STEP_TOP_PAD + STEP_CIRCLE_R
                let xs = stepCenters()
                let reachedCount = min(steps.size, clampStepIndex(steps.size, current) + 1)
                for (step in 0..reachedCount) {
                    let hit = STEP_CIRCLE_R + 4.0
                    let hitFrame = Rect(xs[step] - hit, cy - hit, hit * 2.0, hit * 2.0)
                    if (handlePointerClick(ctx, event, hitFrame, nodeId(step), {=> callback(step)})) {
                        return true
                    }
                }
            case None => ()
        }
        false
    }

    public func interactionOwnerIds(): Array<String> {
        if (onSelect.isSome() && !steps.isEmpty()) { [id] } else { [] }
    }

    private func nodeId(step: Int64): String {
        "${id}:node:${step}"
    }

    private func nodeInteraction(ctx: UiContext, step: Int64): InteractionProgress {
        let nid = nodeId(step)
        nodeAnimations[step].animate(ctx, ctx.isHovered(nid), ctx.isPressed(nid),
            AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate))
    }

    // The x centre of each node, spread evenly with padding so edge labels have room.
    private func stepCenters(): Array<Float32> {
        let n = steps.size
        if (n <= 1) {
            return [frame.centerX()]
        }
        let left = frame.x + STEP_EDGE_PAD
        let right = frame.right() - STEP_EDGE_PAD
        let gap = (right - left) / Float32(n - 1)
        Array<Float32>(n, {i => left + Float32(i) * gap})
    }

    private func drawNode(ctx: UiContext, cx: Float32, cy: Float32, step: Int64, animatedCurrent: Float32): Unit {
        let reached = max(0.0, min(1.0, animatedCurrent - Float32(step) + 1.0))
        let done = max(0.0, min(1.0, animatedCurrent - Float32(step)))
        let interaction = nodeInteraction(ctx, step)
        let amount = ctx.theme.motionLevel.amplitude()
        let radius = STEP_CIRCLE_R + interaction.hover * amount - interaction.press * amount * 0.7
        let fill = ctx.theme.field.lerp(ctx.theme.accent, reached)
        ctx.renderer.fillCircle(cx, cy, radius, fill)
        ctx.renderer.strokeCircle(cx, cy, max(Float32(0.0), radius - Float32(1.0)),
            Pen(width: 1.6, color: ctx.theme.panelEdge.lerp(ctx.theme.accent, reached)))
        if (done > 0.55) {
            drawCheck(ctx, cx, cy, ctx.theme.accentText)
        } else {
            drawNumber(ctx, cx, cy, step + 1, ctx.theme.mutedText.lerp(ctx.theme.accentText, reached))
        }
        let currentAmount = max(0.0, reached - done)
        let labelColor = ctx.theme.mutedText
            .lerp(ctx.theme.text, done)
            .lerp(ctx.theme.accent, currentAmount)
        let label = steps[step]
        let labelW = ctx.renderer.textWidth(label, pointSize: FontSizes.CAPTION)
        let ly = cy + STEP_CIRCLE_R + STEP_LABEL_GAP
        ctx.renderer.text(label, cx - labelW / 2.0, ly, labelColor, pointSize: FontSizes.CAPTION)
    }

    private func drawNumber(ctx: UiContext, cx: Float32, cy: Float32, number: Int64, color: Color): Unit {
        let text = "${number}"
        let w = ctx.renderer.textWidth(text, pointSize: FontSizes.CAPTION)
        let h = ctx.renderer.textHeight(pointSize: FontSizes.CAPTION)
        ctx.renderer.text(text, cx - w / 2.0, cy - h / 2.0, color, pointSize: FontSizes.CAPTION)
    }

    private func drawCheck(ctx: UiContext, cx: Float32, cy: Float32, color: Color): Unit {
        let pen = Pen(width: 2.0, color: color)
        ctx.renderer.strokeLine(cx - 5.0, cy, cx - 1.5, cy + 4.0, pen)
        ctx.renderer.strokeLine(cx - 1.5, cy + 4.0, cx + 5.5, cy - 4.0, pen)
    }
}

internal func clampStepIndex(stepCount: Int64, current: Int64): Int64 {
    if (stepCount <= 0) {
        0
    } else {
        max(Int64(0), min(stepCount - 1, current))
    }
}

// The semantic label default: the visible step labels, joined by " / ".
private func joinStepLabels(steps: Array<String>): String {
    let builder = StringBuilder()
    for (i in 0..steps.size) {
        if (i > 0) {
            builder.append(" / ")
        }
        builder.append(steps[i])
    }
    builder.toString()
}
