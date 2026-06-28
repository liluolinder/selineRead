package ignite

import std.io.InputStream
import stdx.net.http.{HttpContext, HttpHeaders, WebSocket}

/// Ignite-owned ingress wrapper for the current request carrier.
///
/// The current implementation is still stdx-backed, but `Ctx` no longer needs
/// to be constructed directly from `HttpContext`.
public interface CurrentRequestCarrier {
    func rawHttpContext(): HttpContext
    func upgradeWebSocketRaw(): WebSocket
    func openResponseTransportWriterRaw(): ResponseTransportWriter
    func requestMethod(): String
    func requestPath(): String
    func requestUrlString(): String
    func requestVersionString(): String
    func requestRemoteAddr(): String
    func requestQueryValue(key: String): ?String
    func requestFormValue(key: String): ?String
    func requestHeaderValue(key: String): ?String
    func requestHeaders(): HttpHeaders
    func requestBodyStream(): InputStream
    func requestBodySize(): ?Int64
    func setResponseStatus(code: UInt16): Unit
    func setResponseHeader(key: String, value: String): Unit
    func addResponseHeaders(headers: HttpHeaders): Unit
    func setResponseString(body: String): Unit
    func setResponseBytes(data: Array<UInt8>): Unit
    func attachResponseBodyStream(stream: InputStream): Unit
}

public class StdxHttpContextCurrentRequestCarrier <: CurrentRequestCarrier {
    let _httpCtx: HttpContext

    public init(httpCtx: HttpContext) {
        this._httpCtx = httpCtx
    }

    public override func rawHttpContext(): HttpContext {
        _httpCtx
    }

    public override func upgradeWebSocketRaw(): WebSocket {
        WebSocket.upgradeFromServer(_httpCtx)
    }

    public override func openResponseTransportWriterRaw(): ResponseTransportWriter {
        StdxResponseTransportWriter(_httpCtx)
    }

    public override func requestMethod(): String {
        _httpCtx.request.method
    }

    public override func requestPath(): String {
        _httpCtx.request.url.path
    }

    public override func requestUrlString(): String {
        _httpCtx.request.url.toString()
    }

    public override func requestVersionString(): String {
        _httpCtx.request.version.toString()
    }

    public override func requestRemoteAddr(): String {
        _httpCtx.request.remoteAddr
    }

    public override func requestQueryValue(key: String): ?String {
        _httpCtx.request.url.queryForm.get(key)
    }

    public override func requestFormValue(key: String): ?String {
        _httpCtx.request.form.get(key)
    }

    public override func requestHeaderValue(key: String): ?String {
        _httpCtx.request.headers.getFirst(key)
    }

    public override func requestHeaders(): HttpHeaders {
        _httpCtx.request.headers
    }

    public override func requestBodyStream(): InputStream {
        _httpCtx.request.body
    }

    public override func requestBodySize(): ?Int64 {
        _httpCtx.request.bodySize
    }

    public override func setResponseStatus(code: UInt16): Unit {
        _httpCtx.responseBuilder.status(code)
    }

    public override func setResponseHeader(key: String, value: String): Unit {
        _httpCtx.responseBuilder.header(key, value)
    }

    public override func addResponseHeaders(headers: HttpHeaders): Unit {
        _httpCtx.responseBuilder.addHeaders(headers)
    }

    public override func setResponseString(body: String): Unit {
        _httpCtx.responseBuilder.body(body)
    }

    public override func setResponseBytes(data: Array<UInt8>): Unit {
        _httpCtx.responseBuilder.body(data)
    }

    public override func attachResponseBodyStream(stream: InputStream): Unit {
        _httpCtx.responseBuilder.body(stream)
    }
}

type CurrentRequestCarrierResponseWriterFactory = () -> ResponseTransportWriter

let CURRENT_REQUEST_CARRIER_STREAM_COPY_BUFFER_SIZE: Int64 = 64 * 1024

class ResponseTransportWriterBackedCurrentRequestCarrier <: CurrentRequestCarrier {
    let _downstream: CurrentRequestCarrier
    let _responseWriterFactory: CurrentRequestCarrierResponseWriterFactory
    var _responseWriter: ?ResponseTransportWriter = None

