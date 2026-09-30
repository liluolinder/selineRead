package linderHttp.http

/**
 * 大小写不敏感的 HTTP 头容器。
 *
 * 底层直接复用标准库的 `HttpHeaders`（它已经做了小写归一化与多值支持），
 * 本类补上三件事：链式 API、快照拷贝（避免请求之间互相污染）、默认浏览器头。
 */
public class Headers <: Iterable<(String, Collection<String>)> & ToString {
    private let raw: HttpHeaders

    public init() {
        raw = HttpHeaders()
    }

    /** 包装一个已有的标准头对象（不拷贝，双方共享同一份数据）。 */
    public init(raw!: HttpHeaders) {
        this.raw = raw
    }

    public init(pairs: Array<(String, String)>) {
        raw = HttpHeaders()
        for (pair in pairs) {
            raw.add(pair[0], pair[1])
        }
    }

    /** 覆盖同名头。 */
    public func set(name: String, value: String): Headers {
        raw.set(name, value)
        this
    }

    /** 追加一个同名头，保留已有值（多值场景，如 Set-Cookie）。 */
    public func add(name: String, value: String): Headers {
        raw.add(name, value)
        this
    }

    public func setAll(pairs: Array<(String, String)>): Headers {
        for (pair in pairs) {
            raw.set(pair[0], pair[1])
        }
        this
    }

    public func remove(name: String): Headers {
        raw.del(name)
        this
    }

    public func clear(): Headers {
        for ((name, _) in raw) {
            raw.del(name)
        }
        this
    }

    /** 某个头的全部取值。 */
    public func get(name: String): Collection<String> {
        raw.get(name)
    }

    /** 某个头的第一个取值；没有则为 None。 */
    public func first(name: String): ?String {
        raw.getFirst(name)
    }

    /** 便捷取值：不存在时返回默认值。 */
    public func firstOr(name: String, fallback: String): String {
        match (raw.getFirst(name)) {
            case Some(value) => value
            case None => fallback
        }
    }

    public func contains(name: String): Bool {
        !raw.get(name).isEmpty()
    }

    public func names(): Array<String> {
        let result = ArrayList<String>()
        for ((name, _) in raw) {
            result.add(name)
        }
        result.toArray()
    }

    public func size(): Int64 {
        var count = 0
        for ((_, values) in raw) {
            count += values.size
        }
        count
    }

    public func isEmpty(): Bool {
        raw.isEmpty()
    }

    /** 深拷贝一份，供请求快照使用。 */
    public func copy(): Headers {
        let clone = Headers()
        for ((name, values) in raw) {
            for (value in values) {
                clone.raw.add(name, value)
            }
        }
        clone
    }

    /** 交给标准库发送层时使用。 */
    internal func native(): HttpHeaders {
        raw
    }

    public func iterator(): Iterator<(String, Collection<String>)> {
        raw.iterator()
    }

    /**
     * 默认请求头。
     *
     * 只放「不带会明显吃亏」的几个：UA 决定服务端给你哪个变体，Accept 声明通吃，
     * Accept-Encoding 不在这里写死：它由 ClientConfig.acceptCompression 控制，
     */
    public static func standard(): Headers {
        Headers()
            .set("accept", "*/*")
            .set("user-agent", defaultUserAgent())
    }

    /** 本库默认 UA。 */
    public static func defaultUserAgent(): String {
        "LinderHttp/2.0 (Cangjie; x86_64-w64-mingw32)"
    }

    public func toString(): String {
        let parts = ArrayList<String>()
        for ((name, values) in raw) {
            for (value in values) {
                parts.add("${name}: ${value}")
            }
        }
        String.join(parts.toArray(), delimiter: "\n")
    }
}
