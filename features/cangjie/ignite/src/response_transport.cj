package ignite

import std.io.OutputStream
import stdx.net.http.{HttpContext, HttpResponseWriter}

/// Ignite-owned writer seam for response streaming surfaces.
///
/// The current backend is still stdx-backed, but callers no longer need to
/// construct `HttpResponseWriter` directly. That keeps the replacement point
/// narrow for future self-owned runtime work.
public interface ResponseTransportWriter {
    func write(data: Array<UInt8>): Unit
}

public type ResponseTransportWriteSink = (Array<UInt8>) -> Unit
type ResponseTransportWriteTransform = (Array<UInt8>) -> Array<Array<UInt8>>

class StdxResponseTransportWriter <: ResponseTransportWriter {
    let _writer: HttpResponseWriter

    public init(httpCtx: HttpContext) {
        _writer = HttpResponseWriter(httpCtx)
    }

    public override func write(data: Array<UInt8>): Unit {
        _writer.write(data)
    }
}

class TransformingResponseTransportWriter <: ResponseTransportWriter {
    let _downstream: ResponseTransportWriter
    let _transform: ResponseTransportWriteTransform

    init(
        downstream: ResponseTransportWriter,
        transform: ResponseTransportWriteTransform
    ) {
        _downstream = downstream
        _transform = transform
    }

    public override func write(data: Array<UInt8>): Unit {
        if (data.size == 0) {
            return
        }
        let transformed = _transform(cloneResponseTransportBytes(data))
        for (chunk in transformed) {
            if (chunk.size > 0) {
                _downstream.write(chunk)
            }
        }
    }
}

class SinkBackedResponseTransportWriter <: ResponseTransportWriter {
    let _sink: ResponseTransportWriteSink

    init(sink: ResponseTransportWriteSink) {
        _sink = sink
    }

    public override func write(data: Array<UInt8>): Unit {
        if (data.size == 0) {
            return
        }
        _sink(cloneResponseTransportBytes(data))
    }
}

func openResponseTransportWriter(currentRequestCarrier: CurrentRequestCarrier): ResponseTransportWriter {
    currentRequestCarrier.openResponseTransportWriterRaw()
}

/// Opens a transport writer that forwards each write into an arbitrary sink.
///
/// This keeps product-local sinks such as `TcpSocket.write(...)` behind the
/// same `ResponseTransportWriter` seam without re-exposing `HttpResponseWriter`.
public func openSinkBackedResponseTransportWriter(
    sink: ResponseTransportWriteSink
): ResponseTransportWriter {
    SinkBackedResponseTransportWriter(sink)
}

func wrapResponseTransportWriter(
    writer: ResponseTransportWriter,
    transform: ResponseTransportWriteTransform
): ResponseTransportWriter {
    TransformingResponseTransportWriter(writer, transform)
}

/// Presents a response transport writer as an `std.io.OutputStream`.
public class ResponseTransportOutputStream <: OutputStream {
    let _writer: ResponseTransportWriter

    public init(writer: ResponseTransportWriter) {
        _writer = writer
    }

    public override func write(data: Array<Byte>): Unit {
        let out = Array<UInt8>(data.size, repeat: 0)
        var i: Int64 = 0
        while (i < data.size) {
            out[i] = UInt8(data[i])
            i += 1
        }
        _writer.write(out)
    }

    public override func flush(): Unit {
        // The current stdx-backed transport emits per write;
        // there is no stronger flush contract here yet.
    }
}

func cloneResponseTransportBytes(input: Array<UInt8>): Array<UInt8> {
    let out = Array<UInt8>(input.size, repeat: 0)
    var i: Int64 = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}
