package ignite.tests

import ignite.*
import ignite.middleware.*

@Test
public class RewriteMiddlewareRegressionTestSuite {
    @TestCase
    public func testRewriteMiddlewareRebindsRouteParamsAndPath(): Unit {
        let app = App(config: Config())
        app.use(
            rewriteMiddleware(
                RewriteConfig([("/legacy", "/api")])
            )
        )
        app.get("/api/users/:id", { ctx =>
            let userId = ctx.params("id")
            let rewriteFrom = ctx.getLocal("_rewrite_from") ?? ""
            let rewriteTo = ctx.getLocal("_rewrite_to") ?? ""
            _ = ctx.json(
                "{\"path\":\"${ctx.path}\",\"id\":\"${userId}\",\"from\":\"${rewriteFrom}\",\"to\":\"${rewriteTo}\"}"
            )
        })

        let resp = app.handleForTest(
            "GET",
            "/legacy/users/42?tab=base",
            headers: [("host", "ignite.dev")]
        )
        @Assert(resp.status, UInt16(200))
        @Assert(
            resp.body,
            "{\"path\":\"/api/users/42\",\"id\":\"42\",\"from\":\"/legacy/users/42\",\"to\":\"/api/users/42\"}"
        )
    }

    @TestCase
    public func testRewriteMiddlewarePreservesMethodMismatchSemantics(): Unit {
        let app = App(config: Config())
        app.use(
            rewriteMiddleware(
                RewriteConfig([("/legacy/users", "/users")])
            )
        )
        app.get("/users", { ctx =>
            _ = ctx.sendString("ok")
        })

        let resp = app.handleForTest(
            "POST",
            "/legacy/users",
            headers: [("host", "ignite.dev")]
        )
        @Assert(resp.status, UInt16(405))
        @Assert(resp.body, "Method Not Allowed")
        @Assert(resp.header("allow") ?? "", "GET")
    }
}
