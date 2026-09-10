package chui.graphics

import std.collection.ArrayList

/** Internal module protocol. It is deliberately not re-exported by `package chui`. */
protected let CANGHUI_FRAME_GRAPH_PROTOCOL = "canghui.frame-graph.v0"

protected let CANGHUI_FRAME_GRAPH_MAX_PASSES: Int64 = 4096
protected let CANGHUI_FRAME_GRAPH_MAX_RESOURCES: Int64 = 8192
protected let CANGHUI_FRAME_GRAPH_MAX_DEPENDENCIES: Int64 = 65536
protected let CANGHUI_FRAME_GRAPH_MAX_DAMAGE_RECTS: Int64 = 4096
protected let CANGHUI_FRAME_GRAPH_MAX_TRACE_BYTES: Int64 = 4194304
protected let CANGHUI_FRAME_GRAPH_MAX_RESOURCE_BYTES: Int64 = 1073741824

/** Stable graph-owned identity. `key` is bounded ASCII and never a native handle. */
protected struct FrameResourceId <: Equatable<FrameResourceId> {
    public let key: String
    public let generation: Int64

    public init(key: String, generation: Int64) {
        requireFrameGraphToken(key, "frame resource key")
        if (generation <= 0) {
            throw IllegalArgumentException("frame resource generation must be positive")
        }
        this.key = key
        this.generation = generation
    }

    public operator func ==(other: FrameResourceId): Bool {
        key == other.key && generation == other.generation
    }

    public operator func !=(other: FrameResourceId): Bool { !(this == other) }
}

/** Stable pass identity. Declaration order remains a separate scheduling fact. */
protected struct FramePassId <: Equatable<FramePassId> {
    public let key: String

    public init(key: String) {
        requireFrameGraphToken(key, "frame pass key")
        this.key = key
    }

    public operator func ==(other: FramePassId): Bool { key == other.key }
    public operator func !=(other: FramePassId): Bool { !(this == other) }
}

protected enum FrameResourceLifetime <: Equatable<FrameResourceLifetime> {
    | Imported
    | Transient
    | Persistent

    public operator func ==(other: FrameResourceLifetime): Bool {
        frameResourceLifetimeName(this) == frameResourceLifetimeName(other)
    }

    public operator func !=(other: FrameResourceLifetime): Bool { !(this == other) }
}

protected func frameResourceLifetimeName(value: FrameResourceLifetime): String {
    match (value) {
        case FrameResourceLifetime.Imported => "imported"
        case FrameResourceLifetime.Transient => "transient"
        case FrameResourceLifetime.Persistent => "persistent"
    }
}

protected enum FrameResourceKind <: Equatable<FrameResourceKind> {
    | Surface
    | Texture
    | Buffer
    | Sampler
    | Shader
    | Pipeline
    | ExternalSurface

    public operator func ==(other: FrameResourceKind): Bool {
        frameResourceKindName(this) == frameResourceKindName(other)
    }

    public operator func !=(other: FrameResourceKind): Bool { !(this == other) }
}

protected func frameResourceKindName(value: FrameResourceKind): String {
    match (value) {
        case FrameResourceKind.Surface => "surface"
        case FrameResourceKind.Texture => "texture"
        case FrameResourceKind.Buffer => "buffer"
        case FrameResourceKind.Sampler => "sampler"
        case FrameResourceKind.Shader => "shader"
        case FrameResourceKind.Pipeline => "pipeline"
        case FrameResourceKind.ExternalSurface => "external-surface"
    }
}

protected enum FramePassKind <: Equatable<FramePassKind> {
    | Ui2D
    | RendererEffect
    | ExternalScene3D
    | OffscreenComposition
    | CopyResolve
    | Present

    public operator func ==(other: FramePassKind): Bool {
        framePassKindName(this) == framePassKindName(other)
    }

    public operator func !=(other: FramePassKind): Bool { !(this == other) }
}

protected func framePassKindName(value: FramePassKind): String {
    match (value) {
        case FramePassKind.Ui2D => "ui-2d"
        case FramePassKind.RendererEffect => "renderer-effect"
        case FramePassKind.ExternalScene3D => "external-scene3d"
        case FramePassKind.OffscreenComposition => "offscreen-composition"
        case FramePassKind.CopyResolve => "copy-resolve"
        case FramePassKind.Present => "present"
    }
}

