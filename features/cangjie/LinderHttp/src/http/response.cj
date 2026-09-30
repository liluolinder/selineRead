package linderHttp.http

/**
 * 读取包装：响应体以流式租约形式持有连接池槽位时，读到流结尾就自动归还。
 *
 * stdx 的 `InputStream` 接口没有 `close()`，因此归还时机只能由「读到 EOF」触发；
 * 调用方若提前放弃，应调用 `Response.close()`。
 */
internal class BodyGuardStream <: InputStream {
    private let inner: InputStream
    private let onDone: () -> Unit
    private var done: Bool = false

    internal init(inner: InputStream, onDone: () -> Unit) {
        this.inner = inner
        this.onDone = onDone
    }

    public override func read(buffer: Array<Byte>): Int64 {
        let count = inner.read(buffer)
        if (count <= 0) {
            finish()
        }
        count
    }

    private func finish(): Unit {
        if (!done) {
            done = true
            onDone()
        }
    }
}

/**
 * 「内存前缀 + 剩余实流」的组合流。
 *
 * 用于长度未知的响应：先读一小段判断大小，若超出阈值就把已读部分和前缀拼起来继续流式读，
 * 既不浪费已读数据，也不把大响应整块吞进内存。
 */
internal class PrefixedStream <: InputStream {
    private var prefix: ?Array<Byte>
    private let inner: InputStream
    private let onDone: () -> Unit
    private var done: Bool = false

    internal init(prefix: Array<Byte>, inner: InputStream, onDone: () -> Unit) {
        this.prefix = Some(prefix)
        this.inner = inner
        this.onDone = onDone
    }

    public override func read(buffer: Array<Byte>): Int64 {
        match (prefix) {
            case Some(data) =>
                let count = if (Int64(data.size) > Int64(buffer.size)) {
                    Int64(buffer.size)
                } else {
                    Int64(data.size)
                }
                if (count > 0) {
                    var index: Int64 = 0
                    while (index < count) {
                        buffer[index] = data[index]
                        index++
                    }
                    prefix = if (Int64(data.size) > count) { Some(data[count..]) } else { None }
                    return count
                }
            case None => ()
        }
        let count = inner.read(buffer)
        if (count <= 0) {
            finish()
        }
        count
    }

    private func finish(): Unit {
        if (!done) {
            done = true
            onDone()
        }
    }
}

/**
 * HTTP 响应。
 *
 * 设计要点（借鉴 OkHttp 的 ResponseBody 与 requests 的便捷读取，但换成本库自己的风格）：
 *
 * 1. **默认把响应体读进内存**：HTTP/1.1 的响应体必须读完，连接才会被放回连接池。
 *    所以在 `send()` 里就把小响应体（≤ `bodyBufferLimit`）落地，
 *    既让调用方随便读（`text()`/`json()`/`bytes()` 可反复取），也保证长连接一定被复用。
 * 2. **大响应体保持流式**：超过阈值（或长度未知、或显式 `sendStream()`）时不落地，
 *    改为持有「流式租约」，读到结尾自动归还槽位；`saveTo()` 就是流式落盘的入口。
 * 3. **实现 `Resource`**：可以写 `try (response = ...)`，离开作用域自动 `close()`。
 */
public class Response <: Resource & ToString {
    private let raw: HttpResponse
    private let requestValue: Request
    private let attemptCount: Int64
    private let elapsedTime: Duration
    private var cached: ?Array<Byte>
    private var liveSource: ?InputStream
    private var releaseCallback: ?() -> Unit
    private var releasedFlag: Bool = false
    private var closedFlag: Bool = false

    internal init(raw: HttpResponse, request: Request, attempts: Int64, elapsed: Duration,
        buffered: ?Array<Byte>, live: ?InputStream, onRelease: ?() -> Unit) {
        this.raw = raw
        this.requestValue = request
        this.attemptCount = attempts
        this.elapsedTime = elapsed
        this.cached = buffered
        this.releaseCallback = onRelease
        this.liveSource = live
    }

