package chui.graphics

import std.collection.ArrayList

public let CANGHUI_GRAPHICS_PROTOCOL = "canghui.graphics.v0"

/** Portable capability tiers requested by applications rather than native APIs. */
public enum GraphicsProfile <: Equatable<GraphicsProfile> {
    | Core3D
    | Compute3D
    | NativeExtended

    public operator func ==(other: GraphicsProfile): Bool {
        graphicsProfileName(this) == graphicsProfileName(other)
    }

    public operator func !=(other: GraphicsProfile): Bool { !(this == other) }
}

public func graphicsProfileName(profile: GraphicsProfile): String {
    match (profile) {
        case GraphicsProfile.Core3D => "core-3d"
        case GraphicsProfile.Compute3D => "compute-3d"
        case GraphicsProfile.NativeExtended => "native-extended"
    }
}

/** Adapter selection preference. It never names a renderer backend. */
public enum GraphicsPowerPreference <: Equatable<GraphicsPowerPreference> {
    | Default
    | LowPower
    | HighPerformance

    public operator func ==(other: GraphicsPowerPreference): Bool {
        graphicsPowerPreferenceName(this) == graphicsPowerPreferenceName(other)
    }

    public operator func !=(other: GraphicsPowerPreference): Bool { !(this == other) }
}

public func graphicsPowerPreferenceName(preference: GraphicsPowerPreference): String {
    match (preference) {
        case GraphicsPowerPreference.Default => "default"
        case GraphicsPowerPreference.LowPower => "low-power"
        case GraphicsPowerPreference.HighPerformance => "high-performance"
    }
}

/** Capabilities are negotiated before a provider creates native resources. */
public enum GraphicsCapability <: Equatable<GraphicsCapability> {
    | RenderPipeline
    | SampledTexture
    | DepthTexture
    | Instancing
    | ComputePipeline
    | StorageBuffer
    | TimestampQuery
    | HdrSurface

    public operator func ==(other: GraphicsCapability): Bool {
        graphicsCapabilityName(this) == graphicsCapabilityName(other)
    }

    public operator func !=(other: GraphicsCapability): Bool { !(this == other) }
}

public func graphicsCapabilityName(capability: GraphicsCapability): String {
    match (capability) {
        case GraphicsCapability.RenderPipeline => "render-pipeline"
        case GraphicsCapability.SampledTexture => "sampled-texture"
        case GraphicsCapability.DepthTexture => "depth-texture"
        case GraphicsCapability.Instancing => "instancing"
        case GraphicsCapability.ComputePipeline => "compute-pipeline"
        case GraphicsCapability.StorageBuffer => "storage-buffer"
        case GraphicsCapability.TimestampQuery => "timestamp-query"
        case GraphicsCapability.HdrSurface => "hdr-surface"
    }
}

/** Backend identity is provider output and diagnostics, never a surface requirement. */
public enum GraphicsBackend <: Equatable<GraphicsBackend> {
    | Metal
    | Vulkan
    | D3D11
    | D3D12
    | OpenGLES
    | WebGPU
    | Software

    public operator func ==(other: GraphicsBackend): Bool {
        graphicsBackendName(this) == graphicsBackendName(other)
    }

    public operator func !=(other: GraphicsBackend): Bool { !(this == other) }
}

public func graphicsBackendName(backend: GraphicsBackend): String {
    match (backend) {
        case GraphicsBackend.Metal => "metal"
        case GraphicsBackend.Vulkan => "vulkan"
        case GraphicsBackend.D3D11 => "d3d11"
        case GraphicsBackend.D3D12 => "d3d12"
        case GraphicsBackend.OpenGLES => "opengles"
        case GraphicsBackend.WebGPU => "webgpu"
        case GraphicsBackend.Software => "software"
    }
}

public enum GraphicsColorSpace <: Equatable<GraphicsColorSpace> {
    | Srgb
    | DisplayP3
    | ExtendedLinearSrgb

    public operator func ==(other: GraphicsColorSpace): Bool {
        graphicsColorSpaceName(this) == graphicsColorSpaceName(other)
    }

    public operator func !=(other: GraphicsColorSpace): Bool { !(this == other) }
}

public func graphicsColorSpaceName(colorSpace: GraphicsColorSpace): String {
    match (colorSpace) {
        case GraphicsColorSpace.Srgb => "srgb"
        case GraphicsColorSpace.DisplayP3 => "display-p3"
        case GraphicsColorSpace.ExtendedLinearSrgb => "extended-linear-srgb"
    }
}

public enum GraphicsAlphaMode <: Equatable<GraphicsAlphaMode> {
    | Opaque
    | Premultiplied

