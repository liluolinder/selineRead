package ignite.tests

import ignite.*
import std.collection.HashMap
import std.io.InputStream
import std.net.{TcpSocket, IPSocketAddress}
import std.time.DateTime

@Test
public class StreamResponseTestSuite {
    @TestCase
    public func testSendStreamKnownLengthPreservesBodyAndContentLength(): Unit {
        let payload = buildLargeAsciiPayload()
        let app = App(config: Config())
        app.get("/stream-known", { ctx =>
            let stream = SendStreamBytesInput(toSendStreamByteArray(payload.toArray()))
            _ = ctx.sendStream(
                stream,
                contentType: "text/plain; charset=utf-8",
                contentLength: Some(payload.size)
            )
        })

        let resp = app.handleForTest("GET", "/stream-known")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("content-type") ?? "", "text/plain; charset=utf-8")
        @Assert(resp.header("content-length") ?? "", payload.size.toString())
        @Assert(resp.header("transfer-encoding") ?? "", "")
        @Assert(resp.body, payload)
    }

    @TestCase
    public func testSendStreamKnownLengthOverRealHttpKeepsContentLengthWithoutTransferEncoding(): Unit {
        let payload = buildLargeAsciiPayload()
        let port = chooseStreamTestPort(1833)
        let app = App(config: Config())
        app.get("/stream-known-wire", { ctx =>
            let stream = SendStreamBytesInput(toSendStreamByteArray(payload.toArray()))
            _ = ctx.sendStream(
                stream,
                contentType: "text/plain; charset=utf-8",
                contentLength: Some(payload.size)
            )
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawStreamHttpWithRetry(port, "GET", "/stream-known-wire", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "text/plain; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", payload.size.toString())
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.body, payload)
        } finally {
            shutdownStreamTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testSendStreamUnknownLengthFallsBackToChunkedForHttp11(): Unit {
        let payload = buildLargeAsciiPayload()
        let port = chooseStreamTestPort(1841)
        let app = App(config: Config())
        app.get("/stream-unknown", { ctx =>
            let stream = SendStreamBytesInput(toSendStreamByteArray(payload.toArray()))
            _ = ctx.sendStream(stream, contentType: "text/plain; charset=utf-8")
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawStreamHttpWithRetry(port, "GET", "/stream-unknown", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "text/plain; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", "")
            @Assert(resp.header("transfer-encoding") ?? "", "chunked")
            @Assert(decodeStreamChunkedBody(resp.body), payload)
        } finally {
            shutdownStreamTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testTransportWriterChunkedOverRealHttpPreservesChunkedWireBody(): Unit {
        let payload = "ignite-transport-known-wire"
        let port = chooseStreamTestPort(1847)
        let app = App(config: Config())
        app.get("/transport-known-wire", { ctx =>
            let _ = ctx.setHeader("content-type", "text/plain; charset=utf-8")
            let _ = ctx.setHeader("transfer-encoding", "chunked")
            let writer = ctx.transportWriter()
            writeTransportChunks(writer, payload.toArray(), 4096)
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawStreamHttpWithRetry(port, "GET", "/transport-known-wire", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "text/plain; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", "")
            @Assert(resp.header("transfer-encoding") ?? "", "chunked")
            @Assert(decodeStreamChunkedBody(resp.body), payload)
        } finally {
            shutdownStreamTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testHeadSendStreamKeepsHeadersWithoutSendingBody(): Unit {
        let tracked = SendStreamTrackingInput(toSendStreamByteArray("ignite-head-stream".toArray()))
        let app = App(config: Config())
        app.head("/stream-head", { ctx =>
            _ = ctx.sendStream(
                tracked,
                contentType: "application/octet-stream",
                contentLength: Some(Int64(18))
            )
        })

        let resp = app.handleForTest("HEAD", "/stream-head")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("content-type") ?? "", "application/octet-stream")
        @Assert(resp.header("content-length") ?? "", "18")
        @Assert(resp.header("transfer-encoding") ?? "", "")
        @Assert(resp.body, "")
        @Assert(tracked.closed, true)
    }

    @TestCase
    public func testHeadSendStreamOverRealHttpKeepsHeadersWithoutBodyAndClosesStream(): Unit {
        let tracked = SendStreamTrackingInput(toSendStreamByteArray("ignite-head-stream".toArray()))
        let port = chooseStreamTestPort(1851)
        let app = App(config: Config())
        app.head("/stream-head-wire", { ctx =>
            _ = ctx.sendStream(
                tracked,
                contentType: "application/octet-stream",
                contentLength: Some(Int64(18))
            )
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawStreamHttpWithRetry(port, "HEAD", "/stream-head-wire", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/octet-stream")
            @Assert(resp.header("content-length") ?? "", "18")
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.body, "")
            @Assert(tracked.closed, true)
        } finally {
            shutdownStreamTestApp(app, serverFuture)
        }
    }

    func buildLargeAsciiPayload(): String {
        let line = "ignite-send-stream-regression-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ\n"
        var out = ""
        var i: Int64 = 0
        while (i < 2048) {
            out += line
            i += 1
        }
        out
    }
}

class SendStreamBytesInput <: InputStream {
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
        for (i in 0..readLen) {
            outBuf[i] = bytes[cursor + i]
        }
        cursor += readLen
        readLen
    }

    public func close(): Unit {}
}

class SendStreamTrackingInput <: InputStream & Resource {
    let bytes: Array<Byte>
    var cursor: Int64 = 0
    public var closed: Bool = false

    init(bytes: Array<Byte>) {
        this.bytes = bytes
    }

    public override func read(outBuf: Array<Byte>): Int64 {
        if (cursor >= bytes.size || outBuf.size == 0) {
            return 0
        }
        let remaining = bytes.size - cursor
        let readLen = if (remaining < outBuf.size) { remaining } else { outBuf.size }
        for (i in 0..readLen) {
            outBuf[i] = bytes[cursor + i]
        }
        cursor += readLen
        readLen
    }

    public func close(): Unit {
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }
}

func toSendStreamByteArray(input: Array<UInt8>): Array<Byte> {
    let out = Array<Byte>(input.size, repeat: 0)
    var i = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}

func writeTransportChunks(writer: ResponseTransportWriter, data: Array<UInt8>, chunkSize: Int64): Unit {
    var cursor: Int64 = 0
    while (cursor < data.size) {
        let end = if (cursor + chunkSize < data.size) { cursor + chunkSize } else { data.size }
        writer.write(data[cursor..end])
        cursor = end
    }
}

class StreamRawHttpResponse {
    public let status: UInt16
    public let headers: HashMap<String, String>
    public let body: String

    public init(status: UInt16, headers: HashMap<String, String>, body: String) {
        this.status = status
        this.headers = headers
        this.body = body
    }

    public func header(name: String): ?String {
        headers.get(name.trimAscii().toAsciiLower())
    }
}

func sendRawStreamHttpWithRetry(
    port: UInt16,
    method: String,
    target: String,
    headers: Array<(String, String)>
): StreamRawHttpResponse {
    var attempt: Int64 = 0
    while (attempt < 20) {
        try {
            return sendRawStreamHttp(port, method, target, headers)
        } catch (_: Exception) {
            if (attempt == 19) {
                throw Exception("failed to connect raw stream test server: ${port} ${target}")
            }
            sleep(Duration.millisecond * 50)
            attempt += 1
        }
    }
    throw Exception("failed to connect raw stream test server: ${port} ${target}")
}

func sendRawStreamHttp(
    port: UInt16,
    method: String,
    target: String,
    headers: Array<(String, String)>
): StreamRawHttpResponse {
    let socket = TcpSocket(IPSocketAddress.parse("127.0.0.1:${port}"))
    socket.connect()
    try {
        var request = "${method} ${target} HTTP/1.1\r\n"
        request += "host: 127.0.0.1:${port}\r\n"
        for ((key, value) in headers) {
            request += "${key}: ${value}\r\n"
        }
        request += "connection: close\r\n\r\n"
        socket.write(request.toArray())

        let buf = Array<UInt8>(4096, repeat: 0)
        var raw = ""
        while (true) {
            let n = socket.read(buf)
            if (n <= 0) {
                break
            }
            raw += String.fromUtf8(buf[..n])
        }
        parseStreamRawHttpResponse(raw)
    } finally {
        socket.close()
    }
}

func parseStreamRawHttpResponse(raw: String): StreamRawHttpResponse {
    let splitIdx = indexOfStreamText(raw, "\r\n\r\n")
    let headerText = if (splitIdx >= 0) { raw[..splitIdx] } else { raw }
    let body = if (splitIdx >= 0) { raw[splitIdx + 4..raw.size] } else { "" }
    let lines = headerText.split("\r\n")
    if (lines.size == 0) {
        throw Exception("raw stream response missing status line")
    }

    let status = parseStreamStatusCode(lines[0])
    let headerMap = HashMap<String, String>()
    var i: Int64 = 1
    while (i < lines.size) {
        let line = lines[i]
        let colonIdx = indexOfStreamRune(line, r':')
        if (colonIdx > 0) {
            let key = line[..colonIdx].trimAscii().toAsciiLower()
            let value = line[colonIdx + 1..line.size].trimAscii()
            headerMap.add(key, value)
        }
        i += 1
    }
    StreamRawHttpResponse(status, headerMap, body)
}

func parseStreamStatusCode(statusLine: String): UInt16 {
    let parts = statusLine.split(" ")
    if (parts.size < 2) {
        throw Exception("invalid status line: ${statusLine}")
    }
    let digits = parts[1].trimAscii()
    if (digits.size == 0) {
        throw Exception("invalid status code: ${statusLine}")
    }
    var value: Int64 = 0
    for (ch in digits.toRuneArray()) {
        if (ch < r'0' || ch > r'9') {
            throw Exception("invalid status code: ${statusLine}")
        }
        value = value * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
    }
    UInt16(value)
}

func decodeStreamChunkedBody(raw: String): String {
    var idx: Int64 = 0
    var out = ""
    while (idx < raw.size) {
        let lineEnd = indexOfStreamText(raw[idx..raw.size], "\r\n")
        if (lineEnd < 0) {
            throw Exception("invalid chunked response: missing chunk header terminator")
        }
        let sizeText = raw[idx..idx + lineEnd].trimAscii()
        let chunkSize = parseHexInt64(sizeText)
        idx += lineEnd + 2
        if (chunkSize == 0) {
            break
        }
        out += raw[idx..idx + chunkSize]
        idx += chunkSize + 2
    }
    out
}

func parseHexInt64(text: String): Int64 {
    let trimmed = text.trimAscii().toAsciiLower()
    if (trimmed.size == 0) {
        throw Exception("invalid hex integer")
    }
    var value: Int64 = 0
    for (ch in trimmed.toRuneArray()) {
        let digit = if (ch >= r'0' && ch <= r'9') {
            Int64(UInt32(ch) - UInt32(r'0'))
        } else if (ch >= r'a' && ch <= r'f') {
            Int64(UInt32(ch) - UInt32(r'a')) + 10
        } else {
            throw Exception("invalid hex integer")
        }
        value = value * 16 + digit
    }
    value
}

func indexOfStreamText(text: String, target: String): Int64 {
    let a = text.toRuneArray()
    let b = target.toRuneArray()
    if (b.size == 0) {
        return 0
    }
    if (a.size < b.size) {
        return -1
    }
    var i: Int64 = 0
    while (i <= a.size - b.size) {
        var ok = true
        var j: Int64 = 0
        while (j < b.size) {
            if (a[i + j] != b[j]) {
                ok = false
                break
            }
            j += 1
        }
        if (ok) {
            return i
        }
        i += 1
    }
    -1
}

func indexOfStreamRune(text: String, target: Rune): Int64 {
    let runes = text.toRuneArray()
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == target) {
            return i
        }
        i += 1
    }
    -1
}

func chooseStreamTestPort(offset: Int64): UInt16 {
    let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let raw = 44000 + ((nowMs + offset) % 8000)
    UInt16(raw)
}

func shutdownStreamTestApp(app: App, future: Future<Unit>): Unit {
    app.shutdown()
    try {
        let _ = future.get(Duration.second * 1)
    } catch (_: Exception) {
        future.cancel()
    }
}
