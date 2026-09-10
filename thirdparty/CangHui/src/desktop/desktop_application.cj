package chui.desktop

import std.collection.ArrayList
import sdl.{FrameInfo, GamepadButton, GamepadConnectionState, GamepadDevice, Key, MouseButton, Rect,
    SdlEventEnvelope, SdlRuntime, SdlWindow, UiEvent, WindowId, WindowSpec, gamepadButtonName}
import sdl.input.Keyboard
import chui.core.{SemanticActionHandler, SemanticActionReceipt, SemanticActionRequest,
    SemanticInteractionPolicy, SemanticRuntime, SemanticRuntimeLimits, SemanticTreeDiff,
    SemanticTreeSnapshot, StateStore, Theme, UiContext, Widget, buildRoot, drawTooltip,
    withActiveSemanticRuntime}

/** One independently-owned desktop scene attached to a stable native window identity. */
public interface DesktopWindowSession {
    func windowId(): WindowId
    func dispatch(event: UiEvent): Bool
    func requestClose(): Unit
}

public struct WindowDispatchReceipt {
    public let ok: Bool
    public let code: String
    public let target: ?WindowId
    public let consumed: Bool
    public let applicationCloseRequested: Bool
    public let detail: String

    public init(
        ok: Bool,
        code: String,
        target: ?WindowId,
        consumed!: Bool = false,
        applicationCloseRequested!: Bool = false,
        detail!: String = ""
    ) {
        this.ok = ok
        this.code = code
        this.target = target
        this.consumed = consumed
        this.applicationCloseRequested = applicationCloseRequested
        this.detail = detail
    }
}

/** Result of one non-blocking build/layout/draw/present pass for a managed window. */
public struct DesktopWindowStepReceipt {
    public let windowId: WindowId
    public let rendered: Bool
    public let closeRequested: Bool
    public let nativeChildSurfaceCount: Int64
    public let sharedFrameSurfaceCount: Int64
    public let detail: String

    public init(
        windowId: WindowId,
        rendered: Bool,
        closeRequested: Bool,
        nativeChildSurfaceCount!: Int64 = 0,
        sharedFrameSurfaceCount!: Int64 = 0,
        detail!: String = ""
    ) {
        this.windowId = windowId
        this.rendered = rendered
        this.closeRequested = closeRequested
        this.nativeChildSurfaceCount = nativeChildSurfaceCount
        this.sharedFrameSurfaceCount = sharedFrameSurfaceCount
        this.detail = detail
    }
}

/** Window-local state proves that focus, overlays, pointer capture and 3D registration do not leak. */
public struct DesktopWindowStateReceipt {
    public let windowId: WindowId
    public let logicalWidth: Int32
    public let logicalHeight: Int32
    public let focusId: String
    public let overlayCount: Int64
    public let pointerCaptureId: String
    public let nativeChildSurfaceCount: Int64
    public let sharedFrameSurfaceCount: Int64
    public let closeRequested: Bool

    public init(
        windowId: WindowId,
        logicalWidth: Int32,
        logicalHeight: Int32,
        focusId: String,
        overlayCount: Int64,
        pointerCaptureId: String,
        nativeChildSurfaceCount: Int64,
        sharedFrameSurfaceCount: Int64,
        closeRequested: Bool
    ) {
        this.windowId = windowId
        this.logicalWidth = logicalWidth
        this.logicalHeight = logicalHeight
        this.focusId = focusId
        this.overlayCount = overlayCount
        this.pointerCaptureId = pointerCaptureId
        this.nativeChildSurfaceCount = nativeChildSurfaceCount
        this.sharedFrameSurfaceCount = sharedFrameSurfaceCount
        this.closeRequested = closeRequested
    }
}

private class RoutedGamepadState {
    let gamepadId: UInt32
    var device: GamepadDevice
    var owner: ?WindowId
    var connected: Bool = false
    let pressed = ArrayList<GamepadButton>()
    let suppressedUntilUp = ArrayList<GamepadButton>()

    init(device: GamepadDevice, owner: ?WindowId) {
        this.gamepadId = device.id
        this.device = device
        this.owner = owner
    }
}

/**
 * Pure registry and routing contract. Native events keep their window ID; process-global gamepad
 * events are assigned to the focused window and remain there until disconnect or focus transfer.
 */
protected class WindowRegistry {
    private let sessions = ArrayList<DesktopWindowSession>()
    private let gamepads = ArrayList<RoutedGamepadState>()
    private var active: ?WindowId = None

    public func register(session: DesktopWindowSession): Bool {
        let id = session.windowId()
        if (findSession(id).isSome()) { return false }
        sessions.add(session)
        if (active.isNone()) { active = Some(id) }
        true
    }

