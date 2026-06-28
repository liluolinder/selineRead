package ignite.middleware

import ignite.{Handler, Ctx}

public class SecurityConfig {
    public var xContentTypeOptions: String = "nosniff"
    public var xFrameOptions: String = "SAMEORIGIN"
    public var xXssProtection: String = "0"
    public var referrerPolicy: String = "no-referrer"
    public var contentSecurityPolicy: String = ""
    public var hstsMaxAge: Int64 = 0
    public var hstsIncludeSubDomains: Bool = true
    public var hstsPreload: Bool = false
    public var crossOriginOpenerPolicy: String = "same-origin"
    public var crossOriginResourcePolicy: String = "same-origin"
    public var crossOriginEmbedderPolicy: String = "require-corp"
    public var permissionsPolicy: String = ""

    public init(
        xContentTypeOptions!: String = "nosniff",
        xFrameOptions!: String = "SAMEORIGIN",
        xXssProtection!: String = "0",
        referrerPolicy!: String = "no-referrer",
        contentSecurityPolicy!: String = "",
        hstsMaxAge!: Int64 = 0,
        hstsIncludeSubDomains!: Bool = true,
        hstsPreload!: Bool = false,
        crossOriginOpenerPolicy!: String = "same-origin",
        crossOriginResourcePolicy!: String = "same-origin",
        crossOriginEmbedderPolicy!: String = "require-corp",
        permissionsPolicy!: String = ""
    ) {
        this.xContentTypeOptions = xContentTypeOptions
        this.xFrameOptions = xFrameOptions
        this.xXssProtection = xXssProtection
        this.referrerPolicy = referrerPolicy
        this.contentSecurityPolicy = contentSecurityPolicy
        this.hstsMaxAge = hstsMaxAge
        this.hstsIncludeSubDomains = hstsIncludeSubDomains
        this.hstsPreload = hstsPreload
        this.crossOriginOpenerPolicy = crossOriginOpenerPolicy
        this.crossOriginResourcePolicy = crossOriginResourcePolicy
        this.crossOriginEmbedderPolicy = crossOriginEmbedderPolicy
        this.permissionsPolicy = permissionsPolicy
    }
}

public func securityMiddleware(config!: SecurityConfig = SecurityConfig()): Handler {
    let hstsMaxAge = if (config.hstsMaxAge < 0) { 0 } else { config.hstsMaxAge }
    let xContentTypeOptions = if (config.xContentTypeOptions.size == 0) { "nosniff" } else { config.xContentTypeOptions }
    let xFrameOptions = if (config.xFrameOptions.size == 0) { "SAMEORIGIN" } else { config.xFrameOptions }
    let referrerPolicy = if (config.referrerPolicy.size == 0) { "no-referrer" } else { config.referrerPolicy }

    { ctx: Ctx =>
        if (xContentTypeOptions.size > 0) {
            ctx.setHeader("X-Content-Type-Options", xContentTypeOptions)
        }
        if (xFrameOptions.size > 0) {
            ctx.setHeader("X-Frame-Options", xFrameOptions)
        }
        if (config.xXssProtection.size > 0) {
            ctx.setHeader("X-XSS-Protection", config.xXssProtection)
        }
        if (referrerPolicy.size > 0) {
            ctx.setHeader("Referrer-Policy", referrerPolicy)
        }
        if (config.contentSecurityPolicy.size > 0) {
            ctx.setHeader("Content-Security-Policy", config.contentSecurityPolicy)
        }
        if (hstsMaxAge > 0) {
            var hsts = "max-age=${hstsMaxAge}"
            if (config.hstsIncludeSubDomains) { hsts += "; includeSubDomains" }
            if (config.hstsPreload) { hsts += "; preload" }
            ctx.setHeader("Strict-Transport-Security", hsts)
        }
        if (config.crossOriginOpenerPolicy.size > 0) {
            ctx.setHeader("Cross-Origin-Opener-Policy", config.crossOriginOpenerPolicy)
        }
        if (config.crossOriginResourcePolicy.size > 0) {
            ctx.setHeader("Cross-Origin-Resource-Policy", config.crossOriginResourcePolicy)
        }
        if (config.crossOriginEmbedderPolicy.size > 0) {
            ctx.setHeader("Cross-Origin-Embedder-Policy", config.crossOriginEmbedderPolicy)
        }
        if (config.permissionsPolicy.size > 0) {
            ctx.setHeader("Permissions-Policy", config.permissionsPolicy)
        }
        ctx.next()
    }
}
