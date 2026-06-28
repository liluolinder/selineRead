package ignite

import std.collection.{ArrayList, HashMap}
import std.io.{InputStream}
import std.fs.{exists, File, FileInfo, OpenMode, removeIfExists}
import std.unicode.*
import ignite.security
import stdx.net.http.HttpContext
import stdx.encoding.json.JsonValue
import stdx.encoding.json.stream.{
    JsonWriter as StdxJsonWriter,
    JsonReader as StdxJsonReader
}

public class BufferedRequestBodyTooLargeException <: Exception {
    public let limitBytes: Int64
    public let attemptedBytes: Int64

    public init(limitBytes: Int64, attemptedBytes: Int64, message: String) {
        super(message)
        this.limitBytes = limitBytes
        this.attemptedBytes = attemptedBytes
    }
}

class LimitedRequestBodyInputStream <: InputStream & Resource {
    let _upstream: InputStream
    let _limitBytes: Int64
    var _consumedBytes: Int64 = 0
    var _closed: Bool = false

    init(upstream: InputStream, limitBytes: Int64) {
        this._upstream = upstream
        this._limitBytes = limitBytes
    }

    public override func read(outBuf: Array<Byte>): Int64 {
        if (_closed || outBuf.size == 0) {
            return 0
        }
        let readLen = _upstream.read(outBuf)
        if (readLen <= 0) {
            close()
            return readLen
        }
        if (_limitBytes > 0) {
            let attemptedBytes = _consumedBytes + readLen
            if (attemptedBytes > _limitBytes) {
                close()
                throw BufferedRequestBodyTooLargeException(
                    _limitBytes,
                    attemptedBytes,
                    "request body read ${attemptedBytes} bytes which exceeds limit ${_limitBytes}"
                )
            }
        }
        _consumedBytes += readLen
        readLen
    }

    public func close(): Unit {
        if (_closed) {
            return
        }
        _closed = true
        closeStreamIfResource(_upstream)
    }

    public func isClosed(): Bool {
        _closed
    }
}

class CachedRequestBodyReplayInputStream <: InputStream & Resource {
    let _bytes: Array<Byte>
    var _cursor: Int64 = 0
    var _closed: Bool = false

    init(bytes: Array<Byte>) {
        this._bytes = bytes
    }

    public override func read(outBuf: Array<Byte>): Int64 {
        if (_closed || outBuf.size == 0 || _cursor >= _bytes.size) {
            return 0
        }
        let remaining = _bytes.size - _cursor
        let readLen = if (remaining < outBuf.size) { remaining } else { outBuf.size }
        var i: Int64 = 0
        while (i < readLen) {
            outBuf[i] = _bytes[_cursor + i]
            i += 1
        }
        _cursor += readLen
        readLen
    }

    public func close(): Unit {
        _closed = true
    }

    public func isClosed(): Bool {
        _closed
    }
}

public class Ctx {
    let _currentRequestCarrier: CurrentRequestCarrier
    let _app: App
    var _params: HashMap<String, String> = HashMap<String, String>()
    var _responseHeaders: HashMap<String, String> = HashMap<String, String>()
    var _locals: HashMap<String, String> = HashMap<String, String>()
    var _localValues: HashMap<String, Any> = HashMap<String, Any>()
    var _route: ?Route = None
    var _handlers: ArrayList<Handler> = ArrayList<Handler>()
    var _handlerIndex: Int64 = -1
    var _responded: Bool = false
    var _statusCode: UInt16 = 200
    var _bodyBytesCache: ?Array<UInt8> = None
    var _requestBodyStreamCache: ?InputStream = None
    var _multipartForm: ?MultipartForm = None
    var _responseBody: ?String = None
    var _pathOverride: ?String = None

    public init(currentRequestCarrier: CurrentRequestCarrier, app: App) {
        this._currentRequestCarrier = currentRequestCarrier
        this._app = app
    }

    // ── Request accessors ──

    public prop method: String {
        get() { _currentRequestCarrier.requestMethod() }
    }

    public prop path: String {
        get() {
            match (_pathOverride) {
                case Some(path) => path
                case None => _currentRequestCarrier.requestPath()
            }
        }
    }

    public prop originalUrl: String {
        get() { _currentRequestCarrier.requestUrlString() }
    }

    public prop protocol: String {
        get() { _currentRequestCarrier.requestVersionString() }
    }

    public prop ip: String {
        get() { _currentRequestCarrier.requestRemoteAddr() }
    }

    public func params(key: String): String {
        _params.get(key) ?? ""
    }

    public func paramsOpt(key: String): ?String {
        _params.get(key)
    }

    public func query(key: String): ?String {
        if (let urlQueryVal <- _currentRequestCarrier.requestQueryValue(key)) {
            return urlQueryVal
        }
        if (let formVal <- _currentRequestCarrier.requestFormValue(key)) {
            return formVal
        }
        None
    }

    public func queryDefault(key: String, defaultVal: String): String {
        query(key) ?? defaultVal
    }

    public func queryFromUrl(key: String): ?String {
        _currentRequestCarrier.requestQueryValue(key)
    }

    public func queryFromForm(key: String): ?String {
        _currentRequestCarrier.requestFormValue(key)
    }

    public func header(key: String): ?String {
        _currentRequestCarrier.requestHeaderValue(key)
    }

