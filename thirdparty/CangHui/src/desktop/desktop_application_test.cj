package chui.desktop

import std.env.getVariable
import std.collection.ArrayList
import sdl.{GamepadAxis, GamepadButton, GamepadConnectionState, GamepadDevice, Key, SdlEventEnvelope,
    MouseButton, Rect, Renderer, UiEvent, WindowId, WindowSpec, gamepadButtonName,
    gamepadConnectionStateName}
import chui.core.{Button, Label, SemanticActionKind, SemanticActionRequest, SemanticActionSource,
    SharedFrameSurface, Theme, UiContext, VStack}
import chui.host.{NativeSurfaceBackend, NativeSurfaceDescriptor, NativeSurfaceEvent}
import chui.scene3d.{FakeScene3DProvider, FakeScene3DViewHost, Scene3DFrameClock,
    Scene3DFrameSnapshot, Scene3DResource, Scene3DView, Scene3DViewController,
    Scene3DViewFrameSource, Scene3DViewInputEvent}

private class ManagedSharedFrameFinishCounter {
    var calls: Int64 = 0
    var outcome = "none"

    func finish(value: String): Bool {
        calls += 1
        outcome = value
        true
    }
}

@Test
func managedWindowPresentFailureFinishesSharedFrameAsExecutorFailedExactlyOnce(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let counter = ManagedSharedFrameFinishCounter()
    let surface = SharedFrameSurface(
        "managed-scene", 1, 1, Rect(0.0, 0.0, 1.0, 1.0),
        1, 1, 4, "srgb", "premultiplied", "sdr", 1, 1, "portrait",
        [UInt8(0), UInt8(0), UInt8(0), UInt8(255)],
        onFinish: {outcome => counter.finish(outcome)})
    ctx.beginFrameSurfaceRegistration()
    ctx.registerSharedFrameSurface(surface)
    ctx.beginSharedFrameCompositionAttempt()
    surface.recordComposition(true, "sampled-before-present")

    var failed = false
    try {
        let _ = executeManagedSharedFrameTerminal(ctx, { =>
            throw IllegalStateException("simulated renderer.present failure")
        })
    } catch (error: IllegalStateException) {
        failed = error.message.contains("renderer.present")
    }
    @Expect(failed)
    @Expect(counter.calls, Int64(1))
    @Expect(counter.outcome, "executor-failed")
    @Expect(surface.finishOutcome(), "executor-failed")
    @Expect(ctx.finishSharedFrameSurfaces("abandoned"))
    @Expect(counter.calls, Int64(1))
    @Expect(surface.finishOutcome(), "executor-failed")

    let fallbackCtx = UiContext(Renderer.headless(), Theme.light())
    let fallbackCounter = ManagedSharedFrameFinishCounter()
    let fallbackSurface = SharedFrameSurface(
        "managed-fallback-scene", 2, 2, Rect(0.0, 0.0, 1.0, 1.0),
        1, 1, 4, "srgb", "premultiplied", "sdr", 2, 2, "portrait",
        [UInt8(0), UInt8(0), UInt8(0), UInt8(255)],
        onFinish: {outcome => fallbackCounter.finish(outcome)})
    fallbackCtx.beginFrameSurfaceRegistration()
    fallbackCtx.registerSharedFrameSurface(fallbackSurface)
    fallbackCtx.registerNativeChildFrameSurface(
        "managed-fallback-scene", 2, Rect(0.0, 0.0, 1.0, 1.0))
    fallbackCtx.beginSharedFrameCompositionAttempt()
    fallbackSurface.recordComposition(false, "simulated-upload-failure")
    let fallbackOutcome = executeManagedSharedFrameTerminal(fallbackCtx, { => () })
    @Expect(fallbackOutcome, "fallback")
    @Expect(fallbackCounter.calls, Int64(1))
    @Expect(fallbackCounter.outcome, "fallback")
    @Expect(fallbackSurface.finishOutcome(), "fallback")
}

