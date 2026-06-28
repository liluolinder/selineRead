package ignite.middleware

import ignite.{Handler, Ctx}
import std.convert.*

public class BodyLimitConfig {
    public var maxSize: Int64 = 4 * 1024 * 1024

    public init(maxSize!: Int64 = 4 * 1024 * 1024) {
        this.maxSize = maxSize
    }
}

public func bodyLimitMiddleware(config!: BodyLimitConfig = BodyLimitConfig()): Handler {
    { ctx: Ctx =>
        let contentLength = ctx.header("content-length") ?? "0"
        var size: Int64 = 0
        try {
            size = Int64.parse(contentLength)
        } catch (_: Exception) {
            size = 0
        }

        if (size > config.maxSize) {
            ctx.status(413).sendString("Request Entity Too Large")
            return
        }
        ctx.next()
    }
}
