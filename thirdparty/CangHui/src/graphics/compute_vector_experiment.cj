package chui.graphics

import std.collection.ArrayList

/** Isolated compute-vector experiment. This is not part of the public `chui` surface. */
protected let CANGHUI_COMPUTE_VECTOR_PROTOCOL = "canghui.compute-vector.v0-experiment"
protected let CANGHUI_COMPUTE_VECTOR_PIPELINE_ID = "compute-vector.coverage"
protected let CANGHUI_COMPUTE_VECTOR_WIRE_PROTOCOL = "canghui.compute-vector.wire.v1"

private let COMPUTE_VECTOR_WIRE_MAGIC = "CGCVW001"
private let COMPUTE_VECTOR_WIRE_SCHEMA: Int64 = 1
private let COMPUTE_VECTOR_WIRE_HEADER_BYTES: Int64 = 120
private let COMPUTE_VECTOR_WIRE_MAX_BYTES: Int64 = 67108864

protected let CANGHUI_COMPUTE_VECTOR_MAX_PATHS: Int64 = 4096
protected let CANGHUI_COMPUTE_VECTOR_MAX_POINTS: Int64 = 262144
protected let CANGHUI_COMPUTE_VECTOR_MAX_PIXELS: Int64 = 16777216
protected let CANGHUI_COMPUTE_VECTOR_MAX_TILE_REFERENCES: Int64 = 4194304
protected let CANGHUI_COMPUTE_VECTOR_MAX_CPU_SAMPLE_TESTS: Int64 = 67108864

protected struct ComputeVectorPoint <: Equatable<ComputeVectorPoint> {
    public let x: Float32
    public let y: Float32

    public init(x: Float32, y: Float32) {
        if (!computeVectorFiniteCoordinate(x) || !computeVectorFiniteCoordinate(y)) {
            throw IllegalArgumentException("compute-vector coordinates must be finite and non-negative")
        }
        this.x = x
        this.y = y
    }

    public operator func ==(other: ComputeVectorPoint): Bool {
        x == other.x && y == other.y
    }

    public operator func !=(other: ComputeVectorPoint): Bool { !(this == other) }
}

protected enum ComputeVectorFillRule <: Equatable<ComputeVectorFillRule> {
    | EvenOdd
    | NonZero

    public operator func ==(other: ComputeVectorFillRule): Bool {
        computeVectorFillRuleName(this) == computeVectorFillRuleName(other)
    }

    public operator func !=(other: ComputeVectorFillRule): Bool { !(this == other) }
}

protected func computeVectorFillRuleName(value: ComputeVectorFillRule): String {
    match (value) {
        case ComputeVectorFillRule.EvenOdd => "even-odd"
        case ComputeVectorFillRule.NonZero => "non-zero"
    }
}

protected class ComputeVectorPath {
    public let id: String
    public let fillRule: ComputeVectorFillRule
    private let points = ArrayList<ComputeVectorPoint>()

    public init(
        id: String,
        values: Array<ComputeVectorPoint>,
        fillRule!: ComputeVectorFillRule = ComputeVectorFillRule.NonZero
    ) {
        let _ = FramePassId(id)
        if (values.size < 3 || values.size > CANGHUI_COMPUTE_VECTOR_MAX_POINTS) {
            throw IllegalArgumentException("compute-vector paths require 3..262144 points")
        }
        this.id = id
        this.fillRule = fillRule
        for (value in values) { points.add(value) }
    }

    public func pointCount(): Int64 { points.size }
    public func pointAt(index: Int64): ComputeVectorPoint { points[index] }
}

protected struct ComputeVectorLimits {
    public let maxPaths: Int64
    public let maxPoints: Int64
    public let maxPixels: Int64
    public let maxTileReferences: Int64
    public let maxCpuSampleTests: Int64

    public init(
        maxPaths!: Int64 = 1024,
        maxPoints!: Int64 = 65536,
        maxPixels!: Int64 = 1048576,
        maxTileReferences!: Int64 = 1048576,
        maxCpuSampleTests!: Int64 = 16777216
    ) {
        if (maxPaths <= 0 || maxPoints <= 0 || maxPixels <= 0 ||
            maxTileReferences <= 0 || maxCpuSampleTests <= 0 ||
            maxPaths > CANGHUI_COMPUTE_VECTOR_MAX_PATHS ||
            maxPoints > CANGHUI_COMPUTE_VECTOR_MAX_POINTS ||
            maxPixels > CANGHUI_COMPUTE_VECTOR_MAX_PIXELS ||
            maxTileReferences > CANGHUI_COMPUTE_VECTOR_MAX_TILE_REFERENCES ||
            maxCpuSampleTests > CANGHUI_COMPUTE_VECTOR_MAX_CPU_SAMPLE_TESTS) {
            throw IllegalArgumentException("compute-vector limits are outside framework hard bounds")
        }
        this.maxPaths = maxPaths
        this.maxPoints = maxPoints
        this.maxPixels = maxPixels
        this.maxTileReferences = maxTileReferences
        this.maxCpuSampleTests = maxCpuSampleTests
    }
}

/** Immutable scene; `cacheKey` is a diagnostic hint, never a correctness identity. */
protected class ComputeVectorScene {
    public let id: String
    public let width: Int64
    public let height: Int64
    public let tileSize: Int64
    public let totalPoints: Int64
    public let cacheKey: String
    private let identity: String
    private let paths = ArrayList<ComputeVectorPath>()

    public init(
        id: String,
        width: Int64,
        height: Int64,
        values: Array<ComputeVectorPath>,
        tileSize!: Int64 = 16,
        limits!: ComputeVectorLimits = ComputeVectorLimits()
    ) {
        let _ = FramePassId(id)
        if (width <= 0 || height <= 0 || tileSize <= 0 || tileSize > 1024) {
            throw IllegalArgumentException("compute-vector scene geometry is invalid")
        }
        let pixels = computeVectorBoundedProduct(width, height, limits.maxPixels)
        if (pixels < 0 || values.size <= 0 || values.size > limits.maxPaths) {
            throw IllegalArgumentException("compute-vector scene exceeds pixel or path limits")
        }
        var pointCount: Int64 = 0
        for (path in values) {
            if (path.pointCount() > limits.maxPoints - pointCount) {
                throw IllegalArgumentException("compute-vector scene exceeds point limits")
            }
            for (i in 0..path.pointCount()) {
                let point = path.pointAt(i)
                if (point.x > Float32(width) || point.y > Float32(height)) {
                    throw IllegalArgumentException("compute-vector points must stay inside the scene")
                }
            }
            pointCount += path.pointCount()
            paths.add(path)
        }
        this.id = id
        this.width = width
        this.height = height
        this.tileSize = tileSize
        this.totalPoints = pointCount
        this.identity = renderComputeVectorIdentity(id, width, height, tileSize, paths)
        this.cacheKey = "cgcv-v0-hint-${computeVectorStableHint(this.identity)}"
    }

