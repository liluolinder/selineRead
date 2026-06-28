package ignite.middleware

import ignite.{Handler, Ctx}

public class RedirectConfig {
    public var rules: Array<(String, String)>
    public var statusCode: UInt16 = 301

    public init(rules: Array<(String, String)>, statusCode!: UInt16 = 301) {
        this.rules = rules
        this.statusCode = statusCode
    }
}

public func redirectMiddleware(config: RedirectConfig): Handler {
    { ctx: Ctx =>
        let path = ctx.path
        for ((from, to) in config.rules) {
            if (path == from) {
                ctx.redirect(to, code: config.statusCode)
                return
            }
            if (strStartsWith(path, from)) {
                let rest = substringFrom(path, from.size)
                ctx.redirect(to + rest, code: config.statusCode)
                return
            }
        }
        ctx.next()
    }
}
