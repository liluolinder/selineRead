package cuic

@When[debug]
import std.collection.{ArrayList, HashSet}

@When[debug]
private let FRAME_REPLAY_TRACE_PROTOCOL = "canghui.frame-trace.v0"
@When[debug]
private let FRAME_GRAPH_PROTOCOL = "canghui.frame-graph.v0"
@When[debug]
private let FRAME_REPLAY_PROTOCOL = "canghui.frame-replay.v0"
@When[debug]
private let FRAME_REPLAY_MAX_BYTES: Int64 = 512 * 1024
@When[debug]
private let FRAME_REPLAY_MAX_FRAMES: Int64 = 64
@When[debug]
private let FRAME_REPLAY_MAX_PASSES: Int64 = 4096
@When[debug]
private let FRAME_REPLAY_MAX_RECTS: Int64 = 4096
@When[debug]
private let FRAME_REPLAY_MAX_EDGES: Int64 = 65536
@When[debug]
private let FRAME_REPLAY_MAX_RESOURCE_BYTES: Int64 = 1073741824
@When[debug]
private class FrameReplayError <: Exception {
    init(code: String) { super(code) }
}

@When[debug]
private class FrameReplayFrame {
    let surface: String
    let surfaceGeneration: Int64
    let frameId: Int64
    let scheduleHash: String
    let executionDurationNs: Int64
    let executionOk: Bool
    let legacyFallbackUsed: Bool

    init(
        surface: String,
        surfaceGeneration: Int64,
        frameId: Int64,
        scheduleHash: String,
        executionDurationNs: Int64,
        executionOk: Bool,
        legacyFallbackUsed: Bool
    ) {
        this.surface = surface
        this.surfaceGeneration = surfaceGeneration
        this.frameId = frameId
        this.scheduleHash = scheduleHash
        this.executionDurationNs = executionDurationNs
        this.executionOk = executionOk
        this.legacyFallbackUsed = legacyFallbackUsed
    }
}

@When[debug]
private class FrameReplaySummary {
    let scenario: String
    let terminalCode: String
    let frames: Array<FrameReplayFrame>

    init(scenario: String, terminalCode: String, frames: Array<FrameReplayFrame>) {
        this.scenario = scenario
        this.terminalCode = terminalCode
        this.frames = frames
    }
}

@When[debug]
private class FrameReplayPass {
    let id: String
    let order: Int64
    let kind: String
    let externalMode: String
    let culled: Bool
    let damageKind: String
    let damageRectangleCount: Int64
    let reads: Array<String>
    let writes: Array<String>
    let dependsOn: Array<String>

    init(
        id: String,
        order: Int64,
        kind: String,
        externalMode: String,
        culled: Bool,
        damageKind: String,
        damageRectangleCount: Int64,
        reads: Array<String>,
        writes: Array<String>,
        dependsOn: Array<String>
    ) {
        this.id = id
        this.order = order
        this.kind = kind
        this.externalMode = externalMode
        this.culled = culled
        this.damageKind = damageKind
        this.damageRectangleCount = damageRectangleCount
        this.reads = reads
        this.writes = writes
        this.dependsOn = dependsOn
    }
}

@When[debug]
private class FrameReplayDamage {
    let kind: String
    let rectangleCount: Int64

    init(kind: String, rectangleCount: Int64) {
        this.kind = kind
        this.rectangleCount = rectangleCount
    }
}

@When[debug]
private class FrameReplaySurfaceState {
    let surface: String
    var surfaceGeneration: Int64
    var frameId: Int64

    init(surface: String, surfaceGeneration: Int64, frameId: Int64) {
        this.surface = surface
        this.surfaceGeneration = surfaceGeneration
        this.frameId = frameId
    }
}

/** Small dependency-free parser for the frozen frame trace schema; it is not a general JSON API. */
@When[debug]
private class FrameReplayJsonCursor {
    private let runes: Array<Rune>
    private var index: Int64 = 0

    init(value: String) { runes = value.toRuneArray() }

    func finish(): Unit {
        skipWhitespace()
        if (index != runes.size) { frameReplayFail("trailing-json") }
    }

    func expect(expected: Rune): Unit {
        skipWhitespace()
        if (index >= runes.size || runes[index] != expected) {
            frameReplayFail("invalid-json")
        }
        index += 1
    }

    func consume(expected: Rune): Bool {
        skipWhitespace()
        if (index < runes.size && runes[index] == expected) {
            index += 1
            return true
        }
        false
    }

    func readString(): String {
        skipWhitespace()
        if (index >= runes.size || runes[index] != r'\"') {
            frameReplayFail("expected-string")
        }
        index += 1
        let out = StringBuilder()
        while (index < runes.size) {
            let value = runes[index]
            index += 1
            if (value == r'\"') { return out.toString() }
            if (UInt32(value) < UInt32(32)) { frameReplayFail("invalid-json-string") }
            if (value != r'\\') {
                out.append(value.toString())
                continue
            }
            if (index >= runes.size) { frameReplayFail("invalid-json-escape") }
            let escaped = runes[index]
            index += 1
            if (escaped == r'\"' || escaped == r'\\' || escaped == r'/') {
                out.append(escaped.toString())
            } else if (escaped == r'b') {
                out.append("\b")
            } else if (escaped == r'f') {
                out.append("\f")
            } else if (escaped == r'n') {
                out.append("\n")
            } else if (escaped == r'r') {
                out.append("\r")
            } else if (escaped == r't') {
                out.append("\t")
            } else {
                // Trace identifiers are bounded ASCII; accepting \u would add ambiguous
                // surrogate handling to this deliberately small debug boundary.
                frameReplayFail("unsupported-json-escape")
            }
        }
        frameReplayFail("unterminated-json-string")
        ""
    }

