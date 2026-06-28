package seajson

// ============================================================================
// JSON Text Escaping Utilities
// ============================================================================
//
// Low-level string escaping utilities for JSON encoding. Handles:
//   - Control characters (\b, \f, \n, \r, \t)
//   - Quote and backslash escaping
//   - Unicode escape sequences for control codes (U+0000 to U+001F)
//
// These functions are used internally by JsonWriter and jsonValueToString.
// Most users should prefer the higher-level APIs:
//   - jsonStringLiteral() for wrapping strings in quotes
//   - JsonWriter for streaming JSON generation
//
// ============================================================================

/// Escape a string for embedding in JSON text (without surrounding quotes).
///
/// Transforms special characters according to RFC 8259:
///   - Backslash (\\) -> \\
///   - Double quote (") -> \"
///   - Backspace -> \b
///   - Form feed -> \f
///   - Newline -> \n
///   - Carriage return -> \r
///   - Tab -> \t
///   - Control codes U+0000-U+001F -> \u00XX
///
/// Unicode characters outside the ASCII range are passed through unchanged.
///
/// Parameters:
///   value: The raw string to escape
///
/// Returns: The escaped string (without surrounding quotes)
///
/// Example:
///   escapeJsonText("hello\nworld")  // returns "hello\\nworld"
public func escapeJsonText(value: String): String {
    // Fast path: check if escaping is needed
    let bytes = value.toArray()
    var needsEscape = false
    var i: Int64 = 0
    while (i < bytes.size) {
        let b = bytes[i]
        if (b < 0x20 || b == 0x5C || b == 0x22) {
            needsEscape = true
            break
        }
        i += 1
    }
    if (!needsEscape) {
        return value
    }

    // Slow path: build escaped string
    let out = StringBuilder()
    for (r in value.toRuneArray()) {
        out.append(escapeJsonRune(r))
    }
    out.toString()
}

/// Wrap a string in double quotes with proper JSON escaping.
///
/// This is the primary function for creating JSON string literals.
/// It applies escapeJsonText() and adds surrounding double quotes.
///
/// Parameters:
///   value: The raw string value
///
/// Returns: A valid JSON string literal including quotes
///
/// Example:
///   jsonStringLiteral("hello")  // returns "\"hello\""
///   jsonStringLiteral("say \"hi\"")  // returns "\"say \\\"hi\\\"\""
public func jsonStringLiteral(value: String): String {
    "\"" + escapeJsonText(value) + "\""
}

/// Escape a single Unicode rune for JSON text.
/// Internal helper used by escapeJsonText.
public func escapeJsonRune(r: Rune): String {
    let cp = Int64(UInt32(r))
    if (cp < 0x20) {
        // Control characters - use named escapes where available
        if (r == r'\b') { return "\\b" }
        if (r == r'\t') { return "\\t" }
        if (r == r'\n') { return "\\n" }
        if (r == r'\f') { return "\\f" }
        if (r == r'\r') { return "\\r" }
        // Other control codes use \u00XX
        return "\\u00" + byteToLowerHex(UInt8(cp))
    }
    if (r == r'\\') { return "\\\\" }
    if (r == r'"') { return "\\\"" }
    r.toString()
}

/// Convert a byte value to two lowercase hex digits.
/// Used for \u00XX escape sequences.
func byteToLowerHex(value: UInt8): String {
    let hexChars = "0123456789abcdef".toRuneArray()
    let n = Int64(value)
    hexChars[n >> 4].toString() + hexChars[n & 0x0F].toString()
}