    public func pathCount(): Int64 { paths.size }
    public func pathAt(index: Int64): ComputeVectorPath { paths[index] }
    public func pixelCount(): Int64 { width * height }
    /** Exact canonical source identity. The bounded `cacheKey` is never used for correctness. */
    public func exactIdentity(): String { identity }
}

/** One closed-path edge copied out of the source scene. */
protected struct ComputeVectorSegment {
    public let pathIndex: Int64
    public let first: ComputeVectorPoint
    public let second: ComputeVectorPoint

    public init(pathIndex: Int64, first: ComputeVectorPoint, second: ComputeVectorPoint) {
        this.pathIndex = pathIndex
        this.first = first
        this.second = second
    }
}

/** One bounded tile bin. Segment references are immutable after lowering completes. */
protected class ComputeVectorTileBin {
    public let column: Int64
    public let row: Int64
    private let segmentReferences = ArrayList<Int64>()

    init(column: Int64, row: Int64) {
        this.column = column
        this.row = row
    }

    func addSegment(value: Int64): Unit { segmentReferences.add(value) }
    public func segmentReferenceCount(): Int64 { segmentReferences.size }
    public func segmentReferenceAt(index: Int64): Int64 { segmentReferences[index] }
}

/** Hard-bounded segment and tile payload consumed by compute or the independent tiled oracle. */
protected class ComputeVectorLoweredScene {
    public let width: Int64
    public let height: Int64
    public let tileSize: Int64
    public let tileColumns: Int64
    public let tileRows: Int64
    public let tileReferenceCount: Int64
    public let sourceCacheHint: String
    public let sourceIdentity: String
    private let segments = ArrayList<ComputeVectorSegment>()
    private let bins = ArrayList<ComputeVectorTileBin>()
    private let fillRules = ArrayList<ComputeVectorFillRule>()

    init(
        scene: ComputeVectorScene,
        segmentValues: ArrayList<ComputeVectorSegment>,
        binValues: ArrayList<ComputeVectorTileBin>,
        ruleValues: ArrayList<ComputeVectorFillRule>,
        columns: Int64,
        rows: Int64,
        references: Int64
    ) {
        this.width = scene.width
        this.height = scene.height
        this.tileSize = scene.tileSize
        this.tileColumns = columns
        this.tileRows = rows
        this.tileReferenceCount = references
        this.sourceCacheHint = scene.cacheKey
        this.sourceIdentity = scene.exactIdentity()
        for (value in segmentValues) { segments.add(value) }
        for (value in binValues) { bins.add(value) }
        for (value in ruleValues) { fillRules.add(value) }
    }

    public func segmentCount(): Int64 { segments.size }
    public func segmentAt(index: Int64): ComputeVectorSegment { segments[index] }
    public func tileCount(): Int64 { bins.size }
    public func tileAt(column: Int64, row: Int64): ComputeVectorTileBin {
        if (column < 0 || row < 0 || column >= tileColumns || row >= tileRows) {
            throw IllegalArgumentException("compute-vector tile coordinate is invalid")
        }
        bins[row * tileColumns + column]
    }
    public func pathCount(): Int64 { fillRules.size }
    public func fillRuleAt(pathIndex: Int64): ComputeVectorFillRule { fillRules[pathIndex] }
    public func pixelCount(): Int64 { width * height }
}

/**
 * Exact packed provider ABI. Layout (all integers little-endian Int64):
 *
 * - 120-byte header: magic, schema, total bytes, geometry/counts, source-identity bytes,
 *   then segment/tile/reference/fill-rule section offsets;
 * - exact UTF-8 source identity;
 * - variable segment records: pathIndex and four length-prefixed canonical Float32 strings;
 * - fixed tile records: flattened-reference offset and count;
 * - flattened Int64 segment references;
 * - Int64 fill-rule codes (`0` even-odd, `1` non-zero).
 *
 * Coordinates use canonical Float32 strings because Cangjie does not expose a portable safe
 * bit-cast here. Length prefixes keep the wire unambiguous and round-trip exact for Float32.
 */
protected class ComputeVectorPackedWire {
    public let protocol: String
    public let schemaVersion: Int64
    public let sourceIdentity: String
    public let segmentOffset: Int64
    public let tileOffset: Int64
    public let referenceOffset: Int64
    public let fillRuleOffset: Int64
    public let segmentCount: Int64
    public let tileCount: Int64
    public let referenceCount: Int64
    public let pathCount: Int64
    public let contentHint: String
    private let bytes: Array<UInt8>

    init(
        sourceIdentity: String,
        segmentOffset: Int64,
        tileOffset: Int64,
        referenceOffset: Int64,
        fillRuleOffset: Int64,
        segmentCount: Int64,
        tileCount: Int64,
        referenceCount: Int64,
        pathCount: Int64,
        values: Array<UInt8>
    ) {
        this.protocol = CANGHUI_COMPUTE_VECTOR_WIRE_PROTOCOL
        this.schemaVersion = COMPUTE_VECTOR_WIRE_SCHEMA
        this.sourceIdentity = sourceIdentity
        this.segmentOffset = segmentOffset
        this.tileOffset = tileOffset
        this.referenceOffset = referenceOffset
        this.fillRuleOffset = fillRuleOffset
        this.segmentCount = segmentCount
        this.tileCount = tileCount
        this.referenceCount = referenceCount
        this.pathCount = pathCount
        this.bytes = values
        this.contentHint = "cgcv-wire-v1-hint-${computeVectorStableByteHint(values)}-${values.size}"
    }

    public func byteCount(): Int64 { bytes.size }
    public func borrowedBytes(): Array<UInt8> { bytes.clone() }

    /** Correctness identity is exact metadata plus byte-for-byte payload equality. */
    public func exactlyMatches(other: ComputeVectorPackedWire): Bool {
        if (protocol != other.protocol || schemaVersion != other.schemaVersion ||
            sourceIdentity != other.sourceIdentity || segmentOffset != other.segmentOffset ||
            tileOffset != other.tileOffset || referenceOffset != other.referenceOffset ||
            fillRuleOffset != other.fillRuleOffset || segmentCount != other.segmentCount ||
            tileCount != other.tileCount || referenceCount != other.referenceCount ||
            pathCount != other.pathCount || bytes.size != other.bytes.size) {
            return false
        }
        for (i in 0..bytes.size) {
            if (bytes[i] != other.bytes[i]) { return false }
        }
        true
    }
}

