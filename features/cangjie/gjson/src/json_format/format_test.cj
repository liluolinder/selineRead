package gjson.json_format

import std.unittest.*
import std.unittest.testmacro.*

class FormatTestCase {
    let name: String
    let input: String
    let expected: String

    init(name: String, input: String, expected: String) {
        this.name = name
        this.input = input
        this.expected = expected
    }
}

@Test
class FormatTest {
    @TestCase
    func testPretty() {
        let testCases = [
            FormatTestCase(
                "empty string",
                "",
                ""
            ),
            FormatTestCase(
                "simple object",
                #"{"name":"John","age":30}"#,
                ###"{
  "name": "John",
  "age": 30
}"###
            ),
            FormatTestCase(
                "simple array",
                #"[1,2,3]"#,
                ###"[
  1,
  2,
  3
]"###
            )
        ]

        for (testCase in testCases) {
            let got = pretty(testCase.input)
            @Assert(got, testCase.expected)
        }
    }

    @TestCase
    func testUgly() {
        let testCases = [
            FormatTestCase(
                "empty string",
                "",
                ""
            ),
            FormatTestCase(
                "formatted object",
                ###"{
  "name": "John",
  "age": 30
}"###,
                #"{"name":"John","age":30}"#
            ),
            FormatTestCase(
                "mixed whitespace",
                #"{ \t "name" \n: \r "John" \t }"#,
                #"{\t"name"\n:\r"John"\t}"#
            ),
            FormatTestCase(
                "real whitespace characters",
                "{ \t \"name\" \n: \r \"John\" \t }",
                #"{"name":"John"}"#
            )
        ]

        for (testCase in testCases) {
            let got = ugly(testCase.input)
            @Assert(got, testCase.expected)
        }
    }

    @TestCase
    func testPrettyUglyRoundtrip() {
        let testCases = [
            #"{"name":"John","age":30,"active":true}"#,
            #"[1,2,3]"#
        ]

        for (testCase in testCases) {
            let prettified = pretty(testCase)
            let uglified = ugly(prettified)
            @Assert(uglified, testCase)
        }
    }
}