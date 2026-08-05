package gjson

import std.unittest.*
import std.unittest.testmacro.*

// 测试用例数据结构
class StringParseTestCase {
    let name: String
    let input: String
    let start: Int64
    let wantIndex: Int64
    let wantStr: String
    let wantVesc: Bool
    let wantOk: Bool

    init(name: String, input: String, start: Int64, wantIndex: Int64, 
         wantStr: String, wantVesc: Bool, wantOk: Bool) {
        this.name = name
        this.input = input
        this.start = start
        this.wantIndex = wantIndex
        this.wantStr = wantStr
        this.wantVesc = wantVesc
        this.wantOk = wantOk
    }
}

@Test
class ParserTest {
    @TestCase
    func testParseString() {
        let testCases = [
            StringParseTestCase(
                 "basic string",
                #""hello""#,
                1,
                7,
                #""hello""#,
                false,
                true
            ),
            StringParseTestCase(
                 "escaped quote",
                #""hello \"world\"""#,
                1,
                17,
                #""hello \"world\"""#,
                true,
                true
            ),
            StringParseTestCase(
                 "unicode escape",
                #""hello \u4f60""#,
                1,
                14,
                #""hello \u4f60""#,
                true,
                true
            ),
            StringParseTestCase(
                 "mixed escapes",
                #""\b\t\n\f\r\\\/\"""#,
                1,
                18,
                #""\b\t\n\f\r\\\/\"""#,
                true,
                true
            ),
            StringParseTestCase(
                 "unterminated string",
                #""hello"#,
                1,
                6,
                 #""hello"#,
                false,
                false
            ),
            StringParseTestCase(
                 "empty string",
                #""""#,
                1,
                2,
                #""""#,
                false,
                true
            ),
            StringParseTestCase(
                 "invalid escape",
                #""\x""#,
                1,
                4,
                #""\x""#,
                true,
                true
            ),
            StringParseTestCase(
                 "only open quote",
                #"""#,
                1,
                1,
                #"""#,
                false,
                false
            ),
            StringParseTestCase(
                 "surrogate pair",
                #""\uD83D\uDE00""#,
                1,
                14,
                #""\uD83D\uDE00""#,
                true,
                true
            )
        ]

        for (testCase in testCases) {
            let strResult = parseString(testCase.input, testCase.start)
            @Assert(strResult.index ,testCase.wantIndex )
            @Assert(strResult.raw, testCase.wantStr)
            @Assert(strResult.escaped ,testCase.wantVesc)
            @Assert(strResult.ok,testCase.wantOk)
        }
    }
}