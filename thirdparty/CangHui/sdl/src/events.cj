package sdl

public enum Key {
    | Escape
    | Backspace
    | Enter
    | Tab
    | Delete
    | Space
    | Home
    | End
    | Left
    | Right
    | Up
    | Down
    | Letter(UInt8)
    | Digit(UInt8)
    | RawScancode(Int32)
}

public enum MouseButton {
    | Left
    | Middle
    | Right
    | RawCode(UInt8)
}

/** A gamepad axis named by physical location rather than a platform brand. */
public enum GamepadAxis {
    | LeftX
    | LeftY
    | RightX
    | RightY
    | LeftTrigger
    | RightTrigger
    | RawCode(UInt8)
}

public func gamepadAxisName(axis: GamepadAxis): String {
    match (axis) {
        case GamepadAxis.LeftX => "left-x"
        case GamepadAxis.LeftY => "left-y"
        case GamepadAxis.RightX => "right-x"
        case GamepadAxis.RightY => "right-y"
        case GamepadAxis.LeftTrigger => "left-trigger"
        case GamepadAxis.RightTrigger => "right-trigger"
        case GamepadAxis.RawCode(value) => "raw-${value}"
    }
}

/** A gamepad button named by physical location rather than A/B/X/Y artwork. */
public enum GamepadButton {
    | South
    | East
    | West
    | North
    | Back
    | Guide
    | Start
    | LeftStick
    | RightStick
    | LeftShoulder
    | RightShoulder
    | DPadUp
    | DPadDown
    | DPadLeft
    | DPadRight
    | Misc1
    | RightPaddle1
    | LeftPaddle1
    | RightPaddle2
    | LeftPaddle2
    | Touchpad
    | Misc2
    | Misc3
    | Misc4
    | Misc5
    | Misc6
    | RawCode(UInt8)
}

public func gamepadButtonName(button: GamepadButton): String {
    match (button) {
        case GamepadButton.South => "south"
        case GamepadButton.East => "east"
        case GamepadButton.West => "west"
        case GamepadButton.North => "north"
        case GamepadButton.Back => "back"
        case GamepadButton.Guide => "guide"
        case GamepadButton.Start => "start"
        case GamepadButton.LeftStick => "left-stick"
        case GamepadButton.RightStick => "right-stick"
        case GamepadButton.LeftShoulder => "left-shoulder"
        case GamepadButton.RightShoulder => "right-shoulder"
        case GamepadButton.DPadUp => "dpad-up"
        case GamepadButton.DPadDown => "dpad-down"
        case GamepadButton.DPadLeft => "dpad-left"
        case GamepadButton.DPadRight => "dpad-right"
        case GamepadButton.Misc1 => "misc-1"
        case GamepadButton.RightPaddle1 => "right-paddle-1"
        case GamepadButton.LeftPaddle1 => "left-paddle-1"
        case GamepadButton.RightPaddle2 => "right-paddle-2"
        case GamepadButton.LeftPaddle2 => "left-paddle-2"
        case GamepadButton.Touchpad => "touchpad"
        case GamepadButton.Misc2 => "misc-2"
        case GamepadButton.Misc3 => "misc-3"
        case GamepadButton.Misc4 => "misc-4"
        case GamepadButton.Misc5 => "misc-5"
        case GamepadButton.Misc6 => "misc-6"
        case GamepadButton.RawCode(value) => "raw-${value}"
    }
}

public struct GamepadDevice {
    public let id: UInt32
    public let name: String

    public init(id: UInt32, name!: String = "") {
        this.id = id
        this.name = name
    }
}

public enum GamepadConnectionState {
    | Connected
    | Disconnected
    | Remapped
    | Unavailable(String)
}

public func gamepadConnectionStateName(state: GamepadConnectionState): String {
    match (state) {
        case GamepadConnectionState.Connected => "connected"
        case GamepadConnectionState.Disconnected => "disconnected"
        case GamepadConnectionState.Remapped => "remapped"
        case GamepadConnectionState.Unavailable(_) => "unavailable"
    }
}

public struct FrameInfo {
    public let elapsedMs: UInt64
    public let deltaMs: UInt64

