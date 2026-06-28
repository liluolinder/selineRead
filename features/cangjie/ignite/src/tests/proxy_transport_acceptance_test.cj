package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.HashMap
import std.fs.{Directory, exists, removeIfExists}
import std.net.{IPSocketAddress, TcpSocket}
import std.time.DateTime
import stdx.net.tls.TlsClientConfig

@Test
public class ProxyTransportAcceptanceTestSuite {
    @TestCase
    public func testHttpsUnknownLengthUploadFallsBackToTempFileBuffering(): Unit {
        let upstreamPort = chooseProxyAcceptancePort(441)
        let proxyPort = chooseProxyAcceptancePort(445)
        let tempRoot = "/tmp/ignite_proxy_acceptance_https_unknown_length_${proxyPort}"
        let tempDir = tempRoot + "/https-body"
        let payload = buildProxyAcceptancePayload()

        _ = removeIfExists(tempRoot, recursive: true)

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "https://127.0.0.1:${upstreamPort}",
                unknownLengthBodyTempDir: tempDir
            )
        ))

        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendProxyAcceptanceChunkedRequestWithRetry(
                proxyPort,
                "/proxy/https-fallback",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )

            @Assert(resp.status, UInt16(502))
            @Assert(proxyAcceptanceContains(resp.bodyText, "Bad Gateway:"), true)
            @Assert(resp.proxyRequestBodyMode, "temp-file-buffered")
            @Assert(resp.proxyRequestBodyBytes, payload.size.toString())
            @Assert(resp.proxyRequestBodyLimitBytes, "")
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, resp.bodyText.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, resp.bodyText.size.toString())
            @Assert(exists(tempDir), true)
            @Assert(Directory.isEmpty(tempDir), true)
        } finally {
            shutdownProxyAcceptanceApp(proxy, proxyFuture)
            _ = removeIfExists(tempRoot, recursive: true)
        }
    }

    @TestCase
    public func testHttpsUnknownLengthUploadRejectsBufferedOverLimit(): Unit {
        let upstreamPort = chooseProxyAcceptancePort(446)
        let proxyPort = chooseProxyAcceptancePort(449)
        let tempRoot = "/tmp/ignite_proxy_acceptance_https_unknown_length_limit_${proxyPort}"
        let tempDir = tempRoot + "/https-body"
        let payload = buildProxyAcceptancePayload()
        let maxBufferedBodyBytes = payload.size / 2

        _ = removeIfExists(tempRoot, recursive: true)

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "https://127.0.0.1:${upstreamPort}",
                unknownLengthBodyTempDir: tempDir,
                maxBufferedBodyBytes: maxBufferedBodyBytes
            )
        ))

        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendProxyAcceptanceChunkedRequestWithRetry(
                proxyPort,
                "/proxy/https-fallback-limit",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )

            @Assert(resp.status, UInt16(413))
            @Assert(proxyAcceptanceContains(resp.bodyText, "exceeds limit"), true)
            @Assert(resp.proxyRequestBodyMode, "temp-file-buffered-over-limit")
            @Assert(resp.proxyRequestBodyLimitBytes, maxBufferedBodyBytes.toString())
            @Assert(parseProxyAcceptanceDecimalInt64(resp.proxyRequestBodyBytes) > maxBufferedBodyBytes, true)
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, resp.bodyText.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, resp.bodyText.size.toString())
            @Assert(exists(tempDir), true)
            @Assert(Directory.isEmpty(tempDir), true)
        } finally {
            shutdownProxyAcceptanceApp(proxy, proxyFuture)
            _ = removeIfExists(tempRoot, recursive: true)
        }
    }

    @TestCase
    public func testHttpsSeamWithTlsConfigBypassesMissingTlsError(): Unit {
        // Proves the TlsClientConfig seam is actively attached to ClientBuilder:
        //   with tlsConfig set, the proxy's HTTP client bypasses the "TLS must be configured"
        //   gate and attempts to connect.  With no upstream listener, the error
        //   is a transport-level 502 (connection refused), NOT the old boundary error.
        let upstreamPort = chooseProxyAcceptancePort(461)
        let proxyPort = chooseProxyAcceptancePort(465)
        let tempRoot = "/tmp/ignite_proxy_acceptance_tls_seam_bypass_${proxyPort}"
        let tempDir = tempRoot + "/https-body"
        let payload = buildProxyAcceptancePayload()

        _ = removeIfExists(tempRoot, recursive: true)

        // No upstream — port is empty; the proxy HTTP client will attempt
        // TCP connect and fail with "Connection refused" (NOT "TLS must be configured").
        let clientTlsConfig = TlsClientConfig()

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "https://127.0.0.1:${upstreamPort}",
                unknownLengthBodyTempDir: tempDir,
                tlsConfig: clientTlsConfig
            )
        ))

        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendProxyAcceptanceChunkedRequestWithRetry(
                proxyPort,
                "/proxy/https-seam-active",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )

            @Assert(resp.status, UInt16(502))
            @Assert(proxyAcceptanceContains(resp.bodyText, "Bad Gateway:"), true)
            // Critical discriminant: the old "TLS must be configured" MUST NOT appear
            // because the seam allows the HTTP engine to proceed past the old gate.
            match (proxyAcceptanceContains(resp.bodyText, "TLS must be configured")) {
                case true =>
                    throw Exception("TlsClientConfig seam is NOT attached: client still reports 'TLS must be configured' instead of attempting connection")
                case false =>
                    // Expected: a transport-level error (connection refused, timeout, etc.)
                    ()
            }
            @Assert(resp.proxyRequestBodyMode, "temp-file-buffered")
            @Assert(resp.proxyRequestBodyBytes, payload.size.toString())
            @Assert(resp.proxyRequestBodyLimitBytes, "")
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, resp.bodyText.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, resp.bodyText.size.toString())
            @Assert(exists(tempDir), true)
            @Assert(Directory.isEmpty(tempDir), true)
        } finally {
            shutdownProxyAcceptanceApp(proxy, proxyFuture)
            _ = removeIfExists(tempRoot, recursive: true)
        }
    }

    @TestCase
    public func testHttpsWithoutTlsConfigFailsWithOldMissingTlsBoundary(): Unit {
        // Proves the OLD boundary: without TlsClientConfig, https target
        // fails with "TLS must be configured when HTTPS requests are sent."
        // This is the control — it must pass to prove the active-seam test
        // above is a genuinely different failure mode.
        let proxyPort = chooseProxyAcceptancePort(475)
        let tempRoot = "/tmp/ignite_proxy_acceptance_old_missing_tls_boundary_${proxyPort}"
        let tempDir = tempRoot + "/https-body"
        let payload = buildProxyAcceptancePayload()

        _ = removeIfExists(tempRoot, recursive: true)

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "https://127.0.0.1:${chooseProxyAcceptancePort(999)}",
                unknownLengthBodyTempDir: tempDir
            )
        ))

        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendProxyAcceptanceChunkedRequestWithRetry(
                proxyPort,
                "/proxy/https-no-tls",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )

            @Assert(resp.status, UInt16(502))
            @Assert(proxyAcceptanceContains(resp.bodyText, "Bad Gateway:"), true)
            // Old boundary: no TlsClientConfig → stdx HTTP engine rejects https
            @Assert(proxyAcceptanceContains(resp.bodyText, "TLS must be configured"), true)
            @Assert(resp.proxyRequestBodyMode, "temp-file-buffered")
            @Assert(resp.proxyRequestBodyBytes, payload.size.toString())
            @Assert(resp.proxyRequestBodyLimitBytes, "")
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, resp.bodyText.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, resp.bodyText.size.toString())
            @Assert(exists(tempDir), true)
            @Assert(Directory.isEmpty(tempDir), true)
        } finally {
            shutdownProxyAcceptanceApp(proxy, proxyFuture)
            _ = removeIfExists(tempRoot, recursive: true)
        }
    }
}

