package chui.core

import sdl.{FrameInfo, GamepadButton, Key, MouseButton, Rect, UiEvent}
import chui.symbol.SymbolName

private func interactionSurfaceProbe(script: String, disabled!: Bool = false): String {
    let clicks = State<Int64>(0)
    ComponentProbe("test.interaction-surface", width: 180.0, height: 70.0).run(script) {
        let interaction = InteractionSurface(
            action: probedAction("surface.activate", {=> clicks.value += 1}),
            accessibilityLabel: "Save copy",
            key: Some("surface")
        ) { Label("Save") }
            .surface(Shape.rounded(10.0), Materials.themePrimary())
        if (disabled) { interaction.enabled(false) }
    }
}

@Test
func interactionSurfaceActivatesOnReleaseInsideAndPublishesOneOwner(): Unit {
    let report = interactionSurfaceProbe(
        "press 40 30\nrelease 40 30\nassert activation surface.activate 1"
    )
    @Expect(report.contains("\"ok\":true"))
    @Expect(report.contains("\"id\":\"control-semantic:surface\""))
    @Expect(report.contains("\"actionOwner\":\"surface\""))
    @Expect(report.contains("\"enabled\":\"true\""))
    @Expect(report.contains("\"semanticDescendants\":\"decorative\""))
    @Expect(report.contains("\"kind\":\"clip.push\""))
    @Expect(report.contains("\"kind\":\"paint.ripple\""))
    @Expect(report.contains("\"cornerRadius\":9.000000"))
}

@Test
func interactionSurfaceMoveOutCancelsReleaseEvenAfterReturningInside(): Unit {
    let report = interactionSurfaceProbe(
        "press 40 30\nmove-out 230 90\nrelease 40 30\nassert activation surface.activate 0"
    )
    @Expect(report.contains("\"ok\":true"))
}

@Test
func disabledInteractionSurfaceHasNoActionFocusOrActivation(): Unit {
    let report = interactionSurfaceProbe(
        "press 40 30\nrelease 40 30\nassert activation surface.activate 0",
        disabled: true
    )
    @Expect(report.contains("\"ok\":true"))
    @Expect(report.contains("\"disabled\":\"true\""))
    @Expect(report.contains("\"enabled\":\"false\""))
    @Expect(!report.contains("InteractionSurface.activate()"))
}

@Test
func readOnlyInteractionSurfaceExposesStateWithoutFocusOrAction(): Unit {
    let surface = InteractionSurface(action: {=> ()}, key: Some("readonly"), readOnly: true) {
        Label("Read only")
    }
    @Expect(surface.focusableId().isNone())
    let report = ComponentProbe("test.readonly-interaction", width: 180.0, height: 70.0).run("") {
        InteractionSurface(action: {=> ()}, key: Some("readonly"), readOnly: true) {
            Label("Read only")
        }
    }
    @Expect(report.contains("\"ok\":true"))
    @Expect(report.contains("\"readonly\":\"true\""))
    @Expect(report.contains("\"enabled\":\"false\""))
    @Expect(!report.contains("InteractionSurface.activate()"))
}

@Test
func explicitSameOwnerProbeTakesPrecedenceOverAutomaticInteractionSemantics(): Unit {
    let report = ComponentProbe("test.explicit-interaction-probe", width: 180.0, height: 70.0).run("") {
        InteractionSurface(action: {=> ()}, key: Some("explicit")) { Label("Explicit") }
            .probe("explicit", "InteractionSurface", [
                ProbeProperty("role", "button"),
                ProbeProperty("action", "custom.activate()"),
                ProbeProperty("shortcut", "Enter")
            ])
    }
    @Expect(report.contains("\"id\":\"explicit\""))
    @Expect(report.contains("custom.activate()"))
    @Expect(!report.contains("control-semantic:explicit"))
    @Expect(!report.contains("InteractionSurface.activate()"))
}