    func readNonNegativeInt(): Int64 {
        skipWhitespace()
        if (index >= runes.size || runes[index] < r'0' || runes[index] > r'9') {
            frameReplayFail("expected-non-negative-integer")
        }
        if (runes[index] == r'0' && index + 1 < runes.size &&
            runes[index + 1] >= r'0' && runes[index + 1] <= r'9') {
            frameReplayFail("invalid-json-number")
        }
        var result: Int64 = 0
        while (index < runes.size && runes[index] >= r'0' && runes[index] <= r'9') {
            let digit = Int64(UInt32(runes[index]) - UInt32(r'0'))
            if (result > (Int64.Max - digit) / 10) { frameReplayFail("integer-overflow") }
            result = result * 10 + digit
            index += 1
        }
        result
    }

    func readBool(): Bool {
        skipWhitespace()
        if (consumeWord("true")) { return true }
        if (consumeWord("false")) { return false }
        frameReplayFail("expected-boolean")
        false
    }

    private func consumeWord(word: String): Bool {
        let values = word.toRuneArray()
        if (index + values.size > runes.size) { return false }
        for (i in 0..values.size) {
            if (runes[index + i] != values[i]) { return false }
        }
        index += values.size
        true
    }

    private func skipWhitespace(): Unit {
        while (index < runes.size) {
            let value = runes[index]
            if (value != r' ' && value != r'\t' && value != r'\r' && value != r'\n') {
                break
            }
            index += 1
        }
    }
}

@When[debug]
func verifyCompiledFrameTraceReceipt(payload: String): String {
    try {
        renderFrameReplayReceipt(verifyCompiledFrameTraceWithNullSchedule(payload))
    } catch (error: FrameReplayError) {
        throw CuicError("frame replay rejected: ${error.message}")
    } catch (_: Exception) {
        throw CuicError("frame replay rejected: invalid-json")
    }
}

/**
 * Verifies already-compiled schedule traces with a null schedule verifier.
 * It validates schema, bounds and ordering only; it does not rebuild a FrameGraph or submit GPU work.
 */
@When[debug]
private func verifyCompiledFrameTraceWithNullSchedule(payload: String): FrameReplaySummary {
    let byteCount = Int64(payload.toArray().size)
    if (byteCount <= 0) { frameReplayFail("empty-payload") }
    if (byteCount > FRAME_REPLAY_MAX_BYTES) { frameReplayFail("payload-over-cap") }
    let cursor = FrameReplayJsonCursor(payload)
    let summary = parseFrameReplayEnvelope(cursor)
    cursor.finish()
    validateFrameReplaySequence(summary.frames)
    summary
}

@When[debug]
private func parseFrameReplayEnvelope(cursor: FrameReplayJsonCursor): FrameReplaySummary {
    cursor.expect(r'{')
    var protocol = ""
    var scenario = ""
    var complete = false
    var terminalCode = ""
    var frameCount: Int64 = -1
    var frames: Array<FrameReplayFrame> = []
    var sawProtocol = false
    var sawScenario = false
    var sawComplete = false
    var sawTerminalCode = false
    var sawFrameCount = false
    var sawFrames = false

    if (!cursor.consume(r'}')) {
        while (true) {
            let key = cursor.readString()
            cursor.expect(r':')
            if (key == "protocol") {
                if (sawProtocol) { frameReplayFail("duplicate-envelope-field") }
                protocol = cursor.readString()
                sawProtocol = true
            } else if (key == "scenario") {
                if (sawScenario) { frameReplayFail("duplicate-envelope-field") }
                scenario = cursor.readString()
                sawScenario = true
            } else if (key == "complete") {
                if (sawComplete) { frameReplayFail("duplicate-envelope-field") }
                complete = cursor.readBool()
                sawComplete = true
            } else if (key == "terminalCode") {
                if (sawTerminalCode) { frameReplayFail("duplicate-envelope-field") }
                terminalCode = cursor.readString()
                sawTerminalCode = true
            } else if (key == "frameCount") {
                if (sawFrameCount) { frameReplayFail("duplicate-envelope-field") }
                frameCount = cursor.readNonNegativeInt()
                sawFrameCount = true
            } else if (key == "frames") {
                if (sawFrames) { frameReplayFail("duplicate-envelope-field") }
                frames = parseFrameReplayFrames(cursor)
                sawFrames = true
            } else {
                frameReplayFail("unknown-envelope-field")
            }
            if (cursor.consume(r'}')) { break }
            cursor.expect(r',')
        }
    }

    if (!sawProtocol || !sawScenario || !sawComplete || !sawTerminalCode ||
        !sawFrameCount || !sawFrames) {
        frameReplayFail("missing-envelope-field")
    }
    if (protocol != FRAME_REPLAY_TRACE_PROTOCOL) { frameReplayFail("unsupported-trace-protocol") }
    if (!complete) { frameReplayFail("incomplete-trace") }
    validateFrameReplayScenario(scenario)
    validateFrameReplayTerminalCode(terminalCode)
    if (frameCount > FRAME_REPLAY_MAX_FRAMES || frames.size > FRAME_REPLAY_MAX_FRAMES) {
        frameReplayFail("frame-count-over-cap")
    }
    if (frameCount != frames.size) { frameReplayFail("frame-count-mismatch") }
    if (frames.isEmpty()) { frameReplayFail("empty-frame-trace") }
    if (terminalCode != "accepted" && terminalCode != "trace-cap-reached") {
        frameReplayFail("invalid-trace-terminal")
    }
    // The fixed 64-frame child limit finishes as accepted before a later frame
    // can encounter the byte cap.
    if (terminalCode == "trace-cap-reached" && frames.size >= FRAME_REPLAY_MAX_FRAMES) {
        frameReplayFail("invalid-trace-cap-terminal")
    }
    FrameReplaySummary(scenario, terminalCode, frames)
}

