package gjson

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*


@Test
class UtilsTest {
    // 测试 tonum
    @TestCase
    func testTonum() {
        let (raw, num) = tonum('-3.14}')
        @Assert(raw, "-3.14")
        @Assert(num, -3.14)
    }
    // ==================== squash 和 revSquash 测试 ====================
    @TestCase
    func testSquashAndRevSquash() {
        // squash 测试
        @Assert(squash(#"{"name":"value"}"#), #"{"name":"value"}"#)
        @Assert(squash(#"{"outer":{"inner":"value"}}"#), #"{"outer":{"inner":"value"}}"#)
        @Assert(squash(#"[1,2,3]"#), #"[1,2,3]"#)
        
        // revSquash 测试
        @Assert(revSquash(#"{"name":"value"}"#), #"{"name":"value"}"#)
        @Assert(revSquash(#"some text {"name":"value"}"#), #"{"name":"value"}"#)
    }

    // ==================== tolit 测试 ====================
    @TestCase
    func testTolit() {
        @Assert(tolit("true"), "true")
        @Assert(tolit("false"), "false")
        @Assert(tolit("null"), "null")
        // @Assert(tolit("truestuff"), "true")
    }

    // ==================== trim 测试 ====================
    @TestCase
    func testTrim() {
        @Assert(trimWhitespace("  hello  "), "hello")
        @Assert(trimWhitespace("  hello"), "hello")
        @Assert(trimWhitespace("hello  "), "hello")
        @Assert(trimWhitespace("hello"), "hello")
        // 回归测试: findLast 对单字符字符串返回空区间导致 trim 结果为空
        @Assert(trimWhitespace("h"), "h")
        @Assert(trimWhitespace("2"), "2")
    }

    // ==================== isDotPiperChar 测试 ====================
    @TestCase
    func testIsDotPiperChar() {
        @Assert(isDotPiperChar("@pretty"), true)  // 已注册的修饰符
        @Assert(isDotPiperChar("[test]"), true)
        @Assert(isDotPiperChar("{test}"), true)
        @Assert(isDotPiperChar("@test"), false)  // 未注册的修饰符
        @Assert(isDotPiperChar("test"), false)
    }

    // ==================== 真假值判断测试 ====================
    @TestCase
    func testTruthiness() {
        let nullResult = createNullResult()
        let falseResult = setResultBase(Kind.False, "")
        let stringFalseResult = createStringResult("\"false\"", "false")
        let numberResult = setResultBase(Kind.Number, "")
        let trueResult = setResultBase(Kind.True, "")
        let stringTrueResult = createStringResult("\"true\"", "true")
        let numberTrueResult = createNumberResult("", 1.0)

        // falseish 测试
        @Assert(falseish(nullResult), true)
        @Assert(falseish(falseResult), true)
        @Assert(falseish(stringFalseResult), true)
        @Assert(falseish(numberResult), true)

        // trueish 测试
        @Assert(trueish(trueResult), true)
        @Assert(trueish(stringTrueResult), true)
        @Assert(trueish(numberTrueResult), true)

        // nullish 测试
        @Assert(nullish(nullResult), true)
    }

    // ==================== queryMatches 测试 ====================
    @TestCase
    func testQueryMatches() {
        let stringQuery = ArrayPathResult(QueryInfo("=", "test"))
        let stringValue = Result(Kind.String, "\"test\"", "test", 0.0, 0, ArrayList<Int64>())
        let numberQuery = ArrayPathResult(QueryInfo("<",  "10"))
        let numberValue = Result(Kind.Number, "", "", 5.0, 0, ArrayList<Int64>())

        @Assert(queryMatches(stringQuery, stringValue), true)
        @Assert(queryMatches(numberQuery, numberValue), true)
    }

    // ==================== isSafePathKeyChar 测试 ====================
    @TestCase
    func testIsSafePathKeyChar() {
        @Assert(isSafePathKeyChar(b'a'), true)
        @Assert(isSafePathKeyChar(b'Z'), true)
        @Assert(isSafePathKeyChar(b'0'), true)
        @Assert(isSafePathKeyChar(b'_'), true)
        @Assert(isSafePathKeyChar(b'!'), false)
        @Assert(isSafePathKeyChar(b'@'), false)
    }
}