    public func unregister(id: WindowId): Bool {
        let index = match (findSessionIndex(id)) {
            case Some(value) => value
            case None => return false
        }
        let replacement = match (active) {
            case Some(current) => if (current == id) {
                remainingWindowExcluding(id)
            } else {
                Some(current)
            }
            case None => None<WindowId>
        }
        transferWindowGamepads(id, replacement)
        sessions.remove(at: index)
        active = replacement
        true
    }

    public func sessionCount(): Int64 { sessions.size }

    public func activeWindow(): ?WindowId { active }

    public func setActiveWindow(id: WindowId): Bool {
        if (findSession(id).isNone()) { return false }
        match (active) {
            case Some(previous) => if (previous == id) { return true }
            case None => ()
        }
        transferAllGamepads(Some(id))
        active = Some(id)
        true
    }

    public func dispatch(envelope: SdlEventEnvelope): WindowDispatchReceipt {
        match (envelope.windowId) {
            case Some(id) => if (isProcessGlobalGamepadEvent(envelope.event)) {
                return WindowDispatchReceipt(false, "process-global-event-has-window-id", Some(id))
            }
            case None => ()
        }
        match (envelope.event) {
            case UiEvent.Quit =>
                requestAllClose()
                return WindowDispatchReceipt(true, "application-close-requested", None,
                    applicationCloseRequested: true)
            case _ => ()
        }
        match (envelope.windowId) {
            case Some(id) => return dispatchWindowEvent(id, envelope.event)
            case None => return dispatchGlobalEvent(envelope.event)
        }
    }

    public func requestAllClose(): Unit {
        for (session in sessions.toArray()) { session.requestClose() }
    }

    private func dispatchWindowEvent(id: WindowId, event: UiEvent): WindowDispatchReceipt {
        let session = match (findSession(id)) {
            case Some(value) => value
            case None => return WindowDispatchReceipt(false, "window-not-registered", Some(id))
        }
        match (event) {
            case UiEvent.WindowFocusChanged(true) =>
                let consumed = session.dispatch(event)
                let _ = setActiveWindow(id)
                return WindowDispatchReceipt(true, "window-event-dispatched", Some(id), consumed: consumed)
            case UiEvent.WindowFocusChanged(false) =>
                let consumed = session.dispatch(event)
                match (active) {
                    case Some(current) => if (current == id) {
                        transferWindowGamepads(id, None)
                        active = None
                    }
                    case None => ()
                }
                return WindowDispatchReceipt(true, "window-event-dispatched", Some(id), consumed: consumed)
            case UiEvent.WindowCloseRequested =>
                session.requestClose()
                return WindowDispatchReceipt(true, "window-close-requested", Some(id))
            case UiEvent.WindowDestroyed =>
                let consumed = session.dispatch(event)
                let _ = unregister(id)
                return WindowDispatchReceipt(true, "window-destroyed", Some(id), consumed: consumed)
            case _ => ()
        }
        let consumed = session.dispatch(event)
        WindowDispatchReceipt(true, "window-event-dispatched", Some(id), consumed: consumed)
    }

    private func dispatchGlobalEvent(event: UiEvent): WindowDispatchReceipt {
        match (event) {
            case UiEvent.GamepadConnectionChanged(device, GamepadConnectionState.Disconnected) =>
                disconnectGamepad(device, event)
            case UiEvent.GamepadConnectionChanged(device, GamepadConnectionState.Connected) =>
                connectGamepad(device, event)
            case UiEvent.GamepadConnectionChanged(device, _) =>
                dispatchConnectedGamepad(device.id, event, "gamepad-connection")
            case UiEvent.GamepadAxisMotion(deviceId, _, _) =>
                dispatchConnectedGamepad(deviceId, event, "gamepad-event")
            case UiEvent.GamepadButtonDown(deviceId, button) =>
                gamepadButtonDown(deviceId, button, event)
            case UiEvent.GamepadButtonUp(deviceId, button) =>
                gamepadButtonUp(deviceId, button, event)
            case _ => dispatchToOptional(active, event, "active-window-event")
        }
    }

    private func isProcessGlobalGamepadEvent(event: UiEvent): Bool {
        match (event) {
            case UiEvent.GamepadConnectionChanged(_, _) => true
            case UiEvent.GamepadAxisMotion(_, _, _) => true
            case UiEvent.GamepadButtonDown(_, _) => true
            case UiEvent.GamepadButtonUp(_, _) => true
            case _ => false
        }
    }

