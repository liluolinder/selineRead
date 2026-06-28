package ignite.tests

import ignite.*
import seajson.JsonWriter as SeaJsonNativeWriter
import std.collection.{ArrayList, HashMap}
import std.net.{TcpSocket, IPSocketAddress}

/// Focused real-HTTP proof for the public `JsonWriterInputStream` seam.
///
/// This suite proves the second JSON product path:
/// 1. H1 known-length through `ctx.sendStream(..., contentLength: Some(...))`
/// 2. H1 unknown-length chunked fallback when content-length is omitted
/// 3. `HEAD` keeps headers and closes the stream without starting the producer
@Test
public class JsonWriterInputStreamTestSuite {
    @TestCase
    public func testKnownLengthJsonWriterInputStreamUsesContentLengthWithoutChunkedFraming(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1921)
        let app = App(config: Config())
        app.get("/json-known", { ctx =>
            let stream = JsonWriterInputStream({ jw =>
                jw.startObject()
                jw.writeName("a")
                jw.writeValue(1)
                jw.endObject()
            })
            _ = ctx.sendStream(
                stream,
                contentType: "application/json; charset=utf-8",
                contentLength: Some(7)
            )
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "GET", "/json-known", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", "7")
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.body, "{\"a\":1}")
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testUnknownLengthJsonWriterInputStreamFallsBackToChunked(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1923)
        let app = App(config: Config())
        app.get("/json-chunked", { ctx =>
            let stream = JsonWriterInputStream({ jw =>
                jw.startObject()
                jw.writeName("msg")
                jw.writeValue("bridge")
                jw.endObject()
            })
            _ = ctx.sendStream(
                stream,
                contentType: "application/json; charset=utf-8"
            )
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "GET", "/json-chunked", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-length") ?? "", "")
            @Assert(resp.header("transfer-encoding") ?? "", "chunked")
            let body = decodeJsonWriterInputChunkedBody(resp.body)
            @Assert(body, "{\"msg\":\"bridge\"}")
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testHeadClosesJsonWriterInputStreamWithoutStartingProducer(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1925)
        let app = App(config: Config())
        let tracked = ArrayList<JsonWriterInputStream>()
        app.head("/json-head", { ctx =>
            let stream = JsonWriterInputStream({ jw =>
                jw.startObject()
                jw.writeName("head")
                jw.writeValue(true)
                jw.endObject()
            })
            tracked.add(stream)
            _ = ctx.sendStream(
                stream,
                contentType: "application/json; charset=utf-8",
                contentLength: Some(13)
            )
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "HEAD", "/json-head", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", "13")
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.body, "")
            @Assert(tracked.size, Int64(1))
            let stream = tracked[0]
            @Assert(stream.isClosed(), true)
            @Assert(stream.hasStartedProducer(), false)
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }
}

/// Focused real-HTTP proof for the thin `ctx.jsonStream(...)` sugar.
///
/// This suite proves the wrapper preserves the already-accepted bridge truth:
/// 1. H1 known-length through `contentLength: Some(...)`
/// 2. H1 unknown-length chunked fallback
/// 3. `HEAD` keeps headers and never invokes the producer callback
@Test
public class JsonStreamCtxSugarTestSuite {
    @TestCase
    public func testJsonStreamKnownLengthUsesContentLengthWithoutChunkedFraming(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1927)
        let app = App(config: Config())
        app.get("/ctx-json-known", { ctx =>
            _ = ctx.jsonStream({ jw =>
                jw.startObject()
                jw.writeName("a")
                jw.writeValue(1)
                jw.endObject()
            }, contentLength: Some(7))
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "GET", "/ctx-json-known", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", "7")
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.body, "{\"a\":1}")
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testJsonStreamUnknownLengthFallsBackToChunked(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1929)
        let app = App(config: Config())
        app.get("/ctx-json-chunked", { ctx =>
            _ = ctx.jsonStream({ jw =>
                jw.startObject()
                jw.writeName("msg")
                jw.writeValue("bridge")
                jw.endObject()
            })
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "GET", "/ctx-json-chunked", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-length") ?? "", "")
            @Assert(resp.header("transfer-encoding") ?? "", "chunked")
            let body = decodeJsonWriterInputChunkedBody(resp.body)
            @Assert(body, "{\"msg\":\"bridge\"}")
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testHeadJsonStreamKeepsHeadersWithoutInvokingProducer(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1931)
        let app = App(config: Config())
        let started = ArrayList<String>()
        app.head("/ctx-json-head", { ctx =>
            _ = ctx.jsonStream({ jw =>
                started.add("started")
                jw.startObject()
                jw.writeName("head")
                jw.writeValue(true)
                jw.endObject()
            }, contentLength: Some(13))
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "HEAD", "/ctx-json-head", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", "13")
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.body, "")
            @Assert(started.size, Int64(0))
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }
}

/// Focused real-HTTP proof for `ctx.jsonSerializeStream(...)`.
///
/// This suite proves typed `JsonSerializable` callers can now reuse the accepted
/// bridge path without first full-buffering through `serializeJson(...) -> String`:
/// 1. H1 known-length through `contentLength: Some(...)`
/// 2. H1 unknown-length chunked fallback
/// 3. `HEAD` keeps headers and never invokes `toJson(...)`
@Test
public class JsonSerializeStreamCtxSugarTestSuite {
    @TestCase
    public func testJsonSerializeStreamKnownLengthUsesContentLengthWithoutChunkedFraming(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1933)
        let app = App(config: Config())
        app.get("/ctx-jsonserialize-known", { ctx =>
            _ = ctx.jsonSerializeStream(
                buildJsonSerializeStreamValues(),
                contentLength: Some(7)
            )
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "GET", "/ctx-jsonserialize-known", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", "7")
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.body, "[1,2,3]")
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testJsonSerializeStreamUnknownLengthFallsBackToChunked(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1935)
        let app = App(config: Config())
        app.get("/ctx-jsonserialize-chunked", { ctx =>
            _ = ctx.jsonSerializeStream(buildJsonSerializeStreamValues())
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "GET", "/ctx-jsonserialize-chunked", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-length") ?? "", "")
            @Assert(resp.header("transfer-encoding") ?? "", "chunked")
            let body = decodeJsonWriterInputChunkedBody(resp.body)
            @Assert(body, "[1,2,3]")
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testHeadJsonSerializeStreamKeepsHeadersWithoutInvokingToJson(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1937)
        let app = App(config: Config())
        let started = ArrayList<String>()
        app.head("/ctx-jsonserialize-head", { ctx =>
            _ = ctx.jsonSerializeStream(
                HeadTrackedJsonSerializable(started),
                contentLength: Some(7)
            )
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "HEAD", "/ctx-jsonserialize-head", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", "7")
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.body, "")
            @Assert(started.size, Int64(0))
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }
}

/// Focused real-HTTP proof for `ctx.jsonEncodeStream(...)`.
///
/// This suite proves the SeaJson-owned writer-facing twin can now reuse the
/// accepted `sendStream(...)` bridge path without changing current
/// `jsonEncode(...)` defaults:
/// 1. H1 known-length through `contentLength: Some(...)`
/// 2. H1 unknown-length chunked fallback
/// 3. `HEAD` keeps headers and never invokes `writeJson(...)`
@Test
public class JsonEncodeStreamCtxSugarTestSuite {
    @TestCase
    public func testJsonEncodeStreamKnownLengthUsesContentLengthWithoutChunkedFraming(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1939)
        let app = App(config: Config())
        let payload = DualJsonEncodeStreamValue("stream", 5)
        let expected = payload.toJsonString()
        app.get("/ctx-jsonencode-known", { ctx =>
            _ = ctx.jsonEncodeStream(payload, contentLength: Some(expected.size))
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "GET", "/ctx-jsonencode-known", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", expected.size.toString())
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.body, expected)
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testJsonEncodeStreamUnknownLengthFallsBackToChunked(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1941)
        let app = App(config: Config())
        let payload = DualJsonEncodeStreamValue("chunked", 7)
        let expected = payload.toJsonString()
        app.get("/ctx-jsonencode-chunked", { ctx =>
            _ = ctx.jsonEncodeStream(payload)
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "GET", "/ctx-jsonencode-chunked", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-length") ?? "", "")
            @Assert(resp.header("transfer-encoding") ?? "", "chunked")
            let body = decodeJsonWriterInputChunkedBody(resp.body)
            @Assert(body, expected)
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testHeadJsonEncodeStreamKeepsHeadersWithoutInvokingWriteJson(): Unit {
        let port = chooseJsonWriterInputStreamTestPort(1943)
        let app = App(config: Config())
        let started = ArrayList<String>()
        let payload = HeadTrackedJsonWriterEncodable(started)
        let expected = "{\"head\":true}"
        app.head("/ctx-jsonencode-head", { ctx =>
            _ = ctx.jsonEncodeStream(payload, contentLength: Some(expected.size))
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawJsonWriterInputHttp(port, "HEAD", "/ctx-jsonencode-head", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", expected.size.toString())
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.body, "")
            @Assert(started.size, Int64(0))
        } finally {
            shutdownJsonWriterInputTestApp(app, serverFuture)
        }
    }
}

/// Focused proof for the current stdx-backed `SeaJson-Bridge` first cut.
///
/// This suite keeps two truths honest:
/// 1. old full-buffer `serializeJson(...)` still returns the same string
/// 2. bridge extraction did not change the accepted `ctx.jsonSerializeStream(...)` payload shape
@Test
public class SeaJsonBridgeFirstCutTestSuite {
    @TestCase
    public func testSerializeJsonStillReturnsTheSameFullBufferedString(): Unit {
        @Assert(serializeJson(buildJsonSerializeStreamValues()), "[1,2,3]")
    }
}

class JsonWriterInputRawHttpResponse {
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

func sendRawJsonWriterInputHttp(
    port: UInt16,
    method: String,
    target: String,
    headers: Array<(String, String)>
): JsonWriterInputRawHttpResponse {
    var attempt: Int64 = 0
    while (attempt < 20) {
        try {
            return doSendRawJsonWriterInputHttp(port, method, target, headers)
        } catch (_: Exception) {
            if (attempt == 19) {
                throw Exception("failed to connect json writer input test server: ${port} ${target}")
            }
            sleep(Duration.millisecond * 50)
            attempt += 1
        }
    }
    throw Exception("failed to connect json writer input test server: ${port} ${target}")
}

func doSendRawJsonWriterInputHttp(
    port: UInt16,
    method: String,
    target: String,
    headers: Array<(String, String)>
): JsonWriterInputRawHttpResponse {
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
        parseJsonWriterInputRawHttpResponse(raw)
    } finally {
        socket.close()
    }
}

func parseJsonWriterInputRawHttpResponse(raw: String): JsonWriterInputRawHttpResponse {
    let splitIdx = indexOfJsonWriterInputText(raw, "\r\n\r\n")
    let headerText = if (splitIdx >= 0) { raw[..splitIdx] } else { raw }
    let body = if (splitIdx >= 0) { raw[splitIdx + 4..raw.size] } else { "" }
    let lines = headerText.split("\r\n")
    if (lines.size == 0) {
        throw Exception("raw response missing status line")
    }

    let status = parseJsonWriterInputStatusCode(lines[0])
    let headerMap = HashMap<String, String>()
    var i: Int64 = 1
    while (i < lines.size) {
        let line = lines[i]
        let colonIdx = indexOfJsonWriterInputRune(line, r':')
        if (colonIdx > 0) {
            let key = line[..colonIdx].trimAscii().toAsciiLower()
            let value = line[colonIdx + 1..line.size].trimAscii()
            headerMap.add(key, value)
        }
        i += 1
    }
    JsonWriterInputRawHttpResponse(status, headerMap, body)
}

func parseJsonWriterInputStatusCode(statusLine: String): UInt16 {
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
        value = value * 10 + digitOfJsonWriterInputRune(ch)
    }
    UInt16(value)
}

func decodeJsonWriterInputChunkedBody(chunked: String): String {
    var cursor: Int64 = 0
    var out = ""
    while (cursor < chunked.size) {
        let lineEnd = indexOfJsonWriterInputTextFrom(chunked, "\r\n", cursor)
        if (lineEnd < 0) {
            throw Exception("invalid chunked body: missing chunk size line")
        }
        let sizeLine = chunked[cursor..lineEnd].trimAscii().toAsciiLower()
        let chunkSize = parseJsonWriterInputHex(sizeLine)
        cursor = lineEnd + 2
        if (chunkSize == 0) {
            break
        }
        if (cursor + chunkSize > chunked.size) {
            throw Exception("invalid chunked body: chunk overrun")
        }
        out += chunked[cursor..cursor + chunkSize]
        cursor += chunkSize
        if (cursor + 2 > chunked.size || chunked[cursor..cursor + 2] != "\r\n") {
            throw Exception("invalid chunked body: missing chunk terminator")
        }
        cursor += 2
    }
    out
}

func parseJsonWriterInputHex(text: String): Int64 {
    if (text.size == 0) {
        throw Exception("invalid hex text")
    }
    var value: Int64 = 0
    for (ch in text.toRuneArray()) {
        value *= 16
        if (ch >= r'0' && ch <= r'9') {
            value += digitOfJsonWriterInputRune(ch)
        } else if (ch >= r'a' && ch <= r'f') {
            value += hexOfJsonWriterInputRune(ch)
        } else {
            throw Exception("invalid hex text: ${text}")
        }
    }
    value
}

func indexOfJsonWriterInputText(text: String, needle: String): Int64 {
    indexOfJsonWriterInputTextFrom(text, needle, 0)
}

func indexOfJsonWriterInputTextFrom(text: String, needle: String, start: Int64): Int64 {
    if (needle.size == 0) {
        return 0
    }
    if (text.size < needle.size || start < 0) {
        return -1
    }
    var i = start
    while (i <= text.size - needle.size) {
        if (text[i..i + needle.size] == needle) {
            return i
        }
        i += 1
    }
    -1
}

func indexOfJsonWriterInputRune(text: String, target: Rune): Int64 {
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

func digitOfJsonWriterInputRune(ch: Rune): Int64 {
    match (ch) {
        case r'0' => 0
        case r'1' => 1
        case r'2' => 2
        case r'3' => 3
        case r'4' => 4
        case r'5' => 5
        case r'6' => 6
        case r'7' => 7
        case r'8' => 8
        case r'9' => 9
        case _ => throw Exception("invalid numeric rune")
    }
}

func hexOfJsonWriterInputRune(ch: Rune): Int64 {
    match (ch) {
        case r'a' => 10
        case r'b' => 11
        case r'c' => 12
        case r'd' => 13
        case r'e' => 14
        case r'f' => 15
        case _ => throw Exception("invalid hex rune")
    }
}

func chooseJsonWriterInputStreamTestPort(seed: Int64): UInt16 {
    UInt16(seed)
}

func buildJsonSerializeStreamValues(): ArrayList<Int64> {
    let values = ArrayList<Int64>()
    values.add(1)
    values.add(2)
    values.add(3)
    values
}

class HeadTrackedJsonSerializable <: JsonSerializable {
    let _started: ArrayList<String>

    public init(started: ArrayList<String>) {
        _started = started
    }

    public func toJson(w: JsonWriter): Unit {
        _started.add("started")
        w.startArray()
        w.writeValue(1)
        w.writeValue(2)
        w.writeValue(3)
        w.endArray()
    }
}

class DualJsonEncodeStreamValue <: JsonEncodable & JsonWriterEncodable {
    let _name: String
    let _n: Int64

    public init(name: String, n: Int64) {
        _name = name
        _n = n
    }

    public func toJsonString(): String {
        "{\"name\":\"${_name}\",\"n\":${_n}}"
    }

    public func writeJson(writer: SeaJsonNativeWriter): Unit {
        writer.beginObject()
            .name("name").value(_name)
            .name("n").value(_n)
        .endObject()
    }
}

class HeadTrackedJsonWriterEncodable <: JsonWriterEncodable {
    let _started: ArrayList<String>

    public init(started: ArrayList<String>) {
        _started = started
    }

    public func writeJson(writer: SeaJsonNativeWriter): Unit {
        _started.add("started")
        writer.beginObject()
            .name("head").value(true)
        .endObject()
    }
}

func shutdownJsonWriterInputTestApp(app: App, future: Future<Unit>): Unit {
    app.shutdown()
    try {
        let _ = future.get(Duration.millisecond * 100)
    } catch (_: Exception) {
        future.cancel()
    }
}