func buildProxyAcceptancePayload(): String {
    let line = "ignite-proxy-acceptance-unknown-length-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ\n"
    var out = ""
    var i: Int64 = 0
    while (i < 4096) {
        out += line
        i += 1
    }
    out
}

func sendProxyAcceptanceChunkedRequestWithRetry(
    port: UInt16,
    target: String,
    body: String,
    headers!: Array<(String, String)> = []
): ProxyAcceptanceResponseSnapshot {
    var attempt: Int64 = 0
    while (attempt < 20) {
        try {
            return sendProxyAcceptanceChunkedRequest(port, target, body, headers: headers)
        } catch (_: Exception) {
            if (attempt == 19) {
                throw Exception("failed to connect chunked proxy test server: ${port} ${target}")
            }
            sleep(Duration.millisecond * 50)
            attempt += 1
        }
    }
    throw Exception("failed to connect chunked proxy test server: ${port} ${target}")
}

func sendProxyAcceptanceChunkedRequest(
    port: UInt16,
    target: String,
    body: String,
    headers!: Array<(String, String)> = []
): ProxyAcceptanceResponseSnapshot {
    let socket = TcpSocket(IPSocketAddress.parse("127.0.0.1:${port}"))
    socket.connect()
    try {
        var request = "POST ${target} HTTP/1.1\r\n"
        request += "host: 127.0.0.1:${port}\r\n"
        request += "transfer-encoding: chunked\r\n"
        request += "connection: close\r\n"
        for ((key, value) in headers) {
            request += "${key}: ${value}\r\n"
        }
        request += "\r\n"
        socket.write(request.toArray())
        writeProxyAcceptanceChunkedBody(socket, body)

        let buf = Array<UInt8>(4096, repeat: 0)
        var raw = ""
        while (true) {
            let n = socket.read(buf)
            if (n <= 0) {
                break
            }
            raw += String.fromUtf8(buf[..n])
        }
        parseProxyAcceptanceResponse(raw)
    } finally {
        socket.close()
    }
}