/** Packs every lowered input consumed by the compute command into one checked wire buffer. */
protected func packComputeVectorLoweredScene(lowered: ComputeVectorLoweredScene): ComputeVectorPackedWire {
    let identityBytes = lowered.sourceIdentity.toArray()
    var segmentBytes: Int64 = 0
    for (i in 0..lowered.segmentCount()) {
        let segment = lowered.segmentAt(i)
        segmentBytes = computeVectorCheckedWireAdd(segmentBytes, 8)
        segmentBytes = computeVectorCheckedWireAdd(
            segmentBytes, computeVectorCoordinateWireByteCount(segment.first.x))
        segmentBytes = computeVectorCheckedWireAdd(
            segmentBytes, computeVectorCoordinateWireByteCount(segment.first.y))
        segmentBytes = computeVectorCheckedWireAdd(
            segmentBytes, computeVectorCoordinateWireByteCount(segment.second.x))
        segmentBytes = computeVectorCheckedWireAdd(
            segmentBytes, computeVectorCoordinateWireByteCount(segment.second.y))
    }
    let tileCount = computeVectorBoundedProduct(
        lowered.tileColumns, lowered.tileRows, CANGHUI_COMPUTE_VECTOR_MAX_PIXELS)
    if (tileCount < 0 || tileCount != lowered.tileCount()) {
        throw IllegalArgumentException("compute-vector wire tile count is invalid")
    }
    let tileBytes = computeVectorCheckedWireProduct(tileCount, 16)
    let referenceBytes = computeVectorCheckedWireProduct(lowered.tileReferenceCount, 8)
    let fillRuleBytes = computeVectorCheckedWireProduct(lowered.pathCount(), 8)

    let identityOffset = COMPUTE_VECTOR_WIRE_HEADER_BYTES
    let segmentOffset = computeVectorCheckedWireAdd(identityOffset, identityBytes.size)
    let tileOffset = computeVectorCheckedWireAdd(segmentOffset, segmentBytes)
    let referenceOffset = computeVectorCheckedWireAdd(tileOffset, tileBytes)
    let fillRuleOffset = computeVectorCheckedWireAdd(referenceOffset, referenceBytes)
    let totalBytes = computeVectorCheckedWireAdd(fillRuleOffset, fillRuleBytes)
    let writer = ComputeVectorWireWriter(totalBytes)
    writer.writeRawBytes(COMPUTE_VECTOR_WIRE_MAGIC.toArray())
    writer.writeInt64(COMPUTE_VECTOR_WIRE_SCHEMA)
    writer.writeInt64(totalBytes)
    writer.writeInt64(lowered.width)
    writer.writeInt64(lowered.height)
    writer.writeInt64(lowered.tileSize)
    writer.writeInt64(lowered.pathCount())
    writer.writeInt64(lowered.segmentCount())
    writer.writeInt64(tileCount)
    writer.writeInt64(lowered.tileReferenceCount)
    writer.writeInt64(identityBytes.size)
    writer.writeInt64(segmentOffset)
    writer.writeInt64(tileOffset)
    writer.writeInt64(referenceOffset)
    writer.writeInt64(fillRuleOffset)
    writer.writeRawBytes(identityBytes)

    for (i in 0..lowered.segmentCount()) {
        let segment = lowered.segmentAt(i)
        writer.writeInt64(segment.pathIndex)
        writer.writeCoordinate(segment.first.x)
        writer.writeCoordinate(segment.first.y)
        writer.writeCoordinate(segment.second.x)
        writer.writeCoordinate(segment.second.y)
    }
    var flattenedReferenceOffset: Int64 = 0
    for (row in 0..lowered.tileRows) {
        for (column in 0..lowered.tileColumns) {
            let tile = lowered.tileAt(column, row)
            writer.writeInt64(flattenedReferenceOffset)
            writer.writeInt64(tile.segmentReferenceCount())
            flattenedReferenceOffset += tile.segmentReferenceCount()
        }
    }
    if (flattenedReferenceOffset != lowered.tileReferenceCount) {
        throw IllegalArgumentException("compute-vector wire reference count is inconsistent")
    }
    for (row in 0..lowered.tileRows) {
        for (column in 0..lowered.tileColumns) {
            let tile = lowered.tileAt(column, row)
            for (i in 0..tile.segmentReferenceCount()) {
                writer.writeInt64(tile.segmentReferenceAt(i))
            }
        }
    }
    for (i in 0..lowered.pathCount()) {
        writer.writeInt64(match (lowered.fillRuleAt(i)) {
            case ComputeVectorFillRule.EvenOdd => 0
            case ComputeVectorFillRule.NonZero => 1
        })
    }
    ComputeVectorPackedWire(
        lowered.sourceIdentity, segmentOffset, tileOffset, referenceOffset, fillRuleOffset,
        lowered.segmentCount(), tileCount, lowered.tileReferenceCount, lowered.pathCount(),
        writer.finish())
}

protected class ComputeVectorLoweringResult {
    public let ok: Bool
    public let code: String
    private let value: ?ComputeVectorLoweredScene

    private init(ok: Bool, code: String, value: ?ComputeVectorLoweredScene) {
        this.ok = ok
        this.code = code
        this.value = value
    }

    public static func accepted(value: ComputeVectorLoweredScene): ComputeVectorLoweringResult {
        ComputeVectorLoweringResult(true, "lowered", Some(value))
    }

    public static func rejected(code: String): ComputeVectorLoweringResult {
        ComputeVectorLoweringResult(false, code, None)
    }

    public func lowered(): ?ComputeVectorLoweredScene { value }
}

/**
 * Paths are copied into closed segments and binned for a left-to-right crossing test.
 * A segment is referenced by every tile to the left of its maximum x and every row it spans;
 * this is conservative, bounded, and preserves winding/parity correctness.
 */
protected func lowerComputeVectorScene(
    scene: ComputeVectorScene,
    limits!: ComputeVectorLimits = ComputeVectorLimits()
): ComputeVectorLoweringResult {
    if (scene.pathCount() > limits.maxPaths || scene.totalPoints > limits.maxPoints ||
        scene.pixelCount() > limits.maxPixels) {
        return ComputeVectorLoweringResult.rejected("scene-outside-lowering-limits")
    }
    let columns = (scene.width + scene.tileSize - 1) / scene.tileSize
    let rows = (scene.height + scene.tileSize - 1) / scene.tileSize
    let tileCount = computeVectorBoundedProduct(columns, rows, limits.maxPixels)
    if (tileCount < 0) {
        return ComputeVectorLoweringResult.rejected("tile-count-overflow")
    }

    let bins = ArrayList<ComputeVectorTileBin>()
    for (row in 0..rows) {
        for (column in 0..columns) { bins.add(ComputeVectorTileBin(column, row)) }
    }
    let segments = ArrayList<ComputeVectorSegment>()
    let rules = ArrayList<ComputeVectorFillRule>()
    var references: Int64 = 0
    for (pathIndex in 0..scene.pathCount()) {
        let path = scene.pathAt(pathIndex)
        rules.add(path.fillRule)
        var previous = path.pointAt(path.pointCount() - 1)
        for (pointIndex in 0..path.pointCount()) {
            let current = path.pointAt(pointIndex)
            let segmentIndex = segments.size
            segments.add(ComputeVectorSegment(pathIndex, previous, current))

            let minY = min(previous.y, current.y)
            let maxY = max(previous.y, current.y)
            let maxX = max(previous.x, current.x)
            let firstRow = min(rows - 1, Int64(minY) / scene.tileSize)
            let lastRow = min(rows - 1, Int64(maxY) / scene.tileSize)
            let lastColumn = min(columns - 1, Int64(maxX) / scene.tileSize)
            for (row in firstRow..(lastRow + 1)) {
                for (column in 0..(lastColumn + 1)) {
                    if (references >= limits.maxTileReferences) {
                        return ComputeVectorLoweringResult.rejected("tile-reference-overflow")
                    }
                    bins[row * columns + column].addSegment(segmentIndex)
                    references += 1
                }
            }
            previous = current
        }
    }
    ComputeVectorLoweringResult.accepted(
        ComputeVectorLoweredScene(scene, segments, bins, rules, columns, rows, references))
}