    public func requestBody(): InputStream {
        if (let Some(cached) <- _bodyBytesCache) {
            return CachedRequestBodyReplayInputStream(toRequestBodyReplayByteArray(cached))
        }
        if (let Some(stream) <- _requestBodyStreamCache) {
            return stream
        }
        let stream = LimitedRequestBodyInputStream(
            _currentRequestCarrier.requestBodyStream(),
            _app.config.bodyLimit
        )
        _requestBodyStreamCache = Some(stream)
        stream
    }

    /// Returns a `JsonReader` backed by `requestBody()`.
    ///
    /// This is a streamed intake seam: unlike `bodyString()/JsonValue`, it does
    /// not full-buffer the request body. The caller reads JSON tokens directly
    /// from the underlying `InputStream`. Because the backing stream is
    /// `requestBody()`, the current `config.bodyLimit` contract applies: reading
    /// beyond `bodyLimit` bytes throws `BufferedRequestBodyTooLargeException`.
    ///
    /// If the body was already buffered through `bodyBytes()/bodyString()`,
    /// the reader replays from that cached full body. If the request has
    /// already been consumed through the stream path first, later buffered
    /// reads only see the unread remainder and no broader replay is promised.
    ///
    /// The returned reader reads the first top-level JSON value from the stream.
    /// For typed deserialization via `JsonDeserializable`, callers may use:
    ///
    /// ```text
    /// let reader = ctx.requestJsonReader()
    /// let value = SomeType.fromJson(reader)
    /// ```
    ///
    /// This is deliberately a low-level seam. It does not replace
    /// `bindJsonOr400(...)` - that method continues to use the full-buffer
    /// `bodyString()/JsonValue` path.
    public func requestJsonReader(): JsonReader {
        StdxJsonReader(requestBody())
    }

    public func saveBodyToFile(destPath: String): Int64 {
        if (let Some(cached) <- _bodyBytesCache) {
            writeBytesToFile(destPath, cached)
            return cached.size
        }
        streamRequestBodyToFile(requestBody(), destPath)
    }

    public func cachedBodyBytes(): ?Array<UInt8> {
        _bodyBytesCache
    }

    public func bodyBytes(): Array<UInt8> {
        if (let Some(cached) <- _bodyBytesCache) {
            return cached
        }
        let stream = requestBody()
        let buf = ArrayList<UInt8>()
        let tmp = Array<UInt8>(4096, repeat: 0)
        try {
            while (true) {
                let n = stream.read(tmp)
                if (n <= 0) { break }
                for (i in 0..n) {
                    buf.add(tmp[i])
                }
            }
        } catch (e: BufferedRequestBodyTooLargeException) {
            throw BufferedRequestBodyTooLargeException(
                e.limitBytes,
                e.attemptedBytes,
                "request body buffered ${e.attemptedBytes} bytes which exceeds limit ${e.limitBytes}"
            )
        }
        let bytes = buf.toArray()
        _bodyBytesCache = bytes
        bytes
    }

    public func bodyString(): String {
        String.fromUtf8(bodyBytes())
    }

    public func cookies(name: String): ?String {
        match (_locals.get("__ignite_cookie_dec_${name}")) {
            case Some(v) => return Some(v)
            case None => ()
        }
        let cookieHeaderOpt = header("cookie")
        if (let Some(cookieHeader) <- cookieHeaderOpt) {
            let parts = cookieHeader.split(";")
            for (part in parts) {
                let trimmed = part.trimAscii()
                let kv = trimmed.split("=", 2)
                if (kv.size == 2) {
                    let cName = kv[0].trimAscii()
                    let cVal = kv[1].trimAscii()
                    if (cName == name) {
                        return cVal
                    }
                }
            }
        }
        None
    }

    // ── Form data (urlencoded + multipart) ──

    public func formValue(key: String): ?String {
        let queryVal = query(key)
        if (let Some(v) <- queryVal) {
            return v
        }
        let ct = header("content-type") ?? ""
        if (containsStr(ct.toLower(), "multipart")) {
            return multipartForm().value(key)
        }
        None
    }

    public func multipartForm(): MultipartForm {
        if (let Some(form) <- _multipartForm) {
            return form
        }
        let contentType = header("content-type") ?? ""
        let bytes = bodyBytes()
        let form = parseMultipartForm(bytes, contentType)
        _multipartForm = form
        form
    }

    public func formFile(name: String): ?FormFile {
        multipartForm().file(name)
    }

    public func formFiles(name: String): ArrayList<FormFile> {
        multipartForm().files(name)
    }

    public func saveFile(file: FormFile, destPath: String): Unit {
        saveFormFile(file, destPath)
    }

    // ── Response methods ──

    public func status(code: UInt16): Ctx {
        _currentRequestCarrier.setResponseStatus(code)
        _statusCode = code
        this
    }

    public func setHeader(key: String, value: String): Ctx {
        setResponseHeaderTracked(key, value)
        this
    }

    public func json(body: String): Ctx {
        setResponseHeaderTracked("content-type", "application/json; charset=utf-8")
        _currentRequestCarrier.setResponseString(body)
        _responded = true
        _responseBody = body
        this
    }

    public func sendString(body: String): Ctx {
        setResponseHeaderTracked("content-type", "text/plain; charset=utf-8")
        _currentRequestCarrier.setResponseString(body)
        _responded = true
        _responseBody = body
        this
    }

    public func html(body: String): Ctx {
        setResponseHeaderTracked("content-type", "text/html; charset=utf-8")
        _currentRequestCarrier.setResponseString(body)
        _responded = true
        _responseBody = body
        this
    }

