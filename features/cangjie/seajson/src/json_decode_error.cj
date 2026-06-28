package seajson

// ============================================================================
// JSON Decode Error
// ============================================================================
//
// Structured error model for JSON decoding failures.
// Provides path, position, and category information so that callers
// can produce meaningful diagnostics.
//
// ## Error Categories
//   - JsonErrSyntax: Malformed JSON structure (unexpected tokens, unclosed strings)
//   - JsonErrType: Type mismatch (expected number, got string)
//   - JsonErrMissingField: Required field not present in object
//   - JsonErrTrailing: Unexpected content after valid JSON
//   - JsonErrDepth: Nesting depth exceeded
//   - JsonErrEOF: Unexpected end of input
//   - JsonErrOther: Catch-all for other errors
//
// ## Usage
//   try {
//       let v = parseJson(input)
//   } catch (e: JsonDecodeError) {
//       println("${e.kindName} at ${e.path}: ${e.message}")
//       // Example output: "SyntaxError at $.user.name at line 42:10"
//   }
//
// ============================================================================

import std.collection.ArrayList

// ── Error category ───────────────────────────────────────────

/// Categories of JSON decoding errors.
///
/// Each category represents a distinct class of parsing or decoding failure,
/// enabling programmatic error handling based on error type.
public enum JsonErrorKind {
    | JsonErrSyntax        // Malformed JSON (unexpected token, unclosed string, etc.)
    | JsonErrType          // Type mismatch (expected number, got string)
    | JsonErrMissingField  // Required field not present
    | JsonErrTrailing      // Unexpected content after valid JSON
    | JsonErrDepth         // Nesting depth exceeded
    | JsonErrEOF           // Unexpected end of input
    | JsonErrOther         // Catch-all for other errors
}

// ── JsonDecodeError ──────────────────────────────────────────

/// Exception thrown when JSON parsing or decoding fails.
///
/// Provides structured information about the error including:
///   - kind: The category of error
///   - path: JSON path to the error location (e.g., "$.user.name")
///   - offset: Byte offset in the input (-1 if unknown)
///   - line: 1-based line number (-1 if unknown)
///   - column: 1-based column number (-1 if unknown)
///
/// Example error message:
///   "SyntaxError: unexpected character at line 42:10 path=$.users[3].name"
public class JsonDecodeError <: Exception {
    public let kind: JsonErrorKind
    public let path: String        // e.g. "$.user.name"
    public let offset: Int64       // byte offset in input (-1 if unknown)
    public let line: Int64         // 1-based line number (-1 if unknown)
    public let column: Int64       // 1-based column number (-1 if unknown)

    public init(
        kind: JsonErrorKind,
        message: String,
        path!: String = "$",
        offset!: Int64 = -1,
        line!: Int64 = -1,
        column!: Int64 = -1
    ) {
        super(JsonDecodeError.formatMessage(kind, message, path, offset, line, column))
        this.kind = kind
        this.path = path
        this.offset = offset
        this.line = line
        this.column = column
    }

    public static func formatMessage(
        kind: JsonErrorKind,
        message: String,
        path: String,
        offset: Int64,
        line: Int64,
        column: Int64
    ): String {
        var loc = ""
        if (line >= 0 && column >= 0) {
            loc = " at line ${line}:${column}"
        } else {
            if (offset >= 0) {
                loc = " at offset ${offset}"
            }
        }
        let pathInfo = if (path == "$") { "" } else { " path=${path}" }
        "${kindStr(kind)}: ${message}${loc}${pathInfo}"
    }

    public prop kindName: String {
        get() { kindStr(kind) }
    }
}

func kindStr(k: JsonErrorKind): String {
    match (k) {
        case JsonErrSyntax => "SyntaxError"
        case JsonErrType => "TypeError"
        case JsonErrMissingField => "MissingField"
        case JsonErrTrailing => "TrailingContent"
        case JsonErrDepth => "DepthError"
        case JsonErrEOF => "UnexpectedEOF"
        case JsonErrOther => "Error"
    }
}

// ── Path builder for nested error reporting ──────────────────

class JsonPathBuilder {
    private var segments: ArrayList<String> = ArrayList<String>()

    public func pushKey(key: String): Unit {
        segments.add("." + key)
    }

    public func pushIndex(index: Int64): Unit {
        segments.add("[${index}]")
    }

    public func pop(): Unit {
        if (segments.size > 0) {
            segments.remove(at: segments.size - 1)
        }
    }

    public func toString(): String {
        var out = "$"
        var i: Int64 = 0
        while (i < segments.size) {
            out += segments[i]
            i += 1
        }
        out
    }
}
