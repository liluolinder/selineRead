package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.ArrayList

@Test
public class HandleForTestStressSuite {
    @TestCase
    public func testHandleForTestLifecycleRecyclesRapidly(): Unit {
        let iterations: Int64 = 48
        let app = App(config: Config(appName: "ignite-stress-rapid-recycle"))
        app.get("/ping", { ctx =>
            ctx.sendString("pong")
        })

        var i: Int64 = 0
        while (i < iterations) {
            let resp = app.handleForTest("GET", "/ping")
            @Assert(resp.status, UInt16(200))
            @Assert(resp.body, "pong")
            i += 1
        }
    }

    @TestCase
    public func testHandleForTestAlternatesMethodsAndPaths(): Unit {
        let app = App(config: Config(appName: "ignite-stress-multi-route"))
        app.get("/status", { ctx => ctx.sendString("alive") })
        app.post("/data", { ctx =>
            _ = ctx.status(201).sendString("stored")
        })

        var round: Int64 = 0
        while (round < 12) {
            let getResp = app.handleForTest("GET", "/status")
            @Assert(getResp.status, UInt16(200))
            @Assert(getResp.body, "alive")

            let postResp = app.handleForTest("POST", "/data", body: "x=${round}")
            @Assert(postResp.status, UInt16(201))
            @Assert(postResp.body, "stored")
            round += 1
        }
    }

    @TestCase
    public func testHandleForTestWithMiddlewareStress(): Unit {
        let lines = ArrayList<String>()
        let cfg = LoggerConfig(
            output: { line => lines.add(line) },
            enableEntityLog: false
        )
        cfg.jsonLine = true
        cfg.linuxStyle = false
        cfg.enableSelfCheck = false

        let app = App(config: Config())
        app.use(loggerMiddleware(config: cfg))
        app.get("/mid", { ctx => ctx.sendString("ok") })

        var i: Int64 = 0
        while (i < 12) {
            let resp = app.handleForTest("GET", "/mid")
            @Assert(resp.status, UInt16(200))
            @Assert(resp.body, "ok")
            i += 1
        }
        @Assert(lines.size >= 12, true)
    }
}
