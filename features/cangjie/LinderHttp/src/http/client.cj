package linderHttp.http

/**
 * 重定向最多跳几层。
 *
 * 5 层足够覆盖现实中的跳转链（Modrinth 的图标 CDN 只有一跳），同时防止环状跳转让请求打转。
 * 放在文件顶部是因为 `HttpClient.execute` 用到了它 —— 仓颉要求声明先于使用。
 */
internal let MAX_REDIRECT_HOPS: Int64 = 5

/**
 * 解析后的目标地址，用作连接池分键。
 */
internal class ParsedTarget {
    let key: String
    let host: String
    let url: URL
    let rawText: String
    let scheme: String
    let port: String

    init(key: String, host: String, url: URL, rawText: String, scheme: String, port: String) {
        this.key = key
        this.host = host
        this.url = url
        this.rawText = rawText
        this.scheme = scheme
        this.port = port
    }
}

/**
 * 响应体捕获结果。
 */
internal class CapturedBody {
    let buffered: ?Array<Byte>
    let live: ?InputStream
    let release: ?() -> Unit

    init(buffered: ?Array<Byte>, live: ?InputStream, release: ?() -> Unit) {
        this.buffered = buffered
        this.live = live
        this.release = release
    }
}

/**
 * HTTP 客户端。
 *
 * 语义对齐主流库的「客户端 = 连接池 + 配置 + 拦截器」：
 * - **创建一次、全线程共享**：内部持有一个按 host 分组的连接池，长连接在其中复用；
 * - **不可变配置**：建好之后再改 builder 不影响它，`with()` 可以派生一个改过的副本；
 * - **实现 `Resource`**：`try (client = HttpClientBuilder().build()) { ... }` 自动关闭。
 *
 * 一行式用法（对标 requests/axios）：
 * ```cangjie
 * let client = HttpClientBuilder().build()
 * let text = client.get("https://example.com/").text()
 * client.close()
 * ```
 *
 * 可链式用法（需要精细控制时）：
 * ```cangjie
 * let response = client.request(Method.Post, "https://api.example.com/items")
 *     .jsonObject(payload)
 *     .bearer(token)
 *     .timeout(Timeouts.standard().withTotal(Duration.second * 10))
 *     .send()
 * ```
 */
public class HttpClient <: Resource & ToString {
    private let configValue: ClientConfig
    private let listenerValue: ?EventListener
    private let interceptorList: ArrayList<Interceptor>
    private let cookieStore: ?CookieStore
    private let poolMutex: Mutex = Mutex()
    private var poolRef: ?ConnectionPool = None
    private var closedFlag: Bool = false

    internal init(config: ClientConfig, listener: ?EventListener, interceptors: ArrayList<Interceptor>) {
        this.configValue = config
        this.listenerValue = listener
        this.interceptorList = interceptors
        this.cookieStore = if (config.cookiesEnabled) { Some(CookieStore()) } else { None }
    }

    // ---------- 池 ----------

    private func pool(): ConnectionPool {
        synchronized(poolMutex) {
            var current = poolRef
            if (current.isNone()) {
                let created = ConnectionPool(
                    configValue.pool,
                    { poolKey, host => buildTransportClient(configValue, host) },
                    listenerValue,
                    configValue.health
                )
                poolRef = Some(created)
                current = Some(created)
            }
            current.getOrThrow()
        }
    }

    /** 连接池运行状态（长连接复用率、活跃请求数等）。 */
    public func poolStats(): PoolStats {
        pool().stats()
    }

    /** 主动关闭所有空闲连接组，返回被关闭的数量。 */
    public func closeIdleConnections(): Int64 {
        pool().closeIdle()
    }

    /** Cookie 存储；客户端未启用 Cookie 时为 None。 */
    public func cookies(): ?CookieStore {
        cookieStore
    }

    public func config(): ClientConfig {
        configValue
    }

    // ---------- 一行式请求 ----------

    public func get(url: String, headers!: ?Headers = None, timeouts!: ?Timeouts = None,
        retry!: ?RetryPolicy = None): Response {
        send(simpleRequest(Method.Get, url, None, headers, timeouts, retry))
    }

