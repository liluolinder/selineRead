package seajson

// ============================================================================
// Native JSON Reader / Parser
// ============================================================================
//
// A hand-written recursive-descent JSON parser that produces JsonValue trees.
// Zero stdx dependency — pure std + SeaJson.
//
// ## Features
//   - RFC 8259 compliant parsing
//   - Detailed error reporting with path and position information
//   - Support for Unicode escape sequences including surrogate pairs
//   - Efficient number parsing (int vs float discrimination)
//
// ## Usage
//   let json = "{\"name\":\"Alice\",\"age\":30}"
//   let value = parseJson(json)
//
//   // Or with error handling:
//   match (tryParseJson(input)) {
//       case Some(v) => process(v)
//       case None => println("Invalid JSON")
//   }
//
// ## Error Handling
//   try {
//       let v = parseJson(input)
//   } catch (e: JsonDecodeError) {
//       println("${e.kindName} at ${e.path}: ${e.message}")
//   }
//
// ============================================================================

import std.collection.ArrayList

// ── Character constants (UInt8) ──────────────────────────────
// Cangjie String[i] returns UInt8; compare with numeric values.
// These constants avoid repeated character-to-UInt8 conversions.

let CH_SPACE: UInt8 = 32     // ' '
let CH_TAB: UInt8 = 9        // '\t'
let CH_NL: UInt8 = 10        // '\n'
let CH_CR: UInt8 = 13        // '\r'
let CH_QUOTE: UInt8 = 34     // '"'
let CH_BACKSLASH: UInt8 = 92 // '\\'
let CH_LBRACE: UInt8 = 123   // '{'
let CH_RBRACE: UInt8 = 125   // '}'
let CH_LBRACKET: UInt8 = 91  // '['
let CH_RBRACKET: UInt8 = 93  // ']'
let CH_COLON: UInt8 = 58     // ':'
let CH_COMMA: UInt8 = 44     // ','
let CH_MINUS: UInt8 = 45     // '-'
let CH_PLUS: UInt8 = 43      // '+'
let CH_DOT: UInt8 = 46       // '.'
let CH_E_LOWER: UInt8 = 101  // 'e'
let CH_E_UPPER: UInt8 = 69   // 'E'
let CH_u: UInt8 = 117        // 'u'
let CH_0: UInt8 = 48         // '0'
let CH_1: UInt8 = 49         // '1'
let CH_9: UInt8 = 57         // '9'
let CH_a: UInt8 = 97
let CH_z: UInt8 = 122
let CH_A: UInt8 = 65
let CH_Z: UInt8 = 90
let CH_f: UInt8 = 102
let CH_F: UInt8 = 70
let CH_t: UInt8 = 116
let CH_n: UInt8 = 110
let CH_l: UInt8 = 108        // 'l' (null)
let CH_SLASH: UInt8 = 47     // '/'
let CH_ASTERISK: UInt8 = 42  // '*' (for block comments)
let CH_b: UInt8 = 98
let CH_r: UInt8 = 114
let CH_e: UInt8 = 101  // 'e'
let CH_s: UInt8 = 115  // 's'
let CH_UNDERSCORE: UInt8 = 95
let CH_SINGLE_QUOTE: UInt8 = 39 // '\''

// ── JsonReader ───────────────────────────────────────────────

/// A streaming JSON parser that reads a JSON string and produces a JsonValue tree.
///
/// JsonReader implements a recursive-descent parser following RFC 8259 specification.
/// It tracks position (line, column) and JSON path for detailed error reporting.
///
/// Example:
///   let reader = JsonReader("{\"key\": \"value\"}")
///   let value = reader.read()  // JsonObjVal containing the parsed object
///
/// Thread-safety: Not thread-safe. Use separate instances for concurrent parsing.
public class JsonReader {
    private let src: String
    private var pos: Int64 = 0
    private var line: Int64 = 1
    private var col: Int64 = 1
    private let pathBuilder: JsonPathBuilder = JsonPathBuilder()
    private let features: ArrayList<JsonReadFeature>

    /// Create a new JsonReader for the given JSON string.
    /// The input string is not modified; parsing is read-only.
    public init(src: String) {
        this.src = src
        this.features = ArrayList<JsonReadFeature>()
    }

    /// Create a new JsonReader with feature flags enabled.
    /// Features control leniency in parsing (e.g., AllowTrailingComma, AllowComments).
    public init(src: String, features: ArrayList<JsonReadFeature>) {
        this.src = src
        this.features = features
    }

    // ── Feature helpers ────────────────────────────────────────

    private func hasFeature(f: JsonReadFeature): Bool {
        hasReadFeature(features, f)
    }

    // ── Public API ───────────────────────────────────────────

    /// Parse the entire JSON input and return the root JsonValue.
    ///
    /// Throws JsonDecodeError on parse failures including:
    ///   - JsonErrSyntax: malformed JSON structure
    ///   - JsonErrEOF: unexpected end of input
    ///   - JsonErrTrailing: content after valid JSON
    ///
    /// Returns: The parsed JsonValue (JsonNull, JsonBoolVal, JsonIntVal, JsonFloatVal,
    ///          JsonStrVal, JsonArrVal, or JsonObjVal)
    public func read(): JsonValue {
        skipWhitespace()
        if (pos >= src.size) {
            throwDecodeError(JsonErrEOF, "unexpected end of input")
        }
        let val = readValue()
        skipWhitespace()
        if (pos < src.size) {
            throwDecodeError(JsonErrTrailing, "unexpected content after valid JSON")
        }
        val
    }

