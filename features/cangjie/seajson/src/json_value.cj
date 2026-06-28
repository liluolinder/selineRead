package seajson

// ── JsonValue: lightweight DOM representation ────────────────
// Provides a tree-structured JSON value type that can be
// constructed programmatically, serialized to string, and
// queried for fields. This is the native backend's DOM path —
// zero stdx dependency.

import std.collection.{ArrayList, HashMap}

// ── JsonValue enum ───────────────────────────────────────────

public enum JsonValue {
    | JsonNull
    | JsonBoolVal(Bool)
    | JsonIntVal(Int64)
    | JsonInt32Val(Int32)
    | JsonFloatVal(Float64)
    | JsonStrVal(String)
    | JsonArrVal(ArrayList<JsonValue>)
    | JsonObjVal(ArrayList<(String, JsonValue)>)
}

// ── Encoding ─────────────────────────────────────────────────

public func jsonValueToString(v: JsonValue): String {
    match (v) {
        case JsonNull => "null"
        case JsonBoolVal(b) => if (b) { "true" } else { "false" }
        case JsonIntVal(n) => "${n}"
        case JsonInt32Val(n) => "${n}"
        case JsonFloatVal(f) => "${f}"
        case JsonStrVal(s) => jsonStringLiteral(s)
        case JsonArrVal(items) =>
            // Use StringBuilder to avoid O(n²) string concatenation
            let sb = StringBuilder(items.size * 16)  // estimate capacity
            sb.append("[")
            var i: Int64 = 0
            while (i < items.size) {
                if (i > 0) { sb.append(",") }
                sb.append(jsonValueToString(items[i]))
                i += 1
            }
            sb.append("]")
            sb.toString()
        case JsonObjVal(entries) =>
            // Use StringBuilder to avoid O(n²) string concatenation
            let sb = StringBuilder(entries.size * 32)  // estimate capacity
            sb.append("{")
            var i: Int64 = 0
            while (i < entries.size) {
                if (i > 0) { sb.append(",") }
                let (key, val) = entries[i]
                sb.append(jsonStringLiteral(key))
                sb.append(":")
                sb.append(jsonValueToString(val))
                i += 1
            }
            sb.append("}")
            sb.toString()
    }
}

// ── Construction helpers ─────────────────────────────────────

public func jsonNull(): JsonValue { JsonNull }

public func jsonBool(b: Bool): JsonValue { JsonBoolVal(b) }

public func jsonInt(n: Int64): JsonValue { JsonIntVal(n) }

public func jsonInt32(n: Int32): JsonValue { JsonInt32Val(n) }

public func jsonFloat(f: Float64): JsonValue { JsonFloatVal(f) }

public func jsonStr(s: String): JsonValue { JsonStrVal(s) }

public func jsonArr(items: ArrayList<JsonValue>): JsonValue { JsonArrVal(items) }

public func jsonObj(entries: ArrayList<(String, JsonValue)>): JsonValue { JsonObjVal(entries) }

// ── Query / extraction helpers ───────────────────────────────
// These replace soonlink's parseJsonString and similar helpers.

/// Get a field from a JsonValue by key. Returns None if the value
/// is not an object or the key does not exist.
/// Time complexity: O(n) for linear scan.
public func jsonField(v: JsonValue, key: String): ?JsonValue {
    match (v) {
        case JsonObjVal(entries) =>
            var i: Int64 = 0
            while (i < entries.size) {
                let (k, val) = entries[i]
                if (k == key) { return Some(val) }
                i += 1
            }
            None
        case _ => None
    }
}

/// Build a HashMap from a JsonObject for O(1) field lookups.
/// Recommended when performing multiple field accesses on the same object.
public func jsonToMap(v: JsonValue): ?HashMap<String, JsonValue> {
    match (v) {
        case JsonObjVal(entries) =>
            let map = HashMap<String, JsonValue>()
            var i: Int64 = 0
            while (i < entries.size) {
                let (k, val) = entries[i]
                map[k] = val
                i += 1
            }
            Some(map)
        case _ => None
    }
}

/// Get a field from a pre-built HashMap. O(1) lookup.
public func jsonFieldFromMap(map: HashMap<String, JsonValue>, key: String): ?JsonValue {
    map.get(key)
}

/// Extract a String field from a HashMap.
public func jsonFieldStringFromMap(map: HashMap<String, JsonValue>, key: String): ?String {
    match (map.get(key)) {
        case Some(JsonStrVal(s)) => Some(s)
        case _ => None
    }
}

/// Extract an Int64 field from a HashMap.
public func jsonFieldIntFromMap(map: HashMap<String, JsonValue>, key: String): ?Int64 {
    match (map.get(key)) {
        case Some(JsonIntVal(n)) => Some(n)
        case Some(JsonInt32Val(n)) => Some(Int64(n))
        case _ => None
    }
}