    private func connectGamepad(device: GamepadDevice, event: UiEvent): WindowDispatchReceipt {
        let value = match (findGamepad(device.id)) {
            case Some(existing) => existing
            case None =>
                let created = RoutedGamepadState(device, active)
                gamepads.add(created)
                created
        }
        value.device = device
        value.connected = true
        if (value.owner.isNone()) { value.owner = active }
        dispatchToOptional(value.owner, event, "gamepad-connected")
    }

    private func disconnectGamepad(device: GamepadDevice, event: UiEvent): WindowDispatchReceipt {
        let value = match (findGamepad(device.id)) {
            case Some(existing) => existing
            case None => return WindowDispatchReceipt(false, "gamepad-not-connected", None)
        }
        value.device = device
        releasePressedButtons(value)
        let target = value.owner
        value.owner = None
        value.connected = false
        let receipt = dispatchToOptional(target, event, "gamepad-disconnected")
        removeGamepad(device.id)
        receipt
    }

    private func dispatchConnectedGamepad(
        deviceId: UInt32,
        event: UiEvent,
        code: String
    ): WindowDispatchReceipt {
        let value = match (findGamepad(deviceId)) {
            case Some(existing) where existing.connected => existing
            case _ => return WindowDispatchReceipt(false, "gamepad-not-connected", None)
        }
        dispatchToOptional(value.owner, event, code)
    }

    private func gamepadButtonDown(
        deviceId: UInt32,
        button: GamepadButton,
        event: UiEvent
    ): WindowDispatchReceipt {
        let value = match (findGamepad(deviceId)) {
            case Some(existing) where existing.connected => existing
            case _ => return WindowDispatchReceipt(false, "gamepad-not-connected", None)
        }
        removeButton(value.suppressedUntilUp, button)
        if (!containsButton(value.pressed, button)) { value.pressed.add(button) }
        dispatchToOptional(value.owner, event, "gamepad-event")
    }

    private func gamepadButtonUp(
        deviceId: UInt32,
        button: GamepadButton,
        event: UiEvent
    ): WindowDispatchReceipt {
        let value = match (findGamepad(deviceId)) {
            case Some(existing) where existing.connected => existing
            case _ => return WindowDispatchReceipt(false, "gamepad-not-connected", None)
        }
        if (removeButton(value.suppressedUntilUp, button)) {
            return WindowDispatchReceipt(true, "gamepad-release-suppressed", value.owner)
        }
        if (!containsButton(value.pressed, button)) {
            return WindowDispatchReceipt(false, "gamepad-button-not-pressed", value.owner)
        }
        let receipt = dispatchToOptional(value.owner, event, "gamepad-event")
        let _ = removeButton(value.pressed, button)
        receipt
    }

    private func dispatchToOptional(target: ?WindowId, event: UiEvent, code: String): WindowDispatchReceipt {
        match (target) {
            case Some(id) =>
                match (findSession(id)) {
                    case Some(session) => WindowDispatchReceipt(true, code, Some(id),
                        consumed: session.dispatch(event))
                    case None => WindowDispatchReceipt(false, "window-not-registered", Some(id))
                }
            case None => WindowDispatchReceipt(false, "no-active-window", None)
        }
    }

    private func findSession(id: WindowId): ?DesktopWindowSession {
        for (session in sessions) {
            if (session.windowId() == id) { return Some(session) }
        }
        None
    }

    private func findSessionIndex(id: WindowId): ?Int64 {
        var index: Int64 = 0
        while (index < sessions.size) {
            if (sessions[index].windowId() == id) { return Some(index) }
            index += 1
        }
        None
    }

    private func remainingWindowExcluding(id: WindowId): ?WindowId {
        var index = sessions.size - 1
        while (index >= 0) {
            let candidate = sessions[index].windowId()
            if (candidate != id) { return Some(candidate) }
            index -= 1
        }
        None
    }

    private func findGamepad(gamepadId: UInt32): ?RoutedGamepadState {
        for (value in gamepads) {
            if (value.gamepadId == gamepadId) { return Some(value) }
        }
        None
    }

    private func transferAllGamepads(target: ?WindowId): Unit {
        for (value in gamepads) {
            if (value.connected && !sameWindow(value.owner, target)) {
                transferGamepad(value, target)
            }
        }
    }

    private func transferWindowGamepads(id: WindowId, target: ?WindowId): Unit {
        for (value in gamepads) {
            match (value.owner) {
                case Some(owner) => if (owner == id && !sameWindow(value.owner, target)) {
                    transferGamepad(value, target)
                }
                case None => ()
            }
        }
    }

