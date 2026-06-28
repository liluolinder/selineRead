package ignite.middleware

import ignite.{Handler, Ctx}
public class CorsConfig {
    public var allowOrigins: String = "*"
    public var allowMethods: String = "GET,POST,PUT,DELETE,PATCH,HEAD,OPTIONS"
    public var allowHeaders: String = "Origin,Content-Type,Accept,Authorization"
    public var exposeHeaders: String = ""
    public var allowCredentials: Bool = false
    public var maxAge: Int64 = 0

    public init(
        allowOrigins!: String = "*",
        allowMethods!: String = "GET,POST,PUT,DELETE,PATCH,HEAD,OPTIONS",
        allowHeaders!: String = "Origin,Content-Type,Accept,Authorization",
        exposeHeaders!: String = "",
        allowCredentials!: Bool = false,
        maxAge!: Int64 = 0
    ) {
        this.allowOrigins = allowOrigins
        this.allowMethods = allowMethods
        this.allowHeaders = allowHeaders
        this.exposeHeaders = exposeHeaders
        this.allowCredentials = allowCredentials
        this.maxAge = maxAge
    }
}

public func corsMiddleware(config!: CorsConfig = CorsConfig()): Handler {
    { ctx: Ctx =>
        let requestOrigin = ctx.header("origin") ?? ""
        let allowOrigin = resolveCorsAllowOrigin(config, requestOrigin)
        if (allowOrigin.size > 0) {
            ctx.setHeader("Access-Control-Allow-Origin", allowOrigin)
        }
        ctx.setHeader("Access-Control-Allow-Methods", config.allowMethods)
        ctx.setHeader("Access-Control-Allow-Headers", config.allowHeaders)

        if (config.exposeHeaders.size > 0) {
            ctx.setHeader("Access-Control-Expose-Headers", config.exposeHeaders)
        }
        if (shouldSetVaryOrigin(config, requestOrigin, allowOrigin)) {
            ctx.setHeader("Vary", "Origin")
        }
        if (config.allowCredentials && allowOrigin.size > 0 && allowOrigin != "*") {
            ctx.setHeader("Access-Control-Allow-Credentials", "true")
        }
        if (config.maxAge > 0) {
            ctx.setHeader("Access-Control-Max-Age", "${config.maxAge}")
        }

        if (ctx.method == "OPTIONS") {
            ctx.sendStatus(204)
            return
        }

        ctx.next()
    }
}

func resolveCorsAllowOrigin(config: CorsConfig, requestOrigin: String): String {
    let allowed = config.allowOrigins.trimAscii()
    if (allowed.size == 0) {
        return ""
    }
    if (allowed == "*") {
        if (config.allowCredentials && requestOrigin.trimAscii().size > 0) {
            return requestOrigin.trimAscii()
        }
        return "*"
    }
    if (!allowed.contains(",")) {
        return allowed
    }
    let origin = requestOrigin.trimAscii()
    if (origin.size == 0) {
        return ""
    }
    for (entry in allowed.split(",")) {
        let candidate = entry.trimAscii()
        if (candidate == origin) {
            return origin
        }
    }
    ""
}

func shouldSetVaryOrigin(config: CorsConfig, requestOrigin: String, allowOrigin: String): Bool {
    if (requestOrigin.trimAscii().size == 0) {
        return false
    }
    if (config.allowOrigins.trimAscii() == "*") {
        return allowOrigin != "*"
    }
    config.allowOrigins.contains(",")
}
