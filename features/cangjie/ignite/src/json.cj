package ignite

import std.io.ByteBuffer
import seajson.{
    JsonWriter as SeaJsonNativeWriter,
    JsonEncodable as SeaJsonEncodable,
    defaultJsonEncoder as seaJsonDefaultJsonEncoder
}
import stdx.encoding.json.stream.{
    JsonWriter as StdxJsonWriter,
    JsonReader as StdxJsonReader,
    JsonSerializable as StdxJsonSerializable,
    JsonDeserializable as StdxJsonDeserializable
}

public type JsonWriter = StdxJsonWriter
public type JsonEncodable = SeaJsonEncodable
public type JsonSerializable = StdxJsonSerializable
public type JsonDeserializable<T> = StdxJsonDeserializable<T>
public type JsonReader = StdxJsonReader
public type JsonEncoder = (JsonEncodable) -> String

/// Ignite-owned writer-facing JSON contract.
///
/// GitCode SeaJson truth currently lags the newer `JsonWriterEncodable`
/// interface/export surface, so Ignite keeps this narrow writer-facing seam
/// locally while still consuming SeaJson's native writer type directly.
public interface JsonWriterEncodable {
    func writeJson(writer: SeaJsonNativeWriter): Unit
}

func defaultJsonEncoder(obj: JsonEncodable): String {
    seaJsonDefaultJsonEncoder(obj)
}

public func serializeJson<T>(obj: T): String where T <: JsonSerializable {
    serializeJsonThroughSeaJsonBridge<T>(obj)
}

public func deserializeJson<T>(jsonStr: String): T where T <: JsonDeserializable<T> {
    let buf = ByteBuffer(jsonStr.toArray())
    let reader = StdxJsonReader(buf)
    T.fromJson(reader)
}
