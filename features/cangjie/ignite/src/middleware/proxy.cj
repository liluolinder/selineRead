package ignite.middleware

import ignite.{Handler, Ctx}
import stdx.net.http.{ClientBuilder, HttpHeaders, HttpRequestBuilder, HttpResponse}
import stdx.net.tls.TlsClientConfig
import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, OpenMode, Path, exists, removeIfExists}
import std.io.InputStream
import std.random.Random
import std.time.DateTime
import ignite.security as security

public let IGNITE_PROXY_REQUEST_BODY_MODE_LOCAL_KEY: String = "__ignite_proxy_request_body_mode"
public let IGNITE_PROXY_REQUEST_BODY_BYTES_LOCAL_KEY: String = "__ignite_proxy_request_body_bytes"
public let IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_LOCAL_KEY: String = "__ignite_proxy_request_body_limit_bytes"
public let IGNITE_PROXY_RESPONSE_BODY_MODE_LOCAL_KEY: String = "__ignite_proxy_response_body_mode"
public let IGNITE_PROXY_RESPONSE_BODY_BYTES_LOCAL_KEY: String = "__ignite_proxy_response_body_bytes"
public let IGNITE_PROXY_DOWNSTREAM_BODY_MODE_LOCAL_KEY: String = "__ignite_proxy_downstream_body_mode"
public let IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_LOCAL_KEY: String = "__ignite_proxy_downstream_body_bytes"
public let IGNITE_PROXY_REQUEST_BODY_MODE_HEADER: String = "x-ignite-proxy-request-body-mode"
public let IGNITE_PROXY_REQUEST_BODY_BYTES_HEADER: String = "x-ignite-proxy-request-body-bytes"
public let IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_HEADER: String = "x-ignite-proxy-request-body-limit-bytes"
public let IGNITE_PROXY_RESPONSE_BODY_MODE_HEADER: String = "x-ignite-proxy-response-body-mode"
public let IGNITE_PROXY_RESPONSE_BODY_BYTES_HEADER: String = "x-ignite-proxy-response-body-bytes"
public let IGNITE_PROXY_DOWNSTREAM_BODY_MODE_HEADER: String = "x-ignite-proxy-downstream-body-mode"
public let IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_HEADER: String = "x-ignite-proxy-downstream-body-bytes"

public class ProxyConfig {
    public var target: String
    public var pathRewrite: Array<(String, String)> = []
    public var timeout: Duration = Duration.second * 30
    public var x509Verify: ?security.X509VerifyOption = None
    public var tlsConfig: ?TlsClientConfig = None
    public var bufferUnknownLengthBodyToFile: Bool = false
    public var unknownLengthBodyTempDir: String = ""
    public var maxBufferedBodyBytes: Int64 = 0

    public init(target: String, pathRewrite!: Array<(String, String)> = [],
                timeout!: Duration = Duration.second * 30,
                x509Verify!: ?security.X509VerifyOption = None,
                tlsConfig!: ?TlsClientConfig = None,
                bufferUnknownLengthBodyToFile!: Bool = false,
                unknownLengthBodyTempDir!: String = "",
                maxBufferedBodyBytes!: Int64 = 0) {
        this.target = target
        this.pathRewrite = pathRewrite
        this.timeout = timeout
        if (let Some(option) <- x509Verify) {
            this.x509Verify = Some(option.copy())
        }
        this.tlsConfig = tlsConfig
        this.bufferUnknownLengthBodyToFile = bufferUnknownLengthBodyToFile
        this.unknownLengthBodyTempDir = normalizeProxyTempDir(unknownLengthBodyTempDir)
        this.maxBufferedBodyBytes = if (maxBufferedBodyBytes > 0) { maxBufferedBodyBytes } else { 0 }
    }
}

class ProxyBufferedBodyTooLargeException <: Exception {
    public let limitBytes: Int64
    public let attemptedBytes: Int64

    public init(limitBytes: Int64, attemptedBytes: Int64, message: String) {
        super(message)
        this.limitBytes = limitBytes
        this.attemptedBytes = attemptedBytes
    }
}