    public func send(data: Array<UInt8>): Ctx {
        _currentRequestCarrier.setResponseBytes(data)
        _responded = true
        this
    }

    public func sendStream(
        stream: InputStream,
        contentType!: String = "application/octet-stream",
        contentLength!: ?Int64 = None
    ): Ctx {
        var effectiveStream = stream
        var effectiveContentLength = contentLength
        let headRequest = isHeadRequest(method)
        let http2Request = isHttp2Protocol(protocol)
        let normalizedType = contentType.trimAscii()
        if (normalizedType.size > 0) {
            setResponseHeaderTracked("content-type", normalizedType)
        }
        if (let Some(plan) <- currentStreamCompressionPlan(this, contentLength)) {
            effectiveStream = wrapStreamWithCompressionPlan(stream, plan)
            effectiveContentLength = None
            if (plan.setVaryHeader) {
                let existingVary = responseHeader("vary") ?? ""
                let mergedVary = mergeVaryAcceptEncoding(existingVary)
                if (mergedVary != existingVary.trimAscii()) {
                    if (existingVary.trimAscii().size == 0) {
                        setResponseHeaderTracked("vary", mergedVary)
                    } else {
                        rememberResponseHeader("vary", mergedVary)
                        _currentRequestCarrier.setResponseHeader("vary", "Accept-Encoding")
                    }
                }
            }
            setResponseHeaderTracked("content-encoding", plan.encoding)
        }
        match (effectiveContentLength) {
            case Some(size) =>
                if (size >= 0) {
                    setResponseHeaderTracked("content-length", size.toString())
                }
            case None =>
                if (!headRequest && !http2Request) {
                    setResponseHeaderTracked("transfer-encoding", "chunked")
                }
        }
        if (!headRequest) {
            _currentRequestCarrier.attachResponseBodyStream(effectiveStream)
        } else {
            closeStreamIfResource(effectiveStream)
        }
        _responded = true
        this
    }

    /// Stream a JSON payload through a `JsonWriter` callback.
    ///
    /// The callback receives a `JsonWriter` backed by Ignite's current
    /// response transport writer seam. On HTTP/1.x this path is chunked by default; on
    /// HTTP/2 each write becomes a corresponding data segment.
    ///
    /// **Known middleware limitation**: Unlike `ctx.json(...)`, this method
    /// does **not** set `ctx.responseBody`. Middleware that depends on a
    /// fully-buffered response body (`etag`, `cache`, `idempotency`) remains
    /// unpromised for this streaming path. When a stream compression plan is
    /// currently applicable, `jsonWrite(...)` delegates to `jsonStream(...)`
    /// so the accepted streamed-compress subset can be reused.
    ///
    /// For `HEAD` requests the callback is not invoked and no body is sent.
    public func jsonWrite(writerFn: (JsonWriter) -> Unit): Ctx {
        setResponseHeaderTracked("content-type", "application/json; charset=utf-8")
        // When a stream compression plan is registered (e.g. by compressMiddleware),
        // delegate to jsonStream(...) so the existing sendStream-compress seam applies.
        // Without a plan the existing direct-writer path is unchanged.
        if (let Some(_) <- currentStreamCompressionPlan(this, None)) {
            return jsonStream(writerFn)
        }
        let headRequest = isHeadRequest(method)
        let http2Request = isHttp2Protocol(protocol)
        if (!headRequest && !http2Request) {
            setResponseHeaderTracked("transfer-encoding", "chunked")
        }
        setLocal("__ignite_response_kind", "json-stream")
        if (!headRequest) {
            let transportWriter = openResponseTransportWriter(_currentRequestCarrier)
            let out = ResponseTransportOutputStream(transportWriter)
            writeJsonCallbackThroughSeaJsonBridge(out, writerFn)
        }
        _responded = true
        // Intentionally NOT setting _responseBody — this is the streamed path,
        // and middleware depending on a buffered body is unpromised.
        this
    }

    /// Stream a JSON payload through the accepted `JsonWriterInputStream` bridge seam.
    ///
    /// Unlike `jsonWrite(...)`, this method does not write directly into the
    /// response transport writer. It wraps the callback in
    /// `JsonWriterInputStream` and reuses `sendStream(...)`.
    ///
    /// Provide `contentLength` when the final JSON size is known. Otherwise
    /// HTTP/1.x falls back to chunked transfer encoding.
    ///
    /// **Known middleware limitation**: This method does **not** set
    /// `ctx.responseBody`. Middleware that depends on a fully-buffered response
    /// body (`compress`, `etag`, `cache`, `idempotency`) is **not compatible**
    /// with this streaming path.
    ///
    /// For `HEAD` requests the callback is not invoked and no body is sent.
    /// If a caller needs a custom bridge buffer limit, instantiate
    /// `JsonWriterInputStream` directly and call `sendStream(...)`.
    public func jsonStream(
        writerFn: (JsonWriter) -> Unit,
        contentLength!: ?Int64 = None
    ): Ctx {
        setLocal("__ignite_response_kind", "json-stream")
        let stream = JsonWriterInputStream(writerFn)
        sendStream(
            stream,
            contentType: "application/json; charset=utf-8",
            contentLength: contentLength
        )
    }

