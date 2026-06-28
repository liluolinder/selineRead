package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.HashMap
import std.io.InputStream
import stdx.net.http.{HttpContext, HttpHeaders, WebSocket}

@Test
public class RequestBodyBufferCeilingContractTestSuite {
    @TestCase
    public func testBodyBytesThrowsBufferedOverflowExceptionWithLimitMetadata(): Unit {
        let carrier = RequestBodyOverflowTestCarrier("POST", "/overflow", "123456789")
        let ctx = Ctx(carrier, App(config: Config(bodyLimit: 8)))

        try {
            let _ = ctx.bodyBytes()
            @Fail("bodyBytes should refuse bodies larger than config.bodyLimit")
        } catch (e: BufferedRequestBodyTooLargeException) {
            @Assert(e.limitBytes, Int64(8))
            @Assert(e.attemptedBytes, Int64(9))
            @Assert(e.message, "request body buffered 9 bytes which exceeds limit 8")
        }
    }

    @TestCase
    public func testHandleRequestMapsBufferedBodyOverflowTo413ByDefault(): Unit {
        let app = App(config: Config(bodyLimit: 8))
        app.post("/overflow", { ctx =>
            let body = ctx.bodyBytes()
            let _ = ctx.sendString(body.size.toString())
        })

        let carrier = RequestBodyOverflowTestCarrier("POST", "/overflow", "123456789")
        app.handleRequest(carrier)

        @Assert(carrier.responseStatus, UInt16(413))
        @Assert(carrier.responseBody, "Payload Too Large")
        @Assert(carrier.header("content-type") ?? "", "text/plain; charset=utf-8")
    }

    @TestCase
    public func testRecoverMiddlewareKeepsBufferedBodyOverflowOn413(): Unit {
        let app = App(config: Config(bodyLimit: 8))
        app.use(recoverMiddleware())
        app.post("/overflow", { ctx =>
            let _ = ctx.sendString(ctx.bodyString())
        })

        let carrier = RequestBodyOverflowTestCarrier("POST", "/overflow", "123456789")
        app.handleRequest(carrier)

        @Assert(carrier.responseStatus, UInt16(413))
        @Assert(carrier.responseBody, "Payload Too Large")
        @Assert(carrier.header("content-type") ?? "", "text/plain; charset=utf-8")
    }
}

class RequestBodyOverflowTestCarrier <: CurrentRequestCarrier {
    let methodText: String
    let pathText: String
    let requestBytes: Array<Byte>
    let bodyStream: RequestBodyOverflowBytesInputStream
    let responseHeaders = HashMap<String, String>()
    public var responseStatus: UInt16 = 200
    public var responseBody: String = ""

    init(methodText: String, pathText: String, bodyText: String) {
        this.methodText = methodText
        this.pathText = pathText
        this.requestBytes = toRequestBodyOverflowTestByteArray(bodyText.toArray())
        this.bodyStream = RequestBodyOverflowBytesInputStream(this.requestBytes)
    }

    public func header(name: String): ?String {
        responseHeaders.get(name.trimAscii().toAsciiLower())
    }

    public override func rawHttpContext(): HttpContext {
        throw Exception("raw HttpContext should not be required for request body overflow tests")
    }

    public override func upgradeWebSocketRaw(): WebSocket {
        throw Exception("websocket upgrade should not run in request body overflow tests")
    }

    public override func openResponseTransportWriterRaw(): ResponseTransportWriter {
        throw Exception("response transport writer should not open in request body overflow tests")
    }

    public override func requestMethod(): String {
        methodText
    }

    public override func requestPath(): String {
        pathText
    }

    public override func requestUrlString(): String {
        pathText
    }

    public override func requestVersionString(): String {
        "HTTP/1.1"
    }

    public override func requestRemoteAddr(): String {
        "127.0.0.1"
    }

    public override func requestQueryValue(key: String): ?String {
        let _ = key
        None
    }

    public override func requestFormValue(key: String): ?String {
        let _ = key
        None
    }

    public override func requestHeaderValue(key: String): ?String {
        if (key.trimAscii().toAsciiLower() == "content-length") {
            return Some(requestBytes.size.toString())
        }
        None
    }

    public override func requestHeaders(): HttpHeaders {
        let headers = HttpHeaders()
        headers.add("content-length", requestBytes.size.toString())
        headers
    }

    public override func requestBodyStream(): InputStream {
        bodyStream
    }

    public override func requestBodySize(): ?Int64 {
        Some(requestBytes.size)
    }

    public override func setResponseStatus(code: UInt16): Unit {
        responseStatus = code
    }

    public override func setResponseHeader(key: String, value: String): Unit {
        responseHeaders.add(key.trimAscii().toAsciiLower(), value)
    }

    public override func addResponseHeaders(headers: HttpHeaders): Unit {
        let _ = headers
    }

    public override func setResponseString(body: String): Unit {
        responseBody = body
    }

    public override func setResponseBytes(data: Array<UInt8>): Unit {
        responseBody = String.fromUtf8(data)
    }

    public override func attachResponseBodyStream(stream: InputStream): Unit {
        let _ = stream
    }
}

class RequestBodyOverflowBytesInputStream <: InputStream {
    let bytes: Array<Byte>
    var cursor: Int64 = 0

    init(bytes: Array<Byte>) {
        this.bytes = bytes
    }

    public override func read(outBuf: Array<Byte>): Int64 {
        if (cursor >= bytes.size || outBuf.size == 0) {
            return 0
        }
        let remaining = bytes.size - cursor
        let readLen = if (remaining < outBuf.size) { remaining } else { outBuf.size }
        var i: Int64 = 0
        while (i < readLen) {
            outBuf[i] = bytes[cursor + i]
            i += 1
        }
        cursor += readLen
        readLen
    }

    public func close(): Unit {}
}

func toRequestBodyOverflowTestByteArray(input: Array<UInt8>): Array<Byte> {
    let out = Array<Byte>(input.size, repeat: 0)
    var i: Int64 = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}
