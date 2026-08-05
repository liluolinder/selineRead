package gjson

import std.unittest.*
import std.unittest.testmacro.*

@Test
class AdvancedTest {

    @TestCase
    func testLiterals() {
        let json = "{\"name\":\"Tom\",\"age\":37}"
        
        let literal1 = get(json, "!true")
        @Assert(literal1.raw, "true")
        
        let literal2 = get(json, "!false")
        @Assert(literal2.raw, "false")
        
        let literal3 = get(json, "!123")
        @Assert(literal3.raw, "123")
        
        let literal4 = get(json, "!\"Hello\"")
        @Assert(literal4.raw, "\"Hello\"")
        
        let literal5 = get(json, "!null")
        @Assert(literal5.raw, "null")
        
        let literal6 = get(json, "!HelloWorld")
        @Assert(literal6.raw, "\"HelloWorld\"")
    }

    @TestCase
    func testWildcards() {
        let json = "{\"name\":{\"first\":\"Tom\",\"last\":\"Anderson\"},\"age\":37,\"children\":[\"Sara\",\"Alex\",\"Jack\"]}"
        
        let wc1 = get(json, "c?ildren.0")
        @Assert(wc1.str, "Sara")
        
        let wc2 = get(json, "chi*.2")
        @Assert(wc2.str, "Jack")
        
        let wc3 = get(json, "na?e.first")
        @Assert(wc3.str, "Tom")
        
        let wc4 = get(json, "a?e")
        @Assert(wc4.num, 37.0)
    }

    @TestCase
    func testMultipaths() {
        let json = "{\"name\":{\"first\":\"Tom\",\"last\":\"Anderson\"},\"age\":37}"
        
        let multi1 = get(json, "{name.first,age}")
        @Assert(multi1.raw.contains("first"), true)
        @Assert(multi1.raw.contains("age"), true)
        @Assert(multi1.raw.contains("Tom"), true)
        @Assert(multi1.raw.contains("37"), true)
        
        let multi2 = get(json, "[name.first,age]")
        @Assert(multi2.raw.contains("Tom"), true)
        @Assert(multi2.raw.contains("37"), true)
        
        let multi3 = get(json, "{\"the_name\":name.first}")
        @Assert(multi3.raw.contains("the_name"), true)
        @Assert(multi3.raw.contains("Tom"), true)
    }

    @TestCase
    func testQuerySyntax() {
        let json = "{\"friends\":[{\"first\":\"Dale\",\"last\":\"Murphy\"},{\"first\":\"Roger\",\"last\":\"Craig\"},{\"first\":\"Jane\",\"last\":\"Murphy\"}]}"
        
        let q1 = get(json, "friends.0")
        @Assert(q1.exists(), true)
        @Assert(q1.raw.contains("Dale"), true)
        
        let q2 = get(json, "friends.1")
        @Assert(q2.exists(), true)
        @Assert(q2.raw.contains("Roger"), true)
    }

    @TestCase
    func testJSONLines() {
        let jsonLines = "{\"name\":\"Gilbert\",\"age\":61}\n{\"name\":\"Alexa\",\"age\":34}\n{\"name\":\"May\",\"age\":57}\n{\"name\":\"Deloise\",\"age\":44}"
        
        let lines1 = get(jsonLines, "..#")
        @Assert(lines1.exists(), true)
    }

    @TestCase
    func testDotVsPipe() {
        let json = "{\"friends\":[{\"first\":\"Dale\",\"last\":\"Murphy\"},{\"first\":\"Roger\",\"last\":\"Craig\"},{\"first\":\"Jane\",\"last\":\"Murphy\"}]}"
        
        let dp1 = get(json, "friends.0.first")
        @Assert(dp1.str, "Dale")
        
        let dp2 = get(json, "friends|0|first")
        @Assert(dp2.str, "Dale")
    }
}