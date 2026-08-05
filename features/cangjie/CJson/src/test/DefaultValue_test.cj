package CJson.test

import CJson.*
import CJson.jsonmacro.*

@JsonSerializable
class DefaultValueClass {
    public var p0: Int64 = 0
    public var p1: String = "v1"
    public var p2: Int64 = 99
    public var p3: Bool = false
    public var p4: Float64 = 10.99
    public var p5: Int32 = 32i32
    public var p6: Int16 = 16i16
    public var p7: Int8 = 8i8
    public var p8: Float32 = 32.099998f32
    public var p9: Float16 = 16.09375f16
}

@Test
public class TestDefaultValue {
    private let DEFAULT_VALUE_JSON = "{\"p0\":0}"
    private let DEFAULT_TOJSON = "{\"p0\":0,\"p1\":\"v1\",\"p2\":99,\"p3\":false,\"p4\":10.99,\"p5\":32,\"p6\":16,\"p7\":8,\"p8\":32.099998,\"p9\":16.09375}"
    
    @TestCase
    func testFromJson(): Unit {
        @Assert(DefaultValueClass.fromJson(DEFAULT_VALUE_JSON).toJson(), DEFAULT_TOJSON)
    }
}