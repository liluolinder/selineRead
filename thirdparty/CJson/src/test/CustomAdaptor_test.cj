package CJson.test

import std.ast.*
import std.time.DateTime

import CJson.*
import CJson.jsonmacro.*

struct CustomTime {
    public CustomTime(let value: DateTime){
    }
}

extend CustomTime <: IJsonValueSerializable<CustomTime> {
    public static func fromJson(json: String) : CustomTime {
        return CustomTime.fromJsonValue(JsonValue.fromStr(json))
    }

    public static func fromJsonValue(json: JsonValue) : CustomTime {
        return CustomTime(DateTime.parse(json.asObject().get("value").getOrThrow().asString().getValue()[5..]))
    }

    public func toJsonValue(): JsonValue {
        var map: HashMap < String , JsonValue >= HashMap()
        let s = "CUST_"
        map.add("value", JsonString(String.join(s, this.value.toString())))
        return JsonObject(map)
    }

}

@JsonSerializable
class ClassWithCustomTimeAdaptor {
    public var intVar: Int64 = 10
    public var time: CustomTime = CustomTime(DateTime.now())
}

@Test
class TestCustomAdaptor {
    private let JSON_WITH_TIME = "{\"intVar\":10,\"time\":{\"value\":\"CUST_2022-12-21T03:21:51+08:00\"}}"

    @TestCase
    func testCustomTime(): Unit {
        @Assert(ClassWithCustomTimeAdaptor.fromJson(JSON_WITH_TIME).toJson(), JSON_WITH_TIME)
    }
}