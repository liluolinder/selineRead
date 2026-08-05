package CJson.test

import std.convert.*
import std.time.DateTime

import CJson.*
import CJson.jsonmacro.*

class CustInt64Serializer <: IJsonValueSerializable<Int64> {
    public CustInt64Serializer(let value: Int64) {
    }

    public static func fromJsonValue(json: JsonValue): Int64 {
        return json.asInt().getValue() * 100
    }

    public func toJsonValue(): JsonValue {
        return JsonInt(this.value/100)
    }
}

class CustDateTimeSerializer <: IJsonValueSerializable<DateTime> {
    public CustDateTimeSerializer(let value: DateTime) {

    }

    public static func fromJsonValue(json: JsonValue): DateTime {
        let time = DateTime.parse(json.asString().getValue().trimStart("\"").trimEnd("\""))
        return time.addYears(-1)
    }

    public func toJsonValue(): JsonValue {
        return  JsonString(this.value.addYears(1).toString())
    }
}

@JsonSerializable
public class CustTest {
    @JsonCust[CustInt64Serializer]
    var count: Int64 = 99

    @JsonCust[CustDateTimeSerializer]
    var time: DateTime = DateTime.now()
}

@Test
public class TestCUst {
    private let CUSTTEST_JSON = "{\"count\":88,\"time\":\"2023-12-25T00:00:00+01:00\"}"
    @TestCase
    func testCustFromJson(): Unit {
        let cust = CustTest.fromJson(CUSTTEST_JSON)
        @Assert(cust.count, 8800)
        @Assert(cust.time.year, 2022)
    }

    @TestCase
    func testCustToJson(): Unit {
        @Assert(CustTest.fromJson(CUSTTEST_JSON).toJson(), CUSTTEST_JSON)
    }
}