public func proxyMiddleware(config: ProxyConfig): Handler {
    let builder = ClientBuilder()
        .readTimeout(config.timeout)
        .writeTimeout(config.timeout)
    if (let Some(tc) <- config.tlsConfig) {
        builder.tlsConfig(tc)
    }
    let client = builder.build()

    { ctx: Ctx =>
        var targetPath = ctx.path
        for ((from, to) in config.pathRewrite) {
            if (strStartsWith(targetPath, from)) {
                targetPath = to + substringFrom(targetPath, from.size)
            }
        }

        let targetUrl = joinProxyTargetUrl(config.target, targetPath, extractQuerySuffix(ctx.originalUrl))
        try {
            if (let Some(option) <- config.x509Verify) {
                security.verifyX509Target(option, targetUrl, source: "ignite/proxy")
            }
            let reqBuilder = HttpRequestBuilder()
                .method(ctx.method)
                .url(targetUrl)
            let outboundHeaders = buildProxyRequestHeaders(ctx)
            let bodyAttachment = attachProxyRequestBody(reqBuilder, outboundHeaders, ctx, targetUrl, config)
            reqBuilder.addHeaders(outboundHeaders)

            try {
                let resp = client.send(reqBuilder.build())
                relayProxyResponse(ctx, resp)
            } finally {
                closeProxyRequestBodyAttachment(bodyAttachment)
            }
        } catch (e: ProxyBufferedBodyTooLargeException) {
            recordProxyRequestBodyMode(ctx, "temp-file-buffered-over-limit")
            recordProxyRequestBodyBytes(ctx, e.attemptedBytes)
            recordProxyRequestBodyLimitBytes(ctx, e.limitBytes)
            sendObservedProxyStringResponse(ctx, 413, "Payload Too Large: ${e.message}")
        } catch (e: security.SecurityException) {
            markSecurityContext(
                ctx,
                "cert_rejected",
                e.code.toString(),
                "proxy",
                "target=${targetUrl}"
            )
            sendObservedProxyStringResponse(ctx, 502, "Bad Gateway: ${e.message}")
        } catch (e: Exception) {
            sendObservedProxyStringResponse(ctx, 502, "Bad Gateway: ${e.message}")
        }
    }
}

public func proxyObserveHeaderMiddleware(): Handler {
    { ctx: Ctx =>
        ctx.next()
        emitProxyObserveHeader(ctx, IGNITE_PROXY_REQUEST_BODY_MODE_LOCAL_KEY, IGNITE_PROXY_REQUEST_BODY_MODE_HEADER)
        emitProxyObserveHeader(ctx, IGNITE_PROXY_REQUEST_BODY_BYTES_LOCAL_KEY, IGNITE_PROXY_REQUEST_BODY_BYTES_HEADER)
        emitProxyObserveHeader(
            ctx,
            IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_LOCAL_KEY,
            IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_HEADER
        )
        emitProxyObserveHeader(ctx, IGNITE_PROXY_RESPONSE_BODY_MODE_LOCAL_KEY, IGNITE_PROXY_RESPONSE_BODY_MODE_HEADER)
        emitProxyObserveHeader(ctx, IGNITE_PROXY_RESPONSE_BODY_BYTES_LOCAL_KEY, IGNITE_PROXY_RESPONSE_BODY_BYTES_HEADER)
        emitProxyObserveHeader(ctx, IGNITE_PROXY_DOWNSTREAM_BODY_MODE_LOCAL_KEY, IGNITE_PROXY_DOWNSTREAM_BODY_MODE_HEADER)
        emitProxyObserveHeader(ctx, IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_LOCAL_KEY, IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_HEADER)
    }
}

func buildProxyRequestHeaders(ctx: Ctx): HttpHeaders {
    let carrier = ctx.currentRequestCarrier()
    let headers = HttpHeaders()
    let requestHeaders = carrier.requestHeaders()
    let connectionTokens = parseConnectionHeaderTokens(requestHeaders)
    for ((name, values) in requestHeaders) {
        if (shouldSkipProxyRequestHeader(name, connectionTokens)) {
            continue
        }
        for (value in values) {
            headers.add(name, value)
        }
    }

    headers.add("x-forwarded-for", appendForwardedFor(ctx.header("x-forwarded-for") ?? "", ctx.ip))
    let host = ctx.header("host") ?? ""
    if (host.trimAscii().size > 0) {
        headers.add("x-forwarded-host", host)
    }
    if (let Some(proto) <- ctx.header("x-forwarded-proto")) {
        if (proto.trimAscii().size > 0) {
            headers.add("x-forwarded-proto", proto)
        }
    }
    headers
}