    // ── Value dispatch ───────────────────────────────────────

    private func readValue(): JsonValue {
        if (pos >= src.size) {
            throwDecodeError(JsonErrEOF, "unexpected end of input")
        }
        let ch = peek()
        if (ch == CH_LBRACE) { return readObject() }
        if (ch == CH_LBRACKET) { return readArray() }
        if (ch == CH_QUOTE) { return readString() }
        if (hasFeature(AllowSingleQuotes) && ch == CH_SINGLE_QUOTE) { return readString() }
        if (ch == CH_t || ch == CH_f) { return readBool() }
        if (ch == CH_n) { return readNull() }
        if (ch == CH_MINUS || (ch >= CH_0 && ch <= CH_9)) { return readNumber() }
        throwDecodeError(JsonErrSyntax, "unexpected character")
    }

    // ── Object ───────────────────────────────────────────────

    private func readObject(): JsonValue {
        expect(CH_LBRACE)
        let entries = ArrayList<(String, JsonValue)>()
        skipWhitespace()
        if (peek() != CH_RBRACE) {
            let key = readKey()
            pathBuilder.pushKey(key)
            expect(CH_COLON)
            skipWhitespace()
            let val = readValue()
            entries.add((key, val))
            pathBuilder.pop()
            skipWhitespace()
            while (peek() == CH_COMMA) {
                advance()
                skipWhitespace()
                // AllowTrailingComma: check if comma is followed by }
                if (hasFeature(AllowTrailingComma) && peek() == CH_RBRACE) {
                    break
                }
                let k2 = readKey()
                pathBuilder.pushKey(k2)
                expect(CH_COLON)
                skipWhitespace()
                let v2 = readValue()
                entries.add((k2, v2))
                pathBuilder.pop()
                skipWhitespace()
            }
        }
        expect(CH_RBRACE)
        JsonObjVal(entries)
    }

    // ── Array ────────────────────────────────────────────────

    private func readArray(): JsonValue {
        expect(CH_LBRACKET)
        let items = ArrayList<JsonValue>()
        skipWhitespace()
        if (peek() != CH_RBRACKET) {
            pathBuilder.pushIndex(0)
            items.add(readValue())
            pathBuilder.pop()
            skipWhitespace()
            var idx: Int64 = 1
            while (peek() == CH_COMMA) {
                advance()
                skipWhitespace()
                // AllowTrailingComma: check if comma is followed by ]
                if (hasFeature(AllowTrailingComma) && peek() == CH_RBRACKET) {
                    break
                }
                pathBuilder.pushIndex(idx)
                items.add(readValue())
                pathBuilder.pop()
                skipWhitespace()
                idx += 1
            }
        }
        expect(CH_RBRACKET)
        JsonArrVal(items)
    }

    // ── String ───────────────────────────────────────────────

    private func readString(): JsonValue {
        JsonStrVal(readStringRaw())
    }

    private func readKey(): String {
        skipWhitespace()
        // AllowSingleQuotes: also accept single-quoted keys
        if (hasFeature(AllowSingleQuotes) && peek() == CH_SINGLE_QUOTE) {
            readStringRaw()
        } else {
            readStringRaw()
        }
    }

    private func readStringRaw(): String {
        // Determine quote character
        let firstChar = peek()
        let quoteChar: UInt8 = if (hasFeature(AllowSingleQuotes) && firstChar == CH_SINGLE_QUOTE) {
            advance()
            CH_SINGLE_QUOTE
        } else {
            expect(CH_QUOTE)
            CH_QUOTE
        }

        // Fast path: scan for end quote without escapes
        let start = pos
        var needsEscape = false
        while (pos < src.size) {
            let ch = src[pos]
            if (ch == quoteChar) {
                if (!needsEscape) {
                    // Fast path: no escapes, directly slice the string
                    let result = src[start..pos]
                    pos += 1  // skip closing quote
                    return result
                }
                break  // Fall through to slow path
            }
            if (ch == CH_BACKSLASH) {
                needsEscape = true
                // Continue to find the end quote
            }
            pos += 1
        }

        // Reset position for slow path
        pos = start

        // Slow path: handle escapes
        let buf = ArrayList<UInt8>()
        while (pos < src.size) {
            let ch = advance()
            if (ch == quoteChar) {
                return bytesToString(buf)
            }
            if (ch == CH_BACKSLASH) {
                if (pos >= src.size) {
                    throwDecodeError(JsonErrEOF, "unterminated escape in string")
                }
                let esc = advance()
                if (esc == CH_QUOTE) { buf.add(CH_QUOTE) }
                else if (esc == CH_BACKSLASH) { buf.add(CH_BACKSLASH) }
                else if (esc == CH_SLASH) { buf.add(CH_SLASH) }
                else if (esc == CH_b) { buf.add(8) }   // \b = 0x08
                else if (esc == CH_f) { buf.add(12) }  // \f = 0x0C
                else if (esc == CH_n) { buf.add(CH_NL) }
                else if (esc == CH_r) { buf.add(CH_CR) }
                else if (esc == CH_t) { buf.add(CH_TAB) }
                else if (esc == CH_u) {
                    let escaped = readUnicodeEscape()
                    let escapedBytes = escaped.toArray()
                    var j: Int64 = 0
                    while (j < escapedBytes.size) {
                        buf.add(escapedBytes[j])
                        j += 1
                    }
                }
                // AllowSingleQuotes: escaped single quote
                else if (esc == CH_SINGLE_QUOTE && hasFeature(AllowSingleQuotes)) {
                    buf.add(CH_SINGLE_QUOTE)
                }
                else { throwDecodeError(JsonErrSyntax, "invalid escape sequence") }
            } else {
                buf.add(ch)
            }
        }
        throwDecodeError(JsonErrEOF, "unterminated string")
    }