    // ---------- 元信息 ----------

    public prop status: UInt16 {
        get() {
            raw.status
        }
    }

    public prop statusText: String {
        get() {
            statusPhrase(status)
        }
    }

    /** 是否为 2xx。 */
    public prop ok: Bool {
        get() {
            status >= 200 && status < 300
        }
    }

    public prop isSuccessful: Bool {
        get() {
            ok
        }
    }

    public prop isRedirect: Bool {
        get() {
            status >= 300 && status < 400
        }
    }

    public prop headers: Headers {
        get() {
            Headers(raw: raw.headers)
        }
    }

    /** 请求的最终 URL（自动重定向后以底层请求为准）。 */
    public prop url: String {
        get() {
            match (raw.request) {
                case Some(value) => value.url.toString()
                case None => requestValue.url
            }
        }
    }

    public prop method: Method {
        get() {
            requestValue.method
        }
    }

    /** 实际尝试次数（含重试）。 */
    public prop attempts: Int64 {
        get() {
            attemptCount
        }
    }

    /** 本次请求耗时（不含调用方读流的时间）。 */
    public prop elapsed: Duration {
        get() {
            elapsedTime
        }
    }

    public prop protocolVersion: String {
        get() {
            "${raw.version}"
        }
    }

    public prop contentLength: ?Int64 {
        get() {
            // 已落地内存时以实际字节数为准（透明解压后长度会变）
            match (cached) {
                case Some(data) => return Some(Int64(data.size))
                case None => ()
            }
            match (raw.headers.getFirst("content-length")) {
                case Some(value) => tryParseInt64(value.trimAscii())
                case None => raw.bodySize
            }
        }
    }

    public prop contentType: ?String {
        get() {
            raw.headers.getFirst("content-type")
        }
    }

    public prop location: ?String {
        get() {
            raw.headers.getFirst("location")
        }
    }

    /** 服务端下发的 Cookie。 */
    public prop cookies: Array<Cookie> {
        get() {
            let result = ArrayList<Cookie>()
            for (value in raw.headers.get("set-cookie")) {
                match (parseSetCookie(value, "", "/")) {
                    case Some(cookie) => result.add(cookie)
                    case None => ()
                }
            }
            result.toArray()
        }
    }

    public func header(name: String): ?String {
        raw.headers.getFirst(name)
    }

    public func headerValues(name: String): Collection<String> {
        raw.headers.get(name)
    }

    public func rawResponse(): HttpResponse {
        raw
    }

    // ---------- 响应体 ----------

    /** 全部字节；可反复调用（已落地时直接返回缓存）。 */
    public func bytes(): Array<Byte> {
        match (cached) {
            case Some(data) => data
            case None =>
                let source = match (liveSource) {
                    case Some(value) => value
                    case None => throw HttpError(ErrorKind.ResponseBody, "响应体已被消费或已关闭",
                        url: url)
                }
                liveSource = None
                let data = readStreamFully(source)
                cached = Some(data)
                releaseLease()
                data
        }
    }

    /** UTF-8 文本。 */
    public func text(): String {
        String.fromUtf8(bytes())
    }

    public func json(): JsonValue {
        JsonValue.fromStr(text())
    }

    public func jsonObject(): JsonObject {
        json().asObject()
    }

    public func dataModel(): DataModel {
        DataModel.fromJson(json())
    }

    /**
     * 以流的形式取响应体。
     *
     * 若响应体已落地内存，会返回基于内存的流（可多次调用）；
     * 若仍是流式租约，则返回只读一次的包装流，读完自动归还连接池槽位。
     */
    public func stream(): InputStream {
        match (cached) {
            case Some(data) => ByteBuffer(data)
            case None =>
                let source = match (liveSource) {
                    case Some(value) => value
                    case None => throw HttpError(ErrorKind.ResponseBody, "响应体已被消费或已关闭",
                        url: url)
                }
                liveSource = None
                BodyGuardStream(source, { => releaseLease() })
        }
    }