    private func transferGamepad(value: RoutedGamepadState, target: ?WindowId): Unit {
        let previous = value.owner
        releasePressedButtons(value)
        value.owner = None
        let _ = dispatchToOptional(previous,
            UiEvent.GamepadConnectionChanged(value.device, GamepadConnectionState.Disconnected),
            "gamepad-focus-disconnected")
        value.owner = target
        match (target) {
            case Some(_) =>
                let _ = dispatchToOptional(target,
                    UiEvent.GamepadConnectionChanged(value.device, GamepadConnectionState.Connected),
                    "gamepad-focus-connected")
            case None => ()
        }
    }

    private func releasePressedButtons(value: RoutedGamepadState): Unit {
        let previous = value.owner
        for (button in value.pressed.toArray()) {
            if (!containsButton(value.suppressedUntilUp, button)) {
                value.suppressedUntilUp.add(button)
            }
            let _ = dispatchToOptional(previous,
                UiEvent.GamepadButtonUp(value.gamepadId, button), "gamepad-focus-button-up")
        }
        value.pressed.clear()
    }

    private func removeGamepad(gamepadId: UInt32): Unit {
        var index: Int64 = gamepads.size - 1
        while (index >= 0) {
            if (gamepads[index].gamepadId == gamepadId) { gamepads.remove(at: index) }
            index -= 1
        }
    }

    private func sameWindow(first: ?WindowId, second: ?WindowId): Bool {
        match ((first, second)) {
            case (Some(left), Some(right)) => left == right
            case (None, None) => true
            case _ => false
        }
    }

    private func containsButton(values: ArrayList<GamepadButton>, button: GamepadButton): Bool {
        let code = gamepadButtonName(button)
        for (value in values) {
            if (gamepadButtonName(value) == code) { return true }
        }
        false
    }

    private func removeButton(values: ArrayList<GamepadButton>, button: GamepadButton): Bool {
        let code = gamepadButtonName(button)
        var index: Int64 = values.size - 1
        while (index >= 0) {
            if (gamepadButtonName(values[index]) == code) {
                values.remove(at: index)
                return true
            }
            index -= 1
        }
        false
    }
}

/**
 * Owns the terminal shared-frame outcome around the renderer transaction. A renderer failure must
 * release provider frames as executor-failed before outer window cleanup can observe them.
 */
protected func executeManagedSharedFrameTerminal(
    ctx: UiContext,
    renderAndPresent: () -> Unit
): String {
    try {
        renderAndPresent()
    } catch (error: Exception) {
        let _ = ctx.finishSharedFrameSurfaces("executor-failed")
        throw error
    }
    let outcome = if (ctx.sharedFrameCompositionSucceeded()) {
        "presented"
    } else if (ctx.nativeChildFrameSurfaceCount() > 0) {
        // Scene3DView registers its established native-child path as soon as a shared-frame
        // upload/sample fails. Preserve that truthful terminal outcome instead of reporting an
        // executor failure after the fallback surface has already taken ownership.
        "fallback"
    } else {
        "executor-failed"
    }
    if (!ctx.finishSharedFrameSurfaces(outcome)) {
        throw IllegalStateException("managed window shared-frame release failed")
    }
    outcome
}

/**
 * A real window-local scene. Every instance owns its SDL window, renderer-backed context, state
 * store and current declarative tree. Keeping one UiContext per window is what isolates focus,
 * overlays, pressed/drag capture and Scene3D surface registration.
 */
private class ManagedDesktopWindowSession <: DesktopWindowSession & Resource {
    private let window: SdlWindow
    private let ctx: UiContext
    private let stateStore = StateStore()
    private let semanticActionRouter: DesktopSemanticActionRouter
    private let semanticRuntime: SemanticRuntime
    private let body: () -> Unit
    private var currentWidget: ?Widget = None
    private var previousTick: UInt64
    private var wantsClose: Bool = false
    private var closed: Bool = false

    init(
        spec: WindowSpec,
        theme: Theme,
        fontScale: Float32,
        body: () -> Unit,
        semanticWindowId: String,
        semanticPolicy: SemanticInteractionPolicy,
        semanticLimits: SemanticRuntimeLimits,
        onSemanticAction: SemanticActionHandler
    ) {
        if (fontScale <= 0.0) {
            throw IllegalArgumentException("managed desktop window fontScale must be greater than zero")
        }
        // SemanticRuntime owns the identifier contract. Run the same constructor validation
        // before acquiring an SDL window so malformed public input cannot strand native state.
        if (!semanticWindowId.isEmpty()) {
            let _ = SemanticRuntime(
                semanticWindowId,
                policy: semanticPolicy,
                limits: semanticLimits,
                handler: onSemanticAction)
        }
        this.window = SdlWindow(spec)
        this.ctx = UiContext(window.renderer, theme)
        this.ctx.displayScale = window.scale
        this.ctx.fontScale = fontScale
        let resolvedSemanticWindowId = if (semanticWindowId.isEmpty()) {
            "window-${window.id.toString()}"
        } else {
            semanticWindowId
        }
        let actionRouter = DesktopSemanticActionRouter(this.ctx, fallback: onSemanticAction)
        this.semanticActionRouter = actionRouter
        this.semanticRuntime = SemanticRuntime(
            resolvedSemanticWindowId,
            policy: semanticPolicy,
            limits: semanticLimits,
            handler: {request => actionRouter.dispatch(request)})
        this.body = body
        this.previousTick = window.ticks()
    }

