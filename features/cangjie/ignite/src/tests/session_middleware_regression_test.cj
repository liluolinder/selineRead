package ignite.tests

import ignite.*
import ignite.middleware.*
import std.time.MonoTime

@Test
public class SessionMiddlewareRegressionTestSuite {
    @TestCase
    public func testSessionMiddlewareKeepsFreshSessionData(): Unit {
        let store = SessionStore()
        let app = App(config: Config())
        app.use(
            sessionMiddleware(
                config: SessionConfig(
                    cookieMaxAge: 5,
                    cleanupEvery: 1
                ),
                store: store
            )
        )
        app.get("/seed", { ctx =>
            let sessionId = ctx.getLocal("session_id") ?? ""
            store.set(sessionId, "role", "admin")
            _ = ctx.sendString("seed")
        })
        app.get("/read", { ctx =>
            let sessionId = ctx.getLocal("session_id") ?? ""
            _ = ctx.sendString(store.get(sessionId, "role") ?? "")
        })

        let seed = app.handleForTest("GET", "/seed")
        let sessionId = extractCookieValue(seed.header("set-cookie") ?? "", "ignite_session")
        @Assert(sessionId != "", true)

        let read = app.handleForTest(
            "GET",
            "/read",
            headers: [("cookie", "ignite_session=${sessionId}")]
        )
        @Assert(read.status, UInt16(200))
        @Assert(read.body, "admin")
    }

    @TestCase
    public func testSessionMiddlewareDropsExpiredSessionData(): Unit {
        let store = SessionStore()
        let app = App(config: Config())
        app.use(
            sessionMiddleware(
                config: SessionConfig(
                    cookieMaxAge: 1,
                    cleanupEvery: 1
                ),
                store: store
            )
        )
        app.get("/seed", { ctx =>
            let sessionId = ctx.getLocal("session_id") ?? ""
            store.set(sessionId, "role", "admin")
            _ = ctx.sendString("seed")
        })
        app.get("/read", { ctx =>
            let sessionId = ctx.getLocal("session_id") ?? ""
            _ = ctx.sendString(store.get(sessionId, "role") ?? "")
        })

        let seed = app.handleForTest("GET", "/seed")
        let sessionId = extractCookieValue(seed.header("set-cookie") ?? "", "ignite_session")
        @Assert(sessionId != "", true)

        waitSessionMs(1100)

        let read = app.handleForTest(
            "GET",
            "/read",
            headers: [("cookie", "ignite_session=${sessionId}")]
        )
        @Assert(read.status, UInt16(200))
        @Assert(read.body, "")
    }
}

func waitSessionMs(ms: Int64): Unit {
    let start = MonoTime.now()
    while ((MonoTime.now() - start).toMilliseconds() < ms) {}
}
