package seajson.tests

import seajson.*
import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

// ── JsonValue query / extraction tests ───────────────────────

@Test
public class JsonValueQueryTestSuite {

    @TestCase
    public func testJsonFieldString(): Unit {
        let v = parseJson("{\"name\":\"SeaJson\",\"version\":1}")
        match (jsonFieldString(v, "name")) {
            case Some(s) => @Assert(s, "SeaJson")
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonFieldInt(): Unit {
        let v = parseJson("{\"name\":\"SeaJson\",\"version\":1}")
        match (jsonFieldInt(v, "version")) {
            case Some(n) => @Assert(n, 1)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonFieldBool(): Unit {
        let v = parseJson("{\"active\":true}")
        match (jsonFieldBool(v, "active")) {
            case Some(b) => @Assert(b, true)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonFieldMissingReturnsNone(): Unit {
        let v = parseJson("{\"name\":\"SeaJson\"}")
        match (jsonFieldString(v, "missing")) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonFieldOnNonObjectReturnsNone(): Unit {
        let v = parseJson("42")
        match (jsonFieldString(v, "key")) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonIndex(): Unit {
        let v = parseJson("[10,20,30]")
        match (jsonIndex(v, 1)) {
            case Some(JsonIntVal(n)) => @Assert(n, 20)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonIndexOutOfBounds(): Unit {
        let v = parseJson("[10,20,30]")
        match (jsonIndex(v, 5)) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonArrSize(): Unit {
        let v = parseJson("[1,2,3]")
        @Assert(jsonArrSize(v), 3)
    }

    @TestCase
    public func testJsonArrSizeOnNonArray(): Unit {
        let v = parseJson("42")
        @Assert(jsonArrSize(v), -1)
    }

    @TestCase
    public func testIsJsonNull(): Unit {
        @Assert(isJsonNull(parseJson("null")), true)
        @Assert(isJsonNull(parseJson("0")), false)
    }

    @TestCase
    public func testNestedFieldAccess(): Unit {
        let v = parseJson("{\"user\":{\"name\":\"alice\",\"age\":30}}")
        match (jsonFieldObj(v, "user")) {
            case Some(userObj) =>
                match (jsonFieldString(userObj, "name")) {
                    case Some(name) => @Assert(name, "alice")
                    case None => @Assert(false, true)
                }
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testFieldFloat(): Unit {
        let v = parseJson("{\"pi\":3.14}")
        match (jsonFieldFloat(v, "pi")) {
            case Some(f) => @Assert(f > 3.0 && f < 3.2, true)
            case None => @Assert(false, true)
        }
    }

    // ── Int32 support tests ─────────────────────────────────────

    @TestCase
    public func testJsonInt32Construction(): Unit {
        let v = jsonInt32(42)
        @Assert(jsonValueToString(v), "42")
    }

    @TestCase
    public func testJsonFieldInt32(): Unit {
        let v = parseJson("{\"count\":100}")
        match (jsonFieldInt32(v, "count")) {
            case Some(n) => @Assert(n, 100)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonFieldIntFromInt32(): Unit {
        // Int32 field should be readable as Int64
        let entries = ArrayList<(String, JsonValue)>()
        entries.add(("num", jsonInt32(42)))
        let v = jsonObj(entries)
        match (jsonFieldInt(v, "num")) {
            case Some(n) => @Assert(n, Int64(42))
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonFieldInt32FromInt64(): Unit {
        // Int64 field should be readable as Int32 (if in range)
        let v = parseJson("{\"count\":42}")
        match (jsonFieldInt32(v, "count")) {
            case Some(n) => @Assert(n, 42)
            case None => @Assert(false, true)
        }
    }

    // ── jsonHasKey tests ─────────────────────────────────────────

    @TestCase
    public func testJsonHasKeyPresent(): Unit {
        let v = parseJson("{\"name\":\"SeaJson\"}")
        @Assert(jsonHasKey(v, "name"), true)
    }

    @TestCase
    public func testJsonHasKeyMissing(): Unit {
        let v = parseJson("{\"name\":\"SeaJson\"}")
        @Assert(jsonHasKey(v, "missing"), false)
    }

    @TestCase
    public func testJsonHasKeyOnNonObject(): Unit {
        let v = parseJson("42")
        @Assert(jsonHasKey(v, "key"), false)
    }

    // ── jsonKeys tests ───────────────────────────────────────────

    @TestCase
    public func testJsonKeysFromObject(): Unit {
        let v = parseJson("{\"a\":1,\"b\":2,\"c\":3}")
        let keys = jsonKeys(v)
        @Assert(keys.size, 3)
    }

    @TestCase
    public func testJsonKeysFromEmptyObject(): Unit {
        let v = parseJson("{}")
        let keys = jsonKeys(v)
        @Assert(keys.size, 0)
    }

    @TestCase
    public func testJsonKeysOnNonObject(): Unit {
        let v = parseJson("42")
        let keys = jsonKeys(v)
        @Assert(keys.size, 0)
    }

    // ── jsonObjSize tests ────────────────────────────────────────

    @TestCase
    public func testJsonObjSizeFromObject(): Unit {
        let v = parseJson("{\"a\":1,\"b\":2}")
        @Assert(jsonObjSize(v), 2)
    }

    @TestCase
    public func testJsonObjSizeFromEmptyObject(): Unit {
        let v = parseJson("{}")
        @Assert(jsonObjSize(v), 0)
    }

    @TestCase
    public func testJsonObjSizeOnNonObject(): Unit {
        let v = parseJson("42")
        @Assert(jsonObjSize(v), -1)
    }

    // ── jsonFieldArrSize tests ───────────────────────────────────

    @TestCase
    public func testJsonFieldArrSizeFromField(): Unit {
        let v = parseJson("{\"items\":[1,2,3,4,5]}")
        @Assert(jsonFieldArrSize(v, "items"), 5)
    }

    @TestCase
    public func testJsonFieldArrSizeMissingField(): Unit {
        let v = parseJson("{\"name\":\"test\"}")
        @Assert(jsonFieldArrSize(v, "items"), -1)
    }

    @TestCase
    public func testJsonFieldArrSizeNonArrayField(): Unit {
        let v = parseJson("{\"items\":\"not an array\"}")
        @Assert(jsonFieldArrSize(v, "items"), -1)
    }

    // ── Type predicate tests ──────────────────────────────────────

    @TestCase
    public func testIsJsonObject(): Unit {
        @Assert(isJsonObject(parseJson("{}")), true)
        @Assert(isJsonObject(parseJson("[]")), false)
        @Assert(isJsonObject(parseJson("42")), false)
    }

    @TestCase
    public func testIsJsonArray(): Unit {
        @Assert(isJsonArray(parseJson("[]")), true)
        @Assert(isJsonArray(parseJson("{}")), false)
        @Assert(isJsonArray(parseJson("42")), false)
    }

    @TestCase
    public func testIsJsonString(): Unit {
        @Assert(isJsonString(parseJson("\"hello\"")), true)
        @Assert(isJsonString(parseJson("42")), false)
        @Assert(isJsonString(parseJson("null")), false)
    }

    @TestCase
    public func testIsJsonNumber(): Unit {
        @Assert(isJsonNumber(parseJson("42")), true)
        @Assert(isJsonNumber(parseJson("3.14")), true)
        @Assert(isJsonNumber(parseJson("\"42\"")), false)
    }

    @TestCase
    public func testIsJsonBool(): Unit {
        @Assert(isJsonBool(parseJson("true")), true)
        @Assert(isJsonBool(parseJson("false")), true)
        @Assert(isJsonBool(parseJson("1")), false)
    }

    // ── Extraction with defaults tests ────────────────────────────

    @TestCase
    public func testJsonFieldStringOr(): Unit {
        let v = parseJson("{\"name\":\"SeaJson\"}")
        @Assert(jsonFieldStringOr(v, "name", "default"), "SeaJson")
        @Assert(jsonFieldStringOr(v, "missing", "default"), "default")
    }

    @TestCase
    public func testJsonFieldIntOr(): Unit {
        let v = parseJson("{\"count\":42}")
        @Assert(jsonFieldIntOr(v, "count", 0), 42)
        @Assert(jsonFieldIntOr(v, "missing", 0), 0)
    }

    @TestCase
    public func testJsonFieldBoolOr(): Unit {
        let v = parseJson("{\"active\":true}")
        @Assert(jsonFieldBoolOr(v, "active", false), true)
        @Assert(jsonFieldBoolOr(v, "missing", false), false)
    }

    @TestCase
    public func testJsonFieldFloatOr(): Unit {
        let v = parseJson("{\"pi\":3.14}")
        @Assert(jsonFieldFloatOr(v, "pi", 0.0) > 3.0, true)
        @Assert(jsonFieldFloatOr(v, "missing", 2.71) < 3.0, true)
    }

    // ── Quick construction tests ──────────────────────────────────

    @TestCase
    public func testJsonArrayOf(): Unit {
        let items = ArrayList<JsonValue>()
        items.add(jsonInt(1))
        items.add(jsonInt(2))
        items.add(jsonInt(3))
        let arr = jsonArrayOf(items)
        match (arr) {
            case JsonArrVal(items) => @Assert(items.size, 3)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonEmptyArray(): Unit {
        let arr = jsonEmptyArray()
        match (arr) {
            case JsonArrVal(items) => @Assert(items.size, 0)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonEmptyObject(): Unit {
        let obj = jsonEmptyObject()
        match (obj) {
            case JsonObjVal(entries) => @Assert(entries.size, 0)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonObjectOf(): Unit {
        let entries = ArrayList<(String, JsonValue)>()
        entries.add(("name", jsonStr("SeaJson")))
        entries.add(("version", jsonInt(1)))
        let obj = jsonObjectOf(entries)
        match (obj) {
            case JsonObjVal(entries) => @Assert(entries.size, 2)
            case _ => @Assert(false, true)
        }
        @Assert(jsonFieldStringOr(obj, "name", ""), "SeaJson")
        @Assert(jsonFieldIntOr(obj, "version", 0), 1)
    }

    // ── Direct type conversion tests (0.5.0) ───────────────────────

    @TestCase
    public func testJsonAsString(): Unit {
        let v = parseJson("\"hello\"")
        match (jsonAsString(v)) {
            case Some(s) => @Assert(s, "hello")
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonAsStringOnNonString(): Unit {
        let v = parseJson("42")
        match (jsonAsString(v)) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonAsInt(): Unit {
        let v = parseJson("42")
        match (jsonAsInt(v)) {
            case Some(n) => @Assert(n, 42)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonAsIntOnNonInt(): Unit {
        let v = parseJson("\"not a number\"")
        match (jsonAsInt(v)) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonAsFloat(): Unit {
        let v = parseJson("3.14")
        match (jsonAsFloat(v)) {
            case Some(f) => @Assert(f > 3.0 && f < 3.2, true)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonAsFloatFromInt(): Unit {
        // Int should be convertible to Float
        let v = parseJson("42")
        match (jsonAsFloat(v)) {
            case Some(f) => @Assert(f, 42.0)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonAsBool(): Unit {
        let v = parseJson("true")
        match (jsonAsBool(v)) {
            case Some(b) => @Assert(b, true)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonAsBoolFalse(): Unit {
        let v = parseJson("false")
        match (jsonAsBool(v)) {
            case Some(b) => @Assert(b, false)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonAsBoolOnNonBool(): Unit {
        let v = parseJson("1")
        match (jsonAsBool(v)) {
            case None => @Assert(true, true)
            case _ => @Assert(false, true)
        }
    }

    @TestCase
    public func testJsonAsStringOr(): Unit {
        let v = parseJson("\"hello\"")
        @Assert(jsonAsStringOr(v, "default"), "hello")
        let v2 = parseJson("42")
        @Assert(jsonAsStringOr(v2, "default"), "default")
    }

    @TestCase
    public func testJsonAsIntOr(): Unit {
        let v = parseJson("42")
        @Assert(jsonAsIntOr(v, 0), 42)
        let v2 = parseJson("\"not an int\"")
        @Assert(jsonAsIntOr(v2, 99), 99)
    }

    @TestCase
    public func testJsonAsFloatOr(): Unit {
        let v = parseJson("3.14")
        @Assert(jsonAsFloatOr(v, 0.0) > 3.0, true)
        let v2 = parseJson("\"not a float\"")
        @Assert(jsonAsFloatOr(v2, 2.71) < 3.0, true)
    }

    @TestCase
    public func testJsonAsBoolOr(): Unit {
        let v = parseJson("true")
        @Assert(jsonAsBoolOr(v, false), true)
        let v2 = parseJson("42")
        @Assert(jsonAsBoolOr(v2, true), true)
    }
}
