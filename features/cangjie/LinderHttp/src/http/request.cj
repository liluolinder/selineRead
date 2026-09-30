package linderHttp.http

/**
 * 一次请求的不可变描述。
 *
 * 由 `RequestBuilder` 构建；`HttpClient.send(request)` 直接发送它，
 * 也可以把它放进队列、做批量并发（`HttpClient.sendAll`）。
 */
public class Request <: ToString {
    public let method: Method
    /** 已经拼好查询参数、可直接发送的最终 URL */
    public let url: String
    public let headers: Headers
    public let body: ?Body
    /** 请求级超时覆盖（None 表示用客户端设置） */
    public let timeouts: ?Timeouts
    /** 请求级重试覆盖（None 表示用客户端设置） */
    public let retry: ?RetryPolicy
    /** 是否以流式方式返回响应体（不自动读进内存） */
    public let streamResponse: Bool
    /** 业务标记，仅用于日志追踪 */
    public let tag: ?String

    internal init(method: Method, url: String, headers: Headers, body: ?Body,
        timeouts: ?Timeouts, retry: ?RetryPolicy, streamResponse: Bool, tag: ?String) {
        this.method = method
        this.url = url
        this.headers = headers
        this.body = body
        this.timeouts = timeouts
        this.retry = retry
        this.streamResponse = streamResponse
        this.tag = tag
    }

    public func header(name: String): ?String {
        headers.first(name)
    }

    public func hasBody(): Bool {
        body.isSome()
    }

    /**
     * 派生一个「多加一个头」的新请求。
     *
     * 主要给拦截器用：拦截器拿到的是不可变请求，靠它产生改写后的副本，
     * 而不是就地修改共享状态。
     */
    public func withHeader(name: String, value: String): Request {
        let clone = headers.copy()
        clone.set(name, value)
        Request(method, url, clone, body, timeouts, retry, streamResponse, tag)
    }

    /** 派生一个换过请求体的新请求。 */
    public func withBody(value: Body): Request {
        Request(method, url, headers.copy(), Some(value), timeouts, retry, streamResponse, tag)
    }

    /** 派生一个换过 URL 的新请求。 */
    public func withUrl(value: String): Request {
        Request(method, value, headers.copy(), body, timeouts, retry, streamResponse, tag)
    }

    public func toString(): String {
        "${method} ${url}"
    }
}

/**
 * 请求构建器（链式）。
 *
 * 两种取得方式：
 * - `client.get(url)` / `client.post(url)`：绑定到客户端，可直接 `.send()`；
 * - `RequestBuilder(method: Method.Post, url: "...")`：独立构建，`.build()` 出 `Request`。
 *
 * 示例：
 * ```cangjie
 * let response = client.post("https://api.example.com/v1/items")
 *     .jsonObject(payload)
 *     .bearer(token)
 *     .timeout(Timeouts.standard().withTotal(Duration.second * 10))
 *     .send()
 * ```
 */
public class RequestBuilder {
    private let client: ?HttpClient
    private var methodValue: Method
    private var urlValue: String
    private var headerValues: Headers = Headers()
    private var bodyValue: ?Body = None
    private var queryValues: ArrayList<(String, String)> = ArrayList<(String, String)>()
    private var timeoutsValue: ?Timeouts = None
    private var retryValue: ?RetryPolicy = None
    private var streamValue: Bool = false
    private var tagValue: ?String = None

    /** 独立构建器：不绑定客户端，只用于 `.build()`。 */
    public init(method!: Method = Method.Get, url!: String = "") {
        this.client = None
        this.methodValue = method
        this.urlValue = url
    }

    internal init(client: HttpClient, method: Method, url: String) {
        this.client = Some(client)
        this.methodValue = method
        this.urlValue = url
    }

    // ---------- 请求行 ----------

    public func method(value: Method): RequestBuilder {
        methodValue = value
        this
    }

    public func url(value: String): RequestBuilder {
        urlValue = value
        this
    }

    /** 以 `URL` 对象设置地址；编码由库在发送时统一处理。 */
    public func url(value: URL): RequestBuilder {
        urlValue = value.toString()
        this
    }

