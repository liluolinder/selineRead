package seajson.tests

import seajson.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class JsonTextTestSuite {
    @TestCase
    public func testEscapeJsonTextEscapesAsciiControls(): Unit {
        let raw = "\u{0000}\u{0001}\b\f\n\r\t\"\\"
        let escaped = escapeJsonText(raw)
        @Assert(escaped, "\\u0000\\u0001\\b\\f\\n\\r\\t\\\"\\\\")
    }

    @TestCase
    public func testJsonStringLiteralWrapsAndEscapes(): Unit {
        let encoded = jsonStringLiteral("hello\n\"ignite\"")
        @Assert(encoded, "\"hello\\n\\\"ignite\\\"\"")
    }

    // ── Fast path optimization tests ──────────────────────────────

    @TestCase
    public func testEscapeJsonTextNoEscapeNeeded(): Unit {
        // Pure ASCII with no special characters should pass through
        let raw = "hello world 123"
        let escaped = escapeJsonText(raw)
        @Assert(escaped, raw)
    }

    @TestCase
    public func testEscapeJsonTextUnicodePassthrough(): Unit {
        // Non-ASCII Unicode should pass through unchanged
        let raw = "你好世界"
        let escaped = escapeJsonText(raw)
        @Assert(escaped, raw)
    }

    @TestCase
    public func testEscapeJsonTextMixedAsciiUnicode(): Unit {
        // Mix of ASCII and Unicode with no escapes needed
        let raw = "hello 你好"
        let escaped = escapeJsonText(raw)
        @Assert(escaped, raw)
    }

    @TestCase
    public func testEscapeJsonTextOnlyBackslash(): Unit {
        let raw = "path\\to\\file"
        let escaped = escapeJsonText(raw)
        @Assert(escaped, "path\\\\to\\\\file")
    }

    @TestCase
    public func testEscapeJsonTextOnlyQuote(): Unit {
        let raw = "say \"hello\""
        let escaped = escapeJsonText(raw)
        @Assert(escaped, "say \\\"hello\\\"")
    }

    @TestCase
    public func testEscapeJsonTextEmptyString(): Unit {
        let escaped = escapeJsonText("")
        @Assert(escaped, "")
    }

    @TestCase
    public func testJsonStringLiteralEmpty(): Unit {
        let encoded = jsonStringLiteral("")
        @Assert(encoded, "\"\"")
    }

    @TestCase
    public func testEscapeJsonTextAllControlCodes(): Unit {
        // Test all control codes U+0000 to U+001F
        var raw = ""
        var expected = ""
        var i: Int64 = 0
        while (i < 0x20) {
            raw += Rune(i).toString()
            if (i == 0x08) {
                expected += "\\b"
            } else if (i == 0x09) {
                expected += "\\t"
            } else if (i == 0x0A) {
                expected += "\\n"
            } else if (i == 0x0C) {
                expected += "\\f"
            } else if (i == 0x0D) {
                expected += "\\r"
            } else {
                expected += "\\u00" + byteToLowerHex(UInt8(i))
            }
            i += 1
        }
        let escaped = escapeJsonText(raw)
        @Assert(escaped, expected)
    }
}
