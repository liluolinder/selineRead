package sdl

@Test
func keyFromScancodeMapsLettersAndControls(): Unit {
    match (keyFromScancode(SDL_SCANCODE_A)) {
        case Key.Letter(value) => @Expect(value, UInt8(65))
        case _ => @Fail("A scancode should map to Key.Letter.")
    }

    match (keyFromScancode(SDL_SCANCODE_ESCAPE)) {
        case Key.Escape => @Expect(true)
        case _ => @Fail("Escape scancode should map to Key.Escape.")
    }

    match (keyFromScancode(SDL_SCANCODE_HOME)) {
        case Key.Home => @Expect(true)
        case _ => @Fail("Home scancode should map to Key.Home.")
    }
}

@Test
func buttonFromCodeMapsKnownButtons(): Unit {
    match (buttonFromCode(SDL_BUTTON_LEFT)) {
        case MouseButton.Left => @Expect(true)
        case _ => @Fail("Left button code should map to MouseButton.Left.")
    }

    match (buttonFromCode(UInt8(9))) {
        case MouseButton.RawCode(value) => @Expect(value, UInt8(9))
        case _ => @Fail("Unknown button code should map to MouseButton.RawCode.")
    }
}

@Test
func mouseEventsScaleCoordinates(): Unit {
    let event = scaleEventCoordinates(UiEvent.MouseDown(MouseButton.Left, 30.0, 45.0), 1.5)

    match (event) {
        case UiEvent.MouseDown(MouseButton.Left, x, y) =>
            @Expect(x, Float32(20.0))
            @Expect(y, Float32(30.0))
        case _ => @Fail("Scaled event should remain a left mouse down event.")
    }
}

@Test
func windowCoordinateResizeScalesButBackingPixelResizeRemainsExact(): Unit {
    match (scaleEventCoordinates(UiEvent.WindowResized(400, 240), 2.0)) {
        case UiEvent.WindowResized(width, height) =>
            @Expect(width, Int32(200))
            @Expect(height, Int32(120))
        case _ => @Fail("Window resize should remain a logical resize event.")
    }

    match (scaleEventCoordinates(UiEvent.WindowPixelSizeChanged(800, 480), 2.0)) {
        case UiEvent.WindowPixelSizeChanged(width, height) =>
            @Expect(width, Int32(800))
            @Expect(height, Int32(480))
        case _ => @Fail("Pixel-size change should retain exact backing dimensions.")
    }
}

@Test
func dropEventsDecodeFileData(): Unit {
    let event = decodeRawDrop(SDL_EVENT_DROP_FILE, "C:/tmp/note.txt", 30.0, 45.0)

    match (event) {
        case UiEvent.DropFile(path, x, y) =>
            @Expect(path, "C:/tmp/note.txt")
            @Expect(x, Float32(30.0))
            @Expect(y, Float32(45.0))
        case _ => @Fail("Drop file event should decode with path and position.")
    }
}

@Test
func dropEventsScaleCoordinates(): Unit {
    let event = scaleEventCoordinates(UiEvent.DropText("hello", 30.0, 45.0), 1.5)

    match (event) {
        case UiEvent.DropText(value, x, y) =>
            @Expect(value, "hello")
            @Expect(x, Float32(20.0))
            @Expect(y, Float32(30.0))
        case _ => @Fail("Drop text event should scale coordinates.")
    }
}

@Test
func frameEventsKeepTimeValuesWhenScaled(): Unit {
    let event = scaleEventCoordinates(UiEvent.Frame(FrameInfo(UInt64(32), UInt64(16))), 2.0)

    match (event) {
        case UiEvent.Frame(info) =>
            @Expect(info.elapsedMs, UInt64(32))
            @Expect(info.deltaMs, UInt64(16))
        case _ => @Fail("Frame event should not be converted by coordinate scaling.")
    }
}

@Test
func gamepadAxisEventsDecodeAndNormalizeWithoutCoordinateScaling(): Unit {
    let stick = decodeRawGamepadAxis(UInt32(17), SDL_GAMEPAD_AXIS_LEFTX, Int16(-32768))
    match (scaleEventCoordinates(stick, 2.0)) {
        case UiEvent.GamepadAxisMotion(id, GamepadAxis.LeftX, value) =>
            @Expect(id, UInt32(17))
            @Expect(value, Float32(-1.0))
        case _ => @Fail("Left stick event should keep its normalized value when UI coordinates scale.")
    }

    let trigger = decodeRawGamepadAxis(UInt32(18), SDL_GAMEPAD_AXIS_RIGHT_TRIGGER, Int16(32767))
    match (trigger) {
        case UiEvent.GamepadAxisMotion(id, GamepadAxis.RightTrigger, value) =>
            @Expect(id, UInt32(18))
            @Expect(value, Float32(1.0))
        case _ => @Fail("Right trigger event should normalize into the unsigned trigger range.")
    }
    @Expect(normalizeGamepadAxis(SDL_GAMEPAD_AXIS_LEFT_TRIGGER, Int16(-1)), Float32(0.0))
}