    /**
     * 落盘。
     *
     * @param path 目标文件
     * @param overwrite false 时若已存在则自动改名（`file(1).txt`）
     * @return 写入字节数
     */
    public func saveTo(path: Path, overwrite!: Bool = true): Int64 {
        let target = resolveTarget(path, overwrite)
        let file = File(target, OpenMode.Write)
        var written: Int64 = 0
        let chunk = Array<Byte>(65536, repeat: 0)
        let source = stream()
        var count = source.read(chunk)
        while (count > 0) {
            file.write(chunk[0..count])
            written += count
            count = source.read(chunk)
        }
        file.close()
        written
    }

    /** 非 2xx（≥400）时抛出 `StatusError`；便于「先断言再取内容」的写法。 */
    public func raiseForStatus(): Response {
        if (status < 400) {
            return this
        }
        var preview = ""
        try {
            let data = bytes()
            let slice = if (data.size > 512) { data[0..512] } else { data }
            preview = String.fromUtf8(slice)
        } catch (_: Exception) {
            preview = ""
        }
        throw StatusError(status, statusText, url: url, attempts: attemptCount, bodyPreview: preview)
    }

    /**
     * 丢弃响应体并释放资源。已落地内存的响应调用它是空操作；
     * 流式响应会关闭底层响应体，让连接池尽快回收。
     */
    public func close(): Unit {
        if (closedFlag) {
            return
        }
        closedFlag = true
        if (cached.isNone()) {
            liveSource = None
            try {
                raw.close()
            } catch (_: Exception) {
                ()
            }
        }
        releaseLease()
    }

    /** 供 `try (response = ...)` 使用。 */
    public func isClosed(): Bool {
        closedFlag
    }

    private func releaseLease(): Unit {
        if (!releasedFlag) {
            releasedFlag = true
            match (releaseCallback) {
                case Some(callback) => callback()
                case None => ()
            }
        }
    }

    public func toString(): String {
        "HTTP ${status} ${statusText} ${method} ${url} (${attemptCount} 次尝试, ${elapsedTime})"
    }
}

/** 常见状态码的英文短语。 */
internal func statusPhrase(status: UInt16): String {
    match (status) {
        case 200 => "OK"
        case 201 => "Created"
        case 202 => "Accepted"
        case 204 => "No Content"
        case 206 => "Partial Content"
        case 301 => "Moved Permanently"
        case 302 => "Found"
        case 303 => "See Other"
        case 304 => "Not Modified"
        case 307 => "Temporary Redirect"
        case 308 => "Permanent Redirect"
        case 400 => "Bad Request"
        case 401 => "Unauthorized"
        case 403 => "Forbidden"
        case 404 => "Not Found"
        case 405 => "Method Not Allowed"
        case 408 => "Request Timeout"
        case 409 => "Conflict"
        case 410 => "Gone"
        case 413 => "Payload Too Large"
        case 415 => "Unsupported Media Type"
        case 418 => "I'm a teapot"
        case 422 => "Unprocessable Entity"
        case 429 => "Too Many Requests"
        case 500 => "Internal Server Error"
        case 501 => "Not Implemented"
        case 502 => "Bad Gateway"
        case 503 => "Service Unavailable"
        case 504 => "Gateway Timeout"
        case _ => ""
    }
}

/** 按冲突策略解析最终写入路径。 */
internal func resolveTarget(path: Path, overwrite: Bool): Path {
    if (overwrite || !exists(path)) {
        return path
    }
    let parent = path.parent
    let baseName = path.fileNameWithoutExtension
    let extension = path.extensionName
    var counter = 1
    while (counter < 10000) {
        let candidate = if (extension.isEmpty()) {
            parent.join(Path("${baseName}(${counter})"))
        } else {
            parent.join(Path("${baseName}(${counter}).${extension}"))
        }
        if (!exists(candidate)) {
            return candidate
        }
        counter++
    }
    path
}