protected enum ComputeVectorPlanMode <: Equatable<ComputeVectorPlanMode> {
    | ComputeCandidate
    | CpuFallback
    | Rejected

    public operator func ==(other: ComputeVectorPlanMode): Bool {
        computeVectorPlanModeName(this) == computeVectorPlanModeName(other)
    }

    public operator func !=(other: ComputeVectorPlanMode): Bool { !(this == other) }
}

protected func computeVectorPlanModeName(value: ComputeVectorPlanMode): String {
    match (value) {
        case ComputeVectorPlanMode.ComputeCandidate => "compute-candidate"
        case ComputeVectorPlanMode.CpuFallback => "cpu-fallback"
        case ComputeVectorPlanMode.Rejected => "rejected"
    }
}

/** Planning proves eligibility only; it never claims that a GPU command executed. */
protected struct ComputeVectorPlan {
    public let mode: ComputeVectorPlanMode
    public let code: String
    public let segmentCount: Int64
    public let tileReferenceCount: Int64
    public let cacheHint: String
    public let sceneIdentity: String
    private let packedWire: ?ComputeVectorPackedWire

    public init(
        mode: ComputeVectorPlanMode,
        code: String,
        segmentCount: Int64,
        tileReferenceCount: Int64,
        cacheHint: String,
        sceneIdentity: String,
        packedWire: ?ComputeVectorPackedWire
    ) {
        this.mode = mode
        this.code = code
        this.segmentCount = segmentCount
        this.tileReferenceCount = tileReferenceCount
        this.cacheHint = cacheHint
        this.sceneIdentity = sceneIdentity
        this.packedWire = packedWire
    }

    public func isComputeCandidate(): Bool { mode == ComputeVectorPlanMode.ComputeCandidate }
    public func canRender(): Bool { mode != ComputeVectorPlanMode.Rejected }
    public func wire(): ?ComputeVectorPackedWire { packedWire }
}

/** Capability and lowering overflow checks happen before any GPU buffer allocation. */
protected func planComputeVector(
    scene: ComputeVectorScene,
    adapter: GraphicsAdapterCapabilities,
    limits!: ComputeVectorLimits = ComputeVectorLimits()
): ComputeVectorPlan {
    let lowering = lowerComputeVectorScene(scene, limits: limits)
    if (!lowering.ok) {
        let fallback = lowering.code == "tile-reference-overflow"
        if (fallback && !computeVectorCpuOracleFits(scene, limits)) {
            return ComputeVectorPlan(
                ComputeVectorPlanMode.Rejected, "cpu-fallback-operation-limit-exceeded",
                scene.totalPoints, 0, scene.cacheKey, scene.exactIdentity(), None)
        }
        return ComputeVectorPlan(
            if (fallback) { ComputeVectorPlanMode.CpuFallback } else {
                ComputeVectorPlanMode.Rejected
            },
            lowering.code, scene.totalPoints, 0, scene.cacheKey, scene.exactIdentity(), None)
    }
    let lowered = lowering.lowered().getOrThrow()
    let wire = packComputeVectorLoweredScene(lowered)
    if (!adapter.has(GraphicsCapability.ComputePipeline) ||
        !adapter.has(GraphicsCapability.StorageBuffer)) {
        if (!computeVectorCpuOracleFits(scene, limits)) {
            return ComputeVectorPlan(
                ComputeVectorPlanMode.Rejected, "cpu-fallback-operation-limit-exceeded",
                lowered.segmentCount(), lowered.tileReferenceCount, scene.cacheKey,
                scene.exactIdentity(), Some(wire))
        }
        return ComputeVectorPlan(
            ComputeVectorPlanMode.CpuFallback, "compute-capability-unavailable",
            lowered.segmentCount(), lowered.tileReferenceCount, scene.cacheKey,
            scene.exactIdentity(), Some(wire))
    }
    ComputeVectorPlan(
        ComputeVectorPlanMode.ComputeCandidate, "compute-candidate",
        lowered.segmentCount(), lowered.tileReferenceCount, scene.cacheKey,
        scene.exactIdentity(), Some(wire))
}

protected class ComputeVectorCoverage {
    public let width: Int64
    public let height: Int64
    private let values: Array<UInt8>

    public init(width: Int64, height: Int64, values: Array<UInt8>) {
        if (width <= 0 || height <= 0 ||
            computeVectorBoundedProduct(width, height, CANGHUI_COMPUTE_VECTOR_MAX_PIXELS) != values.size) {
            throw IllegalArgumentException("compute-vector coverage payload is invalid")
        }
        this.width = width
        this.height = height
        this.values = values.clone()
    }

    public func coverageAt(x: Int64, y: Int64): UInt8 {
        if (x < 0 || y < 0 || x >= width || y >= height) {
            throw IllegalArgumentException("compute-vector coverage coordinate is outside the scene")
        }
        values[y * width + x]
    }

    public func borrowedBytes(): Array<UInt8> { values.clone() }
}

/** Fixed 2x2 whole-scene oracle retained as the independent reference implementation. */
protected func renderComputeVectorCpuOracle(
    scene: ComputeVectorScene,
    limits!: ComputeVectorLimits = ComputeVectorLimits()
): ComputeVectorCoverage {
    if (scene.pixelCount() > limits.maxPixels) {
        throw IllegalArgumentException("compute-vector CPU oracle pixel limit exceeded")
    }
    if (!computeVectorCpuOracleFits(scene, limits)) {
        throw IllegalArgumentException("compute-vector CPU oracle operation limit exceeded")
    }

    let bytes = Array<UInt8>(scene.pixelCount(), repeat: 0)
    for (y in 0..scene.height) {
        for (x in 0..scene.width) {
            bytes[y * scene.width + x] = computeVectorFourSampleCoverage(
                x, y, {sampleX, sampleY =>
                    computeVectorPointInsideScene(scene, sampleX, sampleY)})
        }
    }
    ComputeVectorCoverage(scene.width, scene.height, bytes)
}

