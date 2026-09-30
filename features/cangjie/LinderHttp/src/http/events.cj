package linderHttp.http

/**
 * 一次重试发生时的事件。
 */
public class RetryEvent <: ToString {
    public let url: String
    public let method: Method
    /** 刚失败的是第几次尝试。 */
    public let attempt: Int64
    public let maxAttempts: Int64
    /** 本次失败原因（人类可读）。 */
    public let reason: String
    /** 即将等待的时长。 */
    public let delay: Duration

    public init(url: String, method: Method, attempt: Int64, maxAttempts: Int64, reason: String,
        delay: Duration) {
        this.url = url
        this.method = method
        this.attempt = attempt
        this.maxAttempts = maxAttempts
        this.reason = reason
        this.delay = delay
    }

    public func toString(): String {
        "${method} ${url} attempt=${attempt}/${maxAttempts} ${reason} wait=${delay}"
    }
}

/**
 * 全生命周期事件监听（可观测性）。
 *
 * 连接池的三类事件是验证「长连接是否真的被复用」最直接的证据：
 * - `onConnectionCreated`：为某个 host 新建了连接组（首次访问，必然要握手）；
 * - `onConnectionReused`：复用了已有连接组（第二次访问同一 host 应当命中）；
 * - `onConnectionEvicted`：空闲超时/超过 host 上限，连接组被回收。
 *
 * 所有回调都在请求线程上同步执行，应保持轻量、不要回调本客户端。
 */
public class EventListener {
    public let onRequestStart: ?(Request) -> Unit
    public let onRetry: ?(RetryEvent) -> Unit
    public let onRequestEnd: ?(Request, Response, Duration) -> Unit
    public let onRequestFailed: ?(Request, HttpError) -> Unit
    public let onConnectionCreated: ?(String) -> Unit
    public let onConnectionReused: ?(String) -> Unit
    public let onConnectionEvicted: ?(String) -> Unit

    public init(
        onRequestStart!: ?(Request) -> Unit = None,
        onRetry!: ?(RetryEvent) -> Unit = None,
        onRequestEnd!: ?(Request, Response, Duration) -> Unit = None,
        onRequestFailed!: ?(Request, HttpError) -> Unit = None,
        onConnectionCreated!: ?(String) -> Unit = None,
        onConnectionReused!: ?(String) -> Unit = None,
        onConnectionEvicted!: ?(String) -> Unit = None) {
        this.onRequestStart = onRequestStart
        this.onRetry = onRetry
        this.onRequestEnd = onRequestEnd
        this.onRequestFailed = onRequestFailed
        this.onConnectionCreated = onConnectionCreated
        this.onConnectionReused = onConnectionReused
        this.onConnectionEvicted = onConnectionEvicted
    }

    internal func requestStart(request: Request): Unit {
        if (let Some(handler) <- onRequestStart) {
            handler(request)
        }
    }

    internal func retry(event: RetryEvent): Unit {
        if (let Some(handler) <- onRetry) {
            handler(event)
        }
    }

    internal func requestEnd(request: Request, response: Response, elapsed: Duration): Unit {
        if (let Some(handler) <- onRequestEnd) {
            handler(request, response, elapsed)
        }
    }

    internal func requestFailed(request: Request, error: HttpError): Unit {
        if (let Some(handler) <- onRequestFailed) {
            handler(request, error)
        }
    }

    internal func connectionCreated(hostKey: String): Unit {
        if (let Some(handler) <- onConnectionCreated) {
            handler(hostKey)
        }
    }

    internal func connectionReused(hostKey: String): Unit {
        if (let Some(handler) <- onConnectionReused) {
            handler(hostKey)
        }
    }

    internal func connectionEvicted(hostKey: String): Unit {
        if (let Some(handler) <- onConnectionEvicted) {
            handler(hostKey)
        }
    }
}

/**
 * 拦截器。
 *
 * 与 OkHttp 的「责任链」不同，这里刻意做成三个简单钩子：
 * - `onRequest` 可以在发送前改写请求（加签名、加租户头）；
 * - `onResponse` 观察最终响应（只在请求成功返回时触发一次）；
 * - `onError` 观察最终失败（重试全部失败后触发一次）。
 *
 * 一个请求只触发一次，不会在每次重试时重复触发，便于做「一次业务 = 一条日志」。
 */
public class Interceptor {
    public let onRequest: ?(Request) -> Request
    public let onResponse: ?(Request, Response) -> Unit
    public let onError: ?(Request, HttpError) -> Unit

    public init(onRequest!: ?(Request) -> Request = None,
        onResponse!: ?(Request, Response) -> Unit = None,
        onError!: ?(Request, HttpError) -> Unit = None) {
        this.onRequest = onRequest
        this.onResponse = onResponse
        this.onError = onError
    }
}