@When[debug]
private func parseFrameReplayFrames(cursor: FrameReplayJsonCursor): Array<FrameReplayFrame> {
    let frames = ArrayList<FrameReplayFrame>()
    cursor.expect(r'[')
    if (cursor.consume(r']')) { return frames.toArray() }
    while (true) {
        frames.add(parseFrameReplayFrame(cursor))
        if (frames.size > FRAME_REPLAY_MAX_FRAMES) { frameReplayFail("frame-count-over-cap") }
        if (cursor.consume(r']')) { break }
        cursor.expect(r',')
    }
    frames.toArray()
}

@When[debug]
private func parseFrameReplayFrame(cursor: FrameReplayJsonCursor): FrameReplayFrame {
    cursor.expect(r'{')
    var protocol = ""
    var surface = ""
    var surfaceGeneration: Int64 = 0
    var frameId: Int64 = 0
    var scheduleHash = ""
    var declaredResourceBytes: Int64 = 0
    var executedPassCount: Int64 = 0
    var culledPassCount: Int64 = 0
    var mergedPassCount: Int64 = 0
    var redrawMode = ""
    var presentMode = ""
    var fallbackReason = ""
    var executionDurationNs: Int64 = 0
    var executionOk = false
    var executionCode = ""
    var providerCode = ""
    var completedPassCount: Int64 = 0
    var completedGroupCount: Int64 = 0
    var legacyFallbackUsed = false
    var finalFrameCode = ""
    var passes: Array<FrameReplayPass> = []
    var fields: Int64 = 0

    if (!cursor.consume(r'}')) {
        while (true) {
            let key = cursor.readString()
            cursor.expect(r':')
            if (key == "protocol") {
                fields = setFrameField(fields, 1)
                protocol = cursor.readString()
            } else if (key == "surface") {
                fields = setFrameField(fields, 2)
                surface = cursor.readString()
            } else if (key == "surfaceGeneration") {
                fields = setFrameField(fields, 4)
                surfaceGeneration = cursor.readNonNegativeInt()
            } else if (key == "frameId") {
                fields = setFrameField(fields, 8)
                frameId = cursor.readNonNegativeInt()
            } else if (key == "scheduleHash") {
                fields = setFrameField(fields, 16)
                scheduleHash = cursor.readString()
            } else if (key == "declaredResourceBytes") {
                fields = setFrameField(fields, 32)
                declaredResourceBytes = cursor.readNonNegativeInt()
            } else if (key == "executedPassCount") {
                fields = setFrameField(fields, 64)
                executedPassCount = cursor.readNonNegativeInt()
            } else if (key == "culledPassCount") {
                fields = setFrameField(fields, 128)
                culledPassCount = cursor.readNonNegativeInt()
            } else if (key == "mergedPassCount") {
                fields = setFrameField(fields, 256)
                mergedPassCount = cursor.readNonNegativeInt()
            } else if (key == "redrawMode") {
                fields = setFrameField(fields, 512)
                redrawMode = cursor.readString()
            } else if (key == "presentMode") {
                fields = setFrameField(fields, 1024)
                presentMode = cursor.readString()
            } else if (key == "fallbackReason") {
                fields = setFrameField(fields, 2048)
                fallbackReason = cursor.readString()
            } else if (key == "passes") {
                fields = setFrameField(fields, 4096)
                passes = parseFrameReplayPasses(cursor)
            } else if (key == "executionDurationNs") {
                fields = setFrameField(fields, 8192)
                executionDurationNs = cursor.readNonNegativeInt()
            } else if (key == "executionOk") {
                fields = setFrameField(fields, 16384)
                executionOk = cursor.readBool()
            } else if (key == "executionCode") {
                fields = setFrameField(fields, 32768)
                executionCode = cursor.readString()
            } else if (key == "providerCode") {
                fields = setFrameField(fields, 65536)
                providerCode = cursor.readString()
            } else if (key == "completedPassCount") {
                fields = setFrameField(fields, 131072)
                completedPassCount = cursor.readNonNegativeInt()
            } else if (key == "completedGroupCount") {
                fields = setFrameField(fields, 262144)
                completedGroupCount = cursor.readNonNegativeInt()
            } else if (key == "legacyFallbackUsed") {
                fields = setFrameField(fields, 524288)
                legacyFallbackUsed = cursor.readBool()
            } else if (key == "finalFrameCode") {
                fields = setFrameField(fields, 1048576)
                finalFrameCode = cursor.readString()
            } else {
                frameReplayFail("unknown-frame-field")
            }
            if (cursor.consume(r'}')) { break }
            cursor.expect(r',')
        }
    }

    if (fields != 2097151) { frameReplayFail("missing-frame-field") }
    if (protocol != FRAME_GRAPH_PROTOCOL) { frameReplayFail("unsupported-frame-protocol") }
    validateFrameGraphToken(surface, "invalid-surface")
    validateFrameScheduleHash(scheduleHash)
    if (surfaceGeneration <= 0) { frameReplayFail("invalid-surface-generation") }
    if (frameId <= 0) { frameReplayFail("invalid-frame-id") }
    if (declaredResourceBytes > FRAME_REPLAY_MAX_RESOURCE_BYTES) {
        frameReplayFail("resource-bytes-over-cap")
    }
    if (executedPassCount > FRAME_REPLAY_MAX_PASSES ||
        culledPassCount > FRAME_REPLAY_MAX_PASSES) {
        frameReplayFail("pass-count-over-cap")
    }
    var actualCulledPassCount: Int64 = 0
    for (pass in passes) {
        if (pass.culled) { actualCulledPassCount += 1 }
    }
    if (culledPassCount != actualCulledPassCount ||
        executedPassCount != passes.size - actualCulledPassCount) {
        frameReplayFail("pass-count-mismatch")
    }
    if (mergedPassCount > executedPassCount) { frameReplayFail("invalid-merged-pass-count") }
    validateFrameReplayPassLinks(passes)
    validateFrameReplayModes(redrawMode, presentMode, fallbackReason, passes)
    validateFrameReplayExecution(
        executionOk,
        executionCode,
        providerCode,
        completedPassCount,
        completedGroupCount,
        legacyFallbackUsed,
        finalFrameCode,
        executedPassCount,
        mergedPassCount,
        redrawMode,
        presentMode)
    FrameReplayFrame(
        surface,
        surfaceGeneration,
        frameId,
        scheduleHash,
        executionDurationNs,
        executionOk,
        legacyFallbackUsed)
}