    /// Stream a `JsonSerializable` payload through the accepted `jsonStream(...)` seam.
    ///
    /// Unlike `jsonSerialize(...)`, this method does not full-buffer through
    /// `serializeJson(...) -> String`. It keeps typed callers on the accepted
    /// stream bridge path and therefore inherits the same current middleware and
    /// H2/TLS non-promises as `jsonStream(...)`.
    public func jsonSerializeStream<T>(
        obj: T,
        contentLength!: ?Int64 = None
    ): Ctx where T <: JsonSerializable {
        jsonStream({ jw =>
            writeJsonSerializableThroughSeaJsonBridge(jw, obj)
        }, contentLength: contentLength)
    }

    /// Stream a `JsonWriterEncodable` payload through the accepted `sendStream(...)` seam.
    ///
    /// Unlike `jsonEncode(...)`, this method does not resolve through the current
    /// `JsonEncoder -> String` contract and therefore does not consult
    /// `Config.jsonEncoder`. Callers must provide the exact streamed wire shape via
    /// the SeaJson writer-facing twin.
    ///
    /// This path inherits the same current middleware and H2/TLS non-promises as
    /// `jsonStream(...)`.
    public func jsonEncodeStream(
        obj: JsonWriterEncodable,
        contentLength!: ?Int64 = None
    ): Ctx {
        setLocal("__ignite_response_kind", "json-stream")
        let stream = JsonWriterInputStream(outputProducer: { out =>
            writeJsonWriterEncodableThroughSeaJsonBridge(out, obj)
        })
        sendStream(
            stream,
            contentType: "application/json; charset=utf-8",
            contentLength: contentLength
        )
    }

    public func sendStatus(code: UInt16): Ctx {
        let msg = statusMessage(code)
        _currentRequestCarrier.setResponseStatus(code)
        _currentRequestCarrier.setResponseString(msg)
        _statusCode = code
        _responded = true
        _responseBody = msg
        this
    }

    public func redirect(url: String, code!: UInt16 = 302): Ctx {
        _currentRequestCarrier.setResponseStatus(code)
        setResponseHeaderTracked("location", url)
        _currentRequestCarrier.setResponseString("")
        _statusCode = code
        _responded = true
        this
    }

    public func setCookie(name: String, value: String, maxAge!: Int64 = 0, path!: String = "/",
                          domain!: String = "", httpOnly!: Bool = false, secure!: Bool = false,
                          sameSite!: String = ""): Ctx {
        let cookieValue = tryEncryptCookieValue(name, value)
        var cookieStr = "${name}=${cookieValue}"
        if (maxAge > 0) {
            cookieStr += "; Max-Age=${maxAge}"
        }
        cookieStr += "; Path=${path}"
        if (domain.size > 0) {
            cookieStr += "; Domain=${domain}"
        }
        if (httpOnly) {
            cookieStr += "; HttpOnly"
        }
        if (secure) {
            cookieStr += "; Secure"
        }
        let normalizedSameSite = sameSite.trimAscii()
        if (normalizedSameSite.size > 0) {
            cookieStr += "; SameSite=${normalizedSameSite}"
        }
        setResponseHeaderTracked("set-cookie", cookieStr)
        this
    }

    public func noContent(): Ctx {
        _currentRequestCarrier.setResponseStatus(204)
        _statusCode = 204
        _responded = true
        this
    }

    // ── JSON serialization ──

    public func jsonSerialize<T>(obj: T): Ctx where T <: JsonSerializable {
        let jsonStr = serializeJson<T>(obj)
        json(jsonStr)
    }

    public func jsonEncode(obj: JsonEncodable): Ctx {
        let jsonStr = if (let Some(encoder) <- _app.config.jsonEncoder) {
            encoder(obj)
        } else {
            defaultJsonEncoder(obj)
        }
        json(jsonStr)
    }

    /// 解析请求 JSON；失败时返回 400，错误体：
    /// {"error":"bad_request","reason":"invalid_json","message":"..."}
    /// decoder 或 validate 抛错时同样返回 400（reason 分别为 invalid_payload / validation_failed）。
    public func bindJsonOr400<T>(
        decoder: (JsonValue) -> T,
        validate!: ?(T) -> ?String = None
    ): ?T {
        let parsed = parseJsonBody()
        if (let None <- parsed) {
            return None
        }
        if (let Some(jsonValue) <- parsed) {
            let decoded = tryDecodeJson<T>(jsonValue, decoder)
            if (let None <- decoded) {
                return None
            }
            if (let Some(value) <- decoded) {
                if (let Some(validateFn) <- validate) {
                    let validation = tryValidateJson<T>(value, validateFn)
                    if (let Some(msg) <- validation) {
                        jsonBadRequest("validation_failed", msg)
                        return None
                    }
                }
                return Some(value)
            }
        }
        None
    }

    /// Streamed typed request JSON bind helper.
    ///
    /// This helper stays parallel to `bindJsonOr400(...)` instead of replacing it.
    /// It decodes directly from `requestJsonReader()` and therefore avoids the
    /// old full-buffer `JsonValue` path. Validation still maps to
    /// `validation_failed` after a successful decode.
    ///
    /// Current narrow contract:
    ///
    /// - `BufferedRequestBodyTooLargeException` still propagates through the
    ///   accepted `bodyLimit` path
    /// - malformed `JsonReader` state / token failures currently map to
    ///   `invalid_json`
    /// - numeric overflow and decoder/domain failures currently map to
    ///   `invalid_payload`
    ///
    /// This intentionally avoids overclaiming a broader parse-vs-decode
    /// taxonomy redesign on the streamed path.
    public func bindJsonReaderOr400<T>(
        decoder: (JsonReader) -> T,
        validate!: ?(T) -> ?String = None
    ): ?T {
        let decoded = tryDecodeJsonReader<T>(decoder)
        if (let None <- decoded) {
            return None
        }
        if (let Some(value) <- decoded) {
            if (let Some(validateFn) <- validate) {
                let validation = tryValidateJson<T>(value, validateFn)
                if (let Some(msg) <- validation) {
                    jsonBadRequest("validation_failed", msg)
                    return None
                }
            }
            return Some(value)
        }
        None
    }

