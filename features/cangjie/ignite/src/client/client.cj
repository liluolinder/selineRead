package ignite.client

import stdx.net.http.HttpRequestBuilder
import std.collection.{ArrayList, HashMap}
import std.random.Random
import std.time.MonoTime
import std.unicode.*
import ignite.api2

// ── URL / Form 编码 ──

func urlEncode(s: String): String {
    let allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
    let runes = s.toRuneArray()
    var result = ""
    for (r in runes) {
        let c = r.toString()
        if (c == " ") {
            result += "+"
        } else if (strContains(allowed, c)) {
            result += c
        } else {
            let bytes = c.toArray()
            for (b in bytes) {
                let n = Int64(b)
                result += "%"
                if (n < 16) { result += "0" }
                result += intToHex(n)
            }
        }
    }
    result
}

func strContains(haystack: String, needle: String): Bool {
    let h = haystack.toRuneArray()
    let n = needle.toRuneArray()
    if (n.size == 0) { return true }
    if (h.size < n.size) { return false }
    for (i in 0..=(h.size - n.size)) {
        var ok = true
        for (j in 0..n.size) {
            if (h[i + j] != n[j]) { ok = false; break }
        }
        if (ok) { return true }
    }
    false
}

func intToHex(n: Int64): String {
    if (n < 10) { return "${n}" }
    if (n < 16) { return String.fromUtf8([UInt8(87 + n)]) }
    intToHex(n / 16) + intToHex(n % 16)
}

func buildQueryString(params: ArrayList<(String, String)>): String {
    if (params.size == 0) { return "" }
    var first = true
    var result = ""
    for ((k, v) in params) {
        if (!first) { result += "&" }
        first = false
        result += urlEncode(k) + "=" + urlEncode(v)
    }
    result
}

func buildFormUrlEncoded(params: ArrayList<(String, String)>): String {
    buildQueryString(params)
}

// ── Multipart 请求体 ──

public class MultipartFile {
    public let name: String
    public let filename: String
    public let contentType: String
    public let data: Array<UInt8>

    public init(name: String, filename: String, contentType: String, data: Array<UInt8>) {
        this.name = name
        this.filename = filename
        this.contentType = contentType
        this.data = data
    }
}

func buildMultipartBody(
    boundary: String,
    fields: ArrayList<(String, String)>,
    files: ArrayList<MultipartFile>
): Array<UInt8> {
    let crlf = [UInt8(13), UInt8(10)]
    let dash = "--".toArray()
    let b = boundary.toArray()
    let result = ArrayList<UInt8>()

    func append(s: String): Unit {
        for (x in s.toArray()) { result.add(x) }
    }
    func appendBytes(arr: Array<UInt8>): Unit {
        for (x in arr) { result.add(x) }
    }

    for ((name, value) in fields) {
        appendBytes(dash)
        appendBytes(b)
        appendBytes(crlf)
        append("Content-Disposition: form-data; name=\"${name}\"")
        appendBytes(crlf)
        appendBytes(crlf)
        append(value)
        appendBytes(crlf)
    }

    for (f in files) {
        appendBytes(dash)
        appendBytes(b)
        appendBytes(crlf)
        append("Content-Disposition: form-data; name=\"${f.name}\"; filename=\"${f.filename}\"")
        appendBytes(crlf)
        append("Content-Type: ${f.contentType}")
        appendBytes(crlf)
        appendBytes(crlf)
        appendBytes(f.data)
        appendBytes(crlf)
    }

    appendBytes(dash)
    appendBytes(b)
    append("--")
    appendBytes(crlf)
    result.toArray()
}

func randomBoundary(): String {
    try {
        api2.clientCryptoRandomHex(32)
    } catch (_: api2.ClientCryptoException) {
        let rng = Random()
        let hex = "0123456789abcdef".toRuneArray()
        var s = ""
        for (_ in 0..32) {
            s += hex[Int64(rng.nextUInt64() % 16)].toString()
        }
        s
    }
}

// ── Cookie 存储 ──

class ClientCookieEntry {
    var name: String
    var value: String
    var domain: String
    var path: String
    var hostOnly: Bool
    var secure: Bool
    var httpOnly: Bool
    var sameSite: String
    var setAt: MonoTime
    var maxAgeMs: ?Int64