func attachProxyRequestBody(
    reqBuilder: HttpRequestBuilder,
    headers: HttpHeaders,
    ctx: Ctx,
    targetUrl: String,
    config: ProxyConfig
): ?ProxyRequestBodyAttachment {
    if (let Some(cached) <- ctx.cachedBodyBytes()) {
        if (cached.size > 0 || shouldForwardRequestBody(ctx)) {
            recordProxyRequestBodyMode(ctx, "cached-body")
            recordProxyRequestBodyBytes(ctx, cached.size)
            headers.add("content-length", cached.size.toString())
            reqBuilder.body(cached)
        } else {
            recordProxyRequestBodyMode(ctx, "skipped")
        }
        return None
    }

    let carrier = ctx.currentRequestCarrier()
    match (carrier.requestBodySize()) {
        case Some(size) =>
            if (size > 0 || shouldForwardRequestBody(ctx)) {
                recordProxyRequestBodyMode(ctx, "known-length-stream")
                recordProxyRequestBodyBytes(ctx, size)
                headers.add("content-length", size.toString())
                reqBuilder.body(carrier.requestBodyStream())
            } else {
                recordProxyRequestBodyMode(ctx, "skipped")
            }
            return None
        case None =>
            if (!shouldForwardRequestBody(ctx)) {
                recordProxyRequestBodyMode(ctx, "skipped")
                return None
            }
            if (shouldProxyBufferUnknownLengthBodyToFile(targetUrl, config)) {
                return attachBufferedProxyRequestBody(reqBuilder, headers, ctx, config)
            }
            if (proxyTargetScheme(targetUrl) == "http") {
                recordProxyRequestBodyMode(ctx, "chunked-stream")
                headers.add("transfer-encoding", "chunked")
                reqBuilder.body(carrier.requestBodyStream())
            } else {
                let buffered = ctx.bodyBytes()
                recordProxyRequestBodyMode(ctx, "memory-buffered")
                recordProxyRequestBodyBytes(ctx, buffered.size)
                headers.add("content-length", buffered.size.toString())
                reqBuilder.body(buffered)
            }
            None
    }
}

class ProxyRequestBodyAttachment {
    public let replayFile: ?File
    public let tempPath: String

    public init(replayFile!: ?File = None, tempPath!: String = "") {
        this.replayFile = replayFile
        this.tempPath = tempPath
    }
}

func attachBufferedProxyRequestBody(
    reqBuilder: HttpRequestBuilder,
    headers: HttpHeaders,
    ctx: Ctx,
    config: ProxyConfig
): ProxyRequestBodyAttachment {
    let tempPath = buildProxyTempBodyPath(config.unknownLengthBodyTempDir)
    let saved = streamProxyBufferedRequestBodyToFile(
        ctx.requestBody(),
        tempPath,
        config.maxBufferedBodyBytes
    )
    recordProxyRequestBodyMode(ctx, "temp-file-buffered")
    recordProxyRequestBodyBytes(ctx, saved)
    headers.add("content-length", saved.toString())
    let replayFile = File(tempPath, OpenMode.Read)
    reqBuilder.body(replayFile)
    ProxyRequestBodyAttachment(replayFile: replayFile, tempPath: tempPath)
}

func streamProxyBufferedRequestBodyToFile(
    stream: InputStream,
    destPath: String,
    maxBytes: Int64
): Int64 {
    let file = File(destPath, OpenMode.Write)
    let buf = Array<UInt8>(8192, repeat: 0)
    var total: Int64 = 0
    var completed = false
    try {
        while (true) {
            let n = stream.read(buf)
            if (n <= 0) {
                completed = true
                break
            }
            let nextTotal = total + n
            if (maxBytes > 0 && nextTotal > maxBytes) {
                throw ProxyBufferedBodyTooLargeException(
                    maxBytes,
                    nextTotal,
                    "proxy buffered request body exceeds limit=${maxBytes}"
                )
            }
            file.write(buf[..n])
            total = nextTotal
        }
    } finally {
        try {
            file.close()
        } catch (_: Exception) { }
        if (!completed) {
            try {
                removeIfExists(destPath)
            } catch (_: Exception) { }
        }
    }
    total
}