    /// Streamed `JsonDeserializable<T>` request bind sugar.
    ///
    /// This helper stays one layer above `bindJsonReaderOr400(...)` and only
    /// removes the repeated `{ reader => T.fromJson(reader) }` wrapper for
    /// typed callers. It therefore inherits the same current body-limit,
    /// malformed-json, invalid-payload, and validation behavior as the
    /// lower-level helper.
    public func bindJsonDeserializeOr400<T>(
        validate!: ?(T) -> ?String = None
    ): ?T where T <: JsonDeserializable<T> {
        bindJsonReaderOr400<T>({ reader =>
            T.fromJson(reader)
        }, validate: validate)
    }

    // ── File serving ──

    public func sendFile(filePath: String): Ctx {
        if (let Some((resolvedPath, totalSize)) <- resolveExistingFile(filePath)) {
            let contentType = detectMimeType(resolvedPath)
            setResponseHeaderTracked("content-type", contentType)
            setResponseHeaderTracked("content-length", "${totalSize}")
            setResponseHeaderTracked("accept-ranges", "bytes")
            _statusCode = 200
            if (!isHeadRequest(method)) {
                if (totalSize == 0) {
                    _currentRequestCarrier.setResponseBytes(Array<UInt8>(0, repeat: 0))
                } else {
                    streamWholeFile(_currentRequestCarrier, resolvedPath)
                }
            }
        } else {
            _currentRequestCarrier.setResponseStatus(404)
            setResponseHeaderTracked("content-type", "text/plain; charset=utf-8")
            _currentRequestCarrier.setResponseString("File not found: ${filePath}")
            _statusCode = 404
        }
        _responded = true
        this
    }

    public func download(filePath: String, filename!: String = ""): Ctx {
        let displayName = if (filename.size > 0) {
            filename
        } else {
            extractFileName(filePath)
        }
        setResponseHeaderTracked("content-disposition", "attachment; filename=\"${displayName}\"")
        sendFile(filePath)
    }

    public func sendFileRange(filePath: String): Ctx {
        if (let Some((resolvedPath, totalSize)) <- resolveExistingFile(filePath)) {
            let contentType = detectMimeType(resolvedPath)

            let rangeHeader = header("range")
            if (let Some(rangeVal) <- rangeHeader) {
                let parsed = parseRangeHeader(rangeVal, totalSize)
                if (let Some((start, end)) <- parsed) {
                    let length = end - start + 1
                    _currentRequestCarrier.setResponseStatus(206)
                    setResponseHeaderTracked("content-type", contentType)
                    setResponseHeaderTracked("content-range", "bytes ${start}-${end}/${totalSize}")
                    setResponseHeaderTracked("content-length", "${length}")
                    setResponseHeaderTracked("accept-ranges", "bytes")
                    _statusCode = 206
                    if (!isHeadRequest(method)) {
                        if (length == 0) {
                            _currentRequestCarrier.setResponseBytes(Array<UInt8>(0, repeat: 0))
                        } else {
                            streamFileSegment(_currentRequestCarrier, resolvedPath, start, length)
                        }
                    }
                } else {
                    _currentRequestCarrier.setResponseStatus(416)
                    setResponseHeaderTracked("content-range", "bytes */${totalSize}")
                    if (!isHeadRequest(method)) {
                        _currentRequestCarrier.setResponseString("Range Not Satisfiable")
                    }
                    _statusCode = 416
                }
            } else {
                setResponseHeaderTracked("content-type", contentType)
                setResponseHeaderTracked("content-length", "${totalSize}")
                setResponseHeaderTracked("accept-ranges", "bytes")
                _statusCode = 200
                if (!isHeadRequest(method)) {
                    if (totalSize == 0) {
                        _currentRequestCarrier.setResponseBytes(Array<UInt8>(0, repeat: 0))
                    } else {
                        streamWholeFile(_currentRequestCarrier, resolvedPath)
                    }
                }
            }
        } else {
            _currentRequestCarrier.setResponseStatus(404)
            setResponseHeaderTracked("content-type", "text/plain; charset=utf-8")
            _currentRequestCarrier.setResponseString("File not found: ${filePath}")
            _statusCode = 404
        }
        _responded = true
        this
    }

    // ── Streaming ──

    /// Open the low-level response transport writer without mutating framing headers.
    ///
    /// Callers own status, content headers, and framing decisions when using this
    /// seam directly. Unlike `writer()` and `jsonWrite(...)`, this method does not
    /// auto-enable HTTP/1.1 chunked transfer encoding.
    public func transportWriter(): ResponseTransportWriter {
        _responded = true
        setLocal("__ignite_response_kind", "transport-stream")
        openResponseTransportWriter(_currentRequestCarrier)
    }

    public func transportOutputStream(): ResponseTransportOutputStream {
        ResponseTransportOutputStream(transportWriter())
    }

