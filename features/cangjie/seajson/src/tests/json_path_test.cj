package seajson.tests

import seajson.*
import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

// ── JSONPath tests ────────────────────────────────────────────────

@Test
public class JsonPathTestSuite {

    // ── Basic path tests ──────────────────────────────────────────────

    @TestCase
    public func testRootPath(): Unit {
        let v = parseJson("{\"name\":\"test\"}")
        match (jsonPathOne(v, "$")) {
            case Some(result) => @Assert(isJsonObject(result), true)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testFieldAccess(): Unit {
        let v = parseJson("{\"name\":\"SeaJson\",\"version\":1}")
        match (jsonPathOne(v, "$.name")) {
            case Some(result) => @Assert(jsonAsStringOr(result, ""), "SeaJson")
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testNestedFieldAccess(): Unit {
        let v = parseJson("{\"store\":{\"book\":{\"title\":\"Guide\"}}}")
        match (jsonPathOne(v, "$.store.book.title")) {
            case Some(result) => @Assert(jsonAsStringOr(result, ""), "Guide")
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testMissingField(): Unit {
        let v = parseJson("{\"name\":\"test\"}")
        match (jsonPathOne(v, "$.missing")) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    // ── Array access tests ─────────────────────────────────────────────

    @TestCase
    public func testArrayIndex(): Unit {
        let v = parseJson("[10,20,30,40,50]")
        match (jsonPathOne(v, "$[2]")) {
            case Some(result) => @Assert(jsonAsIntOr(result, -1), 30)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testArrayIndexWithDot(): Unit {
        let v = parseJson("{\"items\":[1,2,3]}")
        match (jsonPathOne(v, "$.items[1]")) {
            case Some(result) => @Assert(jsonAsIntOr(result, -1), 2)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testArrayOutOfRange(): Unit {
        let v = parseJson("[1,2,3]")
        match (jsonPathOne(v, "$[10]")) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testNegativeArrayIndex(): Unit {
        let v = parseJson("[10,20,30]")
        match (jsonPathOne(v, "$[-1]")) {
            case Some(result) => @Assert(jsonAsIntOr(result, -1), 30)
            case None => @Assert(false, true)
        }
    }

    // ── Slice tests ────────────────────────────────────────────────────

    @TestCase
    public func testArraySlice(): Unit {
        let v = parseJson("[10,20,30,40,50]")
        match (jsonPathOne(v, "$[1:3]")) {
            case Some(result) => @Assert(jsonArrSize(result), 2)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testArraySliceFromStart(): Unit {
        let v = parseJson("[10,20,30,40,50]")
        match (jsonPathOne(v, "$[:2]")) {
            case Some(result) => @Assert(jsonArrSize(result), 2)
            case None => @Assert(false, true)
        }
    }

    // ── Quoted field name tests ────────────────────────────────────────

    @TestCase
    public func testQuotedFieldName(): Unit {
        let v = parseJson("{\"field name\":\"value\"}")
        match (jsonPathOne(v, "$['field name']")) {
            case Some(result) => @Assert(jsonAsStringOr(result, ""), "value")
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testDoubleQuotedFieldName(): Unit {
        let v = parseJson("{\"field\":\"value\"}")
        match (jsonPathOne(v, "$[\"field\"]")) {
            case Some(result) => @Assert(jsonAsStringOr(result, ""), "value")
            case None => @Assert(false, true)
        }
    }

    // ── Complex structure tests ────────────────────────────────────────

    @TestCase
    public func testComplexPath(): Unit {
        let json = """
        {
            "store": {
                "book": [
                    {"title": "Book 1", "price": 10},
                    {"title": "Book 2", "price": 20}
                ]
            }
        }
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$.store.book[0].title")) {
            case Some(result) => @Assert(jsonAsStringOr(result, ""), "Book 1")
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testSecondBookPrice(): Unit {
        let json = """
        {
            "store": {
                "book": [
                    {"title": "Book 1", "price": 10},
                    {"title": "Book 2", "price": 20}
                ]
            }
        }
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$.store.book[1].price")) {
            case Some(result) => @Assert(jsonAsIntOr(result, -1), 20)
            case None => @Assert(false, true)
        }
    }

    // ── jsonPathAll tests ───────────────────────────────────────────────

    @TestCase
    public func testJsonPathAllSingle(): Unit {
        let v = parseJson("{\"name\":\"test\"}")
        let results = jsonPathAll(v, "$.name")
        @Assert(results.size, 1)
        @Assert(jsonAsStringOr(results[0], ""), "test")
    }

    @TestCase
    public func testJsonPathAllEmpty(): Unit {
        let v = parseJson("{\"name\":\"test\"}")
        let results = jsonPathAll(v, "$.missing")
        @Assert(results.size, 0)
    }

    // ── Edge cases ──────────────────────────────────────────────────────

    @TestCase
    public func testEmptyPath(): Unit {
        let v = parseJson("{\"name\":\"test\"}")
        match (jsonPathOne(v, "")) {
            case Some(result) => @Assert(isJsonObject(result), true)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testPrimitiveRoot(): Unit {
        let v = parseJson("42")
        match (jsonPathOne(v, "$")) {
            case Some(result) => @Assert(jsonAsIntOr(result, -1), 42)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testArrayRoot(): Unit {
        let v = parseJson("[1,2,3]")
        match (jsonPathOne(v, "$[1]")) {
            case Some(result) => @Assert(jsonAsIntOr(result, -1), 2)
            case None => @Assert(false, true)
        }
    }

    // ── Recursive wildcard tests (v1.1.0) ─────────────────────────────────

    @TestCase
    public func testRecursiveWildcard(): Unit {
        let json = """
        {
            "a": {"x": 1, "y": 2},
            "b": {"x": 3, "y": 4}
        }
        """
        let v = parseJson(json)
        let results = jsonPathAll(v, "$..*")
        // Should collect: root, a, b, 1, 2, 3, 4
        @Assert(results.size > 0, true)
    }

    @TestCase
    public func testRecursiveWildcardOnArray(): Unit {
        let v = parseJson("[[1,2],[3,4]]")
        let results = jsonPathAll(v, "$..*")
        @Assert(results.size > 0, true)
    }

    @TestCase
    public func testRecursiveWildcardOnFlatArray(): Unit {
        let v = parseJson("[1,2,3]")
        let results = jsonPathAll(v, "$..*")
        @Assert(results.size >= 3, true)  // root + 3 elements
    }

    @TestCase
    public func testRecursiveWildcardOnFlatObject(): Unit {
        let v = parseJson("{\"a\":1,\"b\":2}")
        let results = jsonPathAll(v, "$..*")
        @Assert(results.size >= 2, true)
    }

    // ── Wildcard on array tests ───────────────────────────────────────────

    @TestCase
    public func testWildcardOnArray(): Unit {
        let v = parseJson("[1,2,3]")
        match (jsonPathOne(v, "$[*]")) {
            case Some(result) => @Assert(isJsonArray(result), true)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testWildcardOnObject(): Unit {
        let v = parseJson("{\"a\":1,\"b\":2}")
        match (jsonPathOne(v, "$[*]")) {
            case Some(result) => @Assert(isJsonObject(result), true)
            case None => @Assert(false, true)
        }
    }

    // ── Filter expression tests (v1.2.0) ────────────────────────────────────

    @TestCase
    public func testFilterLessThan(): Unit {
        let json = """
        [
            {"name": "Book 1", "price": 10},
            {"name": "Book 2", "price": 20},
            {"name": "Book 3", "price": 5}
        ]
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$[?(@.price < 15)]")) {
            case Some(result) =>
                @Assert(isJsonArray(result), true)
                @Assert(jsonArrSize(result), 2)  // Book 1 and Book 3
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testFilterGreaterThan(): Unit {
        let json = """
        [
            {"name": "Book 1", "price": 10},
            {"name": "Book 2", "price": 20},
            {"name": "Book 3", "price": 5}
        ]
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$[?(@.price > 10)]")) {
            case Some(result) =>
                @Assert(isJsonArray(result), true)
                @Assert(jsonArrSize(result), 1)  // Only Book 2
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testFilterEquals(): Unit {
        let json = """
        [
            {"name": "Alice", "age": 30},
            {"name": "Bob", "age": 25},
            {"name": "Charlie", "age": 30}
        ]
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$[?(@.age == 30)]")) {
            case Some(result) =>
                @Assert(isJsonArray(result), true)
                @Assert(jsonArrSize(result), 2)  // Alice and Charlie
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testFilterNotEquals(): Unit {
        let json = """
        [
            {"name": "Alice", "active": true},
            {"name": "Bob", "active": false},
            {"name": "Charlie", "active": true}
        ]
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$[?(@.active != true)]")) {
            case Some(result) =>
                @Assert(isJsonArray(result), true)
                @Assert(jsonArrSize(result), 1)  // Only Bob
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testFilterLessOrEqual(): Unit {
        let json = """
        [
            {"name": "A", "score": 50},
            {"name": "B", "score": 60},
            {"name": "C", "score": 70}
        ]
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$[?(@.score <= 60)]")) {
            case Some(result) =>
                @Assert(isJsonArray(result), true)
                @Assert(jsonArrSize(result), 2)  // A and B
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testFilterGreaterOrEqual(): Unit {
        let json = """
        [
            {"name": "A", "score": 50},
            {"name": "B", "score": 60},
            {"name": "C", "score": 70}
        ]
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$[?(@.score >= 60)]")) {
            case Some(result) =>
                @Assert(isJsonArray(result), true)
                @Assert(jsonArrSize(result), 2)  // B and C
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testFilterStringEquals(): Unit {
        let json = """
        [
            {"name": "Alice", "role": "admin"},
            {"name": "Bob", "role": "user"},
            {"name": "Charlie", "role": "admin"}
        ]
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$[?(@.role == 'admin')]")) {
            case Some(result) =>
                @Assert(isJsonArray(result), true)
                @Assert(jsonArrSize(result), 2)  // Alice and Charlie
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testFilterWithDoubleQuotes(): Unit {
        let json = """
        [
            {"name": "Alice", "role": "admin"},
            {"name": "Bob", "role": "user"}
        ]
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$[?(@.role == \"admin\")]")) {
            case Some(result) =>
                @Assert(isJsonArray(result), true)
                @Assert(jsonArrSize(result), 1)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testFilterNoMatch(): Unit {
        let json = """
        [
            {"name": "A", "price": 100},
            {"name": "B", "price": 200}
        ]
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$[?(@.price > 500)]")) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testFilterMissingField(): Unit {
        let json = """
        [
            {"name": "A", "price": 10},
            {"name": "B"}
        ]
        """
        let v = parseJson(json)
        match (jsonPathOne(v, "$[?(@.price < 20)]")) {
            case Some(result) =>
                @Assert(isJsonArray(result), true)
                @Assert(jsonArrSize(result), 1)  // Only A (B has no price)
            case None => @Assert(false, true)
        }
    }
}