@When[debug]
private func setFrameField(fields: Int64, bit: Int64): Int64 {
    if ((fields & bit) != 0) { frameReplayFail("duplicate-frame-field") }
    fields | bit
}

@When[debug]
private func parseFrameReplayPasses(cursor: FrameReplayJsonCursor): Array<FrameReplayPass> {
    let passes = ArrayList<FrameReplayPass>()
    let ids = HashSet<String>()
    let orders = HashSet<Int64>()
    cursor.expect(r'[')
    if (cursor.consume(r']')) { return passes.toArray() }
    while (true) {
        let value = parseFrameReplayPass(cursor)
        if (ids.contains(value.id)) { frameReplayFail("duplicate-pass-id") }
        if (orders.contains(value.order)) { frameReplayFail("duplicate-pass-order") }
        ids.add(value.id)
        orders.add(value.order)
        passes.add(value)
        if (passes.size > FRAME_REPLAY_MAX_PASSES) { frameReplayFail("pass-count-over-cap") }
        if (cursor.consume(r']')) { break }
        cursor.expect(r',')
    }
    passes.toArray()
}

@When[debug]
private func parseFrameReplayPass(cursor: FrameReplayJsonCursor): FrameReplayPass {
    cursor.expect(r'{')
    var id = ""
    var order: Int64 = 0
    var kind = ""
    var externalMode = ""
    var unifiedPixels = false
    var reads: Array<String> = []
    var writes: Array<String> = []
    var dependsOn: Array<String> = []
    var culled = false
    var damageKind = ""
    var damageRectangleCount: Int64 = 0
    var fields: Int64 = 0
    if (!cursor.consume(r'}')) {
        while (true) {
            let key = cursor.readString()
            cursor.expect(r':')
            if (key == "id") {
                fields = setPassField(fields, 1)
                id = cursor.readString()
            } else if (key == "order") {
                fields = setPassField(fields, 2)
                order = cursor.readNonNegativeInt()
            } else if (key == "kind") {
                fields = setPassField(fields, 4)
                kind = cursor.readString()
            } else if (key == "externalMode") {
                fields = setPassField(fields, 8)
                externalMode = cursor.readString()
            } else if (key == "unifiedPixels") {
                fields = setPassField(fields, 16)
                unifiedPixels = cursor.readBool()
            } else if (key == "reads") {
                fields = setPassField(fields, 32)
                reads = parseFrameReplayResourceIds(cursor)
            } else if (key == "writes") {
                fields = setPassField(fields, 64)
                writes = parseFrameReplayResourceIds(cursor)
            } else if (key == "dependsOn") {
                fields = setPassField(fields, 128)
                dependsOn = parseFrameReplayPassIds(cursor)
            } else if (key == "culled") {
                fields = setPassField(fields, 256)
                culled = cursor.readBool()
            } else if (key == "damage") {
                fields = setPassField(fields, 512)
                let damage = parseFrameReplayDamage(cursor)
                damageKind = damage.kind
                damageRectangleCount = damage.rectangleCount
            } else {
                frameReplayFail("unknown-pass-field")
            }
            if (cursor.consume(r'}')) { break }
            cursor.expect(r',')
        }
    }
    if (fields != 1023) { frameReplayFail("missing-pass-field") }
    validateFrameGraphToken(id, "invalid-pass-id")
    if (!isFrameReplayPassKind(kind)) { frameReplayFail("invalid-pass-kind") }
    if (!isFrameReplayExternalMode(externalMode)) { frameReplayFail("invalid-external-mode") }
    if (unifiedPixels != (externalMode == "shared-texture")) {
        frameReplayFail("invalid-unified-pixels")
    }
    if (culled != (damageKind == "empty")) { frameReplayFail("invalid-culled-damage") }
    if (!frameReplayPassModeValid(kind, externalMode, reads.size, writes.size)) {
        frameReplayFail("invalid-pass-mode")
    }
    let writtenResources = HashSet<String>()
    for (written in writes) { writtenResources.add(written) }
    for (read in reads) {
        if (writtenResources.contains(read)) {
            frameReplayFail("read-write-same-resource")
        }
    }
    FrameReplayPass(
        id, order, kind, externalMode, culled, damageKind, damageRectangleCount,
        reads, writes, dependsOn)
}