    public init(elapsedMs: UInt64, deltaMs: UInt64) {
        this.elapsedMs = elapsedMs
        this.deltaMs = deltaMs
    }
}

/** Lifecycle phase for a platform IME preedit transaction. */
public enum TextCompositionPhase {
    | Begin
    | Update
    | Commit
    | Cancel
}

/**
 * Portable IME composition data.
 *
 * `selectionStart` and `selectionLength` count UTF-8 characters in `text`, matching SDL3.
 * A replacement range names exact UTF-8 byte boundaries in the durable document; `-1/-1`
 * means that the focused text control captures its current selection when composition begins.
 */
public struct TextCompositionEvent {
    public let phase: TextCompositionPhase
    public let text: String
    public let selectionStart: Int64
    public let selectionLength: Int64
    public let replacementStartByte: Int64
    public let replacementEndByte: Int64

    public init(
        phase: TextCompositionPhase,
        text!: String = "",
        selectionStart!: Int64 = -1,
        selectionLength!: Int64 = -1,
        replacementStartByte!: Int64 = -1,
        replacementEndByte!: Int64 = -1
    ) {
        if (selectionStart < -1 || selectionLength < -1) {
            throw IllegalArgumentException("composition selection must use -1 or a non-negative character range")
        }
        let replacementUnset = replacementStartByte == -1 && replacementEndByte == -1
        let replacementValid = replacementStartByte >= 0 && replacementEndByte >= replacementStartByte
        if (!replacementUnset && !replacementValid) {
            throw IllegalArgumentException("composition replacement must use -1/-1 or a non-negative byte range")
        }
        this.phase = phase
        this.text = text
        this.selectionStart = selectionStart
        this.selectionLength = selectionLength
        this.replacementStartByte = replacementStartByte
        this.replacementEndByte = replacementEndByte
    }
}

/** A normalized device posture used by layout. Raw gyroscope samples stay provider-owned. */
public enum DeviceRotation {
    | Unknown
    | Portrait
    | LandscapeClockwise
    | PortraitUpsideDown
    | LandscapeCounterClockwise
}

/** Identifies which host surface normalized a device posture event. */
public enum DeviceRotationSource {
    | Gyroscope
    | Display
    | Host
    | Synthetic
}

/** One stable quarter-turn reported by a platform orientation provider. */
public struct DeviceRotationEvent {
    public let rotation: DeviceRotation
    public let source: DeviceRotationSource
    public let timestampMs: UInt64

    public init(
        rotation: DeviceRotation,
        source!: DeviceRotationSource = DeviceRotationSource.Host,
        timestampMs!: UInt64 = UInt64(0)
    ) {
        this.rotation = rotation
        this.source = source
        this.timestampMs = timestampMs
    }
}

public func deviceRotationName(rotation: DeviceRotation): String {
    match (rotation) {
        case DeviceRotation.Unknown => "unknown"
        case DeviceRotation.Portrait => "portrait"
        case DeviceRotation.LandscapeClockwise => "landscape-clockwise"
        case DeviceRotation.PortraitUpsideDown => "portrait-upside-down"
        case DeviceRotation.LandscapeCounterClockwise => "landscape-counter-clockwise"
    }
}

public func deviceRotationSourceName(source: DeviceRotationSource): String {
    match (source) {
        case DeviceRotationSource.Gyroscope => "gyroscope"
        case DeviceRotationSource.Display => "display"
        case DeviceRotationSource.Host => "host"
        case DeviceRotationSource.Synthetic => "synthetic"
    }
}

/** Whether this posture uses a landscape layout. Unknown deliberately resolves to false here. */
public func deviceRotationIsLandscape(rotation: DeviceRotation): Bool {
    match (rotation) {
        case DeviceRotation.LandscapeClockwise => true
        case DeviceRotation.LandscapeCounterClockwise => true
        case _ => false
    }
}

/**
 * Signed quarter-turn from one stable posture to another, in screen-clockwise degrees.
 *
 * Opposite postures deliberately retain direction: portrait -> upside-down is +180,
 * while the reverse is -180; clockwise-landscape -> counter-clockwise-landscape is
 * -180, while the reverse is +180. Unknown has no physical direction and returns zero.
 */
