package ignite.middleware

import ignite.{Handler, Ctx}
import std.time.MonoTime

public class TimeoutConfig {
    public var timeout: Duration = Duration.second * 30
    public var message: String = "Request Timeout"

    public init(
        timeout!: Duration = Duration.second * 30,
        message!: String = "Request Timeout"
    ) {
        this.timeout = timeout
        this.message = message
    }
}

public func timeoutMiddleware(config!: TimeoutConfig = TimeoutConfig()): Handler {
    { ctx: Ctx =>
        let start = MonoTime.now()
        ctx.next()
        let elapsed = MonoTime.now() - start
        if (elapsed > config.timeout) {
            println("[Ignite] Request timeout: ${ctx.method} ${ctx.path} took ${elapsed.toMilliseconds()}ms")
        }
    }
}