@When[debug]
private func setPassField(fields: Int64, bit: Int64): Int64 {
    if ((fields & bit) != 0) { frameReplayFail("duplicate-pass-field") }
    fields | bit
}

@When[debug]
private func parseFrameReplayResourceIds(cursor: FrameReplayJsonCursor): Array<String> {
    let values = ArrayList<String>()
    let unique = HashSet<String>()
    cursor.expect(r'[')
    if (cursor.consume(r']')) { return values.toArray() }
    while (true) {
        let value = cursor.readString()
        validateFrameReplayResourceId(value)
        if (unique.contains(value)) { frameReplayFail("duplicate-resource-access") }
        unique.add(value)
        values.add(value)
        if (values.size > FRAME_REPLAY_MAX_EDGES) { frameReplayFail("edge-count-over-cap") }
        if (cursor.consume(r']')) { break }
        cursor.expect(r',')
    }
    values.toArray()
}

@When[debug]
private func parseFrameReplayPassIds(cursor: FrameReplayJsonCursor): Array<String> {
    let values = ArrayList<String>()
    let unique = HashSet<String>()
    cursor.expect(r'[')
    if (cursor.consume(r']')) { return values.toArray() }
    while (true) {
        let value = cursor.readString()
        validateFrameGraphToken(value, "invalid-pass-dependency")
        if (unique.contains(value)) { frameReplayFail("duplicate-pass-dependency") }
        unique.add(value)
        values.add(value)
        if (values.size > FRAME_REPLAY_MAX_EDGES) { frameReplayFail("edge-count-over-cap") }
        if (cursor.consume(r']')) { break }
        cursor.expect(r',')
    }
    values.toArray()
}

@When[debug]
private func parseFrameReplayDamage(cursor: FrameReplayJsonCursor): FrameReplayDamage {
    cursor.expect(r'{')
    var kind = ""
    var rectangleCount: Int64 = 0
    var sawKind = false
    var sawRectangles = false
    if (!cursor.consume(r'}')) {
        while (true) {
            let key = cursor.readString()
            cursor.expect(r':')
            if (key == "kind") {
                if (sawKind) { frameReplayFail("duplicate-damage-field") }
                kind = cursor.readString()
                sawKind = true
            } else if (key == "rectangles") {
                if (sawRectangles) { frameReplayFail("duplicate-damage-field") }
                rectangleCount = parseFrameReplayRectangles(cursor)
                sawRectangles = true
            } else {
                frameReplayFail("unknown-damage-field")
            }
            if (cursor.consume(r'}')) { break }
            cursor.expect(r',')
        }
    }
    if (!sawKind || !sawRectangles) { frameReplayFail("missing-damage-field") }
    if (kind != "empty" && kind != "bounded" && kind != "full") {
        frameReplayFail("invalid-damage-kind")
    }
    if ((kind == "bounded" && rectangleCount == 0) ||
        (kind != "bounded" && rectangleCount != 0)) {
        frameReplayFail("invalid-damage-rectangles")
    }
    FrameReplayDamage(kind, rectangleCount)
}

@When[debug]
private func parseFrameReplayRectangles(cursor: FrameReplayJsonCursor): Int64 {
    var count: Int64 = 0
    cursor.expect(r'[')
    if (cursor.consume(r']')) { return count }
    while (true) {
        parseFrameReplayRectangle(cursor)
        count += 1
        if (count > FRAME_REPLAY_MAX_RECTS) { frameReplayFail("damage-rect-count-over-cap") }
        if (cursor.consume(r']')) { break }
        cursor.expect(r',')
    }
    count
}

@When[debug]
private func parseFrameReplayRectangle(cursor: FrameReplayJsonCursor): Unit {
    cursor.expect(r'[')
    let x = cursor.readNonNegativeInt()
    cursor.expect(r',')
    let y = cursor.readNonNegativeInt()
    cursor.expect(r',')
    let width = cursor.readNonNegativeInt()
    cursor.expect(r',')
    let height = cursor.readNonNegativeInt()
    cursor.expect(r']')
    if (width <= 0 || height <= 0 ||
        x > Int64.Max - width || y > Int64.Max - height) {
        frameReplayFail("invalid-damage-rectangle")
    }
}

