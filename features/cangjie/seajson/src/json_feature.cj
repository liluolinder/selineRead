package seajson

// ============================================================================
// Feature Flags
// ============================================================================
//
// Configuration flags that control reader and writer behavior.
// Default behavior is strict RFC 8259 compliance; lenient behaviors
// must be explicitly enabled.
//
// Design influenced by Jackson's Feature pattern and fastjson2's
// Feature bit flags. Cangjie enums don't support bit flags, so
// we use ArrayList<JsonReadFeature> / ArrayList<JsonWriteFeature>
// for simple, correct feature sets.
//
// Note: Feature flags are currently defined but not all are implemented
// in the parser/writer. See individual feature documentation for status.
//
// ============================================================================

import std.collection.ArrayList

// ── Read features ──────────────────────────────────────────

/// Feature flags for JSON parsing behavior.
///
/// These flags control leniency in the parser, allowing it to accept
/// non-standard JSON that doesn't strictly conform to RFC 8259.
public enum JsonReadFeature {
    | AllowTrailingComma    // Allow trailing comma in objects/arrays: [1,2,]
                            // Status: IMPLEMENTED
    | AllowComments         // Allow // and /* */ comments in JSON
                            // Status: IMPLEMENTED
    | AllowSingleQuotes     // Allow single-quoted strings
                            // Status: IMPLEMENTED
    | Lenient               // Skip unknown fields, tolerate minor errors
                            // Status: NOT YET IMPLEMENTED
    | UseBigIntForLong      // Parse large integers as string-preserving form
                            // Status: NOT YET IMPLEMENTED
}

public func hasReadFeature(features: ArrayList<JsonReadFeature>, f: JsonReadFeature): Bool {
    var i: Int64 = 0
    while (i < features.size) {
        match (features[i]) {
            case _ => () // Cangjie enum comparison
        }
        i += 1
    }
    // Simpler: direct match loop
    i = 0
    while (i < features.size) {
        if (_readFeatureEq(features[i], f)) { return true }
        i += 1
    }
    false
}

func _readFeatureEq(a: JsonReadFeature, b: JsonReadFeature): Bool {
    match (a) {
        case AllowTrailingComma => match (b) { case AllowTrailingComma => true case _ => false }
        case AllowComments => match (b) { case AllowComments => true case _ => false }
        case AllowSingleQuotes => match (b) { case AllowSingleQuotes => true case _ => false }
        case Lenient => match (b) { case Lenient => true case _ => false }
        case UseBigIntForLong => match (b) { case UseBigIntForLong => true case _ => false }
    }
}

// ── Write features ─────────────────────────────────────────

/// Feature flags for JSON writing behavior.
///
/// These flags control formatting and special handling during serialization.
public enum JsonWriteFeature {
    | PrettyPrint           // Format with indentation and newlines for readability
                            // Status: IMPLEMENTED - see JsonWriter(pretty: true)
    | WriteNulls            // Write null-valued object fields (skip by default)
                            // Status: IMPLEMENTED - see nameWithNull(), nameValue()
    | EscapeNonAscii        // Escape all non-ASCII chars as \uXXXX sequences
                            // Status: IMPLEMENTED - see jsonStringLiteralEscapeNonAscii
    | EnumAsName            // Serialize enums by name instead of ordinal
                            // Status: NOT YET IMPLEMENTED
}

public func hasWriteFeature(features: ArrayList<JsonWriteFeature>, f: JsonWriteFeature): Bool {
    var i: Int64 = 0
    while (i < features.size) {
        if (_writeFeatureEq(features[i], f)) { return true }
        i += 1
    }
    false
}

func _writeFeatureEq(a: JsonWriteFeature, b: JsonWriteFeature): Bool {
    match (a) {
        case PrettyPrint => match (b) { case PrettyPrint => true case _ => false }
        case WriteNulls => match (b) { case WriteNulls => true case _ => false }
        case EscapeNonAscii => match (b) { case EscapeNonAscii => true case _ => false }
        case EnumAsName => match (b) { case EnumAsName => true case _ => false }
    }
}
