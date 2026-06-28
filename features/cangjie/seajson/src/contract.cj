package seajson

// ============================================================================
// Backend-neutral Contracts
// ============================================================================
//
// SeaJson owns its own encode/decode interfaces so that the public surface
// never leaks a specific backend (e.g. stdx). These contracts enable
// type-safe JSON serialization without coupling to implementation details.
//
// ## JsonEncodable
// Implement this interface to provide JSON serialization for your types.
// The toJsonString() method should return a complete, valid JSON string.
//
// Example:
//   class User <: JsonEncodable {
//       let name: String
//       let age: Int64
//
//       public func toJsonString(): String {
//           buildJsonObject { w =>
//               w.name("name").value(name)
//               w.name("age").value(age)
//           }
//       }
//   }
//
// ## JsonDecodable
// Implement this interface to provide JSON deserialization for your types.
// The static fromJsonString() method parses JSON and constructs the object.
//
// Example:
//   class User <: JsonDecodable<User> {
//       let name: String
//       let age: Int64
//
//       public static func fromJsonString(json: String): User {
//           let v = parseJson(json)
//           User(
//               name: jsonFieldString(v, "name") ?? "",
//               age: jsonFieldInt(v, "age") ?? 0
//           )
//       }
//   }
//
// ============================================================================

/// Interface for types that can be serialized to JSON.
///
/// Implement this interface to provide custom JSON serialization.
/// The toJsonString() method must return a valid, complete JSON value
/// (object, array, or primitive).
public interface JsonEncodable {
    /// Serialize this value to a JSON string.
    ///
    /// Returns: A valid JSON string representation of this value.
    func toJsonString(): String
}

/// Interface for types that can be deserialized from JSON.
///
/// The type parameter T allows for proper typing of the return value
/// in static methods.
public interface JsonDecodable<T> {
    /// Deserialize a JSON string into an instance of T.
    ///
    /// Parameters:
    ///   json: A valid JSON string
    ///
    /// Returns: A new instance of T constructed from the JSON data
    ///
    /// Throws: JsonDecodeError if parsing fails or data is invalid
    static func fromJsonString(json: String): T
}

// ── Legacy compatibility alias ────────────────────────────
// JsonTextEncodable is kept as an alias for JsonEncodable so
// that existing consumer code continues to compile. New code
// should prefer JsonEncodable directly.

/// Deprecated alias for JsonEncodable.
/// Kept for backward compatibility; use JsonEncodable in new code.
public type JsonTextEncodable = JsonEncodable

// ── Encoder function types ────────────────────────────────

/// Function type for encoding JsonEncodable values to JSON strings.
public type JsonEncoder = (JsonEncodable) -> String

/// Deprecated alias for JsonEncoder.
public type JsonTextEncoder = JsonEncoder

/// Default encoder that delegates to the object's toJsonString() method.
public func defaultJsonEncoder(obj: JsonEncodable): String {
    obj.toJsonString()
}

/// Deprecated alias for defaultJsonEncoder.
public func defaultJsonTextEncoder(obj: JsonEncodable): String {
    defaultJsonEncoder(obj)
}
