package CJson.test

import CJson.*
import CJson.jsonmacro.*

@JsonSerializable
class ClassWithCustomName {   
    public var stringVar1: String = "Value1"
    
    @JsonName["stringVar2_alias"]
    public var stringVar2: String = "Value2"
    
    public var intVar: Int64 = 10
}

@Test
public class TestCustomName {
    private let MYCLASS_JSON = "{\"stringVar1\": \"String1\",\"stringVar2_alias\": \"String2\", \"intVar\": 10}"

    @TestCase
    func testFromJson(): Unit {
        var myClass = ClassWithCustomName()
        var jsonValues = JsonValue.fromStr(MYCLASS_JSON).asObject()
        myClass.stringVar1 = jsonValues.get("stringVar1").getOrThrow().asString().getValue()
        myClass.stringVar2 = jsonValues.get("stringVar2_alias").getOrThrow().asString().getValue() 
        myClass.intVar = jsonValues.get("intVar").getOrThrow().asInt().getValue()
        
        var myClass1 = ClassWithCustomName.fromJson(MYCLASS_JSON)
        @Assert(myClass.stringVar1, myClass1.stringVar1)
        @Assert(myClass.stringVar2, myClass1.stringVar2)
        @Assert(myClass.intVar, myClass1.intVar)        
    }

    @TestCase
    func testToJson(): Unit {
        var myClass = ClassWithCustomName()
        myClass.stringVar1 = "String1"
        myClass.stringVar2 = "String2"
        myClass.intVar = 10

        var map: HashMap<String, JsonValue> = HashMap()
        map.add("stringVar1", JsonString(myClass.stringVar1))
        map.add("stringVar2_alias", JsonString(myClass.stringVar2))
        map.add("intVar", JsonInt(myClass.intVar))

        @Assert(JsonObject(map).toString(), myClass.toJson())
    }
}

main() {}
