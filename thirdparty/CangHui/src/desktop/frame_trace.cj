package chui.desktop

import chui.graphics.FrameExecutionReceipt

@When[debug]
import std.collection.ArrayList
@When[debug]
import std.convert.*
@When[debug]
import std.env.getVariable
@When[debug]
import std.fs.{File, FileInfo, exists}

@When[debug]
private let FRAME_TRACE_PROTOCOL = "canghui.frame-trace.v0"
@When[debug]
private let FRAME_TRACE_MAX_FRAMES: Int64 = 64
@When[debug]
private let FRAME_TRACE_MAX_BYTES: Int64 = 512 * 1024

/** Compiler-debug-only bounded recorder. It writes no Widget text, paths, handles or pixel data. */
@When[debug]
class FrameTraceRecorder {
    private let outputPath: String
    private let scenario: String
    private let maximumFrames: Int64
    private let traces = ArrayList<String>()
    private var capturedBytes: Int64 = 0
    private var finished = false
    private var traceComplete = true
    private var terminalCode = "accepted"
    private var stableObservationFrames: Int64 = 0

    init() {
        outputPath = frameTraceEnvironmentValue("CANGHUI_FRAME_TRACE_PATH")
        scenario = frameTraceEnvironmentValue("CANGHUI_FRAME_TRACE_SCENARIO")
        maximumFrames = parseFrameTraceMaximum(
            frameTraceEnvironmentValue("CANGHUI_FRAME_TRACE_MAX_FRAMES"))
        if (!outputPath.isEmpty()) { validateFrameTraceScenario(scenario) }
    }

    func active(): Bool { !outputPath.isEmpty() && !finished }

    /**
     * 0 = full, 1 = bounded stable redraw proof, 2 = empty/cull. The bounded probe is emitted only
     * after one full observation frame with no application invalidation.
     */
    func damageMode(fullDamageRequested: Bool): Int64 {
        if (fullDamageRequested) {
            stableObservationFrames = 0
            return 0
        }
        if (!active()) { return 2 }
        stableObservationFrames += 1
        if (stableObservationFrames == 1) { return 0 }
        if (stableObservationFrames == 2) { return 1 }
        2
    }

    /** Returns true when the trace child should leave its ordinary application loop. */
    func capture(receipt: FrameExecutionReceipt, durationNs: UInt64, providerCode: String): Bool {
        if (!active()) { return false }
        if (!receipt.ok || receipt.trace.isEmpty()) {
            terminalCode = frameTraceSafeCode(receipt.code)
            finish()
            return true
        }
        let decorated = decorateFrameTrace(
            receipt.trace,
            durationNs,
            true,
            receipt.code,
            providerCode,
            receipt.completedPassCount,
            receipt.completedGroupCount,
            false,
            receipt.code)
        appendFrame(decorated)
    }

    /** Records the graph failure and the successfully presented legacy fallback as one final truth. */
    func captureLegacyFallback(
        receipt: FrameExecutionReceipt,
        durationNs: UInt64,
        fallbackUsed: Bool,
        providerCode: String,
        fallbackCode: String
    ): Bool {
        if (!active()) { return false }
        if (receipt.trace.isEmpty() || !fallbackUsed) {
            terminalCode = if (fallbackUsed) {
                "legacy-fallback-without-compiled-trace"
            } else {
                "legacy-fallback-not-confirmed"
            }
            finish()
            return true
        }
        let decorated = decorateFrameTrace(
            receipt.trace,
            durationNs,
            false,
            receipt.code,
            providerCode,
            receipt.completedPassCount,
            receipt.completedGroupCount,
            true,
            fallbackCode)
        appendFrame(decorated)
    }

    private func appendFrame(decorated: String): Bool {
        let additional = Int64(decorated.toArray().size) + if (traces.isEmpty()) { 0 } else { 1 }
        // Leave room for the bounded envelope. Ending early is a valid complete capture, not a
        // truncated JSON file.
        if (capturedBytes > FRAME_TRACE_MAX_BYTES - additional - 512) {
            terminalCode = "trace-cap-reached"
            finish()
            return true
        }
        traces.add(decorated)
        capturedBytes += additional
        if (traces.size >= maximumFrames) {
            finish()
            true
        } else {
            false
        }
    }

    func finish(): Unit {
        if (outputPath.isEmpty() || finished) { return }
        if (exists(outputPath) && FileInfo(outputPath).isSymbolicLink()) {
            throw IllegalArgumentException("frame trace output must not be a symbolic link")
        }
        let envelope = renderFrameTraceEnvelope(
            scenario,
            traces.toArray(),
            terminalCode: terminalCode,
            complete: traceComplete)
        if (Int64(envelope.toArray().size) > FRAME_TRACE_MAX_BYTES) {
            throw IllegalArgumentException("frame trace exceeds the compiler-debug byte cap")
        }
        File.writeTo(outputPath, envelope.toArray())
        finished = true
    }

    /** Closes a partially captured trace without allowing offline replay to accept it. */
    func fail(code: String): Unit {
        if (!active()) { return }
        traceComplete = false
        terminalCode = frameTraceSafeCode(code)
        finish()
    }
}