func closeProxyRequestBodyAttachment(attachment: ?ProxyRequestBodyAttachment): Unit {
    if (let Some(state) <- attachment) {
        if (let Some(file) <- state.replayFile) {
            try {
                file.close()
            } catch (_: Exception) { }
        }
        if (state.tempPath.trimAscii().size > 0) {
            try {
                removeIfExists(state.tempPath)
            } catch (_: Exception) { }
        }
    }
}

func recordProxyRequestBodyMode(ctx: Ctx, mode: String): Unit {
    ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_MODE_LOCAL_KEY, mode)
}

func recordProxyRequestBodyBytes(ctx: Ctx, bytes: Int64): Unit {
    ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_BYTES_LOCAL_KEY, bytes.toString())
}

func recordProxyRequestBodyLimitBytes(ctx: Ctx, limitBytes: Int64): Unit {
    ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_LOCAL_KEY, limitBytes.toString())
}

func recordProxyResponseBodyMode(ctx: Ctx, mode: String): Unit {
    ctx.setLocal(IGNITE_PROXY_RESPONSE_BODY_MODE_LOCAL_KEY, mode)
}

func recordProxyResponseBodyBytes(ctx: Ctx, bytes: Int64): Unit {
    ctx.setLocal(IGNITE_PROXY_RESPONSE_BODY_BYTES_LOCAL_KEY, bytes.toString())
}

func recordProxyDownstreamBodyMode(ctx: Ctx, mode: String): Unit {
    ctx.setLocal(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_LOCAL_KEY, mode)
}

func recordProxyDownstreamBodyBytes(ctx: Ctx, bytes: Int64): Unit {
    ctx.setLocal(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_LOCAL_KEY, bytes.toString())
}

func sendObservedProxyStringResponse(ctx: Ctx, status: UInt16, body: String): Unit {
    let size = body.toArray().size
    recordProxyResponseBodyMode(ctx, "known-length-stream")
    recordProxyResponseBodyBytes(ctx, size)
    recordProxyDownstreamBodyMode(ctx, "known-length-stream")
    recordProxyDownstreamBodyBytes(ctx, size)
    ctx.status(status).sendString(body)
}

func emitProxyObserveHeader(ctx: Ctx, localKey: String, headerName: String): Unit {
    let value = ctx.getLocal(localKey) ?? ""
    if (value.trimAscii().size == 0) {
        return
    }
    let _ = ctx.setHeader(headerName, value)
}

func shouldProxyBufferUnknownLengthBodyToFile(targetUrl: String, config: ProxyConfig): Bool {
    if (config.bufferUnknownLengthBodyToFile) {
        return true
    }
    proxyTargetScheme(targetUrl) != "http"
}

func buildProxyTempBodyPath(baseDir: String): String {
    let normalizedDir = normalizeProxyTempDir(baseDir)
    ensureProxyTempDirExists(normalizedDir)
    let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let rng = Random()
    var suffix = ""
    let hex = "0123456789abcdef".toRuneArray()
    var i: Int64 = 0
    while (i < 12) {
        suffix += hex[Int64(rng.nextUInt64() % 16)].toString()
        i += 1
    }
    Path(normalizedDir).join("ignite-proxy-body-${nowMs}-${suffix}.tmp").toString()
}

func ensureProxyTempDirExists(path: String): Unit {
    var attempt: Int64 = 0
    while (attempt < 4) {
        try {
            Directory.create(path, recursive: true)
            return
        } catch (e: Exception) {
            if (exists(path)) {
                return
            }
            if (attempt == 3) {
                throw e
            }
            sleep(Duration.millisecond * 5)
            attempt += 1
        }
    }
}

func normalizeProxyTempDir(path: String): String {
    let trimmed = path.trimAscii()
    if (trimmed.size == 0) {
        return detectDefaultProxyTempDir()
    }
    trimmed
}

