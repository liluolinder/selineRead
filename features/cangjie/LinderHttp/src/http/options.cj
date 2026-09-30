package linderHttp.http

/**
 * 超时设置。
 *
 * 三类超时分别对应不同阶段，都取「宁可失败也不要挂死」的默认值：
 * - `connect`：TCP（含 TLS 握手）建连上限，靠自定义 connector 实现；
 * - `read`/`write`：单次读写上限，直接交给底层；
 * - `total`：一次逻辑请求（含重试与退避）的总预算，由引擎在重试前检查。
 */
public class Timeouts <: ToString {
    public let connect: ?Duration
    public let read: ?Duration
    public let write: ?Duration
    public let total: ?Duration

    public init(connect!: ?Duration = None, read!: ?Duration = None, write!: ?Duration = None,
        total!: ?Duration = None) {
        this.connect = connect
        this.read = read
        this.write = write
        this.total = total
    }

    /** 默认：建连 10s、读写 30s、总预算 120s。 */
    public static func standard(): Timeouts {
        Timeouts(connect: Duration.second * 10, read: Duration.second * 30,
            write: Duration.second * 30, total: Duration.second * 120)
    }

    /** 不设任何超时（极端场景，例如超大文件下载）。 */
    public static func unlimited(): Timeouts {
        Timeouts()
    }

    public static func of(read!: Duration, write!: Duration): Timeouts {
        Timeouts(read: read, write: write)
    }

    public func withConnect(value: Duration): Timeouts {
        Timeouts(connect: Some(value), read: read, write: write, total: total)
    }

    public func withRead(value: Duration): Timeouts {
        Timeouts(connect: connect, read: Some(value), write: write, total: total)
    }

    public func withWrite(value: Duration): Timeouts {
        Timeouts(connect: connect, read: read, write: Some(value), total: total)
    }

    public func withTotal(value: Duration): Timeouts {
        Timeouts(connect: connect, read: read, write: write, total: Some(value))
    }

    /** 用请求级设置覆盖客户端设置；None 的项保留原值。 */
    internal func mergedWith(override: Timeouts): Timeouts {
        Timeouts(
            connect: if (override.connect.isSome()) { override.connect } else { connect },
            read: if (override.read.isSome()) { override.read } else { read },
            write: if (override.write.isSome()) { override.write } else { write },
            total: if (override.total.isSome()) { override.total } else { total }
        )
    }

    /** 连接池键的一部分：建连超时改变的是 connector，必须分池。 */
    internal func connectKey(): String {
        match (connect) {
            case Some(value) => "${value.toMilliseconds()}"
            case None => "-"
        }
    }

    public func toString(): String {
        "Timeouts(connect=${connect}, read=${read}, write=${write}, total=${total})"
    }
}

/**
 * HTTP/2 相关开关（客户端级）。
 */
public class Http2Options <: ToString {
    public let enabled: Bool
    public let enablePush: Bool
    public let initialWindowSize: UInt32
    public let headerTableSize: UInt32

    public init(enabled!: Bool = true, enablePush!: Bool = false,
        initialWindowSize!: UInt32 = 65535, headerTableSize!: UInt32 = 4096) {
        this.enabled = enabled
        this.enablePush = enablePush
        this.initialWindowSize = initialWindowSize
        this.headerTableSize = headerTableSize
    }

    public static func standard(): Http2Options {
        Http2Options()
    }

    internal func key(): String {
        "${enabled}:${enablePush}:${initialWindowSize}:${headerTableSize}"
    }

    public func toString(): String {
        "Http2Options(enabled=${enabled}, push=${enablePush}, window=${initialWindowSize}, table=${headerTableSize})"
    }
}

/**
 * 连接池参数。
 *
 * 本库的池是「每个 host 一组长连接 + 每 host 并发闸门」：
 * - `maxConnectionsPerHost` 同时是 stdx 的连接池上限与本库的并发上限。
 *   这一点很关键：stdx 在并发超过 poolSize 时会直接抛
 *   `HttpException: Too many connections to the same server!`，
 *   而本库改为「排队等待 + 超时报错」，把异常变成可预期的等待。
 * - `idleTimeout`：某个 host 空闲超过该时长就关闭它的连接，避免长期占资源。
 * - `maxHosts`：最多同时持有多少个 host 的连接组，超出后按 LRU 淘汰空闲组。
 * - `liveLeaseTimeout`：流式响应体的租约上限，防止调用方忘记读完导致槽位泄漏。
 */
public class PoolOptions <: ToString {
    public var maxConnectionsPerHost: Int64 = 32
    public var idleTimeout: Duration = Duration.minute * 3
    public var maxHosts: Int64 = 64
    public var acquireTimeout: Duration = Duration.second * 30
    public var liveLeaseTimeout: Duration = Duration.minute * 5

    public init() {}

    public static func standard(): PoolOptions {
        PoolOptions()
    }

    /** 小并发场景（移动端/单线程脚本）。 */
    public static func small(): PoolOptions {
        let options = PoolOptions()
        options.maxConnectionsPerHost = 8
        options.maxHosts = 16
        options
    }

