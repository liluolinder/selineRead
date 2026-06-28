package ignite.tests

import ignite.*
import ignite.middleware.*

@Test
public class CorsMiddlewareRegressionTestSuite {
    @TestCase
    public func testCorsReflectsOriginWhenCredentialsEnabled(): Unit {
        let app = App(config: Config())
        app.use(
            corsMiddleware(
                config: CorsConfig(allowCredentials: true)
            )
        )
        app.get("/cors", { ctx =>
            _ = ctx.sendString("ok")
        })

        let resp = app.handleForTest(
            "GET",
            "/cors",
            headers: [("origin", "https://app.ignite.dev")]
        )
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("access-control-allow-origin") ?? "", "https://app.ignite.dev")
        @Assert(resp.header("access-control-allow-credentials") ?? "", "true")
        @Assert(resp.header("vary") ?? "", "Origin")
    }

    @TestCase
    public func testCorsRejectsOriginOutsideConfiguredAllowList(): Unit {
        let app = App(config: Config())
        app.use(
            corsMiddleware(
                config: CorsConfig(
                    allowOrigins: "https://a.ignite.dev, https://b.ignite.dev",
                    allowCredentials: true
                )
            )
        )
        app.get("/cors", { ctx =>
            _ = ctx.sendString("ok")
        })

        let resp = app.handleForTest(
            "GET",
            "/cors",
            headers: [("origin", "https://evil.example")]
        )
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("access-control-allow-origin") ?? "", "")
        @Assert(resp.header("access-control-allow-credentials") ?? "", "")
    }
}
