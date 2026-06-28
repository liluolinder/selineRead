package ignite.tests

import ignite.*
import ignite.middleware.*
import std.time.MonoTime

@Test
public class RateLimitMiddlewareRegressionTestSuite {
    @TestCase
    public func testRateLimitMiddlewareSetsRetryAfterHeaders(): Unit {
        let app = App(config: Config())
        app.use(
            rateLimitMiddleware(
                config: RateLimitConfig(
                    max: 1,
                    windowMs: 200,
                    cleanupEvery: 1,
                    keyGenerator: { ctx => ctx.header("x-key") ?? ctx.ip }
                )
            )
        )
        app.get("/limited", { ctx =>
            _ = ctx.sendString("ok")
        })

        let first = app.handleForTest(
            "GET",
            "/limited",
            headers: [("x-key", "alpha")]
        )
        @Assert(first.status, UInt16(200))
        @Assert(first.header("x-ratelimit-limit") ?? "", "1")
        @Assert(first.header("x-ratelimit-remaining") ?? "", "0")

        let second = app.handleForTest(
            "GET",
            "/limited",
            headers: [("x-key", "alpha")]
        )
        @Assert(second.status, UInt16(429))
        @Assert(second.body, "Too Many Requests")
        @Assert(second.header("x-ratelimit-limit") ?? "", "1")
        @Assert(second.header("x-ratelimit-remaining") ?? "", "0")
        @Assert(second.header("x-ratelimit-reset") ?? "", "1")
        @Assert(second.header("retry-after") ?? "", "1")
    }

    @TestCase
    public func testRateLimitMiddlewareAllowsFreshWindowAfterExpiry(): Unit {
        let app = App(config: Config())
        app.use(
            rateLimitMiddleware(
                config: RateLimitConfig(
                    max: 1,
                    windowMs: 50,
                    cleanupEvery: 1,
                    keyGenerator: { ctx => ctx.header("x-key") ?? ctx.ip }
                )
            )
        )
        app.get("/limited", { ctx =>
            _ = ctx.sendString("ok")
        })

        let first = app.handleForTest(
            "GET",
            "/limited",
            headers: [("x-key", "beta")]
        )
        @Assert(first.status, UInt16(200))

        let blocked = app.handleForTest(
            "GET",
            "/limited",
            headers: [("x-key", "beta")]
        )
        @Assert(blocked.status, UInt16(429))

        waitRateLimitMs(70)

        let third = app.handleForTest(
            "GET",
            "/limited",
            headers: [("x-key", "beta")]
        )
        @Assert(third.status, UInt16(200))
        @Assert(third.body, "ok")
        @Assert(third.header("x-ratelimit-remaining") ?? "", "0")
    }
}

func waitRateLimitMs(ms: Int64): Unit {
    let start = MonoTime.now()
    while ((MonoTime.now() - start).toMilliseconds() < ms) {}
}
