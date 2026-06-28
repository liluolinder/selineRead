// ============================================================================
// SeaJson - A Complete JSON Library for Cangjie
// ============================================================================
//
// SeaJson provides a complete JSON solution with zero stdx dependency for
// core operations. It offers:
//
//   - Fast, streaming JSON writer with pretty-print support
//   - Hand-written recursive-descent parser producing JsonValue trees
//   - Lightweight DOM representation for query and manipulation
//   - JSONPath queries for navigating complex structures
//   - JSON Schema validation (Draft-07 subset)
//   - Structured error reporting with path and position information
//   - Backend-neutral contracts (JsonEncodable, JsonDecodable)
//   - Optional stdx adapter for migration compatibility
//
// ============================================================================
// Quick Start
// ============================================================================
//
// ## Parsing JSON
//
//   let json = "{\"name\":\"Alice\",\"age\":30}"
//   let value = parseJson(json)
//
//   // Extract fields
//   let name = jsonFieldString(value, "name")  // Some("Alice")
//   let age = jsonFieldInt(value, "age")        // Some(30)
//
// ## Building JSON (Streaming Writer)
//
//   let output = buildJsonObject { w =>
//       w.name("id").value(42)
//       w.name("label").value("hello")
//       w.name("active").value(true)
//   }
//   // {"id":42,"label":"hello","active":true}
//
// ## JSONPath Queries
//
//   let v = parseJson("{\"store\":{\"book\":[{\"title\":\"Guide\"}]}}")
//   let title = jsonPathOne(v, "$.store.book[0].title")  // Some("Guide")
//
// ## JSON Schema Validation
//
//   let schema = parseJson("{\"type\":\"string\",\"minLength\":1}")
//   if (isValidSchema(parseJson("\"hello\""), schema)) {
//       println("Valid!")
//   }
//
// ## Error Handling
//
//   match (tryParseJson(input)) {
//       case Some(v) => process(v)
//       case None => println("Invalid JSON")
//   }
//
//   try {
//       let v = parseJson(input)
//   } catch (e: JsonDecodeError) {
//       println("${e.kindName} at ${e.path}: ${e.message}")
//   }
//
// ============================================================================
// API Reference (by file)
// ============================================================================
//
// seajson.cj          - Version info; this documentation
// native_reader.cj    - JsonReader, parseJson, tryParseJson, parseJsonView, tryParseJsonView
// native_writer.cj    - JsonWriter, buildJsonObject, buildJsonArray
// json_value.cj       - JsonValue enum, query helpers, type conversion
// json_value_view.cj  - JsonValueView enum, zero-copy JSON parsing
// string_view.cj      - StringView, zero-copy string slice
// json_path.cj        - JsonPath, jsonPathOne, jsonPathAll
// json_schema.cj      - validateSchema, isValidSchema, SchemaError
// json_text.cj        - Low-level string escaping utilities
// json_builder.cj     - Simple field/record builders
// json_decode_error.cj- JsonDecodeError, JsonErrorKind
// json_feature.cj     - JsonWriteFeature, JsonReadFeature
// contract.cj         - JsonEncodable, JsonDecodable
// json_stream_backend.cj - stdx adapter (deprecated)
//
// ============================================================================
// Design Principles
// ============================================================================
//
// 1. Zero stdx dependency for core operations
// 2. RFC 8259 compliant by default; lenient modes available via features
// 3. Streaming writer avoids intermediate object allocation
// 4. Error messages include JSON path and position
// 5. Feature flags mirror Jackson's pattern
// 6. JSONPath for flexible querying
// 7. Schema validation for data integrity
//
// ============================================================================

package seajson

public let SeaJsonVersion: String = "1.4.2"

/// Returns the current SeaJson version string.
public func version(): String {
    SeaJsonVersion
}