@When[debug]
private func validateFrameReplayScenario(value: String): Unit {
    let bytes = value.toArray()
    if (bytes.isEmpty() || bytes.size > 64) { frameReplayFail("invalid-scenario") }
    let runes = value.toRuneArray()
    if (!isFrameReplayAsciiLetter(runes[0])) { frameReplayFail("invalid-scenario") }
    for (r in runes) {
        let allowed = isFrameReplayAsciiLetter(r) || (r >= r'0' && r <= r'9') ||
            r == r'.' || r == r'-' || r == r'_'
        if (!allowed) { frameReplayFail("invalid-scenario") }
    }
}

@When[debug]
private func validateFrameReplayTerminalCode(value: String): Unit {
    let bytes = value.toArray()
    if (bytes.isEmpty() || bytes.size > 64) { frameReplayFail("invalid-terminal-code") }
    for (r in value.toRuneArray()) {
        let lower = r >= r'a' && r <= r'z'
        let digit = r >= r'0' && r <= r'9'
        if (!lower && !digit && r != r'-') { frameReplayFail("invalid-terminal-code") }
    }
}

@When[debug]
private func validateFrameGraphToken(value: String, code: String): Unit {
    let bytes = value.toArray()
    if (bytes.isEmpty() || bytes.size > 128) { frameReplayFail(code) }
    for (r in value.toRuneArray()) {
        let lower = r >= r'a' && r <= r'z'
        let digit = r >= r'0' && r <= r'9'
        if (!lower && !digit && r != r'.' && r != r'-' && r != r'_') {
            frameReplayFail(code)
        }
    }
}

@When[debug]
private func validateFrameReplayResourceId(value: String): Unit {
    let runes = value.toRuneArray()
    if (runes.size < 3 || value.toArray().size > 160) {
        frameReplayFail("invalid-resource-id")
    }
    var separator: Int64 = -1
    for (i in 0..runes.size) {
        if (runes[i] == r'@') {
            if (separator >= 0) { frameReplayFail("invalid-resource-id") }
            separator = i
        }
    }
    if (separator <= 0 || separator + 1 >= runes.size) {
        frameReplayFail("invalid-resource-id")
    }
    let key = frameReplaySubstring(runes, 0, separator)
    validateFrameGraphToken(key, "invalid-resource-id")
    var generation: Int64 = 0
    if (runes[separator + 1] == r'0' && separator + 2 < runes.size) {
        frameReplayFail("invalid-resource-id")
    }
    var i = separator + 1
    while (i < runes.size) {
        let valueRune = runes[i]
        if (valueRune < r'0' || valueRune > r'9') { frameReplayFail("invalid-resource-id") }
        let digit = Int64(UInt32(valueRune) - UInt32(r'0'))
        if (generation > (Int64.Max - digit) / 10) { frameReplayFail("invalid-resource-id") }
        generation = generation * 10 + digit
        i += 1
    }
    if (generation <= 0) { frameReplayFail("invalid-resource-id") }
}

@When[debug]
private func validateFrameReplayPassLinks(passes: Array<FrameReplayPass>): Unit {
    var edgeCount: Int64 = 0
    let declaredPasses = HashSet<String>()
    let declaredWrites = HashSet<String>()
    for (pass in passes) {
        declaredPasses.add(pass.id)
        for (written in pass.writes) {
            if (declaredWrites.contains(written)) { frameReplayFail("double-producer") }
            declaredWrites.add(written)
        }
    }
    let scheduled = HashSet<String>()
    let scheduledWrites = HashSet<String>()
    for (pass in passes) {
        if (pass.order >= passes.size) { frameReplayFail("unstable-pass-order") }
        edgeCount += pass.reads.size + pass.writes.size + pass.dependsOn.size
        if (edgeCount > FRAME_REPLAY_MAX_EDGES) { frameReplayFail("edge-count-over-cap") }
        for (read in pass.reads) {
            if (declaredWrites.contains(read) && !scheduledWrites.contains(read)) {
                frameReplayFail("unscheduled-resource-producer")
            }
        }
        for (dependency in pass.dependsOn) {
            if (dependency == pass.id) { frameReplayFail("self-pass-dependency") }
            if (!declaredPasses.contains(dependency)) { frameReplayFail("unknown-pass-dependency") }
            if (!scheduled.contains(dependency)) { frameReplayFail("unscheduled-pass-dependency") }
        }
        scheduled.add(pass.id)
        for (written in pass.writes) { scheduledWrites.add(written) }
    }
}

@When[debug]
private func frameReplayPassModeValid(
    kind: String,
    externalMode: String,
    readCount: Int64,
    writeCount: Int64
): Bool {
    if (kind == "external-scene3d") {
        return externalMode != "none" && readCount + writeCount > 0
    }
    if (externalMode != "none") { return false }
    if (kind == "present") { return readCount > 0 && writeCount == 0 }
    writeCount > 0
}

@When[debug]
private func validateFrameScheduleHash(value: String): Unit {
    if (value.toArray().size > 128) {
        frameReplayFail("invalid-schedule-hash")
    }
    let parts = value.split("-")
    if (parts.size != 3 || parts[0] != "fg" ||
        !isFrameReplayDecimal(parts[1], allowZero: true) ||
        !isFrameReplayDecimal(parts[2], allowZero: false)) {
        frameReplayFail("invalid-schedule-hash")
    }
}