    // Optimized: use toArray() instead of manual loop
    private func bytesToString(buf: ArrayList<UInt8>): String {
        String.fromUtf8(buf.toArray())
    }

    private func readUnicodeEscape(): String {
        if (pos + 4 > src.size) {
            throwDecodeError(JsonErrEOF, "unterminated unicode escape")
        }
        var hex: Int64 = 0
        var i: Int64 = 0
        while (i < 4) {
            let ch = advance()
            let digit = hexDigit(ch)
            if (digit < 0) {
                throwDecodeError(JsonErrSyntax, "invalid hex digit in unicode escape")
            }
            hex = hex * 16 + digit
            i += 1
        }
        // Handle surrogate pairs
        if (hex >= 0xD800 && hex <= 0xDBFF) {
            if (pos + 6 <= src.size && src[pos] == CH_BACKSLASH && src[pos + 1] == CH_u) {
                advance() // skip '\'
                advance() // skip 'u'
                var lowHex: Int64 = 0
                var j: Int64 = 0
                while (j < 4) {
                    let ch2 = advance()
                    let d2 = hexDigit(ch2)
                    if (d2 < 0) {
                        throwDecodeError(JsonErrSyntax, "invalid hex digit in low surrogate")
                    }
                    lowHex = lowHex * 16 + d2
                    j += 1
                }
                if (lowHex >= 0xDC00 && lowHex <= 0xDFFF) {
                    let codePoint = 0x10000 + (hex - 0xD800) * 0x400 + (lowHex - 0xDC00)
                    return codePointToString(codePoint)
                }
                // Not a valid low surrogate — emit FFFD for the lone high surrogate
                // and the BMP character from the second escape
                return "\u{FFFD}" + codePointToString(lowHex)
            }
            return "\u{FFFD}"
        }
        codePointToString(hex)
    }

    // ── Number ───────────────────────────────────────────────

    private func readNumber(): JsonValue {
        let start = pos
        var isFloatVal = false
        let negative = peek() == CH_MINUS
        if (negative) { advance() }

        // Fast path: single-digit integers 0-9
        if (!negative && pos < src.size && peek() >= CH_0 && peek() <= CH_9) {
            let digit = Int64(peek()) - Int64(CH_0)
            let nextPos = pos + 1
            if (nextPos >= src.size || 
                (src[nextPos] != CH_DOT && src[nextPos] != CH_E_LOWER && src[nextPos] != CH_E_UPPER &&
                 !isDigit(src[nextPos]))) {
                advance()
                return JsonIntVal(digit)
            }
        }

        // Fast path: two-digit integers 10-99
        if (!negative && pos + 1 < src.size && 
            peek() >= CH_1 && peek() <= CH_9 &&
            src[pos + 1] >= CH_0 && src[pos + 1] <= CH_9) {
            let d1 = Int64(peek()) - Int64(CH_0)
            let d2 = Int64(src[pos + 1]) - Int64(CH_0)
            let nextPos = pos + 2
            if (nextPos >= src.size ||
                (src[nextPos] != CH_DOT && src[nextPos] != CH_E_LOWER && src[nextPos] != CH_E_UPPER &&
                 !isDigit(src[nextPos]))) {
                pos += 2
                return JsonIntVal(d1 * 10 + d2)
            }
        }

        if (pos < src.size && peek() == CH_0) {
            advance()
        } else {
            readDigits()
        }

        if (pos < src.size && peek() == CH_DOT) {
            isFloatVal = true
            advance()
            readDigits()
        }

        if (pos < src.size && (peek() == CH_E_LOWER || peek() == CH_E_UPPER)) {
            isFloatVal = true
            advance()
            if (pos < src.size && (peek() == CH_PLUS || peek() == CH_MINUS)) {
                advance()
            }
            readDigits()
        }

        let numStr = src[start..pos]
        if (isFloatVal) {
            JsonFloatVal(parseFloat(numStr))
        } else {
            JsonIntVal(parseInt(numStr))
        }
    }

    private func isDigit(ch: UInt8): Bool {
        ch >= CH_0 && ch <= CH_9
    }

    // ── Bool ─────────────────────────────────────────────────

    private func readBool(): JsonValue {
        if (matchKeyword("true")) {
            JsonBoolVal(true)
        } else if (matchKeyword("false")) {
            JsonBoolVal(false)
        } else {
            throwDecodeError(JsonErrSyntax, "expected 'true' or 'false'")
        }
    }

    // ── Null ─────────────────────────────────────────────────

    private func readNull(): JsonValue {
        if (matchKeyword("null")) {
            JsonNull
        } else {
            throwDecodeError(JsonErrSyntax, "expected 'null'")
        }
    }

    // ── Helpers ──────────────────────────────────────────────