/// Extract a Float64 field from a HashMap.
public func jsonFieldFloatFromMap(map: HashMap<String, JsonValue>, key: String): ?Float64 {
    match (map.get(key)) {
        case Some(JsonFloatVal(f)) => Some(f)
        case _ => None
    }
}

/// Extract a Bool field from a HashMap.
public func jsonFieldBoolFromMap(map: HashMap<String, JsonValue>, key: String): ?Bool {
    match (map.get(key)) {
        case Some(JsonBoolVal(b)) => Some(b)
        case _ => None
    }
}

/// Extract a String field from a JsonValue object.
public func jsonFieldString(v: JsonValue, key: String): ?String {
    match (jsonField(v, key)) {
        case Some(JsonStrVal(s)) => Some(s)
        case _ => None
    }
}

/// Extract an Int64 field from a JsonValue object.
public func jsonFieldInt(v: JsonValue, key: String): ?Int64 {
    match (jsonField(v, key)) {
        case Some(JsonIntVal(n)) => Some(n)
        case Some(JsonInt32Val(n)) => Some(Int64(n))
        case _ => None
    }
}

/// Extract an Int32 field from a JsonValue object.
public func jsonFieldInt32(v: JsonValue, key: String): ?Int32 {
    match (jsonField(v, key)) {
        case Some(JsonInt32Val(n)) => Some(n)
        case Some(JsonIntVal(n)) => Some(Int32(n))
        case _ => None
    }
}

/// Extract a Float64 field from a JsonValue object.
public func jsonFieldFloat(v: JsonValue, key: String): ?Float64 {
    match (jsonField(v, key)) {
        case Some(JsonFloatVal(f)) => Some(f)
        case _ => None
    }
}

/// Extract a Bool field from a JsonValue object.
public func jsonFieldBool(v: JsonValue, key: String): ?Bool {
    match (jsonField(v, key)) {
        case Some(JsonBoolVal(b)) => Some(b)
        case _ => None
    }
}

/// Extract a nested Object field from a JsonValue object.
public func jsonFieldObj(v: JsonValue, key: String): ?JsonValue {
    let result = jsonField(v, key)
    match (result) {
        case Some(JsonObjVal(_)) => result
        case _ => None
    }
}

/// Extract a nested Array field from a JsonValue object.
public func jsonFieldArr(v: JsonValue, key: String): ?JsonValue {
    let result = jsonField(v, key)
    match (result) {
        case Some(JsonArrVal(_)) => result
        case _ => None
    }
}

/// Get element from a JsonValue array by index.
public func jsonIndex(v: JsonValue, index: Int64): ?JsonValue {
    match (v) {
        case JsonArrVal(items) =>
            if (index >= 0 && index < items.size) {
                Some(items[index])
            } else {
                None
            }
        case _ => None
    }
}

/// Get the size of a JsonValue array. Returns -1 if not an array.
public func jsonArrSize(v: JsonValue): Int64 {
    match (v) {
        case JsonArrVal(items) => items.size
        case _ => -1
    }
}

/// Check if a JsonValue is null.
public func isJsonNull(v: JsonValue): Bool {
    match (v) {
        case JsonNull => true
        case _ => false
    }
}

/// Check if a JsonValue object has a specific key.
/// Returns false if the value is not an object.
public func jsonHasKey(v: JsonValue, key: String): Bool {
    match (jsonField(v, key)) {
        case Some(_) => true
        case None => false
    }
}

/// Get all keys from a JsonValue object.
/// Returns an empty list if the value is not an object.
public func jsonKeys(v: JsonValue): ArrayList<String> {
    let keys = ArrayList<String>()
    match (v) {
        case JsonObjVal(entries) =>
            var i: Int64 = 0
            while (i < entries.size) {
                let (k, _) = entries[i]
                keys.add(k)
                i += 1
            }
        case _ => ()
    }
    keys
}

/// Get the number of fields in a JsonValue object.
/// Returns -1 if the value is not an object.
public func jsonObjSize(v: JsonValue): Int64 {
    match (v) {
        case JsonObjVal(entries) => entries.size
        case _ => -1
    }
}

/// Get the size of an array field from a JsonValue object.
/// Returns -1 if the field doesn't exist or is not an array.
public func jsonFieldArrSize(v: JsonValue, key: String): Int64 {
    match (jsonFieldArr(v, key)) {
        case Some(arr) => jsonArrSize(arr)
        case None => -1
    }
}

// ── Type predicates ───────────────────────────────────────────