    public func windowId(): WindowId { window.id }

    public func requestClose(): Unit { wantsClose = true }

    func closeRequested(): Bool { wantsClose || ctx.shouldClose || closed }

    public func isClosed(): Bool { closed }

    /** Builds and presents exactly one frame, then returns immediately. */
    func step(): DesktopWindowStepReceipt {
        if (closed || wantsClose || ctx.shouldClose) {
            return DesktopWindowStepReceipt(window.id, false, true, detail: "close-requested")
        }
        let currentTick = window.ticks()
        let delta = if (currentTick >= previousTick) { currentTick - previousTick } else { UInt64(0) }
        previousTick = currentTick
        ctx.frame = FrameInfo(currentTick, delta)
        ctx.viewportWidth = Float32(window.width)
        ctx.viewportHeight = Float32(window.height)

        let widget = buildRoot(body, stateStore)
        currentWidget = Some(widget)
        ctx.adoptFocusRing(stateStore.focusRing())
        semanticActionRouter.bind(widget)
        // Scene3DView registers only against this window's frame-local context during layout.
        ctx.beginFrameSurfaceRegistration()
        widget.layout(ctx, Rect(0.0, 0.0, Float32(window.width), Float32(window.height)))
        let _ = widget.handle(ctx, UiEvent.Frame(ctx.frame))

        ctx.beginSharedFrameCompositionAttempt()
        let sharedOutcome = executeManagedSharedFrameTerminal(ctx, { =>
            ctx.syncThemeResources()
            ctx.renderer.beginScene(Float32(window.width), Float32(window.height), ctx.theme.bg)
            ctx.clearTooltip()
            ctx.clearActiveOverlay()
            ctx.clearTextInputAnchor()
            semanticRuntime.beginFrame()
            try {
                withActiveSemanticRuntime(semanticRuntime, { =>
                    widget.draw(ctx)
                    ctx.drawInkRipples()
                    if (!ctx.hasOverlay()) {
                        drawTooltip(ctx, Float32(window.width), Float32(window.height))
                    }
                    ctx.drawActiveOverlay()
                })
                let _ = semanticRuntime.commitFrame()
            } catch (error: Exception) {
                semanticRuntime.cancelFrame()
                throw error
            }
            applyTextInputAnchor()
            ctx.renderer.endScene()
            ctx.renderer.present()
        })
        if (ctx.shouldClose) { wantsClose = true }
        DesktopWindowStepReceipt(
            window.id,
            true,
            closeRequested(),
            nativeChildSurfaceCount: ctx.nativeChildFrameSurfaceCount(),
            sharedFrameSurfaceCount: ctx.sharedFrameSurfaceCount(),
            detail: if (sharedOutcome == "presented") {
                "presented"
            } else {
                "presented-with-shared-frame-failure"
            })
    }

    /** Routes one already-window-scoped event against this window's current tree. */
    public func dispatch(rawEvent: UiEvent): Bool {
        if (closed) { return false }
        let event = scaleManagedWindowEvent(rawEvent, window.scale)
        match (event) {
            case UiEvent.WindowDestroyed => wantsClose = true
            case _ => ()
        }
        let widget = match (currentWidget) {
            case Some(value) => value
            case None => return false
        }
        preparePointer(event)
        let consumed = routeEvent(widget, event)
        completePointer(event)
        if (ctx.shouldClose) { wantsClose = true }
        consumed
    }

    func focusNativeWindow(): Unit { window.raiseWindow() }

    func delay(ms: UInt32): Unit { window.delay(ms) }

    func stateReceipt(): DesktopWindowStateReceipt {
        let capture = if (!ctx.dragId.isEmpty()) { ctx.dragId } else { ctx.pressedId }
        DesktopWindowStateReceipt(
            window.id,
            window.width,
            window.height,
            ctx.focusId,
            ctx.overlayCount(),
            capture,
            ctx.nativeChildFrameSurfaceCount(),
            ctx.sharedFrameSurfaceCount(),
            closeRequested())
    }