    private func peek(): UInt8 {
        if (pos >= src.size) {
            throwDecodeError(JsonErrEOF, "unexpected end of input")
        }
        src[pos]
    }

    private func advance(): UInt8 {
        if (pos >= src.size) {
            throwDecodeError(JsonErrEOF, "unexpected end of input")
        }
        let ch = src[pos]
        pos += 1
        if (ch == CH_NL) {
            line += 1
            col = 1
        } else {
            col += 1
        }
        ch
    }

    private func expect(ch: UInt8): Unit {
        skipWhitespace()
        let got = advance()
        if (got != ch) {
            throwDecodeError(JsonErrSyntax, "expected character")
        }
    }

    private func skipWhitespace(): Unit {
        while (pos < src.size) {
            let ch = src[pos]
            if (ch == CH_SPACE || ch == CH_TAB || ch == CH_NL || ch == CH_CR) {
                pos += 1
                if (ch == CH_NL) {
                    line += 1
                    col = 1
                } else {
                    col += 1
                }
            } else if (hasFeature(AllowComments) && ch == CH_SLASH) {
                skipComment()
            } else {
                break
            }
        }
    }

    // ── Comment handling (AllowComments) ──────────────────────

    private func skipComment(): Unit {
        if (pos >= src.size) { return }
        if (src[pos] != CH_SLASH) { return }
        pos += 1
        col += 1

        if (pos >= src.size) {
            throwDecodeError(JsonErrSyntax, "unexpected end of input in comment")
        }

        let ch = src[pos]
        if (ch == CH_SLASH) {
            // Single-line comment: // ... \n
            pos += 1
            col += 1
            while (pos < src.size && src[pos] != CH_NL) {
                pos += 1
                col += 1
            }
            // The newline will be consumed by skipWhitespace on next iteration
        } else if (ch == CH_ASTERISK) {
            // Multi-line comment: /* ... */
            pos += 1
            col += 1
            var closed = false
            while (pos < src.size) {
                let c = src[pos]
                pos += 1
                if (c == CH_NL) {
                    line += 1
                    col = 1
                } else {
                    col += 1
                }
                if (c == CH_ASTERISK && pos < src.size && src[pos] == CH_SLASH) {
                    pos += 1
                    col += 1
                    closed = true
                    break
                }
            }
            if (!closed) {
                throwDecodeError(JsonErrSyntax, "unterminated block comment")
            }
        } else {
            throwDecodeError(JsonErrSyntax, "invalid comment syntax")
        }
    }

    private func readDigits(): Unit {
        if (pos >= src.size || src[pos] < CH_0 || src[pos] > CH_9) {
            throwDecodeError(JsonErrSyntax, "expected digit")
        }
        while (pos < src.size && src[pos] >= CH_0 && src[pos] <= CH_9) {
            advance()
        }
    }

    private func matchKeyword(kw: String): Bool {
        let kwArr = kw.toArray()
        if (pos + kwArr.size > src.size) {
            return false
        }
        var i: Int64 = 0
        while (i < kwArr.size) {
            if (src[pos + i] != kwArr[i]) {
                return false
            }
            i += 1
        }
        // Ensure keyword is not part of a longer identifier
        let afterEnd = pos + kwArr.size
        if (afterEnd < src.size) {
            let next = src[afterEnd]
            // Reject if followed by alphanumeric or underscore
            if ((next >= CH_a && next <= CH_z) || (next >= CH_A && next <= CH_Z) ||
                (next >= CH_0 && next <= CH_9) || next == CH_UNDERSCORE) {
                return false
            }
        }
        pos += kwArr.size
        col += kwArr.size
        true
    }

    private func hexDigit(ch: UInt8): Int64 {
        if (ch >= CH_0 && ch <= CH_9) { Int64(ch) - Int64(CH_0) }
        else if (ch >= CH_a && ch <= CH_f) { Int64(ch) - Int64(CH_a) + 10 }
        else if (ch >= CH_A && ch <= CH_F) { Int64(ch) - Int64(CH_A) + 10 }
        else { -1 }
    }

    private func parseInt(s: String): Int64 {
        var neg = false
        var i: Int64 = 0
        if (i < s.size && s[i] == CH_MINUS) {
            neg = true
            i += 1
        }
        var n: Int64 = 0
        while (i < s.size) {
            let d = Int64(s[i]) - Int64(CH_0)
            n = n * 10 + d
            i += 1
        }
        if (neg) { -n } else { n }
    }

    private func parseFloat(s: String): Float64 {
        var result: Float64 = 0.0
        var i: Int64 = 0
        var neg = false
        if (i < s.size && s[i] == CH_MINUS) {
            neg = true
            i += 1
        }
        while (i < s.size && s[i] >= CH_0 && s[i] <= CH_9) {
            result = result * 10.0 + Float64(Int64(s[i]) - Int64(CH_0))
            i += 1
        }
        if (i < s.size && s[i] == CH_DOT) {
            i += 1
            var frac: Float64 = 0.1
            while (i < s.size && s[i] >= CH_0 && s[i] <= CH_9) {
                result += frac * Float64(Int64(s[i]) - Int64(CH_0))
                frac *= 0.1
                i += 1
            }
        }
        if (i < s.size && (s[i] == CH_E_LOWER || s[i] == CH_E_UPPER)) {
            i += 1
            var expNeg = false
            if (i < s.size && s[i] == CH_MINUS) {
                expNeg = true
                i += 1
            } else if (i < s.size && s[i] == CH_PLUS) {
                i += 1
            }
            var exp: Int64 = 0
            while (i < s.size && s[i] >= CH_0 && s[i] <= CH_9) {
                exp = exp * 10 + (Int64(s[i]) - Int64(CH_0))
                i += 1
            }
            var expF: Float64 = 1.0
            var e: Int64 = 0
            while (e < exp) {
                expF *= 10.0
                e += 1
            }
            if (expNeg) { result /= expF } else { result *= expF }
        }
        if (neg) { -result } else { result }
    }