public func deviceRotationDeltaDegrees(from: DeviceRotation, to: DeviceRotation): Float32 {
    if (deviceRotationIsUnknown(from) || deviceRotationIsUnknown(to)) {
        return 0.0
    }
    var delta = deviceRotationDegrees(to) - deviceRotationDegrees(from)
    if (delta > 180.0) { delta -= 360.0 }
    if (delta < -180.0) { delta += 360.0 }
    delta
}

private func deviceRotationDegrees(rotation: DeviceRotation): Float32 {
    match (rotation) {
        case DeviceRotation.Portrait => 0.0
        case DeviceRotation.LandscapeClockwise => 90.0
        case DeviceRotation.PortraitUpsideDown => 180.0
        case DeviceRotation.LandscapeCounterClockwise => -90.0
        case DeviceRotation.Unknown => 0.0
    }
}

private func deviceRotationIsUnknown(rotation: DeviceRotation): Bool {
    match (rotation) {
        case DeviceRotation.Unknown => true
        case _ => false
    }
}

public enum UiEvent {
    | Frame(FrameInfo)
    | Quit
    | WindowResized(Int32, Int32)
    | WindowShown
    | WindowHidden
    | WindowExposed
    | WindowMoved(Int32, Int32)
    | WindowPixelSizeChanged(Int32, Int32)
    | WindowMinimized
    | WindowMaximized
    | WindowRestored
    | WindowFocusChanged(Bool)
    | WindowCloseRequested
    | WindowDestroyed
    | DeviceRotationChanged(DeviceRotationEvent)
    | KeyDown(Key, Bool)
    | KeyUp(Key)
    | TextComposition(TextCompositionEvent)
    | TextInput(String)
    | MouseMove(Float32, Float32)
    | MouseDown(MouseButton, Float32, Float32)
    | MouseUp(MouseButton, Float32, Float32)
    | MouseWheel(Float32, Float32, Float32, Float32)
    | GamepadConnectionChanged(GamepadDevice, GamepadConnectionState)
    | GamepadAxisMotion(UInt32, GamepadAxis, Float32)
    | GamepadButtonDown(UInt32, GamepadButton)
    | GamepadButtonUp(UInt32, GamepadButton)
    | DropBegin
    | DropFile(String, Float32, Float32)
    | DropText(String, Float32, Float32)
    | DropPosition(Float32, Float32)
    | DropComplete
    | Unknown(UInt32)
}

/** Stable SDL window identity. Zero is reserved for process-global events. */
public struct WindowId <: Equatable<WindowId> {
    public let raw: UInt32

    public init(raw: UInt32) {
        if (raw == UInt32(0)) { throw IllegalArgumentException("window id must be non-zero") }
        this.raw = raw
    }

    public operator func ==(other: WindowId): Bool { raw == other.raw }
    public operator func !=(other: WindowId): Bool { raw != other.raw }

    public func toString(): String { raw.toString() }
}

/** Carries window identity without contaminating process-global gamepad and quit events. */
public struct SdlEventEnvelope {
    public let windowId: ?WindowId
    public let event: UiEvent

    public init(windowId: ?WindowId, event: UiEvent) {
        this.windowId = windowId
        this.event = event
    }
}

