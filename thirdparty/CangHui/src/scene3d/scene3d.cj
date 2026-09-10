package chui.scene3d

import std.collection.ArrayList

public let CANGHUI_SCENE3D_PROTOCOL = "canghui.scene3d.v0"
public let CANGHUI_SCENE3D_SHARED_FRAME_PROTOCOL = "canghui.scene3d.shared-frame.v1"

/** Renderer families understood by a Scene3D provider, without exposing engine handles. */
public enum Scene3DBackend <: Equatable<Scene3DBackend> {
    | Metal
    | Vulkan
    | OpenGLES
    | D3D11
    | D3D12
    | Software

    public operator func ==(other: Scene3DBackend): Bool {
        scene3dBackendName(this) == scene3dBackendName(other)
    }

    public operator func !=(other: Scene3DBackend): Bool {
        !(this == other)
    }
}

public func scene3dBackendName(backend: Scene3DBackend): String {
    match (backend) {
        case Scene3DBackend.Metal => "metal"
        case Scene3DBackend.Vulkan => "vulkan"
        case Scene3DBackend.OpenGLES => "opengles"
        case Scene3DBackend.D3D11 => "d3d11"
        case Scene3DBackend.D3D12 => "d3d12"
        case Scene3DBackend.Software => "software"
    }
}

/** Host surface identity for a 3D provider. Generation invalidates stale work. */
public struct Scene3DHostSurface {
    public let id: String
    public let backend: Scene3DBackend
    public let opaqueHandle: UInt64
    public let logicalWidth: Float32
    public let logicalHeight: Float32
    public let pixelWidth: Int64
    public let pixelHeight: Int64
    public let scale: Float32
    public let generation: Int64

