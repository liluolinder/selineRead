package CJson.example.demo

//1. the following package must be imported, when Custom serializer is needed
import CJson.jsonmacro.*
import CJson.*

@JsonSerializable
public class ExampleTwo {
    public var name:String = "New Year"
    public var time:CustomTime = CustomTime(DateTime.now())
}

public class CustomTime {
    public CustomTime(let value: DateTime){
    }
}

//2. extend and implement CustJsonSerializable<T> for custom serializer of type T
extend CustomTime <: IJsonValueSerializable<CustomTime> {
    public static func fromJsonValue(json: JsonValue): CustomTime {
        let custString = json.asObject().get("value").getOrThrow().asString().getValue()
        let time = DateTime.parse(custString.trimStart("CUST_"))
        return CustomTime(time)
    }

    public func toJsonValue(): JsonValue {
        var map: HashMap < String , JsonValue >= HashMap()
        let s = "CUST_"
        map.add("value", JsonString(String.join(s, this.value.toString()))) 
        return JsonObject(map)
    }
}