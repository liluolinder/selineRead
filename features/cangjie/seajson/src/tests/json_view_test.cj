package seajson.tests

import seajson.*
import std.collection.ArrayList

// ============================================================================
// Zero-copy JSON Parsing Tests
// ============================================================================

@Test
func testParseJsonViewBasic() {
    let json = "{\"name\":\"Alice\",\"age\":30}"
    let view = parseJsonView(json)
    
    @Assert(isJsonObjectView(view), true)
    @Assert(jsonObjSizeView(view), 2)
    
    // Zero-copy string access
    let name = jsonFieldStringView(view, "name")
    match (name) {
        case Some(sv) =>
            @Assert(sv.size(), 5)
            @Assert(sv.equals("Alice"), true)
        case None => @Assert(false, true)
    }
    
    // Integer access
    let age = jsonFieldIntView(view, "age")
    match (age) {
        case Some(n) => @Assert(n, 30)
        case None => @Assert(false, true)
    }
}

@Test
func testStringViewZeroCopy() {
    let json = "\"Hello, World!\""
    let view = parseJsonView(json)
    
    match (view) {
        case JsonStrViewVal(sv) =>
            @Assert(sv.size(), 13)
            @Assert(sv.equals("Hello, World!"), true)
            // Verify zero-copy: toString() creates new String
            let str = sv.toString()
            @Assert(str, "Hello, World!")
        case _ => @Assert(false, true)  // expected string view
    }
}

@Test
func testParseJsonViewArray() {
    let json = "[1,2,3]"
    let view = parseJsonView(json)
    
    @Assert(isJsonArrayView(view), true)
    @Assert(jsonArrSizeView(view), 3)
    
    for (i in 0..3) {
        let elem = jsonIndexView(view, i)
        match (elem) {
            case Some(e) =>
                let num = jsonAsIntView(e)
                match (num) {
                    case Some(n) => @Assert(n, i + 1)
                    case None => @Assert(false, true)
                }
            case None => @Assert(false, true)
        }
    }
}

@Test
func testParseJsonViewNested() {
    let json = "{\"outer\":{\"inner\":\"value\"}}"
    let view = parseJsonView(json)
    
    let outer = jsonFieldView(view, "outer")
    match (outer) {
        case Some(outerView) =>
            let inner = jsonFieldStringView(outerView, "inner")
            match (inner) {
                case Some(sv) => @Assert(sv.equals("value"), true)
                case None => @Assert(false, true)
            }
        case None => @Assert(false, true)
    }
}

@Test
func testViewToValueConversion() {
    let json = "{\"name\":\"Alice\",\"active\":true}"
    let view = parseJsonView(json)
    
    // Convert to regular JsonValue
    let value = viewToValue(view)
    
    @Assert(isJsonObject(value), true)
    let name = jsonFieldString(value, "name")
    match (name) {
        case Some(s) => @Assert(s, "Alice")
        case None => @Assert(false, true)
    }
    
    let active = jsonFieldBool(value, "active")
    match (active) {
        case Some(b) => @Assert(b, true)
        case None => @Assert(false, true)
    }
}

@Test
func testParseJsonViewWithEscapes() {
    // Strings with escapes must be copied
    let json = "{\"msg\":\"Hello\\nWorld\"}"
    let view = parseJsonView(json)
    
    let msg = jsonFieldStringView(view, "msg")
    match (msg) {
        case Some(sv) => @Assert(sv.equals("Hello\nWorld"), true)
        case None => @Assert(false, true)
    }
}

@Test
func testParseJsonViewBoolean() {
    let trueResult = jsonAsBoolView(parseJsonView("true"))
    match (trueResult) {
        case Some(b) => @Assert(b, true)
        case None => @Assert(false, true)
    }
    
    let falseResult = jsonAsBoolView(parseJsonView("false"))
    match (falseResult) {
        case Some(b) => @Assert(b, false)
        case None => @Assert(false, true)
    }
}

@Test
func testParseJsonViewNull() {
    let view = parseJsonView("null")
    @Assert(isJsonNullView(view), true)
}

@Test
func testParseJsonViewFloat() {
    let json = "{\"pi\":3.14159}"
    let view = parseJsonView(json)
    
    let pi = jsonFieldFloatView(view, "pi")
    match (pi) {
        case Some(f) => @Assert(f > 3.14 && f < 3.15, true)
        case None => @Assert(false, true)
    }
}

@Test
func testTryParseJsonViewInvalid() {
    let result = tryParseJsonView("{invalid}")
    match (result) {
        case Some(_) => @Assert(false, true)  // should be None
        case None => @Assert(true, true)
    }
}

@Test
func testStringViewSlice() {
    let json = "{\"text\":\"Hello World\"}"
    let view = parseJsonView(json)
    
    let text = jsonFieldStringView(view, "text")
    match (text) {
        case Some(sv) =>
            let slice = sv.slice(0, 5)
            @Assert(slice.equals("Hello"), true)
        case None => @Assert(false, true)
    }
}

@Test
func testStringViewByteAccess() {
    let json = "\"ABC\""
    let view = parseJsonView(json)
    
    match (view) {
        case JsonStrViewVal(sv) =>
            @Assert(sv.get(0), 65)  // 'A'
            @Assert(sv.get(1), 66)  // 'B'
            @Assert(sv.get(2), 67)  // 'C'
        case _ => @Assert(false, true)  // expected string view
    }
}

@Test
func testJsonHasKeyView() {
    let json = "{\"exists\":\"value\"}"
    let view = parseJsonView(json)
    
    @Assert(jsonHasKeyView(view, "exists"), true)
    @Assert(jsonHasKeyView(view, "missing"), false)
}

@Test
func testParseJsonViewWithFeature() {
    // Test with AllowTrailingComma
    let features = ArrayList<JsonReadFeature>()
    features.add(AllowTrailingComma)
    
    let json = "[1,2,]"
    let view = parseJsonView(json, features)
    
    @Assert(jsonArrSizeView(view), 2)
}

@Test
func testViewComparison() {
    let json = "[\"test\",\"test\",\"other\"]"
    let view = parseJsonView(json)
    
    let a = jsonIndexView(view, 0)
    let b = jsonIndexView(view, 1)
    let c = jsonIndexView(view, 2)
    
    match ((a, b, c)) {
        case (Some(JsonStrViewVal(sa)), Some(JsonStrViewVal(sb)), Some(JsonStrViewVal(sc))) =>
            // Same content
            @Assert(sa.equalsView(sb), true)
            // Different content
            @Assert(sa.equalsView(sc), false)
        case _ => @Assert(false, true)  // expected string views
    }
}

@Test
func testParseJsonViewEmptyStructures() {
    let emptyArr = parseJsonView("[]")
    @Assert(isJsonArrayView(emptyArr), true)
    @Assert(jsonArrSizeView(emptyArr), 0)
    
    let emptyObj = parseJsonView("{}")
    @Assert(isJsonObjectView(emptyObj), true)
    @Assert(jsonObjSizeView(emptyObj), 0)
    
    let emptyStr = parseJsonView("\"\"")
    match (emptyStr) {
        case JsonStrViewVal(sv) =>
            @Assert(sv.isEmpty(), true)
            @Assert(sv.size(), 0)
        case _ => @Assert(false, true)  // expected string view
    }
}