    /** 追加一个查询参数（自动百分号编码）。 */
    public func query(name: String, value: String): RequestBuilder {
        queryValues.add((name, value))
        this
    }

    public func query(pairs: Array<(String, String)>): RequestBuilder {
        for (pair in pairs) {
            queryValues.add(pair)
        }
        this
    }

    // ---------- 请求头 ----------

    public func header(name: String, value: String): RequestBuilder {
        headerValues.set(name, value)
        this
    }

    public func header(name: String, value: Int64): RequestBuilder {
        headerValues.set(name, "${value}")
        this
    }

    public func addHeader(name: String, value: String): RequestBuilder {
        headerValues.add(name, value)
        this
    }

    public func headers(values: Headers): RequestBuilder {
        for ((name, items) in values) {
            for (item in items) {
                headerValues.set(name, item)
            }
        }
        this
    }

    /** `Authorization: Basic ...` */
    public func basicAuth(user: String, password: String): RequestBuilder {
        let token = base64Encode("${user}:${password}".toArray())
        headerValues.set("authorization", "Basic ${token}")
        this
    }

    /** `Authorization: Bearer ...` */
    public func bearer(token: String): RequestBuilder {
        headerValues.set("authorization", "Bearer ${token}")
        this
    }

    // ---------- 请求体 ----------

    public func body(value: Body): RequestBuilder {
        bodyValue = Some(value)
        this
    }

    public func text(value: String, contentType!: String = "text/plain; charset=utf-8"): RequestBuilder {
        bodyValue = Some(Body.text(value, contentType: contentType))
        this
    }

    public func json(value: JsonValue): RequestBuilder {
        bodyValue = Some(Body.json(value))
        this
    }

    public func jsonObject(value: JsonObject): RequestBuilder {
        bodyValue = Some(Body.json(value))
        this
    }

    public func jsonText(value: String): RequestBuilder {
        bodyValue = Some(Body.jsonText(value))
        this
    }

    public func dataModel(value: DataModel): RequestBuilder {
        bodyValue = Some(Body.dataModel(value))
        this
    }

    public func bytes(value: Array<Byte>,
        contentType!: String = "application/octet-stream"): RequestBuilder {
        bodyValue = Some(Body.bytes(value, contentType: contentType))
        this
    }

    public func form(fields: HashMap<String, String>): RequestBuilder {
        bodyValue = Some(Body.form(fields))
        this
    }

    public func form(fields: Array<(String, String)>): RequestBuilder {
        bodyValue = Some(Body.form(fields))
        this
    }

    public func multipart(value: MultipartBody): RequestBuilder {
        bodyValue = Some(Body.multipart(value))
        this
    }

    public func streamBody(source: InputStream,
        contentType!: String = "application/octet-stream", length!: ?Int64 = None): RequestBuilder {
        bodyValue = Some(Body.stream(source, contentType: contentType, length: length))
        this
    }

    public func fileBody(path: Path,
        contentType!: String = "application/octet-stream"): RequestBuilder {
        bodyValue = Some(Body.file(path, contentType: contentType))
        this
    }

    // ---------- 行为覆盖 ----------

    public func timeout(value: Timeouts): RequestBuilder {
        timeoutsValue = Some(value)
        this
    }

    public func readTimeout(value: Duration): RequestBuilder {
        timeoutsValue = Some(buildTimeouts(read: Some(value)))
        this
    }

    public func writeTimeout(value: Duration): RequestBuilder {
        timeoutsValue = Some(buildTimeouts(write: Some(value)))
        this
    }

    /** 整次请求（含重试）的总预算。 */
    public func totalTimeout(value: Duration): RequestBuilder {
        timeoutsValue = Some(buildTimeouts(total: Some(value)))
        this
    }

    public func retry(value: RetryPolicy): RequestBuilder {
        retryValue = Some(value)
        this
    }

    public func noRetry(): RequestBuilder {
        retryValue = Some(RetryPolicy.none())
        this
    }

    /** 让响应体保持流式，不自动读进内存（大文件下载用）。 */
    public func streamResponse(value: Bool): RequestBuilder {
        streamValue = value
        this
    }

    public func tag(value: String): RequestBuilder {
        tagValue = Some(value)
        this
    }