/** `SharedTexture` remains capability-gated; rev1 does not imply that a provider exists. */
protected enum FrameExternalMode <: Equatable<FrameExternalMode> {
    | NoExternalSurface
    | NativeChildSurfaceBarrier
    | SharedTexture

    public operator func ==(other: FrameExternalMode): Bool {
        frameExternalModeName(this) == frameExternalModeName(other)
    }

    public operator func !=(other: FrameExternalMode): Bool { !(this == other) }
}

protected func frameExternalModeName(value: FrameExternalMode): String {
    match (value) {
        case FrameExternalMode.NoExternalSurface => "none"
        case FrameExternalMode.NativeChildSurfaceBarrier => "native-child-surface-barrier"
        case FrameExternalMode.SharedTexture => "shared-texture"
    }
}

/** A reserved slot, not an HDR implementation. Rev1 executors normally accept only `Sdr`. */
protected enum FrameDynamicRange <: Equatable<FrameDynamicRange> {
    | Sdr
    | ReservedExtended

    public operator func ==(other: FrameDynamicRange): Bool {
        frameDynamicRangeName(this) == frameDynamicRangeName(other)
    }

    public operator func !=(other: FrameDynamicRange): Bool { !(this == other) }
}

protected func frameDynamicRangeName(value: FrameDynamicRange): String {
    match (value) {
        case FrameDynamicRange.Sdr => "sdr"
        case FrameDynamicRange.ReservedExtended => "reserved-extended"
    }
}

protected enum FrameDamageKind <: Equatable<FrameDamageKind> {
    | Empty
    | Bounded
    | Full

    public operator func ==(other: FrameDamageKind): Bool {
        frameDamageKindName(this) == frameDamageKindName(other)
    }

    public operator func !=(other: FrameDamageKind): Bool { !(this == other) }
}

protected func frameDamageKindName(value: FrameDamageKind): String {
    match (value) {
        case FrameDamageKind.Empty => "empty"
        case FrameDamageKind.Bounded => "bounded"
        case FrameDamageKind.Full => "full"
    }
}

/**
 * Immutable logical surface-space rectangle. Providers convert these units to physical pixels;
 * resource-byte caps separately account for display scale and supersampling.
 */
protected struct FrameDamageRect <: Equatable<FrameDamageRect> {
    public let x: Int64
    public let y: Int64
    public let width: Int64
    public let height: Int64

    public init(x: Int64, y: Int64, width: Int64, height: Int64) {
        if (x < 0 || y < 0 || width <= 0 || height <= 0 ||
            x > Int64.Max - width || y > Int64.Max - height) {
            throw IllegalArgumentException("frame damage rectangle must be positive, finite and non-overflowing")
        }
        this.x = x
        this.y = y
        this.width = width
        this.height = height
    }

    public func right(): Int64 { x + width }
    public func bottom(): Int64 { y + height }

    public operator func ==(other: FrameDamageRect): Bool {
        x == other.x && y == other.y && width == other.width && height == other.height
    }

    public operator func !=(other: FrameDamageRect): Bool { !(this == other) }
}

/** Empty, bounded or explicitly full-frame damage. Constructors copy all rectangles. */
protected class DamageRegion {
    public let kind: FrameDamageKind
    private let rectangles = ArrayList<FrameDamageRect>()

    private init(value: FrameDamageKind, values: Array<FrameDamageRect>) {
        this.kind = value
        for (rect in values) { rectangles.add(rect) }
    }

    public static func empty(): DamageRegion {
        DamageRegion(FrameDamageKind.Empty, [])
    }

    public static func full(): DamageRegion {
        DamageRegion(FrameDamageKind.Full, [])
    }

    public static func bounded(values: Array<FrameDamageRect>): DamageRegion {
        if (values.size == 0) {
            throw IllegalArgumentException("bounded frame damage requires at least one rectangle")
        }
        DamageRegion(FrameDamageKind.Bounded, values)
    }

    public func rectangleCount(): Int64 { rectangles.size }
    public func rectangleAt(index: Int64): FrameDamageRect { rectangles[index] }
}

