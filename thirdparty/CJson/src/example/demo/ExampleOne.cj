package CJson.example.demo

internal import std.time.DateTime

//1. the following three packages must be imported by decoraetd class/struct, or by it's belonging package
internal import std.collection.HashMap
internal import stdx.encoding.json.*
import CJson.jsonmacro.*
import CJson.*

// custom serializer @JsonCust[CustDateTimeSerializer]
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

//2. use @JsonSerializable to decorate target class
@JsonSerializable
public class ExampleOne {
    //3. class properties must be declared with explicit type
    var name: String = "Christmas"
    
    @JsonCust[CustDateTimeSerializer]
    var time: DateTime = DateTime.now()
}

@JsonSerializable
public class ExampleOneOptional {
    var One: Option<ExampleOne> = ExampleOne()
    var Two: Option<String> = None
    var Three: Option<Int64> = None
    var Four: Option<DateTime> = None

}

@JsonSerializable
public class ExampleOne_Init {
    var name: String
    var time: DateTime

    //4. the target class must have a parameter-less contructor
    //try comment out this init method to see compile errors
    //ExampleOne class will work since there it has an equavalent "hidden" parameter-less contructor
    public init() {
        this.name = "Christmas_init"
        this.time = DateTime.parse("2022-12-25T00:00:00+01:00")
    }

    public init(name: String) {
        this.name = name
        this.time = DateTime.parse("2022-12-25T00:00:00+01:00")
    }
}

@JsonSerializable
class ClassWithOption {   
    public var optionalStringWithoutValue: Option<String> = None
    public var optionalStringWithValue: Option<String> = "StringValue"

    public var optionalIntWithoutValue: Option<Int64> = None
    public var optionalIntWithValue: Option<Int64> = 199
}

//struct is also supported
@JsonSerializable
public struct ExampleOneStruct {
    var name: String = "Labor Day"
    var time: DateTime

    public init () {
        this.time = DateTime.now()
    }
}