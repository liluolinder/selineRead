package seajson.tests

import seajson.*
import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class JsonBuilderTestSuite {
    @TestCase
    public func testJoinJsonFieldsProducesStableLines(): Unit {
        let fields = ArrayList<String>()
        fields.add("  \"a\": 1")
        fields.add("  \"b\": true")
        @Assert(joinJsonFields(fields), "  \"a\": 1,\n  \"b\": true\n")
    }

    @TestCase
    public func testJsonObjectBuildsStableObject(): Unit {
        let fields = ArrayList<String>()
        fields.add(jsonStringField("name", "ignite"))
        fields.add(jsonField("ok", "true"))
        @Assert(jsonObject(fields), "{\n  \"name\": \"ignite\",\n  \"ok\": true\n}")
    }

    // ── Additional builder tests ───────────────────────────────────

    @TestCase
    public func testJoinJsonFieldsSingleField(): Unit {
        let fields = ArrayList<String>()
        fields.add("  \"key\": \"value\"")
        let result = joinJsonFields(fields)
        @Assert(result, "  \"key\": \"value\"\n")
    }

    @TestCase
    public func testJoinJsonFieldsEmpty(): Unit {
        let fields = ArrayList<String>()
        let result = joinJsonFields(fields)
        @Assert(result, "")
    }

    @TestCase
    public func testJsonObjectEmpty(): Unit {
        let fields = ArrayList<String>()
        let result = jsonObject(fields)
        // Empty object still has newlines: "{\n" + "" + "}"
        @Assert(result, "{\n}")
    }

    @TestCase
    public func testJsonFieldWithCustomIndent(): Unit {
        let result = jsonField("key", "42", indent: "    ")
        @Assert(result, "    \"key\": 42")
    }

    @TestCase
    public func testJsonStringFieldWithEscape(): Unit {
        let result = jsonStringField("msg", "hello\nworld")
        @Assert(result.contains("\\n"), true)
    }

    @TestCase
    public func testJsonStringFieldWithCustomIndent(): Unit {
        let result = jsonStringField("name", "test", indent: "\t")
        @Assert(result.startsWith("\t"), true)
    }

    @TestCase
    public func testJsonObjectMultipleFields(): Unit {
        let fields = ArrayList<String>()
        fields.add(jsonStringField("a", "1"))
        fields.add(jsonStringField("b", "2"))
        fields.add(jsonStringField("c", "3"))
        let result = jsonObject(fields)
        @Assert(result.contains("\"a\":"), true)
        @Assert(result.contains("\"b\":"), true)
        @Assert(result.contains("\"c\":"), true)
    }
}
