package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.HashMap
import std.net.{TcpSocket, IPSocketAddress}
import std.time.DateTime

@Test
public class HttpsRedirectMiddlewareTestSuite {
    @TestCase
    public func testHttpsRedirectMiddlewarePreservesPathAndQuery(): Unit {
        let app = App(config: Config())
        app.use(httpsRedirectMiddleware())
        app.get("/docs", { ctx =>
            _ = ctx.sendString("docs")
        })

        let port = chooseRedirectTestPort(811)
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        try {
            let resp = sendRawHttpWithRetry(
                port,
                "GET",
                "/docs?page=2&lang=zh",
                [("host", "ignite.dev:8080")]
            )
            @Assert(resp.status, UInt16(307))
            @Assert(resp.header("location") ?? "", "https://ignite.dev/docs?page=2&lang=zh")
        } finally {
            app.shutdown()
            closeRedirectTestServerFuture(serverFuture)
        }
    }

    @TestCase
    public func testHttpsRedirectMiddlewareCanUseForwardedHostAndCustomPort(): Unit {
        let app = App(config: Config())
        app.use(
            httpsRedirectMiddleware(
                config: HttpsRedirectConfig(httpsPort: UInt16(18443))
            )
        )
        app.get("/api", { ctx =>
            _ = ctx.sendString("api")
        })

        let port = chooseRedirectTestPort(877)
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        try {
            let resp = sendRawHttpWithRetry(
                port,
                "GET",
                "/api",
                [
                    ("host", "127.0.0.1:18080"),
                    ("x-forwarded-host", "public.ignite.dev")
                ]
            )
            @Assert(resp.status, UInt16(307))
            @Assert(resp.header("location") ?? "", "https://public.ignite.dev:18443/api")
        } finally {
            app.shutdown()
            closeRedirectTestServerFuture(serverFuture)
        }
    }

    @TestCase
    public func testHttpsRedirectMiddlewareSkipsWhenForwardedProtoIsHttps(): Unit {
        let app = App(config: Config())
        app.use(httpsRedirectMiddleware())
        app.get("/health", { ctx =>
            _ = ctx.sendString("ok")
        })

        let resp = app.handleForTest(
            "GET",
            "/health",
            headers: [
                ("host", "ignite.dev"),
                ("x-forwarded-proto", "https")
            ]
        )
        @Assert(resp.status, UInt16(200))
        @Assert(resp.body, "ok")
    }

    @TestCase
    public func testHttpsRedirectMiddlewareSupportsSkipPaths(): Unit {
        let app = App(config: Config())
        app.use(
            httpsRedirectMiddleware(
                config: HttpsRedirectConfig(
                    skipPaths: ["/health", "/internal/*"]
                )
            )
        )
        app.get("/health", { ctx =>
            _ = ctx.sendString("health-ok")
        })
        app.get("/internal/status", { ctx =>
            _ = ctx.sendString("internal-ok")
        })

        let healthResp = app.handleForTest(
            "GET",
            "/health",
            headers: [("host", "ignite.dev")]
        )
        @Assert(healthResp.status, UInt16(200))
        @Assert(healthResp.body, "health-ok")

        let internalResp = app.handleForTest(
            "GET",
            "/internal/status",
            headers: [("host", "ignite.dev")]
        )
        @Assert(internalResp.status, UInt16(200))
        @Assert(internalResp.body, "internal-ok")
    }
}

class RawHttpResponse {
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

func sendRawHttpWithRetry(
    port: UInt16,
    method: String,
    target: String,
    headers: Array<(String, String)>
): RawHttpResponse {
    var attempt: Int64 = 0
    while (attempt < 20) {
        try {
            return sendRawHttp(port, method, target, headers)
        } catch (_: Exception) {
            if (attempt == 19) {
                throw Exception("failed to connect raw http test server: ${port} ${target}")
            }
            sleep(Duration.millisecond * 50)
            attempt += 1
        }
    }
    throw Exception("failed to connect raw http test server: ${port} ${target}")
}

func sendRawHttp(
    port: UInt16,
    method: String,
    target: String,
    headers: Array<(String, String)>
): RawHttpResponse {
    let socket = TcpSocket(IPSocketAddress.parse("127.0.0.1:${port}"))
    socket.connect()
    try {
        var request = "${method} ${target} HTTP/1.1\r\n"
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
        parseRawHttpResponse(raw)
    } finally {
        socket.close()
    }
}

func parseRawHttpResponse(raw: String): RawHttpResponse {
    let splitIdx = indexOfText(raw, "\r\n\r\n")
    let headerText = if (splitIdx >= 0) { raw[..splitIdx] } else { raw }
    let body = if (splitIdx >= 0) { raw[splitIdx + 4..raw.size] } else { "" }
    let lines = headerText.split("\r\n")
    if (lines.size == 0) {
        throw Exception("raw http response missing status line")
    }

    let statusLine = lines[0]
    let status = parseStatusCode(statusLine)
    let headerMap = HashMap<String, String>()
    var i: Int64 = 1
    while (i < lines.size) {
        let line = lines[i]
        let colonIdx = indexOfRune(line, r':')
        if (colonIdx > 0) {
            let key = line[..colonIdx].trimAscii().toAsciiLower()
            let value = line[colonIdx + 1..line.size].trimAscii()
            headerMap.add(key, value)
        }
        i += 1
    }
    RawHttpResponse(status, headerMap, body)
}

func parseStatusCode(statusLine: String): UInt16 {
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

func indexOfText(text: String, needle: String): Int64 {
    let t = text.toRuneArray()
    let n = needle.toRuneArray()
    if (n.size == 0) {
        return 0
    }
    if (t.size < n.size) {
        return -1
    }
    var i: Int64 = 0
    while (i <= t.size - n.size) {
        var ok = true
        var j: Int64 = 0
        while (j < n.size) {
            if (t[i + j] != n[j]) {
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

func indexOfRune(text: String, target: Rune): Int64 {
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

func chooseRedirectTestPort(offset: Int64): UInt16 {
    let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let raw = 46000 + ((nowMs + offset) % 6000)
    UInt16(raw)
}

func closeRedirectTestServerFuture(serverFuture: Future<Unit>): Unit {
    try {
        let _ = serverFuture.get(Duration.second * 1)
    } catch (_: Exception) {
        serverFuture.cancel()
    }
}
