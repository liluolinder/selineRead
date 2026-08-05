package CJson.test

import CJson.*
import CJson.jsonmacro.*

@JsonSerializable
class ClassWithIgnore {   
    public var stringVar: String = "Value1"    
    public var intVar: Int64 = 10

    @JsonIgnore
    public var ignored: String = "OriginalValue"
}

@Test
public class TestIgnore {
    private let MYCLASS_JSON_WITH_IGNORE = "{\"stringVar\": \"String1\", \"intVar\": 10, \"ignored\": \"IgnoredValue\"}"

    @TestCase
    func testIgnore(): Unit {
        var classWithIgnore = ClassWithIgnore()
        classWithIgnore.stringVar = "String1"
        classWithIgnore.intVar = 10
        classWithIgnore.ignored = "SomeValue"
        
        @Assert(!classWithIgnore.toJson().contains("ignored"), true)
        @Assert(ClassWithIgnore.fromJson(MYCLASS_JSON_WITH_IGNORE).ignored, "OriginalValue")

    }
}