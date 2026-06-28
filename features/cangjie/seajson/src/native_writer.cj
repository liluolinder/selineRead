package seajson

// ── Native JSON Writer ──────────────────────────────────────
// A backend-neutral, streaming JSON writer that produces valid
// JSON without depending on stdx. This is the primary native
// encode path for SeaJson.
//
// Design notes:
//   - Inspired by Jackson's JsonGenerator and soonlink's builder pattern
//   - Validates nesting: beginObject/endObject and beginArray/endArray
//     must be properly paired
//   - Supports feature flags (PrettyPrint, EscapeNonAscii, WriteNulls)
//   - Depth limit prevents stack overflow from circular references
//   - Zero stdx dependency — pure std + SeaJson escaping

import std.collection.ArrayList

// ── Writer state ─────────────────────────────────────────────

enum WCtx {
    | WRoot
    | WObj
    | WArr
}

func wctxEq(a: WCtx, b: WCtx): Bool {
    match (a) {
        case WRoot => match (b) { case WRoot => true case _ => false }
        case WObj  => match (b) { case WObj  => true case _ => false }
        case WArr  => match (b) { case WArr  => true case _ => false }
    }
}

class WriterFrame {
    public var ctx: WCtx = WRoot
    public var needsComma: Bool = false

    public init(ctx: WCtx) {
        this.ctx = ctx
    }
}

// ── Default depth limit ──────────────────────────────────────

let DEFAULT_MAX_DEPTH: Int64 = 512
let DEFAULT_INITIAL_CAPACITY: Int64 = 256

// ── JsonWriter ───────────────────────────────────────────────

public class JsonWriter {
    private var buf: StringBuilder
    private var stack: ArrayList<WriterFrame> = ArrayList<WriterFrame>()
    private let features: ArrayList<JsonWriteFeature>
    private var indentStr: String
    private var closed: Bool = false
    private let maxDepth: Int64

    /// Create a writer with default (strict) settings.
    public init(pretty!: Bool = false, indent!: String = "  ") {
        this.buf = StringBuilder(DEFAULT_INITIAL_CAPACITY)
        this.features = ArrayList<JsonWriteFeature>()
        if (pretty) {
            this.features.add(PrettyPrint)
        }
        this.indentStr = indent
        this.maxDepth = DEFAULT_MAX_DEPTH
        stack.add(WriterFrame(WRoot)) // sentinel
    }

    /// Create a writer with explicit feature flags.
    public init(features!: ArrayList<JsonWriteFeature>, indent!: String = "  ", maxDepth!: Int64 = DEFAULT_MAX_DEPTH) {
        this.buf = StringBuilder(DEFAULT_INITIAL_CAPACITY)
        this.features = features
        this.indentStr = indent
        this.maxDepth = maxDepth
        stack.add(WriterFrame(WRoot)) // sentinel
    }

    /// Create a writer with custom depth limit only.
    public init(maxDepth!: Int64) {
        this.buf = StringBuilder(DEFAULT_INITIAL_CAPACITY)
        this.features = ArrayList<JsonWriteFeature>()
        this.indentStr = "  "
        this.maxDepth = maxDepth
        stack.add(WriterFrame(WRoot)) // sentinel
    }

    /// Create a writer with initial buffer capacity (performance optimization).
    /// Use this when you know the approximate size of the output.
    public init(initialCapacity!: Int64, pretty!: Bool = false, indent!: String = "  ") {
        this.buf = StringBuilder(initialCapacity)
        this.features = ArrayList<JsonWriteFeature>()
        if (pretty) {
            this.features.add(PrettyPrint)
        }
        this.indentStr = indent
        this.maxDepth = DEFAULT_MAX_DEPTH
        stack.add(WriterFrame(WRoot)) // sentinel
    }

    /// Create a writer with all options.
    public init(initialCapacity!: Int64, features!: ArrayList<JsonWriteFeature>, indent!: String = "  ", maxDepth!: Int64 = DEFAULT_MAX_DEPTH) {
        this.buf = StringBuilder(initialCapacity)
        this.features = features
        this.indentStr = indent
        this.maxDepth = maxDepth
        stack.add(WriterFrame(WRoot)) // sentinel
    }

    // ── Object scope ────────────────────────────────────────

    public func beginObject(): JsonWriter {
        _checkOpen()
        _checkDepth()
        _beforeValue()
        buf.append("{")
        stack.add(WriterFrame(WObj))
        _newline()
        this
    }

    public func endObject(): JsonWriter {
        _checkOpen()
        let frame = _pop(WObj)
        frame.needsComma = false
        _newline()
        buf.append("}")
        this
    }

    // ── Array scope ─────────────────────────────────────────

    public func beginArray(): JsonWriter {
        _checkOpen()
        _checkDepth()
        _beforeValue()
        buf.append("[")
        stack.add(WriterFrame(WArr))
        _newline()
        this
    }