@When[!debug]
class FrameTraceRecorder {
    init() {}
    func active(): Bool { false }
    func damageMode(fullDamageRequested: Bool): Int64 { if (fullDamageRequested) { 0 } else { 2 } }
    func capture(_: FrameExecutionReceipt, _: UInt64, _: String): Bool { false }
    func captureLegacyFallback(
        _: FrameExecutionReceipt,
        _: UInt64,
        _: Bool,
        _: String,
        _: String
    ): Bool { false }
    func fail(_: String): Unit {}
    func finish(): Unit {}
}

@When[debug]
func renderFrameTraceEnvelope(
    scenario: String,
    traces: Array<String>,
    terminalCode!: String = "accepted",
    complete!: Bool = true
): String {
    validateFrameTraceScenario(scenario)
    if (traces.size > FRAME_TRACE_MAX_FRAMES) {
        throw IllegalArgumentException("frame trace count exceeds the compiler-debug cap")
    }
    let out = StringBuilder()
    out.append("{\"protocol\":\"")
    out.append(FRAME_TRACE_PROTOCOL)
    out.append("\",\"scenario\":\"")
    out.append(scenario)
    out.append("\",\"complete\":")
    out.append(complete.toString())
    out.append(",\"terminalCode\":\"")
    out.append(frameTraceSafeCode(terminalCode))
    out.append("\",\"frameCount\":")
    out.append(traces.size.toString())
    out.append(",\"frames\":[")
    for (i in 0..traces.size) {
        if (i > 0) { out.append(",") }
        let trace = traces[i]
        if (!trace.startsWith("{\"protocol\":\"canghui.frame-graph.v0\"") ||
            !trace.endsWith("}")) {
            throw IllegalArgumentException("compiled frame trace has an invalid envelope")
        }
        out.append(trace)
    }
    out.append("]}")
    out.toString()
}

@When[debug]
func decorateFrameTrace(
    trace: String,
    durationNs: UInt64,
    executionOk: Bool,
    executionCode: String,
    providerCode: String,
    completedPassCount: Int64,
    completedGroupCount: Int64,
    legacyFallbackUsed: Bool,
    finalFrameCode: String
): String {
    if (!trace.startsWith("{") || !trace.endsWith("}")) {
        throw IllegalArgumentException("compiled frame trace must be a JSON object")
    }
    if (completedPassCount < 0 || completedGroupCount < 0) {
        throw IllegalArgumentException("frame trace execution counts must be non-negative")
    }
    trace[0..trace.size - 1] +
        ",\"executionDurationNs\":" + durationNs.toString() +
        ",\"executionOk\":" + executionOk.toString() +
        ",\"executionCode\":\"" + frameTraceSafeCode(executionCode) + "\"" +
        ",\"providerCode\":\"" + frameTraceSafeCode(providerCode) + "\"" +
        ",\"completedPassCount\":" + completedPassCount.toString() +
        ",\"completedGroupCount\":" + completedGroupCount.toString() +
        ",\"legacyFallbackUsed\":" + legacyFallbackUsed.toString() +
        ",\"finalFrameCode\":\"" + frameTraceSafeCode(finalFrameCode) + "\"}"
}

@When[debug]
private func frameTraceEnvironmentValue(name: String): String {
    match (getVariable(name)) {
        case Some(value) => value
        case None => ""
    }
}

@When[debug]
private func parseFrameTraceMaximum(value: String): Int64 {
    if (value.isEmpty()) { return 1 }
    let parsed = try { Int64.parse(value) } catch (_: Exception) {
        throw IllegalArgumentException("frame trace maximum must be an integer")
    }
    if (parsed <= 0 || parsed > FRAME_TRACE_MAX_FRAMES) {
        throw IllegalArgumentException("frame trace maximum must be within 1..64")
    }
    parsed
}

@When[debug]
private func validateFrameTraceScenario(value: String): Unit {
    let bytes = value.toArray()
    if (bytes.isEmpty() || bytes.size > 64) {
        throw IllegalArgumentException("frame trace scenario must contain 1..64 ASCII bytes")
    }
    for (i in 0..bytes.size) {
        let byte = bytes[i]
        let letter = (byte >= UInt8(65) && byte <= UInt8(90)) ||
            (byte >= UInt8(97) && byte <= UInt8(122))
        let digit = byte >= UInt8(48) && byte <= UInt8(57)
        if ((!letter && (i == 0 || !digit) && byte != UInt8(46) && byte != UInt8(45) &&
            byte != UInt8(95)) || (i == 0 && !letter)) {
            throw IllegalArgumentException("frame trace scenario is not a safe ASCII token")
        }
    }
}

@When[debug]
private func frameTraceSafeCode(value: String): String {
    if (value.isEmpty()) { return "unknown" }
    let out = StringBuilder()
    for (byte in value.toArray()) {
        let lower = byte >= UInt8(97) && byte <= UInt8(122)
        let digit = byte >= UInt8(48) && byte <= UInt8(57)
        if (lower || digit || byte == UInt8(45)) {
            out.append(String.fromUtf8([byte]))
        }
        if (out.toString().toArray().size >= 64) { break }
    }
    if (out.toString().isEmpty()) { "unknown" } else { out.toString() }
}
