package sdl

private class NativeCloseCounter {
    public var value = 0
    public func increment(): Unit { value += 1 }
}

@Test
func nativeThreadIdentityMustMatchExactly(): Unit {
    @Expect(sameNativeThread(UInt64(42), UInt64(42)))
    @Expect(!sameNativeThread(UInt64(42), UInt64(43)))
}

@Test
func wrongThreadWindowCloseNeverEntersNativeTeardown(): Unit {
    let gate = WindowCloseGate(UInt64(42))
    let nativeCloseCount = NativeCloseCounter()

    let result = gate.close(UInt64(43), { => nativeCloseCount.increment() })

    @Expect(isWrongThreadClose(result))
    @Expect(nativeCloseCount.value, 0)
    @Expect(!gate.isClosed())
}

@Test
func ownerThreadWindowCloseIsExactlyOnceAndThenThreadAgnostic(): Unit {
    let gate = WindowCloseGate(UInt64(42))
    let nativeCloseCount = NativeCloseCounter()

    let first = gate.close(UInt64(42), { => nativeCloseCount.increment() })
    let repeatedOwner = gate.close(UInt64(42), { => nativeCloseCount.increment() })
    let repeatedWorker = gate.close(UInt64(99), { => nativeCloseCount.increment() })

    @Expect(isCompletedClose(first))
    @Expect(isAlreadyClosed(repeatedOwner))
    @Expect(isAlreadyClosed(repeatedWorker))
    @Expect(nativeCloseCount.value, 1)
    @Expect(gate.isClosed())
}

private func isWrongThreadClose(result: WindowCloseResult): Bool {
    match (result) {
        case WindowCloseResult.WrongThread => true
        case _ => false
    }
}

private func isCompletedClose(result: WindowCloseResult): Bool {
    match (result) {
        case WindowCloseResult.Closed => true
        case _ => false
    }
}

private func isAlreadyClosed(result: WindowCloseResult): Bool {
    match (result) {
        case WindowCloseResult.AlreadyClosed => true
        case _ => false
    }
}

@Test
func windowSpecNormalizesInvalidScale(): Unit {
    let spec = WindowSpec("Scale", 100, 100, scale: -2.0)

    @Expect(spec.scale, Float32(1.0))
    @Expect(scaledDimension(10, 1.5), Int32(15))
}

@Test
func windowSpecMapsClientDecorationToBorderlessCreationFlag(): Unit {
    let native = windowCreationFlags(WindowSpec("Native", 100, 100))
    let client = windowCreationFlags(WindowSpec("Client", 100, 100, decorated: false))
    let legacy = WindowSpec("Legacy", 100, 100, resizable: true, highDpi: true,
        scale: 1.25, vsync: false, supersample: 3)

    @Expect((native & SDL_WINDOW_BORDERLESS) == UInt64(0))
    @Expect((client & SDL_WINDOW_BORDERLESS) != UInt64(0))
    @Expect((client & SDL_WINDOW_RESIZABLE) != UInt64(0))
    @Expect((client & SDL_WINDOW_HIGH_PIXEL_DENSITY) != UInt64(0))
    @Expect(legacy.scale, Float32(1.25))
    @Expect(!legacy.vsync)
    @Expect(legacy.supersample, Int32(3))
    @Expect(legacy.decorated)
}

@Test
func windowFlagsFromRawMapsKnownBits(): Unit {
    let raw = SDL_WINDOW_FULLSCREEN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_MOUSE_RELATIVE_MODE | SDL_WINDOW_NOT_FOCUSABLE

    let flags = windowFlagsFromRaw(raw)

    @Expect(flags.raw, raw)
    @Expect(flags.fullscreen)
    @Expect(flags.resizable)
    @Expect(flags.relativeMouseMode)
    @Expect(flags.notFocusable)
    @Expect(!flags.hidden)
    @Expect(!flags.vulkan)
}

@Test
func windowSizeFromPixelsUsesNormalizedScale(): Unit {
    let scaled = windowSizeFromPixels(300, 180, 2.0)
    let fallback = windowSizeFromPixels(300, 180, 0.0)

    @Expect(scaled.w, 150.0)
    @Expect(scaled.h, 90.0)
    @Expect(fallback.w, 300.0)
    @Expect(fallback.h, 180.0)
}

