package seajson.tests

import seajson.*
import std.unittest.*
import std.unittest.testmacro.*

// ── Backend-neutral contract tests ────────────────────────
// These tests verify the SeaJson contract surface without
// depending on any specific backend (stdx, native, etc.).
// When a native backend arrives, it must pass these same tests.

@Test
public class JsonContractTestSuite {

    @TestCase
    public func testJsonEncodableContractRequiresToJsonString(): Unit {
        // A minimal JsonEncodable implementation must provide
        // toJsonString() that returns a valid JSON string.
        let obj = SimpleEncodable("hello")
        @Assert(obj.toJsonString(), "\"hello\"")
    }

    @TestCase
    public func testJsonDecodableContractRequiresFromJsonString(): Unit {
        // A minimal JsonDecodable implementation must provide
        // fromJsonString() that reconstructs the value.
        let obj = SimpleDecodable.fromJsonString("\"world\"")
        @Assert(obj.value, "world")
    }

    @TestCase
    public func testJsonEncoderDefaultDelegatesToJsonString(): Unit {
        let obj = SimpleEncodable("test")
        @Assert(defaultJsonEncoder(obj), "\"test\"")
    }

    @TestCase
    public func testDefaultJsonTextEncoderIsAliasOfDefaultJsonEncoder(): Unit {
        let obj = SimpleEncodable("alias")
        @Assert(defaultJsonTextEncoder(obj), "\"alias\"")
    }

    @TestCase
    public func testCustomJsonEncoderOverridesDefault(): Unit {
        let obj = SimpleEncodable("custom")
        let customEncoder: JsonEncoder = { enc =>
            "{\"wrapped\":" + enc.toJsonString() + "}"
        }
        @Assert(customEncoder(obj), "{\"wrapped\":\"custom\"}")
    }

    // ── Additional contract tests ────────────────────────────────

    @TestCase
    public func testJsonEncodableWithComplexValue(): Unit {
        let obj = ComplexEncodable(42, "test", true)
        let json = obj.toJsonString()
        @Assert(json.contains("42"), true)
        @Assert(json.contains("test"), true)
        @Assert(json.contains("true"), true)
    }

    @TestCase
    public func testLegacyJsonTextEncodableAlias(): Unit {
        // JsonTextEncodable should be an alias for JsonEncodable
        let obj: JsonTextEncodable = SimpleEncodable("alias test")
        @Assert(obj.toJsonString(), "\"alias test\"")
    }

    @TestCase
    public func testLegacyJsonTextEncoderAlias(): Unit {
        let encoder: JsonTextEncoder = defaultJsonEncoder
        let obj = SimpleEncodable("encoder alias")
        @Assert(encoder(obj), "\"encoder alias\"")
    }

    @TestCase
    public func testDefaultJsonTextEncoderFunction(): Unit {
        let obj = SimpleEncodable("text encoder")
        @Assert(defaultJsonTextEncoder(obj), "\"text encoder\"")
    }
}

// ── Test stubs ────────────────────────────────────────────

class SimpleEncodable <: JsonEncodable {
    SimpleEncodable(let value: String) {}

    public func toJsonString(): String {
        jsonStringLiteral(value)
    }
}

class SimpleDecodable <: JsonDecodable<SimpleDecodable> {
    SimpleDecodable(let value: String) {}

    public static func fromJsonString(json: String): SimpleDecodable {
        // Minimal decode: strip surrounding quotes for testing.
        // Real backends will handle full JSON parsing.
        let runes = json.toRuneArray()
        if (runes.size >= 2 && runes[0] == r'"' && runes[runes.size - 1] == r'"') {
            var inner = ""
            var i: Int64 = 1
            while (i < runes.size - 1) {
                inner += runes[i].toString()
                i += 1
            }
            SimpleDecodable(inner)
        } else {
            SimpleDecodable(json)
        }
    }
}

class ComplexEncodable <: JsonEncodable {
    ComplexEncodable(let id: Int64, let name: String, let active: Bool) {}

    public func toJsonString(): String {
        buildJsonObject { w =>
            w.name("id").value(id)
            w.name("name").value(name)
            w.name("active").value(active)
        }
    }
}
