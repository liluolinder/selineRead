package linderHttp.http

/**
 * 重试策略。
 *
 * 三条原则：
 * 1. **默认只重试幂等方法**（GET/HEAD/PUT/DELETE/OPTIONS/TRACE），POST/PATCH 需要显式开启；
 * 2. **流式请求体默认不重试**（流已被读过一次，重发需要重新构造）；
 * 3. **指数退避 + 抖动**，避免大量客户端在同一时刻一起重发（惊群）。
 *
 * 另外会遵守响应里的 `Retry-After`（429/503 常见），但不超过 `maxBackoff`。
 */
public class RetryPolicy <: ToString {
    /** 最大尝试次数，含首次。1 表示不重试。 */
    public let maxAttempts: Int64
    /** 首次退避时长。 */
    public let initialBackoff: Duration
    /** 退避上限。 */
    public let maxBackoff: Duration
    /** 退避倍率。 */
    public let multiplier: Float64
    /** 抖动比例，0.25 表示实际退避在 ±25% 之间浮动。 */
    public let jitterRatio: Float64
    public let retryOnTimeout: Bool
    public let retryOnTransport: Bool
    public let retryOnPoolBusy: Bool
    /** 这些状态码会触发重试。 */
    public let retryOnStatus: Array<UInt16>
    /** 非幂等方法是否也重试。 */
    public let retryNonIdempotent: Bool
    /** 是否遵守 Retry-After 响应头。 */
    public let honorRetryAfter: Bool

    public init(maxAttempts!: Int64 = 3, initialBackoff!: Duration = Duration.millisecond * 200,
        maxBackoff!: Duration = Duration.second * 10, multiplier!: Float64 = 2.0,
        jitterRatio!: Float64 = 0.25, retryOnTimeout!: Bool = true, retryOnTransport!: Bool = true,
        retryOnPoolBusy!: Bool = true, retryOnStatus!: Array<UInt16> = [429, 502, 503, 504],
        retryNonIdempotent!: Bool = false, honorRetryAfter!: Bool = true) {
        this.maxAttempts = if (maxAttempts < 1) { 1 } else { maxAttempts }
        this.initialBackoff = initialBackoff
        this.maxBackoff = maxBackoff
        this.multiplier = multiplier
        this.jitterRatio = jitterRatio
        this.retryOnTimeout = retryOnTimeout
        this.retryOnTransport = retryOnTransport
        this.retryOnPoolBusy = retryOnPoolBusy
        this.retryOnStatus = retryOnStatus
        this.retryNonIdempotent = retryNonIdempotent
        this.honorRetryAfter = honorRetryAfter
    }

    /** 不重试。 */
    public static func none(): RetryPolicy {
        RetryPolicy(maxAttempts: 1, retryOnStatus: [])
    }

    /** 默认：3 次尝试、200ms 起步、2 倍增长、25% 抖动。 */
    public static func standard(): RetryPolicy {
        RetryPolicy()
    }

    /** 弱网/移动网络：更多次数、更长退避。 */
    public static func robust(): RetryPolicy {
        RetryPolicy(maxAttempts: 5, initialBackoff: Duration.millisecond * 300,
            maxBackoff: Duration.second * 20, jitterRatio: 0.35,
            retryOnStatus: [408, 425, 429, 500, 502, 503, 504])
    }

    /** 该方法 + 该请求体能否重试。 */
    internal func allowsMethod(method: Method, streamingBody: Bool): Bool {
        if (maxAttempts <= 1) {
            return false
        }
        if (streamingBody) {
            return false
        }
        if (method.isIdempotent()) {
            return true
        }
        retryNonIdempotent
    }

    internal func allowsError(kind: ErrorKind): Bool {
        match (kind) {
            case Timeout => retryOnTimeout
            case Connect => retryOnTransport
            case Transport => retryOnTransport
            case Protocol => retryOnTransport
            case PoolBusy => retryOnPoolBusy
            case _ => false
        }
    }

    internal func allowsStatus(status: UInt16): Bool {
        for (candidate in retryOnStatus) {
            if (candidate == status) {
                return true
            }
        }
        false
    }

    /**
     * 第 `attempt` 次失败之后应该等多久（attempt 从 1 开始）。
     */
    internal func backoffFor(attempt: Int64): Duration {
        var millis = Float64(initialBackoff.toMilliseconds())
        var step = 1
        while (step < attempt) {
            millis = millis * multiplier
            step++
        }
        let cap = Float64(maxBackoff.toMilliseconds())
        if (millis > cap) {
            millis = cap
        }
        if (jitterRatio > 0.0) {
            let rng = Random()
            let factor = 1.0 + (rng.nextFloat64() * 2.0 - 1.0) * jitterRatio
            millis = millis * factor
        }
        if (millis < 0.0) {
            millis = 0.0
        }
        Duration.millisecond * Int64(millis)
    }

    /** 解析 Retry-After：支持秒数与 HTTP 日期两种形式，超出上限时截断。 */
    internal func retryAfterDelay(headerValue: String): ?Duration {
        if (!honorRetryAfter) {
            return None
        }
        let trimmed = headerValue.trimAscii()
        let seconds = try {
            Int64.parse(trimmed)
        } catch (_: Exception) {
            -1
        }
        if (seconds < 0) {
            return None
        }
        var delay = Duration.second * seconds
        if (delay > maxBackoff) {
            delay = maxBackoff
        }
        Some(delay)
    }

    public func toString(): String {
        "RetryPolicy(maxAttempts=${maxAttempts}, backoff=${initialBackoff}~${maxBackoff}, status=${retryOnStatus})"
    }
}
