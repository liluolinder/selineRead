package chui.host

import std.sync.Mutex

private let HARMONY_BRIDGE_ACCEPTED: Int64 = 0
private let HARMONY_BRIDGE_INVALID_ARGUMENT: Int64 = -1
private let HARMONY_BRIDGE_STALE_GENERATION: Int64 = -2
private let HARMONY_MAX_SURFACE_DIMENSION: Int64 = 65535
private let HARMONY_MIN_SCALE_MILLI: Int64 = 100
private let HARMONY_MAX_SCALE_MILLI: Int64 = 16000

/** Immutable integer-only snapshot shared with the Harmony XComponent host adapter. */
public struct HarmonyNativeSurfaceSnapshot {
    public let attached: Bool
    public let handle: Int64
    public let pixelWidth: Int64
    public let pixelHeight: Int64
    public let scaleMilli: Int64
    public let generation: Int64
    public let surfaceRevision: Int64
    public let frameId: Int64
    public let timestampNanos: Int64
    public let targetTimestampNanos: Int64

    public init(
        attached: Bool,
        handle: Int64,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64,
        surfaceRevision: Int64,
        frameId: Int64,
        timestampNanos: Int64,
        targetTimestampNanos: Int64
    ) {
        this.attached = attached
        this.handle = handle
        this.pixelWidth = pixelWidth
        this.pixelHeight = pixelHeight
        this.scaleMilli = scaleMilli
        this.generation = generation
        this.surfaceRevision = surfaceRevision
        this.frameId = frameId
        this.timestampNanos = timestampNanos
        this.targetTimestampNanos = targetTimestampNanos
    }
}

/**
 * Harmony XComponent ingress. Native callbacks commit only mutex-protected,
 * integer facts; the Scene3D host applies them later on CangHui's UI owner.
 */
public class HarmonyNativeSurfaceBridge {
    private let stateMutex = Mutex()
    private var attached = false
    private var handle: Int64 = 0
    private var pixelWidth: Int64 = 0
    private var pixelHeight: Int64 = 0
    private var scaleMilli: Int64 = 1000
    private var generation: Int64 = 0
    private var surfaceRevision: Int64 = 0
    private var frameId: Int64 = -1
    private var timestampNanos: Int64 = 0
    private var targetTimestampNanos: Int64 = 0
    private var attachCount: Int64 = 0
    private var resizeCount: Int64 = 0
    private var detachCount: Int64 = 0
    private var frameCount: Int64 = 0

    public func attach(
        handle: Int64,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64
    ): Int64 {
        if (handle <= 0 || !validDimensions(pixelWidth, pixelHeight, scaleMilli) || generation <= 0) {
            return HARMONY_BRIDGE_INVALID_ARGUMENT
        }
        synchronized(stateMutex) {
            if (generation <= this.generation) { return HARMONY_BRIDGE_STALE_GENERATION }
            this.attached = true
            this.handle = handle
            this.pixelWidth = pixelWidth
            this.pixelHeight = pixelHeight
            this.scaleMilli = scaleMilli
            this.generation = generation
            this.surfaceRevision += 1
            this.frameId = -1
            this.timestampNanos = 0
            this.targetTimestampNanos = 0
            this.attachCount += 1
            HARMONY_BRIDGE_ACCEPTED
        }
    }

    public func resize(
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64
    ): Int64 {
        if (!validDimensions(pixelWidth, pixelHeight, scaleMilli)) {
            return HARMONY_BRIDGE_INVALID_ARGUMENT
        }
        synchronized(stateMutex) {
            if (!matchesAttachedGeneration(generation)) { return HARMONY_BRIDGE_STALE_GENERATION }
            this.pixelWidth = pixelWidth
            this.pixelHeight = pixelHeight
            this.scaleMilli = scaleMilli
            this.surfaceRevision += 1
            this.resizeCount += 1
            HARMONY_BRIDGE_ACCEPTED
        }
    }