    public func head(url: String, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Head, url, None, headers, None, None))
    }

    public func options(url: String, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Options, url, None, headers, None, None))
    }

    public func delete(url: String, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Delete, url, None, headers, None, None))
    }

    public func post(url: String, body: String, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Post, url, Some(Body.text(body)), headers, None, None))
    }

    public func post(url: String, body: JsonValue, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Post, url, Some(Body.json(body)), headers, None, None))
    }

    public func post(url: String, body: JsonObject, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Post, url, Some(Body.json(body)), headers, None, None))
    }

    public func post(url: String, body: HashMap<String, String>, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Post, url, Some(Body.form(body)), headers, None, None))
    }

    public func post(url: String, body: Body, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Post, url, Some(body), headers, None, None))
    }

    public func put(url: String, body: String, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Put, url, Some(Body.text(body)), headers, None, None))
    }

    public func put(url: String, body: JsonObject, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Put, url, Some(Body.json(body)), headers, None, None))
    }

    public func put(url: String, body: Body, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Put, url, Some(body), headers, None, None))
    }

    public func patch(url: String, body: JsonObject, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Patch, url, Some(Body.json(body)), headers, None, None))
    }

    public func patch(url: String, body: Body, headers!: ?Headers = None): Response {
        send(simpleRequest(Method.Patch, url, Some(body), headers, None, None))
    }

    private func simpleRequest(method: Method, url: String, body: ?Body, headers: ?Headers,
        timeouts: ?Timeouts, retry: ?RetryPolicy): Request {
        let builder = RequestBuilder(method: method, url: url)
        if (let Some(value) <- headers) {
            builder.headers(value)
        }
        if (let Some(value) <- body) {
            builder.body(value)
        }
        if (let Some(value) <- timeouts) {
            builder.timeout(value)
        }
        if (let Some(value) <- retry) {
            builder.retry(value)
        }
        builder.build()
    }

    // ---------- 构建器入口 ----------

    public func request(method: Method, url: String): RequestBuilder {
        RequestBuilder(this, method, url)
    }

    /** 以 `URL` 对象起一个链式请求（与旧 API 的 `setUrl(URL)` 对齐）。 */
    public func request(method: Method, url: URL): RequestBuilder {
        RequestBuilder(this, method, url.toString())
    }

    /**
     * 建立 WebSocket 连接。
     *
     * WebSocket 会独占一条连接，因此这里用一个专用底层客户端（其余配置与当前客户端一致）；
     * 该连接随 `WebSocket.close()` 一起释放，不占用普通请求的连接池。
     */
    public func websocket(url: String, subProtocols!: Array<String> = Array<String>(),
        headers!: ?Headers = None): WebSocket {
        if (closedFlag) {
            throw HttpError(ErrorKind.Closed, "HttpClient 已关闭，无法建立 WebSocket", url: url)
        }
        let parsed = try {
            URL.parse(url)
        } catch (e: Exception) {
            throw HttpError(ErrorKind.Url, "无法解析 WebSocket URL：${e.message}", url: url)
        }
        let scheme = parsed.scheme.toString().toAsciiLower()
        if (scheme != "ws" && scheme != "wss") {
            throw HttpError(ErrorKind.Url,
                "WebSocket URL 必须以 ws:// 或 wss:// 开头，实际为 '${scheme}'", url: url)
        }
        let host = parsed.hostName.toString()
        let transport = buildTransportClient(configValue, host)
        let protocols = ArrayList<String>()
        for (protocol in subProtocols) {
            protocols.add(protocol)
        }
        let nativeHeaders = match (headers) {
            case Some(value) => value.native()
            case None => HttpHeaders()
        }
        let pair = NativeWebSocket.upgradeFromClient(transport, parsed,
            subProtocols: protocols, headers: nativeHeaders)
        WebSocket(pair[0], transport, url)
    }

    // ---------- 发送 ----------

    /** 发送请求；响应体按策略自动落地（小响应进内存，大响应保持流式）。 */
    public func send(request: Request): Response {
        execute(request, false)
    }

    /** 发送请求并强制保持响应体流式（大文件、SSE 等场景）。 */
    public func sendStream(request: Request): Response {
        execute(request, true)
    }

    /** 并发发送一批请求，返回顺序与入参一致；任一失败则整体抛错。 */
    public func sendAll(requests: Array<Request>): Array<Response> {
        let futures = ArrayList<Future<Response>>()
        for (request in requests) {
            let captured = request
            futures.add(spawn {
                =>
                send(captured)
            })
        }
        let results = ArrayList<Response>()
        for (future in futures) {
            results.add(future.get())
        }
        results.toArray()
    }

    /**
     * 发送请求，并**自己处理重定向**。
     *
     * 逐跳在这里做，而不是交给 stdx 的 `autoRedirect`：那个实现在跨域跳转时会沿用旧
     * `serverName`，跳到另一个域名后证书必然对不上（实测报 134）。
     * 这里每跳都重新构造请求、重新取传输客户端，于是 SNI 与主机名校验都按"这一跳"来。
     *
     * 重定向预算与重试共用一个循环：否则"每跳各自重试"会让实际尝试次数按跳数相乘。
     */
    private func execute(request: Request, forceStream: Bool): Response {
        var current = request
        var hop: Int64 = 0
        /*
         * 用有界循环而不是 `while (true)`：仓颉的类型检查器不认"循环体内必然 return"，
         * 会要求函数末尾也有返回值。写成 `hop <= MAX` 就让"超出层数"成为正常的循环出口。
         */
        while (hop <= MAX_REDIRECT_HOPS) {
            let response = executeOnce(current, forceStream)
            if (!configValue.followRedirects) {
                return response
            }
            let location = match (response.location) {
                case Some(value) => value
                case None => return response
            }
            /*
             * 3xx 之外一律不跳：`location` 出现在其它状态码上不构成重定向语义。
             * 303 一律降级成 GET，且丢掉请求体 —— 这是 HTTP 的明文规定。
             */
            let status = response.status
            let isRedirect = status == 301 || status == 302 || status == 303 || status == 307 || status == 308
            if (!isRedirect) {
                return response
            }
            if (hop == MAX_REDIRECT_HOPS) {
                response.close()
                throw HttpError(ErrorKind.Protocol, "重定向层数超过 ${MAX_REDIRECT_HOPS} 层", url: current.url)
            }
            let next = resolveRedirect(location, current.url)
            if (next.isEmpty()) {
                return response
            }
            /* 旧响应必须释放，否则连接池的槽位被它占着。 */
            response.close()
            /*
             * 构造下一跳的请求，**逐项带上原来那些请求头**。
             *
             * 用一个新的 builder 而不是复用 `RequestBuilder`：绑定客户端的那种构造器是 internal，
             * 而且这里只是"发一个同样的请求到新地址"，不需要原来的客户端绑定。
             *
             * 303 按 HTTP 规定降级成 GET 并丢掉请求体；其余状态码保持原方法。
             */
            let useGet = status == 303
            var builder = RequestBuilder(method: if (useGet) { Method.Get } else { current.method }, url: next)
            /* `Headers` 可迭代，每项是「名字 + 该名字下的一组值」。 */
            for ((name, values) in current.headers) {
                for (value in values) {
                    builder = builder.header(name, value)
                }
            }
            if (!useGet) {
                match (current.body) {
                    case Some(body) => builder = builder.body(body)
                    case None => ()
                }
            }
            current = builder.build()
            hop += 1
        }
        /* 循环正常出口只有"超出层数"一种，前面已经在相同条件下抛过错了；这里兜底。 */
        throw HttpError(ErrorKind.Protocol, "重定向层数超过 ${MAX_REDIRECT_HOPS} 层", url: current.url)
    }

    /** 单次发送（不含重定向），是 `execute` 每跳调用一次的那一层。 */
    private func executeOnce(request: Request, forceStream: Bool): Response {
        if (closedFlag) {
            throw HttpError(ErrorKind.Closed, "HttpClient 已关闭，无法继续发送请求", url: request.url)
        }
        let started = DateTime.now()
        var effective = request
        for (interceptor in interceptorList) {
            if (let Some(handler) <- interceptor.onRequest) {
                effective = handler(effective)
            }
        }
        let target = parseTarget(effective.url)
        let timeouts = mergeTimeouts(effective.timeouts)
        let deadline: ?DateTime = match (timeouts.total) {
            case Some(value) => Some(started + value)
            case None => None
        }
        let policy = match (effective.retry) {
            case Some(value) => value
            case None => configValue.retry
        }
        let streamingBody = match (effective.body) {
            case Some(value) => value.isStreaming()
            case None => false
        }
        let canRetry = policy.allowsMethod(effective.method, streamingBody)
        match (listenerValue) {
            case Some(handler) => handler.requestStart(effective)
            case None => ()
        }

        var attempt: Int64 = 1
        while (true) {
            var slot: ?PooledSlot = None
            var response: Response
            try {
                let acquired = pool().acquire(target.key, target.host, waitLimit: remaining(deadline))
                slot = Some(acquired)
                let native = buildNativeRequest(effective, target,
                    clampTimeouts(timeouts, remaining(deadline)))
                let raw = acquired.client.send(native)
                storeCookies(effective.url, raw)
                pool().noteSuccess(acquired)
                let captured = captureBody(raw, effective, forceStream, acquired)
                response = Response(raw, effective, attempt, DateTime.now() - started,
                    captured.buffered, captured.live, captured.release)
            } catch (e: Exception) {
                match (slot) {
                    case Some(held) =>
                        pool().noteFailure(held)
                        held.finish()
                    case None => ()
                }
                let error = match (e) {
                    // 池层抛出的 HttpError（例如熔断）已经是最终形态，保留分类与信息
                    case existing: HttpError => existing
                    case _ => wrapError(classifyException(e, false), effective.url, attempt, e)
                }
                let kind = error.kind
                if (canRetry && attempt < policy.maxAttempts && policy.allowsError(kind) &&
                    hasBudget(deadline)) {
                    let delay = policy.backoffFor(attempt)
                    pool().noteRetry()
                    emitRetry(effective, attempt, policy, kind.toString(), delay)
                    sleepSafely(delay)
                    attempt++
                    continue
                }
                match (listenerValue) {
                    case Some(handler) => handler.requestFailed(effective, error)
                    case None => ()
                }
                for (interceptor in interceptorList) {
                    if (let Some(handler) <- interceptor.onError) {
                        handler(effective, error)
                    }
                }
                throw error
            }

            // 状态码维度的重试（429/5xx 等）：必须先释放响应体才能重发
            if (canRetry && attempt < policy.maxAttempts && policy.allowsStatus(response.status) &&
                hasBudget(deadline)) {
                let delay = statusRetryDelay(policy, response, attempt)
                response.close()
                pool().noteRetry()
                emitRetry(effective, attempt, policy, "HTTP ${response.status}", delay)
                sleepSafely(delay)
                attempt++
                continue
            }

            let elapsed = DateTime.now() - started
            match (listenerValue) {
                case Some(handler) => handler.requestEnd(effective, response, elapsed)
                case None => ()
            }
            for (interceptor in interceptorList) {
                if (let Some(handler) <- interceptor.onResponse) {
                    handler(effective, response)
                }
            }
            return response
        }
        // 循环内所有分支都会 return/throw/continue，这里只是让类型检查器确定不会落到末尾
        throw HttpError(ErrorKind.RetryExhausted, "请求未完成且重试次数已耗尽", url: effective.url,
            attempts: attempt)
    }

    /** 把单次尝试的读写超时压到「总预算剩余时间」以内，让 totalTimeout 真正生效。 */
    private func clampTimeouts(base: Timeouts, budget: ?Duration): Timeouts {
        if (let Some(left) <- budget) {
            var result = base
            match (base.read) {
                case Some(value) => if (left < value) {
                    result = result.withRead(left)
                }
                case None => result = result.withRead(left)
            }
            match (base.write) {
                case Some(value) => if (left < value) {
                    result = result.withWrite(left)
                }
                case None => result = result.withWrite(left)
            }
            return result
        }
        base
    }

    private func mergeTimeouts(override: ?Timeouts): Timeouts {
        if (let Some(value) <- override) {
            return configValue.timeouts.mergedWith(value)
        }
        configValue.timeouts
    }

    private func remaining(deadline: ?DateTime): ?Duration {
        if (let Some(limit) <- deadline) {
            let left = limit - DateTime.now()
            if (left <= Duration.millisecond * 0) {
                return Some(Duration.millisecond * 1)
            }
            return Some(left)
        }
        None
    }

    private func hasBudget(deadline: ?DateTime): Bool {
        if (let Some(limit) <- deadline) {
            return DateTime.now() < limit
        }
        true
    }

    private func emitRetry(request: Request, attempt: Int64, policy: RetryPolicy, reason: String,
        delay: Duration): Unit {
        match (listenerValue) {
            case Some(handler) =>
                handler.retry(RetryEvent(request.url, request.method, attempt, policy.maxAttempts,
                    reason, delay))
            case None => ()
        }
    }

    private func statusRetryDelay(policy: RetryPolicy, response: Response, attempt: Int64): Duration {
        match (response.header("retry-after")) {
            case Some(value) =>
                match (policy.retryAfterDelay(value)) {
                    case Some(delay) => delay
                    case None => policy.backoffFor(attempt)
                }
            case None => policy.backoffFor(attempt)
        }
    }

    private func storeCookies(url: String, raw: HttpResponse): Unit {
        match (cookieStore) {
            case Some(store) => store.store(url, raw.headers.get("set-cookie"))
            case None => ()
        }
    }

    private func buildNativeRequest(request: Request, target: ParsedTarget,
        timeouts: Timeouts): HttpRequest {
        let builder = HttpRequestBuilder()
        builder.method(request.method.toString())
        let targetText = if (configValue.compensateTargetDecoding) {
            compensateTargetDecoding(target.rawText)
        } else {
            target.rawText
        }
        builder.url(targetText)
        let merged = configValue.defaultHeaders.copy()
        merged.set("user-agent", configValue.userAgent)
        for ((name, values) in request.headers) {
            for (value in values) {
                merged.set(name, value)
            }
        }
        match (cookieStore) {
            case Some(store) =>
                match (store.headerFor(request.url)) {
                    case Some(line) => merged.set("cookie", line)
                    case None => ()
                }
            case None => ()
        }
        if (let Some(body) <- request.body) {
            body.applyTo(builder)
            match (body.mediaType()) {
                case Some(mediaType) =>
                    if (!merged.contains("content-type")) {
                        merged.set("content-type", mediaType)
                    }
                case None => ()
            }
            if (body.isStreaming()) {
                match (body.contentLength()) {
                    case Some(length) => merged.set("content-length", "${length}")
                    case None => ()
                }
            }
        }
        if (configValue.acceptCompression && !merged.contains("accept-encoding")) {
            merged.set("accept-encoding", "gzip, deflate")
        }
        builder.setHeaders(merged.native())
        match (timeouts.read) {
            case Some(value) => builder.readTimeout(value)
            case None => builder.readTimeout(Duration.Max)
        }
        match (timeouts.write) {
            case Some(value) => builder.writeTimeout(value)
            case None => builder.writeTimeout(Duration.Max)
        }
        builder.build()
    }

    /**
     * 决定响应体怎么处理。
     *
     * - 强制/显式流式：直接挂流式租约；
     * - 已知长度且不超过阈值：立刻读进内存并归还槽位（保证连接一定被复用）；
     * - 长度未知：先最多读 `阈值+1` 字节，读得完就落地，读不完则「内存前缀 + 剩余流」；
     * - 已知长度且超过阈值：保持流式，交给调用方（`saveTo` / `stream`）。
     */
    private func captureBody(raw: HttpResponse, request: Request, forceStream: Bool,
        slot: PooledSlot): CapturedBody {
        let encoding = contentEncoding(raw)
        let source = wrapDecoding(raw.body, encoding)
        if (forceStream || request.streamResponse) {
            slot.toLease()
            return CapturedBody(None, Some(guardStream(source, slot)), Some({ => slot.endLease() }))
        }
        let limit = configValue.bodyBufferLimit
        // 压缩体的 Content-Length 是压缩后长度，不能用来判断解压后大小，只能按阈值试探读取
        if (encoding.isSome()) {
            let prefix = readUpTo(source, limit + 1)
            if (Int64(prefix.size) <= limit) {
                slot.finish()
                CapturedBody(Some(prefix), None, None)
            } else {
                slot.toLease()
                let combined = PrefixedStream(prefix, source, { => slot.endLease() })
                CapturedBody(None, Some(combined), Some({ => slot.endLease() }))
            }
        } else {
            match (declaredLength(raw)) {
                case Some(length) =>
                    if (length <= limit) {
                        let data = readStreamFully(source)
                        slot.finish()
                        CapturedBody(Some(data), None, None)
                    } else {
                        slot.toLease()
                        CapturedBody(None, Some(guardStream(source, slot)),
                            Some({ => slot.endLease() }))
                    }
                case None =>
                    let prefix = readUpTo(source, limit + 1)
                    if (Int64(prefix.size) <= limit) {
                        slot.finish()
                        CapturedBody(Some(prefix), None, None)
                    } else {
                        slot.toLease()
                        let combined = PrefixedStream(prefix, source, { => slot.endLease() })
                        CapturedBody(None, Some(combined), Some({ => slot.endLease() }))
                    }
            }
        }
    }

    private func declaredLength(raw: HttpResponse): ?Int64 {
        match (raw.headers.getFirst("content-length")) {
            case Some(value) => tryParseInt64(value.trimAscii())
            case None => raw.bodySize
        }
    }

    private func guardStream(source: InputStream, slot: PooledSlot): InputStream {
        BodyGuardStream(source, { => slot.endLease() })
    }

    public func close(): Unit {
        if (closedFlag) {
            return
        }
        closedFlag = true
        pool().close()
    }

    public func isClosed(): Bool {
        closedFlag
    }

    /** 以当前配置为基准派生一个可继续修改的 builder。 */
    public func derive(): HttpClientBuilder {
        let builder = HttpClientBuilder.from(configValue.copy())
        match (listenerValue) {
            case Some(value) => builder.listener(value)
            case None => ()
        }
        for (interceptor in interceptorList) {
            builder.intercept(interceptor)
        }
        builder
    }

    public func toString(): String {
        "HttpClient(${configValue.pool}, ${poolStats()})"
    }
}