    init(
        name: String,
        value: String,
        domain: String,
        path: String,
        hostOnly: Bool,
        secure: Bool,
        httpOnly: Bool,
        sameSite: String,
        maxAgeMs: ?Int64
    ) {
        this.name = name
        this.value = value
        this.domain = domain
        this.path = path
        this.hostOnly = hostOnly
        this.secure = secure
        this.httpOnly = httpOnly
        this.sameSite = sameSite
        this.setAt = MonoTime.now()
        this.maxAgeMs = maxAgeMs
    }
}

public class CookieStore {
    var _store: HashMap<String, ClientCookieEntry> = HashMap<String, ClientCookieEntry>()

    public init() {}

    public func addFromResponse(urlOrHost: String, response: ClientResponse): Unit {
        let setCookies = response.headerValues("set-cookie")
        for (line in setCookies) {
            addSetCookie(urlOrHost, line)
        }
    }

    public func addSetCookie(urlOrHost: String, line: String): Unit {
        let req = parseUrlOrHost(urlOrHost)
        let tokens = line.split(";")
        if (tokens.size == 0) {
            return
        }

        let pair = tokens[0].trimAscii()
        let nv = pair.split("=", 2)
        if (nv.size != 2) {
            return
        }
        let name = nv[0].trimAscii()
        let value = nv[1].trimAscii()
        if (name.size == 0) {
            return
        }

        var hostOnly = true
        var domain = req.host
        var path = defaultCookiePath(req.path)
        var secure = false
        var httpOnly = false
        var sameSite = ""
        var maxAgeMs: ?Int64 = None

        for (i in 1..tokens.size) {
            let token = tokens[i].trimAscii()
            if (token.size == 0) {
                continue
            }
            let attr = token.split("=", 2)
            let key = attr[0].trimAscii().toAsciiLower()
            let hasValue = attr.size == 2
            let attrValue = if (hasValue) { attr[1].trimAscii() } else { "" }
            if (key == "domain" && hasValue) {
                let d = normalizeDomain(attrValue)
                if (d.size > 0 && domainMatchesHost(req.host, d)) {
                    domain = d
                    hostOnly = false
                }
            } else if (key == "path" && hasValue) {
                if (isValidCookiePath(attrValue)) {
                    path = attrValue
                }
            } else if (key == "secure") {
                secure = true
            } else if (key == "httponly") {
                httpOnly = true
            } else if (key == "samesite" && hasValue) {
                sameSite = normalizeSameSite(attrValue)
            } else if (key == "max-age" && hasValue) {
                if (let Some(seconds) <- parseInt64(attrValue)) {
                    maxAgeMs = seconds * 1000
                }
            }
        }

        let entryKey = cookieKey(domain, path, name, hostOnly)
        if (let Some(ms) <- maxAgeMs) {
            if (ms <= 0) {
                _store.remove(entryKey)
                return
            }
        }

        _store.add(
            entryKey,
            ClientCookieEntry(
                name,
                value,
                domain,
                path,
                hostOnly,
                secure,
                httpOnly,
                sameSite,
                maxAgeMs
            )
        )
    }

    public func getCookieHeader(urlOrHost: String): String {
        let req = parseUrlOrHost(urlOrHost)
        let staleKeys = ArrayList<String>()
        let items = ArrayList<(String, String)>()

        for ((key, cookie) in _store) {
            if (isExpired(cookie)) {
                staleKeys.add(key)
                continue
            }
            if (!cookieMatchesRequest(cookie, req.host, req.path, req.secure)) {
                continue
            }
            items.add((cookie.name, cookie.value))
        }

        for (k in staleKeys) {
            _store.remove(k)
        }

        var first = true
        var out = ""
        for ((name, value) in items) {
            if (!first) {
                out += "; "
            }
            first = false
            out += name + "=" + value
        }
        out
    }

    func parseUrlOrHost(urlOrHost: String): CookieRequestContext {
        let raw = urlOrHost.trimAscii()
        if (startsWith(raw, "https://")) {
            return parseAbsoluteUrl(raw, true, 8)
        }
        if (startsWith(raw, "http://")) {
            return parseAbsoluteUrl(raw, false, 7)
        }
        let host = normalizeHost(raw)
        CookieRequestContext(host, "/", false)
    }

    func parseAbsoluteUrl(raw: String, secure: Bool, prefixLen: Int64): CookieRequestContext {
        let tail = sliceFrom(raw, prefixLen)
        let slash = indexOfChar(tail, r'/')
        if (slash < 0) {
            return CookieRequestContext(normalizeHost(tail), "/", secure)
        }
        let hostPart = sliceRange(tail, 0, slash)
        var path = sliceFrom(tail, slash)
        if (path.size == 0 || path.toRuneArray()[0] != r'/') {
            path = "/"
        }
        CookieRequestContext(normalizeHost(hostPart), path, secure)
    }