    public func endArray(): JsonWriter {
        _checkOpen()
        let frame = _pop(WArr)
        frame.needsComma = false
        _newline()
        buf.append("]")
        this
    }

    // ── Name (object key) ───────────────────────────────────

    public func name(key: String): JsonWriter {
        _checkOpen()
        let top = stack[stack.size - 1]
        if (!wctxEq(top.ctx, WObj)) {
            throw Exception("JsonWriter.name() called outside object context")
        }
        if (top.needsComma) {
            buf.append(",")
            _newline()
        }
        _indent()
        buf.append(jsonStringLiteral(key))
        if (isPretty()) { buf.append(": ") } else { buf.append(":") }
        this
    }

    /// Write a name with null value, respecting WriteNulls feature.
    /// If WriteNulls is disabled, the field is skipped entirely.
    /// Returns true if the field was written, false if skipped.
    public func nameWithNull(key: String): Bool {
        if (hasWriteFeature(features, WriteNulls)) {
            name(key).nullValue()
            true
        } else {
            // Skip this field entirely
            false
        }
    }

    /// Write a name with optional null value.
    /// If value is null and WriteNulls is disabled, the field is skipped.
    public func nameValue(key: String, value: ?String): Bool {
        match (value) {
            case Some(v) =>
                name(key).value(v)
                true
            case None =>
                nameWithNull(key)
        }
    }

    // ── Value writers ───────────────────────────────────────

    public func value(v: String): JsonWriter {
        _beforeValue()
        if (hasWriteFeature(features, EscapeNonAscii)) {
            buf.append(jsonStringLiteralEscapeNonAscii(v))
        } else {
            buf.append(jsonStringLiteral(v))
        }
        this
    }

    public func value(v: Int64): JsonWriter {
        _beforeValue()
        buf.append("${v}")
        this
    }

    public func value(v: Int32): JsonWriter {
        _beforeValue()
        buf.append("${v}")
        this
    }

    public func value(v: UInt64): JsonWriter {
        _beforeValue()
        buf.append("${v}")
        this
    }

    public func value(v: Float64): JsonWriter {
        _beforeValue()
        buf.append(_formatFloat(v))
        this
    }

    public func value(v: Bool): JsonWriter {
        _beforeValue()
        buf.append(if (v) { "true" } else { "false" })
        this
    }

    public func nullValue(): JsonWriter {
        _beforeValue()
        buf.append("null")
        this
    }

    // Write a pre-formatted JSON literal (e.g. another object or array
    // already serialized). Use with caution — no validation is performed.
    public func rawValue(json: String): JsonWriter {
        _beforeValue()
        buf.append(json)
        this
    }

    // ── Convenience: write a JsonEncodable value ─────────────

    public func encodableValue(obj: JsonEncodable): JsonWriter {
        _beforeValue()
        buf.append(obj.toJsonString())
        this
    }

    // ── Feature query ───────────────────────────────────────

    public func isPretty(): Bool {
        hasWriteFeature(features, PrettyPrint)
    }

    // ── Output ──────────────────────────────────────────────

    public func toString(): String {
        buf.toString()
    }

    // Close the writer and verify all scopes have been closed.
    public func close(): String {
        if (closed) {
            return buf.toString()
        }
        closed = true
        if (stack.size > 1) {
            throw Exception("JsonWriter closed with unclosed scopes (depth=${stack.size - 1})")
        }
        buf.toString()
    }

    // ── Internal helpers ────────────────────────────────────

    private func _beforeValue(): Unit {
        _checkOpen()
        let top = stack[stack.size - 1]
        if (wctxEq(top.ctx, WArr) && top.needsComma) {
            buf.append(",")
            _newline()
        }
        if (wctxEq(top.ctx, WArr) && !top.needsComma) {
            _indent()
        }
        top.needsComma = true
    }

    private func _pop(expected: WCtx): WriterFrame {
        if (stack.size <= 1) {
            throw Exception("JsonWriter: unmatched end call at root")
        }
        let frame = stack.remove(at: stack.size - 1)
        if (!wctxEq(frame.ctx, expected)) {
            throw Exception("JsonWriter: context mismatch")
        }
        // Mark parent as having received a value
        let parent = stack[stack.size - 1]
        parent.needsComma = true
        frame
    }

    private func _indent(): Unit {
        if (!isPretty()) {
            return
        }
        var i: Int64 = 1
        while (i < stack.size) {
            buf.append(indentStr)
            i += 1
        }
    }

    private func _newline(): Unit {
        if (isPretty()) {
            buf.append("\n")
        }
    }

    private func _checkOpen(): Unit {
        if (closed) {
            throw Exception("JsonWriter is already closed")
        }
    }

    private func _checkDepth(): Unit {
        if (stack.size > maxDepth) {
            throw Exception("JsonWriter: nesting depth exceeded (max=${maxDepth})")
        }
    }