/**
 * 客户端构建器。
 */
public class HttpClientBuilder {
    private let configValue: ClientConfig = ClientConfig()
    private var listenerValue: ?EventListener = None
    private let interceptorList: ArrayList<Interceptor> = ArrayList<Interceptor>()

    public init() {}

    internal static func from(config: ClientConfig): HttpClientBuilder {
        let builder = HttpClientBuilder()
        let target = builder.configValue
        target.timeouts = config.timeouts
        target.followRedirects = config.followRedirects
        target.defaultHeaders = config.defaultHeaders.copy()
        target.tls = config.tls
        target.pool = config.pool.copy()
        target.retry = config.retry
        target.http2 = config.http2
        target.bodyBufferLimit = config.bodyBufferLimit
        /*
         * 这几个字段原先漏了：`from` 是"用一份配置造 builder"，漏复制就静默沿用
         * `ClientConfig` 的默认值 —— 调用方设了也不生效。`compensateTargetDecoding`
         * 正是踩了这个坑（默认 true 是直连兜底，于是"显式关掉"永远无效）。
         */
        target.transportLogLevel = config.transportLogLevel
        target.compensateTargetDecoding = config.compensateTargetDecoding
        target.acceptCompression = config.acceptCompression
        target.health = config.health.copy()
        target.httpProxy = config.httpProxy
        target.httpsProxy = config.httpsProxy
        target.useEnvironmentProxy = config.useEnvironmentProxy
        target.cookiesEnabled = config.cookiesEnabled
        target.userAgent = config.userAgent
        builder
    }