@Test
func interactionSurfaceRejectsAnEmptyCustomSemanticRole(): Unit {
    var rejected = false
    try {
        let _ = InteractionSurface(action: {=> ()}, role: ControlRole.Custom("")) { Label("Invalid") }
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func interactionSurfaceKeyboardFocusActivatesEnterAndSpace(): Unit {
    let clicks = State<Int64>(0)
    let surface = InteractionSurface(action: {=> clicks.value += 1}, key: Some("keyboard")) {
        Label("Keyboard")
    }
    let ctx = testContext()
    surface.layout(ctx, Rect(0.0, 0.0, 120.0, 40.0))
    ctx.focus("keyboard", viaKeyboard: true)
    @Expect(surface.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(surface.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(clicks.value, Int64(2))
}

@Test
func invalidNestedInteractionFailsClosedAndReportsStableStructureError(): Unit {
    let report = ComponentProbe("test.invalid-interaction", width: 180.0, height: 70.0).run(
        "press 40 30\nrelease 40 30\n" +
        "assert activation outer.activate 0\nassert activation nested.activate 0"
    ) {
        InteractionSurface(
            action: probedAction("outer.activate", {=> ()}),
            key: Some("outer")
        ) {
            Button("Nested", probedAction("nested.activate", {=> ()})).key("nested")
        }
    }
    @Expect(report.contains("\"ok\":false"))
    @Expect(report.contains("structural-nested-interaction-owner"))
    @Expect(report.contains("InteractionSurface outer contains interaction-owning descendants: nested"))
    @Expect(report.contains("\"diagnostic\":\"nested-interaction-owner\""))
    @Expect(report.contains("\"descendantInteractionOwnerIds\":\"nested\""))
    @Expect(report.contains("\"descendantFocusIds\":\"nested\""))
    @Expect(!report.contains("InteractionSurface.activate()"))
    @Expect(!report.contains("Button.activate()"))
    @Expect(!report.contains("\"shortcut\":\"Enter|Space\""))
}

@Test
func pointerOnlyEventHandlerIsRejectedThroughDecorativeWrappers(): Unit {
    let surface = InteractionSurface(action: {=> ()}, key: Some("outer")) {
        Surface {
            VStack {
                EventHandler(onEvent: {_ => true}) { Label("Pointer owner") }
                    .padding(2.0)
            }
        }
    }
    match (surface.structuralDiagnostic()) {
        case Some(value) => @Expect(value, "nested-interaction-owner: EventHandler")
        case None => @Fail("A pointer-only EventHandler must be an interaction owner.")
    }

    let handled = State<Int64>(0)
    let report = ComponentProbe("test.pointer-owner", width: 180.0, height: 70.0).run(
        "press 40 30\nrelease 40 30"
    ) {
        InteractionSurface(action: {=> ()}, key: Some("outer")) {
            EventHandler(onEvent: {_ => handled.value += 1; true}) { Label("Pointer owner") }
        }
    }
    @Expect(report.contains("\"ok\":false"))
    @Expect(report.contains("InteractionSurface outer contains interaction-owning descendants: EventHandler"))
    @Expect(report.contains("\"descendantInteractionOwnerIds\":\"EventHandler\""))
    @Expect(report.contains("\"descendantFocusIds\":\"\""))
    @Expect(!report.contains("InteractionSurface.activate()"))
    @Expect(handled.value, Int64(0))
}

@Test
func decorativeLabelSymbolLayoutSurfaceAndFrameHandlerStayValid(): Unit {
    let surface = InteractionSurface(action: {=> ()}, key: Some("valid")) {
        Surface {
            FrameHandler(onFrame: {_ => ()}) {
                VStack {
                    Label("Decorative")
                    Symbol(SymbolName("save", provider: "builtin"))
                }
            }
        }
    }
    @Expect(surface.structuralDiagnostic().isNone())
    @Expect(surface.focusableId(), Some("valid"))
}

@Test
func nestedFocusOwnerIsRemovedAndValidOwnerKeepsDeclarationOrder(): Unit {
    let store = StateStore()
    let _ = buildRoot({=>
        VStack {
            Button("Before", {=> ()}).key("before")
            InteractionSurface(action: {=> ()}, key: Some("outer")) {
                Button("Nested", {=> ()}).key("nested")
            }
            InteractionSurface(action: {=> ()}, key: Some("valid")) { Label("Valid") }
        }
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, Int64(2))
    @Expect(ring[0], "before")
    @Expect(ring[1], "valid")
}

@Test
func gestureSurfaceComposesDoubleTapLongPressDragHoverAndGamepadUnderOneOwner(): Unit {
    let taps = State<Int64>(0)
    let doubles = State<Int64>(0)
    let longs = State<Int64>(0)
    let drags = State<Int64>(0)
    let hovers = State<Int64>(0)
    let surface = GestureSurface(
        action: {=> taps.value += 1},
        key: Some("gesture"),
        gestures: GestureHandlers(
            onDoubleTap: Some({=> doubles.value += 1}),
            onLongPress: Some({=> longs.value += 1}),
            onDragStart: Some({_, _ => drags.value += 1}),
            onDragUpdate: Some({_, _, _, _ => drags.value += 1}),
            onDragEnd: Some({_, _ => drags.value += 1}),
            onHoverChanged: Some({_ => hovers.value += 1})
        )
    ) { Label("Gesture") }
    let ctx = testContext()
    surface.layout(ctx, Rect(0.0, 0.0, 120.0, 40.0))

    let _ = surface.handle(ctx, UiEvent.MouseMove(10.0, 10.0))
    ctx.clickCount = 2
    let _ = surface.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0))
    let _ = surface.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 10.0, 10.0))
    @Expect(doubles.value, 1)
    @Expect(taps.value, 0)

    ctx.frame = FrameInfo(UInt64(100), UInt64(0))
    let _ = surface.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0))
    let _ = surface.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(700), UInt64(600))))
    let _ = surface.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 10.0, 10.0))
    @Expect(longs.value, 1)

    let _ = surface.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0))
    let _ = surface.handle(ctx, UiEvent.MouseMove(30.0, 20.0))
    @Expect(ctx.hasPointerCapture("gesture"))
    let _ = surface.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 150.0, 50.0))
    @Expect(drags.value, 3)
    @Expect(!ctx.hasPointerCapture("gesture"))
    @Expect(hovers.value >= 1)

    ctx.focus("gesture", viaKeyboard: true)
    @Expect(surface.handle(ctx, UiEvent.GamepadButtonDown(UInt32(1), GamepadButton.South)))
    @Expect(taps.value, 1)
    @Expect(surface.interactionOwnerIds(), ["gesture"])
}

@Test
func gestureSurfaceCancelsCapturedDragWhenWindowLosesFocus(): Unit {
    let cancelled = State<Int64>(0)
    let surface = GestureSurface(
        action: {=> ()},
        key: Some("captured"),
        gestures: GestureHandlers(
            onDragUpdate: Some({_, _, _, _ => ()}),
            onDragCancel: Some({=> cancelled.value += 1})
        )
    ) { Label("Drag") }
    let ctx = testContext()
    surface.layout(ctx, Rect(0.0, 0.0, 100.0, 40.0))
    let _ = surface.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0))
    let _ = surface.handle(ctx, UiEvent.MouseMove(30.0, 10.0))
    @Expect(ctx.hasPointerCapture("captured"))
    @Expect(surface.handle(ctx, UiEvent.WindowFocusChanged(false)))
    @Expect(cancelled.value, 1)
    @Expect(!ctx.hasPointerCapture("captured"))
    @Expect(!ctx.isDragging("captured"))
}
