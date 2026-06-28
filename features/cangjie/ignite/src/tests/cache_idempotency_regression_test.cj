package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.ArrayList
import std.time.MonoTime

@Test
public class CacheIdempotencyRegressionTestSuite {
    @TestCase
    public func testCacheMiddlewareExpiresAndMissesAgain(): Unit {
        let app = App(config: Config())
        let hits = ArrayList<String>()
        app.use(
            cacheMiddleware(
                config: CacheConfig(
                    expiration: Duration.second * 1,
                    cleanupEvery: 1
                )
            )
        )
        app.get("/cache", { ctx =>
            hits.add("hit")
            _ = ctx.sendString("value-${hits.size}")
        })

        let first = app.handleForTest("GET", "/cache")
        @Assert(first.status, UInt16(200))
        @Assert(first.body, "value-1")
        @Assert(first.header("x-cache") ?? "", "MISS")

        let second = app.handleForTest("GET", "/cache")
        @Assert(second.status, UInt16(200))
        @Assert(second.body, "value-1")
        @Assert(second.header("x-cache") ?? "", "HIT")

        waitCacheIdemMs(1100)

        let third = app.handleForTest("GET", "/cache")
        @Assert(third.status, UInt16(200))
        @Assert(third.body, "value-2")
        @Assert(third.header("x-cache") ?? "", "MISS")
    }

    @TestCase
    public func testIdempotencyMiddlewareStopsReusingExpiredEntry(): Unit {
        let app = App(config: Config())
        let hits = ArrayList<String>()
        app.use(
            idempotencyMiddleware(
                config: IdempotencyConfig(
                    lifetime: Duration.second * 1,
                    cleanupEvery: 1
                )
            )
        )
        app.post("/orders", { ctx =>
            hits.add("hit")
            _ = ctx.json("{\"n\":${hits.size}}")
        })

        let first = app.handleForTest(
            "POST",
            "/orders",
            headers: [("x-idempotency-key", "order-1")]
        )
        @Assert(first.status, UInt16(200))
        @Assert(first.body, "{\"n\":1}")
        @Assert(first.header("x-idempotency-cached") ?? "", "")

        let second = app.handleForTest(
            "POST",
            "/orders",
            headers: [("x-idempotency-key", "order-1")]
        )
        @Assert(second.status, UInt16(200))
        @Assert(second.body, "{\"n\":1}")
        @Assert(second.header("x-idempotency-cached") ?? "", "true")

        waitCacheIdemMs(1100)

        let third = app.handleForTest(
            "POST",
            "/orders",
            headers: [("x-idempotency-key", "order-1")]
        )
        @Assert(third.status, UInt16(200))
        @Assert(third.body, "{\"n\":2}")
        @Assert(third.header("x-idempotency-cached") ?? "", "")
    }
}

func waitCacheIdemMs(ms: Int64): Unit {
    let start = MonoTime.now()
    while ((MonoTime.now() - start).toMilliseconds() < ms) {}
}
