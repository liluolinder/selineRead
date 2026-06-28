package ignite.middleware

import ignite.{Handler, Ctx}

public class HealthCheckConfig {
    public var endpoint: String = "/health"
    public var checker: ?(() -> Bool) = None
    public var responseBody: String = #"{"status":"ok"}"#

    public init(
        endpoint!: String = "/health",
        checker!: ?(() -> Bool) = None,
        responseBody!: String = #"{"status":"ok"}"#
    ) {
        this.endpoint = endpoint
        this.checker = checker
        this.responseBody = responseBody
    }
}

public func healthCheckMiddleware(config!: HealthCheckConfig = HealthCheckConfig()): Handler {
    { ctx: Ctx =>
        if (ctx.path != config.endpoint || ctx.method != "GET") {
            ctx.next()
            return
        }

        if (let Some(checker) <- config.checker) {
            if (checker()) {
                ctx.json(config.responseBody)
            } else {
                ctx.status(503).json(#"{"status":"unavailable"}"#)
            }
        } else {
            ctx.json(config.responseBody)
        }
    }
}
