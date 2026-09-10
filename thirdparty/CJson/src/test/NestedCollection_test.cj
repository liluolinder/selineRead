package CJson.test

import CJson.*
import CJson.jsonmacro.*

@JsonSerializable
class ClassWithNestedCollction {
    public var p1: String = "v1"
    public var p2: Int64 = 1
    public var array: ArrayList<ArrayList<String>> =  ArrayList<ArrayList<String>>()
    //add two elements
    public var mapWithArrayList: HashMap<String, ArrayList<Int64>> = HashMap<String, ArrayList<Int64>>()
}



@Test
class TestNestedCollection {
    private let JSON_WITH_COLLECTION = "{\"p1\":\"v1\",\"p2\":299,\"array\":[[\"8\"],[\"7\"],[\"999\",\"25\"]],\"mapWithArrayList\":{\"key1\":[1,2,3],\"key2\":[4,5,6]}}"

    @TestCase
    func testToJson(): Unit {        
        @Assert(ClassWithNestedCollction.fromJson(JSON_WITH_COLLECTION).toJson(), JSON_WITH_COLLECTION)
    }
}