/** Proves the fixed four-sample whole-scene cost before selecting a CPU fallback. */
private func computeVectorCpuOracleFits(
    scene: ComputeVectorScene,
    limits: ComputeVectorLimits
): Bool {
    let pointTests = computeVectorBoundedProduct(
        scene.pixelCount(), scene.totalPoints, limits.maxCpuSampleTests / 4)
    pointTests >= 0
}

/**
 * Independent conformance executor. It consumes only lowered segments/tile bins and never reads
 * source paths, so agreement with the whole-scene oracle catches lowering/binning defects.
 */
protected func renderComputeVectorTiledConformance(
    lowered: ComputeVectorLoweredScene,
    limits!: ComputeVectorLimits = ComputeVectorLimits()
): ComputeVectorCoverage {
    if (lowered.pixelCount() > limits.maxPixels ||
        lowered.tileReferenceCount > limits.maxTileReferences) {
        throw IllegalArgumentException("compute-vector tiled conformance limits exceeded")
    }
    let tilePixels = computeVectorBoundedProduct(
        lowered.tileSize, lowered.tileSize, limits.maxPixels)
    let referencePixelTests = computeVectorBoundedProduct(
        lowered.tileReferenceCount, tilePixels, limits.maxCpuSampleTests / 4)
    let allPathTests = computeVectorBoundedProduct(
        referencePixelTests, lowered.pathCount(), limits.maxCpuSampleTests / 4)
    if (tilePixels < 0 || referencePixelTests < 0 || allPathTests < 0) {
        throw IllegalArgumentException("compute-vector tiled conformance operation limit exceeded")
    }

    let bytes = Array<UInt8>(lowered.pixelCount(), repeat: 0)
    for (y in 0..lowered.height) {
        for (x in 0..lowered.width) {
            let bin = lowered.tileAt(x / lowered.tileSize, y / lowered.tileSize)
            bytes[y * lowered.width + x] = computeVectorFourSampleCoverage(
                x, y, {sampleX, sampleY =>
                    computeVectorPointInsideLowered(lowered, bin, sampleX, sampleY)})
        }
    }
    ComputeVectorCoverage(lowered.width, lowered.height, bytes)
}

protected enum ComputeVectorActualExecution <: Equatable<ComputeVectorActualExecution> {
    | NotExecuted
    | TiledSoftware
    | ProviderGpu

    public operator func ==(other: ComputeVectorActualExecution): Bool {
        computeVectorActualExecutionName(this) == computeVectorActualExecutionName(other)
    }

    public operator func !=(other: ComputeVectorActualExecution): Bool { !(this == other) }
}

protected func computeVectorActualExecutionName(value: ComputeVectorActualExecution): String {
    match (value) {
        case ComputeVectorActualExecution.NotExecuted => "not-executed"
        case ComputeVectorActualExecution.TiledSoftware => "tiled-software"
        case ComputeVectorActualExecution.ProviderGpu => "provider-gpu"
    }
}

protected struct ComputeVectorExecutionReceipt {
    public let computeCandidate: Bool
    public let actualExecution: ComputeVectorActualExecution
    public let conformancePassed: Bool
    public let mismatchCount: Int64
    public let code: String
    public let providerId: String
    private let gpuProofAccepted: Bool

    public init(
        computeCandidate: Bool,
        actualExecution: ComputeVectorActualExecution,
        conformancePassed: Bool,
        mismatchCount: Int64,
        code: String,
        providerId: String,
        gpuProofAccepted: Bool
    ) {
        this.computeCandidate = computeCandidate
        this.actualExecution = actualExecution
        this.conformancePassed = conformancePassed
        this.mismatchCount = mismatchCount
        this.code = code
        this.providerId = providerId
        this.gpuProofAccepted = gpuProofAccepted
    }

    public func gpuActuallyExecuted(): Bool {
        actualExecution == ComputeVectorActualExecution.ProviderGpu && gpuProofAccepted
    }

    public func accepted(): Bool {
        actualExecution != ComputeVectorActualExecution.NotExecuted && conformancePassed &&
            (actualExecution != ComputeVectorActualExecution.ProviderGpu || gpuProofAccepted)
    }
}

/** Provider evidence tying one completed dispatch to exact device, pipeline, graph, and wire. */
protected class ComputeVectorGpuCommandProof {
    public let commandId: String
    public let deviceIdentity: String
    public let capabilityGeneration: Int64
    public let backend: GraphicsBackend
    public let surfaceKey: String
    public let surfaceGeneration: Int64
    public let frameId: Int64
    public let passId: String
    public let workgroupCountX: Int64
    public let workgroupCountY: Int64
    public let completed: Bool
    public let pipelineArtifact: PortableGpuPipelineArtifact
    public let submittedWire: ComputeVectorPackedWire

    public init(
        commandId: String,
        deviceIdentity: String,
        capabilityGeneration: Int64,
        backend: GraphicsBackend,
        surfaceKey: String,
        surfaceGeneration: Int64,
        frameId: Int64,
        passId: String,
        workgroupCountX: Int64,
        workgroupCountY: Int64,
        completed: Bool,
        pipelineArtifact: PortableGpuPipelineArtifact,
        submittedWire: ComputeVectorPackedWire
    ) {
        let _ = FramePassId(commandId)
        let _ = FramePassId(deviceIdentity)
        let _ = FramePassId(surfaceKey)
        let _ = FramePassId(passId)
        if (capabilityGeneration <= 0 || surfaceGeneration <= 0 || frameId <= 0 ||
            workgroupCountX <= 0 || workgroupCountY <= 0 || backend == GraphicsBackend.Software) {
            throw IllegalArgumentException("compute-vector GPU command proof is invalid")
        }
        this.commandId = commandId
        this.deviceIdentity = deviceIdentity
        this.capabilityGeneration = capabilityGeneration
        this.backend = backend
        this.surfaceKey = surfaceKey
        this.surfaceGeneration = surfaceGeneration
        this.frameId = frameId
        this.passId = passId
        this.workgroupCountX = workgroupCountX
        this.workgroupCountY = workgroupCountY
        this.completed = completed
        this.pipelineArtifact = pipelineArtifact
        this.submittedWire = submittedWire
    }
}

protected struct ComputeVectorProviderResult {
    public let ok: Bool
    public let code: String
    public let coverage: ComputeVectorCoverage
    private let commandProof: ?ComputeVectorGpuCommandProof

