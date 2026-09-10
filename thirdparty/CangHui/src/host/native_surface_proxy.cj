package chui.host

/** Graphics backend exposed by a host-owned native surface. */
public enum NativeSurfaceBackend <: Equatable<NativeSurfaceBackend> {
    | Metal
    | Vulkan
    | OpenGLES
    | Software

    public operator func ==(other: NativeSurfaceBackend): Bool {
        nativeSurfaceBackendName(this) == nativeSurfaceBackendName(other)
    }

    public operator func !=(other: NativeSurfaceBackend): Bool {
        !(this == other)
    }
}

public func nativeSurfaceBackendName(backend: NativeSurfaceBackend): String {
    match (backend) {
        case NativeSurfaceBackend.Metal => "metal"
        case NativeSurfaceBackend.Vulkan => "vulkan"
        case NativeSurfaceBackend.OpenGLES => "opengles"
        case NativeSurfaceBackend.Software => "software"
    }
}

/** Whether the framework owns an SDL window or is embedded in a native view. */
public enum HostPresentationMode <: Equatable<HostPresentationMode> {
    | OwnedWindow
    | EmbeddedSurface

    public operator func ==(other: HostPresentationMode): Bool {
        hostPresentationModeName(this) == hostPresentationModeName(other)
    }

    public operator func !=(other: HostPresentationMode): Bool {
        !(this == other)
    }
}

public func hostPresentationModeName(mode: HostPresentationMode): String {
    match (mode) {
        case HostPresentationMode.OwnedWindow => "owned-window"
        case HostPresentationMode.EmbeddedSurface => "embedded-surface"
    }
}

/** Result returned by an SDL-style callback-driven application loop. */
public enum HostLoopResult {
    | Continue
    | Success
    | Failure(String)
}

public func hostLoopResultName(result: HostLoopResult): String {
    match (result) {
        case HostLoopResult.Continue => "continue"
        case HostLoopResult.Success => "success"
        case HostLoopResult.Failure(_) => "failure"
    }
}

/**
 * Host-owned surface identity. `opaqueHandle` is interpreted only by the
 * matching platform backend; `generation` prevents reuse after recreation.
 */
public struct NativeSurfaceDescriptor {
    public let id: String
    public let backend: NativeSurfaceBackend
    public let opaqueHandle: UInt64
    public let logicalWidth: Float32
    public let logicalHeight: Float32
    public let pixelWidth: Int64
    public let pixelHeight: Int64
    public let scale: Float32
    public let generation: Int64

    public init(
        id: String,
        backend: NativeSurfaceBackend,
        opaqueHandle: UInt64,
        logicalWidth: Float32,
        logicalHeight: Float32,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scale: Float32,
        generation: Int64
    ) {
        if (id.isEmpty() || opaqueHandle == UInt64(0)) {
            throw IllegalArgumentException("native surface identity and handle must be present")
        }
        if (logicalWidth <= 0.0 || logicalHeight <= 0.0 ||
            pixelWidth <= 0 || pixelHeight <= 0 || scale <= 0.0) {
            throw IllegalArgumentException("native surface dimensions and scale must be positive")
        }
        if (generation < 0) {
            throw IllegalArgumentException("native surface generation must not be negative")
        }
        this.id = id
        this.backend = backend
        this.opaqueHandle = opaqueHandle
        this.logicalWidth = logicalWidth
        this.logicalHeight = logicalHeight
        this.pixelWidth = pixelWidth
        this.pixelHeight = pixelHeight
        this.scale = scale
        this.generation = generation
    }
}

/** Frame-clock event supplied by the platform display scheduler. */
public struct NativeSurfaceFrame {
    public let frameId: Int64
    public let timestampNanos: Int64
    public let targetTimestampNanos: Int64

    public init(frameId: Int64, timestampNanos: Int64, targetTimestampNanos: Int64) {
        if (frameId < 0 || timestampNanos < 0 || targetTimestampNanos < timestampNanos) {
            throw IllegalArgumentException("native surface frame timing is invalid")
        }
        this.frameId = frameId
        this.timestampNanos = timestampNanos
        this.targetTimestampNanos = targetTimestampNanos
    }
}

/** XComponent-like surface lifecycle delivered by the platform proxy. */
public enum NativeSurfaceEvent {
    | Available(NativeSurfaceDescriptor)
    | Changed(NativeSurfaceDescriptor)
    | Frame(NativeSurfaceFrame)
    | Unavailable(String, Int64)
}

/** Cangjie-owned renderer attached to a host-owned native surface. */
public interface NativeSurfaceRenderer {
    func attach(surface: NativeSurfaceDescriptor): Unit
    func resize(surface: NativeSurfaceDescriptor): Unit
    func draw(frame: NativeSurfaceFrame): Unit
    func detach(surfaceId: String, generation: Int64): Unit
}

/**
 * Platform adapter implemented by UIKit, Harmony XComponent or another host.
 * Callbacks must be marshalled onto the fixed Cangjie UI scheduler thread.
 */
public interface HostNativeSurfaceService {
    func presentationMode(): HostPresentationMode
    func current(): ?NativeSurfaceDescriptor
    func observe(handler: (NativeSurfaceEvent) -> Unit): Unit
    func bind(renderer: NativeSurfaceRenderer): Unit
    func requestFrame(): Unit
}

/**
 * Callback application loop shared by SDL-owned windows and embedded hosts.
 * Input and lifecycle continue to arrive through the focused host services.
 */
public interface HostApplicationLoop {
    func onInitialize(): HostLoopResult
    func onIterate(frame: NativeSurfaceFrame): HostLoopResult
    func onShutdown(result: HostLoopResult): Unit
}
