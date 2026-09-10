package CJson.test

import std.time.DateTime

import CJson.*
import CJson.jsonmacro.*

@JsonSerializable
class ClassWithTime {
    public var intVar: Int64 = 10
    public var time: DateTime = DateTime.now()
}

@Test
class TestTime {
    private let JSON_WITH_TIME = "{\"intVar\":20,\"time\":\"2025-12-31T12:12:12+01:00\"}"

    @TestCase
    func testTime(): Unit {
        @Assert(ClassWithTime.fromJson(JSON_WITH_TIME).toJson(), JSON_WITH_TIME)
    }
}