    public func writer(): ResponseWriter {
        _responded = true
        ResponseWriter(_currentRequestCarrier)
    }

    public func sse(): SseWriter {
        _responded = true
        setLocal("__ignite_response_kind", "sse")
        SseWriter(_currentRequestCarrier)
    }

    // ── WebSocket ──

    public func upgradeWebSocket(): WsConn {
        _responded = true
        let ws = _currentRequestCarrier.upgradeWebSocketRaw()
        WsConn(ws)
    }

    // ── Internal HttpContext access ──

    public func httpContext(): HttpContext {
        _currentRequestCarrier.rawHttpContext()
    }

    public func currentRequestCarrier(): CurrentRequestCarrier {
        _currentRequestCarrier
    }

    // ── Flow control ──

    public func next(): Unit {
        _handlerIndex += 1
        if (_handlerIndex < _handlers.size) {
            let handler = _handlers[_handlerIndex]
            handler(this)
        }
    }

    // ── Locals (per-request storage) ──

    public func getLocal(key: String): ?String {
        _locals.get(key)
    }

    public func setLocal(key: String, value: String): Unit {
        _locals.add(key, value)
        _localValues.add(key, value)
    }

    public func getLocalValue<T>(key: String): ?T where T <: Any {
        match (_localValues.get(key)) {
            case Some(value) =>
                match (value) {
                    case typed: T => Some(typed)
                    case _ => None
                }
            case None => None
        }
    }

    public func setLocalValue<T>(key: String, value: T): Unit where T <: Any {
        _localValues.add(key, value)
        match (value) {
            case text: String => _locals.add(key, text)
            case _ => let _ = _locals.remove(key)
        }
    }

    // ── App reference ──

    public func app(): App {
        _app
    }

    public prop responseBody: ?String {
        get() { _responseBody }
    }

    public prop responseStatus: UInt16 {
        get() { _statusCode }
    }

    public func route(): ?Route {
        _route
    }

    func responseHeader(key: String): ?String {
        _responseHeaders.get(key.trimAscii().toAsciiLower())
    }

    func rememberResponseHeader(key: String, value: String): Unit {
        _responseHeaders.add(key.trimAscii().toAsciiLower(), value)
    }

    func setResponseHeaderTracked(key: String, value: String): Unit {
        rememberResponseHeader(key, value)
        _currentRequestCarrier.setResponseHeader(key, value)
    }

    // ── Internal setup ──

    public func setParams(params: HashMap<String, String>): Unit {
        this._params = params
    }

    public func setHandlers(handlers: ArrayList<Handler>): Unit {
        this._handlers = handlers
        this._handlerIndex = -1
    }

    public func handlerIndex(): Int64 {
        _handlerIndex
    }

    public func setHandlerIndex(index: Int64): Unit {
        this._handlerIndex = index
    }

    public func setRoute(route: Route): Unit {
        this._route = route
    }

    public func overridePath(path: String): Unit {
        this._pathOverride = Some(path)
    }

    func statusMessage(code: UInt16): String {
        match (code) {
            case 200 => "OK"
            case 201 => "Created"
            case 204 => "No Content"
            case 301 => "Moved Permanently"
            case 302 => "Found"
            case 304 => "Not Modified"
            case 400 => "Bad Request"
            case 401 => "Unauthorized"
            case 403 => "Forbidden"
            case 404 => "Not Found"
            case 405 => "Method Not Allowed"
            case 409 => "Conflict"
            case 413 => "Payload Too Large"
            case 422 => "Unprocessable Entity"
            case 429 => "Too Many Requests"
            case 500 => "Internal Server Error"
            case 502 => "Bad Gateway"
            case 503 => "Service Unavailable"
            case _ => "Unknown"
        }
    }

    func tryEncryptCookieValue(name: String, value: String): String {
        let enabled = _locals.get("__ignite_cookie_enc_enabled") ?? "0"
        if (enabled != "1") {
            return value
        }
        let exceptCsv = _locals.get("__ignite_cookie_enc_except") ?? ""
        if (cookieNameInCsv(name, exceptCsv)) {
            return value
        }
        let keyHex = _locals.get("__ignite_cookie_enc_key_hex") ?? ""
        let keyId = _locals.get("__ignite_cookie_enc_kid") ?? "k1"
        let alg = _locals.get("__ignite_cookie_enc_alg") ?? "AES-256-GCM"
        let providerText = _locals.get("__ignite_cookie_enc_provider") ?? "jinguiSSL"
        if (keyHex.size == 0) {
            return value
        }
        try {
            let key = security.hexToBytes(keyHex)
            let keyRing = HashMap<String, Array<UInt8>>()
            keyRing.add(keyId, key)
            let config = security.SecurityConfig(
                providerKind: parseSecurityProviderKind(providerText),
                activeKid: keyId,
                keyRing: keyRing,
                aeadAlgorithm: alg
            )
            security.sealCookieValueV1(config, value, cookieName: name)
        } catch (_: Exception) {
            value
        }
    }

    func parseSecurityProviderKind(raw: String): security.SecurityProviderKind {
        let v = raw.trimAscii().toAsciiLower()
        if (v == "stdx-fallback") {
            return security.SecurityProviderKind.StdxFallback
        }
        security.SecurityProviderKind.jinguiSSL
    }

