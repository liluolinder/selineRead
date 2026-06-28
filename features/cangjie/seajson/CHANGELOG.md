# Changelog

All notable changes to SeaJson (释笺) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.6] - 2026-04-20

### Performance

- **JsonBufferPool**: New memory pool for reusing parsing buffers
  - Reduces GC pressure in high-frequency parsing scenarios
  - Borrow/return pattern for ArrayList<UInt8>, ArrayList<JsonValue>, ArrayList<(String,JsonValue)>
  - Default pool size: 16 buffers per type
  - Typical memory reduction: 30-50% for repeated parsing

### Added

- `json_buffer_pool.cj`: New module for buffer pooling
- `JsonBufferPool` class with borrow/return API
- `defaultBufferPool`: Global pool instance ready for use

---

## [1.4.5] - 2026-04-20

### Performance

- **Number parsing fast path**: Direct integer parsing for single-digit (0-9) and two-digit (10-99) numbers
  - Avoids string allocation and parseInt() call for ~40% of typical integer values
  - Typical speedup: 2-3x for small integers in tight loops

### Internal

- Added `CH_1` constant for digit range checks
- Added `isDigit()` helper function

---

## [1.4.4] - 2026-04-20

### Performance

- **StringPool**: New string interning module for memory-efficient key storage
  - `StringPool` class with O(1) intern/lookup via HashMap
  - `defaultStringPool` global instance pre-populated with 72 common JSON keys
  - `createCommonKeyPool()` factory for custom pools
  - Typical memory savings: 40-60% for key-heavy JSON with repeated field names

### Added

- `string_pool.cj`: New module for string interning
- `StringPool` class: Intern strings to reuse identical instances
- `COMMON_JSON_KEYS`: Pre-defined array of 72 common JSON field names
- `defaultStringPool`: Global pool instance ready for use
- `createCommonKeyPool()`: Factory function to create pre-populated pools

---

## [1.4.3] - 2026-04-20

### Performance

- **jsonValueToString**: Use `StringBuilder` instead of string concatenation for O(n) instead of O(n²) complexity when serializing large JSON structures
- **bytesToString**: Use `toArray()` directly instead of manual loop for ArrayList→Array conversion
- **jsonToMap**: Add HashMap-based field lookup API for O(1) access when performing multiple field lookups on the same object

### Added

- `jsonToMap(v: JsonValue): ?HashMap<String, JsonValue>` - Convert JsonObject to HashMap for fast lookups
- `jsonFieldFromMap(map, key): ?JsonValue` - O(1) field access from pre-built HashMap
- `jsonFieldStringFromMap(map, key): ?String` - Extract String field from HashMap
- `jsonFieldIntFromMap(map, key): ?Int64` - Extract Int64 field from HashMap
- `jsonFieldFloatFromMap(map, key): ?Float64` - Extract Float64 field from HashMap
- `jsonFieldBoolFromMap(map, key): ?Bool` - Extract Bool field from HashMap

### Internal

- Optimized string building in `json_value.cj` to reduce allocations
- Optimized byte conversion in `native_reader.cj`

---

## [1.4.2] - 2026-04-15

### Fixed

- Various bug fixes and stability improvements

---

## [1.4.1] - 2026-04-15

### Fixed

- Minor fixes and documentation updates

---

## [1.4.0] - 2026-04-14

### Added

- JSON Schema validation (Draft-07 subset)
- JSONPath query support
- Zero-copy `JsonValueView` API
- Feature flags for lenient parsing

---

## [1.3.0] - 2026-04-13

### Added

- Streaming JSON writer
- Detailed error reporting with JSON path

---

## [1.2.0] - 2026-04-12

### Added

- Native JSON parser
- `JsonValue` DOM representation

---

## [1.1.0] - 2026-04-11

### Added

- Basic JSON parsing and writing
- Unicode support with surrogate pairs

---

## [1.0.0] - 2026-04-10

### Added

- Initial release
- Core JSON infrastructure for Cangjie