    public init(
        ok: Bool,
        code: String,
        coverage: ComputeVectorCoverage,
        commandProof!: ?ComputeVectorGpuCommandProof = None
    ) {
        if (code.isEmpty()) {
            throw IllegalArgumentException("compute-vector provider result code is required")
        }
        this.ok = ok
        this.code = code
        this.coverage = coverage
        this.commandProof = commandProof
    }

    public func proof(): ?ComputeVectorGpuCommandProof { commandProof }
}

/** Provider SPI: immutable device truth and one exact packed-wire command boundary. */
protected interface ComputeVectorGpuProvider {
    func identity(): String
    func snapshot(): PortableGpuDeviceSnapshot
    func execute(
        graph: FrameGraph,
        wire: ComputeVectorPackedWire,
        pack: PortableGpuPipelinePack
    ): ComputeVectorProviderResult
}

protected func verifyComputeVectorCoverage(
    plan: ComputeVectorPlan,
    expected: ComputeVectorCoverage,
    actual: ComputeVectorCoverage,
    execution: ComputeVectorActualExecution,
    providerId!: String = ""
): ComputeVectorExecutionReceipt {
    // The general verifier cannot mint a GPU receipt. Only the proof-gated execution path can.
    if (execution == ComputeVectorActualExecution.ProviderGpu) {
        return ComputeVectorExecutionReceipt(
            plan.isComputeCandidate(), ComputeVectorActualExecution.NotExecuted,
            false, 0, "invalid-gpu-execution-claim", providerId, false)
    }
    verifyComputeVectorCoverageAfterProof(
        plan, expected, actual, execution, providerId, false)
}

private func verifyComputeVectorCoverageAfterProof(
    plan: ComputeVectorPlan,
    expected: ComputeVectorCoverage,
    actual: ComputeVectorCoverage,
    execution: ComputeVectorActualExecution,
    providerId: String,
    gpuProofAccepted: Bool
): ComputeVectorExecutionReceipt {
    if (execution == ComputeVectorActualExecution.NotExecuted) {
        return ComputeVectorExecutionReceipt(
            plan.isComputeCandidate(), execution, false, 0, "not-executed", providerId, false)
    }
    if (execution == ComputeVectorActualExecution.ProviderGpu &&
        (!plan.isComputeCandidate() || providerId.isEmpty() || !gpuProofAccepted)) {
        return ComputeVectorExecutionReceipt(
            plan.isComputeCandidate(), ComputeVectorActualExecution.NotExecuted,
            false, 0, "invalid-gpu-execution-claim", providerId, false)
    }
    if (expected.width != actual.width || expected.height != actual.height) {
        return ComputeVectorExecutionReceipt(
            plan.isComputeCandidate(), execution, false, 0, "coverage-shape-mismatch", providerId,
            gpuProofAccepted)
    }
    let expectedBytes = expected.borrowedBytes()
    let actualBytes = actual.borrowedBytes()
    var mismatches: Int64 = 0
    for (i in 0..expectedBytes.size) {
        if (expectedBytes[i] != actualBytes[i]) { mismatches += 1 }
    }
    ComputeVectorExecutionReceipt(
        plan.isComputeCandidate(), execution, mismatches == 0, mismatches,
        if (mismatches == 0) {
            if (execution == ComputeVectorActualExecution.ProviderGpu) {
                "provider-gpu-conformant"
            } else {
                "tiled-software-conformant"
            }
        } else {
            "coverage-mismatch"
        },
        providerId, gpuProofAccepted)
}

/**
 * GPU claims require compatible device truth plus exact pipeline/graph/wire command evidence.
 * Final correctness is always compared with the original whole-scene oracle, never lowered bins.
 */
protected func executeComputeVectorGpuCandidate(
    scene: ComputeVectorScene,
    lowered: ComputeVectorLoweredScene,
    plan: ComputeVectorPlan,
    pack: PortableGpuPipelinePack,
    backend: GraphicsBackend,
    surfaceGeneration: Int64,
    frameId: Int64,
    provider: ComputeVectorGpuProvider,
    limits!: ComputeVectorLimits = ComputeVectorLimits()
): ComputeVectorExecutionReceipt {
    if (!plan.isComputeCandidate()) {
        return ComputeVectorExecutionReceipt(
            false, ComputeVectorActualExecution.NotExecuted, false, 0,
            "not-a-compute-candidate", provider.identity(), false)
    }
    let _ = FramePassId(provider.identity())
    let inputReceipt = validateComputeVectorExactInputs(scene, lowered, plan)
    if (!inputReceipt.ok) {
        return ComputeVectorExecutionReceipt(
            true, ComputeVectorActualExecution.NotExecuted, false, 0,
            inputReceipt.code, provider.identity(), false)
    }
    let wire = plan.wire().getOrThrow()
    let graph = buildComputeVectorFrameGraph(
        scene, lowered, plan, pack, backend, surfaceGeneration, frameId)
    let snapshot = provider.snapshot()
    let compiled = compileFrameGraph(
        graph, FrameGraphCompilerState(), snapshot.executorCapabilities)
    if (!compiled.ok) {
        return ComputeVectorExecutionReceipt(
            true, ComputeVectorActualExecution.NotExecuted, false, 0,
            "provider-graph-rejected:" + compiled.code, provider.identity(), false)
    }
    let compatibility = validatePortableGpuExecution(
        compiled.graph().getOrThrow(), snapshot, pack)
    if (!compatibility.ok) {
        return ComputeVectorExecutionReceipt(
            true, ComputeVectorActualExecution.NotExecuted, false, 0,
            "provider-device-rejected:" + compatibility.code, provider.identity(), false)
    }
    let result = provider.execute(graph, wire, pack)
    if (!result.ok) {
        return ComputeVectorExecutionReceipt(
            true, ComputeVectorActualExecution.NotExecuted, false, 0,
            "provider-execution-failed:" + result.code, provider.identity(), false)
    }
    let proofReceipt = validateComputeVectorGpuCommandProof(
        result.proof(), snapshot, graph, wire, pack, backend)
    if (!proofReceipt.ok) {
        return ComputeVectorExecutionReceipt(
            true, ComputeVectorActualExecution.NotExecuted, false, 0,
            "provider-proof-rejected:" + proofReceipt.code, provider.identity(), false)
    }
    let expected = renderComputeVectorCpuOracle(scene, limits: limits)
    verifyComputeVectorCoverageAfterProof(
        plan, expected, result.coverage, ComputeVectorActualExecution.ProviderGpu,
        provider.identity(), true)
}