func writeProxyAcceptanceChunkedBody(socket: TcpSocket, body: String): Unit {
    let bytes = body.toArray()
    var index: Int64 = 0
    let chunkSize: Int64 = 2048
    while (index < bytes.size) {
        let end = if (index + chunkSize < bytes.size) { index + chunkSize } else { bytes.size }
        let chunk = bytes[index..end]
        let header = int64ToProxyAcceptanceHex(chunk.size) + "\r\n"
        socket.write(header.toArray())
        socket.write(chunk)
        socket.write("\r\n".toArray())
        index = end
    }
    socket.write("0\r\n\r\n".toArray())
}

func parseProxyAcceptanceResponse(raw: String): ProxyAcceptanceResponseSnapshot {
    let splitIdx = indexOfProxyAcceptanceText(raw, "\r\n\r\n")
    let headerText = if (splitIdx >= 0) { raw[..splitIdx] } else { raw }
    let bodyText = if (splitIdx >= 0) { raw[splitIdx + 4..raw.size] } else { "" }
    let lines = headerText.split("\r\n")
    if (lines.size == 0) {
        throw Exception("raw proxy response missing status line")
    }

    let status = parseProxyAcceptanceStatusCode(lines[0])
    let headers = HashMap<String, String>()
    var i: Int64 = 1
    while (i < lines.size) {
        let line = lines[i]
        let colonIdx = indexOfProxyAcceptanceRune(line, r':')
        if (colonIdx > 0) {
            let key = line[..colonIdx].trimAscii().toAsciiLower()
            let value = line[colonIdx + 1..line.size].trimAscii()
            headers.add(key, value)
        }
        i += 1
    }

    ProxyAcceptanceResponseSnapshot(
        status,
        bodyText,
        headers.get(IGNITE_PROXY_REQUEST_BODY_MODE_HEADER.toAsciiLower()) ?? "",
        headers.get(IGNITE_PROXY_REQUEST_BODY_BYTES_HEADER.toAsciiLower()) ?? "",
        headers.get(IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_HEADER.toAsciiLower()) ?? "",
        headers.get(IGNITE_PROXY_RESPONSE_BODY_MODE_HEADER.toAsciiLower()) ?? "",
        headers.get(IGNITE_PROXY_RESPONSE_BODY_BYTES_HEADER.toAsciiLower()) ?? "",
        headers.get(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_HEADER.toAsciiLower()) ?? "",
        headers.get(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_HEADER.toAsciiLower()) ?? ""
    )
}

