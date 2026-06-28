package seajson

import std.collection.ArrayList

// ============================================================================
// JsonValueView - Zero-copy JSON Value
// ============================================================================
//
// A zero-copy representation of JSON values that uses StringView for strings.
// Useful for parsing large JSON documents where most string fields are never
// accessed, avoiding memory allocation for those strings.
//
// ## Features
//   - Zero-copy string storage via StringView
//   - Same recursive structure as JsonValue
//   - Convert to JsonValue when needed via toJsonValue()
//   - Compatible with JSONPath queries
//
// ## Usage
//   let json = "{\"name\":\"Alice\",\"city\":\"Beijing\"}"
//   let view = parseJsonView(json)
//   
//   // Access without creating String objects
//   match (view) {
//       case JsonObjView(entries) =>
//           for (key, val) in entries {
//               // key and val strings are views, not copies
//           }
//       case _ => ()
//   }
//   
//   // Convert to regular JsonValue when done
//   let value = view.toJsonValue()
//
// ## Thread Safety
//   JsonValueView is immutable but holds references to the original JSON string.
//   The source string must remain valid for the lifetime of the view.
//
// ============================================================================

/// A zero-copy JSON value representation.
///
/// Unlike JsonValue which owns its strings, JsonValueView uses StringView
/// to reference slices of the original JSON string, avoiding memory allocation
/// for string values until explicitly converted via toString().
public enum JsonValueView {
    | JsonNullView
    | JsonBoolViewVal(Bool)
    | JsonIntViewVal(Int64)
    | JsonInt32ViewVal(Int32)
    | JsonFloatViewVal(Float64)
    | JsonStrViewVal(StringView)
    | JsonArrViewVal(ArrayList<JsonValueView>)
    | JsonObjViewVal(ArrayList<(StringView, JsonValueView)>)
}

/// Convert a JsonValueView to a regular JsonValue.
/// This performs the actual string copying for all string values in the tree.
public func viewToValue(v: JsonValueView): JsonValue {
    match (v) {
        case JsonNullView => JsonNull
        case JsonBoolViewVal(b) => JsonBoolVal(b)
        case JsonIntViewVal(n) => JsonIntVal(n)
        case JsonInt32ViewVal(n) => JsonInt32Val(n)
        case JsonFloatViewVal(f) => JsonFloatVal(f)
        case JsonStrViewVal(sv) => JsonStrVal(sv.toString())
        case JsonArrViewVal(items) =>
            let arr = ArrayList<JsonValue>()
            var i: Int64 = 0
            while (i < items.size) {
                arr.add(viewToValue(items[i]))
                i += 1
            }
            JsonArrVal(arr)
        case JsonObjViewVal(entries) =>
            let obj = ArrayList<(String, JsonValue)>()
            var i: Int64 = 0
            while (i < entries.size) {
                let (keyView, valView) = entries[i]
                obj.add((keyView.toString(), viewToValue(valView)))
                i += 1
            }
            JsonObjVal(obj)
    }
}

// ============================================================================
// View Query Helpers
// ============================================================================

/// Check if a JsonValueView is null.
public func isJsonNullView(v: JsonValueView): Bool {
    match (v) {
        case JsonNullView => true
        case _ => false
    }
}

/// Check if a JsonValueView is a boolean.
public func isJsonBoolView(v: JsonValueView): Bool {
    match (v) {
        case JsonBoolViewVal(_) => true
        case _ => false
    }
}

/// Check if a JsonValueView is an integer.
public func isJsonIntView(v: JsonValueView): Bool {
    match (v) {
        case JsonIntViewVal(_) | JsonInt32ViewVal(_) => true
        case _ => false
    }
}

/// Check if a JsonValueView is a number (int or float).
public func isJsonNumberView(v: JsonValueView): Bool {
    match (v) {
        case JsonIntViewVal(_) | JsonInt32ViewVal(_) | JsonFloatViewVal(_) => true
        case _ => false
    }
}

/// Check if a JsonValueView is a string.
public func isJsonStringView(v: JsonValueView): Bool {
    match (v) {
        case JsonStrViewVal(_) => true
        case _ => false
    }
}

/// Check if a JsonValueView is an array.
public func isJsonArrayView(v: JsonValueView): Bool {
    match (v) {
        case JsonArrViewVal(_) => true
        case _ => false
    }
}

/// Check if a JsonValueView is an object.
public func isJsonObjectView(v: JsonValueView): Bool {
    match (v) {
        case JsonObjViewVal(_) => true
        case _ => false
    }
}

/// Get a field from a JsonValueView object without creating a String copy.
/// Returns None if v is not an object or key doesn't exist.
/// Note: The key comparison is done byte-by-byte without creating new strings.
public func jsonFieldView(v: JsonValueView, key: String): ?JsonValueView {
    match (v) {
        case JsonObjViewVal(entries) =>
            var i: Int64 = 0
            while (i < entries.size) {
                let (keyView, valView) = entries[i]
                if (keyView.equals(key)) {
                    return Some(valView)
                }
                i += 1
            }
            None
        case _ => None
    }
}