@Test
func windowResizeUpdatesDistinguishLogicalGeometryFromBackingPixels(): Unit {
    let logical = logicalWindowResizeUpdate(200, 120, 2.0)
    @Expect(logical.logicalWidth, Int32(200))
    @Expect(logical.logicalHeight, Int32(120))
    @Expect(logical.pixelWidth, Int32(400))
    @Expect(logical.pixelHeight, Int32(240))

    let backing = backingPixelResizeUpdate(
        logical.logicalWidth, logical.logicalHeight, 800, 480)
    @Expect(backing.logicalWidth, Int32(200))
    @Expect(backing.logicalHeight, Int32(120))
    @Expect(backing.pixelWidth, Int32(800))
    @Expect(backing.pixelHeight, Int32(480))
}

@Test
func windowProgressStateFromCodeMapsSdlValues(): Unit {
    @Expect(isNoProgress(windowProgressStateFromCode(SDL_PROGRESS_STATE_NONE)))
    @Expect(isIndeterminate(windowProgressStateFromCode(SDL_PROGRESS_STATE_INDETERMINATE)))
    @Expect(isNormalProgress(windowProgressStateFromCode(SDL_PROGRESS_STATE_NORMAL)))
    @Expect(isPausedProgress(windowProgressStateFromCode(SDL_PROGRESS_STATE_PAUSED)))
    @Expect(isErrorProgress(windowProgressStateFromCode(SDL_PROGRESS_STATE_ERROR)))
    @Expect(isUnknownProgress(windowProgressStateFromCode(SDL_PROGRESS_STATE_INVALID)))
    @Expect(isUnknownProgress(windowProgressStateFromCode(99)))
}

@Test
func windowProgressStateCodeMapsPublicEnum(): Unit {
    @Expect(windowProgressStateCode(WindowProgressState.Inactive), SDL_PROGRESS_STATE_NONE)
    @Expect(windowProgressStateCode(WindowProgressState.Indeterminate), SDL_PROGRESS_STATE_INDETERMINATE)
    @Expect(windowProgressStateCode(WindowProgressState.Normal), SDL_PROGRESS_STATE_NORMAL)
    @Expect(windowProgressStateCode(WindowProgressState.Paused), SDL_PROGRESS_STATE_PAUSED)
    @Expect(windowProgressStateCode(WindowProgressState.Error), SDL_PROGRESS_STATE_ERROR)
}

private func isNoProgress(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(value) => match (value) {
            case WindowProgressState.Inactive => true
            case _ => false
        }
        case None => false
    }
}

private func isIndeterminate(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(value) => match (value) {
            case WindowProgressState.Indeterminate => true
            case _ => false
        }
        case None => false
    }
}

private func isNormalProgress(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(value) => match (value) {
            case WindowProgressState.Normal => true
            case _ => false
        }
        case None => false
    }
}

private func isPausedProgress(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(value) => match (value) {
            case WindowProgressState.Paused => true
            case _ => false
        }
        case None => false
    }
}

private func isErrorProgress(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(value) => match (value) {
            case WindowProgressState.Error => true
            case _ => false
        }
        case None => false
    }
}

private func isUnknownProgress(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(_) => false
        case None => true
    }
}

@Test
func windowSpecFramelessAliasAddsBorderlessFlag(): Unit {
    let framed = windowCreationFlags(WindowSpec("Framed", 100, 100, frameless: false))
    let frameless = windowCreationFlags(WindowSpec("Frameless", 100, 100, frameless: true))
    let explicitDecorated = WindowSpec("Both", 100, 100, decorated: true, frameless: true)

    @Expect((framed & SDL_WINDOW_BORDERLESS) == UInt64(0))
    @Expect((frameless & SDL_WINDOW_BORDERLESS) != UInt64(0))
    @Expect((windowCreationFlags(explicitDecorated) & SDL_WINDOW_BORDERLESS) != UInt64(0))
    @Expect(explicitDecorated.frameless)
    @Expect(explicitDecorated.decorated)
}

@Test
func windowSpecRoundedShapeAddsTransparencyAndNormalizesRadius(): Unit {
    let shaped = WindowSpec("Shaped", 100, 80, frameless: true, cornerRadius: 18.0)
    let invalid = WindowSpec("Invalid", 100, 80, cornerRadius: -2.0)

    @Expect(shaped.cornerRadius, Float32(18.0))
    @Expect((windowCreationFlags(shaped) & SDL_WINDOW_TRANSPARENT) != UInt64(0))
    @Expect(invalid.cornerRadius, Float32(0.0))
    @Expect((windowCreationFlags(invalid) & SDL_WINDOW_TRANSPARENT) == UInt64(0))
}

@Test
func roundedWindowShapeKeepsCenterAndCutsOuterCorner(): Unit {
    @Expect(roundedCornerAlpha(0, 0, 12.0), UInt8(0))
    @Expect(roundedCornerAlpha(11, 11, 12.0), UInt8(255))
    @Expect(fittedCornerRadius(20, 10, 30.0), Float32(5.0))
}
