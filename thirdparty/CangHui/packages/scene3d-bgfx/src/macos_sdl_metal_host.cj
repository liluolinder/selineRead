package canghui_scene3d_bgfx

import chui.scene3d.{Scene3DBackend, Scene3DHostSurface}
import sdl.sdlVersion

private let SDL_INIT_VIDEO: UInt32 = UInt32(0x00000020)
private let SDL_WINDOW_RESIZABLE: UInt64 = UInt64(0x0000000000000020)
private let SDL_WINDOW_HIGH_PIXEL_DENSITY: UInt64 = UInt64(0x0000000000002000)
private let SDL_WINDOW_METAL: UInt64 = UInt64(0x0000000020000000)
private let SDL_EVENT_QUIT: UInt32 = UInt32(0x100)
private let SDL_PROP_WINDOW_COCOA_WINDOW_POINTER = "SDL.window.cocoa.window"

@C
struct MacOSSdlMetalEvent {
    var eventType: UInt32 = 0
    var padding = VArray<UInt8, $124>(repeat: 0)
}

foreign {
    func SDL_Init(flags: UInt32): Bool
    func SDL_Quit(): Unit
    func SDL_GetError(): CString
    func SDL_CreateWindow(title: CString, width: Int32, height: Int32, flags: UInt64): CPointer<Unit>
    func SDL_DestroyWindow(window: CPointer<Unit>): Unit
    func SDL_GetWindowProperties(window: CPointer<Unit>): UInt32
    func SDL_GetPointerProperty(properties: UInt32, name: CString, defaultValue: CPointer<Unit>): CPointer<Unit>
    func SDL_GetWindowSize(window: CPointer<Unit>, width: CPointer<Int32>, height: CPointer<Int32>): Bool
    func SDL_GetWindowSizeInPixels(window: CPointer<Unit>, width: CPointer<Int32>, height: CPointer<Int32>): Bool
    func SDL_ShowWindow(window: CPointer<Unit>): Bool
    func SDL_RaiseWindow(window: CPointer<Unit>): Bool
    func SDL_PollEvent(event: CPointer<MacOSSdlMetalEvent>): Bool
    func SDL_Delay(milliseconds: UInt32): Unit
}

/** Bounded macOS SDL3 host for an owned Metal window. */
public class MacOSSdlMetalHost <: Resource {
    private var window = CPointer<Unit>()
    private var nativeWindow = CPointer<Unit>()
    private var closed = false
    private var closeRequested = false
    public let identity: UInt64

    public init(title: String, width: Int32, height: Int32, identity!: UInt64 = UInt64(1)) {
        if (title.isEmpty() || width <= 0 || height <= 0 || identity == UInt64(0)) {
            throw IllegalArgumentException("macOS Metal host requires title, positive size, and identity")
        }
        this.identity = identity
        let _ = sdlVersion()
        if (!unsafe { SDL_Init(SDL_INIT_VIDEO) }) {
            throw IllegalStateException("SDL_Init failed: ${sdlError()}")
        }
        let cTitle = unsafe { LibC.mallocCString(title) }
        try (titleResource = cTitle.asResource()) {
            window = unsafe {
                SDL_CreateWindow(
                    titleResource.value,
                    width,
                    height,
                    SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY | SDL_WINDOW_METAL
                )
            }
        }
        if (window.isNull()) {
            unsafe { SDL_Quit() }
            throw IllegalStateException("SDL_CreateWindow failed: ${sdlError()}")
        }
        let propertyName = unsafe { LibC.mallocCString(SDL_PROP_WINDOW_COCOA_WINDOW_POINTER) }
        try (propertyResource = propertyName.asResource()) {
            let properties = unsafe { SDL_GetWindowProperties(window) }
            nativeWindow = unsafe {
                SDL_GetPointerProperty(properties, propertyResource.value, CPointer<Unit>())
            }
        }
        if (nativeWindow.isNull()) {
            close()
            throw IllegalStateException("SDL Cocoa NSWindow property is missing")
        }
        let _ = unsafe { SDL_ShowWindow(window) }
        let _ = unsafe { SDL_RaiseWindow(window) }
    }

    public func nativeWindowPointer(): CPointer<Unit> { nativeWindow }

    public func surface(id: String, generation!: Int64 = 1): Scene3DHostSurface {
        var logicalWidth: Int32 = 0
        var logicalHeight: Int32 = 0
        var pixelWidth: Int32 = 0
        var pixelHeight: Int32 = 0
        if (!unsafe { SDL_GetWindowSize(window, inout logicalWidth, inout logicalHeight) } ||
            !unsafe { SDL_GetWindowSizeInPixels(window, inout pixelWidth, inout pixelHeight) }) {
            throw IllegalStateException("SDL window size query failed: ${sdlError()}")
        }
        let scale = Float32(pixelWidth) / Float32(logicalWidth)
        Scene3DHostSurface(
            id,
            Scene3DBackend.Metal,
            identity,
            Float32(logicalWidth),
            Float32(logicalHeight),
            Int64(pixelWidth),
            Int64(pixelHeight),
            scale,
            generation
        )
    }

    /** Drain host events and retain a close request for the product loop. */
    public func pump(): Unit {
        var event = MacOSSdlMetalEvent()
        while (unsafe { SDL_PollEvent(inout event) }) {
            if (macOSSdlMetalHostEventRequestsClose(event.eventType)) {
                closeRequested = true
            }
            event = MacOSSdlMetalEvent()
        }
    }
    public func delay(milliseconds: UInt32): Unit { unsafe { SDL_Delay(milliseconds) } }
    public func isClosed(): Bool { closed }
    public func shouldClose(): Bool { closeRequested }

    public func close(): Unit {
        if (closed) { return }
        closed = true
        closeRequested = true
        if (!window.isNull()) { unsafe { SDL_DestroyWindow(window) } }
        unsafe { SDL_Quit() }
        window = CPointer<Unit>()
        nativeWindow = CPointer<Unit>()
    }
}

internal func macOSSdlMetalHostEventRequestsClose(eventType: UInt32): Bool {
    eventType == SDL_EVENT_QUIT
}

private func sdlError(): String {
    let error = unsafe { SDL_GetError() }
    if (error.isNull()) { "unknown SDL error" } else { error.toString() }
}