/// Get a string field from a JsonValueView object.
/// Returns None if v is not an object, key doesn't exist, or value is not a string.
/// Note: Returns a StringView, not a String - no copy is made.
public func jsonFieldStringView(v: JsonValueView, key: String): ?StringView {
    match (jsonFieldView(v, key)) {
        case Some(JsonStrViewVal(sv)) => Some(sv)
        case _ => None
    }
}

/// Get an integer field from a JsonValueView object.
/// Returns None if v is not an object, key doesn't exist, or value is not an integer.
public func jsonFieldIntView(v: JsonValueView, key: String): ?Int64 {
    match (jsonFieldView(v, key)) {
        case Some(JsonIntViewVal(n)) => Some<Int64>(n)
        case Some(JsonInt32ViewVal(n)) => Some<Int64>(Int64(n))
        case _ => None
    }
}

/// Get a float field from a JsonValueView object.
/// Returns None if v is not an object, key doesn't exist, or value is not a number.
/// Note: Integers are converted to floats.
public func jsonFieldFloatView(v: JsonValueView, key: String): ?Float64 {
    match (jsonFieldView(v, key)) {
        case Some(JsonFloatViewVal(f)) => Some<Float64>(f)
        case Some(JsonIntViewVal(n)) => Some<Float64>(Float64(n))
        case Some(JsonInt32ViewVal(n)) => Some<Float64>(Float64(n))
        case _ => None
    }
}

/// Get a boolean field from a JsonValueView object.
/// Returns None if v is not an object, key doesn't exist, or value is not a boolean.
public func jsonFieldBoolView(v: JsonValueView, key: String): ?Bool {
    match (jsonFieldView(v, key)) {
        case Some(JsonBoolViewVal(b)) => Some<Bool>(b)
        case _ => None
    }
}

/// Get an element from a JsonValueView array by index.
/// Returns None if v is not an array or index is out of bounds.
public func jsonIndexView(v: JsonValueView, index: Int64): ?JsonValueView {
    match (v) {
        case JsonArrViewVal(items) =>
            if (index < 0 || index >= items.size) {
                None
            } else {
                Some(items[index])
            }
        case _ => None
    }
}

/// Get the size of a JsonValueView array.
/// Returns 0 if v is not an array.
public func jsonArrSizeView(v: JsonValueView): Int64 {
    match (v) {
        case JsonArrViewVal(items) => items.size
        case _ => 0
    }
}

/// Get the number of fields in a JsonValueView object.
/// Returns 0 if v is not an object.
public func jsonObjSizeView(v: JsonValueView): Int64 {
    match (v) {
        case JsonObjViewVal(entries) => entries.size
        case _ => 0
    }
}

/// Check if a JsonValueView object has a field with the given key.
/// Uses zero-copy comparison for the key.
public func jsonHasKeyView(v: JsonValueView, key: String): Bool {
    match (v) {
        case JsonObjViewVal(entries) =>
            var i: Int64 = 0
            while (i < entries.size) {
                let (keyView, _) = entries[i]
                if (keyView.equals(key)) { return true }
                i += 1
            }
            false
        case _ => false
    }
}

/// Convert a StringView to a String (performs the actual copy).
/// Helper for when you need an owned String from a view.
public func viewToString(sv: StringView): String {
    sv.toString()
}

/// Convert a JsonValueView string to a String.
/// Returns None if v is not a string.
public func jsonAsStringView(v: JsonValueView): ?String {
    match (v) {
        case JsonStrViewVal(sv) => Some(sv.toString())
        case _ => None
    }
}

/// Convert a JsonValueView integer to Int64.
/// Returns None if v is not an integer.
public func jsonAsIntView(v: JsonValueView): ?Int64 {
    match (v) {
        case JsonIntViewVal(n) => Some<Int64>(n)
        case JsonInt32ViewVal(n) => Some<Int64>(Int64(n))
        case _ => None
    }
}

/// Convert a JsonValueView number to Float64.
/// Returns None if v is not a number.
/// Note: Integers are converted to floats.
public func jsonAsFloatView(v: JsonValueView): ?Float64 {
    match (v) {
        case JsonFloatViewVal(f) => Some<Float64>(f)
        case JsonIntViewVal(n) => Some<Float64>(Float64(n))
        case JsonInt32ViewVal(n) => Some<Float64>(Float64(n))
        case _ => None
    }
}

/// Convert a JsonValueView boolean to Bool.
/// Returns None if v is not a boolean.
public func jsonAsBoolView(v: JsonValueView): ?Bool {
    match (v) {
        case JsonBoolViewVal(b) => Some<Bool>(b)
        case _ => None
    }
}