private class TestDesktopWindowSession <: DesktopWindowSession {
    private let id: WindowId
    let events = ArrayList<String>()
    let pressedButtons = ArrayList<String>()
    var eventCount: Int64 = 0
    var closeCount: Int64 = 0
    var lastEvent: String = ""
    var gamepadConnected = false

    init(id: UInt32) { this.id = WindowId(id) }

    public func windowId(): WindowId { id }

    public func dispatch(event: UiEvent): Bool {
        eventCount += 1
        lastEvent = match (event) {
            case UiEvent.KeyDown(_, _) => "key"
            case UiEvent.MouseDown(_, _, _) => "pointer-down"
            case UiEvent.WindowResized(_, _) => "resize"
            case UiEvent.WindowFocusChanged(true) => "focus-gained"
            case UiEvent.WindowFocusChanged(false) => "focus-lost"
            case UiEvent.GamepadAxisMotion(_, _, _) => "axis"
            case UiEvent.GamepadButtonDown(_, button) =>
                let name = gamepadButtonName(button)
                if (!pressedButtons.contains(name)) { pressedButtons.add(name) }
                "button-down:${name}"
            case UiEvent.GamepadButtonUp(_, button) =>
                let name = gamepadButtonName(button)
                var index = pressedButtons.size - 1
                while (index >= 0) {
                    if (pressedButtons[index] == name) { pressedButtons.remove(at: index); break }
                    index -= 1
                }
                "button-up:${name}"
            case UiEvent.GamepadConnectionChanged(_, state) =>
                let name = gamepadConnectionStateName(state)
                if (name == "connected") { gamepadConnected = true }
                if (name == "disconnected") { gamepadConnected = false; pressedButtons.clear() }
                "connection:${name}"
            case UiEvent.WindowDestroyed => "destroyed"
            case _ => "other"
        }
        events.add(lastEvent)
        true
    }

    public func requestClose(): Unit { closeCount += 1 }
}

@Test
func windowRegistryIsolatesResizePointerFocusKeyboardAndUnknownWindowIds(): Unit {
    let registry = WindowRegistry()
    let first = TestDesktopWindowSession(UInt32(13))
    let second = TestDesktopWindowSession(UInt32(14))
    let _ = registry.register(first)
    let _ = registry.register(second)

    let resize = registry.dispatch(SdlEventEnvelope(Some(first.windowId()), UiEvent.WindowResized(640, 480)))
    @Expect(resize.target, Some(first.windowId()))
    @Expect(first.events.size, Int64(1))
    @Expect(first.events[0], "resize")
    @Expect(second.events.size, Int64(0))

    let pointer = registry.dispatch(SdlEventEnvelope(Some(second.windowId()),
        UiEvent.MouseDown(MouseButton.Left, 12.0, 16.0)))
    @Expect(pointer.target, Some(second.windowId()))
    @Expect(first.events.size, Int64(1))
    @Expect(first.events[0], "resize")
    @Expect(second.events.size, Int64(1))
    @Expect(second.events[0], "pointer-down")

    let _ = registry.dispatch(SdlEventEnvelope(Some(second.windowId()), UiEvent.WindowFocusChanged(true)))
    let key = registry.dispatch(SdlEventEnvelope(Some(second.windowId()), UiEvent.KeyDown(Key.Enter, false)))
    @Expect(key.target, Some(second.windowId()))
    @Expect(first.events.size, Int64(1))
    @Expect(first.events[0], "resize")
    @Expect(second.events.size, Int64(3))
    @Expect(second.events[0], "pointer-down")
    @Expect(second.events[1], "focus-gained")
    @Expect(second.events[2], "key")

    let firstCount = first.eventCount
    let secondCount = second.eventCount
    let unknown = registry.dispatch(SdlEventEnvelope(Some(WindowId(UInt32(999))),
        UiEvent.MouseDown(MouseButton.Left, 1.0, 1.0)))
    @Expect(!unknown.ok)
    @Expect(unknown.code, "window-not-registered")
    @Expect(first.eventCount, firstCount)
    @Expect(second.eventCount, secondCount)
}

