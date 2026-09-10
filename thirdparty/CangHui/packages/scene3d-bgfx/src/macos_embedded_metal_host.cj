package canghui_scene3d_bgfx

import chui.host.{HostPresentationMode, NativeSurfaceBackend, NativeSurfaceDescriptor, NativeSurfaceEvent,
    NativeSurfaceFrame, NativeSurfaceRenderer}
import chui.scene3d.{Scene3DViewHost, Scene3DViewHostReceipt, Scene3DViewPlacement}

private let SDL_PROP_WINDOW_COCOA_WINDOW_POINTER_EMBEDDED = "SDL.window.cocoa.window"
private let EMBEDDED_FRAME_NANOS: UInt64 = UInt64(16666667)

foreign {
    func SDL_GetTicksNS(): UInt64

    func chui_macos_embedded_metal_create(parentWindow: CPointer<Unit>, x: Float64, y: Float64,
        width: Float64, height: Float64, scale: Float64): CPointer<Unit>
    func chui_macos_embedded_metal_layer(view: CPointer<Unit>): CPointer<Unit>
    func chui_macos_embedded_metal_place(view: CPointer<Unit>, x: Float64, y: Float64,
        width: Float64, height: Float64, scale: Float64): Bool
    func chui_macos_embedded_metal_destroy(view: CPointer<Unit>): Unit
    func chui_macos_embedded_metal_is_attached(view: CPointer<Unit>): Bool
}

/** macOS provider slice: one CAMetalLayer-backed child NSView inside CangHui's SDL window. */
public class MacOSEmbeddedMetalHost <: Scene3DViewHost & Resource {
    private let viewId: String
    private let identity: UInt64
    private var childView = CPointer<Unit>()
    private var metalLayer = CPointer<Unit>()
    private var renderer: ?NativeSurfaceRenderer = None
    private var observer: (NativeSurfaceEvent) -> Unit = { _ => () }
    private var currentSurface: ?NativeSurfaceDescriptor = None
    private var generation: Int64 = 1
    private var frameId: Int64 = 0
    private var closed = false

    public init(sdlWindow: CPointer<Unit>, initial: Scene3DViewPlacement,
        identity!: UInt64 = UInt64(1)) {
        if (sdlWindow.isNull() || identity == UInt64(0)) {
            throw IllegalArgumentException("embedded Metal host needs a borrowed SDL window and identity")
        }
        this.viewId = initial.viewId
        this.identity = identity
        let nativeWindow = cocoaWindow(sdlWindow)
        if (nativeWindow.isNull()) {
            throw IllegalStateException("SDL Cocoa NSWindow property is missing")
        }
        childView = unsafe {
            chui_macos_embedded_metal_create(nativeWindow, Float64(initial.x), Float64(initial.y),
                Float64(initial.width), Float64(initial.height), Float64(initial.scale))
        }
        if (childView.isNull()) {
            throw IllegalStateException("macOS child NSView creation failed")
        }
        metalLayer = unsafe { chui_macos_embedded_metal_layer(childView) }
        if (metalLayer.isNull()) {
            close()
            throw IllegalStateException("macOS child CAMetalLayer is missing")
        }
        currentSurface = Some(descriptor(initial))
    }

    /** CAMetalLayer pointer consumed only by the matching bgfx Metal driver. */
    public func nativeLayerPointer(): CPointer<Unit> { metalLayer }
    public func surfaceIdentity(): UInt64 { identity }
    public func isClosed(): Bool { closed }
    public func isChildAttached(): Bool {
        childView.isNotNull() && unsafe { chui_macos_embedded_metal_is_attached(childView) }
    }
    public func presentationMode(): HostPresentationMode { HostPresentationMode.EmbeddedSurface }
    public func current(): ?NativeSurfaceDescriptor { currentSurface }
    public func observe(handler: (NativeSurfaceEvent) -> Unit): Unit { observer = handler }

    public func bind(value: NativeSurfaceRenderer): Unit {
        renderer = Some(value)
        match (currentSurface) {
            case Some(surface) => value.attach(surface)
            case None => ()
        }
    }

    public func place(value: Scene3DViewPlacement): Scene3DViewHostReceipt {
        if (closed || value.viewId != viewId) {
            return Scene3DViewHostReceipt(false, "place", "host-unavailable", value.viewId,
                "embedded Metal host is closed or has a different view identity")
        }
        let ok = unsafe {
            chui_macos_embedded_metal_place(childView, Float64(value.x), Float64(value.y),
                Float64(value.width), Float64(value.height), Float64(value.scale))
        }
        if (!ok) {
            return Scene3DViewHostReceipt(false, "place", "native-place-failed", value.viewId,
                "macOS child NSView rejected placement")
        }
        let surface = descriptor(value)
        currentSurface = Some(surface)
        match (renderer) {
            case Some(bound) => bound.resize(surface)
            case None => ()
        }
        observer(NativeSurfaceEvent.Changed(surface))
        Scene3DViewHostReceipt(true, "place", "accepted", value.viewId,
            "CAMetalLayer child view placed inside the SDL parent")
    }

    public func remove(value: String): Scene3DViewHostReceipt {
        if (value != viewId) {
            return Scene3DViewHostReceipt(false, "remove", "unknown-view", value,
                "embedded Metal host has a different view identity")
        }
        close()
        Scene3DViewHostReceipt(true, "remove", "accepted", value, "embedded Metal child view removed")
    }

    /** Uses the UI-owner call as the display-clock handoff in this bounded macOS adapter. */
    public func requestFrame(): Unit {
        if (closed) { return }
        let now = unsafe { SDL_GetTicksNS() }
        let frame = NativeSurfaceFrame(frameId, Int64(now), Int64(now + EMBEDDED_FRAME_NANOS))
        frameId += 1
        match (renderer) {
            case Some(bound) => bound.draw(frame)
            case None => ()
        }
        observer(NativeSurfaceEvent.Frame(frame))
    }

    public func close(): Unit {
        if (closed) { return }
        closed = true
        match (currentSurface) {
            case Some(surface) =>
                match (renderer) {
                    case Some(bound) => bound.detach(surface.id, surface.generation)
                    case None => ()
                }
                observer(NativeSurfaceEvent.Unavailable(surface.id, surface.generation))
            case None => ()
        }
        if (childView.isNotNull()) { unsafe { chui_macos_embedded_metal_destroy(childView) } }
        childView = CPointer<Unit>()
        metalLayer = CPointer<Unit>()
        currentSurface = None
    }

    private func descriptor(value: Scene3DViewPlacement): NativeSurfaceDescriptor {
        NativeSurfaceDescriptor("${viewId}.metal", NativeSurfaceBackend.Metal, identity,
            value.width, value.height, Int64(value.width * value.scale), Int64(value.height * value.scale),
            value.scale, generation)
    }
}

private func cocoaWindow(sdlWindow: CPointer<Unit>): CPointer<Unit> {
    let propertyName = unsafe { LibC.mallocCString(SDL_PROP_WINDOW_COCOA_WINDOW_POINTER_EMBEDDED) }
    var result = CPointer<Unit>()
    try (propertyResource = propertyName.asResource()) {
        let properties = unsafe { SDL_GetWindowProperties(sdlWindow) }
        result = unsafe { SDL_GetPointerProperty(properties, propertyResource.value, CPointer<Unit>()) }
    }
    result
}