    public operator func ==(other: GraphicsAlphaMode): Bool {
        graphicsAlphaModeName(this) == graphicsAlphaModeName(other)
    }

    public operator func !=(other: GraphicsAlphaMode): Bool { !(this == other) }
}

public func graphicsAlphaModeName(alphaMode: GraphicsAlphaMode): String {
    match (alphaMode) {
        case GraphicsAlphaMode.Opaque => "opaque"
        case GraphicsAlphaMode.Premultiplied => "premultiplied"
    }
}

/**
 * A host-owned surface lease. `platformToken` is opaque to applications and
 * resolved only by the selected platform/provider adapter.
 */
public struct GraphicsSurfaceLease {
    public let id: String
    public let platformToken: String
    public let logicalWidth: Float32
    public let logicalHeight: Float32
    public let pixelWidth: Int64
    public let pixelHeight: Int64
    public let scale: Float32
    public let colorSpace: GraphicsColorSpace
    public let alphaMode: GraphicsAlphaMode
    public let generation: Int64

    public init(
        id: String,
        platformToken: String,
        logicalWidth: Float32,
        logicalHeight: Float32,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scale: Float32,
        generation: Int64,
        colorSpace!: GraphicsColorSpace = GraphicsColorSpace.Srgb,
        alphaMode!: GraphicsAlphaMode = GraphicsAlphaMode.Opaque
    ) {
        if (id.isEmpty() || platformToken.isEmpty()) {
            throw IllegalArgumentException("graphics surface identity and token must be present")
        }
        if (logicalWidth <= 0.0 || logicalWidth - logicalWidth != 0.0 ||
            logicalHeight <= 0.0 || logicalHeight - logicalHeight != 0.0 ||
            pixelWidth <= 0 || pixelHeight <= 0 ||
            scale <= 0.0 || scale - scale != 0.0) {
            throw IllegalArgumentException("graphics surface geometry must be positive and finite")
        }
        if (generation <= 0) {
            throw IllegalArgumentException("graphics surface generation must be positive")
        }
        this.id = id
        this.platformToken = platformToken
        this.logicalWidth = logicalWidth
        this.logicalHeight = logicalHeight
        this.pixelWidth = pixelWidth
        this.pixelHeight = pixelHeight
        this.scale = scale
        this.colorSpace = colorSpace
        this.alphaMode = alphaMode
        this.generation = generation
    }
}

/** Bounded portable limits. Providers may expose larger values. */
public struct GraphicsLimits {
    public let maxTextureDimension2D: Int64
    public let maxBindGroups: Int64
    public let maxVertexBuffers: Int64
    public let maxColorAttachments: Int64

    public init(
        maxTextureDimension2D: Int64,
        maxBindGroups: Int64,
        maxVertexBuffers: Int64,
        maxColorAttachments: Int64
    ) {
        if (maxTextureDimension2D <= 0 || maxBindGroups <= 0 ||
            maxVertexBuffers <= 0 || maxColorAttachments <= 0) {
            throw IllegalArgumentException("graphics limits must be positive")
        }
        this.maxTextureDimension2D = maxTextureDimension2D
        this.maxBindGroups = maxBindGroups
        this.maxVertexBuffers = maxVertexBuffers
        this.maxColorAttachments = maxColorAttachments
    }

    public func supports(required: GraphicsLimits): Bool {
        maxTextureDimension2D >= required.maxTextureDimension2D &&
        maxBindGroups >= required.maxBindGroups &&
        maxVertexBuffers >= required.maxVertexBuffers &&
        maxColorAttachments >= required.maxColorAttachments
    }
}

/** Immutable provider capability snapshot returned before native attachment. */
public class GraphicsAdapterCapabilities {
    public let providerId: String
    public let adapterId: String
    public let backend: GraphicsBackend
    public let profile: GraphicsProfile
    public let limits: GraphicsLimits
    private let capabilities = ArrayList<GraphicsCapability>()

    public init(
        providerId: String,
        adapterId: String,
        backend: GraphicsBackend,
        profile: GraphicsProfile,
        limits: GraphicsLimits,
        capabilities!: Array<GraphicsCapability> = []
    ) {
        if (providerId.isEmpty() || adapterId.isEmpty()) {
            throw IllegalArgumentException("graphics provider and adapter identity must be present")
        }
        this.providerId = providerId
        this.adapterId = adapterId
        this.backend = backend
        this.profile = profile
        this.limits = limits
        for (capability in capabilities) {
            if (has(capability)) {
                throw IllegalArgumentException(
                    "duplicate graphics capability: " + graphicsCapabilityName(capability))
            }
            this.capabilities.add(capability)
        }
        if (!has(GraphicsCapability.RenderPipeline) ||
            !has(GraphicsCapability.SampledTexture) ||
            !has(GraphicsCapability.DepthTexture)) {
            throw IllegalArgumentException(
                "graphics profiles require render-pipeline, sampled-texture and depth-texture")
        }
        if (profile == GraphicsProfile.Compute3D &&
            (!has(GraphicsCapability.ComputePipeline) ||
             !has(GraphicsCapability.StorageBuffer))) {
            throw IllegalArgumentException(
                "compute-3d profile requires compute-pipeline and storage-buffer")
        }
    }

