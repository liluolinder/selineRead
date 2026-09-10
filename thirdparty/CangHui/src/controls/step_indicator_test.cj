package chui.controls

import sdl.{MouseButton, Rect, Renderer, Size, UiEvent}
import chui.core.{State, Theme, UiContext}

private func stepTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

// For a 440-wide layout with 4 steps: left = 44, right = 396, gap = 352/3 ≈ 117.33.
// Node centres are 44, 161.33, 278.67, 396; the node row's centre-y is 4 + 14 = 18.
private let STEP_NODE_CY: Float32 = 18.0

@Test
func stepIndicatorMeasuresFixedHeight(): Unit {
    let ctx = stepTestContext()
    // circle 28 + top pad 4 + label gap 8 + label 18 = 58.
    let size = StepIndicator(["A", "B"], 0).measure(ctx, Size(400.0, 100.0))
    @Expect(size.h, Float32(58.0))
    @Expect(size.w, Float32(400.0))
}

@Test
func stepIndicatorClicksReachableSteps(): Unit {
    let ctx = stepTestContext()
    let picked = State<Int64>(-1)
    let steps = StepIndicator(["账户", "资料", "偏好", "完成"], 2, onSelect: {i => picked.value = i})
    steps.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))

    // Step 0 is done (≤ current 2): clicking its node selects it.
    @Expect(steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 44.0, STEP_NODE_CY)))
    @Expect(steps.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 44.0, STEP_NODE_CY)))
    @Expect(picked.value, 0)
    // The current step (2) is also reachable.
    @Expect(steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 278.0, STEP_NODE_CY)))
    @Expect(steps.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 278.0, STEP_NODE_CY)))
    @Expect(picked.value, 2)
}

@Test
func stepIndicatorMoveOutCancelsSelection(): Unit {
    let ctx = stepTestContext()
    let picked = State<Int64>(-1)
    let steps = StepIndicator(["A", "B", "C"], 2, onSelect: {i => picked.value = i}, key: "cancel")
    steps.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))

    @Expect(steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 44.0, STEP_NODE_CY)))
    let _ = steps.handle(ctx, UiEvent.MouseMove(220.0, 100.0))
    @Expect(!steps.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 44.0, STEP_NODE_CY)))
    @Expect(picked.value, -1)
}

@Test
func stepIndicatorIgnoresFutureSteps(): Unit {
    let ctx = stepTestContext()
    let picked = State<Int64>(-1)
    let steps = StepIndicator(["A", "B", "C", "D"], 1, onSelect: {i => picked.value = i})
    steps.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))

    // Step 3 is in the future (> current 1): the click is not consumed and nothing is selected.
    @Expect(!steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 396.0, STEP_NODE_CY)))
    @Expect(picked.value, -1)
}

@Test
func stepIndicatorWithoutCallbackIsDisplayOnly(): Unit {
    let ctx = stepTestContext()
    let steps = StepIndicator(["A", "B", "C"], 1)
    steps.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))
    // No onSelect: node presses are never consumed.
    @Expect(!steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 44.0, STEP_NODE_CY)))
}

@Test
func stepIndicatorPublishesOnlyRealPointerOwnership(): Unit {
    let interactive = StepIndicator(["A", "B"], 0, onSelect: {_ => ()}, key: "interactive")
    let displayOnly = StepIndicator(["A", "B"], 0, key: "display")
    @Expect(interactive.interactionOwnerIds(), ["interactive"])
    @Expect(displayOnly.interactionOwnerIds(), [])
}

@Test
func stepIndicatorIgnoresPressesAwayFromNodes(): Unit {
    let ctx = stepTestContext()
    let picked = State<Int64>(-1)
    let steps = StepIndicator(["A", "B", "C", "D"], 3, onSelect: {i => picked.value = i})
    steps.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))
    // Well below the node row (y = 50), no node is hit.
    @Expect(!steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 44.0, 50.0)))
    @Expect(picked.value, -1)
}

@Test
func stepIndicatorClampsOutOfRangeCurrentForInteraction(): Unit {
    @Expect(clampStepIndex(0, 4), 0)
    @Expect(clampStepIndex(3, -2), 0)
    @Expect(clampStepIndex(3, 9), 2)

    let ctx = stepTestContext()
    let firstPicked = State<Int64>(-1)
    let beforeFirst = StepIndicator(["A", "B", "C"], -2,
        onSelect: {i => firstPicked.value = i}, key: "before-first")
    beforeFirst.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))
    @Expect(beforeFirst.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 44.0, STEP_NODE_CY)))
    @Expect(beforeFirst.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 44.0, STEP_NODE_CY)))
    @Expect(firstPicked.value, 0)

    let lastPicked = State<Int64>(-1)
    let afterLast = StepIndicator(["A", "B", "C"], 9,
        onSelect: {i => lastPicked.value = i}, key: "after-last")
    afterLast.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))
    @Expect(afterLast.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 396.0, STEP_NODE_CY)))
    @Expect(afterLast.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 396.0, STEP_NODE_CY)))
    @Expect(lastPicked.value, 2)
}
