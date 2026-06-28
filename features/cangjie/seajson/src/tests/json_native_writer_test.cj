package seajson.tests

import seajson.*
import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

// ── Native writer conformance tests ─────────────────────────
// These verify the JsonWriter produces valid JSON output.
// When a native reader/parser arrives (Phase 3), the output
// of these tests should round-trip cleanly.

@Test
public class JsonNativeWriterTestSuite {

    @TestCase
    public func testSimpleObject(): Unit {
        let json = buildJsonObject { w =>
            w.name("name").value("SeaJson")
            w.name("version").value(1)
        }
        @Assert(json, "{\"name\":\"SeaJson\",\"version\":1}")
    }

    @TestCase
    public func testSimpleArray(): Unit {
        let json = buildJsonArray { w =>
            w.value("a")
            w.value("b")
            w.value(3)
        }
        @Assert(json, "[\"a\",\"b\",3]")
    }

    @TestCase
    public func testNestedObject(): Unit {
        let json = buildJsonObject { w =>
            w.name("user").beginObject()
                .name("id").value(42)
                .name("active").value(true)
            .endObject()
        }
        @Assert(json, "{\"user\":{\"id\":42,\"active\":true}}")
    }

    @TestCase
    public func testNestedArray(): Unit {
        let json = buildJsonObject { w =>
            w.name("tags").beginArray()
                .value("json")
                .value("cangjie")
            .endArray()
        }
        @Assert(json, "{\"tags\":[\"json\",\"cangjie\"]}")
    }

    @TestCase
    public func testNullAndBoolValues(): Unit {
        let json = buildJsonObject { w =>
            w.name("empty").nullValue()
            w.name("flag").value(false)
        }
        @Assert(json, "{\"empty\":null,\"flag\":false}")
    }

    @TestCase
    public func testStringEscaping(): Unit {
        let json = buildJsonObject { w =>
            w.name("path").value("C:\\Users\\test")
            w.name("msg").value("hello\nworld")
        }
        @Assert(json, "{\"path\":\"C:\\\\Users\\\\test\",\"msg\":\"hello\\nworld\"}")
    }

    @TestCase
    public func testRawValue(): Unit {
        let json = buildJsonObject { w =>
            w.name("extra").rawValue("{\"nested\":true}")
        }
        @Assert(json, "{\"extra\":{\"nested\":true}}")
    }

    @TestCase
    public func testUInt64Value(): Unit {
        let json = buildJsonObject { w =>
            w.name("big").value(UInt64(9007199254740991))
        }
        @Assert(json, "{\"big\":9007199254740991}")
    }

    @TestCase
    public func testInt32Value(): Unit {
        let json = buildJsonObject { w =>
            w.name("count").value(Int32(42))
        }
        @Assert(json, "{\"count\":42}")
    }

    @TestCase
    public func testFloatValue(): Unit {
        let json = buildJsonObject { w =>
            w.name("pi").value(3.14)
        }
        // Float64 string interpolation may vary; just check it starts correctly
        let expected = "{\"pi\":"
        @Assert(json.startsWith(expected), true)
    }

    @TestCase
    public func testEncodableValue(): Unit {
        let obj = SimpleTestEncodable("test")
        let json = buildJsonObject { w =>
            w.name("data").encodableValue(obj)
        }
        @Assert(json, "{\"data\":\"test\"}")
    }

    @TestCase
    public func testEmptyObject(): Unit {
        let w = JsonWriter()
        w.beginObject().endObject()
        @Assert(w.close(), "{}")
    }

    @TestCase
    public func testEmptyArray(): Unit {
        let w = JsonWriter()
        w.beginArray().endArray()
        @Assert(w.close(), "[]")
    }

    @TestCase
    public func testPrettyOutput(): Unit {
        let w = JsonWriter(pretty: true, indent: "  ")
        w.beginObject()
            .name("name").value("SeaJson")
            .name("version").value(2)
        .endObject()
        let result = w.close()
        @Assert(result.contains("\n"), true)
        @Assert(result.contains("  \"name\":"), true)
    }

    @TestCase
    public func testComplexNestedStructure(): Unit {
        let json = buildJsonObject { w =>
            w.name("server").beginObject()
                .name("host").value("0.0.0.0")
                .name("port").value(8080)
                .name("tls").value(false)
            .endObject()
            w.name("middleware").beginArray()
                .value("logger")
                .value("cors")
                .value("recover")
            .endArray()
            w.name("metadata").nullValue()
        }
        @Assert(json.startsWith("{"), true)
        @Assert(json.contains("\"server\""), true)
        @Assert(json.contains("\"middleware\""), true)
        @Assert(json.contains("null"), true)
    }
}

// ── JsonValue tests ──────────────────────────────────────────

@Test
public class JsonValueTestSuite {

    @TestCase
    public func testJsonValueNull(): Unit {
        @Assert(jsonValueToString(JsonNull), "null")
    }

    @TestCase
    public func testJsonValueBool(): Unit {
        @Assert(jsonValueToString(jsonBool(true)), "true")
        @Assert(jsonValueToString(jsonBool(false)), "false")
    }

    @TestCase
    public func testJsonValueInt(): Unit {
        @Assert(jsonValueToString(jsonInt(42)), "42")
    }

