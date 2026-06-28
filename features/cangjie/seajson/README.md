# SeaJson (释笺)

[![Cangjie](https://img.shields.io/badge/Cangjie-1.1.0-blue.svg)](https://cangjie-lang.cn)
[![License](https://img.shields.io/badge/License-Apache--2.0-green.svg)](LICENSE)

**Native JSON infrastructure for Cangjie** — A complete JSON solution with parsing, writing, validation, and querying capabilities.

Inspired by [FastJson2](https://github.com/alibaba/fastjson2) and [Jackson](https://github.com/FasterXML/jackson).

## Features

- **Zero stdx dependency** for core operations
- **RFC 8259 compliant** by default; lenient modes available via features
- **Streaming writer** avoids intermediate object allocation
- **JSONPath queries** for navigating complex structures
- **JSON Schema validation** (Draft-07 subset)
- **Detailed error reporting** with JSON path and position
- **Unicode support** including surrogate pairs and non-ASCII escaping
- **Backend-neutral contracts** (`JsonEncodable`, `JsonDecodable`)
- **Performance optimizations**:
  - String interning via `StringPool` for memory-efficient key storage
  - Buffer pooling via `JsonBufferPool` for reduced GC pressure
  - Fast path for small integer parsing (0-99)

## Quick Start

### Installation

Add to your `cjpm.toml`:

```toml
[dependencies]
  seajson = { path = "path/to/seajson" }
```

### Parsing JSON

```cangjie
import seajson.*

let json = "{\"name\":\"Alice\",\"age\":30}"
let value = parseJson(json)

// Extract fields
let name = jsonFieldString(value, "name")  // Some("Alice")
let age = jsonFieldInt(value, "age")        // Some(30)

// With defaults
let name = jsonFieldStringOr(value, "name", "unknown")
let age = jsonFieldIntOr(value, "age", 0)
```

### Building JSON (Streaming Writer)

```cangjie
import seajson.*

let output = buildJsonObject { w =>
    w.name("id").value(42)
    w.name("label").value("hello")
    w.name("active").value(true)
}
// {"id":42,"label":"hello","active":true}
```

### JSONPath Queries

```cangjie
import seajson.*

let json = """
{
    "store": {
        "book": [
            {"title": "Book 1", "price": 10},
            {"title": "Book 2", "price": 20}
        ]
    }
}
"""

let v = parseJson(json)

// Get first book's title
let title = jsonPathOne(v, "$.store.book[0].title")  // Some("Book 1")

// Negative array index
let lastBook = jsonPathOne(v, "$.store.book[-1]")    // Last book

// Array slice
let firstTwo = jsonPathOne(v, "$.store.book[0:2]")   // First two books

// Recursive descent - find all titles at any depth
let allTitles = jsonPathAll(v, "$..title")
```

### JSON Schema Validation

```cangjie
import seajson.*

let schema = parseJson("""
{
    "type": "object",
    "required": ["name"],
    "properties": {
        "name": {"type": "string", "minLength": 1},
        "age": {"type": "integer", "minimum": 0},
        "email": {"type": "string"}
    }
}
""")

let validData = parseJson("{\"name\":\"Alice\",\"age\":30}")

// Quick check
if (isValidSchema(validData, schema)) {
    println("Valid!")
}

// Detailed errors
match (validateSchema(validData, schema)) {
    case Valid => println("Valid!")
    case Invalid(errors) =>
        for (e in errors) {
            println("${e.path}: ${e.message}")
        }
}
```

### Feature Flags

```cangjie
import std.collection.ArrayList

// Read features
let features = ArrayList<JsonReadFeature>()
features.add(AllowTrailingComma)  // Allow [1,2,]
features.add(AllowComments)       // Allow // and /* */ comments
features.add(AllowSingleQuotes)   // Allow 'strings'

let v = parseJson(json, features: features)

// Write features
let writeFeatures = ArrayList<JsonWriteFeature>()
writeFeatures.add(PrettyPrint)    // Format with indentation
writeFeatures.add(EscapeNonAscii) // Escape non-ASCII as \uXXXX
writeFeatures.add(WriteNulls)     // Write null-valued fields
```

### Error Handling

```cangjie
// Safe parsing with Option
match (tryParseJson(input)) {
    case Some(v) => process(v)
    case None => println("Invalid JSON")
}

// Detailed error information
try {
    let v = parseJson(input)
} catch (e: JsonDecodeError) {
    println("${e.kindName} at ${e.path}: ${e.message}")
}
```

## API Reference

| File | Description |
|------|-------------|
| `seajson.cj` | Version info, package documentation |
| `native_reader.cj` | `JsonReader`, `parseJson`, `tryParseJson` |
| `native_writer.cj` | `JsonWriter`, `buildJsonObject`, `buildJsonArray` |
| `json_value.cj` | `JsonValue` enum, query helpers, type conversion |
| `json_path.cj` | `JsonPath`, `jsonPathOne`, `jsonPathAll` |
| `json_schema.cj` | `validateSchema`, `isValidSchema`, `SchemaError` |
| `json_text.cj` | Low-level string escaping utilities |
| `json_builder.cj` | Simple field/record builders |
| `json_decode_error.cj` | `JsonDecodeError`, `JsonErrorKind` |
| `json_feature.cj` | `JsonWriteFeature`, `JsonReadFeature` |
| `contract.cj` | `JsonEncodable`, `JsonDecodable` interfaces |
| `string_pool.cj` | `StringPool`, `defaultStringPool` for string interning |
| `json_buffer_pool.cj` | `JsonBufferPool`, `defaultBufferPool` for memory reuse |
| `json_stream_backend.cj` | **[DEPRECATED]** stdx compatibility layer |

## Design Principles

1. **Zero stdx dependency** for core operations
2. **RFC 8259 compliant** by default
3. **Streaming writer** avoids intermediate allocation
4. **Error messages** include path and position
5. **Feature flags** mirror Jackson's pattern
6. **JSONPath** for flexible querying
7. **Schema validation** for data integrity

## Requirements

- Cangjie SDK 1.1.0+
- stdx (optional, for compatibility layer only)

## License

Apache License 2.0

## Acknowledgments

Design influenced by:
- [FastJson2](https://github.com/alibaba/fastjson2) - Performance patterns
- [Jackson](https://github.com/FasterXML/jackson) - Feature flag design
- [JSONPath](https://goessner.net/articles/JsonPath/) - Query syntax
- [JSON Schema](https://json-schema.org/) - Validation specification