    private func buildTimeouts(read!: ?Duration = None, write!: ?Duration = None,
        total!: ?Duration = None): Timeouts {
        match (timeoutsValue) {
            case Some(existing) =>
                Timeouts(
                    connect: existing.connect,
                    read: if (read.isSome()) { read } else { existing.read },
                    write: if (write.isSome()) { write } else { existing.write },
                    total: if (total.isSome()) { total } else { existing.total }
                )
            case None => Timeouts(read: read, write: write, total: total)
        }
    }

    /** 生成最终 URL：拼查询参数、按需编码非 ASCII 字符。 */
    private func resolveUrl(): String {
        var target = urlValue
        if (!queryValues.isEmpty()) {
            let parts = ArrayList<String>()
            for (pair in queryValues) {
                parts.add("${percentEncode(pair[0])}=${percentEncode(pair[1])}")
            }
            let joined = String.join(parts.toArray(), delimiter: "&")
            target = if (target.contains("?")) {
                "${target}&${joined}"
            } else {
                "${target}?${joined}"
            }
        }
        if (containsNonAscii(target)) {
            target = URL.encode(target)
        }
        target
    }

    public func build(): Request {
        Request(methodValue, resolveUrl(), headerValues.copy(), bodyValue, timeoutsValue, retryValue,
            streamValue, tagValue)
    }

    /** 发送（响应体按策略自动落地）。 */
    public func send(): Response {
        let bound = match (client) {
            case Some(value) => value
            case None => throw Exception("该 RequestBuilder 未绑定 HttpClient，请先 .build() 再用 client.send(request)")
        }
        bound.send(build())
    }

    /** 发送并保持响应体流式。 */
    public func sendStream(): Response {
        let bound = match (client) {
            case Some(value) => value
            case None => throw Exception("该 RequestBuilder 未绑定 HttpClient，请先 .build() 再用 client.sendStream(request)")
        }
        bound.sendStream(build())
    }
}

// ---------- 编码小工具（不引入额外依赖，行为可控） ----------

internal func percentEncode(value: String): String {
    var result = ""
    for (byte in value.toArray()) {
        if (isUnreserved(byte)) {
            result += String.fromUtf8([byte])
        } else {
            result += "%" + hexDigit(byte >> 4) + hexDigit(byte & 0x0F)
        }
    }
    result
}

private func isUnreserved(byte: UInt8): Bool {
    (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57) ||
        byte == 45 || byte == 46 || byte == 95 || byte == 126
}

private func hexDigit(value: UInt8): String {
    let digits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
    digits[Int64(value)]
}

internal func containsNonAscii(text: String): Bool {
    for (byte in text.toArray()) {
        if (byte > 127) {
            return true
        }
    }
    false
}

/** 解析 Int64，失败返回 None（不抛异常）。 */
internal func tryParseInt64(text: String): ?Int64 {
    if (text.isEmpty()) {
        return None
    }
    try {
        Some(Int64.parse(text))
    } catch (_: Exception) {
        None
    }
}

internal func base64Encode(data: Array<Byte>): String {
    let alphabet = [
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
        "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
        "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "/"
    ]
    var result = ""
    var index = 0
    while (index + 2 < data.size) {
        let chunk = (Int64(data[index]) << 16) | (Int64(data[index + 1]) << 8) | Int64(data[index + 2])
        result += alphabet[(chunk >> 18) & 63]
        result += alphabet[(chunk >> 12) & 63]
        result += alphabet[(chunk >> 6) & 63]
        result += alphabet[chunk & 63]
        index += 3
    }
    let remaining = data.size - index
    if (remaining == 1) {
        let chunk = Int64(data[index]) << 16
        result += alphabet[(chunk >> 18) & 63]
        result += alphabet[(chunk >> 12) & 63]
        result += "=="
    } else if (remaining == 2) {
        let chunk = (Int64(data[index]) << 16) | (Int64(data[index + 1]) << 8)
        result += alphabet[(chunk >> 18) & 63]
        result += alphabet[(chunk >> 12) & 63]
        result += alphabet[(chunk >> 6) & 63]
        result += "="
    }
    result
}
