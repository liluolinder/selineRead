package sdl

@Test
func eventEnvelopePreservesWindowIdentityAndCloseIntent(): Unit {
    let resized = decodeWindowEnvelope(SDL_EVENT_WINDOW_RESIZED, UInt32(42), 800, 600)
    @Expect(resized.windowId.getOrThrow(), WindowId(UInt32(42)))
    match (resized.event) {
        case UiEvent.WindowResized(width, height) =>
            @Expect(width, Int32(800))
            @Expect(height, Int32(600))
        case _ => @Fail("window resize should retain its payload")
    }

    let close = decodeWindowEnvelope(SDL_EVENT_WINDOW_CLOSE_REQUESTED, UInt32(42), 0, 0)
    match (close.event) {
        case UiEvent.WindowCloseRequested => @Expect(true)
        case _ => @Fail("window close request must not become process quit")
    }
}

@Test
func eventEnvelopeKeepsGamepadsProcessGlobal(): Unit {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    var envelope = SdlEventEnvelope(None<WindowId>, UiEvent.Unknown(UInt32(0)))
    try (eventResource = eventPtr.asResource()) {
        var raw = SdlGamepadAxisEvent()
        raw.eventType = SDL_EVENT_GAMEPAD_AXIS_MOTION
        raw.which = UInt32(9)
        raw.axis = SDL_GAMEPAD_AXIS_LEFTX
        raw.value = Int16(12)
        unsafe { CPointer<SdlGamepadAxisEvent>(eventResource.value).write(raw) }
        envelope = decodeEventEnvelope(unsafe { eventResource.value.read() })
    }
    @Expect(envelope.windowId.isNone())
    match (envelope.event) {
        case UiEvent.GamepadAxisMotion(id, _, _) => @Expect(id, UInt32(9))
        case _ => @Fail("gamepad event should remain process-global")
    }
}

private func decodeWindowEnvelope(
    eventType: UInt32,
    windowId: UInt32,
    data1: Int32,
    data2: Int32
): SdlEventEnvelope {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    var envelope = SdlEventEnvelope(None<WindowId>, UiEvent.Unknown(UInt32(0)))
    try (eventResource = eventPtr.asResource()) {
        var raw = SdlWindowEvent()
        raw.eventType = eventType
        raw.windowID = windowId
        raw.data1 = data1
        raw.data2 = data2
        unsafe { CPointer<SdlWindowEvent>(eventResource.value).write(raw) }
        envelope = decodeEventEnvelope(unsafe { eventResource.value.read() })
    }
    envelope
}