    func normalizeHost(hostPortRaw: String): String {
        let hostPort = hostPortRaw.trimAscii()
        if (hostPort.size == 0) {
            return ""
        }
        if (hostPort.toRuneArray()[0] == r'[') {
            let close = indexOfChar(hostPort, r']')
            if (close > 0) {
                return sliceRange(hostPort, 1, close).toAsciiLower()
            }
            return hostPort.toAsciiLower()
        }
        let colon = indexOfChar(hostPort, r':')
        if (colon < 0) {
            return hostPort.toAsciiLower()
        }
        sliceRange(hostPort, 0, colon).toAsciiLower()
    }

    func normalizeDomain(raw: String): String {
        let trimmed = raw.trimAscii().toAsciiLower()
        if (trimmed.size == 0) {
            return ""
        }
        if (trimmed.toRuneArray()[0] == r'.') {
            return sliceFrom(trimmed, 1)
        }
        trimmed
    }

    func normalizeSameSite(raw: String): String {
        let v = raw.trimAscii().toAsciiLower()
        if (v == "lax") { return "Lax" }
        if (v == "strict") { return "Strict" }
        if (v == "none") { return "None" }
        ""
    }

    func domainMatchesHost(host: String, domain: String): Bool {
        if (host == domain) {
            return true
        }
        if (host.size <= domain.size) {
            return false
        }
        if (!endsWith(host, "." + domain)) {
            return false
        }
        true
    }

    func isValidCookiePath(path: String): Bool {
        path.size > 0 && path.toRuneArray()[0] == r'/'
    }

    func defaultCookiePath(reqPath: String): String {
        if (reqPath.size == 0) {
            return "/"
        }
        let runes = reqPath.toRuneArray()
        if (runes[0] != r'/') {
            return "/"
        }
        if (runes.size == 1) {
            return "/"
        }
        let lastSlash = lastIndexOfChar(reqPath, r'/')
        if (lastSlash <= 0) {
            return "/"
        }
        sliceRange(reqPath, 0, lastSlash)
    }

    func cookieKey(domain: String, path: String, name: String, hostOnly: Bool): String {
        let ho = if (hostOnly) { "1" } else { "0" }
        domain + "|" + path + "|" + name + "|" + ho
    }

    func isExpired(cookie: ClientCookieEntry): Bool {
        match (cookie.maxAgeMs) {
            case Some(ms) => (MonoTime.now() - cookie.setAt).toMilliseconds() >= ms
            case None => false
        }
    }

    func cookieMatchesRequest(cookie: ClientCookieEntry, host: String, path: String, secure: Bool): Bool {
        if (cookie.hostOnly) {
            if (host != cookie.domain) {
                return false
            }
        } else {
            if (!domainMatchesHost(host, cookie.domain)) {
                return false
            }
        }
        if (cookie.secure && !secure) {
            return false
        }
        if (!pathMatches(path, cookie.path)) {
            return false
        }
        true
    }

    func pathMatches(reqPathRaw: String, cookiePath: String): Bool {
        let reqPath = if (reqPathRaw.size == 0) { "/" } else { reqPathRaw }
        if (reqPath == cookiePath) {
            return true
        }
        if (!startsWith(reqPath, cookiePath)) {
            return false
        }
        if (cookiePath.toRuneArray()[cookiePath.size - 1] == r'/') {
            return true
        }
        if (reqPath.size > cookiePath.size && reqPath.toRuneArray()[cookiePath.size] == r'/') {
            return true
        }
        false
    }

    func parseInt64(raw: String): ?Int64 {
        let s = raw.trimAscii()
        if (s.size == 0) {
            return None
        }
        let runes = s.toRuneArray()
        var sign: Int64 = 1
        var i: Int64 = 0
        if (runes[0] == r'-') {
            sign = -1
            i = 1
        } else if (runes[0] == r'+') {
            i = 1
        }
        if (i >= runes.size) {
            return None
        }
        var value: Int64 = 0
        while (i < runes.size) {
            let ch = runes[i]
            if (ch < r'0' || ch > r'9') {
                return None
            }
            let digit = Int64(UInt32(ch)) - Int64(UInt32(r'0'))
            value = value * 10 + digit
            i += 1
        }
        Some(value * sign)
    }