    private func _formatFloat(v: Float64): String {
        // Guard: NaN and Infinity are not valid JSON
        if (v != v) {
            throw Exception("JsonWriter: cannot write NaN as JSON float (not RFC 8259 compliant)")
        }
        if (v == v / 0.0 && v > 0.0) {
            throw Exception("JsonWriter: cannot write +Infinity as JSON float (not RFC 8259 compliant)")
        }
        if (v == v / 0.0 && v < 0.0) {
            throw Exception("JsonWriter: cannot write -Infinity as JSON float (not RFC 8259 compliant)")
        }
        let s = "${v}"
        s
    }
}

// ── Non-ASCII escape variant ─────────────────────────────────

/// Escape a string and encode all non-ASCII characters as \uXXXX sequences.
func jsonStringLiteralEscapeNonAscii(value: String): String {
    "\"" + escapeJsonTextNonAscii(value) + "\""
}

func escapeJsonTextNonAscii(value: String): String {
    var out = ""
    for (r in value.toRuneArray()) {
        let piece = r.toString()
        let bytes = piece.toArray()
        if (bytes.size == 1) {
            let code = Int64(bytes[0])
            if (code < 0x20) {
                out = out + escapeJsonRune(r)
            } else if (code > 0x7F) {
                out = out + "\\u00" + byteToLowerHex(bytes[0])
            } else {
                out = out + piece
            }
        } else {
            // Multi-byte UTF-8 → encode each codepoint as \uXXXX or surrogate pair
            let cp = Int64(UInt32(r))
            if (cp < 0x10000) {
                out = out + "\\u" + intToHex4(cp)
            } else {
                // Encode as surrogate pair
                let hi = 0xD800 + ((cp - 0x10000) >> 10)
                let lo = 0xDC00 + ((cp - 0x10000) & 0x3FF)
                out = out + "\\u" + intToHex4(hi) + "\\u" + intToHex4(lo)
            }
        }
    }
    out
}

func intToHex4(v: Int64): String {
    let hexChars = "0123456789ABCDEF".toRuneArray()
    var s = ""
    s += hexChars[Int64((v >> 12) & 0xF)].toString()
    s += hexChars[Int64((v >> 8) & 0xF)].toString()
    s += hexChars[Int64((v >> 4) & 0xF)].toString()
    s += hexChars[Int64(v & 0xF)].toString()
    s
}

// ── Top-level convenience functions ──────────────────────────

/// Build a JSON object using a writer block.
/// Usage:
///   let json = buildJsonObject { w =>
///       w.name("id").value(42)
///       w.name("label").value("hello")
///   }
///   // {"id":42,"label":"hello"}
public func buildJsonObject(block: (JsonWriter) -> JsonWriter): String {
    let w = JsonWriter()
    block(w.beginObject()).endObject()
    w.close()
}

/// Build a JSON object with initial buffer capacity hint.
public func buildJsonObject(initialCapacity: Int64, block: (JsonWriter) -> JsonWriter): String {
    let w = JsonWriter(initialCapacity: initialCapacity)
    block(w.beginObject()).endObject()
    w.close()
}

/// Build a JSON array using a writer block.
public func buildJsonArray(block: (JsonWriter) -> JsonWriter): String {
    let w = JsonWriter()
    block(w.beginArray()).endArray()
    w.close()
}

/// Build a JSON array with initial buffer capacity hint.
public func buildJsonArray(initialCapacity: Int64, block: (JsonWriter) -> JsonWriter): String {
    let w = JsonWriter(initialCapacity: initialCapacity)
    block(w.beginArray()).endArray()
    w.close()
}

/// Build a pretty-printed JSON object.
public func buildJsonObjectPretty(block: (JsonWriter) -> JsonWriter): String {
    let features = ArrayList<JsonWriteFeature>()
    features.add(PrettyPrint)
    let w = JsonWriter(features: features)
    block(w.beginObject()).endObject()
    w.close()
}

/// Build a pretty-printed JSON object with initial capacity.
public func buildJsonObjectPretty(initialCapacity: Int64, block: (JsonWriter) -> JsonWriter): String {
    let features = ArrayList<JsonWriteFeature>()
    features.add(PrettyPrint)
    let w = JsonWriter(initialCapacity: initialCapacity, features: features)
    block(w.beginObject()).endObject()
    w.close()
}

/// Build a pretty-printed JSON array.
public func buildJsonArrayPretty(block: (JsonWriter) -> JsonWriter): String {
    let features = ArrayList<JsonWriteFeature>()
    features.add(PrettyPrint)
    let w = JsonWriter(features: features)
    block(w.beginArray()).endArray()
    w.close()
}

/// Build a pretty-printed JSON array with initial capacity.
public func buildJsonArrayPretty(initialCapacity: Int64, block: (JsonWriter) -> JsonWriter): String {
    let features = ArrayList<JsonWriteFeature>()
    features.add(PrettyPrint)
    let w = JsonWriter(initialCapacity: initialCapacity, features: features)
    block(w.beginArray()).endArray()
    w.close()
}