    public func has(capability: GraphicsCapability): Bool {
        for (current in capabilities) {
            if (current == capability) { return true }
        }
        false
    }

    public func capabilityCount(): Int64 { capabilities.size }
    public func capabilityAt(index: Int64): GraphicsCapability { capabilities[index] }

    public func supportsProfile(required: GraphicsProfile): Bool {
        match (required) {
            case GraphicsProfile.Core3D => true
            case GraphicsProfile.Compute3D =>
                has(GraphicsCapability.ComputePipeline) && has(GraphicsCapability.StorageBuffer)
            case GraphicsProfile.NativeExtended => profile == GraphicsProfile.NativeExtended
        }
    }
}

/** Application request. A backend is deliberately absent. */
public class GraphicsAdapterRequest {
    public let profile: GraphicsProfile
    public let powerPreference: GraphicsPowerPreference
    public let minimumLimits: ?GraphicsLimits
    public let allowFallback: Bool
    private let requiredCapabilities = ArrayList<GraphicsCapability>()

    public init(
        profile: GraphicsProfile,
        powerPreference!: GraphicsPowerPreference = GraphicsPowerPreference.Default,
        requiredCapabilities!: Array<GraphicsCapability> = [],
        minimumLimits!: ?GraphicsLimits = None,
        allowFallback!: Bool = false
    ) {
        this.profile = profile
        this.powerPreference = powerPreference
        this.minimumLimits = minimumLimits
        this.allowFallback = allowFallback
        for (capability in requiredCapabilities) {
            if (requires(capability)) {
                throw IllegalArgumentException(
                    "duplicate required graphics capability: " + graphicsCapabilityName(capability))
            }
            this.requiredCapabilities.add(capability)
        }
    }

    public func requires(capability: GraphicsCapability): Bool {
        for (current in requiredCapabilities) {
            if (current == capability) { return true }
        }
        false
    }

    public func requiredCapabilityCount(): Int64 { requiredCapabilities.size }
    public func requiredCapabilityAt(index: Int64): GraphicsCapability { requiredCapabilities[index] }
}

public enum GraphicsAdapterSelectionStatus <: Equatable<GraphicsAdapterSelectionStatus> {
    | Selected
    | Degraded
    | Unsupported
    | Rejected

    public operator func ==(other: GraphicsAdapterSelectionStatus): Bool {
        graphicsAdapterSelectionStatusName(this) == graphicsAdapterSelectionStatusName(other)
    }

    public operator func !=(other: GraphicsAdapterSelectionStatus): Bool { !(this == other) }
}

public func graphicsAdapterSelectionStatusName(status: GraphicsAdapterSelectionStatus): String {
    match (status) {
        case GraphicsAdapterSelectionStatus.Selected => "selected"
        case GraphicsAdapterSelectionStatus.Degraded => "degraded"
        case GraphicsAdapterSelectionStatus.Unsupported => "unsupported"
        case GraphicsAdapterSelectionStatus.Rejected => "rejected"
    }
}

/** Machine-readable selection truth for logging, doctor and future cuic receipts. */
public struct GraphicsAdapterSelection {
    public let status: GraphicsAdapterSelectionStatus
    public let code: String
    public let providerId: String
    public let adapterId: String
    public let backend: GraphicsBackend
    public let requestedProfile: GraphicsProfile
    public let selectedProfile: GraphicsProfile
    public let surfaceId: String
    public let generation: Int64
    public let detail: String

    public init(
        status: GraphicsAdapterSelectionStatus,
        code: String,
        request: GraphicsAdapterRequest,
        capabilities: GraphicsAdapterCapabilities,
        surface: GraphicsSurfaceLease,
        detail!: String = ""
    ) {
        if (code.isEmpty()) {
            throw IllegalArgumentException("graphics adapter selection code must be present")
        }
        this.status = status
        this.code = code
        this.providerId = capabilities.providerId
        this.adapterId = capabilities.adapterId
        this.backend = capabilities.backend
        this.requestedProfile = request.profile
        this.selectedProfile = capabilities.profile
        this.surfaceId = surface.id
        this.generation = surface.generation
        this.detail = detail
    }