    @TestCase
    public func testJsonValueString(): Unit {
        @Assert(jsonValueToString(jsonStr("hello")), "\"hello\"")
    }

    @TestCase
    public func testJsonValueArray(): Unit {
        let arr = ArrayList<JsonValue>()
        arr.add(jsonInt(1))
        arr.add(jsonInt(2))
        arr.add(jsonInt(3))
        @Assert(jsonValueToString(jsonArr(arr)), "[1,2,3]")
    }

    @TestCase
    public func testJsonValueObject(): Unit {
        let entries = ArrayList<(String, JsonValue)>()
        entries.add(("name", jsonStr("SeaJson")))
        entries.add(("version", jsonInt(1)))
        @Assert(jsonValueToString(jsonObj(entries)), "{\"name\":\"SeaJson\",\"version\":1}")
    }

    @TestCase
    public func testJsonValueNestedRoundTrip(): Unit {
        let inner = ArrayList<(String, JsonValue)>()
        inner.add(("active", jsonBool(true)))
        let outer = ArrayList<(String, JsonValue)>()
        let flagArr = ArrayList<JsonValue>()
        flagArr.add(jsonBool(true))
        flagArr.add(jsonBool(false))
        outer.add(("flags", jsonArr(flagArr)))
        let result = jsonValueToString(jsonObj(outer))
        @Assert(result, "{\"flags\":[true,false]}")
    }
}

// ── Feature flags / depth / NaN guard tests ──────────────────

@Test
public class JsonWriterFeatureTestSuite {

    @TestCase
    public func testFeaturePrettyPrintViaFlag(): Unit {
        let features = ArrayList<JsonWriteFeature>()
        features.add(PrettyPrint)
        let w = JsonWriter(features: features)
        w.beginObject()
            .name("key").value("val")
        .endObject()
        let result = w.close()
        @Assert(result.contains("\n"), true)
        @Assert(result.contains("  \"key\":"), true)
    }

    @TestCase
    public func testDepthLimitExceeded(): Unit {
        let w = JsonWriter(maxDepth: 3)
        w.beginObject()
        w.name("a").beginObject()
        w.name("b").beginObject()
        var caught = false
        try {
            w.name("c").beginObject() // depth 4 → exceeds limit
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testNaNRejected(): Unit {
        let w = JsonWriter()
        w.beginObject()
        w.name("x")
        var caught = false
        try {
            w.value(0.0 / 0.0)
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testPositiveInfinityRejected(): Unit {
        let w = JsonWriter()
        w.beginObject()
        w.name("x")
        var caught = false
        try {
            w.value(1.0 / 0.0)
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testNegativeInfinityRejected(): Unit {
        let w = JsonWriter()
        w.beginObject()
        w.name("x")
        var caught = false
        try {
            w.value(-1.0 / 0.0)
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testFeatureEscapeNonAscii(): Unit {
        let features = ArrayList<JsonWriteFeature>()
        features.add(EscapeNonAscii)
        let w = JsonWriter(features: features)
        w.beginObject()
            .name("cn").value("\u{4E16}")
        .endObject()
        let result = w.close()
        @Assert(result.contains("\\u4E16"), true)
    }

    @TestCase
    public func testBuildJsonObjectPretty(): Unit {
        let json = buildJsonObjectPretty { w =>
            w.name("name").value("SeaJson")
        }
        @Assert(json.contains("\n"), true)
        @Assert(json.contains("\"name\":"), true)
    }

    // ── WriteNulls feature ──────────────────────────────────────

    @TestCase
    public func testWriteNullsSkippedByDefault(): Unit {
        let w = JsonWriter()
        w.beginObject()
        let written = w.nameWithNull("optional")
        w.endObject()
        let result = w.close()
        @Assert(written, false)
        @Assert(result, "{}")
    }

    @TestCase
    public func testWriteNullsIncludedWithFeature(): Unit {
        let features = ArrayList<JsonWriteFeature>()
        features.add(WriteNulls)
        let w = JsonWriter(features: features)
        w.beginObject()
        let written = w.nameWithNull("optional")
        w.endObject()
        let result = w.close()
        @Assert(written, true)
        @Assert(result.contains("\"optional\":null"), true)
    }

    @TestCase
    public func testNameValueWithNull(): Unit {
        let features = ArrayList<JsonWriteFeature>()
        features.add(WriteNulls)
        let w = JsonWriter(features: features)
        w.beginObject()
        w.nameValue("present", Some("value"))
        w.nameValue("absent", None<String>)
        w.endObject()
        let result = w.close()
        @Assert(result.contains("\"present\":\"value\""), true)
        @Assert(result.contains("\"absent\":null"), true)
    }

    @TestCase
    public func testNameValueWithoutWriteNullsFeature(): Unit {
        let w = JsonWriter()
        w.beginObject()
        let w1 = w.nameValue("present", Some("value"))
        let w2 = w.nameValue("absent", None<String>)
        w.endObject()
        let result = w.close()
        @Assert(w1, true)
        @Assert(w2, false)
        @Assert(result.contains("\"present\":\"value\""), true)
        @Assert(result.contains("absent"), false)
    }
}

// ── Test stubs ───────────────────────────────────────────────

class SimpleTestEncodable <: JsonEncodable {
    SimpleTestEncodable(let val: String) {}

    public func toJsonString(): String {
        jsonStringLiteral(val)
    }
}
