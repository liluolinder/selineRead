package ignite.middleware

import ignite.{Handler, Ctx}

public class ETagConfig {
    public var weak: Bool = false

    public init(weak!: Bool = false) {
        this.weak = weak
    }
}

public func etagMiddleware(config!: ETagConfig = ETagConfig()): Handler {
    { ctx: Ctx =>
        ctx.next()

        if (let Some(body) <- ctx.responseBody) {
            if (body.size == 0) { return }

            var hasher = DefaultHasher()
            hasher.write(body)
            let hashVal = hasher.finish()
            let hashHex = int64ToHex(if (hashVal < 0) { -hashVal } else { hashVal })
            let etag = if (config.weak) {
                "W/\"${hashHex}\""
            } else {
                "\"${hashHex}\""
            }

            ctx.setHeader("ETag", etag)

            let ifNoneMatch = ctx.header("if-none-match") ?? ""
            if (ifNoneMatch.size > 0 && ifNoneMatch == etag) {
                ctx.status(304).sendString("")
            }
        }
    }
}

func int64ToHex(n: Int64): String {
    if (n == 0) { return "0" }
    let hexChars = "0123456789abcdef".toRuneArray()
    var result = ""
    var value = n
    while (value > 0) {
        result = hexChars[value % 16].toString() + result
        value = value / 16
    }
    result
}