func detectDefaultProxyTempDir(): String {
    let keys = ["TMPDIR", "TEMP", "TMP"]
    for (key in keys) {
        if (let Some(value) <- getVariable(key)) {
            let trimmed = value.trimAscii()
            if (trimmed.size > 0) {
                return trimmed
            }
        }
    }
    "/tmp"
}

func relayProxyResponse(ctx: Ctx, resp: HttpResponse): Unit {
    let carrier = ctx.currentRequestCarrier()
    observeProxyResponseBody(ctx, resp)
    observeProxyDownstreamBody(ctx, resp)
    _ = ctx.status(resp.status)
    carrier.addResponseHeaders(buildProxyResponseHeaders(ctx, resp))
    if (proxyResponseMustBeBodyless(ctx.method, resp.status)) {
        return
    }
    carrier.attachResponseBodyStream(resp.body)
}

func observeProxyResponseBody(ctx: Ctx, resp: HttpResponse): Unit {
    if (proxyResponseMustBeBodyless(ctx.method, resp.status)) {
        recordProxyResponseBodyMode(ctx, "bodyless")
        recordProxyResponseBodyBytes(ctx, 0)
        return
    }

    match (resp.bodySize) {
        case Some(size) =>
            recordProxyResponseBodyMode(ctx, "known-length-stream")
            recordProxyResponseBodyBytes(ctx, size)
        case None =>
            recordProxyResponseBodyMode(ctx, "unknown-length-stream")
    }
}

func observeProxyDownstreamBody(ctx: Ctx, resp: HttpResponse): Unit {
    if (proxyResponseMustBeBodyless(ctx.method, resp.status)) {
        recordProxyDownstreamBodyMode(ctx, "bodyless")
        recordProxyDownstreamBodyBytes(ctx, 0)
        return
    }

    match (resp.bodySize) {
        case Some(size) =>
            recordProxyDownstreamBodyMode(ctx, "known-length-stream")
            recordProxyDownstreamBodyBytes(ctx, size)
        case None =>
            if (isHttp2Protocol(ctx.protocol)) {
                recordProxyDownstreamBodyMode(ctx, "h2-data-stream")
            } else {
                recordProxyDownstreamBodyMode(ctx, "http11-chunked")
            }
    }
}

func buildProxyResponseHeaders(ctx: Ctx, resp: HttpResponse): HttpHeaders {
    let headers = HttpHeaders()
    let connectionTokens = parseConnectionHeaderTokens(resp.headers)
    for ((name, values) in resp.headers) {
        if (shouldSkipProxyResponseHeader(name, connectionTokens)) {
            continue
        }
        for (value in values) {
            headers.add(name, value)
        }
    }

    if (proxyResponseMustBeBodyless(ctx.method, resp.status)) {
        if (let Some(contentLength) <- resp.headers.getFirst("content-length")) {
            if (contentLength.trimAscii().size > 0) {
                headers.add("content-length", contentLength)
            }
        }
        return headers
    }

    match (resp.bodySize) {
        case Some(size) =>
            headers.add("content-length", size.toString())
        case None =>
            if (!isHttp2Protocol(ctx.protocol)) {
                headers.add("transfer-encoding", "chunked")
            }
    }
    headers
}

func shouldForwardRequestBody(ctx: Ctx): Bool {
    if ((ctx.header("content-length") ?? "").trimAscii().size > 0) {
        return true
    }
    if ((ctx.header("transfer-encoding") ?? "").trimAscii().size > 0) {
        return true
    }
    let method = ctx.method.trimAscii().toAsciiUpper()
    method == "POST" || method == "PUT" || method == "PATCH" || method == "DELETE"
}

func shouldSkipProxyRequestHeader(name: String, connectionTokens: ArrayList<String>): Bool {
    let normalized = name.trimAscii().toAsciiLower()
    if (normalized == "host" || normalized == "connection" || normalized == "keep-alive" ||
        normalized == "proxy-authenticate" || normalized == "proxy-authorization" ||
        normalized == "te" || normalized == "trailer" || normalized == "upgrade" ||
        normalized == "proxy-connection" || normalized == "content-length" ||
        normalized == "transfer-encoding" || normalized == "x-forwarded-for" ||
        normalized == "x-forwarded-host" || normalized == "x-forwarded-proto") {
        return true
    }
    containsHeaderName(connectionTokens, normalized)
}

