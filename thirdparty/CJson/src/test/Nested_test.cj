package CJson.test

import CJson.*
import CJson.jsonmacro.*

@JsonSerializable
class NestedChild {
    public var c1: Int64 = 1
}

@JsonSerializable
class NestedParent {
    public var p1: String = "v1"
    public var nested: Option<NestedChild> = NestedChild()
}

@Test
public class TestNested {
    private let NESTED_JSON = "{\"p1\":\"v1\",\"nested\":{\"c1\":10}}"
    private let NESTED_JSON2 = "{\"p1\":\"v1\",\"nested\":null}"
    @TestCase
    func testNestedFromJson(): Unit {
        var parent = NestedParent()
        var jsonValues = JsonValue.fromStr(NESTED_JSON).asObject()
        parent.p1 = jsonValues.get("p1").getOrThrow().asString().getValue()
        
        parent.nested = NestedChild()
        var nestedJson = jsonValues.get("nested").getOrThrow().asObject()
        parent.nested?.c1 = nestedJson.get("c1").getOrThrow().asInt().getValue()
        
        var parent1 = NestedParent.fromJson(NESTED_JSON)
        @Assert(parent.p1, parent1.p1)
        @Assert(parent.nested?.c1, parent1.nested?.c1)
    }

    @TestCase
    func testNestedToJson(): Unit {
        @Assert(NestedParent.fromJson(NESTED_JSON).toJson(), NESTED_JSON)
        @Assert(NestedParent.fromJson(NESTED_JSON2).toJson(), NESTED_JSON2)

    }
}