    func semanticSnapshot(): SemanticTreeSnapshot { semanticRuntime.snapshot() }

    func semanticDiff(previous: SemanticTreeSnapshot): SemanticTreeDiff {
        semanticRuntime.diff(previous)
    }

    func dispatchSemanticAction(request: SemanticActionRequest): SemanticActionReceipt {
        semanticRuntime.dispatch(request)
    }

    public func close(): Unit {
        if (closed) { return }
        let _ = ctx.finishSharedFrameSurfaces("abandoned")
        semanticActionRouter.clear()
        stateStore.clear()
        window.close()
        closed = true
        wantsClose = true
        currentWidget = None
    }

    private func routeEvent(widget: Widget, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Quit => ctx.requestClose(); true
            case UiEvent.WindowCloseRequested => ctx.requestClose(); true
            case UiEvent.WindowDestroyed => ctx.requestClose(); true
            case UiEvent.WindowResized(width, height) =>
                window.updateLogicalSize(width, height)
                widget.handle(ctx, event)
            case UiEvent.WindowPixelSizeChanged(width, height) =>
                window.updatePixelSize(width, height)
                widget.handle(ctx, event)
            case UiEvent.DeviceRotationChanged(rotation) =>
                ctx.updateDeviceRotation(rotation)
                widget.handle(ctx, event)
            case UiEvent.WindowFocusChanged(false) =>
                ctx.leftMouseDown = false
                ctx.clearDrag()
                ctx.clearPress()
                widget.handle(ctx, event)
            case UiEvent.MouseMove(_, _) =>
                ctx.beginHoverTest()
                let consumed = if (ctx.dispatchOverlay(event)) { true } else { widget.handle(ctx, event) }
                ctx.settleHover()
                consumed
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                ctx.recordPress(x, y)
                if (ctx.dispatchOverlay(event)) {
                    true
                } else {
                    ctx.beginPointerPress()
                    let consumed = widget.handle(ctx, event)
                    ctx.settleFocusAfterPress()
                    consumed
                }
            case UiEvent.KeyDown(Key.Tab, _) =>
                if (ctx.dispatchOverlay(event)) {
                    true
                } else {
                    if (Keyboard.modifiers().shift) { ctx.focusPrevious() } else { ctx.focusNext() }
                    true
                }
            case _ => if (ctx.dispatchOverlay(event)) { true } else { widget.handle(ctx, event) }
        }
    }

    private func preparePointer(event: UiEvent): Unit {
        match (event) {
            case UiEvent.MouseMove(x, y) => rememberMouse(x, y)
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                rememberMouse(x, y)
                ctx.leftMouseDown = true
            case UiEvent.MouseUp(MouseButton.Left, x, y) => rememberMouse(x, y)
            case UiEvent.DropFile(_, x, y) => rememberMouse(x, y)
            case UiEvent.DropText(_, x, y) => rememberMouse(x, y)
            case UiEvent.DropPosition(x, y) => rememberMouse(x, y)
            case _ => ()
        }
    }

    private func completePointer(event: UiEvent): Unit {
        match (event) {
            case UiEvent.MouseUp(MouseButton.Left, _, _) =>
                ctx.leftMouseDown = false
                ctx.clearDrag()
                ctx.clearPress()
            case _ => ()
        }
    }

    private func rememberMouse(x: Float32, y: Float32): Unit {
        ctx.mouseX = x
        ctx.mouseY = y
    }

    private func applyTextInputAnchor(): Unit {
        match (ctx.textInputAnchorRect()) {
            case Some(anchor) => try {
                window.setTextInputArea(anchor)
            } catch (_: Exception) {
                ()
            }
            case None => ()
        }
    }
}

/** Applies the same physical-to-logical pointer conversion as SdlWindow.pollEventEnvelope. */
private func scaleManagedWindowEvent(event: UiEvent, scale: Float32): UiEvent {
    if (scale == 1.0) { return event }
    match (event) {
        case UiEvent.MouseMove(x, y) => UiEvent.MouseMove(x / scale, y / scale)
        case UiEvent.MouseDown(button, x, y) => UiEvent.MouseDown(button, x / scale, y / scale)
        case UiEvent.MouseUp(button, x, y) => UiEvent.MouseUp(button, x / scale, y / scale)
        case UiEvent.MouseWheel(dx, dy, x, y) => UiEvent.MouseWheel(dx, dy, x / scale, y / scale)
        case UiEvent.DropFile(path, x, y) => UiEvent.DropFile(path, x / scale, y / scale)
        case UiEvent.DropText(text, x, y) => UiEvent.DropText(text, x / scale, y / scale)
        case UiEvent.DropPosition(x, y) => UiEvent.DropPosition(x / scale, y / scale)
        case UiEvent.WindowResized(width, height) => UiEvent.WindowResized(
            Int32(Float32(width) / scale), Int32(Float32(height) / scale))
        case _ => event
    }
}

