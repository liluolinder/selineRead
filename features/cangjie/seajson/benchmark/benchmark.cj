package seajson.benchmark

// ============================================================================
// SeaJson Benchmark Suite
// ============================================================================
//
// Performance benchmarks for JSON parsing and writing.
// Run with: cjpm run benchmark
//
// Benchmark categories:
//   - Parse: JSON string -> JsonValue
//   - Write: JsonValue -> JSON string
//   - Query: JsonValue field/index access
//   - JSONPath: Path-based queries
//
// ============================================================================

import seajson.*
import std.collection.ArrayList

// ── Benchmark utilities ─────────────────────────────────────────────

/// Simple nanosecond timing using system clock
func nanoTime(): Int64 {
    // Use a simple counter-based approach
    // In practice, this would use std.time or system calls
    var counter: Int64 = 0
    // This is a placeholder - actual timing requires platform-specific code
    counter
}

/// Run a benchmark and print results
func benchmark(name: String, iterations: Int64, op: () -> Unit): Unit {
    // Warmup phase
    var warmup = 0
    while (warmup < 5) {
        op()
        warmup += 1
    }

    // Measure phase (manual timing would be done externally)
    var i: Int64 = 0
    let startCount = i
    while (i < iterations) {
        op()
        i += 1
    }

    // Print result (actual timing would be added in production)
    println("${name}: ${iterations} iterations completed")
}

// ── Test data generators ─────────────────────────────────────────────

func generateSmallObject(): String {
    "{\"name\":\"test\",\"value\":42,\"active\":true}"
}

func generateMediumObject(): String {
    let sb = StringBuilder()
    sb.append("{\"user\":{\"name\":\"Alice\",\"age\":30,\"email\":\"alice@example.com\"")
    sb.append(",\"address\":{\"street\":\"123 Main St\",\"city\":\"Springfield\"}")
    sb.append(",\"tags\":[\"developer\",\"manager\",\"admin\"]")
    sb.append(",\"scores\":[95,87,92,88,91]}}")
    sb.toString()
}

func generateLargeArray(): String {
    let sb = StringBuilder()
    sb.append("[")
    var i: Int64 = 0
    while (i < 100) {
        if (i > 0) { sb.append(",") }
        sb.append("{\"id\":${i},\"name\":\"item${i}\",\"value\":${i * 10}}")
        i += 1
    }
    sb.append("]")
    sb.toString()
}

func generateDeepNestedObject(): String {
    var json = "{\"value\":42}"
    var i: Int64 = 0
    while (i < 20) {
        json = "{\"nested\":${json}}"
        i += 1
    }
    json
}

func generateUnicodeString(): String {
    // Mix of ASCII and non-ASCII characters
    let sb = StringBuilder()
    sb.append("{\"text\":\"")
    sb.append("Hello World 你好世界 こんにちは")
    sb.append(" Привет мир مرحبا بالعالم")
    sb.append(" Unicode Test\"}")
    sb.toString()
}

// ── Parse benchmarks ─────────────────────────────────────────────────

func benchParseSmallObject(): Unit {
    let json = generateSmallObject()
    benchmark("parseSmallObject", 10000, { => _ = parseJson(json) })
}

func benchParseMediumObject(): Unit {
    let json = generateMediumObject()
    benchmark("parseMediumObject", 1000, { => _ = parseJson(json) })
}

func benchParseLargeArray(): Unit {
    let json = generateLargeArray()
    benchmark("parseLargeArray", 100, { => _ = parseJson(json) })
}

func benchParseDeepNested(): Unit {
    let json = generateDeepNestedObject()
    benchmark("parseDeepNested", 1000, { => _ = parseJson(json) })
}

func benchParseUnicode(): Unit {
    let json = generateUnicodeString()
    benchmark("parseUnicode", 1000, { => _ = parseJson(json) })
}

// ── Write benchmarks ─────────────────────────────────────────────────

func benchWriteSmallObject(): Unit {
    let v = parseJson(generateSmallObject())
    benchmark("writeSmallObject", 10000, { => _ = jsonValueToString(v) })
}