    public func copy(): PoolOptions {
        let clone = PoolOptions()
        clone.maxConnectionsPerHost = maxConnectionsPerHost
        clone.idleTimeout = idleTimeout
        clone.maxHosts = maxHosts
        clone.acquireTimeout = acquireTimeout
        clone.liveLeaseTimeout = liveLeaseTimeout
        clone
    }

    public func toString(): String {
        "PoolOptions(maxPerHost=${maxConnectionsPerHost}, idle=${idleTimeout}, maxHosts=${maxHosts})"
    }
}

/**
 * 熔断（健康）策略。
 *
 * 只统计**传输层失败**（建连失败、超时、连接中断），不把 4xx/5xx 算进去——
 * 服务端明确回了状态码，说明它是活的，压它反而是对的。
 *
 * 连续失败达到 `failureThreshold` 后进入冷却：冷却期内对该 host 的请求直接快速失败
 * （`ErrorKind.CircuitOpen`），不再白等一次建连超时；冷却结束放行下一次请求作为探测，
 * 成功即清零恢复。
 *
 * 默认**关闭**：库不该在没有明确意愿时改变请求的到达性。
 */
public class HealthPolicy {
    public var enabled: Bool = false
    /** 连续失败多少次后熔断 */
    public var failureThreshold: Int64 = 5
    /** 熔断冷却时长 */
    public var cooldown: Duration = Duration.second * 10

    public init() {}

    public static func disabled(): HealthPolicy {
        HealthPolicy()
    }

    public static func standard(): HealthPolicy {
        let policy = HealthPolicy()
        policy.enabled = true
        policy
    }

    public func copy(): HealthPolicy {
        let clone = HealthPolicy()
        clone.enabled = enabled
        clone.failureThreshold = if (failureThreshold < 1) { 1 } else { failureThreshold }
        clone.cooldown = cooldown
        clone
    }

    public func toString(): String {
        "HealthPolicy(enabled=${enabled}, threshold=${failureThreshold}, cooldown=${cooldown})"
    }
}

/**
 * 一次「客户端」的全部可调项。
 *
 * `HttpClientBuilder` 只是把它逐项改好再交给 `HttpClient`；`HttpClient` 内部持有它的副本，
 * 之后外部再改 builder 也不会影响已建好的客户端（不可变客户端语义）。
 */
public class ClientConfig {
    public var timeouts: Timeouts = Timeouts.standard()
    public var followRedirects: Bool = true
    public var defaultHeaders: Headers = Headers.standard()
    public var tls: TlsOptions = TlsOptions.system()
    public var pool: PoolOptions = PoolOptions.standard()
    public var retry: RetryPolicy = RetryPolicy.standard()
    public var http2: Http2Options = Http2Options.standard()
    /** 超过该大小的响应体不再自动读进内存，而是交给调用方流式消费。 */
    public var bodyBufferLimit: Int64 = 1024 * 1024
    /**
     * 是否在请求里声明 Accept-Encoding: gzip, deflate 并透明解压响应体。
     *
     * 底层传输层不会自动解压，所以解压由本库负责：已落地内存的响应一次性解压，
     * 流式响应则包一层解压流；由于压缩后长度不可信，解压读取始终按 bodyBufferLimit 设上限，
     * 避免压缩炸弹把内存吃光。
     */
    public var acceptCompression: Bool = true
    /**
     * 补偿底层传输层对「请求目标」的百分号解码。
     *
     * 实测仓颉 1.2.0 的 stdx：把 `?q=a%20b` 交出去，线路上写的是 `?q=a b`（服务端 505），
     * `%2F` 会变 `/`、`%26` 会变 `&`，语义直接被破坏。开启本项后本库会把路径/查询里
     * 已有的 `%` 再转义一次，底层解码一次后线路上恰好是正确的 `%xx`。
     * 如果将来工具链修好了这个问题，把它置为 false 即可。
     */
    public var compensateTargetDecoding: Bool = true
    /** 底层 stdx 传输层日志级别；默认关闭，避免框架日志污染业务输出。 */
    public var transportLogLevel: LogLevel = LogLevel.OFF
    public var httpProxy: ?String = None
    public var httpsProxy: ?String = None
    /** 未显式配置代理时，是否读取 http_proxy / https_proxy 环境变量。 */
    public var useEnvironmentProxy: Bool = true
    public var health: HealthPolicy = HealthPolicy.disabled()
    public var cookiesEnabled: Bool = true
    public var userAgent: String = Headers.defaultUserAgent()

    public init() {}

    public func copy(): ClientConfig {
        let clone = ClientConfig()
        clone.timeouts = timeouts
        clone.followRedirects = followRedirects
        clone.defaultHeaders = defaultHeaders.copy()
        clone.tls = tls
        clone.pool = pool.copy()
        clone.retry = retry
        clone.http2 = http2
        clone.bodyBufferLimit = bodyBufferLimit
        clone.transportLogLevel = transportLogLevel
        clone.compensateTargetDecoding = compensateTargetDecoding
        clone.acceptCompression = acceptCompression
        clone.httpProxy = httpProxy
        clone.httpsProxy = httpsProxy
        clone.useEnvironmentProxy = useEnvironmentProxy
        clone.health = health.copy()
        clone.cookiesEnabled = cookiesEnabled
        clone.userAgent = userAgent
        clone
    }

}
