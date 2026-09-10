package chui.scene3d

import chui.host.{HarmonyNativeSurfaceBridge, HostPresentationMode, NativeSurfaceBackend,
    NativeSurfaceDescriptor, NativeSurfaceEvent, NativeSurfaceFrame, NativeSurfaceRenderer,
    harmonyNativeSurfaceBridge}

/** CangHui-owned adapter from integer XComponent ingress to the public Scene3DViewHost SPI. */
public class HarmonyXComponentScene3DHost <: Scene3DViewHost & Resource {
    private let viewId: String
    private let bridge: HarmonyNativeSurfaceBridge
    private let backend: NativeSurfaceBackend
    private let requestDisplayFrame: () -> Unit
    private var renderer: ?NativeSurfaceRenderer = None
    private var observer: (NativeSurfaceEvent) -> Unit = { _ => () }
    private var surface: ?NativeSurfaceDescriptor = None
    private var active = false
    private var closed = false
    private var observedSurfaceRevision: Int64 = -1
    private var observedFrameId: Int64 = -1

    public init(
        viewId: String,
        bridge!: HarmonyNativeSurfaceBridge = harmonyNativeSurfaceBridge(),
        backend!: NativeSurfaceBackend = NativeSurfaceBackend.Vulkan,
        requestDisplayFrame!: () -> Unit = { => () }
    ) {
        if (viewId.isEmpty()) {
            throw IllegalArgumentException("Harmony XComponent host needs a view identity")
        }
        if (backend != NativeSurfaceBackend.Vulkan && backend != NativeSurfaceBackend.OpenGLES) {
            throw IllegalArgumentException("Harmony XComponent host supports Vulkan or OpenGLES")
        }
        this.viewId = viewId
        this.bridge = bridge
        this.backend = backend
        this.requestDisplayFrame = requestDisplayFrame
    }

    public func presentationMode(): HostPresentationMode { HostPresentationMode.EmbeddedSurface }
    public func isClosed(): Bool { closed }
    public func current(): ?NativeSurfaceDescriptor { surface }
    public func observe(handler: (NativeSurfaceEvent) -> Unit): Unit { observer = handler }

    public func bind(value: NativeSurfaceRenderer): Unit {
        renderer = Some(value)
        match (surface) {
            case Some(currentSurface) => value.attach(currentSurface)
            case None => refresh()
        }
    }

    public func place(value: Scene3DViewPlacement): Scene3DViewHostReceipt {
        if (closed || value.viewId != viewId) {
            return Scene3DViewHostReceipt(false, "place", "host-unavailable", value.viewId,
                "Harmony XComponent host is closed or has a different view identity")
        }
        active = true
        refresh()
        match (surface) {
            case Some(_) => Scene3DViewHostReceipt(true, "place", "accepted", value.viewId,
                "XComponent surface is attached; ArkTS remains the native placement owner")
            case None => Scene3DViewHostReceipt(false, "place", "surface-unavailable", value.viewId,
                "waiting for the XComponent surface-created callback")
        }
    }

    public func remove(value: String): Scene3DViewHostReceipt {
        if (value != viewId) {
            return Scene3DViewHostReceipt(false, "remove", "unknown-view", value,
                "Harmony XComponent host has a different view identity")
        }
        if (!active) {
            return Scene3DViewHostReceipt(true, "remove", "already-removed", value,
                "Harmony XComponent view was already removed")
        }
        active = false
        detachCurrent()
        observedSurfaceRevision = -1
        Scene3DViewHostReceipt(true, "remove", "accepted", value,
            "renderer detached; XComponent lifetime remains owned by ArkTS")
    }

    /** Polls committed native facts and preserves attach/resize/frame/detach ordering. */
    public func refresh(): Unit {
        if (closed || !active) { return }
        let snapshot = bridge.snapshot()
        if (snapshot.surfaceRevision != observedSurfaceRevision) {
            observedSurfaceRevision = snapshot.surfaceRevision
            if (!snapshot.attached) {
                detachCurrent()
            } else {
                let next = descriptor(snapshot.handle, snapshot.pixelWidth, snapshot.pixelHeight,
                    snapshot.scaleMilli, snapshot.generation)
                match (surface) {
                    case Some(previous) =>
                        if (previous.generation != next.generation || previous.opaqueHandle != next.opaqueHandle) {
                            detachCurrent()
                            attach(next)
                        } else if (previous.pixelWidth != next.pixelWidth ||
                            previous.pixelHeight != next.pixelHeight || previous.scale != next.scale) {
                            surface = Some(next)
                            match (renderer) {
                                case Some(bound) => bound.resize(next)
                                case None => ()
                            }
                            observer(NativeSurfaceEvent.Changed(next))
                        }
                    case None => attach(next)
                }
            }
        }
        if (snapshot.attached && snapshot.frameId > observedFrameId) {
            observedFrameId = snapshot.frameId
            let frame = NativeSurfaceFrame(snapshot.frameId, snapshot.timestampNanos,
                snapshot.targetTimestampNanos)
            match (renderer) {
                case Some(bound) => bound.draw(frame)
                case None => ()
            }
            observer(NativeSurfaceEvent.Frame(frame))
        }
    }

    /** Requests the platform display scheduler and consumes the latest committed callback. */
    public func requestFrame(): Unit {
        if (closed || !active) { return }
        refresh()
        requestDisplayFrame()
    }

    public func close(): Unit {
        if (closed) { return }
        closed = true
        active = false
        detachCurrent()
    }

    private func descriptor(
        handle: Int64,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64
    ): NativeSurfaceDescriptor {
        let scale = Float32(scaleMilli) / 1000.0
        NativeSurfaceDescriptor(
            viewId + ".xcomponent", backend, UInt64(handle),
            Float32(pixelWidth) / scale, Float32(pixelHeight) / scale,
            pixelWidth, pixelHeight, scale, generation
        )
    }

    private func attach(value: NativeSurfaceDescriptor): Unit {
        surface = Some(value)
        observedFrameId = -1
        match (renderer) {
            case Some(bound) => bound.attach(value)
            case None => ()
        }
        observer(NativeSurfaceEvent.Available(value))
    }

    private func detachCurrent(): Unit {
        match (surface) {
            case Some(value) =>
                match (renderer) {
                    case Some(bound) => bound.detach(value.id, value.generation)
                    case None => ()
                }
                observer(NativeSurfaceEvent.Unavailable(value.id, value.generation))
            case None => ()
        }
        surface = None
        observedFrameId = -1
    }
}