@Test
func gamepadButtonsUsePhysicalLocationNames(): Unit {
    let down = decodeRawGamepadButton(SDL_EVENT_GAMEPAD_BUTTON_DOWN, UInt32(9), UInt8(0))
    match (down) {
        case UiEvent.GamepadButtonDown(id, button) =>
            @Expect(id, UInt32(9))
            @Expect(gamepadButtonName(button), "south")
        case _ => @Fail("Button zero should decode as the physical south button.")
    }

    let up = decodeRawGamepadButton(SDL_EVENT_GAMEPAD_BUTTON_UP, UInt32(9), UInt8(25))
    match (up) {
        case UiEvent.GamepadButtonUp(_, button) => @Expect(gamepadButtonName(button), "misc-6")
        case _ => @Fail("Button-up should retain its physical-location mapping.")
    }
}

@Test
func gamepadDeviceEventsExposeConnectionLifecycle(): Unit {
    let event = decodeRawGamepadDevice(SDL_EVENT_GAMEPAD_ADDED, UInt32(42))
    match (event) {
        case UiEvent.GamepadConnectionChanged(device, state) =>
            @Expect(device.id, UInt32(42))
            @Expect(device.name, "")
            @Expect(gamepadConnectionStateName(state), "connected")
        case _ => @Fail("Gamepad addition should decode as a connection lifecycle event.")
    }
}

@Test
func textEditingEventsExposePortableCompositionWithoutDurableInput(): Unit {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    let cText = unsafe { LibC.mallocCString("拼音") }
    var decoded = UiEvent.Unknown(UInt32(0))
    try (eventResource = eventPtr.asResource()) {
        try (textResource = cText.asResource()) {
            var raw = SdlTextEditingEvent()
            raw.eventType = SDL_EVENT_TEXT_EDITING
            raw.windowID = UInt32(27)
            raw.text = textResource.value.getChars()
            raw.start = Int32(1)
            raw.length = Int32(1)
            unsafe { CPointer<SdlTextEditingEvent>(eventResource.value).write(raw) }
            let envelope = decodeEventEnvelope(unsafe { eventResource.value.read() })
            @Expect(envelope.windowId.getOrThrow(), WindowId(UInt32(27)))
            decoded = envelope.event
        }
    }
    match (decoded) {
        case UiEvent.TextComposition(value) =>
            match (value.phase) {
                case TextCompositionPhase.Update => @Expect(true)
                case _ => @Fail("Non-empty SDL editing text should be a composition update.")
            }
            @Expect(value.text, "拼音")
            @Expect(value.selectionStart, Int64(1))
            @Expect(value.selectionLength, Int64(1))
            @Expect(value.replacementStartByte, Int64(-1))
        case _ => @Fail("SDL text editing should remain distinct from durable TextInput.")
    }
}

private func decodeRawDrop(eventType: UInt32, data: String, x: Float32, y: Float32): UiEvent {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    let cData = unsafe { LibC.mallocCString(data) }
    var decoded = UiEvent.Unknown(UInt32(0))
    try (eventResource = eventPtr.asResource()) {
        try (dataResource = cData.asResource()) {
            var drop = SdlDropEvent()
            drop.eventType = eventType
            drop.x = x
            drop.y = y
            drop.data = dataResource.value.getChars()
            unsafe { CPointer<SdlDropEvent>(eventResource.value).write(drop) }
            decoded = decodeEvent(unsafe { eventResource.value.read() })
        }
    }
    decoded
}

private func decodeRawGamepadAxis(id: UInt32, axis: UInt8, value: Int16): UiEvent {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    var decoded = UiEvent.Unknown(UInt32(0))
    try (eventResource = eventPtr.asResource()) {
        var raw = SdlGamepadAxisEvent()
        raw.eventType = SDL_EVENT_GAMEPAD_AXIS_MOTION
        raw.which = id
        raw.axis = axis
        raw.value = value
        unsafe { CPointer<SdlGamepadAxisEvent>(eventResource.value).write(raw) }
        decoded = decodeEvent(unsafe { eventResource.value.read() })
    }
    decoded
}

private func decodeRawGamepadButton(eventType: UInt32, id: UInt32, button: UInt8): UiEvent {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    var decoded = UiEvent.Unknown(UInt32(0))
    try (eventResource = eventPtr.asResource()) {
        var raw = SdlGamepadButtonEvent()
        raw.eventType = eventType
        raw.which = id
        raw.button = button
        raw.down = eventType == SDL_EVENT_GAMEPAD_BUTTON_DOWN
        unsafe { CPointer<SdlGamepadButtonEvent>(eventResource.value).write(raw) }
        decoded = decodeEvent(unsafe { eventResource.value.read() })
    }
    decoded
}

private func decodeRawGamepadDevice(eventType: UInt32, id: UInt32): UiEvent {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    var decoded = UiEvent.Unknown(UInt32(0))
    try (eventResource = eventPtr.asResource()) {
        var raw = SdlGamepadDeviceEvent()
        raw.eventType = eventType
        raw.which = id
        unsafe { CPointer<SdlGamepadDeviceEvent>(eventResource.value).write(raw) }
        decoded = decodeEvent(unsafe { eventResource.value.read() })
    }
    decoded
}
