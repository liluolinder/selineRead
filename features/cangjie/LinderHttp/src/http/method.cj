package linderHttp.http

/**
 * HTTP 请求方法。
 *
 * 相比「字符串到处传」，枚举把标准方法固定下来，同时用 `Custom` 兜住 WebDAV / 私有方法。
 * `isIdempotent()` 是重试策略的判定依据：默认只重试幂等方法。
 */
public enum Method <: ToString {
    | Get
    | Post
    | Put
    | Patch
    | Delete
    | Head
    | Options
    | Trace
    | Connect
    | Custom(String)

    public func toString(): String {
        match (this) {
            case Get => "GET"
            case Post => "POST"
            case Put => "PUT"
            case Patch => "PATCH"
            case Delete => "DELETE"
            case Head => "HEAD"
            case Options => "OPTIONS"
            case Trace => "TRACE"
            case Connect => "CONNECT"
            case Custom(text) => text
        }
    }

    /** 由字符串解析；无法识别时包装为 `Custom`，不抛异常。 */
    public static func parse(text: String): Method {
        match (text.toAsciiUpper()) {
            case "GET" => Get
            case "POST" => Post
            case "PUT" => Put
            case "PATCH" => Patch
            case "DELETE" => Delete
            case "HEAD" => Head
            case "OPTIONS" => Options
            case "TRACE" => Trace
            case "CONNECT" => Connect
            case _ => Custom(text)
        }
    }

    /**
     * 是否为幂等方法。
     *
     * 幂等是「重复执行不改变服务端状态」的语义，因此 GET/HEAD/PUT/DELETE/OPTIONS/TRACE
     * 可以在网络抖动后安全重发；POST/PATCH 默认不重试。
     */
    public func isIdempotent(): Bool {
        match (this) {
            case Get => true
            case Head => true
            case Put => true
            case Delete => true
            case Options => true
            case Trace => true
            case _ => false
        }
    }
}
