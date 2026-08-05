package gjson

import std.unittest.*
import std.unittest.testmacro.*

@Test
class QueryTest {

    let friendsJson = "{\"friends\":[{\"first\":\"Dale\",\"last\":\"Murphy\",\"age\":44},{\"first\":\"Roger\",\"last\":\"Craig\",\"age\":68},{\"first\":\"Jane\",\"last\":\"Murphy\",\"age\":47}]}"

    @TestCase
    func testParseQueryValue() {
        let query = "#(last==\"Murphy\")"
        let result = parseQuery(query)
        
        @Assert(result.ok, true)
        @Assert(result.path, "last")
        @Assert(result.op, "==")
        @Assert(result.value, "\"Murphy\"")
    }

    @TestCase
    func testParseQueryAllFlag() {
        let path = "#(last==\"Murphy\")#.first"
        let result = parseArrayPath(path)
        
        @Assert(result.query.on, true)
        @Assert(result.query.all, true)
    }

    @TestCase
    func testQueryFirstMatch() {
        let result = get(friendsJson, "friends.#(last==\"Murphy\").first")
        @Assert(result.exists(), true)
        @Assert(result.str, "Dale")
    }

    @TestCase
    func testQueryAllMatches() {
        let result = get(friendsJson, "friends.#(last==\"Murphy\")#.first")
        @Assert(result.exists(), true)
        @Assert(result.raw.contains("Dale"), true)
        @Assert(result.raw.contains("Jane"), true)
    }

    @TestCase
    func testQueryGreaterThan() {
        let result = get(friendsJson, "friends.#(age>45)#.last")
        @Assert(result.exists(), true)
        @Assert(result.raw.contains("Craig"), true)
        @Assert(result.raw.contains("Murphy"), true)
    }

    @TestCase
    func testQueryLessThan() {
        let result = get(friendsJson, "friends.#(age<50).first")
        @Assert(result.exists(), true)
        @Assert(result.str, "Dale")
    }

    @TestCase
    func testQueryNotEqual() {
        let result = get(friendsJson, "friends.#(last!=\"Murphy\").first")
        @Assert(result.exists(), true)
        @Assert(result.str, "Roger")
    }

    @TestCase
    func testQueryPatternMatch() {
        let result = get(friendsJson, "friends.#(first%\"D*\").last")
        @Assert(result.exists(), true)
        @Assert(result.str, "Murphy")
    }

    @TestCase
    func testQueryPatternNotMatch() {
        let result = get(friendsJson, "friends.#(first!%\"D*\").last")
        @Assert(result.exists(), true)
        @Assert(result.str, "Craig")
    }

    @TestCase
    func testQueryGreaterEqual() {
        let result = get(friendsJson, "friends.#(age>=68).first")
        @Assert(result.exists(), true)
        @Assert(result.str, "Roger")
    }

    @TestCase
    func testQueryLessEqual() {
        let result = get(friendsJson, "friends.#(age<=44).first")
        @Assert(result.exists(), true)
        @Assert(result.str, "Dale")
    }

    @TestCase
    func testQueryNoMatch() {
        let result = get(friendsJson, "friends.#(last==\"NotFound\").first")
        @Assert(result.exists(), false)
    }
    
    @TestCase
    func testQueryAllMatchesNoSubPath() {
        let result = get(friendsJson, "friends.#(last==\"Murphy\")#")
        @Assert(result.exists(), true)
        @Assert(result.raw.contains("Dale"), true)
        @Assert(result.raw.contains("Jane"), true)
        @Assert(!result.raw.contains("Roger"), true)
    }
}