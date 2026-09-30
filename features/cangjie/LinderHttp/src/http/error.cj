package linderHttp.http

/**
 * 失败原因分类。
 *
 * 分类的价值在于：重试策略只对「可能自愈」的类别生效，而不是见到异常就重试。
 */
public enum ErrorKind <: ToString {
    /** URL 非法或缺少协议头 */
    | Url
    /** TCP/TLS 建连失败 */
    | Connect
    /** 超时（连接、读写或总超时） */
    | Timeout
    /** 连接建立之后传输中断 */
    | Transport
    /** 协议层错误（分块编码异常、响应非法等） */
    | Protocol
    /** 连接池被占满，在等待超时内没拿到槽位 */
    | PoolBusy
    /** 客户端已关闭 */
    | Closed
    /** 目标已被熔断（连续失败达到阈值，冷却期内快速失败） */
    | CircuitOpen
    /** 响应状态码不满足要求（仅 raiseForStatus 抛出） */
    | Status
    /** 重试次数耗尽 */
    | RetryExhausted
    /** 读取响应体失败 */
    | ResponseBody

    public func toString(): String {
        match (this) {
            case Url => "Url"
            case Connect => "Connect"
            case Timeout => "Timeout"
            case Transport => "Transport"
            case Protocol => "Protocol"
            case PoolBusy => "PoolBusy"
            case Closed => "Closed"
            case CircuitOpen => "CircuitOpen"
            case Status => "Status"
            case RetryExhausted => "RetryExhausted"
            case ResponseBody => "ResponseBody"
        }
    }

    /** 该类失败是否值得重试。 */
    public func isRetryable(): Bool {
        match (this) {
            case Connect | Timeout | Transport | PoolBusy | Protocol => true
            case _ => false
        }
    }
}

/**
 * 本库统一的异常类型。
 *
 * 设计上只暴露两个异常类：`HttpError`（传输/超时/池/协议）与 `StatusError`（状态码不符合预期），
 * 通过 `kind` 区分具体原因，避免让调用方去 catch 一大堆异常子类。
 */
public open class HttpError <: Exception {
    /** 失败分类 */
    public let kind: ErrorKind
    /** 出问题的请求 URL */
    public let url: String
    /** 实际尝试次数（含首次） */
    public let attempts: Int64
    /** 最底层的原始异常，便于排查 */
    public let cause: ?Exception

    public init(kind: ErrorKind, message: String, url!: String = "", attempts!: Int64 = 1,
        cause!: ?Exception = None) {
        super(message)
        this.kind = kind
        this.url = url
        this.attempts = attempts
        this.cause = cause
    }

    /** 该失败是否值得重试。 */
    public func isRetryable(): Bool {
        kind.isRetryable()
    }

    public open func describe(): String {
        let locationText = if (url.isEmpty()) { "" } else { " [${url}]" }
        let tries = if (attempts > 1) { " attempts=${attempts}" } else { "" }
        "${kind}${locationText}${tries}: ${message}"
    }
}

/**
 * 状态码不符合预期时抛出（由 `Response.raiseForStatus()` 触发）。
 */
public class StatusError <: HttpError {
    /** 实际状态码 */
    public let status: UInt16
    /** 响应体开头片段，便于直接看清服务端报了什么错 */
    public let bodyPreview: String

    public init(status: UInt16, message: String, url!: String = "", attempts!: Int64 = 1,
        bodyPreview!: String = "") {
        super(ErrorKind.Status, message, url: url, attempts: attempts)
        this.status = status
        this.bodyPreview = bodyPreview
    }

    public override func describe(): String {
        let preview = if (bodyPreview.isEmpty()) { "" } else { " body=${bodyPreview}" }
        "HTTP ${status} [${url}]: ${message}${preview}"
    }
}

/*
 * 内部构造辅助：把底层异常包成带上下文的 HttpError。
 */

internal func wrapError(kind: ErrorKind, url: String, attempts: Int64, e: Exception): HttpError {
    HttpError(kind, e.message, url: url, attempts: attempts, cause: e)
}

/**
 * 依据底层异常判断失败分类。
 *
 * stdx 把建连失败、读写超时等包装成了不同异常，这里做一次归一化；
 * 判定不出来时归为 Transport（连接已建立后的通用失败）。
 */
internal func classifyException(e: Exception, timedOut: Bool): ErrorKind {
    if (timedOut) {
        return ErrorKind.Timeout
    }
    if (e is HttpTimeoutException) {
        return ErrorKind.Timeout
    }
    if (e is SocketTimeoutException) {
        return ErrorKind.Timeout
    }
    if (e is TlsException) {
        return ErrorKind.Connect
    }
    if (e is SocketException) {
        return ErrorKind.Connect
    }
    if (e is ConnectionException) {
        return ErrorKind.Transport
    }
    if (e is HttpException) {
        // stdx 的 HttpException 覆盖面较广：连接池占满、协议错误等都走这里。
        let text = e.message
        if (text.contains("Too many connections")) {
            return ErrorKind.PoolBusy
        }
        if (text.contains("TLS must be configured")) {
            return ErrorKind.Connect
        }
        return ErrorKind.Protocol
    }
    ErrorKind.Transport
}