internal func decodeEvent(raw: SdlEvent): UiEvent {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    var decoded = UiEvent.Unknown(UInt32(0))
    try (eventResource = eventPtr.asResource()) {
        unsafe { eventResource.value.write(raw) }
        let common = unsafe { CPointer<SdlCommonEvent>(eventResource.value).read() }
        let eventType = common.eventType

        // Only SDL_EVENT_QUIT ends the app. For a single-window desktop app SDL raises
        // it when the last window's close button is pressed. SDL_EVENT_WINDOW_CLOSE_REQUESTED
        // is intentionally NOT treated as quit: Windows can emit a spurious close request
        // during window creation, which would otherwise flash the window shut on startup.
        if (eventType == SDL_EVENT_QUIT) {
            decoded = UiEvent.Quit
        } else if (eventType == SDL_EVENT_WINDOW_SHOWN) {
            decoded = UiEvent.WindowShown
        } else if (eventType == SDL_EVENT_WINDOW_HIDDEN) {
            decoded = UiEvent.WindowHidden
        } else if (eventType == SDL_EVENT_WINDOW_EXPOSED) {
            decoded = UiEvent.WindowExposed
        } else if (eventType == SDL_EVENT_WINDOW_MOVED) {
            let window = unsafe { CPointer<SdlWindowEvent>(eventResource.value).read() }
            decoded = UiEvent.WindowMoved(window.data1, window.data2)
        } else if (eventType == SDL_EVENT_WINDOW_RESIZED) {
            let window = unsafe { CPointer<SdlWindowEvent>(eventResource.value).read() }
            decoded = UiEvent.WindowResized(window.data1, window.data2)
        } else if (eventType == SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED ||
            eventType == SDL_EVENT_WINDOW_METAL_VIEW_RESIZED) {
            let window = unsafe { CPointer<SdlWindowEvent>(eventResource.value).read() }
            decoded = UiEvent.WindowPixelSizeChanged(window.data1, window.data2)
        } else if (eventType == SDL_EVENT_WINDOW_MINIMIZED) {
            decoded = UiEvent.WindowMinimized
        } else if (eventType == SDL_EVENT_WINDOW_MAXIMIZED) {
            decoded = UiEvent.WindowMaximized
        } else if (eventType == SDL_EVENT_WINDOW_RESTORED) {
            decoded = UiEvent.WindowRestored
        } else if (eventType == SDL_EVENT_WINDOW_FOCUS_GAINED) {
            decoded = UiEvent.WindowFocusChanged(true)
        } else if (eventType == SDL_EVENT_WINDOW_FOCUS_LOST) {
            decoded = UiEvent.WindowFocusChanged(false)
        } else if (eventType == SDL_EVENT_WINDOW_CLOSE_REQUESTED) {
            decoded = UiEvent.WindowCloseRequested
        } else if (eventType == SDL_EVENT_WINDOW_DESTROYED) {
            decoded = UiEvent.WindowDestroyed
        } else if (eventType == SDL_EVENT_KEY_DOWN || eventType == SDL_EVENT_KEY_UP) {
            let keyEvent = unsafe { CPointer<SdlKeyboardEvent>(eventResource.value).read() }
            if (eventType == SDL_EVENT_KEY_DOWN) {
                decoded = UiEvent.KeyDown(keyFromScancode(keyEvent.scancode), keyEvent.repeat)
            } else {
                decoded = UiEvent.KeyUp(keyFromScancode(keyEvent.scancode))
            }
        } else if (eventType == SDL_EVENT_TEXT_EDITING) {
            let editing = unsafe { CPointer<SdlTextEditingEvent>(eventResource.value).read() }
            let value = if (editing.text.isNull()) { "" } else { CString(editing.text).toString() }
            decoded = UiEvent.TextComposition(TextCompositionEvent(
                if (value.isEmpty()) { TextCompositionPhase.Cancel } else { TextCompositionPhase.Update },
                text: value,
                selectionStart: Int64(editing.start),
                selectionLength: Int64(editing.length)
            ))
        } else if (eventType == SDL_EVENT_TEXT_INPUT) {
            let text = unsafe { CPointer<SdlTextInputEvent>(eventResource.value).read() }
            if (text.text.isNull()) {
                decoded = UiEvent.TextInput("")
            } else {
                decoded = UiEvent.TextInput(CString(text.text).toString())
            }
        } else if (eventType == SDL_EVENT_MOUSE_MOTION) {
            let motion = unsafe { CPointer<SdlMouseMotionEvent>(eventResource.value).read() }
            decoded = UiEvent.MouseMove(motion.x, motion.y)
        } else if (eventType == SDL_EVENT_MOUSE_BUTTON_DOWN || eventType == SDL_EVENT_MOUSE_BUTTON_UP) {
            let button = unsafe { CPointer<SdlMouseButtonEvent>(eventResource.value).read() }
            if (eventType == SDL_EVENT_MOUSE_BUTTON_DOWN) {
                decoded = UiEvent.MouseDown(buttonFromCode(button.button), button.x, button.y)
            } else {
                decoded = UiEvent.MouseUp(buttonFromCode(button.button), button.x, button.y)
            }
        } else if (eventType == SDL_EVENT_MOUSE_WHEEL) {
            let wheel = unsafe { CPointer<SdlMouseWheelEvent>(eventResource.value).read() }
            decoded = UiEvent.MouseWheel(wheel.x, wheel.y, wheel.mouseX, wheel.mouseY)
        } else if (eventType == SDL_EVENT_GAMEPAD_AXIS_MOTION) {
            let axis = unsafe { CPointer<SdlGamepadAxisEvent>(eventResource.value).read() }
            decoded = UiEvent.GamepadAxisMotion(axis.which, gamepadAxisFromCode(axis.axis),
                normalizeGamepadAxis(axis.axis, axis.value))
        } else if (eventType == SDL_EVENT_GAMEPAD_BUTTON_DOWN || eventType == SDL_EVENT_GAMEPAD_BUTTON_UP) {
            let button = unsafe { CPointer<SdlGamepadButtonEvent>(eventResource.value).read() }
            if (eventType == SDL_EVENT_GAMEPAD_BUTTON_DOWN) {
                decoded = UiEvent.GamepadButtonDown(button.which, gamepadButtonFromCode(button.button))
            } else {
                decoded = UiEvent.GamepadButtonUp(button.which, gamepadButtonFromCode(button.button))
            }
        } else if (eventType == SDL_EVENT_GAMEPAD_ADDED || eventType == SDL_EVENT_GAMEPAD_REMOVED ||
            eventType == SDL_EVENT_GAMEPAD_REMAPPED) {
            let device = unsafe { CPointer<SdlGamepadDeviceEvent>(eventResource.value).read() }
            let state = if (eventType == SDL_EVENT_GAMEPAD_ADDED) {
                GamepadConnectionState.Connected
            } else if (eventType == SDL_EVENT_GAMEPAD_REMOVED) {
                GamepadConnectionState.Disconnected
            } else {
                GamepadConnectionState.Remapped
            }
            decoded = UiEvent.GamepadConnectionChanged(GamepadDevice(device.which), state)
        } else if (isDropEvent(eventType)) {
            let drop = unsafe { CPointer<SdlDropEvent>(eventResource.value).read() }
            decoded = decodeDropEvent(eventType, drop)
        } else {
            decoded = UiEvent.Unknown(eventType)
        }
    }
    decoded
}

