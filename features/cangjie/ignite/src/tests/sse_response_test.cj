package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.HashMap
import std.net.{TcpSocket, IPSocketAddress}
import std.time.DateTime

@Test
public class SseResponseTestSuite {
    @TestCase
    public func testSseWireResponseIncludesOperationalHeadersAndHeartbeat(): Unit {
        let port = chooseSsePort(1861)
        let app = App(config: Config())
        app.get("/events", { ctx =>
            let sse = ctx.sse()
            sse.sendRetry(3000)
            sse.sendHeartbeat(comment: "ready")
            sse.sendEvent("line-1\nline-2", event: "tick", id: "evt-1")
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawSseHttpWithRetry(port, "GET", "/events", [])
            let body = decodeIfChunked(resp)
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "text/event-stream")
            @Assert(resp.header("cache-control") ?? "", "no-cache")
            @Assert(headerHasSseToken(resp.header("connection") ?? "", "keep-alive"), true)
            @Assert(resp.header("transfer-encoding") ?? "", "chunked")
            @Assert(resp.header("x-accel-buffering") ?? "", "no")
            @Assert(containsSseText(body, "retry: 3000\n\n"), true)
            @Assert(containsSseText(body, ": ready\n\n"), true)
            @Assert(containsSseText(body, "id: evt-1\n"), true)
            @Assert(containsSseText(body, "event: tick\n"), true)
            @Assert(containsSseText(body, "data: line-1\n"), true)
            @Assert(containsSseText(body, "data: line-2\n\n"), true)
        } finally {
            shutdownSseApp(app, serverFuture)
        }
    }

    @TestCase
    public func testSseResponseSkipsCompressionNegotiation(): Unit {
        let port = chooseSsePort(1871)
        let app = App(config: Config())
        app.use(compressMiddleware(config: CompressConfig(minBytes: 0)))
        app.get("/events", { ctx =>
            let sse = ctx.sse()
            sse.sendEvent("payload", event: "tick")
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawSseHttpWithRetry(
                port,
                "GET",
                "/events",
                [("accept-encoding", "gzip, deflate")]
            )
            let body = decodeIfChunked(resp)
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-encoding") ?? "", "")
            @Assert(containsSseText(body, "event: tick\n"), true)
            @Assert(containsSseText(body, "data: payload\n\n"), true)
        } finally {
            shutdownSseApp(app, serverFuture)
        }
    }
}

class SseRawHttpResponse {
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

func sendRawSseHttpWithRetry(
    port: UInt16,
    method: String,
    target: String,
    headers: Array<(String, String)>
): SseRawHttpResponse {
    var attempt: Int64 = 0
    while (attempt < 20) {
        try {
            return sendRawSseHttp(port, method, target, headers)
        } catch (_: Exception) {
            if (attempt == 19) {
                throw Exception("failed to connect raw SSE test server: ${port} ${target}")
            }
            sleep(Duration.millisecond * 50)
            attempt += 1
        }
    }
    throw Exception("failed to connect raw SSE test server: ${port} ${target}")
}

func sendRawSseHttp(
    port: UInt16,
    method: String,
    target: String,
    headers: Array<(String, String)>
): SseRawHttpResponse {
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
        parseRawSseHttpResponse(raw)
    } finally {
        socket.close()
    }
}

func parseRawSseHttpResponse(raw: String): SseRawHttpResponse {
    let splitIdx = indexOfSseText(raw, "\r\n\r\n")
    let headerText = if (splitIdx >= 0) { raw[..splitIdx] } else { raw }
    let body = if (splitIdx >= 0) { raw[splitIdx + 4..raw.size] } else { "" }
    let lines = headerText.split("\r\n")
    if (lines.size == 0) {
        throw Exception("raw SSE response missing status line")
    }

    let status = parseSseStatusCode(lines[0])
    let headerMap = HashMap<String, String>()
    var i: Int64 = 1
    while (i < lines.size) {
        let line = lines[i]
        let colonIdx = indexOfSseRune(line, r':')
        if (colonIdx > 0) {
            let key = line[..colonIdx].trimAscii().toAsciiLower()
            let value = line[colonIdx + 1..line.size].trimAscii()
            headerMap.add(key, value)
        }
        i += 1
    }
    SseRawHttpResponse(status, headerMap, body)
}

func parseSseStatusCode(statusLine: String): UInt16 {
    let parts = statusLine.split(" ")
    if (parts.size < 2) {
        throw Exception("invalid SSE status line: ${statusLine}")
    }
    let digits = parts[1].trimAscii()
    var value: Int64 = 0
    for (ch in digits.toRuneArray()) {
        if (ch < r'0' || ch > r'9') {
            throw Exception("invalid SSE status code: ${statusLine}")
        }
        value = value * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
    }
    UInt16(value)
}

func decodeIfChunked(resp: SseRawHttpResponse): String {
    if ((resp.header("transfer-encoding") ?? "") == "chunked") {
        return decodeSseChunkedBody(resp.body)
    }
    resp.body
}

func decodeSseChunkedBody(raw: String): String {
    var idx: Int64 = 0
    var out = ""
    while (idx < raw.size) {
        let lineEnd = indexOfSseText(raw[idx..raw.size], "\r\n")
        if (lineEnd < 0) {
            throw Exception("invalid chunked SSE response: missing chunk header terminator")
        }
        let sizeText = raw[idx..idx + lineEnd].trimAscii()
        let chunkSize = parseSseHexInt64(sizeText)
        idx += lineEnd + 2
        if (chunkSize == 0) {
            break
        }
        out += raw[idx..idx + chunkSize]
        idx += chunkSize + 2
    }
    out
}

func parseSseHexInt64(text: String): Int64 {
    let trimmed = text.trimAscii().toAsciiLower()
    var value: Int64 = 0
    for (ch in trimmed.toRuneArray()) {
        value *= 16
        if (ch >= r'0' && ch <= r'9') {
            value += Int64(UInt32(ch)) - Int64(UInt32(r'0'))
        } else if (ch >= r'a' && ch <= r'f') {
            value += 10 + Int64(UInt32(ch)) - Int64(UInt32(r'a'))
        } else {
            throw Exception("invalid SSE hex length: ${text}")
        }
    }
    value
}

func indexOfSseText(text: String, pattern: String): Int64 {
    let chars = text.toRuneArray()
    let target = pattern.toRuneArray()
    if (target.size == 0) {
        return 0
    }
    if (chars.size < target.size) {
        return -1
    }
    var i: Int64 = 0
    while (i <= chars.size - target.size) {
        var ok = true
        var j: Int64 = 0
        while (j < target.size) {
            if (chars[i + j] != target[j]) {
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

func indexOfSseRune(text: String, target: Rune): Int64 {
    let chars = text.toRuneArray()
    var i: Int64 = 0
    while (i < chars.size) {
        if (chars[i] == target) {
            return i
        }
        i += 1
    }
    -1
}

func containsSseText(text: String, target: String): Bool {
    indexOfSseText(text, target) >= 0
}

func headerHasSseToken(value: String, expected: String): Bool {
    for (part in value.split(",")) {
        if (part.trimAscii().toAsciiLower() == expected.toAsciiLower()) {
            return true
        }
    }
    false
}

func shutdownSseApp(app: App, future: Future<Unit>): Unit {
    app.shutdown()
    try {
        let _ = future.get(Duration.second * 1)
    } catch (_: Exception) {
        future.cancel()
    }
}

func chooseSsePort(offset: Int64): UInt16 {
    let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let raw = 43000 + ((nowMs + offset) % 10000)
    UInt16(raw)
}