    private func throwDecodeError(kind: JsonErrorKind, msg: String): Nothing {
        throw JsonDecodeError(kind, msg, path: pathBuilder.toString(), offset: pos - 1, line: line, column: col)
    }

    private func codePointToString(cp: Int64): String {
        if (cp < 0x80) {
            let arr = Array<UInt8>(1, repeat: UInt8(cp))
            String.fromUtf8(arr)
        } else if (cp < 0x800) {
            let arr = Array<UInt8>(2, repeat: 0)
            arr[0] = UInt8(0xC0 | (cp >> 6))
            arr[1] = UInt8(0x80 | (cp & 0x3F))
            String.fromUtf8(arr)
        } else if (cp < 0x10000) {
            let arr = Array<UInt8>(3, repeat: 0)
            arr[0] = UInt8(0xE0 | (cp >> 12))
            arr[1] = UInt8(0x80 | ((cp >> 6) & 0x3F))
            arr[2] = UInt8(0x80 | (cp & 0x3F))
            String.fromUtf8(arr)
        } else {
            // 4-byte UTF-8 for code points U+10000..U+10FFFF (surrogate pair result)
            let arr = Array<UInt8>(4, repeat: 0)
            arr[0] = UInt8(0xF0 | (cp >> 18))
            arr[1] = UInt8(0x80 | ((cp >> 12) & 0x3F))
            arr[2] = UInt8(0x80 | ((cp >> 6) & 0x3F))
            arr[3] = UInt8(0x80 | (cp & 0x3F))
            String.fromUtf8(arr)
        }
    }
}

// ── Top-level convenience ────────────────────────────────────

/// Parse a JSON string and return the root JsonValue.
///
/// This is the primary entry point for JSON parsing. It creates a JsonReader
/// internally and parses the entire input.
///
/// Parameters:
///   json: A valid JSON string (object, array, or primitive value)
///
/// Returns: The parsed JsonValue tree
///
/// Throws: JsonDecodeError if the input is not valid JSON
///
/// Example:
///   let obj = parseJson("{\"name\": \"Alice\"}")
///   let name = jsonFieldString(obj, "name")  // Some("Alice")
public func parseJson(json: String): JsonValue {
    let reader = JsonReader(json)
    reader.read()
}

/// Parse a JSON string with feature flags enabled.
///
/// Feature flags allow lenient parsing of non-standard JSON constructs.
///
/// Parameters:
///   json: A JSON string
///   features: Feature flags to enable (e.g., AllowTrailingComma, AllowComments)
///
/// Returns: The parsed JsonValue tree
///
/// Example:
///   let features = ArrayList<JsonReadFeature>()
///   features.add(AllowTrailingComma)
///   let arr = parseJson("[1,2,]", features)  // Valid with AllowTrailingComma
public func parseJson(json: String, features: ArrayList<JsonReadFeature>): JsonValue {
    let reader = JsonReader(json, features)
    reader.read()
}

/// Try to parse a JSON string, returning None on failure instead of throwing.
///
/// Use this when you want to handle parse errors gracefully without exceptions.
///
/// Parameters:
///   json: A string that may or may not be valid JSON
///
/// Returns: Some(JsonValue) on success, None on any parse error
///
/// Example:
///   match (tryParseJson(input)) {
///       case Some(v) => processValidJson(v)
///       case None => println("Invalid JSON input")
///   }
public func tryParseJson(json: String): ?JsonValue {
    try {
        Some(parseJson(json))
    } catch (_) {
        None
    }
}

/// Try to parse a JSON string with feature flags, returning None on failure.
public func tryParseJson(json: String, features: ArrayList<JsonReadFeature>): ?JsonValue {
    try {
        Some(parseJson(json, features))
    } catch (_) {
        None
    }
}

// ============================================================================
// Zero-copy Parser (parseJsonView)
// ============================================================================

/// Parse a JSON string into a zero-copy JsonValueView.
///
/// Unlike parseJson(), this function returns a view that references slices
/// of the original JSON string for all string values, avoiding memory allocation
/// for strings until explicitly converted via toString().
///
/// Parameters:
///   json: A JSON string (must remain valid for the lifetime of the returned view)
///
/// Returns: The parsed JsonValueView tree
///
/// Example:
///   let json = "{\"name\":\"Alice\",\"age\":30}"
///   let view = parseJsonView(json)
///   let name = jsonFieldStringView(view, "name")  // StringView, no copy
///   println(name.get().toString())  // "Alice" - copy only when needed
public func parseJsonView(json: String): JsonValueView {
    let reader = JsonReaderView(json)
    reader.readView()
}

/// Parse a JSON string into a zero-copy JsonValueView with feature flags.
public func parseJsonView(json: String, features: ArrayList<JsonReadFeature>): JsonValueView {
    let reader = JsonReaderView(json, features)
    reader.readView()
}