/** Lowers a candidate into FrameGraph declarations; this still does not claim GPU execution. */
protected func buildComputeVectorFrameGraph(
    scene: ComputeVectorScene,
    lowered: ComputeVectorLoweredScene,
    plan: ComputeVectorPlan,
    pack: PortableGpuPipelinePack,
    backend: GraphicsBackend,
    surfaceGeneration: Int64,
    frameId: Int64
): FrameGraph {
    if (!plan.isComputeCandidate()) {
        throw IllegalStateException("compute-vector FrameGraph requires a compute candidate")
    }
    let inputReceipt = validateComputeVectorExactInputs(scene, lowered, plan)
    if (!inputReceipt.ok) {
        throw IllegalArgumentException("compute-vector exact input mismatch: " + inputReceipt.code)
    }
    if (!pack.hasArtifact(
        CANGHUI_COMPUTE_VECTOR_PIPELINE_ID, backend, PortableGpuPipelineStage.Compute)) {
        throw IllegalArgumentException("AOT pack lacks the compute-vector pipeline for the selected backend")
    }

    let pipeline = FrameResourceDescriptor(
        FrameResourceId("compute-vector.pipeline", 1), FrameResourceKind.Pipeline,
        FrameResourceLifetime.Imported)
    let wire = plan.wire().getOrThrow()
    let inputWire = FrameResourceDescriptor(
        FrameResourceId("compute-vector.input-wire", 1), FrameResourceKind.Buffer,
        FrameResourceLifetime.Imported, declaredBytes: wire.byteCount())
    let output = FrameResourceDescriptor(
        FrameResourceId("compute-vector.coverage", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent, declaredBytes: scene.pixelCount())
    let pass = FramePassDescriptor(
        FramePassId("compute-vector.rasterize"), 0, FramePassKind.OffscreenComposition,
        reads: [pipeline.id, inputWire.id], writes: [output.id],
        // Diagnostic scheduling hint only; exact scene/wire/pack checks run above.
        stableInputCode: computeVectorStableHint(wire.contentHint + "." + pack.cacheKey))
    FrameGraph(
        "compute-vector", surfaceGeneration, frameId, scene.width, scene.height,
        [pipeline, inputWire, output], [pass])
}

private func validateComputeVectorExactInputs(
    scene: ComputeVectorScene,
    lowered: ComputeVectorLoweredScene,
    plan: ComputeVectorPlan
): PortableGpuCompatibilityReceipt {
    if (scene.exactIdentity() != plan.sceneIdentity ||
        lowered.sourceIdentity != scene.exactIdentity() ||
        lowered.width != scene.width || lowered.height != scene.height ||
        lowered.segmentCount() != plan.segmentCount ||
        lowered.tileReferenceCount != plan.tileReferenceCount) {
        return PortableGpuCompatibilityReceipt(false, "scene-or-lowered-identity-mismatch")
    }
    let plannedWire = match (plan.wire()) {
        case Some(value) => value
        case None => return PortableGpuCompatibilityReceipt(false, "planned-wire-missing")
    }
    let actualWire = packComputeVectorLoweredScene(lowered)
    if (!plannedWire.exactlyMatches(actualWire)) {
        return PortableGpuCompatibilityReceipt(false, "lowered-wire-mismatch")
    }
    PortableGpuCompatibilityReceipt(true, "exact-inputs")
}

private func validateComputeVectorGpuCommandProof(
    value: ?ComputeVectorGpuCommandProof,
    snapshot: PortableGpuDeviceSnapshot,
    graph: FrameGraph,
    wire: ComputeVectorPackedWire,
    pack: PortableGpuPipelinePack,
    backend: GraphicsBackend
): PortableGpuCompatibilityReceipt {
    let proof = match (value) {
        case Some(current) => current
        case None => return PortableGpuCompatibilityReceipt(false, "command-proof-missing")
    }
    if (!proof.completed) {
        return PortableGpuCompatibilityReceipt(false, "command-not-completed")
    }
    if (proof.deviceIdentity != snapshot.identity ||
        proof.capabilityGeneration != snapshot.capabilityGeneration ||
        proof.backend != snapshot.adapter.backend || proof.backend != backend) {
        return PortableGpuCompatibilityReceipt(false, "command-device-mismatch")
    }
    if (!snapshot.adapter.has(GraphicsCapability.ComputePipeline) ||
        !snapshot.adapter.has(GraphicsCapability.StorageBuffer)) {
        return PortableGpuCompatibilityReceipt(false, "command-capability-missing")
    }
    if (proof.surfaceKey != graph.surfaceKey ||
        proof.surfaceGeneration != graph.surfaceGeneration || proof.frameId != graph.frameId ||
        proof.passId != "compute-vector.rasterize") {
        return PortableGpuCompatibilityReceipt(false, "command-graph-mismatch")
    }
    let expectedWorkgroupsX = (graph.surfaceWidth + 7) / 8
    let expectedWorkgroupsY = (graph.surfaceHeight + 7) / 8
    if (proof.workgroupCountX != expectedWorkgroupsX ||
        proof.workgroupCountY != expectedWorkgroupsY) {
        return PortableGpuCompatibilityReceipt(false, "command-dispatch-mismatch")
    }
    if (!proof.submittedWire.exactlyMatches(wire)) {
        return PortableGpuCompatibilityReceipt(false, "command-wire-mismatch")
    }
    let expectedArtifact = match (computeVectorPipelineArtifact(pack, backend)) {
        case Some(value) => value
        case None => return PortableGpuCompatibilityReceipt(false, "command-pipeline-missing")
    }
    if (!proof.pipelineArtifact.exactlyMatches(expectedArtifact)) {
        return PortableGpuCompatibilityReceipt(false, "command-pipeline-mismatch")
    }
    PortableGpuCompatibilityReceipt(true, "command-proof-accepted")
}

private func computeVectorPipelineArtifact(
    pack: PortableGpuPipelinePack,
    backend: GraphicsBackend
): ?PortableGpuPipelineArtifact {
    for (i in 0..pack.artifactCount()) {
        let value = pack.artifactAt(i)
        if (value.id == CANGHUI_COMPUTE_VECTOR_PIPELINE_ID && value.backend == backend &&
            value.stage == PortableGpuPipelineStage.Compute) {
            return Some(value)
        }
    }
    None
}

private func computeVectorFourSampleCoverage(
    x: Int64,
    y: Int64,
    contains: (Float32, Float32) -> Bool
): UInt8 {
    var covered: Int64 = 0
    if (contains(Float32(x) + 0.25, Float32(y) + 0.25)) { covered += 1 }
    if (contains(Float32(x) + 0.75, Float32(y) + 0.25)) { covered += 1 }
    if (contains(Float32(x) + 0.25, Float32(y) + 0.75)) { covered += 1 }
    if (contains(Float32(x) + 0.75, Float32(y) + 0.75)) { covered += 1 }
    UInt8(covered * 255 / 4)
}

private func computeVectorPointInsideScene(scene: ComputeVectorScene, x: Float32, y: Float32): Bool {
    for (pathIndex in 0..scene.pathCount()) {
        if (computeVectorPointInsidePath(scene.pathAt(pathIndex), x, y)) { return true }
    }
    false
}

private func computeVectorPointInsidePath(path: ComputeVectorPath, x: Float32, y: Float32): Bool {
    match (path.fillRule) {
        case ComputeVectorFillRule.EvenOdd => computeVectorEvenOdd(path, x, y)
        case ComputeVectorFillRule.NonZero => computeVectorNonZero(path, x, y)
    }
}

private func computeVectorEvenOdd(path: ComputeVectorPath, x: Float32, y: Float32): Bool {
    var inside = false
    var previous = path.pointAt(path.pointCount() - 1)
    for (i in 0..path.pointCount()) {
        let current = path.pointAt(i)
        if ((current.y > y) != (previous.y > y)) {
            let crossing = (previous.x - current.x) * (y - current.y) /
                (previous.y - current.y) + current.x
            if (x < crossing) { inside = !inside }
        }
        previous = current
    }
    inside
}

private func computeVectorNonZero(path: ComputeVectorPath, x: Float32, y: Float32): Bool {
    var winding: Int64 = 0
    var previous = path.pointAt(path.pointCount() - 1)
    for (i in 0..path.pointCount()) {
        let current = path.pointAt(i)
        let left = (current.x - previous.x) * (y - previous.y) -
            (x - previous.x) * (current.y - previous.y)
        if (previous.y <= y && current.y > y && left > 0.0) {
            winding += 1
        } else if (previous.y > y && current.y <= y && left < 0.0) {
            winding -= 1
        }
        previous = current
    }
    winding != 0
}

private func computeVectorPointInsideLowered(
    lowered: ComputeVectorLoweredScene,
    bin: ComputeVectorTileBin,
    x: Float32,
    y: Float32
): Bool {
    for (pathIndex in 0..lowered.pathCount()) {
        var parity = false
        var winding: Int64 = 0
        for (referenceIndex in 0..bin.segmentReferenceCount()) {
            let segment = lowered.segmentAt(bin.segmentReferenceAt(referenceIndex))
            if (segment.pathIndex != pathIndex) { continue }
            let first = segment.first
            let second = segment.second
            if ((second.y > y) != (first.y > y)) {
                let crossing = (first.x - second.x) * (y - second.y) /
                    (first.y - second.y) + second.x
                if (x < crossing) { parity = !parity }
            }
            let left = (second.x - first.x) * (y - first.y) -
                (x - first.x) * (second.y - first.y)
            if (first.y <= y && second.y > y && left > 0.0) {
                winding += 1
            } else if (first.y > y && second.y <= y && left < 0.0) {
                winding -= 1
            }
        }
        let inside = match (lowered.fillRuleAt(pathIndex)) {
            case ComputeVectorFillRule.EvenOdd => parity
            case ComputeVectorFillRule.NonZero => winding != 0
        }
        if (inside) { return true }
    }
    false
}

private func renderComputeVectorIdentity(
    id: String,
    width: Int64,
    height: Int64,
    tileSize: Int64,
    paths: ArrayList<ComputeVectorPath>
): String {
    let out = StringBuilder()
    out.append(CANGHUI_COMPUTE_VECTOR_PROTOCOL)
    out.append("|")
    out.append(id)
    out.append("|")
    out.append(width.toString())
    out.append("x")
    out.append(height.toString())
    out.append("@")
    out.append(tileSize.toString())
    for (path in paths) {
        out.append("|")
        out.append(path.id)
        out.append(":")
        out.append(computeVectorFillRuleName(path.fillRule))
        for (i in 0..path.pointCount()) {
            let point = path.pointAt(i)
            out.append(":")
            out.append(point.x.toString())
            out.append(",")
            out.append(point.y.toString())
        }
    }
    out.toString()
}

private func computeVectorStableHint(value: String): Int64 {
    var code: Int64 = 31
    for (byte in value.toArray()) {
        code = (code * 131 + Int64(byte)) % 2147483647
    }
    code
}

private func computeVectorStableByteHint(values: Array<UInt8>): Int64 {
    var code: Int64 = 31
    for (value in values) {
        code = (code * 131 + Int64(value)) % 2147483647
    }
    code
}

private func computeVectorCoordinateWireByteCount(value: Float32): Int64 {
    computeVectorCheckedWireAdd(8, value.toString().toArray().size)
}

private func computeVectorCheckedWireAdd(first: Int64, second: Int64): Int64 {
    if (first < 0 || second < 0 || first > COMPUTE_VECTOR_WIRE_MAX_BYTES - second) {
        throw IllegalArgumentException("compute-vector packed wire exceeds its byte bound")
    }
    first + second
}

private func computeVectorCheckedWireProduct(first: Int64, second: Int64): Int64 {
    let value = computeVectorBoundedProduct(first, second, COMPUTE_VECTOR_WIRE_MAX_BYTES)
    if (value < 0) {
        throw IllegalArgumentException("compute-vector packed wire exceeds its byte bound")
    }
    value
}

private class ComputeVectorWireWriter {
    private let bytes: Array<UInt8>
    private var cursor: Int64 = 0

    init(byteCount: Int64) {
        if (byteCount <= 0 || byteCount > COMPUTE_VECTOR_WIRE_MAX_BYTES) {
            throw IllegalArgumentException("compute-vector packed wire allocation is invalid")
        }
        bytes = Array<UInt8>(byteCount, repeat: 0)
    }

    func writeInt64(value: Int64): Unit {
        if (value < 0) {
            throw IllegalArgumentException("compute-vector packed wire integers must be non-negative")
        }
        for (shift in 0..8) {
            writeByte(UInt8((value >> (shift * 8)) & 255))
        }
    }

    func writeCoordinate(value: Float32): Unit {
        let encoded = value.toString().toArray()
        writeInt64(encoded.size)
        writeRawBytes(encoded)
    }

    func writeRawBytes(values: Array<UInt8>): Unit {
        for (value in values) { writeByte(value) }
    }

    private func writeByte(value: UInt8): Unit {
        if (cursor >= bytes.size) {
            throw IllegalStateException("compute-vector packed wire writer overflow")
        }
        bytes[cursor] = value
        cursor += 1
    }

    func finish(): Array<UInt8> {
        if (cursor != bytes.size) {
            throw IllegalStateException("compute-vector packed wire writer size mismatch")
        }
        bytes
    }
}

/** Returns -1 instead of overflowing or exceeding the supplied cap. */
private func computeVectorBoundedProduct(first: Int64, second: Int64, cap: Int64): Int64 {
    if (first < 0 || second < 0 || cap < 0) { return -1 }
    if (first == 0 || second == 0) { return 0 }
    if (first > cap / second) { return -1 }
    first * second
}

private func computeVectorFiniteCoordinate(value: Float32): Bool {
    value >= 0.0 && value <= 1048576.0 && value - value == 0.0
}