    func startsWith(s: String, prefix: String): Bool {
        let a = s.toRuneArray()
        let b = prefix.toRuneArray()
        if (a.size < b.size) {
            return false
        }
        for (i in 0..b.size) {
            if (a[i] != b[i]) {
                return false
            }
        }
        true
    }

    func endsWith(s: String, suffix: String): Bool {
        let a = s.toRuneArray()
        let b = suffix.toRuneArray()
        if (a.size < b.size) {
            return false
        }
        let offset = a.size - b.size
        for (i in 0..b.size) {
            if (a[offset + i] != b[i]) {
                return false
            }
        }
        true
    }

    func indexOfChar(s: String, ch: Rune): Int64 {
        let runes = s.toRuneArray()
        for (i in 0..runes.size) {
            if (runes[i] == ch) {
                return i
            }
        }
        -1
    }

    func lastIndexOfChar(s: String, ch: Rune): Int64 {
        let runes = s.toRuneArray()
        var i = runes.size
        while (i > 0) {
            i -= 1
            if (runes[i] == ch) {
                return i
            }
        }
        -1
    }

    func sliceFrom(s: String, start: Int64): String {
        let runes = s.toRuneArray()
        if (start <= 0) {
            return s
        }
        if (start >= runes.size) {
            return ""
        }
        var out = ""
        for (i in start..runes.size) {
            out += runes[i].toString()
        }
        out
    }

    func sliceRange(s: String, start: Int64, end: Int64): String {
        let runes = s.toRuneArray()
        if (start >= end || start >= runes.size || end <= 0) {
            return ""
        }
        var st = start
        var ed = end
        if (st < 0) { st = 0 }
        if (ed > runes.size) { ed = runes.size }
        var out = ""
        for (i in st..ed) {
            out += runes[i].toString()
        }
        out
    }
}

class CookieRequestContext {
    let host: String
    let path: String
    let secure: Bool

    init(host: String, path: String, secure: Bool) {
        this.host = host
        this.path = path
        this.secure = secure
    }
}

public type ClientRequestHook = (HttpRequestBuilder) -> Unit
public type ClientResponseHook = (ClientResponse) -> Unit
public type ClientErrorHook = (Exception) -> Unit
public type ClientObserveHook = (ClientObserveSnapshot) -> Unit
public type ClientTransportTouchpointHook = (ClientTransportTouchpoint) -> Unit

public class ClientRetryConfig {
    public var enabled: Bool
    public var maxAttempts: Int64
    public var idempotentOnly: Bool
    public var baseDelayMs: Int64
    public var maxDelayMs: Int64
    public var jitterMs: Int64
    public var retryStatusCodes: ArrayList<Int64>

    public init(
        enabled!: Bool = true,
        maxAttempts!: Int64 = 3,
        idempotentOnly!: Bool = true,
        baseDelayMs!: Int64 = 100,
        maxDelayMs!: Int64 = 1000,
        jitterMs!: Int64 = 50,
        retryStatusCodes!: ?ArrayList<Int64> = None
    ) {
        this.enabled = enabled
        this.maxAttempts = if (maxAttempts < 1) { 1 } else { maxAttempts }
        this.idempotentOnly = idempotentOnly
        this.baseDelayMs = if (baseDelayMs < 0) { 0 } else { baseDelayMs }
        this.maxDelayMs = if (maxDelayMs < this.baseDelayMs) { this.baseDelayMs } else { maxDelayMs }
        this.jitterMs = if (jitterMs < 0) { 0 } else { jitterMs }
        this.retryStatusCodes = ArrayList<Int64>()
        if (let Some(list) <- retryStatusCodes) {
            for (code in list) {
                this.retryStatusCodes.add(code)
            }
        } else {
            this.retryStatusCodes.add(408)
            this.retryStatusCodes.add(425)
            this.retryStatusCodes.add(429)
            this.retryStatusCodes.add(500)
            this.retryStatusCodes.add(502)
            this.retryStatusCodes.add(503)
            this.retryStatusCodes.add(504)
        }
    }

    public func copy(): ClientRetryConfig {
        let copied = ArrayList<Int64>()
        for (code in retryStatusCodes) {
            copied.add(code)
        }
        ClientRetryConfig(
            enabled: enabled,
            maxAttempts: maxAttempts,
            idempotentOnly: idempotentOnly,
            baseDelayMs: baseDelayMs,
            maxDelayMs: maxDelayMs,
            jitterMs: jitterMs,
            retryStatusCodes: copied
        )
    }
}