@Test
func windowRegistryRejectsWindowScopedGamepadEnvelopesBeforeOwnershipRouting(): Unit {
    let registry = WindowRegistry()
    let first = TestDesktopWindowSession(UInt32(15))
    let second = TestDesktopWindowSession(UInt32(16))
    let _ = registry.register(first)
    let _ = registry.register(second)
    let forged: Array<UiEvent> = [
        UiEvent.GamepadConnectionChanged(GamepadDevice(UInt32(5)), GamepadConnectionState.Connected),
        UiEvent.GamepadAxisMotion(UInt32(5), GamepadAxis.LeftX, 0.25),
        UiEvent.GamepadButtonDown(UInt32(5), GamepadButton.South),
        UiEvent.GamepadButtonUp(UInt32(5), GamepadButton.South)
    ]
    for (event in forged) {
        let receipt = registry.dispatch(SdlEventEnvelope(Some(second.windowId()), event))
        @Expect(!receipt.ok)
        @Expect(receipt.code, "process-global-event-has-window-id")
        @Expect(receipt.target, Some(second.windowId()))
    }
    @Expect(first.eventCount, Int64(0))
    @Expect(second.eventCount, Int64(0))

    let connected = registry.dispatch(SdlEventEnvelope(None, UiEvent.GamepadConnectionChanged(
        GamepadDevice(UInt32(5)), GamepadConnectionState.Connected)))
    let down = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadButtonDown(UInt32(5), GamepadButton.South)))
    @Expect(connected.target, Some(first.windowId()))
    @Expect(down.target, Some(first.windowId()))
    @Expect(first.lastEvent, "button-down:south")
    @Expect(second.eventCount, Int64(0))
}

@Test
func windowRegistryPreservesExactWindowRoutingAndCloseScope(): Unit {
    let registry = WindowRegistry()
    let first = TestDesktopWindowSession(UInt32(11))
    let second = TestDesktopWindowSession(UInt32(12))
    @Expect(registry.register(first))
    @Expect(registry.register(second))
    @Expect(!registry.register(first))

    let routed = registry.dispatch(SdlEventEnvelope(Some(WindowId(UInt32(12))), UiEvent.KeyDown(Key.Enter, false)))
    @Expect(routed.ok)
    @Expect(first.eventCount, Int64(0))
    @Expect(second.eventCount, Int64(1))

    let close = registry.dispatch(SdlEventEnvelope(Some(WindowId(UInt32(11))), UiEvent.WindowCloseRequested))
    @Expect(close.code, "window-close-requested")
    @Expect(first.closeCount, Int64(1))
    @Expect(second.closeCount, Int64(0))
}

@Test
func windowRegistryQuitRequestsEveryWindow(): Unit {
    let registry = WindowRegistry()
    let first = TestDesktopWindowSession(UInt32(21))
    let second = TestDesktopWindowSession(UInt32(22))
    let _ = registry.register(first)
    let _ = registry.register(second)
    let receipt = registry.dispatch(SdlEventEnvelope(None, UiEvent.Quit))

    @Expect(receipt.applicationCloseRequested)
    @Expect(first.closeCount, Int64(1))
    @Expect(second.closeCount, Int64(1))
}