/** One resource version declared by a frame. */
protected class FrameResourceDescriptor {
    public let id: FrameResourceId
    public let kind: FrameResourceKind
    public let lifetime: FrameResourceLifetime
    public let declaredBytes: Int64
    public let colorSpace: GraphicsColorSpace
    public let alphaMode: GraphicsAlphaMode
    public let dynamicRange: FrameDynamicRange

    public init(
        id: FrameResourceId,
        kind: FrameResourceKind,
        lifetime: FrameResourceLifetime,
        declaredBytes!: Int64 = 0,
        colorSpace!: GraphicsColorSpace = GraphicsColorSpace.Srgb,
        alphaMode!: GraphicsAlphaMode = GraphicsAlphaMode.Premultiplied,
        dynamicRange!: FrameDynamicRange = FrameDynamicRange.Sdr
    ) {
        if (declaredBytes < 0) {
            throw IllegalArgumentException("frame resource bytes must be non-negative")
        }
        this.id = id
        this.kind = kind
        this.lifetime = lifetime
        this.declaredBytes = declaredBytes
        this.colorSpace = colorSpace
        this.alphaMode = alphaMode
        this.dynamicRange = dynamicRange
    }
}

/**
 * Pure scheduling metadata. Runtime closures, renderer objects and native handles belong in an
 * executor-owned binding table keyed by `id`; none of them enter this descriptor or its trace.
 */
protected class FramePassDescriptor {
    public let id: FramePassId
    public let declarationOrder: Int64
    public let kind: FramePassKind
    private let readResources = ArrayList<FrameResourceId>()
    private let writtenResources = ArrayList<FrameResourceId>()
    private let explicitDependencies = ArrayList<FramePassId>()
    public let bounds: ?FrameDamageRect
    public let declaredDamage: DamageRegion
    public let effectRadius: Int64
    public let stableInputCode: Int64
    public let canCull: Bool
    public let canMerge: Bool
    public let mergeKey: String
    public let colorSpace: GraphicsColorSpace
    public let alphaMode: GraphicsAlphaMode
    public let dynamicRange: FrameDynamicRange
    public let externalMode: FrameExternalMode

    public init(
        id: FramePassId,
        declarationOrder: Int64,
        kind: FramePassKind,
        reads!: Array<FrameResourceId> = [],
        writes!: Array<FrameResourceId> = [],
        dependsOn!: Array<FramePassId> = [],
        bounds!: ?FrameDamageRect = None,
        declaredDamage!: DamageRegion = DamageRegion.empty(),
        effectRadius!: Int64 = 0,
        stableInputCode!: Int64 = 0,
        canCull!: Bool = false,
        canMerge!: Bool = false,
        mergeKey!: String = "",
        colorSpace!: GraphicsColorSpace = GraphicsColorSpace.Srgb,
        alphaMode!: GraphicsAlphaMode = GraphicsAlphaMode.Premultiplied,
        dynamicRange!: FrameDynamicRange = FrameDynamicRange.Sdr,
        externalMode!: FrameExternalMode = FrameExternalMode.NoExternalSurface
    ) {
        if (declarationOrder < 0 || effectRadius < 0 || stableInputCode < 0) {
            throw IllegalArgumentException("frame pass order, effect radius and stable code must be non-negative")
        }
        if (!mergeKey.isEmpty()) { requireFrameGraphToken(mergeKey, "frame pass merge key") }
        this.id = id
        this.declarationOrder = declarationOrder
        this.kind = kind
        for (value in reads) { readResources.add(value) }
        for (value in writes) { writtenResources.add(value) }
        for (value in dependsOn) { explicitDependencies.add(value) }
        this.bounds = bounds
        this.declaredDamage = declaredDamage
        this.effectRadius = effectRadius
        this.stableInputCode = stableInputCode
        this.canCull = canCull
        this.canMerge = canMerge
        this.mergeKey = mergeKey
        this.colorSpace = colorSpace
        this.alphaMode = alphaMode
        this.dynamicRange = dynamicRange
        this.externalMode = externalMode
    }

