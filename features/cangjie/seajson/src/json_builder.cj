package seajson

// ============================================================================
// Simple JSON Builders
// ============================================================================
//
// Utility functions for manually constructing JSON strings without using
// the streaming JsonWriter API. Useful for simple cases where the full
// streaming API would be overkill.
//
// For complex JSON construction, prefer JsonWriter which provides:
//   - Streaming output (no intermediate string concatenation)
//   - Pretty-print support
//   - Nesting validation
//
// ============================================================================

import std.collection.ArrayList

/// Join a list of pre-formatted JSON field strings with commas.
///
/// Each field should already be formatted as "key": value.
/// Adds newlines between fields for readability.
///
/// Parameters:
///   fields: ArrayList of formatted field strings
///
/// Returns: The fields joined with commas and newlines
///
/// Example:
///   let fields = ArrayList<String>()
///   fields.add("\"name\": \"Alice\"")
///   fields.add("\"age\": 30")
///   joinJsonFields(fields)  // "\"name\": \"Alice\",\n\"age\": 30\n"
public func joinJsonFields(fields: ArrayList<String>): String {
    var out = ""
    var i: Int64 = 0
    while (i < fields.size) {
        out += fields[i]
        if (i < fields.size - 1) {
            out += ","
        }
        out += "\n"
        i += 1
    }
    out
}

/// Build a JSON object string from pre-formatted field strings.
///
/// Wraps the fields in curly braces. Each field should already be
/// formatted as a complete "key": value pair.
///
/// Parameters:
///   fields: ArrayList of formatted field strings
///
/// Returns: A complete JSON object string
///
/// Example:
///   let fields = ArrayList<String>()
///   fields.add(jsonStringField("name", "Alice"))
///   fields.add(jsonField("age", "30"))
///   jsonObject(fields)  // "{\n  \"name\": \"Alice\",\n  \"age\": 30\n}"
public func jsonObject(fields: ArrayList<String>): String {
    "{\n" + joinJsonFields(fields) + "}"
}

/// Format a single JSON field (key: value) with optional indentation.
///
/// Parameters:
///   name: The field name (will be JSON-escaped)
///   valueLiteral: The value as a string (NOT escaped; use jsonStringLiteral for strings)
///   indent: Indentation prefix (default: two spaces)
///
/// Returns: A formatted "key": value string
///
/// Example:
///   jsonField("count", "42")  // "  \"count\": 42"
///   jsonField("name", "\"Alice\"", indent: "    ")  // "    \"name\": \"Alice\""
public func jsonField(name: String, valueLiteral: String, indent!: String = "  "): String {
    indent + jsonStringLiteral(name) + ": " + valueLiteral
}

/// Format a string field (key: "value") with JSON escaping.
///
/// Convenience function that handles string escaping automatically.
///
/// Parameters:
///   name: The field name (will be JSON-escaped)
///   value: The string value (will be JSON-escaped and quoted)
///   indent: Indentation prefix (default: two spaces)
///
/// Returns: A formatted "key": "escaped-value" string
///
/// Example:
///   jsonStringField("message", "hello\nworld")
///   // "  \"message\": \"hello\\nworld\""
public func jsonStringField(name: String, value: String, indent!: String = "  "): String {
    jsonField(name, jsonStringLiteral(value), indent: indent)
}