@Test
func windowRegistryKeepsGamepadLifecyclePairedAcrossFocusChange(): Unit {
    let registry = WindowRegistry()
    let first = TestDesktopWindowSession(UInt32(31))
    let second = TestDesktopWindowSession(UInt32(32))
    let _ = registry.register(first)
    let _ = registry.register(second)
    let _ = registry.setActiveWindow(WindowId(UInt32(31)))
    let connected = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadConnectionChanged(GamepadDevice(UInt32(7), name: "test-pad"),
            GamepadConnectionState.Connected)))
    @Expect(connected.target, Some(first.windowId()))
    let _ = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadAxisMotion(UInt32(7), GamepadAxis.LeftX, 0.5)))
    let _ = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadButtonDown(UInt32(7), GamepadButton.South)))
    @Expect(first.gamepadConnected)
    @Expect(first.pressedButtons.size, Int64(1))

    let _ = registry.dispatch(SdlEventEnvelope(Some(WindowId(UInt32(32))), UiEvent.WindowFocusChanged(true)))
    @Expect(!first.gamepadConnected)
    @Expect(first.pressedButtons.size, Int64(0))
    @Expect(second.gamepadConnected)
    @Expect(first.events[first.events.size - 2], "button-up:south")
    @Expect(first.events[first.events.size - 1], "connection:disconnected")
    @Expect(second.lastEvent, "connection:connected")

    // The physical release paired with the synthetic old-window release is consumed locally;
    // the new window must not observe an orphan ButtonUp.
    let suppressed = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadButtonUp(UInt32(7), GamepadButton.South)))
    @Expect(suppressed.code, "gamepad-release-suppressed")
    @Expect(second.lastEvent, "connection:connected")

    let _ = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadButtonDown(UInt32(7), GamepadButton.East)))
    let _ = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadButtonUp(UInt32(7), GamepadButton.East)))
    @Expect(second.lastEvent, "button-up:east")
    @Expect(second.pressedButtons.size, Int64(0))

    let _ = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadConnectionChanged(GamepadDevice(UInt32(7)), GamepadConnectionState.Disconnected)))
    @Expect(second.lastEvent, "connection:disconnected")
    @Expect(!second.gamepadConnected)
}

@Test
func windowRegistryRejectsUnknownOrAbsentTargets(): Unit {
    let registry = WindowRegistry()
    let unknown = registry.dispatch(SdlEventEnvelope(Some(WindowId(UInt32(99))),
        UiEvent.WindowCloseRequested))
    let global = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadButtonUp(UInt32(1), GamepadButton.South)))
    @Expect(unknown.code, "window-not-registered")
    @Expect(global.code, "gamepad-not-connected")
}

@Test
func windowRegistrySelectsRemainingWindowWhenActiveWindowCloses(): Unit {
    let registry = WindowRegistry()
    let first = TestDesktopWindowSession(UInt32(101))
    let second = TestDesktopWindowSession(UInt32(102))
    let _ = registry.register(first)
    let _ = registry.register(second)
    let _ = registry.setActiveWindow(first.windowId())

    @Expect(registry.unregister(first.windowId()))
    match (registry.activeWindow()) {
        case Some(id) => @Expect(id, second.windowId())
        case None => @Expect(false)
    }
    let _ = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadConnectionChanged(GamepadDevice(UInt32(9)), GamepadConnectionState.Connected)))
    let receipt = registry.dispatch(SdlEventEnvelope(None,
        UiEvent.GamepadButtonDown(UInt32(9), GamepadButton.South)))
    @Expect(receipt.target, Some(second.windowId()))
    @Expect(second.lastEvent, "button-down:south")
}

private class DesktopNativeSceneFrameSource <: Scene3DViewFrameSource {
    private let sceneId: String

    init(sceneId: String) { this.sceneId = sceneId }

    public func snapshot(_: Scene3DFrameClock): Scene3DFrameSnapshot {
        Scene3DFrameSnapshot(sceneId)
    }
}

private class DesktopNativeSceneInputCounter {
    var pointerDown: Int64 = 0
    var gamepadConnected: Int64 = 0
    var gamepadDown: Int64 = 0
    var gamepadUp: Int64 = 0
    var gamepadDisconnected: Int64 = 0