    public func timeout(value: Timeouts): HttpClientBuilder {
        configValue.timeouts = value
        this
    }

    public func readTimeout(value: Duration): HttpClientBuilder {
        configValue.timeouts = configValue.timeouts.withRead(value)
        this
    }

    public func writeTimeout(value: Duration): HttpClientBuilder {
        configValue.timeouts = configValue.timeouts.withWrite(value)
        this
    }

    /** 整次请求（含重试）的总预算。 */
    public func totalTimeout(value: Duration): HttpClientBuilder {
        configValue.timeouts = configValue.timeouts.withTotal(value)
        this
    }

    /** TCP/TLS 建连超时（通过自定义 connector 实现）。 */
    public func connectTimeout(value: Duration): HttpClientBuilder {
        configValue.timeouts = configValue.timeouts.withConnect(value)
        this
    }

    public func followRedirects(value: Bool): HttpClientBuilder {
        configValue.followRedirects = value
        this
    }

    public func defaultHeaders(value: Headers): HttpClientBuilder {
        configValue.defaultHeaders = value
        this
    }

    public func header(name: String, value: String): HttpClientBuilder {
        configValue.defaultHeaders.set(name, value)
        this
    }

    public func userAgent(value: String): HttpClientBuilder {
        configValue.userAgent = value
        this
    }

