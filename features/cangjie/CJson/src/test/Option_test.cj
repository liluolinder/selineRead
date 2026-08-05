package CJson.test

import CJson.*
import CJson.jsonmacro.*

@JsonSerializable
class ClassWithOption {   
    public var optionalStringWithoutValue: Option<String> = None
    public var optionalInt64WithoutValue: Option<Int64> = None

    public var optionalStringWithValue: Option<String> = "StringValue"
    public var optionalInt64WithValue: Option<Int64> = 199
}

@Test
public class TestOption {
    private let MYCLASS_JSON_WITH_OPTION = 
"""
    {\"stringVar\": \"String1\", 
    \"intVar\": 10, 
    \"optionalStringWithoutValue\": null,
    \"optionalInt64WithoutValue\": null,
    \"optionalInt64WithValue\": 1001,
    \"optionalStringWithValue\": \"StringValue\"}
"""

    @TestCase
    func testOption(): Unit {
        var json = JsonValue.fromStr(MYCLASS_JSON_WITH_OPTION).asObject()
        var classWithOption = ClassWithOption()
        @Assert(classWithOption.toJson().contains("StringValue"), true)
        @Assert(classWithOption.toJson().contains("199"), true)
        
        let fromJson = ClassWithOption.fromJson(MYCLASS_JSON_WITH_OPTION)
        @Assert(fromJson.optionalStringWithoutValue, None)
        @Assert(fromJson.optionalInt64WithoutValue, None)
        @Assert(fromJson.optionalStringWithValue, "StringValue")
        @Assert(fromJson.optionalInt64WithValue, 1001)
    }
}