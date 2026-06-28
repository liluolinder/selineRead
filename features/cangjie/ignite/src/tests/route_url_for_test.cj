package ignite.tests

import ignite.*

@Test
public class RouteUrlForTestSuite {
    @TestCase
    public func testUrlForWithOperationIdRouteName(): Unit {
        let app = App(config: Config())
        app.get(
            "/users/:id/posts/:postId",
            { ctx => _ = ctx.sendString("ok") },
            option: RouteOption().withOperationId("user.post.detail")
        )

        let url = mustUrl(
            app.urlFor(
                "user.post.detail",
                params: [("id", "42"), ("postId", "7")],
                query: [("include", "meta data"), ("lang", "zh-CN")]
            ),
            "urlFor(operationId) should return url"
        )
        @Assert(url, "/users/42/posts/7?include=meta+data&lang=zh-CN")
    }

    @TestCase
    public func testUrlForWithExplicitNameRoute(): Unit {
        let app = App(config: Config())
        app.get("/assets/*", { ctx => _ = ctx.sendString("ok") })

        let named = app.nameRoute("get", "assets/*", "asset.file")
        @Assert(named, true)

        let url = mustUrl(
            app.urlFor("asset.file", params: [("*", "img/logo.png")]),
            "urlFor(named route) should return url"
        )
        @Assert(url, "/assets/img/logo.png")
    }

    @TestCase
    public func testUrlForReturnsNoneWhenParamMissingOrRouteMissing(): Unit {
        let app = App(config: Config())
        app.get(
            "/orders/:orderId/items/:itemId",
            { ctx => _ = ctx.sendString("ok") },
            option: RouteOption().withOperationId("order.item")
        )

        let missingParam = app.urlFor("order.item", params: [("orderId", "1001")])
        match (missingParam) {
            case Some(_) => throw Exception("expected None for missing path param")
            case None => ()
        }

        let missingRoute = app.urlFor("not.exists", params: [("id", "1")])
        match (missingRoute) {
            case Some(_) => throw Exception("expected None for missing route name")
            case None => ()
        }
    }

    func mustUrl(v: ?String, message: String): String {
        match (v) {
            case Some(url) => url
            case None => throw Exception(message)
        }
    }
}
