package linderHttp.http

/**
 * 一条 Cookie。
 */
public class Cookie <: ToString {
    public let name: String
    public let value: String
    /** 生效域；为空表示仅当前主机 */
    public let domain: String
    public let path: String
    public let secure: Bool
    public let httpOnly: Bool
    /** 过期时间；None 表示会话 Cookie */
    public let expiresAt: ?DateTime
    /** 服务端下发的原始文本 */
    public let raw: String

    public init(name: String, value: String, domain: String, path: String, secure: Bool,
        httpOnly: Bool, expiresAt: ?DateTime, raw: String) {
        this.name = name
        this.value = value
        this.domain = domain
        this.path = path
        this.secure = secure
        this.httpOnly = httpOnly
        this.expiresAt = expiresAt
        this.raw = raw
    }

    public func isExpired(now: DateTime): Bool {
        match (expiresAt) {
            case Some(deadline) => now > deadline
            case None => false
        }
    }

    public func matches(host: String, requestPath: String, secureRequest: Bool): Bool {
        if (secure && !secureRequest) {
            return false
        }
        if (!domain.isEmpty()) {
            let lowerHost = host.toAsciiLower()
            let lowerDomain = domain.toAsciiLower()
            let domainMatches = lowerHost == lowerDomain ||
                lowerHost.endsWith(".${lowerDomain}")
            if (!domainMatches) {
                return false
            }
        }
        if (!path.isEmpty() && !requestPath.startsWith(path)) {
            return false
        }
        true
    }

    public func toCookieLine(): String {
        "${name}=${value}"
    }

    public func toString(): String {
        "${name}=${value}; Domain=${domain}; Path=${path}"
    }
}

/**
 * 进程内 Cookie 存储。
 *
 * 行为对齐浏览器/常见 HTTP 库：收到 `Set-Cookie` 就存，发请求时按域、路径、Secure 匹配后
 * 拼成一个 `Cookie` 头。`Max-Age` 会换算成绝对过期时间；`Expires` 只识别
 * 「1970-01-01」这种删除语义（其余日期解析从略，当作会话 Cookie）。
 */
public class CookieStore {
    private let mutex: Mutex = Mutex()
    private let cookies: ArrayList<Cookie> = ArrayList<Cookie>()

    public init() {}

    public func size(): Int64 {
        synchronized(mutex) {
            cookies.size
        }
    }

    public func all(): Array<Cookie> {
        synchronized(mutex) {
            cookies.toArray()
        }
    }

    public func clear(): Unit {
        synchronized(mutex) {
            cookies.clear()
        }
    }

    /** 把一组 Set-Cookie 头按来源 URL 存入。 */
    public func store(url: String, setCookieHeaders: Collection<String>): Unit {
        let parsed = URL.parse(url)
        let host = parsed.hostName.toString()
        let path = parsed.path.toString()
        let secureRequest = parsed.scheme.toString().toAsciiUpper() == "HTTPS"
        for (headerValue in setCookieHeaders) {
            match (parseSetCookie(headerValue, host, path)) {
                case Some(cookie) => put(cookie)
                case None => ()
            }
        }
    }

    private func put(cookie: Cookie): Unit {
        synchronized(mutex) {
            var replaced = false
            var index = 0
            while (index < cookies.size) {
                let existing = cookies[index]
                if (existing.name == cookie.name && existing.domain == cookie.domain &&
                    existing.path == cookie.path) {
                    if (cookie.isExpired(DateTime.now())) {
                        cookies.remove(index..(index + 1))
                    } else {
                        cookies[index] = cookie
                    }
                    replaced = true
                    break
                }
                index++
            }
            if (!replaced && !cookie.isExpired(DateTime.now())) {
                cookies.add(cookie)
            }
        }
    }

    /** 为某个 URL 生成 Cookie 请求头；没有可用 Cookie 时返回 None。 */
    public func headerFor(url: String): ?String {
        let parsed = URL.parse(url)
        let host = parsed.hostName.toString()
        let path = parsed.path.toString()
        let secureRequest = parsed.scheme.toString().toAsciiUpper() == "HTTPS"
        synchronized(mutex) {
            let now = DateTime.now()
            var index = 0
            while (index < cookies.size) {
                if (cookies[index].isExpired(now)) {
                    cookies.remove(index..(index + 1))
                    continue
                }
                index++
            }
            let parts = ArrayList<String>()
            for (cookie in cookies) {
                if (cookie.matches(host, path, secureRequest)) {
                    parts.add(cookie.toCookieLine())
                }
            }
            if (parts.isEmpty()) {
                None
            } else {
                Some(String.join(parts.toArray(), delimiter: "; "))
            }
        }
    }
}

/** 解析单条 Set-Cookie；解析不出 name=value 时返回 None。 */
internal func parseSetCookie(value: String, host: String, requestPath: String): ?Cookie {
    let segments = value.split(";")
    if (segments.size == 0) {
        return None
    }
    let first = segments[0].trimAscii()
    let separator = first.indexOf('=')
    if (separator.isNone()) {
        return None
    }
    let position = separator.getOrThrow()
    if (position <= 0) {
        return None
    }
    let name = first[0..position].trimAscii()
    let cookieValue = first[(position + 1)..].trimAscii()
    var domain = ""
    var path = ""
    var secure = false
    var httpOnly = false
    var expiresAt: ?DateTime = None
    var index = 1
    while (index < segments.size) {
        let segment = segments[index].trimAscii()
        let eq = segment.indexOf('=')
        let key = if (eq.isNone()) { segment } else { segment[0..eq.getOrThrow()] }
        let rawValue = if (eq.isNone()) { "" } else { segment[(eq.getOrThrow() + 1)..] }
        match (key.toAsciiLower()) {
            case "domain" => domain = rawValue.trimAscii()
            case "path" => path = rawValue.trimAscii()
            case "secure" => secure = true
            case "httponly" => httpOnly = true
            case "max-age" =>
                match (tryParseInt64(rawValue.trimAscii())) {
                    case Some(seconds) =>
                        if (seconds >= 0) {
                            expiresAt = Some(DateTime.now() + Duration.second * seconds)
                        } else {
                            // 负数表示立即删除
                            expiresAt = Some(DateTime.now() - Duration.second)
                        }
                    case None => ()
                }
            case "expires" =>
                // 只识别删除语义：过期时间落在 1970/1969 的一律视为删除
                if (rawValue.contains("1970") || rawValue.contains("1969")) {
                    expiresAt = Some(DateTime.now() - Duration.second)
                }
            case _ => ()
        }
        index++
    }
    var effectiveDomain = domain
    if (effectiveDomain.isEmpty()) {
        effectiveDomain = host
    }
    var effectivePath = path
    if (effectivePath.isEmpty()) {
        effectivePath = defaultCookiePath(requestPath)
    }
    Some(Cookie(name, cookieValue, effectiveDomain, effectivePath, secure, httpOnly, expiresAt,
        value))
}

private func defaultCookiePath(requestPath: String): String {
    if (requestPath.isEmpty() || !requestPath.startsWith("/")) {
        return "/"
    }
    let lastSlash = requestPath.lastIndexOf('/')
    match (lastSlash) {
        case Some(position) =>
            if (position == 0) {
                "/"
            } else {
                requestPath[0..position]
            }
        case None => "/"
    }
}
