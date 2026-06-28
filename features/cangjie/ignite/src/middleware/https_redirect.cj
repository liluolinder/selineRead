package ignite.middleware

import ignite.{Handler, Ctx}

public class HttpsRedirectConfig {
    public var host: String = ""
    public var httpsPort: UInt16 = 443
    public var statusCode: UInt16 = 307
    public var skipPaths: Array<String> = []
    public var trustForwardedHeaders: Bool = true

    public init(
        host!: String = "",
        httpsPort!: UInt16 = 443,
        statusCode!: UInt16 = 307,
        skipPaths!: Array<String> = [],
        trustForwardedHeaders!: Bool = true
    ) {
        this.host = host
        this.httpsPort = httpsPort
        this.statusCode = statusCode
        this.skipPaths = skipPaths
        this.trustForwardedHeaders = trustForwardedHeaders
    }
}

public func httpsRedirectMiddleware(config!: HttpsRedirectConfig = HttpsRedirectConfig()): Handler {
    { ctx: Ctx =>
        if (requestAlreadyHttps(ctx, config)) {
            ctx.next()
            return
        }
        if (shouldSkipHttpsRedirect(ctx.path, config.skipPaths)) {
            ctx.next()
            return
        }

        let authority = resolveHttpsRedirectAuthority(ctx, config)
        if (authority.size == 0) {
            ctx.next()
            return
        }

        let location = "https://${authority}" + requestTargetForRedirect(ctx)
        ctx.redirect(location, code: config.statusCode)
    }
}

func requestAlreadyHttps(ctx: Ctx, config: HttpsRedirectConfig): Bool {
    if (!config.trustForwardedHeaders) {
        return false
    }
    if (let Some(protoHeader) <- ctx.header("x-forwarded-proto")) {
        let proto = firstForwardedValue(protoHeader).trimAscii().toAsciiLower()
        if (proto == "https") {
            return true
        }
    }
    false
}

func resolveHttpsRedirectAuthority(ctx: Ctx, config: HttpsRedirectConfig): String {
    var host = config.host.trimAscii()
    if (host.size == 0 && config.trustForwardedHeaders) {
        host = normalizeRedirectHost(ctx.header("x-forwarded-host") ?? "")
    }
    if (host.size == 0) {
        host = normalizeRedirectHost(ctx.header("host") ?? "")
    }
    if (host.size == 0) {
        return ""
    }
    if (config.httpsPort == UInt16(443)) {
        return host
    }
    "${host}:${config.httpsPort}"
}

func normalizeRedirectHost(raw: String): String {
    let trimmed = firstForwardedValue(raw).trimAscii()
    if (trimmed.size == 0) {
        return ""
    }
    if (trimmed.startsWith("[")) {
        let closeIdx = indexOfRune(trimmed, r']')
        if (closeIdx >= 0) {
            return trimmed[..closeIdx + 1]
        }
        return trimmed
    }

    let chars = trimmed.toRuneArray()
    var colonCount: Int64 = 0
    for (ch in chars) {
        if (ch == r':') {
            colonCount += 1
        }
    }
    if (colonCount <= 1) {
        let lastColon = lastIndexOfRune(trimmed, r':')
        if (lastColon > 0) {
            let suffix = trimmed[lastColon + 1..trimmed.size]
            if (isDigitsOnly(suffix)) {
                return trimmed[..lastColon]
            }
        }
    }
    trimmed
}

func requestTargetForRedirect(ctx: Ctx): String {
    let original = ctx.originalUrl.trimAscii()
    if (original.size == 0) {
        return ctx.path
    }
    if (original.startsWith("http://") || original.startsWith("https://")) {
        let slashIdx = indexOfAfterScheme(original)
        if (slashIdx >= 0) {
            return original[slashIdx..original.size]
        }
        return "/"
    }
    if (original.startsWith("/")) {
        return original
    }
    "/" + original
}

func shouldSkipHttpsRedirect(path: String, rules: Array<String>): Bool {
    let target = path.trimAscii()
    for (ruleRaw in rules) {
        let rule = ruleRaw.trimAscii()
        if (rule.size == 0) {
            continue
        }
        if (rule == target) {
            return true
        }
        if (rule.endsWith("*")) {
            let prefix = rule[..rule.size - 1]
            if (prefix.size == 0 || strStartsWith(target, prefix)) {
                return true
            }
        }
    }
    false
}

func firstForwardedValue(raw: String): String {
    let chars = raw.toRuneArray()
    var out = ""
    for (ch in chars) {
        if (ch == r',') {
            break
        }
        out += ch.toString()
    }
    out
}

func isDigitsOnly(raw: String): Bool {
    if (raw.size == 0) {
        return false
    }
    for (ch in raw.toRuneArray()) {
        if (ch < r'0' || ch > r'9') {
            return false
        }
    }
    true
}

func indexOfAfterScheme(url: String): Int64 {
    let chars = url.toRuneArray()
    var slashSeen: Int64 = 0
    var i: Int64 = 0
    while (i < chars.size) {
        if (chars[i] == r'/') {
            slashSeen += 1
            if (slashSeen == 3) {
                return i
            }
        }
        i += 1
    }
    -1
}

func indexOfRune(text: String, target: Rune): Int64 {
    let chars = text.toRuneArray()
    var i: Int64 = 0
    while (i < chars.size) {
        if (chars[i] == target) {
            return i
        }
        i += 1
    }
    -1
}

func lastIndexOfRune(text: String, target: Rune): Int64 {
    let chars = text.toRuneArray()
    var i: Int64 = chars.size - 1
    while (i >= 0) {
        if (chars[i] == target) {
            return i
        }
        i -= 1
    }
    -1
}
