package ignite.tests

import ignite.*
import std.collection.ArrayList

class RouteSurfaceActor {
    let id: String

    init(id: String) {
        this.id = id
    }
}

@Test
public class RouteSurfaceRegressionTestSuite {
    @TestCase
    public func testAppRouteHandlerArraysRunInOrder(): Unit {
        let steps = ArrayList<String>()
        let app = App()
        let first: Handler = { ctx =>
            steps.add("first")
            ctx.next()
        }
        let second: Handler = { ctx =>
            steps.add("second")
            ctx.next()
        }
        let last: Handler = { ctx =>
            steps.add("last")
            let _ = ctx.sendString("ok")
        }
        let routeHandlers: Array<Handler> = [first, second, last]
        app.get("/chain", routeHandlers)

        let resp = app.handleForTest("GET", "/chain")
        @Assert(resp.status, 200)
        @Assert(resp.body, "ok")
        @Assert(joinSteps(steps), "first>second>last")
    }

    @TestCase
    public func testGroupRouteHandlerArraysPreserveGroupMiddlewareOrder(): Unit {
        let steps = ArrayList<String>()
        let app = App()
        let api = app.group("/api")
        api.use({ ctx =>
            steps.add("group")
            ctx.next()
        })
        let first: Handler = { ctx =>
            steps.add("first")
            ctx.next()
        }
        let second: Handler = { ctx =>
            steps.add("second")
            let _ = ctx.sendString("group-ok")
        }
        let routeHandlers: Array<Handler> = [first, second]
        api.get("/users", routeHandlers)

        let resp = app.handleForTest("GET", "/api/users")
        @Assert(resp.status, 200)
        @Assert(resp.body, "group-ok")
        @Assert(joinSteps(steps), "group>first>second")
    }

    @TestCase
    public func testCustomNotFoundAndMethodNotAllowedHandlersCanReplaceDefaultBodies(): Unit {
        let app = App()
        app.use({ ctx =>
            let _ = ctx.setHeader("x-global-middleware", "1")
            ctx.next()
        })
        app.get("/users", { ctx =>
            let _ = ctx.sendString("users")
        })
        app.notFound({ ctx =>
            let _ = ctx.setHeader("x-ignite-not-found", "1").sendString("custom-404")
        })
        app.methodNotAllowed({ ctx =>
            let _ = ctx.setHeader("x-ignite-method-not-allowed", "1").sendString("custom-405")
        })

        let notFoundResp = app.handleForTest("POST", "/missing")
        @Assert(notFoundResp.status, 404)
        @Assert(notFoundResp.body, "custom-404")
        @Assert(notFoundResp.header("x-ignite-not-found") ?? "", "1")
        @Assert(notFoundResp.header("x-global-middleware") ?? "", "1")

        let methodNotAllowedResp = app.handleForTest("POST", "/users")
        @Assert(methodNotAllowedResp.status, 405)
        @Assert(methodNotAllowedResp.body, "custom-405")
        @Assert(methodNotAllowedResp.header("x-ignite-method-not-allowed") ?? "", "1")
        @Assert(methodNotAllowedResp.header("allow") ?? "", "GET")
        @Assert(methodNotAllowedResp.header("x-global-middleware") ?? "", "1")
    }

    @TestCase
    public func testTypedLocalValuesCoexistWithStringLocals(): Unit {
        let app = App()
        app.get("/locals", { ctx =>
            ctx.setLocal("mode", "strict")
            ctx.setLocalValue("actor", RouteSurfaceActor("u-1"))
            ctx.setLocalValue("count", Int64(7))
            let actor = ctx.getLocalValue<RouteSurfaceActor>("actor")
            let mode = ctx.getLocalValue<String>("mode")
            let count = ctx.getLocalValue<Int64>("count")
            let actorId = match (actor) {
                case Some(value) => value.id
                case None => "missing"
            }
            let currentMode = mode ?? "missing"
            let legacyMode = ctx.getLocal("mode") ?? "missing"
            let currentCount = count ?? Int64(-1)
            let body =
                "{\"actor\":\"" + actorId +
                "\",\"mode\":\"" + currentMode +
                "\",\"legacyMode\":\"" + legacyMode +
                "\",\"count\":" + currentCount.toString() + "}"
            let _ = ctx.json(body)
        })

        let resp = app.handleForTest("GET", "/locals")
        @Assert(resp.status, 200)
        @Assert(contains(resp.body, #""actor":"u-1""#), true)
        @Assert(contains(resp.body, #""mode":"strict""#), true)
        @Assert(contains(resp.body, #""legacyMode":"strict""#), true)
        @Assert(contains(resp.body, #""count":7"#), true)
    }

    func joinSteps(steps: ArrayList<String>): String {
        var out = ""
        var first = true
        for (step in steps) {
            if (!first) {
                out += ">"
            }
            first = false
            out += step
        }
        out
    }

    func contains(text: String, target: String): Bool {
        let t = text.toRuneArray()
        let p = target.toRuneArray()
        if (p.size == 0) {
            return true
        }
        if (t.size < p.size) {
            return false
        }
        var i: Int64 = 0
        while (i <= t.size - p.size) {
            var ok = true
            var j: Int64 = 0
            while (j < p.size) {
                if (t[i + j] != p[j]) {
                    ok = false
                    break
                }
                j += 1
            }
            if (ok) {
                return true
            }
            i += 1
        }
        false
    }
}