@When[debug]
private func validateFrameReplayModes(
    redraw: String,
    present: String,
    fallback: String,
    passes: Array<FrameReplayPass>
): Unit {
    if (redraw != "none" && redraw != "bounded" && redraw != "full") {
        frameReplayFail("invalid-redraw-mode")
    }
    if (present != "none" && present != "partial" && present != "full") {
        frameReplayFail("invalid-present-mode")
    }
    if (fallback != "none" && fallback != "bounded-redraw-unsupported" &&
        fallback != "partial-present-unsupported") {
        frameReplayFail("invalid-fallback-reason")
    }
    var declaredPresentCount: Int64 = 0
    var declaredPresentIndex: Int64 = -1
    var executedPresentCount: Int64 = 0
    var executedNonPresentCount: Int64 = 0
    var executedBoundedNonPresentCount: Int64 = 0
    var executedFullNonPresentCount: Int64 = 0
    var executedBoundedRectangleCount: Int64 = 0
    for (i in 0..passes.size) {
        let pass = passes[i]
        if (pass.kind == "present") {
            declaredPresentCount += 1
            declaredPresentIndex = i
        }
        if (pass.culled) { continue }
        if (pass.kind == "present") {
            executedPresentCount += 1
        } else {
            executedNonPresentCount += 1
            if (pass.damageKind == "bounded") {
                executedBoundedNonPresentCount += 1
                executedBoundedRectangleCount += pass.damageRectangleCount
            } else if (pass.damageKind == "full") {
                executedFullNonPresentCount += 1
            }
        }
    }
    if (declaredPresentCount > 1) { frameReplayFail("multiple-present-passes") }
    if (declaredPresentCount == 1 && declaredPresentIndex != passes.size - 1) {
        frameReplayFail("present-not-terminal")
    }
    if (redraw == "none") {
        if (executedPresentCount != 0 || executedNonPresentCount != 0 ||
            present != "none" || fallback != "none") {
            frameReplayFail("invalid-skipped-frame-modes")
        }
        return
    }
    if (executedNonPresentCount == 0) { frameReplayFail("invalid-redraw-without-work") }
    if (redraw == "bounded" &&
        (executedBoundedNonPresentCount != executedNonPresentCount ||
        executedFullNonPresentCount != 0 ||
        executedBoundedRectangleCount > FRAME_REPLAY_MAX_RECTS)) {
        frameReplayFail("invalid-bounded-redraw-damage")
    }
    let boundedAggregateFits =
        executedBoundedNonPresentCount == executedNonPresentCount &&
        executedFullNonPresentCount == 0 &&
        executedBoundedRectangleCount <= FRAME_REPLAY_MAX_RECTS
    if (redraw == "full" && boundedAggregateFits &&
        fallback != "bounded-redraw-unsupported") {
        frameReplayFail("missing-bounded-redraw-fallback")
    }
    if ((executedPresentCount == 0) != (present == "none")) {
        frameReplayFail("invalid-present-work")
    }
    if (present == "partial" && (redraw != "bounded" || fallback != "none")) {
        frameReplayFail("invalid-partial-present")
    }
    if (fallback == "partial-present-unsupported" &&
        (redraw != "bounded" || present != "full")) {
        frameReplayFail("invalid-partial-present-fallback")
    }
    if (redraw == "bounded" && present == "full" &&
        fallback != "partial-present-unsupported") {
        frameReplayFail("missing-partial-present-fallback")
    }
    if (fallback == "bounded-redraw-unsupported" &&
        (redraw != "full" || executedBoundedNonPresentCount != executedNonPresentCount ||
        executedFullNonPresentCount != 0 ||
        executedBoundedRectangleCount > FRAME_REPLAY_MAX_RECTS)) {
        frameReplayFail("invalid-bounded-redraw-fallback")
    }
}

@When[debug]
private func validateFrameReplayExecution(
    executionOk: Bool,
    executionCode: String,
    providerCode: String,
    completedPassCount: Int64,
    completedGroupCount: Int64,
    legacyFallbackUsed: Bool,
    finalFrameCode: String,
    executedPassCount: Int64,
    mergedPassCount: Int64,
    redrawMode: String,
    presentMode: String
): Unit {
    validateFrameReplayTerminalCode(executionCode)
    validateFrameReplayTerminalCode(providerCode)
    validateFrameReplayTerminalCode(finalFrameCode)
    let executionGroupCount = executedPassCount - mergedPassCount
    if (completedPassCount > executedPassCount ||
        completedGroupCount > executionGroupCount ||
        completedGroupCount > completedPassCount ||
        completedPassCount - completedGroupCount > mergedPassCount) {
        frameReplayFail("invalid-completed-count")
    }
    if (executionOk) {
        if (executionCode != "accepted" || !isFrameReplaySuccessProviderCode(providerCode) ||
            finalFrameCode != "accepted" ||
            legacyFallbackUsed || completedPassCount != executedPassCount ||
            completedGroupCount != executionGroupCount ||
            (providerCode == "accepted-legacy-full-present" &&
            (redrawMode != "full" || presentMode != "full"))) {
            frameReplayFail("invalid-success-execution")
        }
        return
    }
    // A failed compiled execution may enter the trace only after the upper layer really
    // presented its legacy fallback. This is final-frame truth, not a successful graph replay.
    if (!isFrameReplayExecutionFailureCode(executionCode) ||
        startsWithText(providerCode, "accepted") ||
        !legacyFallbackUsed || finalFrameCode != "accepted-legacy-fallback") {
        frameReplayFail("invalid-legacy-fallback-execution")
    }
    if (executionCode == "executor-commit-failed" &&
        (completedPassCount != executedPassCount ||
        completedGroupCount != executionGroupCount)) {
        frameReplayFail("invalid-commit-failure-count")
    }
    if (executionCode == "executor-pass-failed" &&
        completedGroupCount >= executionGroupCount) {
        frameReplayFail("invalid-pass-failure-count")
    }
    if (providerCode == "not-started" &&
        (executionCode != "executor-exception" ||
        completedPassCount != 0 || completedGroupCount != 0)) {
        frameReplayFail("invalid-not-started-provider")
    }
}