/// Try to parse a JSON string into a zero-copy JsonValueView.
/// Returns None on any parse error.
public func tryParseJsonView(json: String): ?JsonValueView {
    try {
        Some(parseJsonView(json))
    } catch (_) {
        None
    }
}

/// Try to parse a JSON string into a zero-copy JsonValueView with feature flags.
public func tryParseJsonView(json: String, features: ArrayList<JsonReadFeature>): ?JsonValueView {
    try {
        Some(parseJsonView(json, features))
    } catch (_) {
        None
    }
}

/// Zero-copy JSON reader that produces JsonValueView trees.
///
/// JsonReaderView is similar to JsonReader but returns StringView instead
/// of String for all string values, avoiding memory allocation for string data.
public class JsonReaderView {
    private let src: String
    private var pos: Int64 = 0
    private var line: Int64 = 1
    private var col: Int64 = 1
    private let pathBuilder: JsonPathBuilder = JsonPathBuilder()
    private let features: ArrayList<JsonReadFeature>

    public init(src: String) {
        this.src = src
        this.features = ArrayList<JsonReadFeature>()
    }

    public init(src: String, features: ArrayList<JsonReadFeature>) {
        this.src = src
        this.features = features
    }

    private func hasFeature(f: JsonReadFeature): Bool {
        hasReadFeature(features, f)
    }

    /// Parse the entire JSON input and return a zero-copy JsonValueView.
    public func readView(): JsonValueView {
        skipWhitespace()
        if (pos >= src.size) {
            throwDecodeError(JsonErrEOF, "unexpected end of input")
        }
        let val = readValueView()
        skipWhitespace()
        if (pos < src.size) {
            throwDecodeError(JsonErrTrailing, "unexpected content after valid JSON")
        }
        val
    }

    private func readValueView(): JsonValueView {
        if (pos >= src.size) {
            throwDecodeError(JsonErrEOF, "unexpected end of input")
        }
        let ch = peek()
        if (ch == CH_LBRACE) { return readObjectView() }
        if (ch == CH_LBRACKET) { return readArrayView() }
        if (ch == CH_QUOTE) { return readStringView() }
        if (hasFeature(AllowSingleQuotes) && ch == CH_SINGLE_QUOTE) { return readStringView() }
        if (ch == CH_t || ch == CH_f) { return readBoolView() }
        if (ch == CH_n) { 
            // Consume "null" keyword
            expect(CH_n)
            expect(CH_u)
            expect(CH_l)
            expect(CH_l)
            return JsonNullView 
        }
        if (ch == CH_MINUS || (ch >= CH_0 && ch <= CH_9)) { return readNumberView() }
        throwDecodeError(JsonErrSyntax, "unexpected character")
    }

    private func readObjectView(): JsonValueView {
        expect(CH_LBRACE)
        let entries = ArrayList<(StringView, JsonValueView)>()
        skipWhitespace()
        if (peek() != CH_RBRACE) {
            let key = readKeyView()
            pathBuilder.pushKey(key.toString())
            expect(CH_COLON)
            skipWhitespace()
            let val = readValueView()
            entries.add((key, val))
            pathBuilder.pop()
            skipWhitespace()
            while (peek() == CH_COMMA) {
                advance()
                skipWhitespace()
                if (hasFeature(AllowTrailingComma) && peek() == CH_RBRACE) {
                    break
                }
                let k2 = readKeyView()
                pathBuilder.pushKey(k2.toString())
                expect(CH_COLON)
                skipWhitespace()
                let v2 = readValueView()
                entries.add((k2, v2))
                pathBuilder.pop()
                skipWhitespace()
            }
        }
        expect(CH_RBRACE)
        JsonObjViewVal(entries)
    }

    private func readArrayView(): JsonValueView {
        expect(CH_LBRACKET)
        let items = ArrayList<JsonValueView>()
        skipWhitespace()
        if (peek() != CH_RBRACKET) {
            pathBuilder.pushIndex(0)
            items.add(readValueView())
            pathBuilder.pop()
            skipWhitespace()
            var idx: Int64 = 1
            while (peek() == CH_COMMA) {
                advance()
                skipWhitespace()
                if (hasFeature(AllowTrailingComma) && peek() == CH_RBRACKET) {
                    break
                }
                pathBuilder.pushIndex(idx)
                items.add(readValueView())
                pathBuilder.pop()
                skipWhitespace()
                idx += 1
            }
        }
        expect(CH_RBRACKET)
        JsonArrViewVal(items)
    }

    private func readKeyView(): StringView {
        readStringViewRaw()
    }

    private func readStringView(): JsonValueView {
        JsonStrViewVal(readStringViewRaw())
    }