    func cookieNameInCsv(name: String, csv: String): Bool {
        if (csv.trimAscii().size == 0) {
            return false
        }
        let parts = csv.split(",")
        for (part in parts) {
            if (part.trimAscii() == name) {
                return true
            }
        }
        false
    }

    func parseJsonBody(): ?JsonValue {
        let raw = bodyString()
        try {
            Some(JsonValue.fromStr(raw))
        } catch (_: Exception) {
            jsonBadRequest("invalid_json", "request body is not valid json")
            None
        }
    }

    func tryDecodeJson<T>(jsonValue: JsonValue, decoder: (JsonValue) -> T): ?T {
        try {
            Some(decoder(jsonValue))
        } catch (e: Exception) {
            let msg = if (e.message.trimAscii().size > 0) {
                "failed to decode payload: ${e.message}"
            } else {
                "failed to decode payload"
            }
            jsonBadRequest("invalid_payload", msg)
            None
        }
    }

    func tryDecodeJsonReader<T>(decoder: (JsonReader) -> T): ?T {
        let reader = requestJsonReader()
        try {
            Some(decoder(reader))
        } catch (e: BufferedRequestBodyTooLargeException) {
            throw e
        } catch (e: IllegalStateException) {
            let msg = if (e.message.trimAscii().size > 0) {
                "request body is not valid json: ${e.message}"
            } else {
                "request body is not valid json"
            }
            jsonBadRequest("invalid_json", msg)
            None
        } catch (e: OverflowException) {
            let msg = if (e.message.trimAscii().size > 0) {
                "failed to decode payload: ${e.message}"
            } else {
                "failed to decode payload"
            }
            jsonBadRequest("invalid_payload", msg)
            None
        } catch (e: Exception) {
            let msg = if (e.message.trimAscii().size > 0) {
                "failed to decode payload: ${e.message}"
            } else {
                "failed to decode payload"
            }
            jsonBadRequest("invalid_payload", msg)
            None
        }
    }

    func tryValidateJson<T>(value: T, validateFn: (T) -> ?String): ?String {
        try {
            validateFn(value)
        } catch (e: Exception) {
            if (e.message.trimAscii().size > 0) {
                Some("validation exception: ${e.message}")
            } else {
                Some("validation exception")
            }
        }
    }

    func jsonBadRequest(reason: String, message: String): Unit {
        let payload = #"{"error":"bad_request","reason":""# + escapeJson(reason) + #"","message":""# + escapeJson(message) + #""}"#
        _ = status(400).json(payload)
    }

    func escapeJson(input: String): String {
        escapeJsonText(input)
    }
}

func detectMimeType(path: String): String {
    let ext = extractExtension(path.toLower())
    match (ext) {
        case ".html" | ".htm" => "text/html; charset=utf-8"
        case ".css" => "text/css; charset=utf-8"
        case ".js" | ".mjs" => "application/javascript; charset=utf-8"
        case ".json" => "application/json; charset=utf-8"
        case ".png" => "image/png"
        case ".jpg" | ".jpeg" => "image/jpeg"
        case ".gif" => "image/gif"
        case ".svg" => "image/svg+xml"
        case ".ico" => "image/x-icon"
        case ".webp" => "image/webp"
        case ".txt" => "text/plain; charset=utf-8"
        case ".xml" => "application/xml"
        case ".pdf" => "application/pdf"
        case ".zip" => "application/zip"
        case ".gz" => "application/gzip"
        case ".woff" => "font/woff"
        case ".woff2" => "font/woff2"
        case ".ttf" => "font/ttf"
        case ".mp4" => "video/mp4"
        case ".webm" => "video/webm"
        case ".mp3" => "audio/mpeg"
        case ".wav" => "audio/wav"
        case _ => "application/octet-stream"
    }
}

let FILE_STREAM_BUFFER_SIZE: Int64 = 64 * 1024

func resolveExistingFile(rawPath: String): ?(String, Int64) {
    let path = rawPath.trimAscii()
    if (path.size == 0) {
        return None
    }

    let candidates = ArrayList<String>()
    candidates.add(path)
    if (startsWithSlash(path)) {
        candidates.add("." + path)
    }

    for (candidate in candidates) {
        if (!exists(candidate)) {
            continue
        }
        try {
            let info = FileInfo(candidate)
            if (!info.isDirectory()) {
                return Some((candidate, info.size))
            }
        } catch (_: Exception) {
            ()
        }
    }
    None
}

func streamWholeFile(currentRequestCarrier: CurrentRequestCarrier, path: String): Unit {
    streamFileSegment(currentRequestCarrier, path, 0, -1)
}

func streamFileSegment(currentRequestCarrier: CurrentRequestCarrier, path: String, start: Int64, length: Int64): Unit {
    let stream = FileSegmentInputStream(path, start: start, length: length)
    attachResponseBodyStream(currentRequestCarrier, stream)
}

func attachResponseBodyStream(currentRequestCarrier: CurrentRequestCarrier, stream: InputStream): Unit {
    currentRequestCarrier.attachResponseBodyStream(stream)
}