    public func ok(): Bool {
        status == GraphicsAdapterSelectionStatus.Selected ||
        status == GraphicsAdapterSelectionStatus.Degraded
    }
}

public struct GraphicsAdapterReceipt {
    public let ok: Bool
    public let operation: String
    public let code: String
    public let surfaceId: String
    public let generation: Int64
    public let detail: String

    public init(
        ok: Bool,
        operation: String,
        code: String,
        surfaceId: String,
        generation: Int64,
        detail!: String = ""
    ) {
        this.ok = ok
        this.operation = operation
        this.code = code
        this.surfaceId = surfaceId
        this.generation = generation
        this.detail = detail
    }
}

/** Provider-neutral selection boundary. Native device creation stays private. */
public interface GraphicsAdapter {
    func capabilities(): GraphicsAdapterCapabilities
    func select(request: GraphicsAdapterRequest, surface: GraphicsSurfaceLease): GraphicsAdapterSelection
    func release(surfaceId: String, generation: Int64): GraphicsAdapterReceipt
}

/** Deterministic F0 adapter used to prove negotiation without opening a GPU. */
public class FakeGraphicsAdapter <: GraphicsAdapter {
    private let offered: GraphicsAdapterCapabilities
    private var selected = false
    private var surfaceId = ""
    private var generation: Int64 = 0

    public init(offered: GraphicsAdapterCapabilities) { this.offered = offered }

    public func capabilities(): GraphicsAdapterCapabilities { offered }

    public func select(
        request: GraphicsAdapterRequest,
        surface: GraphicsSurfaceLease
    ): GraphicsAdapterSelection {
        if (selected && surface.id != surfaceId) {
            return selection(GraphicsAdapterSelectionStatus.Rejected, "adapter-busy", request, surface,
                "fake adapter already owns another surface")
        }
        if (selected && surface.generation <= generation) {
            return selection(GraphicsAdapterSelectionStatus.Rejected, "stale-generation", request, surface,
                "surface generation must advance before reselection")
        }

        for (i in 0..request.requiredCapabilityCount()) {
            let required = request.requiredCapabilityAt(i)
            if (!offered.has(required)) {
                return selection(GraphicsAdapterSelectionStatus.Unsupported,
                    "missing-capability:" + graphicsCapabilityName(required), request, surface,
                    "required graphics capability is unavailable")
            }
        }

        match (request.minimumLimits) {
            case Some(required) =>
                if (!offered.limits.supports(required)) {
                    return selection(GraphicsAdapterSelectionStatus.Unsupported,
                        "limits-unsupported", request, surface,
                        "requested graphics limits exceed provider limits")
                }
            case None => ()
        }

        let profileSupported = offered.supportsProfile(request.profile)
        if (!profileSupported && !request.allowFallback) {
            return selection(GraphicsAdapterSelectionStatus.Unsupported,
                "profile-unsupported", request, surface,
                "requested graphics profile is unavailable")
        }

        selected = true
        surfaceId = surface.id
        generation = surface.generation
        if (profileSupported) {
            selection(GraphicsAdapterSelectionStatus.Selected, "selected", request, surface,
                "fake adapter selected without fallback")
        } else {
            selection(GraphicsAdapterSelectionStatus.Degraded, "profile-fallback", request, surface,
                "fake adapter selected its available profile")
        }
    }

    public func release(releasedSurfaceId: String, releasedGeneration: Int64): GraphicsAdapterReceipt {
        if (!selected) {
            return GraphicsAdapterReceipt(false, "release", "not-selected",
                releasedSurfaceId, releasedGeneration, detail: "fake adapter has no selected surface")
        }
        if (releasedSurfaceId != surfaceId || releasedGeneration != generation) {
            return GraphicsAdapterReceipt(false, "release", "stale-generation",
                releasedSurfaceId, releasedGeneration, detail: "fake adapter rejected stale release")
        }
        selected = false
        surfaceId = ""
        generation = 0
        GraphicsAdapterReceipt(true, "release", "released",
            releasedSurfaceId, releasedGeneration, detail: "fake adapter surface released")
    }

    public func isSelected(): Bool { selected }
    public func currentGeneration(): Int64 { generation }

    private func selection(
        status: GraphicsAdapterSelectionStatus,
        code: String,
        request: GraphicsAdapterRequest,
        surface: GraphicsSurfaceLease,
        detail: String
    ): GraphicsAdapterSelection {
        GraphicsAdapterSelection(status, code, request, offered, surface, detail: detail)
    }
}
