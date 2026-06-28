package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.ArrayList
import std.time.MonoTime

@Test
public class MiddlewareStoreContractTestSuite {
    @TestCase
    public func testSessionMiddlewareAcceptsCustomStoreBackend(): Unit {
        let app = App(config: Config())
        let store = RecordingSessionStore()
        app.use(
            sessionMiddleware(
                config: SessionConfig(cleanupEvery: 1),
                store: store
            )
        )
        app.get("/seed", { ctx =>
            let sessionId = ctx.getLocal("session_id") ?? ""
            store.set(sessionId, "role", "maintainer")
            _ = ctx.sendString("ok")
        })
        app.get("/read", { ctx =>
            let sessionId = ctx.getLocal("session_id") ?? ""
            _ = ctx.sendString(store.get(sessionId, "role") ?? "")
        })

        let seed = app.handleForTest("GET", "/seed")
        let sessionId = extractCookieValueForStore(seed.header("set-cookie") ?? "", "ignite_session")
        @Assert(sessionId != "", true)
        @Assert(store.touchCalls > 0, true)

        let read = app.handleForTest(
            "GET",
            "/read",
            headers: [("cookie", "ignite_session=${sessionId}")]
        )
        @Assert(read.status, UInt16(200))
        @Assert(read.body, "maintainer")
        @Assert(store.getCalls > 0, true)
    }

    @TestCase
    public func testCsrfMiddlewareAcceptsCustomTokenStore(): Unit {
        let app = App(config: Config())
        let store = RecordingCsrfTokenStore()
        app.use(
            csrfMiddleware(
                config: CsrfConfig(cleanupEvery: 1),
                store: store
            )
        )
        app.get("/form", { ctx =>
            _ = ctx.sendString("form")
        })
        app.post("/submit", { ctx =>
            _ = ctx.sendString("submitted")
        })

        let seed = app.handleForTest("GET", "/form")
        let token = extractCookieValueForStore(seed.header("set-cookie") ?? "", "_csrf")
        @Assert(token != "", true)
        @Assert(store.issueCalls > 0, true)

        let resp = app.handleForTest(
            "POST",
            "/submit",
            headers: [
                ("x-csrf-token", token),
                ("cookie", "_csrf=${token}")
            ]
        )
        @Assert(resp.status, UInt16(200))
        @Assert(resp.body, "submitted")
        @Assert(store.consumeCalls, 1)
    }

    @TestCase
    public func testRateLimitMiddlewareAcceptsCustomStore(): Unit {
        let app = App(config: Config())
        let store = RecordingRateLimitStore()
        app.use(
            rateLimitMiddleware(
                config: RateLimitConfig(
                    max: 1,
                    windowMs: 200,
                    cleanupEvery: 1,
                    keyGenerator: { ctx => ctx.header("x-key") ?? ctx.ip }
                ),
                store: store
            )
        )
        app.get("/limited", { ctx =>
            _ = ctx.sendString("ok")
        })

        let first = app.handleForTest(
            "GET",
            "/limited",
            headers: [("x-key", "delta")]
        )
        @Assert(first.status, UInt16(200))

        let second = app.handleForTest(
            "GET",
            "/limited",
            headers: [("x-key", "delta")]
        )
        @Assert(second.status, UInt16(429))
        @Assert(store.checkCalls, 2)
    }

    @TestCase
    public func testCacheMiddlewareAcceptsCustomStore(): Unit {
        let app = App(config: Config())
        let hits = ArrayList<String>()
        let store = RecordingResponseCacheStore()
        app.use(
            cacheMiddleware(
                config: CacheConfig(
                    expiration: Duration.second * 30,
                    cleanupEvery: 1
                ),
                store: store
            )
        )
        app.get("/cache", { ctx =>
            let count = hits.size + 1
            hits.add("hit")
            _ = ctx.sendString("value-${count}")
        })

        let first = app.handleForTest("GET", "/cache")
        @Assert(first.status, UInt16(200))
        @Assert(first.header("x-cache") ?? "", "MISS")

        let second = app.handleForTest("GET", "/cache")
        @Assert(second.status, UInt16(200))
        @Assert(second.header("x-cache") ?? "", "HIT")
        @Assert(second.body, "value-1")
        @Assert(store.lookupCalls >= 2, true)
        @Assert(store.putCalls, 1)
    }