@When[debug]
private func isFrameReplaySuccessProviderCode(value: String): Bool {
    value == "accepted" || value == "accepted-legacy-full-present"
}

@When[debug]
private func isFrameReplayExecutionFailureCode(value: String): Bool {
    value == "executor-pass-failed" || value == "executor-commit-failed" ||
        value == "executor-exception"
}

@When[debug]
private func isFrameReplayPassKind(value: String): Bool {
    value == "ui-2d" || value == "renderer-effect" || value == "external-scene3d" ||
        value == "offscreen-composition" || value == "copy-resolve" || value == "present"
}

@When[debug]
private func isFrameReplayExternalMode(value: String): Bool {
    value == "none" || value == "native-child-surface-barrier" || value == "shared-texture"
}

@When[debug]
private func isFrameReplayDecimal(value: String, allowZero!: Bool = false): Bool {
    let runes = value.toRuneArray()
    if (runes.isEmpty() || (runes.size > 1 && runes[0] == r'0')) { return false }
    var parsed: Int64 = 0
    for (r in runes) {
        if (r < r'0' || r > r'9') { return false }
        let digit = Int64(UInt32(r) - UInt32(r'0'))
        if (parsed > (Int64.Max - digit) / 10) { return false }
        parsed = parsed * 10 + digit
    }
    allowZero || parsed > 0
}

@When[debug]
private func validateFrameReplaySequence(frames: Array<FrameReplayFrame>): Unit {
    let states = ArrayList<FrameReplaySurfaceState>()
    for (frame in frames) {
        var found = false
        for (state in states) {
            if (state.surface == frame.surface) {
                if (frame.surfaceGeneration < state.surfaceGeneration) {
                    frameReplayFail("stale-surface-generation")
                }
                if (frame.surfaceGeneration == state.surfaceGeneration &&
                    frame.frameId <= state.frameId) {
                    frameReplayFail("stale-frame")
                }
                state.surfaceGeneration = frame.surfaceGeneration
                state.frameId = frame.frameId
                found = true
                break
            }
        }
        if (!found) {
            states.add(FrameReplaySurfaceState(
                frame.surface, frame.surfaceGeneration, frame.frameId))
        }
    }
}

@When[debug]
private func renderFrameReplayReceipt(summary: FrameReplaySummary): String {
    let lastScheduleHash = if (summary.frames.isEmpty()) {
        ""
    } else {
        summary.frames[summary.frames.size - 1].scheduleHash
    }
    var executionOkFrameCount: Int64 = 0
    var upperLayerLegacyFallbackFrameCount: Int64 = 0
    for (frame in summary.frames) {
        if (frame.executionOk) { executionOkFrameCount += 1 }
        if (frame.legacyFallbackUsed) { upperLayerLegacyFallbackFrameCount += 1 }
    }
    "{\"protocol\":" + frameReplayJsonQuote(FRAME_REPLAY_PROTOCOL) +
        ",\"executor\":\"null\",\"ok\":true,\"scenario\":" +
        frameReplayJsonQuote(summary.scenario) +
        ",\"frameCount\":" + summary.frames.size.toString() +
        ",\"acceptedFrameCount\":" + summary.frames.size.toString() +
        ",\"executionOkFrameCount\":" + executionOkFrameCount.toString() +
        ",\"upperLayerLegacyFallbackFrameCount\":" +
        upperLayerLegacyFallbackFrameCount.toString() +
        ",\"terminalCode\":" + frameReplayJsonQuote(summary.terminalCode) +
        ",\"lastScheduleHash\":" + frameReplayJsonQuote(lastScheduleHash) +
        ",\"detail\":\"compiled-trace null schedule verifier only; no graph recompilation, GPU submission or presentation\"}"
}

@When[debug]
private func frameReplayJsonQuote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (r in value.toRuneArray()) {
        if (r == r'\"') { out.append("\\\"") }
        else if (r == r'\\') { out.append("\\\\") }
        else if (r == r'\n') { out.append("\\n") }
        else if (r == r'\r') { out.append("\\r") }
        else if (r == r'\t') { out.append("\\t") }
        else if (UInt32(r) < UInt32(32)) { frameReplayFail("invalid-receipt-string") }
        else { out.append(r.toString()) }
    }
    out.append("\"")
    out.toString()
}

@When[debug]
private func isFrameReplayAsciiLetter(value: Rune): Bool {
    (value >= r'a' && value <= r'z') || (value >= r'A' && value <= r'Z')
}

@When[debug]
private func frameReplaySubstring(values: Array<Rune>, start: Int64, end: Int64): String {
    let out = StringBuilder()
    var i = start
    while (i < end && i < values.size) {
        out.append(values[i].toString())
        i += 1
    }
    out.toString()
}

@When[debug]
private func frameReplayFail(code: String): Nothing {
    throw FrameReplayError(code)
}
