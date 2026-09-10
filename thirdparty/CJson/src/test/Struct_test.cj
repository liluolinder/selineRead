package CJson.test

import CJson.*
import CJson.jsonmacro.*

@JsonSerializable
struct StructInTest {
    var name: String = "name"
    var age: Int64 = 0
 }

 @Test
class TestStruct {
    private let JSON = "{\"name\":\"new name\",\"age\":18}"

    //TODO:fix type mis-match issue with age below (int vs string),
    //in this case, deserialized age vlaue will be default value 0, not 18
    //the expected dehavior would be either throw or 18
    //private let JSON = "{\"name\":\"new name\",\"age\":\"18\"}"

    @TestCase
    func testTime(): Unit {
        @Assert(StructInTest.fromJson(JSON).toJson(), JSON)
    }
}