package ignite.middleware

import ignite.{Handler, Ctx}
import std.time.MonoTime

public class CacheConfig {
    public var expiration: Duration = Duration.second * 60
    public var cleanupEvery: Int64 = 64
    public var keyGenerator: ?((Ctx) -> String) = None
    public var cacheControl: String = ""
    public var methods: Array<String> = ["GET"]

    public init(
        expiration!: Duration = Duration.second * 60,
        cleanupEvery!: Int64 = 64,
        keyGenerator!: ?((Ctx) -> String) = None,
        cacheControl!: String = "",
        methods!: Array<String> = ["GET"]
    ) {
        this.expiration = expiration
        this.cleanupEvery = if (cleanupEvery > 0) { cleanupEvery } else { 64 }
        this.keyGenerator = keyGenerator
        this.cacheControl = cacheControl
        this.methods = methods
    }
}

class CacheSweepState {
    var cleanupTicks: Int64 = 0
}

public func cacheMiddleware(
    config!: CacheConfig = CacheConfig(),
    store!: ?ResponseCacheStore = None
): Handler {
    let cacheStore = resolveResponseCacheStore(store)
    let sweepState = CacheSweepState()

    { ctx: Ctx =>
        var isCacheable = false
        for (m in config.methods) {
            if (ctx.method == m) {
                isCacheable = true
                break
            }
        }

        if (!isCacheable) {
            ctx.next()
            return
        }

        let key = if (let Some(gen) <- config.keyGenerator) {
            gen(ctx)
        } else {
            ctx.method + ":" + ctx.path
        }

        let now = MonoTime.now()
        sweepState.cleanupTicks += 1
        if (sweepState.cleanupTicks >= config.cleanupEvery) {
            cacheStore.cleanupExpired(now, config.expiration)
            sweepState.cleanupTicks = 0
        }
        if (let Some(entry) <- cacheStore.getFresh(key, now, config.expiration)) {
            ctx.setHeader("X-Cache", "HIT")
            if (config.cacheControl.size > 0) {
                ctx.setHeader("Cache-Control", config.cacheControl)
            }
            ctx.setHeader("content-type", entry.contentType)
            ctx.sendString(entry.body)
            return
        }

        ctx.setHeader("X-Cache", "MISS")
        ctx.next()

        if (let Some(body) <- ctx.responseBody) {
            let ct = ctx.header("content-type") ?? "text/plain"
            cacheStore.put(key, body, ct, MonoTime.now())
        }
    }
}