/**
 * One process-level desktop event pump plus a registry of independently-owned window scenes.
 * `openWindow` paints once before returning; later `step` calls are non-blocking and `run` simply
 * repeats pump + step until the final registered window closes.
 */
public class DesktopApplication <: Resource {
    private let runtime: SdlRuntime
    private let windows: WindowRegistry
    private let managedWindows = ArrayList<ManagedDesktopWindowSession>()
    private var closed: Bool = false

    public init() {
        runtime = SdlRuntime()
        windows = WindowRegistry()
    }

    public func registerWindowSession(session: DesktopWindowSession): Bool {
        if (closed) { return false }
        windows.register(session)
    }

    public func unregisterWindowSession(id: WindowId): Bool {
        match (findManagedWindowIndex(id)) {
            case Some(_) => closeWindow(id)
            case None =>
                let removed = windows.unregister(id)
                if (removed) { closeRuntimeAfterLastWindow() }
                removed
        }
    }

    /** Creates, registers and presents a native window without entering a nested event loop. */
    public func openWindow(
        spec: WindowSpec,
        body: () -> Unit,
        theme!: Theme = Theme.light(),
        fontScale!: Float32 = 1.0,
        semanticWindowId!: String = "",
        semanticPolicy!: SemanticInteractionPolicy = SemanticInteractionPolicy(),
        semanticLimits!: SemanticRuntimeLimits = SemanticRuntimeLimits(),
        onSemanticAction!: SemanticActionHandler = {_ => false}
    ): WindowId {
        if (closed) { throw IllegalStateException("cannot open a window on a closed DesktopApplication") }
        let session = ManagedDesktopWindowSession(
            spec,
            theme,
            fontScale,
            body,
            semanticWindowId,
            semanticPolicy,
            semanticLimits,
            onSemanticAction)
        let id = session.windowId()
        if (!windows.register(session)) {
            session.close()
            throw IllegalStateException("native window identity ${id.toString()} is already registered")
        }
        managedWindows.add(session)
        let _ = windows.setActiveWindow(id)
        try {
            let _ = session.step()
            finishRequestedManagedWindows()
            closeRuntimeAfterLastWindow()
            id
        } catch (error: Exception) {
            discardManagedWindow(id)
            throw error
        }
    }

    /** Raises a managed native window and selects it as the target for process-global gamepad events. */
    public func focusWindow(id: WindowId): Bool {
        if (closed) { return false }
        match (findManagedWindow(id)) {
            case Some(session) =>
                session.focusNativeWindow()
                windows.setActiveWindow(id)
            case None => false
        }
    }

    /** Closes one managed window immediately on the application owner thread. */
    public func closeWindow(id: WindowId): Bool {
        match (findManagedWindowIndex(id)) {
            case Some(index) =>
                managedWindows[index].requestClose()
                closeManagedWindowAt(index)
                closeRuntimeAfterLastWindow()
                true
            case None => false
        }
    }

    public func activeWindow(): ?WindowId { windows.activeWindow() }

    /** Read-only count of application-owned sessions; registry mutation stays lifecycle-gated. */
    public func sessionCount(): Int64 { windows.sessionCount() }

    /** Returns the isolated scene-state receipt for one framework-managed native window. */
    public func windowState(id: WindowId): ?DesktopWindowStateReceipt {
        match (findManagedWindow(id)) {
            case Some(session) => Some(session.stateReceipt())
            case None => None
        }
    }

    /** Latest copy-isolated semantic snapshot for one framework-managed window. */
    public func semanticSnapshot(id: WindowId): ?SemanticTreeSnapshot {
        match (findManagedWindow(id)) {
            case Some(session) => Some(session.semanticSnapshot())
            case None => None
        }
    }

    public func semanticDiff(id: WindowId, previous: SemanticTreeSnapshot): ?SemanticTreeDiff {
        match (findManagedWindow(id)) {
            case Some(session) => Some(session.semanticDiff(previous))
            case None => None
        }
    }

    /** Dispatches a typed action only to the exact managed window and committed revision. */
    public func dispatchSemanticAction(
        id: WindowId,
        request: SemanticActionRequest
    ): ?SemanticActionReceipt {
        match (findManagedWindow(id)) {
            case Some(session) => Some(session.dispatchSemanticAction(request))
            case None => None
        }
    }