    public func tls(value: TlsOptions): HttpClientBuilder {
        configValue.tls = value
        this
    }

    /** 信任所有证书（仅开发调试）。 */
    public func trustAllCertificates(): HttpClientBuilder {
        configValue.tls = TlsOptions.trustAll()
        this
    }

    public func proxy(http: String, https: String): HttpClientBuilder {
        configValue.httpProxy = Some(http)
        configValue.httpsProxy = Some(https)
        this
    }

    public func httpsProxy(value: String): HttpClientBuilder {
        configValue.httpsProxy = Some(value)
        this
    }

    public func httpProxy(value: String): HttpClientBuilder {
        configValue.httpProxy = Some(value)
        this
    }

    public func useEnvironmentProxy(value: Bool): HttpClientBuilder {
        configValue.useEnvironmentProxy = value
        this
    }

    /**
     * 关掉"请求目标百分号补偿"。
     *
     * 这个补偿是给直连兜底的（stdx 会把请求目标里的 `%5B` 再解码一次），但**经代理时不成立**：
     * 代理按原样转发，补偿反而把 `%` 变成 `%25`，线上真的发出双重编码。所以走代理时要关掉它。
     */
    public func compensateTargetDecoding(value: Bool): HttpClientBuilder {
        configValue.compensateTargetDecoding = value
        this
    }