    public init(
        id: String,
        backend: Scene3DBackend,
        opaqueHandle: UInt64,
        logicalWidth: Float32,
        logicalHeight: Float32,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scale: Float32,
        generation: Int64
    ) {
        if (id.isEmpty() || opaqueHandle == UInt64(0)) {
            throw IllegalArgumentException("scene3d surface identity and handle must be present")
        }
        if (logicalWidth <= 0.0 || logicalHeight <= 0.0 ||
            pixelWidth <= 0 || pixelHeight <= 0 || scale <= 0.0) {
            throw IllegalArgumentException("scene3d surface geometry must be positive")
        }
        if (generation <= 0) {
            throw IllegalArgumentException("scene3d surface generation must be positive")
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

/** One platform frame boundary. Providers must not create a competing clock. */
public struct Scene3DFrameClock {
    public let frameId: Int64
    public let timestampNanos: Int64
    public let targetTimestampNanos: Int64

    public init(frameId: Int64, timestampNanos: Int64, targetTimestampNanos: Int64) {
        if (frameId < 0 || timestampNanos < 0 || targetTimestampNanos < timestampNanos) {
            throw IllegalArgumentException("scene3d frame timing is invalid")
        }
        this.frameId = frameId
        this.timestampNanos = timestampNanos
        this.targetTimestampNanos = targetTimestampNanos
    }
}

/** Validated resource identity. Native handles remain private to a provider. */
public struct Scene3DResource {
    public let id: String
    public let uri: String
    public let checksum: String
    public let sizeBytes: Int64

    public init(id: String, uri: String, checksum: String, sizeBytes: Int64) {
        if (id.isEmpty() || uri.isEmpty() || checksum.isEmpty() || sizeBytes < 0) {
            throw IllegalArgumentException("scene3d resource identity and checksum are required")
        }
        this.id = id
        this.uri = uri
        this.checksum = checksum
        this.sizeBytes = sizeBytes
    }
}

/** Minimal immutable entity projection used by a provider for one frame. */
public struct Scene3DEntitySnapshot {
    public let id: String
    public let kind: Scene3DEntityKind
    public let x: Float32
    public let y: Float32
    public let z: Float32
    public let scaleX: Float32
    public let scaleY: Float32
    public let scaleZ: Float32
    public let rotationX: Float32
    public let rotationY: Float32
    public let rotationZ: Float32
    public let visible: Bool

    public init(
        id: String,
        x: Float32,
        y: Float32,
        z: Float32,
        visible!: Bool = true,
        kind!: Scene3DEntityKind = Scene3DEntityKind.Vehicle,
        scaleX!: Float32 = 0.0,
        scaleY!: Float32 = 0.0,
        scaleZ!: Float32 = 0.0,
        rotationX!: Float32 = 0.0,
        rotationY!: Float32 = 0.0,
        rotationZ!: Float32 = 0.0
    ) {
        if (id.isEmpty()) { throw IllegalArgumentException("scene3d entity id must be present") }
        if (scaleX < 0.0 || scaleY < 0.0 || scaleZ < 0.0) {
            throw IllegalArgumentException("scene3d entity scale overrides must not be negative")
        }
        this.id = id
        this.kind = kind
        this.x = x
        this.y = y
        this.z = z
        this.scaleX = scaleX
        this.scaleY = scaleY
        this.scaleZ = scaleZ
        this.rotationX = rotationX
        this.rotationY = rotationY
        this.rotationZ = rotationZ
        this.visible = visible
    }
}

/** Provider-neutral camera carried by one immutable scene frame. */
public struct Scene3DCameraSnapshot {
    public let eyeX: Float32
    public let eyeY: Float32
    public let eyeZ: Float32
    public let targetX: Float32
    public let targetY: Float32
    public let targetZ: Float32
    public let upX: Float32
    public let upY: Float32
    public let upZ: Float32
    public let fieldOfViewY: Float32
    public let nearPlane: Float32
    public let farPlane: Float32

    public init(
        eyeX: Float32,
        eyeY: Float32,
        eyeZ: Float32,
        targetX: Float32,
        targetY: Float32,
        targetZ: Float32,
        upX!: Float32 = 0.0,
        upY!: Float32 = 1.0,
        upZ!: Float32 = 0.0,
        fieldOfViewY!: Float32 = 52.0,
        nearPlane!: Float32 = 0.1,
        farPlane!: Float32 = 100.0
    ) {
        if (fieldOfViewY <= 1.0 || fieldOfViewY >= 179.0 || nearPlane <= 0.0 || farPlane <= nearPlane) {
            throw IllegalArgumentException("scene3d camera projection is invalid")
        }
        if (upX == 0.0 && upY == 0.0 && upZ == 0.0) {
            throw IllegalArgumentException("scene3d camera up vector must not be zero")
        }
        this.eyeX = eyeX
        this.eyeY = eyeY
        this.eyeZ = eyeZ
        this.targetX = targetX
        this.targetY = targetY
        this.targetZ = targetZ
        this.upX = upX
        this.upY = upY
        this.upZ = upZ
        this.fieldOfViewY = fieldOfViewY
        this.nearPlane = nearPlane
        this.farPlane = farPlane
    }
}

/** Product-facing scene snapshot. It becomes immutable at the submit boundary. */
public class Scene3DFrameSnapshot {
    public let sceneId: String
    public let camera: ?Scene3DCameraSnapshot
    private let entities = ArrayList<Scene3DEntitySnapshot>()
    private var sealed = false

    public init(sceneId: String, camera!: ?Scene3DCameraSnapshot = None) {
        if (sceneId.isEmpty()) { throw IllegalArgumentException("scene3d scene id must be present") }
        this.sceneId = sceneId
        this.camera = camera
    }

    public func add(entity: Scene3DEntitySnapshot): Unit {
        if (sealed) { throw IllegalStateException("scene3d snapshot is sealed") }
        entities.add(entity)
    }

    public func seal(): Unit { sealed = true }
    public func isSealed(): Bool { sealed }
    public func entityCount(): Int64 { entities.size }
    public func entityAt(index: Int64): Scene3DEntitySnapshot { entities[index] }
}

public struct Scene3DHitTestRequest {
    public let x: Float32
    public let y: Float32
    public let generation: Int64
    public let frameId: Int64

    public init(x: Float32, y: Float32, generation: Int64, frameId: Int64) {
        if (generation <= 0 || frameId < 0) {
            throw IllegalArgumentException("scene3d hit-test identity is invalid")
        }
        this.x = x
        this.y = y
        this.generation = generation
        this.frameId = frameId
    }
}

public struct Scene3DHitTestResult {
    public let hit: Bool
    public let entityId: String
    public let generation: Int64
    public let frameId: Int64

    public init(hit: Bool, entityId: String, generation: Int64, frameId: Int64) {
        if (hit && entityId.isEmpty()) {
            throw IllegalArgumentException("a scene3d hit must carry an entity id")
        }
        this.hit = hit
        this.entityId = entityId
        this.generation = generation
        this.frameId = frameId
    }

    public static func none(generation: Int64, frameId: Int64): Scene3DHitTestResult {
        Scene3DHitTestResult(false, "", generation, frameId)
    }
}

/** Structured lifecycle receipt shared by fake and native providers. */
public struct Scene3DReceipt {
    public let ok: Bool
    public let operation: String
    public let code: String
    public let generation: Int64
    public let frameId: Int64
    public let detail: String

    public init(
        ok: Bool,
        operation: String,
        code: String,
        generation: Int64,
        frameId: Int64,
        detail: String
    ) {
        this.ok = ok
        this.operation = operation
        this.code = code
        this.generation = generation
        this.frameId = frameId
        this.detail = detail
    }
}

/** Portable color identity for a Scene3D frame offered to the compositor. */
public enum Scene3DSharedColorSpace <: Equatable<Scene3DSharedColorSpace> {
    | Srgb
    | DisplayP3
    | ExtendedLinearSrgb

    public operator func ==(other: Scene3DSharedColorSpace): Bool {
        scene3DSharedColorSpaceName(this) == scene3DSharedColorSpaceName(other)
    }

    public operator func !=(other: Scene3DSharedColorSpace): Bool { !(this == other) }
}

public func scene3DSharedColorSpaceName(value: Scene3DSharedColorSpace): String {
    match (value) {
        case Scene3DSharedColorSpace.Srgb => "srgb"
        case Scene3DSharedColorSpace.DisplayP3 => "display-p3"
        case Scene3DSharedColorSpace.ExtendedLinearSrgb => "extended-linear-srgb"
    }
}

public enum Scene3DSharedAlphaMode <: Equatable<Scene3DSharedAlphaMode> {
    | Opaque
    | Premultiplied

    public operator func ==(other: Scene3DSharedAlphaMode): Bool {
        scene3DSharedAlphaModeName(this) == scene3DSharedAlphaModeName(other)
    }

    public operator func !=(other: Scene3DSharedAlphaMode): Bool { !(this == other) }
}

public func scene3DSharedAlphaModeName(value: Scene3DSharedAlphaMode): String {
    match (value) {
        case Scene3DSharedAlphaMode.Opaque => "opaque"
        case Scene3DSharedAlphaMode.Premultiplied => "premultiplied"
    }
}

/** Requested content range is not proof that a host actually activated HDR/EDR output. */
public enum Scene3DSharedDynamicRange <: Equatable<Scene3DSharedDynamicRange> {
    | Sdr
    | Extended

    public operator func ==(other: Scene3DSharedDynamicRange): Bool {
        scene3DSharedDynamicRangeName(this) == scene3DSharedDynamicRangeName(other)
    }

    public operator func !=(other: Scene3DSharedDynamicRange): Bool { !(this == other) }
}

public func scene3DSharedDynamicRangeName(value: Scene3DSharedDynamicRange): String {
    match (value) {
        case Scene3DSharedDynamicRange.Sdr => "sdr"
        case Scene3DSharedDynamicRange.Extended => "extended"
    }
}

/** Payload identity stays handle-free; native providers resolve private tokens inside their executor. */
public enum Scene3DSharedFramePayloadKind <: Equatable<Scene3DSharedFramePayloadKind> {
    | CpuRgba8
    | ProviderPrivateTexture

    public operator func ==(other: Scene3DSharedFramePayloadKind): Bool {
        scene3DSharedFramePayloadKindName(this) == scene3DSharedFramePayloadKindName(other)
    }

    public operator func !=(other: Scene3DSharedFramePayloadKind): Bool { !(this == other) }
}

public func scene3DSharedFramePayloadKindName(value: Scene3DSharedFramePayloadKind): String {
    match (value) {
        case Scene3DSharedFramePayloadKind.CpuRgba8 => "cpu-rgba8"
        case Scene3DSharedFramePayloadKind.ProviderPrivateTexture => "provider-private-texture"
    }
}

/** Explicit acquire synchronization fact; it is not itself proof that a provider waited. */
public struct Scene3DSharedAcquireSync {
    public let epoch: Int64
    public let waitRequired: Bool

    public init(epoch: Int64, waitRequired!: Bool = false) {
        if (epoch < 0) { throw IllegalArgumentException("scene3d acquire sync epoch must be non-negative") }
        this.epoch = epoch
        this.waitRequired = waitRequired
    }
}

/** Geometry/revision requested by the view at the exact layout frame being composed. */
public struct Scene3DSharedFrameRequest {
    public let surfaceId: String
    public let generation: Int64
    public let frameId: Int64
    public let logicalWidth: Float32
    public let logicalHeight: Float32
    public let scale: Float32
    public let placementRevision: Int64
    public let rotationCode: String

    public init(
        surfaceId: String,
        generation: Int64,
        frameId: Int64,
        logicalWidth: Float32,
        logicalHeight: Float32,
        scale: Float32,
        placementRevision: Int64,
        rotationCode: String
    ) {
        if (surfaceId.isEmpty() || generation <= 0 || frameId < 0 || logicalWidth <= 0.0 ||
            logicalHeight <= 0.0 || scale <= 0.0 || placementRevision <= 0 || rotationCode.isEmpty()) {
            throw IllegalArgumentException("scene3d shared frame request is invalid")
        }
        this.surfaceId = surfaceId
        this.generation = generation
        this.frameId = frameId
        this.logicalWidth = logicalWidth
        this.logicalHeight = logicalHeight
        this.scale = scale
        this.placementRevision = placementRevision
        this.rotationCode = rotationCode
    }
}

public enum Scene3DSharedFrameFinishReason {
    | Presented
    | Rejected
    | Fallback
    | ExecutorFailed
    | Replaced
    | Abandoned
}

public func scene3DSharedFrameFinishReasonName(value: Scene3DSharedFrameFinishReason): String {
    match (value) {
        case Scene3DSharedFrameFinishReason.Presented => "presented"
        case Scene3DSharedFrameFinishReason.Rejected => "rejected"
        case Scene3DSharedFrameFinishReason.Fallback => "fallback"
        case Scene3DSharedFrameFinishReason.ExecutorFailed => "executor-failed"
        case Scene3DSharedFrameFinishReason.Replaced => "replaced"
        case Scene3DSharedFrameFinishReason.Abandoned => "abandoned"
    }
}

/** Provider-visible proof that one lease release callback completed or failed. */
public struct Scene3DSharedFrameReleaseReceipt {
    public let ok: Bool
    public let code: String
    public let token: String
    public let reason: Scene3DSharedFrameFinishReason

    public init(ok: Bool, code: String, token: String, reason: Scene3DSharedFrameFinishReason) {
        this.ok = ok
        this.code = code
        this.token = token
        this.reason = reason
    }
}

private let SCENE3D_SHARED_FRAME_HARD_MAX_BYTES: Int64 = 268435456

/**
 * Exactly-once shared-frame lease. The portable software path exposes RGBA8 bytes; a native GPU
 * provider keeps its native texture/fence behind the provider and may use the stable token to bind
 * a private executor resource. No native handle is present in this API.
 */
public class Scene3DSharedFrameLease <: Resource {
    public let token: String
    public let surfaceId: String
    public let generation: Int64
    public let frameId: Int64
    public let pixelWidth: Int64
    public let pixelHeight: Int64
    public let rowBytes: Int64
    public let colorSpace: Scene3DSharedColorSpace
    public let alphaMode: Scene3DSharedAlphaMode
    public let dynamicRange: Scene3DSharedDynamicRange
    public let payloadKind: Scene3DSharedFramePayloadKind
    public let providerPrivateToken: String
    public let request: Scene3DSharedFrameRequest
    public let acquireSync: Scene3DSharedAcquireSync
    public let syncEpoch: Int64
    public let contentCode: Int64
    private let pixels: Array<UInt8>
    private let releaseAction: (Scene3DSharedFrameFinishReason) -> Bool
    private var closed = false
    private var releaseReceiptValue: ?Scene3DSharedFrameReleaseReceipt = None

    public init(
        token: String,
        request: Scene3DSharedFrameRequest,
        pixelWidth: Int64,
        pixelHeight: Int64,
        rowBytes: Int64,
        colorSpace: Scene3DSharedColorSpace,
        alphaMode: Scene3DSharedAlphaMode,
        dynamicRange: Scene3DSharedDynamicRange,
        acquireSync: Scene3DSharedAcquireSync,
        contentCode: Int64,
        payloadKind!: Scene3DSharedFramePayloadKind = Scene3DSharedFramePayloadKind.CpuRgba8,
        rgbaPixels!: Array<UInt8> = [],
        providerPrivateToken!: String = "",
        onFinish!: (Scene3DSharedFrameFinishReason) -> Bool = {_ => true}
    ) {
        if (token.isEmpty() || pixelWidth <= 0 || pixelHeight <= 0 ||
            pixelWidth > Int64.Max / 4 || contentCode <= 0) {
            throw IllegalArgumentException("scene3d shared frame metadata is invalid")
        }
        let minimumRowBytes = pixelWidth * 4
        if (rowBytes < minimumRowBytes || rowBytes <= 0 || pixelHeight > Int64.Max / rowBytes) {
            throw IllegalArgumentException("scene3d shared frame geometry overflows")
        }
        let payloadBytes = pixelHeight * rowBytes
        if (payloadBytes > SCENE3D_SHARED_FRAME_HARD_MAX_BYTES) {
            throw IllegalArgumentException("scene3d shared frame exceeds the hard byte limit")
        }
        if (payloadKind == Scene3DSharedFramePayloadKind.CpuRgba8 && rgbaPixels.size != payloadBytes) {
            throw IllegalArgumentException("scene3d shared frame payload does not match its geometry")
        }
        if (payloadKind == Scene3DSharedFramePayloadKind.ProviderPrivateTexture &&
            (!rgbaPixels.isEmpty() || providerPrivateToken.isEmpty())) {
            throw IllegalArgumentException("scene3d private texture payload requires only an opaque token")
        }
        this.token = token
        this.surfaceId = request.surfaceId
        this.generation = request.generation
        this.frameId = request.frameId
        this.pixelWidth = pixelWidth
        this.pixelHeight = pixelHeight
        this.rowBytes = rowBytes
        this.colorSpace = colorSpace
        this.alphaMode = alphaMode
        this.dynamicRange = dynamicRange
        this.payloadKind = payloadKind
        this.providerPrivateToken = providerPrivateToken
        this.request = request
        this.acquireSync = acquireSync
        this.syncEpoch = acquireSync.epoch
        this.contentCode = contentCode
        this.pixels = rgbaPixels.clone()
        this.releaseAction = onFinish
    }

    /** Returns an owned copy so provider memory never outlives the lease. */
    public func copyRgbaPixels(): Array<UInt8> {
        if (closed) { throw IllegalStateException("scene3d shared frame lease is closed") }
        if (payloadKind != Scene3DSharedFramePayloadKind.CpuRgba8) {
            throw IllegalStateException("scene3d shared frame does not expose CPU RGBA pixels")
        }
        pixels.clone()
    }

    public func isClosed(): Bool { closed }

    public func releaseReceipt(): ?Scene3DSharedFrameReleaseReceipt { releaseReceiptValue }

    public func finish(reason: Scene3DSharedFrameFinishReason): Scene3DSharedFrameReleaseReceipt {
        match (releaseReceiptValue) {
            case Some(value) => return value
            case None => ()
        }
        closed = true
        // Publish terminal ownership before entering provider code. A provider is allowed to
        // inspect or close the same lease from inside its callback; that re-entry must observe the
        // original token/reason and must never invoke the callback a second time. The outer call
        // replaces this in-progress receipt with the callback's final result before returning.
        releaseReceiptValue = Some(Scene3DSharedFrameReleaseReceipt(
            false,
            "release-in-progress",
            token,
            reason))
        let released = try {
            releaseAction(reason)
        } catch (_: Exception) {
            false
        }
        let value = Scene3DSharedFrameReleaseReceipt(
            released,
            if (released) { "released" } else { "release-failed" },
            token,
            reason)
        releaseReceiptValue = Some(value)
        value
    }

    public func close(): Unit {
        let _ = finish(Scene3DSharedFrameFinishReason.Abandoned)
    }
}

/** Optional provider extension; ordinary native-child Scene3DProvider implementations remain valid. */
public interface Scene3DSharedFrameProvider {
    func acquireSharedFrame(request: Scene3DSharedFrameRequest): ?Scene3DSharedFrameLease
}

/** A view remains native-child by default; shared composition is always an explicit opt-in. */
public enum Scene3DCompositionMode <: Equatable<Scene3DCompositionMode> {
    | NativeChild
    | PreferSharedFrame

    public operator func ==(other: Scene3DCompositionMode): Bool {
        scene3DCompositionModeName(this) == scene3DCompositionModeName(other)
    }

    public operator func !=(other: Scene3DCompositionMode): Bool { !(this == other) }
}

public func scene3DCompositionModeName(value: Scene3DCompositionMode): String {
    match (value) {
        case Scene3DCompositionMode.NativeChild => "native-child"
        case Scene3DCompositionMode.PreferSharedFrame => "prefer-shared-frame"
    }
}

/** Engine-neutral provider boundary. Implementations own all native resources. */
public interface Scene3DProvider {
    func attach(surface: Scene3DHostSurface, clock: Scene3DFrameClock): Scene3DReceipt
    func resize(surface: Scene3DHostSurface): Scene3DReceipt
    func loadScene(resource: Scene3DResource): Scene3DReceipt
    func submit(snapshot: Scene3DFrameSnapshot, clock: Scene3DFrameClock): Scene3DReceipt
    func hitTest(request: Scene3DHitTestRequest): Scene3DHitTestResult
    func present(clock: Scene3DFrameClock): Scene3DReceipt
    func detach(surfaceId: String, generation: Int64): Scene3DReceipt
}

/**
 * Deterministic F0 implementation. It validates the lifecycle and ordering
 * rules without opening a window or linking a renderer.
 */
public class FakeScene3DProvider <: Scene3DProvider & Scene3DSharedFrameProvider {
    private var attached = false
    private var surfaceId = ""
    private var generation: Int64 = 0
    private var lastFrameId: Int64 = -1
    private var loadedResourceId = ""
    private var lastSceneId = ""
    private var surfacePixelWidth: Int64 = 0
    private var surfacePixelHeight: Int64 = 0
    private var sharedAcquireCountValue: Int64 = 0
    private var sharedReleaseCountValue: Int64 = 0

    public func attach(surface: Scene3DHostSurface, clock: Scene3DFrameClock): Scene3DReceipt {
        if (attached && (surface.id != surfaceId || surface.generation <= generation)) {
            return reject("attach", "stale-generation", surface.generation, clock.frameId)
        }
        attached = true
        surfaceId = surface.id
        generation = surface.generation
        lastFrameId = clock.frameId
        loadedResourceId = ""
        lastSceneId = ""
        surfacePixelWidth = surface.pixelWidth
        surfacePixelHeight = surface.pixelHeight
        Scene3DReceipt(true, "attach", "accepted", generation, clock.frameId, "fake surface attached")
    }

    public func resize(surface: Scene3DHostSurface): Scene3DReceipt {
        if (!matches(surface.id, surface.generation)) {
            return reject("resize", "stale-generation", surface.generation, lastFrameId)
        }
        surfacePixelWidth = surface.pixelWidth
        surfacePixelHeight = surface.pixelHeight
        Scene3DReceipt(true, "resize", "accepted", generation, lastFrameId, "fake surface resized")
    }

    public func loadScene(resource: Scene3DResource): Scene3DReceipt {
        if (!attached) { return reject("load-scene", "not-attached", generation, lastFrameId) }
        loadedResourceId = resource.id
        Scene3DReceipt(true, "load-scene", "accepted", generation, lastFrameId, "resource validated")
    }

    public func submit(snapshot: Scene3DFrameSnapshot, clock: Scene3DFrameClock): Scene3DReceipt {
        if (!attached) { return reject("submit", "not-attached", generation, clock.frameId) }
        if (clock.frameId < lastFrameId) {
            return reject("submit", "frame-regressed", generation, clock.frameId)
        }
        if (loadedResourceId.isEmpty()) {
            return reject("submit", "scene-not-loaded", generation, clock.frameId)
        }
        snapshot.seal()
        lastFrameId = clock.frameId
        lastSceneId = snapshot.sceneId
        Scene3DReceipt(true, "submit", "accepted", generation, clock.frameId, "snapshot accepted")
    }

    public func hitTest(request: Scene3DHitTestRequest): Scene3DHitTestResult {
        if (!matches(surfaceId, request.generation) || request.frameId != lastFrameId) {
            return Scene3DHitTestResult.none(request.generation, request.frameId)
        }
        Scene3DHitTestResult.none(request.generation, request.frameId)
    }

    public func present(clock: Scene3DFrameClock): Scene3DReceipt {
        if (!attached) { return reject("present", "not-attached", generation, clock.frameId) }
        if (clock.frameId < lastFrameId) {
            return reject("present", "frame-regressed", generation, clock.frameId)
        }
        lastFrameId = clock.frameId
        Scene3DReceipt(true, "present", "accepted", generation, clock.frameId, "fake frame presented")
    }

    public func acquireSharedFrame(request: Scene3DSharedFrameRequest): ?Scene3DSharedFrameLease {
        if (!matches(request.surfaceId, request.generation) || request.frameId != lastFrameId ||
            request.frameId < 0 || loadedResourceId.isEmpty()) {
            return None
        }
        // The fake provider is a bounded software-conformance source, not a native GPU claim.
        let width = min(Int64(256), surfacePixelWidth)
        let height = min(Int64(256), surfacePixelHeight)
        if (width <= 0 || height <= 0) { return None }
        let pixels = ArrayList<UInt8>()
        let frameTint = UInt8(request.frameId % 251)
        for (y in 0..height) {
            for (x in 0..width) {
                let light = (x / 16 + y / 16) % 2 == 0
                pixels.add(if (light) { UInt8(48) } else { UInt8(20) })
                pixels.add(if (light) { UInt8(132) } else { UInt8(72) })
                pixels.add(frameTint)
                pixels.add(UInt8(255))
            }
        }
        sharedAcquireCountValue += 1
        let token = "fake-${generation}-${request.frameId}-${sharedAcquireCountValue}"
        Some(Scene3DSharedFrameLease(
            token,
            request,
            width,
            height,
            width * 4,
            Scene3DSharedColorSpace.Srgb,
            Scene3DSharedAlphaMode.Opaque,
            Scene3DSharedDynamicRange.Sdr,
            Scene3DSharedAcquireSync(request.frameId),
            fakeSharedFrameContentCode(generation, request.frameId, width, height),
            rgbaPixels: pixels.toArray(),
            onFinish: {_ => recordSharedFrameRelease() }
        ))
    }

    public func detach(surfaceId: String, generation: Int64): Scene3DReceipt {
        if (!matches(surfaceId, generation)) {
            return reject("detach", "stale-generation", generation, lastFrameId)
        }
        attached = false
        this.surfaceId = ""
        this.generation = 0
        loadedResourceId = ""
        lastSceneId = ""
        surfacePixelWidth = 0
        surfacePixelHeight = 0
        Scene3DReceipt(true, "detach", "accepted", generation, lastFrameId, "fake surface detached")
    }

    public func isAttached(): Bool { attached }
    public func currentGeneration(): Int64 { generation }
    public func currentSceneId(): String { lastSceneId }
    public func sharedAcquireCount(): Int64 { sharedAcquireCountValue }
    public func sharedReleaseCount(): Int64 { sharedReleaseCountValue }

    private func matches(id: String, value: Int64): Bool {
        attached && id == surfaceId && value == generation
    }

    private func reject(operation: String, code: String, value: Int64, frameId: Int64): Scene3DReceipt {
        Scene3DReceipt(false, operation, code, value, frameId, "fake provider rejected request")
    }

    private func recordSharedFrameRelease(): Bool { sharedReleaseCountValue += 1; true }
}

private func fakeSharedFrameContentCode(
    generation: Int64,
    frameId: Int64,
    width: Int64,
    height: Int64
): Int64 {
    let modulus: Int64 = 2147483647
    var code = positiveScene3DSharedCodePart(generation, modulus)
    code = (code * 1009 + positiveScene3DSharedCodePart(frameId, modulus)) % modulus
    code = (code * 31 + positiveScene3DSharedCodePart(width, modulus)) % modulus
    code = (code * 17 + positiveScene3DSharedCodePart(height, modulus)) % modulus
    if (code <= 0) { code += 2147483646 }
    code
}

private func positiveScene3DSharedCodePart(value: Int64, modulus: Int64): Int64 {
    let reduced = value % modulus
    if (reduced < 0) { reduced + modulus } else { reduced }
}
