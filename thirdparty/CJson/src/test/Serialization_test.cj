package CJson.test

import CJson.*
import CJson.jsonmacro.*

interface MyInterface {
    func rotate(): Unit
}

open class BaseClass {
    public func sayHello() {
        println("hello")
    }
}

@JsonSerializable
class MyClass <: BaseClass & MyInterface {   
    public var stringVar1: String = "Value1"
    
    @JsonName["stringVar2_alias"]
    public var stringVar2: String = "Value2"
    
    public var intVar: Int64 = 10
    public var boolVar: Bool = false
    public var floatVar: Float64 = 99.01

    public init() {
        this.stringVar2 = "stringVar2+"
    }

    public func rotate() {
        var v: String = this.stringVar2
        this.stringVar2 = this.stringVar1
        this.stringVar1 = v
    }
}

@JsonSerializable
class MyNewClass <: BaseClass & MyInterface {   
    public var stringVar1: String = "S1C"
    
    @JsonName["stringVar2_alias2"]
    public var stringVar2: String = "S2C"
    
    public var v4: Int64 = 10

    public init() {

    }

    public func rotate() {
        var v: String = this.stringVar2
        this.stringVar2 = this.stringVar1
        this.stringVar1 = v
    }
}

@Test
public class TestSerialization {
    private let MYCLASS_JSON = "{\"stringVar1\": \"String1\",\"stringVar2_alias\": \"String2\", \"intVar\": 10, \"boolVar\": true, \"floatVar\": 38.09}"
    private let MYNEWCLASS_JSON = "{\"stringVar1\": \"S1\",\"stringVar2_alias2\": \"S2\", \"v4\": 10}"

    @TestCase
    func testFromJson(): Unit {
        var myClass = MyClass()
        var jsonValues = JsonValue.fromStr(MYCLASS_JSON).asObject()
        myClass.stringVar1 = jsonValues.get("stringVar1").getOrThrow().asString().getValue()
        myClass.stringVar2 = jsonValues.get("stringVar2_alias").getOrThrow().asString().getValue() 
        myClass.intVar = jsonValues.get("intVar").getOrThrow().asInt().getValue()
        myClass.boolVar = jsonValues.get("boolVar").getOrThrow().asBool().getValue()
        myClass.floatVar = jsonValues.get("floatVar").getOrThrow().asFloat().getValue()

        var myClass1 = MyClass.fromJson(MYCLASS_JSON)
        @Assert(myClass.stringVar1, myClass1.stringVar1)
        @Assert(myClass.stringVar2, myClass1.stringVar2)
        @Assert(myClass.intVar, myClass1.intVar)
        @Assert(myClass.boolVar, myClass1.boolVar)
        @Assert(myClass.floatVar, myClass1.floatVar)
    }

    @TestCase
    func testToJson(): Unit {
        var myClass = MyClass()
        myClass.stringVar1 = "String1"
        myClass.stringVar2 = "String2"
        myClass.intVar = 10
        myClass.boolVar = true
        myClass.floatVar = 38.09

        var map: HashMap<String, JsonValue> = HashMap()
        map.add("stringVar1", JsonString(myClass.stringVar1))
        map.add("stringVar2_alias", JsonString(myClass.stringVar2))
        map.add("intVar", JsonInt(myClass.intVar))
        map.add("boolVar", JsonBool(myClass.boolVar))
        map.add("floatVar", JsonFloat(myClass.floatVar))

        @Assert(JsonObject(map).toString(), myClass.toJson())
    }

    @TestCase
    func testFromJsonForTwoCustomName(): Unit {
        var myClass = MyClass()
        var jsonValues = JsonValue.fromStr(MYCLASS_JSON).asObject()
        myClass.stringVar1 = jsonValues.get("stringVar1").getOrThrow().asString().getValue()
        myClass.stringVar2 = jsonValues.get("stringVar2_alias").getOrThrow().asString().getValue() 
        myClass.intVar = jsonValues.get("intVar").getOrThrow().asInt().getValue()

        var myClass1 = MyClass.fromJson(MYCLASS_JSON)
        @Assert(myClass.stringVar1, myClass1.stringVar1)
        @Assert(myClass.stringVar2, myClass1.stringVar2)
        @Assert(myClass.intVar, myClass1.intVar)

        var myNewClass = MyNewClass()
        var jsonValues2 = JsonValue.fromStr(MYNEWCLASS_JSON).asObject()
        myNewClass.stringVar1 = jsonValues2.get("stringVar1").getOrThrow().asString().getValue()
        myNewClass.stringVar2 = jsonValues2.get("stringVar2_alias2").getOrThrow().asString().getValue() 
        myNewClass.v4 = jsonValues2.get("v4").getOrThrow().asInt().getValue()

        var myNewClass2 = MyNewClass.fromJson(MYNEWCLASS_JSON)
        @Assert(myNewClass.stringVar1, myNewClass2.stringVar1)
        @Assert(myNewClass.stringVar2, myNewClass2.stringVar2)
        @Assert(myNewClass.v4, myNewClass2.v4)
    }
}