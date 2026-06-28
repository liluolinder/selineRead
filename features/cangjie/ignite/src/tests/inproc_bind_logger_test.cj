package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.ArrayList
import stdx.encoding.json.{JsonValue, JsonObject}

@Test
public class InprocBindLoggerTestSuite {
    @TestCase
    public func testHandleForTestRunsMiddlewareChain(): Unit {
        let app = App(config: Config())
        app.use({ ctx =>
            ctx.setHeader("x-mw", "hit")
            ctx.next()
        })
        app.get("/ping", { ctx =>
            let q = ctx.queryFromUrl("x") ?? "-"
            ctx.sendString("pong-${q}")
        })

        let resp = app.handleForTest("GET", "/ping?x=1")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.body, "pong-1")
        @Assert(resp.header("x-mw") ?? "", "hit")
    }

    @TestCase
    public func testHandleForTestRetriesOnAddressInUse(): Unit {
        let app = App(config: Config())
        let engine = RetryAddressInUseEngine()
        app.serverEngine(engine)
        app.get("/retry-port", { ctx =>
            ctx.sendString("retry-ok")
        })

        let resp = app.handleForTest("GET", "/retry-port")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.body, "retry-ok")
        @Assert(engine.listenCalls, 2)
        @Assert(engine.attemptedPorts.size, 2)
        @Assert(engine.attemptedPorts[0] == engine.attemptedPorts[1], false)
    }

    @TestCase
    public func testBindJsonOr400SuccessAndValidation(): Unit {
        let app = App(config: Config())
        app.post("/users", { ctx =>
            if (let Some(req) <- ctx.bindJsonOr400<CreateUserReq>(
                { jsonValue => decodeCreateUserReq(jsonValue) },
                validate: { req =>
                    if (req.name.trimAscii().size == 0) {
                        Some("name is required")
                    } else if (req.age <= 0) {
                        Some("age must be positive")
                    } else {
                        None
                    }
                }
            )) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.age}")
            }
        })

        let okResp = app.handleForTest(
            "POST",
            "/users",
            body: #"{"name":"ignite","age":7}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(okResp.status, UInt16(201))
        @Assert(okResp.body, "created:ignite:7")

        let badValidation = app.handleForTest(
            "POST",
            "/users",
            body: #"{"name":"ignite","age":0}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(badValidation.status, UInt16(400))
        @Assert(contains(badValidation.body, #""reason":"validation_failed""#), true)
        @Assert(contains(badValidation.body, "age must be positive"), true)
    }

    @TestCase
    public func testBindJsonOr400InvalidJsonReturnsReadable400(): Unit {
        let app = App(config: Config())
        app.post("/users", { ctx =>
            if (let Some(req) <- ctx.bindJsonOr400<CreateUserReq>(
                { jsonValue => decodeCreateUserReq(jsonValue) }
            )) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.age}")
            }
        })

        let resp = app.handleForTest(
            "POST",
            "/users",
            body: #"{"name":"broken","age":"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(resp.status, UInt16(400))
        @Assert(contains(resp.body, #""reason":"invalid_json""#), true)
        @Assert(contains(resp.body, "request body is not valid json"), true)
    }

    @TestCase
    public func testLoggerJsonLineOutput(): Unit {
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
        app.get("/json-log", { ctx => ctx.sendString("ok") })

        let resp = app.handleForTest("GET", "/json-log")
        @Assert(resp.status, UInt16(200))
        @Assert(lines.size > 0, true)

        let line = lines[lines.size - 1]
        @Assert(contains(line, #""method":"GET""#), true)
        @Assert(contains(line, #""path":"/json-log""#), true)
        @Assert(contains(line, #""status":200"#), true)
        @Assert(contains(line, #""message":"[GET] /json-log 200 "#), true)
    }

    @TestCase
    public func testLoggerJsonLineIncludesProxyObserveFields(): Unit {
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
        app.use({ ctx =>
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_MODE_LOCAL_KEY, "temp-file-buffered")
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_BYTES_LOCAL_KEY, "16384")
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_LOCAL_KEY, "8192")
            ctx.next()
            ctx.setLocal(IGNITE_PROXY_RESPONSE_BODY_MODE_LOCAL_KEY, "known-length-stream")
            ctx.setLocal(IGNITE_PROXY_RESPONSE_BODY_BYTES_LOCAL_KEY, "2")
            ctx.setLocal(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_LOCAL_KEY, "known-length-stream")
            ctx.setLocal(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_LOCAL_KEY, "2")
        })
        app.post("/json-log-proxy", { ctx =>
            let _ = ctx.status(201).sendString("ok")
        })

        let resp = app.handleForTest("POST", "/json-log-proxy", body: "proxy-body")
        @Assert(resp.status, UInt16(201))
        @Assert(lines.size > 0, true)

        let line = lines[lines.size - 1]
        @Assert(contains(line, #""proxyBodyMode":"temp-file-buffered""#), true)
        @Assert(contains(line, #""proxyBodyBytes":"16384""#), true)
        @Assert(contains(line, #""proxyBodyLimitBytes":"8192""#), true)
        @Assert(contains(line, #""proxyResponseBodyMode":"known-length-stream""#), true)
        @Assert(contains(line, #""proxyResponseBodyBytes":"2""#), true)
        @Assert(contains(line, #""proxyDownstreamBodyMode":"known-length-stream""#), true)
        @Assert(contains(line, #""proxyDownstreamBodyBytes":"2""#), true)
        @Assert(
            contains(
                line,
                #"proxyBodyMode=temp-file-buffered proxyBodyBytes=16384 proxyBodyLimitBytes=8192 proxyResponseBodyMode=known-length-stream proxyResponseBodyBytes=2 proxyDownstreamBodyMode=known-length-stream proxyDownstreamBodyBytes=2"#
            ),
            true
        )
    }

    func decodeCreateUserReq(jsonValue: JsonValue): CreateUserReq {
        let obj = jsonValue.asObject()
        let name = requireStringField(obj, "name")
        let age = requireIntField(obj, "age")
        CreateUserReq(name, age)
    }

    func requireStringField(obj: JsonObject, key: String): String {
        if (let Some(v) <- obj.get(key)) {
            return v.asString().getValue()
        }
        throw Exception("missing field: ${key}")
    }

    func requireIntField(obj: JsonObject, key: String): Int64 {
        if (let Some(v) <- obj.get(key)) {
            return v.asInt().getValue()
        }
        throw Exception("missing field: ${key}")
    }

    func contains(text: String, sub: String): Bool {
        let t = text.toRuneArray()
        let p = sub.toRuneArray()
        if (p.size == 0) { return true }
        if (t.size < p.size) { return false }
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
            if (ok) { return true }
            i += 1
        }
        false
    }
}

struct CreateUserReq {
    let name: String
    let age: Int64

    init(name: String, age: Int64) {
        this.name = name
        this.age = age
    }
}

class RetryAddressInUseEngine <: ServerEngine {
    let delegate = StdxServerEngine()
    public var listenCalls: Int64 = 0
    public let attemptedPorts: ArrayList<UInt16> = ArrayList<UInt16>()

    public override func listen(
        option: ServerEngineListenOption,
        app: App,
        onReady: ?((ServerEngineReadySignal) -> Unit)
    ): Unit {
        listenCalls += 1
        attemptedPorts.add(option.port)
        if (listenCalls == 1) {
            throw Exception("bind failed: address already in use")
        }
        delegate.listen(option, app, onReady)
    }

    public override func shutdown(): Unit {
        delegate.shutdown()
    }
}
