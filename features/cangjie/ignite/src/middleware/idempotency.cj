package ignite.middleware

import ignite.{Handler, Ctx}
import std.time.MonoTime

public class IdempotencyConfig {
    public var headerName: String = "X-Idempotency-Key"
    public var lifetime: Duration = Duration.second * 300
    public var methods: Array<String> = ["POST", "PUT", "PATCH"]
    public var cleanupEvery: Int64 = 64

    public init(
        headerName!: String = "X-Idempotency-Key",
        lifetime!: Duration = Duration.second * 300,
        methods!: Array<String> = ["POST", "PUT", "PATCH"],
        cleanupEvery!: Int64 = 64
    ) {
        this.headerName = headerName
        this.lifetime = lifetime
        this.methods = methods
        this.cleanupEvery = if (cleanupEvery > 0) { cleanupEvery } else { 64 }
    }
}

class IdempotencySweepState {
    var cleanupTicks: Int64 = 0
}

public func idempotencyMiddleware(
    config!: IdempotencyConfig = IdempotencyConfig(),
    store!: ?IdempotencyStore = None
): Handler {
    let idempotencyStore = resolveIdempotencyStore(store)
    let sweepState = IdempotencySweepState()

    { ctx: Ctx =>
        var isTarget = false
        for (m in config.methods) {
            if (ctx.method == m) {
                isTarget = true
                break
            }
        }

        if (!isTarget) {
            ctx.next()
            return
        }

        let key = ctx.header(config.headerName) ?? ""
        if (key.size == 0) {
            ctx.next()
            return
        }

        let now = MonoTime.now()
        sweepState.cleanupTicks += 1
        if (sweepState.cleanupTicks >= config.cleanupEvery) {
            idempotencyStore.cleanupExpired(now, config.lifetime)
            sweepState.cleanupTicks = 0
        }
        if (let Some(entry) <- idempotencyStore.getFresh(key, now, config.lifetime)) {
            ctx.setHeader("X-Idempotency-Cached", "true")
            ctx.json(entry.body)
            return
        }

        ctx.next()

        if (let Some(body) <- ctx.responseBody) {
            idempotencyStore.put(key, body, MonoTime.now())
        }
    }
}