    public func detach(generation: Int64): Int64 {
        synchronized(stateMutex) {
            if (!matchesAttachedGeneration(generation)) { return HARMONY_BRIDGE_STALE_GENERATION }
            this.attached = false
            this.handle = 0
            this.pixelWidth = 0
            this.pixelHeight = 0
            this.surfaceRevision += 1
            this.detachCount += 1
            HARMONY_BRIDGE_ACCEPTED
        }
    }

    public func frame(
        timestampNanos: Int64,
        targetTimestampNanos: Int64,
        generation: Int64
    ): Int64 {
        if (timestampNanos < 0 || targetTimestampNanos < timestampNanos) {
            return HARMONY_BRIDGE_INVALID_ARGUMENT
        }
        synchronized(stateMutex) {
            if (!matchesAttachedGeneration(generation)) { return HARMONY_BRIDGE_STALE_GENERATION }
            if ((frameId >= 0 && timestampNanos < this.timestampNanos) || frameId == Int64.Max) {
                return HARMONY_BRIDGE_INVALID_ARGUMENT
            }
            this.frameId += 1
            this.timestampNanos = timestampNanos
            this.targetTimestampNanos = targetTimestampNanos
            this.frameCount += 1
            HARMONY_BRIDGE_ACCEPTED
        }
    }

    public func snapshot(): HarmonyNativeSurfaceSnapshot {
        synchronized(stateMutex) {
            HarmonyNativeSurfaceSnapshot(
                attached, handle, pixelWidth, pixelHeight, scaleMilli, generation,
                surfaceRevision, frameId, timestampNanos, targetTimestampNanos
            )
        }
    }

    public func totalAttachCount(): Int64 { synchronized(stateMutex) { attachCount } }
    public func totalResizeCount(): Int64 { synchronized(stateMutex) { resizeCount } }
    public func totalDetachCount(): Int64 { synchronized(stateMutex) { detachCount } }
    public func totalFrameCount(): Int64 { synchronized(stateMutex) { frameCount } }

    private func validDimensions(width: Int64, height: Int64, scaleMilli: Int64): Bool {
        width > 0 && width <= HARMONY_MAX_SURFACE_DIMENSION &&
            height > 0 && height <= HARMONY_MAX_SURFACE_DIMENSION &&
            scaleMilli >= HARMONY_MIN_SCALE_MILLI && scaleMilli <= HARMONY_MAX_SCALE_MILLI
    }

    private func matchesAttachedGeneration(generation: Int64): Bool {
        attached && generation > 0 && this.generation == generation
    }
}

private let sharedHarmonyNativeSurfaceBridge = HarmonyNativeSurfaceBridge()

/** Shared bridge consumed by the native ABI and the public Scene3D host. */
public func harmonyNativeSurfaceBridge(): HarmonyNativeSurfaceBridge {
    sharedHarmonyNativeSurfaceBridge
}

/** Integer ABI v1. Native pointers never enter serializable CangHui receipts. */
@C public func canghui_harmony_xcomponent_host_abi_version(): Int64 { 1 }

@C
public func canghui_harmony_surface_attach(
    handle: Int64,
    pixelWidth: Int64,
    pixelHeight: Int64,
    scaleMilli: Int64,
    generation: Int64
): Int64 {
    sharedHarmonyNativeSurfaceBridge.attach(handle, pixelWidth, pixelHeight, scaleMilli, generation)
}

@C
public func canghui_harmony_surface_resize(
    pixelWidth: Int64,
    pixelHeight: Int64,
    scaleMilli: Int64,
    generation: Int64
): Int64 {
    sharedHarmonyNativeSurfaceBridge.resize(pixelWidth, pixelHeight, scaleMilli, generation)
}

@C public func canghui_harmony_surface_detach(generation: Int64): Int64 {
    sharedHarmonyNativeSurfaceBridge.detach(generation)
}

@C
public func canghui_harmony_surface_frame(
    timestampNanos: Int64,
    targetTimestampNanos: Int64,
    generation: Int64
): Int64 {
    sharedHarmonyNativeSurfaceBridge.frame(timestampNanos, targetTimestampNanos, generation)
}