    /// Zero-copy string reading: returns a StringView instead of String.
    private func readStringViewRaw(): StringView {
        let firstChar = peek()
        let quoteChar: UInt8 = if (hasFeature(AllowSingleQuotes) && firstChar == CH_SINGLE_QUOTE) {
            advance()
            CH_SINGLE_QUOTE
        } else {
            expect(CH_QUOTE)
            CH_QUOTE
        }

        // Fast path: scan for end quote without escapes
        let start = pos
        var needsEscape = false
        while (pos < src.size) {
            let ch = src[pos]
            if (ch == quoteChar) {
                if (!needsEscape) {
                    // Zero-copy: return StringView of the slice
                    let result = StringView(src, start, pos - start)
                    pos += 1
                    return result
                }
                break
            }
            if (ch == CH_BACKSLASH) {
                needsEscape = true
            }
            pos += 1
        }

        // Slow path with escapes: must create a new string
        // Reset and use the original slow path
        pos = start
        let buf = ArrayList<UInt8>()
        while (pos < src.size) {
            let ch = advance()
            if (ch == quoteChar) {
                // Create StringView from the escaped string
                // Note: This does allocate, but only for strings with escapes
                let escapedStr = bytesToString(buf)
                return StringView(escapedStr, 0, escapedStr.size)
            }
            if (ch == CH_BACKSLASH) {
                if (pos >= src.size) {
                    throwDecodeError(JsonErrEOF, "unterminated escape in string")
                }
                let esc = advance()
                if (esc == CH_QUOTE) { buf.add(CH_QUOTE) }
                else if (esc == CH_BACKSLASH) { buf.add(CH_BACKSLASH) }
                else if (esc == CH_SLASH) { buf.add(CH_SLASH) }
                else if (esc == CH_b) { buf.add(8) }
                else if (esc == CH_f) { buf.add(12) }
                else if (esc == CH_n) { buf.add(CH_NL) }
                else if (esc == CH_r) { buf.add(CH_CR) }
                else if (esc == CH_t) { buf.add(CH_TAB) }
                else if (esc == CH_u) {
                    let escaped = readUnicodeEscape()
                    let escapedBytes = escaped.toArray()
                    var j: Int64 = 0
                    while (j < escapedBytes.size) {
                        buf.add(escapedBytes[j])
                        j += 1
                    }
                }
                else if (esc == CH_SINGLE_QUOTE && hasFeature(AllowSingleQuotes)) {
                    buf.add(CH_SINGLE_QUOTE)
                }
                else { throwDecodeError(JsonErrSyntax, "invalid escape sequence") }
            } else {
                buf.add(ch)
            }
        }
        throwDecodeError(JsonErrEOF, "unterminated string")
    }

    private func readNumberView(): JsonValueView {
        let start = pos
        var isFloatVal = false

        if (peek() == CH_MINUS) { advance() }

        if (pos < src.size && peek() == CH_0) {
            advance()
        } else {
            readDigits()
        }

        if (pos < src.size && peek() == CH_DOT) {
            isFloatVal = true
            advance()
            readDigits()
        }

        if (pos < src.size && (peek() == CH_E_LOWER || peek() == CH_E_UPPER)) {
            isFloatVal = true
            advance()
            if (pos < src.size && (peek() == CH_PLUS || peek() == CH_MINUS)) {
                advance()
            }
            readDigits()
        }

        let numStr = src[start..pos]
        if (isFloatVal) {
            JsonFloatViewVal(parseFloat(numStr))
        } else {
            JsonIntViewVal(parseInt(numStr))
        }
    }

    private func readBoolView(): JsonValueView {
        if (peek() == CH_t) {
            expect(CH_t)
            expect(CH_r)
            expect(CH_u)
            expect(CH_e)
            JsonBoolViewVal(true)
        } else {
            expect(CH_f)
            expect(CH_a)
            expect(CH_l)
            expect(CH_s)
            expect(CH_e)
            JsonBoolViewVal(false)
        }
    }

    // Reuse helper methods from JsonReader
    private func peek(): UInt8 { src[pos] }
    private func advance(): UInt8 {
        let ch = src[pos]
        pos += 1
        if (ch == CH_NL) { line += 1; col = 1 } else { col += 1 }
        ch
    }
    private func skipWhitespace() {
        while (pos < src.size) {
            let ch = src[pos]
            if (ch == CH_SPACE || ch == CH_TAB || ch == CH_NL || ch == CH_CR) {
                advance()
            } else if (ch == CH_SLASH && hasFeature(AllowComments)) {
                skipComment()
            } else {
                break
            }
        }
    }
    private func skipComment() {
        advance() // skip /
        let ch = advance()
        if (ch == CH_SLASH) {
            while (pos < src.size && src[pos] != CH_NL) { advance() }
        } else if (ch == CH_ASTERISK) {
            while (pos < src.size) {
                if (src[pos] == CH_ASTERISK && pos + 1 < src.size && src[pos + 1] == CH_SLASH) {
                    advance()
                    advance()
                    return
                }
                advance()
            }
            throwDecodeError(JsonErrEOF, "unterminated block comment")
        } else {
            throwDecodeError(JsonErrSyntax, "invalid comment")
        }
    }
    private func expect(ch: UInt8) {
        if (pos >= src.size || src[pos] != ch) {
            throwDecodeError(JsonErrSyntax, "expected '${String.fromUtf8(Array<UInt8>(1, repeat: ch))}'")
        }
        advance()
    }
    private func readDigits() {
        while (pos < src.size && src[pos] >= CH_0 && src[pos] <= CH_9) {
            advance()
        }
    }
    private func throwDecodeError(kind: JsonErrorKind, message: String): Nothing {
        throw JsonDecodeError(kind, message, path: pathBuilder.toString(), offset: pos - 1, line: line, column: col)
    }
    private func bytesToString(buf: ArrayList<UInt8>): String {
        let arr = Array<UInt8>(buf.size, repeat: 0)
        var i: Int64 = 0
        while (i < buf.size) {
            arr[i] = buf[i]
            i += 1
        }
        String.fromUtf8(arr)
    }
    