    /** 完全不走代理（也忽略 `http_proxy` 等环境变量）。 */
    public func noProxy(): HttpClientBuilder {
        configValue.httpProxy = None
        configValue.httpsProxy = None
        configValue.useEnvironmentProxy = false
        this
    }

    public func pool(value: PoolOptions): HttpClientBuilder {
        configValue.pool = value
        this
    }

    public func maxConnectionsPerHost(value: Int64): HttpClientBuilder {
        configValue.pool.maxConnectionsPerHost = value
        this
    }

    /**
     * 空闲连接在池里存活多久（超过就关掉，把名额让出来）。
     *
     * 这个旋钮对"长时间连续下载"很关键。默认值是 **3 分钟**，而连接组的并发是"超出上限就排队"：
     * 一批请求跑完之后，那些连接**仍然占着名额**直到这个时间过去。于是下载进行到几分钟、池里攒满
     * 空闲连接之后，新请求全部被拒（`Too many connections to the same server!`），吞吐断崖式下跌
     * —— 实测：26.3 的资源阶段前 3 分钟每分钟完成 100–270 个文件、零拒绝，第 6 分钟起拒绝数暴涨到
     * 每分钟 ~100 次，末尾掉到 **27 个/分钟**。
     *
     * 连续小文件下载的场景里，连接复用主要发生在"相邻几个请求"之间，拉长到 3 分钟没有任何收益，
     * 只是把池占满。这类调用方应当把它调到几十秒以内。
     */
    public func idleConnectionTimeout(value: Duration): HttpClientBuilder {
        configValue.pool.idleTimeout = value
        this
    }

    /** 熔断/健康策略（默认关闭）。 */
    public func healthPolicy(value: HealthPolicy): HttpClientBuilder {
        configValue.health = value.copy()
        this
    }

    public func retry(value: RetryPolicy): HttpClientBuilder {
        configValue.retry = value
        this
    }

    public func noRetry(): HttpClientBuilder {
        configValue.retry = RetryPolicy.none()
        this
    }

    /** 是否在请求里声明 Accept-Encoding 并透明解压响应体（默认开启）。 */
    public func acceptCompression(value: Bool): HttpClientBuilder {
        configValue.acceptCompression = value
        this
    }

    public func cookies(enabled: Bool): HttpClientBuilder {
        configValue.cookiesEnabled = enabled
        this
    }

    public func http2(value: Http2Options): HttpClientBuilder {
        configValue.http2 = value
        this
    }

    /** 超过该大小的响应体不再自动进内存。 */
    public func bodyBufferLimit(value: Int64): HttpClientBuilder {
        configValue.bodyBufferLimit = value
        this
    }

    public func listener(value: EventListener): HttpClientBuilder {
        listenerValue = Some(value)
        this
    }

    public func intercept(value: Interceptor): HttpClientBuilder {
        interceptorList.add(value)
        this
    }

    public func build(): HttpClient {
        let interceptors = ArrayList<Interceptor>()
        for (interceptor in interceptorList) {
            interceptors.add(interceptor)
        }
        HttpClient(configValue.copy(), listenerValue, interceptors)
    }
}

/*
 * 全局共享客户端：供 LinderHttp.* 一行式接口使用。
 * 独立成类是为了让静态可变状态集中在一处，便于 shutdown。
 *
 * 另外承载一份**全局配置覆盖**（见 [GlobalConfig]）：`LinderHttp.configure()` 写进来，
 * 共享客户端重建时用它。有了这层，使用方可以在运行期改代理/超时，而不必自己建客户端。
 */
internal class SharedClients {
    private static let mutex = Mutex()
    private static var instance: ?HttpClient = None

    internal static func shared(): HttpClient {
        synchronized(mutex) {
            var needCreate = true
            match (instance) {
                case Some(client) => if (!client.isClosed()) {
                    needCreate = false
                }
                case None => ()
            }
            if (needCreate) {
                instance = Some(GlobalConfig.builderFor().build())
            }
        }
        match (instance) {
            case Some(client) => client
            case None => throw HttpError(ErrorKind.Closed, "共享 HttpClient 初始化失败")
        }
    }

