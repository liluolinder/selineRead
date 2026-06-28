package ignite.tests

import ignite.*
import std.collection.ArrayList

@Test
public class RouterHttpSemanticsTestSuite {
    @TestCase
    public func testMethodMismatchReturnsAllowedMethods(): Unit {
        let router = Router(Config())
        let handlers = ArrayList<Handler>()
        handlers.add({ ctx => ctx.sendString("ok") })
        router.addRoute("GET", "/users/:id", handlers)
        router.addRoute("POST", "/users/:id", handlers)

        let result = router.matchRoute("PUT", "/users/42")
        @Assert(result.matched, false)
        @Assert(contains(result.allowedMethods, "GET"), true)
        @Assert(contains(result.allowedMethods, "POST"), true)
    }

    @TestCase
    public func testUnknownPathHasNoAllowedMethods(): Unit {
        let router = Router(Config())
        let handlers = ArrayList<Handler>()
        handlers.add({ ctx => ctx.sendString("ok") })
        router.addRoute("GET", "/health", handlers)

        let result = router.matchRoute("POST", "/unknown")
        @Assert(result.matched, false)
        @Assert(result.allowedMethods.size, 0)
    }

    @TestCase
    public func testValidationFailureKeeps404Semantics(): Unit {
        let router = Router(Config())
        let handlers = ArrayList<Handler>()
        handlers.add({ ctx => ctx.sendString("ok") })
        let option = RouteOption().withParamValidation("id", "int")
        router.addRoute("GET", "/orders/:id", handlers, option: option)

        let result = router.matchRoute("GET", "/orders/abc")
        @Assert(result.matched, false)
        @Assert(result.allowedMethods.size, 0)
    }

    @TestCase
    public func testCatchAllRouteAlsoMatchesRootPath(): Unit {
        let router = Router(Config())
        let handlers = ArrayList<Handler>()
        handlers.add({ ctx => ctx.sendString("ok") })
        router.addRoute("GET", "/*", handlers)

        let result = router.matchRoute("GET", "/")
        @Assert(result.matched, true)
        @Assert(result.params.get("*") ?? "missing", "")
        match (result.route) {
            case Some(route) => @Assert(route.path, "/*")
            case None => throw Exception("expected catch-all route for root path")
        }
    }

    @TestCase
    public func testExactRootStillWinsOverCatchAllRootMatch(): Unit {
        let router = Router(Config())
        let exactHandlers = ArrayList<Handler>()
        exactHandlers.add({ ctx => ctx.sendString("root") })
        let catchAllHandlers = ArrayList<Handler>()
        catchAllHandlers.add({ ctx => ctx.sendString("catch") })
        router.addRoute("GET", "/", exactHandlers)
        router.addRoute("GET", "/*", catchAllHandlers)

        let result = router.matchRoute("GET", "/")
        @Assert(result.matched, true)
        match (result.route) {
            case Some(route) => @Assert(route.path, "/")
            case None => throw Exception("expected exact root route")
        }
    }

    func contains(values: ArrayList<String>, target: String): Bool {
        for (v in values) {
            if (v == target) {
                return true
            }
        }
        false
    }
}