    func accept(event: Scene3DViewInputEvent): Bool {
        match (event) {
            case Scene3DViewInputEvent.PointerDown(_, _, _) => pointerDown += 1
            case Scene3DViewInputEvent.GamepadButtonDown(_, _) => gamepadDown += 1
            case Scene3DViewInputEvent.GamepadButtonUp(_, _) => gamepadUp += 1
            case Scene3DViewInputEvent.GamepadConnectionChanged(_, state) =>
                let name = gamepadConnectionStateName(state)
                if (name == "connected") { gamepadConnected += 1 }
                if (name == "disconnected") { gamepadDisconnected += 1 }
            case _ => ()
        }
        true
    }

    func total(): Int64 {
        pointerDown + gamepadConnected + gamepadDown + gamepadUp + gamepadDisconnected
    }
}

private func desktopNativeSceneController(
    id: String,
    host: FakeScene3DViewHost,
    input: DesktopNativeSceneInputCounter
): Scene3DViewController {
    let controller = Scene3DViewController(
        id,
        host,
        FakeScene3DProvider(),
        Scene3DResource("${id}-resource", "memory://${id}", "sha256:${id}", 0),
        DesktopNativeSceneFrameSource("${id}-frame"),
        onInput: {event => input.accept(event)})
    host.publish(NativeSurfaceEvent.Available(NativeSurfaceDescriptor(
        "${id}-surface", NativeSurfaceBackend.Metal, UInt64(100),
        180.0, 90.0, 180, 90, 1.0, 1)))
    controller
}

private enum DesktopNativeSmokeStatus {
    | Passed
    | Skipped
    | Failed
}

private struct DesktopNativeSmokeReceipt {
    let status: DesktopNativeSmokeStatus
    let code: String
    let detail: String

    init(status: DesktopNativeSmokeStatus, code: String, detail: String) {
        this.status = status
        this.code = code
        this.detail = detail
    }

    func accepted(): Bool {
        match (status) {
            case DesktopNativeSmokeStatus.Passed => true
            case DesktopNativeSmokeStatus.Skipped => true
            case DesktopNativeSmokeStatus.Failed => false
        }
    }
}

private class DesktopNativeSemanticCounter {
    var first: Int64 = 0
    var second: Int64 = 0
}

private func configuredNativeSmokeSkip(): ?String {
    match (getVariable("CANGHUI_SKIP_NATIVE_WINDOW_SMOKE")) {
        case Some(value) where value == "1" || value == "true" =>
            return Some("CANGHUI_SKIP_NATIVE_WINDOW_SMOKE explicitly requested")
        case _ => ()
    }
    None
}

private func nativeSmokeFailureCanSkip(detail: String): Bool {
    let environmentCanBeHeadless = match (getVariable("CI")) {
        case Some(value) where !value.isEmpty() => true
        case _ => match (getVariable("SDL_VIDEODRIVER")) {
            case Some(value) => value == "dummy" || value == "offscreen"
            case None => false
        }
    }
    environmentCanBeHeadless && (detail.contains("SDL_Init failed") ||
        detail.contains("SDL_CreateWindowAndRenderer failed") ||
        detail.contains("video driver"))
}