    // Number parsing helpers for JsonReaderView
    private func parseInt(s: String): Int64 {
        var neg = false
        var i: Int64 = 0
        if (i < s.size && s[i] == CH_MINUS) {
            neg = true
            i += 1
        }
        var n: Int64 = 0
        while (i < s.size) {
            n = n * 10 + Int64(s[i] - CH_0)
            i += 1
        }
        if (neg) { -n } else { n }
    }
    
    private func parseFloat(s: String): Float64 {
        var result: Float64 = 0.0
        var i: Int64 = 0
        var neg = false
        if (i < s.size && s[i] == CH_MINUS) {
            neg = true
            i += 1
        }
        // Integer part
        while (i < s.size && s[i] >= CH_0 && s[i] <= CH_9) {
            result = result * 10.0 + Float64(s[i] - CH_0)
            i += 1
        }
        // Fraction part
        if (i < s.size && s[i] == CH_DOT) {
            i += 1
            var divisor: Float64 = 10.0
            while (i < s.size && s[i] >= CH_0 && s[i] <= CH_9) {
                result = result + Float64(s[i] - CH_0) / divisor
                divisor *= 10.0
                i += 1
            }
        }
        // Exponent part
        if (i < s.size && (s[i] == CH_E_LOWER || s[i] == CH_E_UPPER)) {
            i += 1
            var expNeg = false
            if (i < s.size && s[i] == CH_MINUS) {
                expNeg = true
                i += 1
            } else if (i < s.size && s[i] == CH_PLUS) {
                i += 1
            }
            var exp: Int64 = 0
            while (i < s.size && s[i] >= CH_0 && s[i] <= CH_9) {
                exp = exp * 10 + Int64(s[i] - CH_0)
                i += 1
            }
            var multiplier: Float64 = 1.0
            var j: Int64 = 0
            while (j < exp) {
                multiplier *= 10.0
                j += 1
            }
            if (expNeg) {
                result = result / multiplier
            } else {
                result = result * multiplier
            }
        }
        if (neg) { -result } else { result }
    }
    
    private func readUnicodeEscape(): String {
        if (pos + 4 > src.size) {
            throwDecodeError(JsonErrEOF, "unterminated unicode escape")
        }
        var hex: Int64 = 0
        var i: Int64 = 0
        while (i < 4) {
            let ch = advance()
            let digit = hexDigit(ch)
            if (digit < 0) {
                throwDecodeError(JsonErrSyntax, "invalid hex digit in unicode escape")
            }
            hex = hex * 16 + digit
            i += 1
        }
        if (hex >= 0xD800 && hex <= 0xDBFF) {
            if (pos + 6 <= src.size && src[pos] == CH_BACKSLASH && src[pos + 1] == CH_u) {
                advance()
                advance()
                var lowHex: Int64 = 0
                var j: Int64 = 0
                while (j < 4) {
                    let ch2 = advance()
                    let d2 = hexDigit(ch2)
                    if (d2 < 0) {
                        throwDecodeError(JsonErrSyntax, "invalid hex digit in low surrogate")
                    }
                    lowHex = lowHex * 16 + d2
                    j += 1
                }
                if (lowHex >= 0xDC00 && lowHex <= 0xDFFF) {
                    let codePoint = 0x10000 + (hex - 0xD800) * 0x400 + (lowHex - 0xDC00)
                    return codePointToString(codePoint)
                }
                return "\u{FFFD}" + codePointToString(lowHex)
            }
            return "\u{FFFD}"
        }
        codePointToString(hex)
    }
    
    private func hexDigit(ch: UInt8): Int64 {
        if (ch >= CH_0 && ch <= CH_9) { Int64(ch - CH_0) }
        else if (ch >= CH_a && ch <= CH_f) { Int64(ch) - Int64(CH_a) + 10 }
        else if (ch >= CH_A && ch <= CH_F) { Int64(ch) - Int64(CH_A) + 10 }
        else { -1 }
    }
    
    private func codePointToString(cp: Int64): String {
        if (cp < 0x80) {
            return String.fromUtf8(Array<UInt8>(1, repeat: UInt8(cp)))
        } else if (cp < 0x800) {
            let arr = Array<UInt8>(2, repeat: 0)
            arr[0] = UInt8(0xC0 | (cp >> 6))
            arr[1] = UInt8(0x80 | (cp & 0x3F))
            return String.fromUtf8(arr)
        } else if (cp < 0x10000) {
            let arr = Array<UInt8>(3, repeat: 0)
            arr[0] = UInt8(0xE0 | (cp >> 12))
            arr[1] = UInt8(0x80 | ((cp >> 6) & 0x3F))
            arr[2] = UInt8(0x80 | (cp & 0x3F))
            return String.fromUtf8(arr)
        } else {
            let arr = Array<UInt8>(4, repeat: 0)
            arr[0] = UInt8(0xF0 | (cp >> 18))
            arr[1] = UInt8(0x80 | ((cp >> 12) & 0x3F))
            arr[2] = UInt8(0x80 | ((cp >> 6) & 0x3F))
            arr[3] = UInt8(0x80 | (cp & 0x3F))
            return String.fromUtf8(arr)
        }
    }
}