func shouldSkipProxyResponseHeader(name: String, connectionTokens: ArrayList<String>): Bool {
    let normalized = name.trimAscii().toAsciiLower()
    if (normalized == "connection" || normalized == "keep-alive" ||
        normalized == "proxy-authenticate" || normalized == "proxy-authorization" ||
        normalized == "te" || normalized == "trailer" || normalized == "upgrade" ||
        normalized == "proxy-connection" || normalized == "content-length" ||
        normalized == "transfer-encoding") {
        return true
    }
    containsHeaderName(connectionTokens, normalized)
}

func parseConnectionHeaderTokens(headers: HttpHeaders): ArrayList<String> {
    let tokens = ArrayList<String>()
    for (value in headers.get("connection")) {
        for (part in value.split(",")) {
            let token = part.trimAscii().toAsciiLower()
            if (token.size == 0) {
                continue
            }
            if (!containsHeaderName(tokens, token)) {
                tokens.add(token)
            }
        }
    }
    tokens
}

func containsHeaderName(values: ArrayList<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    false
}

func appendForwardedFor(existing: String, ip: String): String {
    let normalizedExisting = existing.trimAscii()
    let normalizedIp = ip.trimAscii()
    if (normalizedExisting.size == 0) {
        return normalizedIp
    }
    if (normalizedIp.size == 0) {
        return normalizedExisting
    }
    normalizedExisting + ", " + normalizedIp
}

func joinProxyTargetUrl(baseTarget: String, targetPath: String, querySuffix: String): String {
    let base = trimTrailingSlashProxy(baseTarget.trimAscii())
    let path = ensureLeadingSlashProxy(targetPath)
    base + path + querySuffix
}

func trimTrailingSlashProxy(text: String): String {
    let runes = text.toRuneArray()
    if (runes.size == 0) {
        return text
    }
    var end = runes.size
    while (end > 0 && runes[end - 1] == r'/') {
        end -= 1
    }
    if (end == 0) {
        return ""
    }
    var out = ""
    var i: Int64 = 0
    while (i < end) {
        out += runes[i].toString()
        i += 1
    }
    out
}

func ensureLeadingSlashProxy(text: String): String {
    let trimmed = text.trimAscii()
    if (trimmed.size == 0) {
        return "/"
    }
    let runes = trimmed.toRuneArray()
    if (runes[0] == r'/') {
        return trimmed
    }
    "/" + trimmed
}

func extractQuerySuffix(rawUrl: String): String {
    let runes = rawUrl.toRuneArray()
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'?') {
            var out = ""
            while (i < runes.size) {
                out += runes[i].toString()
                i += 1
            }
            return out
        }
        i += 1
    }
    ""
}

func proxyTargetScheme(targetUrl: String): String {
    let normalized = targetUrl.trimAscii().toAsciiLower()
    if (strStartsWith(normalized, "https://")) {
        return "https"
    }
    if (strStartsWith(normalized, "http://")) {
        return "http"
    }
    "unknown"
}

func proxyResponseMustBeBodyless(method: String, status: UInt16): Bool {
    let normalizedMethod = method.trimAscii().toAsciiUpper()
    if (normalizedMethod == "HEAD") {
        return true
    }
    let code = Int64(status)
    (code >= 100 && code < 200) || status == 204 || status == 304
}

func isHttp2Protocol(protocol: String): Bool {
    let text = protocol.trimAscii().toAsciiLower()
    if (text.size == 0) {
        return false
    }
    if (text == "h2" || text == "h2c") {
        return true
    }
    proxyContainsText(text, "http/2") || proxyContainsText(text, "http2")
}

func proxyContainsText(text: String, pattern: String): Bool {
    let a = text.toRuneArray()
    let b = pattern.toRuneArray()
    if (b.size == 0) {
        return true
    }
    if (a.size < b.size) {
        return false
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
            return true
        }
        i += 1
    }
    false
}