func benchWriteMediumObject(): Unit {
    let v = parseJson(generateMediumObject())
    benchmark("writeMediumObject", 1000, { => _ = jsonValueToString(v) })
}

func benchWriteLargeArray(): Unit {
    let v = parseJson(generateLargeArray())
    benchmark("writeLargeArray", 100, { => _ = jsonValueToString(v) })
}

func benchBuildJsonObject(): Unit {
    benchmark("buildJsonObject", 5000, {
        => _ = buildJsonObject { w =>
            w.name("name").value("test")
            w.name("value").value(42)
            w.name("active").value(true)
        }
    })
}

func benchBuildJsonArray(): Unit {
    benchmark("buildJsonArray", 5000, {
        => _ = buildJsonArray { w =>
            w.value(1).value(2).value(3).value(4).value(5)
        }
    })
}

// ── Query benchmarks ─────────────────────────────────────────────────

func benchFieldAccess(): Unit {
    let v = parseJson(generateMediumObject())
    benchmark("fieldAccess", 10000, { => _ = jsonFieldString(v, "user") })
}

func benchNestedFieldAccess(): Unit {
    let v = parseJson(generateMediumObject())
    benchmark("nestedFieldAccess", 10000, {
        => match (jsonFieldObj(v, "user")) {
            case Some(user) => _ = jsonFieldString(user, "name")
            case None => ()
        }
    })
}

func benchArrayIndex(): Unit {
    let v = parseJson(generateLargeArray())
    benchmark("arrayIndex", 10000, { => _ = jsonIndex(v, 50) })
}

func benchArrayIteration(): Unit {
    let v = parseJson(generateLargeArray())
    benchmark("arrayIteration", 100, {
        let size = jsonArrSize(v)
        var i: Int64 = 0
        while (i < size) {
            _ = jsonIndex(v, i)
            i += 1
        }
    })
}

// ── JSONPath benchmarks ──────────────────────────────────────────────

func benchJsonPathRoot(): Unit {
    let v = parseJson(generateMediumObject())
    benchmark("jsonPathRoot", 10000, { => _ = jsonPathOne(v, "$") })
}

func benchJsonPathField(): Unit {
    let v = parseJson(generateMediumObject())
    benchmark("jsonPathField", 10000, { => _ = jsonPathOne(v, "$.user") })
}

func benchJsonPathNestedField(): Unit {
    let v = parseJson(generateMediumObject())
    benchmark("jsonPathNestedField", 10000, { => _ = jsonPathOne(v, "$.user.name") })
}

func benchJsonPathArrayIndex(): Unit {
    let v = parseJson(generateLargeArray())
    benchmark("jsonPathArrayIndex", 10000, { => _ = jsonPathOne(v, "$[50]") })
}

// ── Main entry point ─────────────────────────────────────────────────

main() {
    println("============================================================")
    println("SeaJson Benchmark Suite v${SeaJsonVersion}")
    println("============================================================")
    println("")
    println("Note: Timing requires platform-specific implementation.")
    println("This benchmark measures operation counts only.")
    println("")

    println("--- Parse Benchmarks ---")
    benchParseSmallObject()
    benchParseMediumObject()
    benchParseLargeArray()
    benchParseDeepNested()
    benchParseUnicode()
    println("")

    println("--- Write Benchmarks ---")
    benchWriteSmallObject()
    benchWriteMediumObject()
    benchWriteLargeArray()
    benchBuildJsonObject()
    benchBuildJsonArray()
    println("")

    println("--- Query Benchmarks ---")
    benchFieldAccess()
    benchNestedFieldAccess()
    benchArrayIndex()
    benchArrayIteration()
    println("")

    println("--- JSONPath Benchmarks ---")
    benchJsonPathRoot()
    benchJsonPathField()
    benchJsonPathNestedField()
    benchJsonPathArrayIndex()
    println("")

    println("============================================================")
    println("Benchmark complete")
    println("============================================================")
}