    internal static func shutdown(): Unit {
        synchronized(mutex) {
            match (instance) {
                case Some(existing) => existing.close()
                case None => ()
            }
            instance = None
        }
    }

    /**
     * 改全局配置并让共享客户端**下次重建**。
     *
     * 只关旧的、不立即建新的：此刻可能正有请求在用旧连接，立即替换会让它们的池作废。
     * 下一次 `shared()` 会用新配置建一个，在此之前旧请求还能正常收尾。
     */
    internal static func invalidate(): Unit {
        synchronized(mutex) {
            match (instance) {
                case Some(existing) => existing.close()
                case None => ()
            }
            instance = None
        }
    }
}

/**
 * 全局配置覆盖。
 *
 * 为什么需要它：`SharedClients` 只建一次客户端（连接池、Cookie、重试策略都在里面），
 * 一旦建好就再也改不了代理。而"用户中途改了代理设置"是真实需求，所以必须有一个能改、
 * 且能让共享客户端重建的入口。
 *
 * 未设置时行为与以前完全一致（`HttpClientBuilder()` 的默认配置）。
 */
internal class GlobalConfig {
    private static let mutex = Mutex()
    private static var override: ?ClientConfig = None

    internal static func set(config: ClientConfig): Unit {
        synchronized(mutex) {
            override = Some(config.copy())
        }
    }

    /** 当前配置快照；没有覆盖时返回 None。 */
    internal static func current(): ?ClientConfig {
        synchronized(mutex) {
            match (override) {
                case Some(config) => Some(config.copy())
                case None => None
            }
        }
    }

    /** 建一个 builder：有覆盖就用覆盖配置，否则默认。 */
    internal static func builderFor(): HttpClientBuilder {
        match (current()) {
            case Some(config) => HttpClientBuilder.from(config)
            case None => HttpClientBuilder()
        }
    }
}

// ---------- 内部工具 ----------

/**
 * 补偿底层传输层对请求目标的百分号解码（详见 ClientConfig.compensateTargetDecoding）。
 *
 * 只处理 scheme://authority 之后的路径与查询部分，authority 原样保留。
 */
internal func compensateTargetDecoding(urlText: String): String {
    var splitAt = urlText.size
    if (let Some(firstSlash) <- urlText.indexOf('/')) {
        let rest = urlText[(firstSlash + 1)..]
        if (let Some(secondSlash) <- rest.indexOf('/')) {
            splitAt = firstSlash + 1 + secondSlash
        }
    }
    let head = urlText[0..splitAt]
    if (splitAt >= urlText.size) {
        return head
    }
    let tail = urlText[splitAt..]
    head + tail.replace("%", "%25")
}

/** 响应体的内容编码（小写）；无则 None。 */
internal func contentEncoding(raw: HttpResponse): ?String {
    match (raw.headers.getFirst("content-encoding")) {
        case Some(value) =>
            let normalized = value.trimAscii().toAsciiLower()
            if (normalized.isEmpty() || normalized == "identity") {
                None
            } else {
                Some(normalized)
            }
        case None => None
    }
}

/**
 * 按 Content-Encoding 包一层解压流。
 *
 * 实测底层传输层不会自动解压（声明 gzip 后拿到的是原始压缩字节），
 * 所以这里显式接管：gzip / deflate 走 stdx 的流式解压，其余编码原样透传。
 */
internal func wrapDecoding(source: InputStream, encoding: ?String): InputStream {
    match (encoding) {
        case Some(value) =>
            match (value) {
                case "gzip" => DecompressInputStream(source, wrap: GzipFormat)
                case "deflate" => DecompressInputStream(source, wrap: DeflateFormat)
                case _ => source
            }
        case None => source
    }
}

internal func parseTarget(urlText: String): ParsedTarget {
    let parsed = try {
        URL.parse(urlText)
    } catch (e: Exception) {
        throw HttpError(ErrorKind.Url, "无法解析 URL：${e.message}", url: urlText)
    }
    let scheme = parsed.scheme.toString().toAsciiLower()
    if (scheme != "http" && scheme != "https") {
        throw HttpError(ErrorKind.Url, "只支持 http/https，实际为 '${scheme}'", url: urlText)
    }
    let host = parsed.hostName.toString()
    if (host.isEmpty()) {
        throw HttpError(ErrorKind.Url, "URL 缺少主机名", url: urlText)
    }
    var port = parsed.port.toString()
    if (port.isEmpty()) {
        port = if (scheme == "https") { "443" } else { "80" }
    }
    ParsedTarget("${scheme}://${host}:${port}", host, parsed, urlText, scheme, port)
}

/**
 * 把 `Location` 解析成绝对 URL。
 *
 * 三种形态都要认，缺一种就会在真实站点上翻车：
 *   - 绝对 URL（`https://cdn-alt.modrinth.com/...`）—— 直接用；
 *   - 绝对路径（`/data/x.png`）—— 换到当前 origin 下；
 *   - 相对路径（`x.png` / `../x.png`）—— 相对当前 URL 的**目录**解析。
 *
 * 解析不出来返回空串，由调用方把原响应交回去（总比抛一个看不懂的错强）。
 */
