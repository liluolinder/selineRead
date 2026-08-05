package gjson

import std.unittest.*
import std.unittest.testmacro.*
// 测试用例数据结构
class UnescapeTestCase {
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
class StringUtilsTest {
    @TestCase
    func testUnescape() {
        let testCases = [
            // 基础测试
            UnescapeTestCase(
                "no escapes",
                "hello world",
                "hello world"
            ),
            // 标准转义字符 - 使用元字符避免转义
            UnescapeTestCase(
                "standard escapes",
                #"\b\t\n\f\r\\\"\/"#,
                "\b\t\n\f\r\\\"/"
            ),
            // Unicode转义 - 使用元字符
            UnescapeTestCase(
                "unicode escape",
                #"\u4f60\u597d"#, // 你好
                "你好"
            ),
            // 混合转义 - 使用元字符
            UnescapeTestCase(
                "mixed escapes",
                #"hello\nworld\t\u4f60\b"#,
                "hello\nworld\t你\b"
            ),
            // 非法转义字符 - 使用元字符保留原样
            // UnescapeTestCase(
            //     "invalid escape",
            //     #"\x\y"#,
            //     #"\x\y"#
            // ),
            // 不完整Unicode转义
            // UnescapeTestCase(
            //     "incomplete unicode",
            //     #"\u123"#,
            //     #"\u123"#
            // ),
            // 空字符串
            UnescapeTestCase(
                "empty string",
                "",
                ""
            ),
            // 代理对
            // UnescapeTestCase(
            //     "surrogate pair",
            //     #"\uD83D\uDE00"#, // 😀
            //     "😀"
            // ),
            // 多层级转义
            UnescapeTestCase(
                "nested escapes",
                #"\\\u0061"#, // \a
                #"\a"#
            )
        ]

        for (testCase in testCases) {
            let got = unescape(testCase.input)
            @Assert(got, testCase.expected )
        }
    }
}
