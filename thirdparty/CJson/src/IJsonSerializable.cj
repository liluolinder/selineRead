package CJson

internal import stdx.encoding.json.*

import std.time.DateTime
internal import std.collection.*

public interface IJsonSerializable<T> <: IJsonValueSerializable<T> {
    static func fromJson(json: String) : T
    func toJson() : String
}

public interface IJsonValueSerializable<T> {
    static func fromJsonValue(value: JsonValue) : T
    func toJsonValue() : JsonValue
}

extend String <: IJsonValueSerializable<String> {
    public static func fromJsonValue(value: JsonValue): String {
        match(value.kind) {
            case JsonString => value.asString().getValue()
            case _ => ""
        }
    }

    public func toJsonValue() : JsonValue {
        JsonString(this)
    }
}

extend Bool <: IJsonValueSerializable<Bool> {
    public static func fromJsonValue(value: JsonValue): Bool {
        match(value.kind) {
            case JsonBool => value.asBool().getValue()
            case _ => false
        }
    }

    public func toJsonValue() : JsonValue {
        JsonBool(this)
    }
}

extend Int64 <: IJsonValueSerializable<Int64> {

    public static func fromJsonValue(value: JsonValue): Int64 {
        match(value.kind) {
            case JsonInt => value.asInt().getValue()
            case _ => 0
        }
    }

    public func toJsonValue() : JsonValue {
        JsonInt(this)
    }

}

extend Int32 <: IJsonValueSerializable<Int32> {

    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): Int32 {
      match(value.kind) {
          case JsonInt => Int32(value.asInt().getValue())
          case _ => Int32(0)
      }
    }

    public func toJsonValue() : JsonValue {
        JsonInt(Int64(this))
    }
}

extend Int16 <: IJsonValueSerializable<Int16> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): Int16 {
        match(value.kind) {
            case JsonInt => Int16(value.asInt().getValue())
            case _ => Int16(0)
        }
    }

    public func toJsonValue() : JsonValue {
        JsonInt(Int64(this))
    }
}    

extend Int8 <: IJsonValueSerializable<Int8> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): Int8 {
        match(value.kind) {
            case JsonInt => Int8(value.asInt().getValue())
            case _ => Int8(0)
        }
    }

    public func toJsonValue() : JsonValue {
        JsonInt(Int64(this))
    }
}


extend Float64 <: IJsonValueSerializable<Float64> {
    public static func fromJsonValue(value: JsonValue): Float64 {
        match(value.kind) {
            case JsonFloat => value.asFloat().getValue()
            case _ => 0.0
        }
    }

    public func toJsonValue() : JsonValue {
        JsonFloat(this)
    }
}


extend Float32 <: IJsonValueSerializable<Float32> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): Float32 {
        Float32(value.asFloat().getValue())
    }

    public func toJsonValue() : JsonValue {
        JsonFloat(Float64(this))
    }
}

extend Float16 <: IJsonValueSerializable<Float16> {
    @OverflowWrapping
    public static func fromJsonValue(value: JsonValue): Float16 {
        Float16(value.asFloat().getValue())
    }

    public func toJsonValue() : JsonValue {
        JsonFloat(Float64(this))
    }
}


extend DateTime <: IJsonValueSerializable<DateTime> {
    public static func fromJsonValue(value: JsonValue): DateTime {
        match(value.kind) {
            case JsonString => DateTime.parse(value.asString().getValue())
            case _ => DateTime.now()
            }
    }

    public func toJsonValue() : JsonValue {
        JsonString(this.toString())
    }
}

extend<T> ArrayList<T> <: IJsonValueSerializable<ArrayList<T>> where T <: IJsonValueSerializable<T> {
    public static func fromJsonValue(value: JsonValue): ArrayList<T> {
        var res = ArrayList<T>()
        match(value.kind) {
            case JsonArray =>
                let jv = value.asArray()
                for(i in jv.getItems()) {
                    res.add(T.fromJsonValue(i))
                }
            case _ => ()
        }
        res
    }

    public func toJsonValue() : JsonValue {
        var jsonArray = JsonArray()
        for(item in this) {
            jsonArray.add(item.toJsonValue())
        }
        jsonArray
    }
}

extend<T> HashSet<T> <: IJsonValueSerializable<HashSet<T>> where T <: IJsonValueSerializable<T> {
    public static func fromJsonValue(value: JsonValue): HashSet<T> {
        var res = HashSet<T>()
        match(value.kind) {
            case JsonArray =>
                let jv = value.asArray()
                for(i in jv.getItems()) {
                    res.add(T.fromJsonValue(i))
                }
            case _ => ()
            }
        res
    }

    public func toJsonValue() : JsonValue {
        var jsonArray = JsonArray()
        for(item in this) {
            jsonArray.add(item.toJsonValue())
        }
        jsonArray
    }
}

extend<K, V> HashMap<K, V> <: IJsonValueSerializable<HashMap<K, V>> where K <: ToString & Hashable & Equatable<K> & IJsonValueSerializable<K>, V <: IJsonValueSerializable<V> {
    public static func fromJsonValue(value: JsonValue): HashMap<K, V> {
        var res = HashMap<K, V>()
        match(value.kind) {
            case JsonObject =>
                let jv = value.asObject()
                for ((x, y) in jv.getFields()) {
                    res.add(K.fromJsonValue(JsonString(x)), V.fromJsonValue(y))
                }
            case _ => ()
        }
        res
    }

    public func toJsonValue() : JsonValue {
        var jsonObj = JsonObject()
        for((k, v) in this) {
            jsonObj.put(k.toString(), v.toJsonValue())
        }
        jsonObj
    }
}