internal func decodeEventEnvelope(raw: SdlEvent): SdlEventEnvelope {
    SdlEventEnvelope(rawEventWindowId(raw), decodeEvent(raw))
}

private func rawEventWindowId(raw: SdlEvent): ?WindowId {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    var result: ?WindowId = None
    try (eventResource = eventPtr.asResource()) {
        unsafe { eventResource.value.write(raw) }
        let common = unsafe { CPointer<SdlCommonEvent>(eventResource.value).read() }
        let eventType = common.eventType
        var rawId: UInt32 = UInt32(0)
        if (eventType >= SDL_EVENT_WINDOW_SHOWN && eventType <= SDL_EVENT_WINDOW_DESTROYED) {
            rawId = unsafe { CPointer<SdlWindowEvent>(eventResource.value).read() }.windowID
        } else if (eventType == SDL_EVENT_KEY_DOWN || eventType == SDL_EVENT_KEY_UP) {
            rawId = unsafe { CPointer<SdlKeyboardEvent>(eventResource.value).read() }.windowID
        } else if (eventType == SDL_EVENT_TEXT_EDITING) {
            rawId = unsafe { CPointer<SdlTextEditingEvent>(eventResource.value).read() }.windowID
        } else if (eventType == SDL_EVENT_TEXT_INPUT) {
            rawId = unsafe { CPointer<SdlTextInputEvent>(eventResource.value).read() }.windowID
        } else if (eventType == SDL_EVENT_MOUSE_MOTION) {
            rawId = unsafe { CPointer<SdlMouseMotionEvent>(eventResource.value).read() }.windowID
        } else if (eventType == SDL_EVENT_MOUSE_BUTTON_DOWN || eventType == SDL_EVENT_MOUSE_BUTTON_UP) {
            rawId = unsafe { CPointer<SdlMouseButtonEvent>(eventResource.value).read() }.windowID
        } else if (eventType == SDL_EVENT_MOUSE_WHEEL) {
            rawId = unsafe { CPointer<SdlMouseWheelEvent>(eventResource.value).read() }.windowID
        } else if (isDropEvent(eventType)) {
            rawId = unsafe { CPointer<SdlDropEvent>(eventResource.value).read() }.windowID
        }
        if (rawId != UInt32(0)) { result = Some(WindowId(rawId)) }
    }
    result
}

