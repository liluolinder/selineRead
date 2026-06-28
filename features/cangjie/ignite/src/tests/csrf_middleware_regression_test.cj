package ignite.tests

import ignite.*
import ignite.middleware.*
import std.time.MonoTime

@Test
public class CsrfMiddlewareRegressionTestSuite {
    @TestCase
    public func testCsrfMiddlewareRejectsExpiredToken(): Unit {
        let app = App(config: Config())
        app.use(
            csrfMiddleware(
                config: CsrfConfig(
                    cookieMaxAge: 1,
                    cleanupEvery: 1
                )
            )
        )
        app.get("/form", { ctx =>
            _ = ctx.sendString("form")
        })
        app.post("/submit", { ctx =>
            _ = ctx.sendString("submitted")
        })

        let seed = app.handleForTest("GET", "/form")
        let token = extractCookieValue(seed.header("set-cookie") ?? "", "_csrf")
        @Assert(token != "", true)

        waitCsrfMs(1100)

        let resp = app.handleForTest(
            "POST",
            "/submit",
            headers: [
                ("x-csrf-token", token),
                ("cookie", "_csrf=${token}")
            ]
        )
        @Assert(resp.status, UInt16(403))
        @Assert(resp.body, "Forbidden - CSRF token invalid")
    }

    @TestCase
    public func testCsrfMiddlewareRotatesTokenAfterSuccessfulSubmit(): Unit {
        let app = App(config: Config())
        app.use(
            csrfMiddleware(
                config: CsrfConfig(cleanupEvery: 1)
            )
        )
        app.get("/form", { ctx =>
            _ = ctx.sendString("form")
        })
        app.post("/submit", { ctx =>
            _ = ctx.sendString("submitted")
        })

        let seed = app.handleForTest("GET", "/form")
        let token = extractCookieValue(seed.header("set-cookie") ?? "", "_csrf")
        @Assert(token != "", true)

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

        let rotated = extractCookieValue(resp.header("set-cookie") ?? "", "_csrf")
        @Assert(rotated != "", true)
        @Assert(rotated == token, false)
    }
}

func extractCookieValue(setCookie: String, name: String): String {
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

func waitCsrfMs(ms: Int64): Unit {
    let start = MonoTime.now()
    while ((MonoTime.now() - start).toMilliseconds() < ms) {}
}
