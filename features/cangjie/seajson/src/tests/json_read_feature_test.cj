package seajson.tests

import seajson.*
import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

// ── Feature flag tests ────────────────────────────────────────
// Tests for JsonReadFeature flags (AllowTrailingComma, AllowComments, etc.)

@Test
public class JsonReadFeatureTestSuite {

    // ── AllowTrailingComma ─────────────────────────────────────

    @TestCase
    public func testAllowTrailingCommaInArray(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowTrailingComma)
        let v = parseJson("[1,2,]", features)
        match (v) {
            case JsonArrVal(items) => @Assert(items.size, 2)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testAllowTrailingCommaInObject(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowTrailingComma)
        let v = parseJson("{\"a\":1,\"b\":2,}", features)
        match (v) {
            case JsonObjVal(entries) => @Assert(entries.size, 2)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testAllowTrailingCommaInNestedStructure(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowTrailingComma)
        let v = parseJson("{\"arr\":[1,2,],\"obj\":{\"x\":1,},}", features)
        match (v) {
            case JsonObjVal(entries) => @Assert(entries.size, 2)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testTrailingCommaStillRejectedWithoutFeature(): Unit {
        var caught = false
        try {
            parseJson("[1,2,]")
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testTryParseWithTrailingComma(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowTrailingComma)
        let result = tryParseJson("[1,]", features)
        match (result) {
            case Some(v) => @Assert(isJsonArray(v), true)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testTryParseWithoutTrailingCommaFeature(): Unit {
        let result = tryParseJson("[1,]")
        match (result) {
            case None => @Assert(true, true)
            case Some(_) => @Assert(false, true)
        }
    }

    // ── AllowComments ─────────────────────────────────────────

    @TestCase
    public func testAllowSingleLineComment(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowComments)
        let v = parseJson("{\"name\":\"Alice\"// comment\n}", features)
        match (v) {
            case JsonObjVal(entries) => @Assert(entries.size, 1)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testAllowBlockComment(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowComments)
        let v = parseJson("{\"name\"/*block*/:\"Alice\"}", features)
        match (v) {
            case JsonObjVal(entries) => @Assert(entries.size, 1)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testAllowCommentBetweenArrayElements(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowComments)
        let v = parseJson("[1/*mid*/,2]", features)
        match (v) {
            case JsonArrVal(items) => @Assert(items.size, 2)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testAllowMultilineComment(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowComments)
        let json = """
{
    "a": 1, /* this is a
    multiline comment */
    "b": 2
}
"""
        let v = parseJson(json, features)
        match (v) {
            case JsonObjVal(entries) => @Assert(entries.size, 2)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testCommentStillRejectedWithoutFeature(): Unit {
        var caught = false
        try {
            parseJson("{\"a\":1//comment\n}")
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testUnterminatedBlockCommentError(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowComments)
        var caught = false
        try {
            parseJson("{\"a\":1/* not closed}", features)
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    // ── Combined features ─────────────────────────────────────

    @TestCase
    public func testTrailingCommaAndCommentsTogether(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowTrailingComma)
        features.add(AllowComments)
        let v = parseJson("[1, // first\n2, // second\n]", features)
        match (v) {
            case JsonArrVal(items) => @Assert(items.size, 2)
            case _ => @Assert(false, true)
        }
    }

    // ── Feature flag helper tests ──────────────────────────────

    @TestCase
    public func testHasReadFeatureTrue(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowTrailingComma)
        @Assert(hasReadFeature(features, AllowTrailingComma), true)
    }

    @TestCase
    public func testHasReadFeatureFalse(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowTrailingComma)
        @Assert(hasReadFeature(features, AllowComments), false)
    }

    @TestCase
    public func testHasReadFeatureEmpty(): Unit {
        let features = ArrayList<JsonReadFeature>()
        @Assert(hasReadFeature(features, AllowTrailingComma), false)
    }

    @TestCase
    public func testHasReadFeatureMultiple(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowTrailingComma)
        features.add(AllowComments)
        @Assert(hasReadFeature(features, AllowTrailingComma), true)
        @Assert(hasReadFeature(features, AllowComments), true)
        @Assert(hasReadFeature(features, AllowSingleQuotes), false)
    }

    // ── AllowSingleQuotes ──────────────────────────────────────

    @TestCase
    public func testAllowSingleQuotesStringValue(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowSingleQuotes)
        let v = parseJson("{'name':'Alice'}", features)
        match (v) {
            case JsonObjVal(entries) => @Assert(entries.size, 1)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testAllowSingleQuotesInArray(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowSingleQuotes)
        let v = parseJson("['a','b','c']", features)
        match (v) {
            case JsonArrVal(items) => @Assert(items.size, 3)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testAllowSingleQuotesEscapedQuote(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowSingleQuotes)
        let v = parseJson("{'key':'it\\'s'}", features)
        match (v) {
            case JsonObjVal(entries) => @Assert(entries.size, 1)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testSingleQuotesRejectedWithoutFeature(): Unit {
        var caught = false
        try {
            parseJson("{'a':1}")
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testMixedQuotesAllowed(): Unit {
        let features = ArrayList<JsonReadFeature>()
        features.add(AllowSingleQuotes)
        let v = parseJson("{\"single\":'value',\"double\":\"value\"}", features)
        match (v) {
            case JsonObjVal(entries) => @Assert(entries.size, 2)
            case _ => @Assert(false, true)
        }
    }
}