func streamRequestBodyToFile(stream: InputStream, destPath: String): Int64 {
    let file = File(destPath, OpenMode.Write)
    let buffer = Array<UInt8>(FILE_STREAM_BUFFER_SIZE, repeat: 0)
    var total: Int64 = 0
    var completed = false
    try {
        while (true) {
            let readLen = stream.read(buffer)
            if (readLen <= 0) {
                completed = true
                break
            }
            let chunk = Array<UInt8>(readLen, repeat: 0)
            var i: Int64 = 0
            while (i < readLen) {
                chunk[i] = buffer[i]
                i += 1
            }
            file.write(chunk)
            total += readLen
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

func writeBytesToFile(destPath: String, bytes: Array<UInt8>): Unit {
    let file = File(destPath, OpenMode.Write)
    try {
        file.write(bytes)
    } finally {
        file.close()
    }
}

func toRequestBodyReplayByteArray(input: Array<UInt8>): Array<Byte> {
    let out = Array<Byte>(input.size, repeat: 0)
    var i: Int64 = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}

func closeStreamIfResource(stream: InputStream): Unit {
    match (stream) {
        case closable: Resource => closable.close()
        case _ => ()
    }
}

/// Public file-backed segment stream for known-length and range-style response migration.
///
/// This seam is intended for callers that already own response headers and want
/// to reuse Ignite's file-window streaming path via `ctx.sendStream(...)`
/// instead of constructing a transport writer directly.
public class FileSegmentInputStream <: InputStream & Resource {
    let _file: File
    var _remaining: Int64
    var _closed: Bool = false

    public init(path: String, start!: Int64 = 0, length!: Int64 = -1) {
        _file = File(path, OpenMode.Read)
        _remaining = length
        skipFilePrefix(_file, start)
    }

    public override func read(outBuf: Array<Byte>): Int64 {
        if (_closed || outBuf.size == 0) {
            return 0
        }
        if (_remaining == 0) {
            close()
            return 0
        }
        let window = if (_remaining < 0 || _remaining >= outBuf.size) {
            outBuf
        } else {
            outBuf[.._remaining]
        }
        let readLen = _file.read(window)
        if (readLen <= 0) {
            close()
            return readLen
        }
        if (_remaining > 0) {
            _remaining -= readLen
            if (_remaining <= 0) {
                close()
            }
        }
        readLen
    }

    public func close(): Unit {
        if (_closed) {
            return
        }
        _closed = true
        _file.close()
    }

    public func isClosed(): Bool {
        _closed
    }
}

func skipFilePrefix(file: File, bytesToSkip: Int64): Unit {
    if (bytesToSkip <= 0) {
        return
    }
    let buffer = Array<UInt8>(FILE_STREAM_BUFFER_SIZE, repeat: 0)
    var remaining = bytesToSkip
    while (remaining > 0) {
        let window = if (remaining < FILE_STREAM_BUFFER_SIZE) {
            buffer[..remaining]
        } else {
            buffer
        }
        let readLen = file.read(window)
        if (readLen <= 0) {
            throw Exception("failed to skip file bytes")
        }
        remaining -= readLen
    }
}

func isHeadRequest(method: String): Bool {
    method.trimAscii().toAsciiUpper() == "HEAD"
}

func startsWithSlash(path: String): Bool {
    let runes = path.toRuneArray()
    if (runes.size == 0) {
        return false
    }
    runes[0] == r'/' || runes[0] == r'\\'
}

func extractExtension(path: String): String {
    let runes = path.toRuneArray()
    var i = runes.size - 1
    while (i >= 0) {
        if (runes[i] == r'.') {
            var ext = ""
            for (j in i..runes.size) {
                ext += runes[j].toString()
            }
            return ext
        }
        if (runes[i] == r'/' || runes[i] == r'\\') {
            return ""
        }
        i -= 1
    }
    ""
}

func extractFileName(path: String): String {
    let runes = path.toRuneArray()
    var i = runes.size - 1
    while (i >= 0) {
        if (runes[i] == r'/' || runes[i] == r'\\') {
            var name = ""
            for (j in (i + 1)..runes.size) {
                name += runes[j].toString()
            }
            return name
        }
        i -= 1
    }
    path
}

func parseRangeHeader(rangeVal: String, totalSize: Int64): ?(Int64, Int64) {
    let runes = rangeVal.toRuneArray()
    if (runes.size < 6) { return None }
    var prefix = ""
    for (i in 0..6) {
        prefix += runes[i].toString()
    }
    if (prefix.toLower() != "bytes=") { return None }

    var rangeSpec = ""
    for (i in 6..runes.size) {
        rangeSpec += runes[i].toString()
    }
    let parts = rangeSpec.split("-", 2)
    if (parts.size != 2) { return None }

    let startStr = parts[0].trimAscii()
    let endStr = parts[1].trimAscii()

    if (startStr.size == 0 && endStr.size == 0) { return None }

    if (startStr.size == 0) {
        let suffix = parsePositiveInt(endStr)
        if (suffix <= 0) { return None }
        var start = totalSize - suffix
        if (start < 0) { start = 0 }
        return Some((start, totalSize - 1))
    }

    let start = parsePositiveInt(startStr)
    if (start < 0 || start >= totalSize) { return None }

    if (endStr.size == 0) {
        return Some((start, totalSize - 1))
    }

    let end = parsePositiveInt(endStr)
    if (end < start || end >= totalSize) {
        return Some((start, totalSize - 1))
    }
    Some((start, end))
}

func parsePositiveInt(s: String): Int64 {
    let runes = s.toRuneArray()
    if (runes.size == 0) { return -1 }
    var result: Int64 = 0
    for (ch in runes) {
        if (ch < r'0' || ch > r'9') { return -1 }
        let digit = Int64(UInt32(ch)) - Int64(UInt32(r'0'))
        result = result * 10 + digit
    }
    result
}