    public func route(envelope: SdlEventEnvelope): WindowDispatchReceipt {
        if (closed) {
            return WindowDispatchReceipt(false, "application-closed", envelope.windowId)
        }
        let receipt = windows.dispatch(envelope)
        finishRequestedManagedWindows()
        if (receipt.applicationCloseRequested) {
            finishApplicationRuntime()
        } else {
            closeRuntimeAfterLastWindow()
        }
        receipt
    }

    public func pumpOne(): ?WindowDispatchReceipt {
        if (closed) { return None }
        match (runtime.pollEvent()) {
            case Some(envelope) => Some(route(envelope))
            case None => None
        }
    }

    public func pump(limit!: Int64 = 64): Array<WindowDispatchReceipt> {
        if (limit <= 0 || limit > 4096) {
            throw IllegalArgumentException("desktop event pump limit must be in 1..4096")
        }
        let receipts = ArrayList<WindowDispatchReceipt>()
        while (receipts.size < limit) {
            match (pumpOne()) {
                case Some(receipt) => receipts.add(receipt)
                case None => break
            }
        }
        receipts.toArray()
    }

    /** Builds/layouts/draws/presents every managed window once and returns without waiting. */
    public func step(): Array<DesktopWindowStepReceipt> {
        if (closed) { return [] }
        let receipts = ArrayList<DesktopWindowStepReceipt>()
        for (session in managedWindows.toArray()) {
            if (!session.closeRequested()) {
                try {
                    receipts.add(session.step())
                } catch (error: Exception) {
                    session.requestClose()
                    finishRequestedManagedWindows()
                    throw error
                }
            }
        }
        finishRequestedManagedWindows()
        closeRuntimeAfterLastWindow()
        receipts.toArray()
    }

    /** Convenience blocking loop built entirely from the public non-blocking pump/step surface. */
    public func run(): Unit {
        if (closed) { return }
        var failure: ?Exception = None
        try {
            while (!closed && windows.sessionCount() > 0) {
                let _ = pump()
                if (closed) { break }
                let _ = step()
                if (!closed) { delayOneMillisecond() }
            }
            closeRuntimeAfterLastWindow()
        } catch (error: Exception) {
            failure = Some(error)
        }
        match (failure) {
            case Some(error) =>
                try { close() } catch (_: Exception) { () }
                throw error
            case None => ()
        }
    }

    public func isClosed(): Bool { closed }

    public func close(): Unit {
        if (closed) { return }
        windows.requestAllClose()
        finishRequestedManagedWindows()
        finishApplicationRuntime()
    }

    private func findManagedWindow(id: WindowId): ?ManagedDesktopWindowSession {
        for (session in managedWindows) {
            if (session.windowId() == id) { return Some(session) }
        }
        None
    }

    private func findManagedWindowIndex(id: WindowId): ?Int64 {
        var index: Int64 = 0
        while (index < managedWindows.size) {
            if (managedWindows[index].windowId() == id) { return Some(index) }
            index += 1
        }
        None
    }

    /** Open failed before ownership could be returned; clean only that partial window and stay usable. */
    private func discardManagedWindow(id: WindowId): Unit {
        match (findManagedWindowIndex(id)) {
            case Some(index) =>
                // Registry teardown emits any outstanding device cleanup while the session can
                // still consume it; native destruction follows ownership release.
                let _ = windows.unregister(id)
                try { managedWindows[index].close() } catch (_: Exception) { () }
                managedWindows.remove(at: index)
            case None => ()
        }
    }

    private func finishRequestedManagedWindows(): Unit {
        var index = managedWindows.size - 1
        while (index >= 0) {
            if (managedWindows[index].closeRequested()) {
                closeManagedWindowAt(index)
            }
            index -= 1
        }
    }

    private func closeManagedWindowAt(index: Int64): Unit {
        let session = managedWindows[index]
        let _ = windows.unregister(session.windowId())
        session.close()
        managedWindows.remove(at: index)
    }

    private func closeRuntimeAfterLastWindow(): Unit {
        if (!closed && windows.sessionCount() == 0) {
            finishApplicationRuntime()
        }
    }

    private func finishApplicationRuntime(): Unit {
        if (closed) { return }
        // A process-level quit also owns every managed native window, even when a host-owned
        // session remains registered only long enough to observe its close request.
        var index = managedWindows.size - 1
        while (index >= 0) {
            closeManagedWindowAt(index)
            index -= 1
        }
        runtime.close()
        closed = true
    }

    private func delayOneMillisecond(): Unit {
        if (!managedWindows.isEmpty()) {
            managedWindows[0].delay(UInt32(1))
        }
    }
}