internal func resolveRedirect(location: String, baseUrl: String): String {
    let target = location.trimAscii()
    if (target.isEmpty()) {
        return ""
    }
    if (target.startsWith("http://") || target.startsWith("https://")) {
        return target
    }
    /* 当前 URL 的 origin：`scheme://host[:port]`。 */
    let schemeEnd = baseUrl.indexOf("://")
    let originEnd = if (schemeEnd.isSome()) {
        schemeEnd.getOrThrow() + 3
    } else {
        0
    }
    let afterOrigin = baseUrl[originEnd..]
    let authorityEnd = match (afterOrigin.indexOf("/")) {
        case Some(position) => originEnd + position
        case None => baseUrl.size
    }
    let origin = baseUrl[0..authorityEnd]
    if (target.startsWith("/")) {
        return "${origin}${target}"
    }
    /* 相对路径：取当前 URL 最后一个 `/` 之前的部分作为目录。 */
    let pathStart = authorityEnd
    let slash = baseUrl.lastIndexOf("/")
    let directory = match (slash) {
        case Some(position) =>
            if (position >= pathStart) {
                baseUrl[0..position]
            } else {
                "${origin}/"
            }
        case None => "${origin}/"
    }
    "${directory}/${target}"
}

/**
 * 按客户端配置构造底层 stdx 客户端。
 *
 * 注意两点实测结论：
 * 1. stdx 对 https 必须显式提供 `tlsConfig`，否则抛
 *    `HttpException: TLS must be configured when HTTPS requests are sent.`；
 * 2. 它的 `serverName` 不会自动填，必须逐 host 设置，否则 SNI 缺失会导致握手失败。
 */
internal func buildTransportClient(config: ClientConfig, host: String): Client {
    var builder = ClientBuilder()
    /*
     * 传输层日志：落点由 `HttpLogger.sink` 决定（默认丢弃），级别由本客户端显式指定。
     * 原先这里写死 `SimpleLogger(getStdOut())`，于是即使级别是 OFF，宿主的标准输出也被库选作了落点 ——
     * 一旦它被重定向到文件，框架日志就混进了宿主的日志里。
     */
    builder.logger(HttpLogger.logger(config.transportLogLevel))
    builder.tlsConfig(config.tls.materialize(host, config.http2.enabled))
    /*
     * **底层永远不自动重定向**，重定向由本库自己在 `execute` 里逐跳做。
     *
     * 原因是 stdx 的自动重定向有一个致命缺陷：跨域跳转时它**沿用发起请求时那个 `serverName`**
     * （SNI 与主机名校验都用它），于是跳到另一个域名后证书必然对不上。实测同一进程内对比：
     *
     *   autoRedirect(true)  + SNI  ->  TLS 握手失败 certificate verify failed (134)
     *   autoRedirect(true)  无 SNI  ->  TLS 握手失败 handshake failure (1040)
     *   autoRedirect(false) 手动逐跳 -> 307 正常拿到
     *
     * 这不是理论问题：Modrinth 的图标 CDN（`cdn.modrinth.com` 307 跳到 `cdn-alt.modrinth.com`）
     * 正因此完全下不动。自己逐跳之后，每一跳都按**该跳的 host** 取传输客户端
     * （见 `buildTransportClient` 的注释），SNI 与校验自然都对。
     */
    builder.autoRedirect(false)
    match (config.timeouts.read) {
        case Some(value) => builder.readTimeout(value)
        case None => builder.readTimeout(Duration.Max)
    }
    match (config.timeouts.write) {
        case Some(value) => builder.writeTimeout(value)
        case None => builder.writeTimeout(Duration.Max)
    }
    builder.poolSize(config.pool.maxConnectionsPerHost)
    // Cookie 由本库自己管理，关掉 stdx 的 CookieJar，避免两套状态打架
    builder.cookieJar(None)
    if (config.http2.enabled) {
        builder.enablePush(config.http2.enablePush)
        builder.initialWindowSize(config.http2.initialWindowSize)
        builder.headerTableSize(config.http2.headerTableSize)
    }
    match (config.httpProxy) {
        case Some(value) => builder.httpProxy(value)
        case None =>
            if (!config.useEnvironmentProxy) {
                builder.noProxy()
            }
    }
    match (config.httpsProxy) {
        case Some(value) => builder.httpsProxy(value)
        case None => ()
    }
    if (let Some(connectTimeout) <- config.timeouts.connect) {
        // 自定义 connector 是 stdx 里唯一能表达「建连超时」的位置
        let connector = {
            address: SocketAddress =>
            let socket = TcpSocket(address)
            socket.connect(timeout: connectTimeout)
            socket
        }
        builder.connector(connector)
    }
    builder.build()
}

internal func readUpTo(source: InputStream, limit: Int64): Array<Byte> {
    let buffer = ByteBuffer()
    let chunk = Array<Byte>(8192, repeat: 0)
    var total: Int64 = 0
    while (total <= limit) {
        let count = source.read(chunk)
        if (count <= 0) {
            break
        }
        buffer.write(chunk[0..count])
        total += count
    }
    buffer.bytes()
}

internal func sleepSafely(duration: Duration): Unit {
    if (duration <= Duration.millisecond * 0) {
        return
    }
    sleep(duration)
}