    public func readCount(): Int64 { readResources.size }
    public func readAt(index: Int64): FrameResourceId { readResources[index] }
    public func writeCount(): Int64 { writtenResources.size }
    public func writeAt(index: Int64): FrameResourceId { writtenResources[index] }
    public func dependencyCount(): Int64 { explicitDependencies.size }
    public func dependencyAt(index: Int64): FramePassId { explicitDependencies[index] }
}

/** User-lowerable limits under immutable framework hard caps. */
protected struct FrameGraphLimits {
    public let maxPasses: Int64
    public let maxResources: Int64
    public let maxDependencies: Int64
    public let maxDamageRectangles: Int64
    public let maxTraceBytes: Int64
    public let maxDeclaredResourceBytes: Int64

    public init(
        maxPasses!: Int64 = 1024,
        maxResources!: Int64 = 2048,
        maxDependencies!: Int64 = 16384,
        maxDamageRectangles!: Int64 = 256,
        maxTraceBytes!: Int64 = 1048576,
        maxDeclaredResourceBytes!: Int64 = 268435456
    ) {
        if (maxPasses <= 0 || maxResources <= 0 || maxDependencies <= 0 ||
            maxDamageRectangles <= 0 || maxTraceBytes <= 0 || maxDeclaredResourceBytes <= 0) {
            throw IllegalArgumentException("frame graph limits must be positive")
        }
        if (maxPasses > CANGHUI_FRAME_GRAPH_MAX_PASSES ||
            maxResources > CANGHUI_FRAME_GRAPH_MAX_RESOURCES ||
            maxDependencies > CANGHUI_FRAME_GRAPH_MAX_DEPENDENCIES ||
            maxDamageRectangles > CANGHUI_FRAME_GRAPH_MAX_DAMAGE_RECTS ||
            maxTraceBytes > CANGHUI_FRAME_GRAPH_MAX_TRACE_BYTES ||
            maxDeclaredResourceBytes > CANGHUI_FRAME_GRAPH_MAX_RESOURCE_BYTES) {
            throw IllegalArgumentException("frame graph limits exceed framework hard caps")
        }
        this.maxPasses = maxPasses
        this.maxResources = maxResources
        this.maxDependencies = maxDependencies
        this.maxDamageRectangles = maxDamageRectangles
        this.maxTraceBytes = maxTraceBytes
        this.maxDeclaredResourceBytes = maxDeclaredResourceBytes
    }
}

/** Immutable graph input. Array declaration order is part of its deterministic identity. */
protected class FrameGraph {
    public let surfaceKey: String
    public let surfaceGeneration: Int64
    public let frameId: Int64
    public let surfaceWidth: Int64
    public let surfaceHeight: Int64
    public let frameDamage: DamageRegion
    public let limits: FrameGraphLimits
    private let resources = ArrayList<FrameResourceDescriptor>()
    private let passes = ArrayList<FramePassDescriptor>()

    public init(
        surfaceKey: String,
        surfaceGeneration: Int64,
        frameId: Int64,
        surfaceWidth: Int64,
        surfaceHeight: Int64,
        resources: Array<FrameResourceDescriptor>,
        passes: Array<FramePassDescriptor>,
        frameDamage!: DamageRegion = DamageRegion.full(),
        limits!: FrameGraphLimits = FrameGraphLimits()
    ) {
        requireFrameGraphToken(surfaceKey, "frame graph surface key")
        if (surfaceGeneration <= 0 || frameId <= 0 || surfaceWidth <= 0 || surfaceHeight <= 0) {
            throw IllegalArgumentException("frame graph surface, generation and frame geometry must be positive")
        }
        this.surfaceKey = surfaceKey
        this.surfaceGeneration = surfaceGeneration
        this.frameId = frameId
        this.surfaceWidth = surfaceWidth
        this.surfaceHeight = surfaceHeight
        for (value in resources) { this.resources.add(value) }
        for (value in passes) { this.passes.add(value) }
        this.frameDamage = frameDamage
        this.limits = limits
    }

    public func resourceCount(): Int64 { resources.size }
    public func resourceAt(index: Int64): FrameResourceDescriptor { resources[index] }
    public func passCount(): Int64 { passes.size }
    public func passAt(index: Int64): FramePassDescriptor { passes[index] }
}

