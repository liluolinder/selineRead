package ignite.middleware

import ignite.{Handler, Ctx}
import std.time.MonoTime

public class RateLimitConfig {
    public var max: Int64 = 100
    public var windowMs: Int64 = 60000
    public var cleanupEvery: Int64 = 64
    public var keyGenerator: ?((Ctx) -> String) = None
    public var message: String = "Too Many Requests"

    public init(
        max!: Int64 = 100,
        windowMs!: Int64 = 60000,
        cleanupEvery!: Int64 = 64,
        keyGenerator!: ?((Ctx) -> String) = None,
        message!: String = "Too Many Requests"
    ) {
        this.max = max
        this.windowMs = windowMs
        this.cleanupEvery = if (cleanupEvery > 0) { cleanupEvery } else { 64 }
        this.keyGenerator = keyGenerator
        this.message = message
    }
}

class RateLimitSweepState {
    var cleanupTicks: Int64 = 0
}

public func rateLimitMiddleware(
    config!: RateLimitConfig = RateLimitConfig(),
    store!: ?RateLimitStore = None
): Handler {
    let rateLimitStore = resolveRateLimitStore(store)
    let sweepState = RateLimitSweepState()

    { ctx: Ctx =>
        let key = if (let Some(gen) <- config.keyGenerator) {
            gen(ctx)
        } else {
            ctx.ip
        }

        var allowed = true
        var remaining: Int64 = config.max
        var resetInMs = config.windowMs

        let now = MonoTime.now()
        sweepState.cleanupTicks += 1
        if (sweepState.cleanupTicks >= config.cleanupEvery) {
            rateLimitStore.cleanupExpired(now, config.windowMs)
            sweepState.cleanupTicks = 0
        }
        let result = rateLimitStore.consumeWindowPermit(key, now, config.max, config.windowMs)
        remaining = config.max - result.count
        if (remaining < 0) { remaining = 0 }
        allowed = result.allowed
        resetInMs = result.resetInMs

        ctx.setHeader("X-RateLimit-Limit", "${config.max}")
        ctx.setHeader("X-RateLimit-Remaining", "${remaining}")
        ctx.setHeader("X-RateLimit-Reset", "${retryAfterSeconds(resetInMs)}")

        if (!allowed) {
            ctx.setHeader("Retry-After", "${retryAfterSeconds(resetInMs)}")
            ctx.status(429).sendString(config.message)
            return
        }
        ctx.next()
    }
}

func retryAfterSeconds(remainingMs: Int64): Int64 {
    if (remainingMs <= 0) {
        return 0
    }
    let whole = remainingMs / 1000
    if ((remainingMs % 1000) == 0) {
        return whole
    }
    whole + 1
}