internal func scaleEventCoordinates(event: UiEvent, scale: Float32): UiEvent {
    if (scale == 1.0) {
        return event
    }
    match (event) {
        case UiEvent.MouseMove(x, y) => UiEvent.MouseMove(x / scale, y / scale)
        case UiEvent.MouseDown(button, x, y) => UiEvent.MouseDown(button, x / scale, y / scale)
        case UiEvent.MouseUp(button, x, y) => UiEvent.MouseUp(button, x / scale, y / scale)
        case UiEvent.MouseWheel(dx, dy, x, y) => UiEvent.MouseWheel(dx, dy, x / scale, y / scale)
        case UiEvent.DropFile(path, x, y) => UiEvent.DropFile(path, x / scale, y / scale)
        case UiEvent.DropText(text, x, y) => UiEvent.DropText(text, x / scale, y / scale)
        case UiEvent.DropPosition(x, y) => UiEvent.DropPosition(x / scale, y / scale)
        // SDL window-size events use window coordinates. Convert only those into CangHui logical
        // coordinates; drawable-pixel events retain their exact backing dimensions.
        case UiEvent.WindowResized(width, height) => UiEvent.WindowResized(
            Int32(Float32(width) / scale), Int32(Float32(height) / scale))
        case _ => event
    }
}

internal func scaleEventEnvelope(envelope: SdlEventEnvelope, scale: Float32): SdlEventEnvelope {
    SdlEventEnvelope(envelope.windowId, scaleEventCoordinates(envelope.event, scale))
}

internal func isDropEvent(eventType: UInt32): Bool {
    eventType == SDL_EVENT_DROP_FILE || eventType == SDL_EVENT_DROP_TEXT || eventType == SDL_EVENT_DROP_BEGIN ||
        eventType == SDL_EVENT_DROP_COMPLETE || eventType == SDL_EVENT_DROP_POSITION
}

internal func decodeDropEvent(eventType: UInt32, drop: SdlDropEvent): UiEvent {
    if (eventType == SDL_EVENT_DROP_FILE) {
        UiEvent.DropFile(dropData(drop), drop.x, drop.y)
    } else if (eventType == SDL_EVENT_DROP_TEXT) {
        UiEvent.DropText(dropData(drop), drop.x, drop.y)
    } else if (eventType == SDL_EVENT_DROP_POSITION) {
        UiEvent.DropPosition(drop.x, drop.y)
    } else if (eventType == SDL_EVENT_DROP_BEGIN) {
        UiEvent.DropBegin
    } else {
        UiEvent.DropComplete
    }
}

private func dropData(drop: SdlDropEvent): String {
    if (drop.data.isNull()) {
        ""
    } else {
        CString(drop.data).toString()
    }
}

