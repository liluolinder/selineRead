package ignite

import std.io.{ByteBuffer, OutputStream}
import seajson.JsonWriter as SeaJsonNativeWriter
import stdx.encoding.json.stream.JsonWriter as StdxJsonWriter

/// Ignite-owned JSON backend bridge.
///
/// The current first cut is still stdx-backed, but all core writer creation
/// now goes through this one seam so future SeaJson/Cangku backend work can be
/// plugged in without re-touching every JSON response path in Ignite Core.
func writeJsonCallbackThroughSeaJsonBridge(
    out: OutputStream,
    writerFn: (JsonWriter) -> Unit
): Unit {
    let writer = StdxJsonWriter(out)
    writerFn(writer)
    writer.flush()
}

func writeJsonSerializableThroughSeaJsonBridge<T>(
    writer: JsonWriter,
    obj: T
): Unit where T <: JsonSerializable {
    obj.toJson(writer)
}

func writeJsonWriterEncodableThroughSeaJsonBridge(
    out: OutputStream,
    obj: JsonWriterEncodable
): Unit {
    // Keep the hosted Gitcode SeaJson baseline consumable even before its
    // public writer surface lands the OutputStream-backed constructor.
    // This preserves the Ignite-side contract while honestly buffering inside
    // the bridge until the sibling hosted truth catches up.
    let writer = SeaJsonNativeWriter()
    obj.writeJson(writer)
    let json = writer.close()
    out.write(json.toArray())
    out.flush()
}

func serializeJsonThroughSeaJsonBridge<T>(obj: T): String where T <: JsonSerializable {
    let buf = ByteBuffer()
    let writer = StdxJsonWriter(buf)
    obj.toJson(writer)
    writer.flush()
    String.fromUtf8(buf.bytes())
}