func parseProxyAcceptanceStatusCode(statusLine: String): UInt16 {
    let parts = statusLine.split(" ")
    if (parts.size < 2) {
        throw Exception("invalid status line: ${statusLine}")
    }
    let digits = parts[1].trimAscii()
    var value: Int64 = 0
    for (ch in digits.toRuneArray()) {
        if (ch < r'0' || ch > r'9') {
            throw Exception("invalid status code: ${statusLine}")
        }
        value = value * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
    }
    UInt16(value)
}

func parseProxyAcceptanceDecimalInt64(text: String): Int64 {
    let trimmed = text.trimAscii()
    if (trimmed.size == 0) {
        throw Exception("invalid decimal integer")
    }
    var value: Int64 = 0
    for (ch in trimmed.toRuneArray()) {
        if (ch < r'0' || ch > r'9') {
            throw Exception("invalid decimal integer")
        }
        value = value * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
    }
    value
}

func int64ToProxyAcceptanceHex(value: Int64): String {
    let hex = "0123456789abcdef".toRuneArray()
    if (value < 16) {
        return hex[value].toString()
    }
    int64ToProxyAcceptanceHex(value / 16) + hex[value % 16].toString()
}

func indexOfProxyAcceptanceText(text: String, target: String): Int64 {
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
        var matched = true
        var j: Int64 = 0
        while (j < b.size) {
            if (a[i + j] != b[j]) {
                matched = false
                break
            }
            j += 1
        }
        if (matched) {
            return i
        }
        i += 1
    }
    -1
}

func indexOfProxyAcceptanceRune(text: String, target: Rune): Int64 {
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

func proxyAcceptanceContains(text: String, target: String): Bool {
    let t = text.toRuneArray()
    let p = target.toRuneArray()
    if (p.size == 0) {
        return true
    }
    if (t.size < p.size) {
        return false
    }
    var i: Int64 = 0
    while (i <= t.size - p.size) {
        var matched = true
        var j: Int64 = 0
        while (j < p.size) {
            if (t[i + j] != p[j]) {
                matched = false
                break
            }
            j += 1
        }
        if (matched) {
            return true
        }
        i += 1
    }
    false
}

func chooseProxyAcceptancePort(offset: Int64): UInt16 {
    let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let raw = 60000 + ((nowMs + offset) % 4000)
    UInt16(raw)
}

func shutdownProxyAcceptanceApp(app: App, future: Future<Unit>): Unit {
    app.shutdown()
    try {
        let _ = future.get(Duration.second * 1)
    } catch (_: Exception) {
        future.cancel()
    }
}

class ProxyAcceptanceResponseSnapshot {
    let status: UInt16
    let bodyText: String
    let proxyRequestBodyMode: String
    let proxyRequestBodyBytes: String
    let proxyRequestBodyLimitBytes: String
    let proxyResponseBodyMode: String
    let proxyResponseBodyBytes: String
    let proxyDownstreamBodyMode: String
    let proxyDownstreamBodyBytes: String

    init(
        status: UInt16,
        bodyText: String,
        proxyRequestBodyMode: String,
        proxyRequestBodyBytes: String,
        proxyRequestBodyLimitBytes: String,
        proxyResponseBodyMode: String,
        proxyResponseBodyBytes: String,
        proxyDownstreamBodyMode: String,
        proxyDownstreamBodyBytes: String
    ) {
        this.status = status
        this.bodyText = bodyText
        this.proxyRequestBodyMode = proxyRequestBodyMode
        this.proxyRequestBodyBytes = proxyRequestBodyBytes
        this.proxyRequestBodyLimitBytes = proxyRequestBodyLimitBytes
        this.proxyResponseBodyMode = proxyResponseBodyMode
        this.proxyResponseBodyBytes = proxyResponseBodyBytes
        this.proxyDownstreamBodyMode = proxyDownstreamBodyMode
        this.proxyDownstreamBodyBytes = proxyDownstreamBodyBytes
    }
}
