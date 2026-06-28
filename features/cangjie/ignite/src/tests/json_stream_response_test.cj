package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.HashMap
import std.net.{TcpSocket, IPSocketAddress}
import std.time.DateTime

/// Focused wire-proof suite for `ctx.jsonWrite(...)`.
///
/// Proves three contracts over real HTTP:
/// 1. `GET` without `content-length` (unknown-length, chunked for H1)
/// 2. `HEAD` (headers sent, no body)
/// 3. current `responseBody`-based compression middleware stays unpromised
///
/// These tests follow the same real-HTTP pattern as `StreamResponseTestSuite`.
/// `handleForTest` is intentionally not used because `HttpResponseWriter`
/// requires a live HTTP exchange.
@Test
public class JsonStreamResponseTestSuite {
    @TestCase
    public func testJsonWriteUnknownLengthOverRealHttpFallsBackToChunked(): Unit {
        let port = chooseJsonStreamTestPort(1913)
        let app = App(config: Config())
        app.get("/json-write-unknown", { ctx =>
            _ = ctx.jsonWrite({ jw =>
                jw.startObject()
                jw.writeName("msg")
                jw.writeValue("hello chunked world")
                jw.endObject()
            })
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonStreamHttp(port, "GET", "/json-write-unknown", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", "")
            @Assert(resp.header("transfer-encoding") ?? "", "chunked")
            let body = decodeJsonStreamChunkedBody(resp.body)
            @Assert(body, "{\"msg\":\"hello chunked world\"}")
        } finally {
            shutdownJsonStreamTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testJsonWriteHeadOverRealHttpKeepsHeadersWithoutBody(): Unit {
        let port = chooseJsonStreamTestPort(1915)
        let app = App(config: Config())
        app.head("/json-write-head", { ctx =>
            _ = ctx.jsonWrite({ jw =>
                jw.startObject()
                jw.writeName("a")
                jw.writeValue(1)
                jw.endObject()
            })
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonStreamHttp(port, "HEAD", "/json-write-head", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.header("content-length") ?? "", "0")
            @Assert(resp.body, "")
        } finally {
            shutdownJsonStreamTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testJsonWriteSkipsCompressionNegotiationBecauseResponseBodyIsUnpromised(): Unit {
        let port = chooseJsonStreamTestPort(1917)
        let app = App(config: Config())
        app.use(compressMiddleware(config: CompressConfig(minBytes: 0)))
        app.get("/json-write-compress", { ctx =>
            _ = ctx.jsonWrite({ jw =>
                jw.startObject()
                jw.writeName("msg")
                jw.writeValue("no-buffered-body")
                jw.endObject()
            })
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonStreamHttp(
                port,
                "GET",
                "/json-write-compress",
                [("accept-encoding", "gzip, deflate")]
            )
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-encoding") ?? "", "")
            let body = decodeJsonStreamChunkedBody(resp.body)
            @Assert(body, "{\"msg\":\"no-buffered-body\"}")
        } finally {
            shutdownJsonStreamTestApp(app, serverFuture)
        }
    }
}

// ── Test helpers ──

class JsonStreamRawHttpResponse {
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

func sendRawJsonStreamHttp(
    port: UInt16,
    method: String,
    target: String,
    headers: Array<(String, String)>
): JsonStreamRawHttpResponse {
    var attempt: Int64 = 0
    while (attempt < 20) {
        try {
            return doSendRawJsonStreamHttp(port, method, target, headers)
        } catch (_: Exception) {
            if (attempt == 19) {
                throw Exception("failed to connect json stream test server: ${port} ${target}")
            }
            sleep(Duration.millisecond * 50)
            attempt += 1
        }
    }
    throw Exception("failed to connect json stream test server: ${port} ${target}")
}

func doSendRawJsonStreamHttp(
    port: UInt16,
    method: String,
    target: String,
    headers: Array<(String, String)>
): JsonStreamRawHttpResponse {
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
        parseJsonStreamRawHttpResponse(raw)
    } finally {
        socket.close()
    }
}

func parseJsonStreamRawHttpResponse(raw: String): JsonStreamRawHttpResponse {
    let splitIdx = indexOfJsonStreamText(raw, "\r\n\r\n")
    let headerText = if (splitIdx >= 0) { raw[..splitIdx] } else { raw }
    let body = if (splitIdx >= 0) { raw[splitIdx + 4..raw.size] } else { "" }
    let lines = headerText.split("\r\n")
    if (lines.size == 0) {
        throw Exception("raw response missing status line")
    }

    let status = parseJsonStreamStatusCode(lines[0])
    let headerMap = HashMap<String, String>()
    var i: Int64 = 1
    while (i < lines.size) {
        let line = lines[i]
        let colonIdx = indexOfJsonStreamRune(line, r':')
        if (colonIdx > 0) {
            let key = line[..colonIdx].trimAscii().toAsciiLower()
            let value = line[colonIdx + 1..line.size].trimAscii()
            headerMap.add(key, value)
        }
        i += 1
    }
    JsonStreamRawHttpResponse(status, headerMap, body)
}

func parseJsonStreamStatusCode(statusLine: String): UInt16 {
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

func decodeJsonStreamChunkedBody(raw: String): String {
    var idx: Int64 = 0
    var out = ""
    while (idx < raw.size) {
        let lineEnd = indexOfJsonStreamText(raw[idx..raw.size], "\r\n")
        if (lineEnd < 0) {
            throw Exception("invalid chunked response: missing chunk header terminator")
        }
        let sizeText = raw[idx..idx + lineEnd].trimAscii()
        let chunkSize = parseJsonStreamHexInt64(sizeText)
        idx += lineEnd + 2
        if (chunkSize == 0) {
            break
        }
        out += raw[idx..idx + chunkSize]
        idx += chunkSize + 2
    }
    out
}

func parseJsonStreamHexInt64(text: String): Int64 {
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

func indexOfJsonStreamText(text: String, target: String): Int64 {
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

func indexOfJsonStreamRune(text: String, target: Rune): Int64 {
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

func chooseJsonStreamTestPort(offset: Int64): UInt16 {
    let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let raw = 45000 + ((nowMs + offset) % 8000)
    UInt16(raw)
}

func shutdownJsonStreamTestApp(app: App, future: Future<Unit>): Unit {
    app.shutdown()
    try {
        let _ = future.get(Duration.second * 1)
    } catch (_: Exception) {
        future.cancel()
    }
}