/** Executor truth is separate from graph content and may differ by provider. */
protected struct FrameGraphExecutorCapabilities {
    public let supportsBoundedRedraw: Bool
    public let supportsPartialPresent: Bool
    public let supportsSharedTexture: Bool
    public let supportsExtendedDynamicRange: Bool
    public let maxDeclaredResourceBytes: Int64

    public init(
        supportsBoundedRedraw!: Bool = false,
        supportsPartialPresent!: Bool = false,
        supportsSharedTexture!: Bool = false,
        supportsExtendedDynamicRange!: Bool = false,
        maxDeclaredResourceBytes!: Int64 = 268435456
    ) {
        if (maxDeclaredResourceBytes <= 0 ||
            maxDeclaredResourceBytes > CANGHUI_FRAME_GRAPH_MAX_RESOURCE_BYTES) {
            throw IllegalArgumentException("frame executor resource-byte capability is invalid")
        }
        this.supportsBoundedRedraw = supportsBoundedRedraw
        this.supportsPartialPresent = supportsPartialPresent
        this.supportsSharedTexture = supportsSharedTexture
        this.supportsExtendedDynamicRange = supportsExtendedDynamicRange
        this.maxDeclaredResourceBytes = maxDeclaredResourceBytes
    }
}

protected enum FrameRedrawMode <: Equatable<FrameRedrawMode> {
    | Skipped
    | Bounded
    | Full

    public operator func ==(other: FrameRedrawMode): Bool {
        frameRedrawModeName(this) == frameRedrawModeName(other)
    }

    public operator func !=(other: FrameRedrawMode): Bool { !(this == other) }
}

protected func frameRedrawModeName(value: FrameRedrawMode): String {
    match (value) {
        case FrameRedrawMode.Skipped => "none"
        case FrameRedrawMode.Bounded => "bounded"
        case FrameRedrawMode.Full => "full"
    }
}

protected enum FramePresentMode <: Equatable<FramePresentMode> {
    | NotPresented
    | Partial
    | Full

    public operator func ==(other: FramePresentMode): Bool {
        framePresentModeName(this) == framePresentModeName(other)
    }

    public operator func !=(other: FramePresentMode): Bool { !(this == other) }
}

protected func framePresentModeName(value: FramePresentMode): String {
    match (value) {
        case FramePresentMode.NotPresented => "none"
        case FramePresentMode.Partial => "partial"
        case FramePresentMode.Full => "full"
    }
}

/**
 * Provider-neutral strategy behind the redraw/present pair. `PreservedBufferBounded`
 * deliberately still maps to a full platform present when the provider can preserve
 * prior pixels but cannot submit damage regions (the SDL path). The strategy is
 * execution truth; it never upgrades a provider capability by inference.
 */
protected enum FramePresentStrategy <: Equatable<FramePresentStrategy> {
    | NotPresented
    | FullSurface
    | PreservedBufferBounded
    | IncrementalRegions
    | UnsupportedFallback

    public operator func ==(other: FramePresentStrategy): Bool {
        framePresentStrategyName(this) == framePresentStrategyName(other)
    }

    public operator func !=(other: FramePresentStrategy): Bool { !(this == other) }
}

protected func framePresentStrategyName(value: FramePresentStrategy): String {
    match (value) {
        case FramePresentStrategy.NotPresented => "none"
        case FramePresentStrategy.FullSurface => "full-surface"
        case FramePresentStrategy.PreservedBufferBounded => "preserved-buffer-bounded"
        case FramePresentStrategy.IncrementalRegions => "incremental-regions"
        case FramePresentStrategy.UnsupportedFallback => "unsupported-fallback"
    }
}

private func requireFrameGraphToken(value: String, label: String): Unit {
    if (value.isEmpty() || value.toArray().size > 128) {
        throw IllegalArgumentException(label + " must contain 1..128 ASCII bytes")
    }
    for (r in value.toRuneArray()) {
        let lower = r >= r'a' && r <= r'z'
        let digit = r >= r'0' && r <= r'9'
        if (!lower && !digit && r != r'.' && r != r'-' && r != r'_') {
            throw IllegalArgumentException(label + " accepts lowercase ASCII, digits, dot, dash and underscore")
        }
    }
}