private func runDesktopNativeDoubleWindowSmoke(): DesktopNativeSmokeReceipt {
    match (configuredNativeSmokeSkip()) {
        case Some(reason) => return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Skipped,
            "skipped-explicitly", reason)
        case None => ()
    }
    var application: ?DesktopApplication = None
    try {
        let app = DesktopApplication()
        application = Some(app)
        var invalidSemanticIdRejected = false
        try {
            let _ = app.openWindow(
                WindowSpec("unreachable invalid semantic id", 80, 60, vsync: false, supersample: 1),
                { => VStack { Label("unreachable") } },
                semanticWindowId: "invalid\nwindow")
        } catch (error: IllegalArgumentException) {
            invalidSemanticIdRejected = error.message.contains("semantic runtime window id")
        }
        if (!invalidSemanticIdRejected || app.sessionCount() != 0) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "semantic-id-preflight-failed",
                "invalid semantic input reached native window ownership or registry state")
        }
        let semanticActions = DesktopNativeSemanticCounter()
        let firstHost = FakeScene3DViewHost()
        let secondHost = FakeScene3DViewHost()
        let firstSceneInput = DesktopNativeSceneInputCounter()
        let secondSceneInput = DesktopNativeSceneInputCounter()
        let firstController = desktopNativeSceneController("window-a.scene", firstHost, firstSceneInput)
        let secondController = desktopNativeSceneController("window-b.scene", secondHost, secondSceneInput)
        let first = app.openWindow(
            WindowSpec("CangHui multi-window smoke A", 180, 140, resizable: true, highDpi: false,
                vsync: false, supersample: 1),
            { =>
                VStack {
                    Scene3DView(firstController, width: 160.0, height: 70.0)
                    Button("window A", { => semanticActions.first += 1 }).key("window-a.action")
                }
            },
            semanticWindowId: "window-a")
        let second = app.openWindow(
            WindowSpec("CangHui multi-window smoke B", 180, 140, resizable: true, highDpi: false,
                vsync: false, supersample: 1),
            { =>
                VStack {
                    Scene3DView(secondController, width: 160.0, height: 70.0)
                    Button("window B", { => semanticActions.second += 1 }).key("window-b.action")
                }
            },
            semanticWindowId: "window-b")
        if (first == second || !app.focusWindow(second)) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "window-identity-or-focus-failed", "two native windows did not retain distinct routable identities")
        }
        let firstSemantic = match (app.semanticSnapshot(first)) {
            case Some(value) => value
            case None =>
                app.close()
                return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                    "window-semantic-snapshot-missing", "managed window did not commit a semantic tree")
        }
        let semanticReceipt = match (app.dispatchSemanticAction(first, SemanticActionRequest(
            firstSemantic.windowId,
            firstSemantic.revision,
            "window-a.action",
            SemanticActionKind.Activate,
            SemanticActionSource.Accessibility))) {
            case Some(value) => value
            case None =>
                app.close()
                return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                    "window-semantic-route-missing", "managed semantic action lost its exact window")
        }
        if (!semanticReceipt.ok || semanticActions.first != 1 || semanticActions.second != 0) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "window-semantic-route-failed", "typed action did not remain within the requested window")
        }

        let initialFirst = app.windowState(first).getOrThrow()
        let initialSecond = app.windowState(second).getOrThrow()
        if (initialFirst.nativeChildSurfaceCount != 1 || initialSecond.nativeChildSurfaceCount != 1 ||
            firstHost.currentPlacement().getOrThrow().viewId != "window-a.scene" ||
            secondHost.currentPlacement().getOrThrow().viewId != "window-b.scene") {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "scene-surface-isolation-failed", "Scene3D native-child registration crossed a window owner")
        }

        let resize = app.route(SdlEventEnvelope(Some(first), UiEvent.WindowResized(240, 150)))
        let resizedFirst = app.windowState(first).getOrThrow()
        let untouchedSecond = app.windowState(second).getOrThrow()
        if (!resize.ok || resizedFirst.logicalWidth != 240 || resizedFirst.logicalHeight != 150 ||
            untouchedSecond.logicalWidth != 180 || untouchedSecond.logicalHeight != 140) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "window-resize-isolation-failed", "resize escaped its exact WindowId")
        }

        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.WindowFocusChanged(true)))
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.MouseDown(MouseButton.Left, 20.0, 95.0)))
        let capturedFirst = app.windowState(first).getOrThrow()
        let uncapturedSecond = app.windowState(second).getOrThrow()
        if (capturedFirst.pointerCaptureId != "window-a.action" ||
            !uncapturedSecond.pointerCaptureId.isEmpty()) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "pointer-capture-isolation-failed", "button capture leaked outside its UiContext")
        }
        let firstBeforeKeyboard = semanticActions.first
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.KeyDown(Key.Enter, false)))
        if (semanticActions.first != firstBeforeKeyboard + 1 || semanticActions.second != 0) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "keyboard-focus-isolation-failed", "focused keyboard action escaped its exact window")
        }
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.MouseUp(MouseButton.Left, 20.0, 95.0)))
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0)))
        if (firstSceneInput.pointerDown != 1 || secondSceneInput.pointerDown != 0) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "scene-pointer-isolation-failed", "Scene3D pointer input escaped its exact WindowId")
        }

        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.WindowFocusChanged(false)))
        let _ = app.route(SdlEventEnvelope(Some(second), UiEvent.WindowFocusChanged(true)))
        if (!app.windowState(first).getOrThrow().pointerCaptureId.isEmpty()) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "focus-loss-capture-stale", "old window retained pointer capture after focus loss")
        }
        let _ = app.route(SdlEventEnvelope(Some(second), UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0)))
        if (secondSceneInput.pointerDown != 1 || firstSceneInput.pointerDown != 1) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "second-scene-pointer-isolation-failed", "second Scene3D view did not own its input")
        }

        let _ = app.route(SdlEventEnvelope(None, UiEvent.GamepadConnectionChanged(
            GamepadDevice(UInt32(77), name: "native-smoke-pad"), GamepadConnectionState.Connected)))
        let gamepad = app.route(SdlEventEnvelope(None,
            UiEvent.GamepadButtonDown(UInt32(77), GamepadButton.South)))
        let _ = app.route(SdlEventEnvelope(None,
            UiEvent.GamepadButtonUp(UInt32(77), GamepadButton.South)))
        let _ = app.route(SdlEventEnvelope(None, UiEvent.GamepadConnectionChanged(
            GamepadDevice(UInt32(77)), GamepadConnectionState.Disconnected)))
        if (gamepad.target != Some(second) || secondSceneInput.gamepadConnected != 1 ||
            secondSceneInput.gamepadDown != 1 || secondSceneInput.gamepadUp != 1 ||
            secondSceneInput.gamepadDisconnected != 1 || firstSceneInput.gamepadConnected != 0) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "active-window-gamepad-route-failed",
                "process-global gamepad lifecycle did not remain in the focused Scene3D window")
        }

        let beforeUnknownFirst = firstSceneInput.total()
        let beforeUnknownSecond = secondSceneInput.total()
        let unknown = app.route(SdlEventEnvelope(Some(WindowId(UInt32(999999))),
            UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0)))
        if (unknown.ok || unknown.code != "window-not-registered" ||
            firstSceneInput.total() != beforeUnknownFirst || secondSceneInput.total() != beforeUnknownSecond ||
            app.windowState(WindowId(UInt32(999999))).isSome()) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "unknown-window-did-not-fail-closed", "unknown WindowId mutated a managed scene")
        }

        let frames = app.step()
        if (frames.size != 2) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "double-window-step-failed", "expected two presented managed-window receipts")
        }
        if (!app.closeWindow(first) || app.semanticSnapshot(first).isSome() || app.isClosed() ||
            !app.closeWindow(second) || !app.isClosed()) {
            app.close()
            return DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "last-window-exit-failed", "managed windows did not close independently and stop after the last window")
        }
        DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Passed,
            "passed-native-double-window", "created, stepped, focused and independently closed two SDL windows")
    } catch (error: Exception) {
        match (application) {
            case Some(app) => try { app.close() } catch (_: Exception) { () }
            case None => ()
        }
        if (nativeSmokeFailureCanSkip(error.message)) {
            DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Skipped,
                "skipped-headless-runtime", error.message)
        } else {
            DesktopNativeSmokeReceipt(DesktopNativeSmokeStatus.Failed,
                "native-double-window-failed", error.message)
        }
    }
}

@Test
func desktopApplicationCreatesAndRunsTwoRealWindowsOrEmitsExplicitHeadlessReceipt(): Unit {
    let receipt = runDesktopNativeDoubleWindowSmoke()
    println("[desktop-native-double-window] ${receipt.code}: ${receipt.detail}")
    @Expect(receipt.accepted())
}