    @TestCase
    public func testIdempotencyMiddlewareAcceptsCustomStore(): Unit {
        let app = App(config: Config())
        let hits = ArrayList<String>()
        let store = RecordingIdempotencyStore()
        app.use(
            idempotencyMiddleware(
                config: IdempotencyConfig(
                    lifetime: Duration.second * 30,
                    cleanupEvery: 1
                ),
                store: store
            )
        )
        app.post("/orders", { ctx =>
            let count = hits.size + 1
            hits.add("hit")
            _ = ctx.json("{\"n\":${count}}")
        })

        let first = app.handleForTest(
            "POST",
            "/orders",
            headers: [("x-idempotency-key", "order-9")]
        )
        @Assert(first.status, UInt16(200))

        let second = app.handleForTest(
            "POST",
            "/orders",
            headers: [("x-idempotency-key", "order-9")]
        )
        @Assert(second.status, UInt16(200))
        @Assert(second.header("x-idempotency-cached") ?? "", "true")
        @Assert(second.body, "{\"n\":1}")
        @Assert(store.lookupCalls >= 2, true)
        @Assert(store.putCalls, 1)
    }
}

class RecordingSessionStore <: SessionStoreBackend {
    let inner = SessionStore()
    var getCalls: Int64 = 0
    var touchCalls: Int64 = 0

    public override func get(sessionId: String, key: String): ?String {
        getCalls += 1
        inner.get(sessionId, key)
    }

    public override func set(sessionId: String, key: String, value: String): Unit {
        inner.set(sessionId, key, value)
    }

    public override func delete(sessionId: String, key: String): Unit {
        inner.delete(sessionId, key)
    }

    public override func touch(sessionId: String, nowMs: Int64): Unit {
        touchCalls += 1
        inner.touch(sessionId, nowMs)
    }

    public override func cleanupExpired(ttlMs: Int64, nowMs: Int64): Unit {
        inner.cleanupExpired(ttlMs, nowMs)
    }
}

class RecordingCsrfTokenStore <: CsrfTokenStore {
    let inner = MemoryCsrfTokenStore()
    var issueCalls: Int64 = 0
    var consumeCalls: Int64 = 0

    public override func issue(token: String, issuedAtMs: Int64): Unit {
        issueCalls += 1
        inner.issue(token, issuedAtMs)
    }

    public override func consume(token: String, nowMs: Int64, ttlMs: Int64): Bool {
        consumeCalls += 1
        inner.consume(token, nowMs, ttlMs)
    }

    public override func cleanupExpired(nowMs: Int64, ttlMs: Int64): Unit {
        inner.cleanupExpired(nowMs, ttlMs)
    }
}

class RecordingRateLimitStore <: RateLimitStore {
    let inner = MemoryRateLimitStore()
    var checkCalls: Int64 = 0

    public override func consumeWindowPermit(
        key: String,
        now: MonoTime,
        max: Int64,
        windowMs: Int64
    ): RateLimitStoreResult {
        checkCalls += 1
        inner.consumeWindowPermit(key, now, max, windowMs)
    }

    public override func cleanupExpired(now: MonoTime, windowMs: Int64): Unit {
        inner.cleanupExpired(now, windowMs)
    }
}

class RecordingResponseCacheStore <: ResponseCacheStore {
    let inner = MemoryResponseCacheStore()
    var lookupCalls: Int64 = 0
    var putCalls: Int64 = 0

    public override func getFresh(
        key: String,
        now: MonoTime,
        expiration: Duration
    ): ?ResponseCacheValue {
        lookupCalls += 1
        inner.getFresh(key, now, expiration)
    }

    public override func put(
        key: String,
        body: String,
        contentType: String,
        now: MonoTime
    ): Unit {
        putCalls += 1
        inner.put(key, body, contentType, now)
    }

    public override func cleanupExpired(now: MonoTime, expiration: Duration): Unit {
        inner.cleanupExpired(now, expiration)
    }
}

class RecordingIdempotencyStore <: IdempotencyStore {
    let inner = MemoryIdempotencyStore()
    var lookupCalls: Int64 = 0
    var putCalls: Int64 = 0

    public override func getFresh(
        key: String,
        now: MonoTime,
        lifetime: Duration
    ): ?IdempotencyValue {
        lookupCalls += 1
        inner.getFresh(key, now, lifetime)
    }

    public override func put(key: String, body: String, now: MonoTime): Unit {
        putCalls += 1
        inner.put(key, body, now)
    }

    public override func cleanupExpired(now: MonoTime, lifetime: Duration): Unit {
        inner.cleanupExpired(now, lifetime)
    }
}

func extractCookieValueForStore(setCookie: String, name: String): String {
    if (setCookie.size == 0) {
        return ""
    }
    let firstPart = setCookie.split(";", 2)[0].trimAscii()
    let kv = firstPart.split("=", 2)
    if (kv.size != 2) {
        return ""
    }
    if (kv[0].trimAscii() != name) {
        return ""
    }
    kv[1].trimAscii()
}
