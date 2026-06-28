package seajson.tests

import seajson.*
import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

// ── Native reader conformance tests ──────────────────────────
// These verify the JsonReader parses JSON strings into JsonValue
// trees correctly. They should be the inverse of the writer tests.

@Test
public class JsonNativeReaderTestSuite {

    // ── Primitives ───────────────────────────────────────────

    @TestCase
    public func testParseNull(): Unit {
        let v = parseJson("null")
        match (v) {
            case JsonNull => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseTrue(): Unit {
        let v = parseJson("true")
        match (v) {
            case JsonBoolVal(b) => @Assert(b, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseFalse(): Unit {
        let v = parseJson("false")
        match (v) {
            case JsonBoolVal(b) => @Assert(b, false)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseInt(): Unit {
        let v = parseJson("42")
        match (v) {
            case JsonIntVal(n) => @Assert(n, 42)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseNegativeInt(): Unit {
        let v = parseJson("-7")
        match (v) {
            case JsonIntVal(n) => @Assert(n, -7)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseFloat(): Unit {
        let v = parseJson("3.14")
        match (v) {
            case JsonFloatVal(f) => @Assert(f > 3.0 && f < 3.2, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseString(): Unit {
        let v = parseJson("\"hello\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "hello")
            case _ => @Assert(false, true)
        }
    }

    // ── Array ────────────────────────────────────────────────

    @TestCase
    public func testParseEmptyArray(): Unit {
        let v = parseJson("[]")
        match (v) {
            case JsonArrVal(items) => @Assert(items.size, 0)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseIntArray(): Unit {
        let v = parseJson("[1,2,3]")
        match (v) {
            case JsonArrVal(items) =>
                @Assert(items.size, 3)
                match (items[0]) {
                    case JsonIntVal(n) => @Assert(n, 1)
                    case _ => @Assert(false, true)
                }
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseMixedArray(): Unit {
        let v = parseJson("[\"a\", 1, true, null]")
        match (v) {
            case JsonArrVal(items) => @Assert(items.size, 4)
            case _ => @Assert(false, true)
        }
    }

    // ── Object ───────────────────────────────────────────────

    @TestCase
    public func testParseEmptyObject(): Unit {
        let v = parseJson("{}")
        match (v) {
            case JsonObjVal(entries) => @Assert(entries.size, 0)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseSimpleObject(): Unit {
        let v = parseJson("{\"name\":\"SeaJson\",\"version\":1}")
        match (v) {
            case JsonObjVal(entries) =>
                @Assert(entries.size, 2)
                let (k1, v1) = entries[0]
                @Assert(k1, "name")
                match (v1) {
                    case JsonStrVal(s) => @Assert(s, "SeaJson")
                    case _ => @Assert(false, true)
                }
            case _ => @Assert(false, true)
        }
    }

    // ── Nested structures ────────────────────────────────────

    @TestCase
    public func testParseNestedObject(): Unit {
        let v = parseJson("{\"user\":{\"id\":42,\"active\":true}}")
        match (v) {
            case JsonObjVal(entries) =>
                @Assert(entries.size, 1)
                let (_, v1) = entries[0]
                match (v1) {
                    case JsonObjVal(inner) =>
                        @Assert(inner.size, 2)
                    case _ => @Assert(false, true)
                }
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseObjectWithArray(): Unit {
        let v = parseJson("{\"tags\":[\"json\",\"cangjie\"]}")
        match (v) {
            case JsonObjVal(entries) =>
                let (_, v1) = entries[0]
                match (v1) {
                    case JsonArrVal(items) => @Assert(items.size, 2)
                    case _ => @Assert(false, true)
                }
            case _ => @Assert(false, true)
        }
    }

    // ── String escapes ───────────────────────────────────────

    @TestCase
    public func testParseEscapedString(): Unit {
        let v = parseJson("\"hello\\nworld\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "hello\nworld")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseEscapedQuote(): Unit {
        let v = parseJson("\"say \\\"hi\\\"\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "say \"hi\"")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseEscapedBackslash(): Unit {
        let v = parseJson("\"C:\\\\Users\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "C:\\Users")
            case _ => @Assert(false, true)
        }
    }

    // ── Whitespace tolerance ─────────────────────────────────

    @TestCase
    public func testParseWithWhitespace(): Unit {
        let v = parseJson("  {  \"key\"  :  42  }  ")
        match (v) {
            case JsonObjVal(entries) => @Assert(entries.size, 1)
            case _ => @Assert(false, true)
        }
    }

    // ── Error handling ───────────────────────────────────────

    @TestCase
    public func testTryParseInvalidReturnsNone(): Unit {
        let result = tryParseJson("{invalid}")
        match (result) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testTryParseEmptyReturnsNone(): Unit {
        let result = tryParseJson("")
        match (result) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testTrailingCommaInObjectRejected(): Unit {
        var caught = false
        try {
            parseJson("{\"a\":1,}")
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testTrailingCommaInArrayRejected(): Unit {
        var caught = false
        try {
            parseJson("[1,]")
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testKeywordTrueFollowedByLetterRejected(): Unit {
        var caught = false
        try {
            parseJson("truex")
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testKeywordNullFollowedByLetterRejected(): Unit {
        var caught = false
        try {
            parseJson("nullx")
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    @TestCase
    public func testKeywordFalseFollowedByLetterRejected(): Unit {
        var caught = false
        try {
            parseJson("falsey")
        } catch (_: Exception) {
            caught = true
        }
        @Assert(caught, true)
    }

    // ── Round-trip: write then read ──────────────────────────

    @TestCase
    public func testRoundTripSimpleObject(): Unit {
        let original = buildJsonObject { w =>
            w.name("name").value("SeaJson")
            w.name("version").value(2)
        }
        let v = parseJson(original)
        match (v) {
            case JsonObjVal(entries) =>
                @Assert(entries.size, 2)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testRoundTripNested(): Unit {
        let original = buildJsonObject { w =>
            w.name("server").beginObject()
                .name("host").value("0.0.0.0")
                .name("port").value(8080)
            .endObject()
            w.name("tags").beginArray()
                .value("json")
                .value("cangjie")
            .endArray()
        }
        let v = parseJson(original)
        // Re-serialize and check it's valid
        let roundTripped = jsonValueToString(v)
        let v2 = parseJson(roundTripped)
        match (v2) {
            case JsonObjVal(entries) => @Assert(entries.size, 2)
            case _ => @Assert(false, true)
        }
    }
    // ── Unicode escapes ──────────────────────────────────────

    @TestCase
    public func testParseUnicodeEscapeBasicLatin(): Unit {
        // U+0041 = 'A'
        let v = parseJson("\"\\u0041\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "A")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseUnicodeEscapeCjkUnified(): Unit {
        // U+4E16 = '世'
        let v = parseJson("\"\\u4E16\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "\u{4E16}")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseUnicodeEscapeMulti(): Unit {
        // Two BMP characters: U+4E16 U+754C = '世界'
        let v = parseJson("\"\\u4E16\\u754C\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "\u{4E16}\u{754C}")
            case _ => @Assert(false, true)
        }
    }

    // ── Surrogate pairs (non-BMP) ───────────────────────────

    @TestCase
    public func testParseSurrogatePairEmoji(): Unit {
        // U+1F600 = 😀  →  \uD83D\uDE00
        let v = parseJson("\"\\uD83D\\uDE00\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "\u{1F600}")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseSurrogatePairMusicalSymbol(): Unit {
        // U+1D11E = 𝄞 (Musical Symbol G Clef)  →  \uD834\uDD1E
        let v = parseJson("\"\\uD834\\uDD1E\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "\u{1D11E}")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseLoneHighSurrogateReplaced(): Unit {
        // Lone high surrogate without matching low surrogate → U+FFFD
        let v = parseJson("\"\\uD83D\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "\u{FFFD}")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseHighSurrogateNotFollowedByUnicodeEscape(): Unit {
        // High surrogate followed by non-escape character → U+FFFD
        let v = parseJson("\"\\uD83Da\"")
        match (v) {
            case JsonStrVal(s) =>
                // FFFD + 'a'
                @Assert(s.size > 0, true)
                let runes = s.toRuneArray()
                @Assert(runes[0] == r'\u{FFFD}', true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseBmpAfterHighSurrogateFallback(): Unit {
        // High surrogate followed by BMP escape (not low surrogate) → U+FFFD + BMP char
        // \uD83D then \u0041 ('A')
        let v = parseJson("\"\\uD83D\\u0041\"")
        match (v) {
            case JsonStrVal(s) =>
                let runes = s.toRuneArray()
                @Assert(runes[0] == r'\u{FFFD}', true)
                @Assert(runes[1] == r'A', true)
            case _ => @Assert(false, true)
        }
    }

    // ── Number edge cases ─────────────────────────────────────

    @TestCase
    public func testParseLargeInt(): Unit {
        let v = parseJson("9007199254740991")  // 2^53 - 1 (safe integer)
        match (v) {
            case JsonIntVal(n) => @Assert(n, 9007199254740991)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseNegativeLargeInt(): Unit {
        let v = parseJson("-9007199254740991")
        match (v) {
            case JsonIntVal(n) => @Assert(n, -9007199254740991)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseScientificNotationPositive(): Unit {
        let v = parseJson("1.5e2")  // 150.0
        match (v) {
            case JsonFloatVal(f) => @Assert(f > 149.0 && f < 151.0, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseScientificNotationNegative(): Unit {
        let v = parseJson("1.5e-2")  // 0.015
        match (v) {
            case JsonFloatVal(f) => @Assert(f > 0.01 && f < 0.02, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseScientificNotationUpperE(): Unit {
        let v = parseJson("3E3")  // 3000.0
        match (v) {
            case JsonFloatVal(f) => @Assert(f > 2999.0 && f < 3001.0, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseZero(): Unit {
        let v = parseJson("0")
        match (v) {
            case JsonIntVal(n) => @Assert(n, 0)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseNegativeZero(): Unit {
        let v = parseJson("-0")
        match (v) {
            case JsonIntVal(n) => @Assert(n, 0)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseFloatZero(): Unit {
        let v = parseJson("0.0")
        match (v) {
            case JsonFloatVal(f) => @Assert(f == 0.0, true)
            case _ => @Assert(false, true)
        }
    }

    // ── Deep nesting ──────────────────────────────────────────

    @TestCase
    public func testParseDeeplyNestedObject(): Unit {
        // 5 levels of nesting
        let v = parseJson("{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":1}}}}}")
        match (v) {
            case JsonObjVal(entries) =>
                @Assert(entries.size, 1)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseDeeplyNestedArray(): Unit {
        // 5 levels of array nesting
        let v = parseJson("[[[[[1]]]]]")
        match (v) {
            case JsonArrVal(items) =>
                @Assert(items.size, 1)
            case _ => @Assert(false, true)
        }
    }

    // ── String edge cases ─────────────────────────────────────

    @TestCase
    public func testParseEmptyString(): Unit {
        let v = parseJson("\"\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseStringWithTab(): Unit {
        let v = parseJson("\"hello\\tworld\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "hello\tworld")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseStringWithCarriageReturn(): Unit {
        let v = parseJson("\"line1\\rline2\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "line1\rline2")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseStringWithFormFeed(): Unit {
        let v = parseJson("\"page1\\fpage2\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s.contains("\f"), true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseStringWithBackspace(): Unit {
        let v = parseJson("\"abc\\bdef\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s.contains("\b"), true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseStringWithSlash(): Unit {
        let v = parseJson("\"path\\/to\\/file\"")
        match (v) {
            case JsonStrVal(s) => @Assert(s, "path/to/file")
            case _ => @Assert(false, true)
        }
    }

    // ── Array edge cases ──────────────────────────────────────

    @TestCase
    public func testParseArrayOfArrays(): Unit {
        let v = parseJson("[[1,2],[3,4]]")
        match (v) {
            case JsonArrVal(items) =>
                @Assert(items.size, 2)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseArrayOfObjects(): Unit {
        let v = parseJson("[{\"a\":1},{\"b\":2}]")
        match (v) {
            case JsonArrVal(items) =>
                @Assert(items.size, 2)
            case _ => @Assert(false, true)
        }
    }

    // ── Object edge cases ─────────────────────────────────────

    @TestCase
    public func testParseObjectWithNumericKey(): Unit {
        // Keys are always strings in JSON
        let v = parseJson("{\"123\":456}")
        match (v) {
            case JsonObjVal(entries) =>
                @Assert(entries.size, 1)
                let (k, _) = entries[0]
                @Assert(k, "123")
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testParseObjectWithEmptyKey(): Unit {
        let v = parseJson("{\"\":1}")
        match (v) {
            case JsonObjVal(entries) =>
                @Assert(entries.size, 1)
                let (k, _) = entries[0]
                @Assert(k, "")
            case _ => @Assert(false, true)
        }
    }
}

// ── JsonDecodeError tests ────────────────────────────────────

@Test
public class JsonDecodeErrorTestSuite {

    @TestCase
    public func testErrorKindSyntax(): Unit {
        let err = JsonDecodeError(JsonErrSyntax, "bad token", offset: 5, line: 1, column: 6)
        let msg = err.message
        @Assert(msg.contains("SyntaxError"), true)
        @Assert(msg.contains("bad token"), true)
    }

    @TestCase
    public func testErrorKindMissingField(): Unit {
        let err = JsonDecodeError(JsonErrMissingField, "field 'name' not found", path: "$.user")
        let msg = err.message
        @Assert(msg.contains("MissingField"), true)
        @Assert(msg.contains("$.user"), true)
    }

    @TestCase
    public func testErrorKindEOF(): Unit {
        let err = JsonDecodeError(JsonErrEOF, "unexpected end", offset: 10)
        let msg = err.message
        @Assert(msg.contains("UnexpectedEOF"), true)
    }

    // ── Typed error catch tests ─────────────────────────────

    @TestCase
    public func testCatchTypedDecodeErrorFromParseJson(): Unit {
        var caught = false
        var errKind: ?JsonErrorKind = None
        var errOffset: Int64 = -99
        try {
            parseJson("{invalid}")
        } catch (e: JsonDecodeError) {
            caught = true
            errKind = e.kind
            errOffset = e.offset
        } catch (_: Exception) {
            // Should not reach here if typed error works
        }
        @Assert(caught, true)
        match (errKind) {
            case Some(JsonErrSyntax) => @Assert(true, true)
            case _ => @Assert(false, true)
        }
        @Assert(errOffset >= 0, true)
    }

    @TestCase
    public func testCatchTypedEOFFromEmptyInput(): Unit {
        var caught = false
        var errKind: ?JsonErrorKind = None
        try {
            parseJson("")
        } catch (e: JsonDecodeError) {
            caught = true
            errKind = e.kind
        } catch (_: Exception) {}
        @Assert(caught, true)
        match (errKind) {
            case Some(JsonErrEOF) => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testCatchTypedTrailingError(): Unit {
        var caught = false
        var errKind: ?JsonErrorKind = None
        try {
            parseJson("42 extra")
        } catch (e: JsonDecodeError) {
            caught = true
            errKind = e.kind
        } catch (_: Exception) {}
        @Assert(caught, true)
        match (errKind) {
            case Some(JsonErrTrailing) => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testDecodeErrorPreservesPosition(): Unit {
        var errLine: Int64 = -99
        var errCol: Int64 = -99
        try {
            parseJson("{\"key\": }")
        } catch (e: JsonDecodeError) {
            errLine = e.line
            errCol = e.column
        } catch (_: Exception) {}
        @Assert(errLine >= 1, true)
        @Assert(errCol >= 1, true)
    }

    // ── Path-aware error reporting ───────────────────────────

    @TestCase
    public func testErrorPathAtRoot(): Unit {
        var errPath = ""
        try {
            parseJson("{invalid}")
        } catch (e: JsonDecodeError) {
            errPath = e.path
        } catch (_: Exception) {}
        @Assert(errPath, "$")
    }

    @TestCase
    public func testErrorPathInNestedObject(): Unit {
        var errPath = ""
        try {
            parseJson("{\"user\":{\"name\":}}")
        } catch (e: JsonDecodeError) {
            errPath = e.path
        } catch (_: Exception) {}
        // Error occurs after reading key "name", so path is $.user.name
        @Assert(errPath, "$.user.name")
    }

    @TestCase
    public func testErrorPathInDeeplyNestedObject(): Unit {
        var errPath = ""
        try {
            parseJson("{\"a\":{\"b\":{\"c\":}}}")
        } catch (e: JsonDecodeError) {
            errPath = e.path
        } catch (_: Exception) {}
        // Error occurs after reading key "c", so path is $.a.b.c
        @Assert(errPath, "$.a.b.c")
    }

    @TestCase
    public func testErrorPathInArray(): Unit {
        var errPath = ""
        try {
            parseJson("{\"items\":[1,]}")
        } catch (e: JsonDecodeError) {
            errPath = e.path
        } catch (_: Exception) {}
        @Assert(errPath == "$.items" || errPath == "$.items[1]", true)
    }

    @TestCase
    public func testErrorPathInNestedArrayInObject(): Unit {
        var errPath = ""
        try {
            parseJson("{\"data\":{\"values\":[1,2,]}}")
        } catch (e: JsonDecodeError) {
            errPath = e.path
        } catch (_: Exception) {}
        // Error occurs inside array nested in object
        @Assert(errPath.startsWith("$.data.values"), true)
    }
}