    init(
        downstream: CurrentRequestCarrier,
        responseWriterFactory: CurrentRequestCarrierResponseWriterFactory
    ) {
        _downstream = downstream
        _responseWriterFactory = responseWriterFactory
    }

    func ensureResponseWriter(): ResponseTransportWriter {
        match (_responseWriter) {
            case Some(writer) => writer
            case None =>
                let writer = _responseWriterFactory()
                _responseWriter = Some(writer)
                writer
        }
    }

    public override func rawHttpContext(): HttpContext {
        _downstream.rawHttpContext()
    }

    public override func upgradeWebSocketRaw(): WebSocket {
        _downstream.upgradeWebSocketRaw()
    }

    public override func openResponseTransportWriterRaw(): ResponseTransportWriter {
        ensureResponseWriter()
    }

    public override func requestMethod(): String {
        _downstream.requestMethod()
    }

    public override func requestPath(): String {
        _downstream.requestPath()
    }

    public override func requestUrlString(): String {
        _downstream.requestUrlString()
    }

    public override func requestVersionString(): String {
        _downstream.requestVersionString()
    }

    public override func requestRemoteAddr(): String {
        _downstream.requestRemoteAddr()
    }

    public override func requestQueryValue(key: String): ?String {
        _downstream.requestQueryValue(key)
    }

    public override func requestFormValue(key: String): ?String {
        _downstream.requestFormValue(key)
    }

    public override func requestHeaderValue(key: String): ?String {
        _downstream.requestHeaderValue(key)
    }

    public override func requestHeaders(): HttpHeaders {
        _downstream.requestHeaders()
    }

    public override func requestBodyStream(): InputStream {
        _downstream.requestBodyStream()
    }

    public override func requestBodySize(): ?Int64 {
        _downstream.requestBodySize()
    }

    public override func setResponseStatus(code: UInt16): Unit {
        _downstream.setResponseStatus(code)
    }

    public override func setResponseHeader(key: String, value: String): Unit {
        _downstream.setResponseHeader(key, value)
    }

    public override func addResponseHeaders(headers: HttpHeaders): Unit {
        _downstream.addResponseHeaders(headers)
    }

    public override func setResponseString(body: String): Unit {
        let bytes = body.toArray()
        if (bytes.size == 0) {
            return
        }
        ensureResponseWriter().write(bytes)
    }

    public override func setResponseBytes(data: Array<UInt8>): Unit {
        if (data.size == 0) {
            return
        }
        ensureResponseWriter().write(cloneResponseTransportBytes(data))
    }

    public override func attachResponseBodyStream(stream: InputStream): Unit {
        let writer = ensureResponseWriter()
        let buffer = Array<Byte>(
            CURRENT_REQUEST_CARRIER_STREAM_COPY_BUFFER_SIZE,
            repeat: 0
        )
        try {
            while (true) {
                let readLen = stream.read(buffer)
                if (readLen <= 0) {
                    break
                }
                writer.write(
                    currentRequestCarrierByteWindowToUInt8(buffer, readLen)
                )
            }
        } finally {
            closeCurrentRequestCarrierStreamIfResource(stream)
        }
    }
}

func wrapCurrentRequestCarrier(httpCtx: HttpContext): CurrentRequestCarrier {
    StdxHttpContextCurrentRequestCarrier(httpCtx)
}

func wrapCurrentRequestCarrierResponseWriter(
    currentRequestCarrier: CurrentRequestCarrier,
    responseWriterFactory: CurrentRequestCarrierResponseWriterFactory
): CurrentRequestCarrier {
    ResponseTransportWriterBackedCurrentRequestCarrier(
        currentRequestCarrier,
        responseWriterFactory
    )
}

func currentRequestCarrierByteWindowToUInt8(
    input: Array<Byte>,
    size: Int64
): Array<UInt8> {
    let out = Array<UInt8>(size, repeat: 0)
    var i: Int64 = 0
    while (i < size) {
        out[i] = UInt8(input[i])
        i += 1
    }
    out
}

func closeCurrentRequestCarrierStreamIfResource(stream: InputStream): Unit {
    match (stream) {
        case closable: Resource => closable.close()
        case _ => ()
    }
}