internal func keyFromScancode(scancode: Int32): Key {
    if (scancode >= SDL_SCANCODE_A && scancode <= SDL_SCANCODE_Z) {
        Key.Letter(UInt8(scancode - SDL_SCANCODE_A + 65))
    } else if (scancode >= SDL_SCANCODE_1 && scancode <= SDL_SCANCODE_0) {
        if (scancode == SDL_SCANCODE_0) {
            Key.Digit(UInt8(48))
        } else {
            Key.Digit(UInt8(scancode - SDL_SCANCODE_1 + 49))
        }
    } else if (scancode == SDL_SCANCODE_ESCAPE) {
        Key.Escape
    } else if (scancode == SDL_SCANCODE_BACKSPACE) {
        Key.Backspace
    } else if (scancode == SDL_SCANCODE_RETURN) {
        Key.Enter
    } else if (scancode == SDL_SCANCODE_TAB) {
        Key.Tab
    } else if (scancode == SDL_SCANCODE_DELETE) {
        Key.Delete
    } else if (scancode == SDL_SCANCODE_SPACE) {
        Key.Space
    } else if (scancode == SDL_SCANCODE_HOME) {
        Key.Home
    } else if (scancode == SDL_SCANCODE_END) {
        Key.End
    } else if (scancode == SDL_SCANCODE_RIGHT) {
        Key.Right
    } else if (scancode == SDL_SCANCODE_LEFT) {
        Key.Left
    } else if (scancode == SDL_SCANCODE_DOWN) {
        Key.Down
    } else if (scancode == SDL_SCANCODE_UP) {
        Key.Up
    } else {
        Key.RawScancode(scancode)
    }
}

internal func buttonFromCode(button: UInt8): MouseButton {
    if (button == SDL_BUTTON_LEFT) {
        MouseButton.Left
    } else if (button == SDL_BUTTON_MIDDLE) {
        MouseButton.Middle
    } else if (button == SDL_BUTTON_RIGHT) {
        MouseButton.Right
    } else {
        MouseButton.RawCode(button)
    }
}

internal func gamepadAxisFromCode(axis: UInt8): GamepadAxis {
    if (axis == SDL_GAMEPAD_AXIS_LEFTX) { GamepadAxis.LeftX }
    else if (axis == SDL_GAMEPAD_AXIS_LEFTY) { GamepadAxis.LeftY }
    else if (axis == SDL_GAMEPAD_AXIS_RIGHTX) { GamepadAxis.RightX }
    else if (axis == SDL_GAMEPAD_AXIS_RIGHTY) { GamepadAxis.RightY }
    else if (axis == SDL_GAMEPAD_AXIS_LEFT_TRIGGER) { GamepadAxis.LeftTrigger }
    else if (axis == SDL_GAMEPAD_AXIS_RIGHT_TRIGGER) { GamepadAxis.RightTrigger }
    else { GamepadAxis.RawCode(axis) }
}

internal func normalizeGamepadAxis(axis: UInt8, value: Int16): Float32 {
    if (axis == SDL_GAMEPAD_AXIS_LEFT_TRIGGER || axis == SDL_GAMEPAD_AXIS_RIGHT_TRIGGER) {
        if (value <= 0) { 0.0 } else { Float32(value) / 32767.0 }
    } else if (value < 0) {
        Float32(value) / 32768.0
    } else {
        Float32(value) / 32767.0
    }
}

internal func gamepadButtonFromCode(button: UInt8): GamepadButton {
    match (button) {
        case 0 => GamepadButton.South
        case 1 => GamepadButton.East
        case 2 => GamepadButton.West
        case 3 => GamepadButton.North
        case 4 => GamepadButton.Back
        case 5 => GamepadButton.Guide
        case 6 => GamepadButton.Start
        case 7 => GamepadButton.LeftStick
        case 8 => GamepadButton.RightStick
        case 9 => GamepadButton.LeftShoulder
        case 10 => GamepadButton.RightShoulder
        case 11 => GamepadButton.DPadUp
        case 12 => GamepadButton.DPadDown
        case 13 => GamepadButton.DPadLeft
        case 14 => GamepadButton.DPadRight
        case 15 => GamepadButton.Misc1
        case 16 => GamepadButton.RightPaddle1
        case 17 => GamepadButton.LeftPaddle1
        case 18 => GamepadButton.RightPaddle2
        case 19 => GamepadButton.LeftPaddle2
        case 20 => GamepadButton.Touchpad
        case 21 => GamepadButton.Misc2
        case 22 => GamepadButton.Misc3
        case 23 => GamepadButton.Misc4
        case 24 => GamepadButton.Misc5
        case 25 => GamepadButton.Misc6
        case _ => GamepadButton.RawCode(button)
    }
}