/// Check if a JsonValue is an object.
public func isJsonObject(v: JsonValue): Bool {
    match (v) {
        case JsonObjVal(_) => true
        case _ => false
    }
}

/// Check if a JsonValue is an array.
public func isJsonArray(v: JsonValue): Bool {
    match (v) {
        case JsonArrVal(_) => true
        case _ => false
    }
}

/// Check if a JsonValue is a string.
public func isJsonString(v: JsonValue): Bool {
    match (v) {
        case JsonStrVal(_) => true
        case _ => false
    }
}

/// Check if a JsonValue is a number (int or float).
public func isJsonNumber(v: JsonValue): Bool {
    match (v) {
        case JsonIntVal(_) => true
        case JsonInt32Val(_) => true
        case JsonFloatVal(_) => true
        case _ => false
    }
}

/// Check if a JsonValue is a boolean.
public func isJsonBool(v: JsonValue): Bool {
    match (v) {
        case JsonBoolVal(_) => true
        case _ => false
    }
}

// ── Extraction with defaults ───────────────────────────────────

/// Extract a String field with a default value.
public func jsonFieldStringOr(v: JsonValue, key: String, default: String): String {
    match (jsonFieldString(v, key)) {
        case Some(s) => s
        case None => default
    }
}

/// Extract an Int64 field with a default value.
public func jsonFieldIntOr(v: JsonValue, key: String, default: Int64): Int64 {
    match (jsonFieldInt(v, key)) {
        case Some(n) => n
        case None => default
    }
}

/// Extract a Bool field with a default value.
public func jsonFieldBoolOr(v: JsonValue, key: String, default: Bool): Bool {
    match (jsonFieldBool(v, key)) {
        case Some(b) => b
        case None => default
    }
}

/// Extract a Float64 field with a default value.
public func jsonFieldFloatOr(v: JsonValue, key: String, default: Float64): Float64 {
    match (jsonFieldFloat(v, key)) {
        case Some(f) => f
        case None => default
    }
}

// ── Quick construction helpers ─────────────────────────────────

/// Create a JsonValue array from an ArrayList.
public func jsonArrayOf(elements: ArrayList<JsonValue>): JsonValue {
    JsonArrVal(elements)
}

/// Create an empty JsonValue array.
public func jsonEmptyArray(): JsonValue {
    JsonArrVal(ArrayList<JsonValue>())
}

/// Create an empty JsonValue object.
public func jsonEmptyObject(): JsonValue {
    JsonObjVal(ArrayList<(String, JsonValue)>())
}

/// Create a JsonValue object from an ArrayList of entries.
public func jsonObjectOf(entries: ArrayList<(String, JsonValue)>): JsonValue {
    JsonObjVal(entries)
}

// ── Type conversion helpers (0.5.0) ───────────────────────────────

/// Extract a String value from JsonValue directly.
/// Returns None if the value is not a string.
public func jsonAsString(v: JsonValue): ?String {
    match (v) {
        case JsonStrVal(s) => Some(s)
        case _ => None
    }
}

/// Extract an Int64 value from JsonValue directly.
/// Returns None if the value is not an integer.
public func jsonAsInt(v: JsonValue): ?Int64 {
    match (v) {
        case JsonIntVal(n) => Some(n)
        case JsonInt32Val(n) => Some(Int64(n))
        case _ => None
    }
}

/// Extract a Float64 value from JsonValue directly.
/// Returns None if the value is not a float.
public func jsonAsFloat(v: JsonValue): ?Float64 {
    match (v) {
        case JsonFloatVal(f) => Some(f)
        case JsonIntVal(n) => Some(Float64(n))
        case JsonInt32Val(n) => Some(Float64(n))
        case _ => None
    }
}

/// Extract a Bool value from JsonValue directly.
/// Returns None if the value is not a boolean.
public func jsonAsBool(v: JsonValue): ?Bool {
    match (v) {
        case JsonBoolVal(b) => Some(b)
        case _ => None
    }
}

/// Extract a String value with default.
public func jsonAsStringOr(v: JsonValue, default: String): String {
    match (jsonAsString(v)) {
        case Some(s) => s
        case None => default
    }
}

/// Extract an Int64 value with default.
public func jsonAsIntOr(v: JsonValue, default: Int64): Int64 {
    match (jsonAsInt(v)) {
        case Some(n) => n
        case None => default
    }
}

/// Extract a Float64 value with default.
public func jsonAsFloatOr(v: JsonValue, default: Float64): Float64 {
    match (jsonAsFloat(v)) {
        case Some(f) => f
        case None => default
    }
}

/// Extract a Bool value with default.
public func jsonAsBoolOr(v: JsonValue, default: Bool): Bool {
    match (jsonAsBool(v)) {
        case Some(b) => b
        case None => default
    }
}
