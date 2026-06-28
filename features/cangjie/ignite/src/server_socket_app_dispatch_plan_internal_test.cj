package ignite

import std.collection.ArrayList
import std.collection.HashMap
import std.io.InputStream
import stdx.net.http.{HttpContext, HttpHeaders, WebSocket}

@Test
public class AppDispatchPlanInternalTestSuite {
    @TestCase
    public func testResolveAppDispatchPlanBuildsMatchedRoutePlan(): Unit {
        let app = App()
        app.use({ ctx =>
            ctx.next()
        })
        app.get("/users/:id", { ctx =>
            let _ = ctx.sendString(ctx.params("id"))
        })

        let plan = resolveAppDispatchPlan(app, "GET", "/users/42")

        @Assert(plan.matched(), true)
        @Assert(plan.kindName(), "matched")
        @Assert(plan.requestMethod, "GET")
        @Assert(plan.requestPath, "/users/42")
        @Assert(plan.params.get("id") ?? "", "42")
        @Assert(plan.handlers.size, Int64(2))
        @Assert(plan.allowedMethods.size, Int64(0))
        match (plan.route) {
            case Some(route) =>
                @Assert(route.method, "GET")
                @Assert(route.path, "/users/:id")
            case None => @Fail("matched dispatch plan should keep selected route")
        }
    }

    @TestCase
    public func testResolveAppDispatchPlanBuildsMethodNotAllowedFallbackPlan(): Unit {
        let app = App()
        app.use({ ctx =>
            ctx.next()
        })
        app.get("/users", { ctx =>
            let _ = ctx.sendString("users")
        })

        let plan = resolveAppDispatchPlan(app, "POST", "/users")

        @Assert(plan.matched(), false)
        @Assert(plan.kindName(), "method-not-allowed")
        @Assert(plan.requestMethod, "POST")
        @Assert(plan.requestPath, "/users")
        @Assert(plan.params.size, Int64(0))
        @Assert(plan.handlers.size, Int64(2))
        @Assert(containsDispatchPlanMethod(plan.allowedMethods, "GET"), true)
        match (plan.route) {
            case Some(_) => @Fail("method-not-allowed fallback should not keep a matched route")
            case None => ()
        }
    }

    @TestCase
    public func testResolveAppDispatchPlanDoesNotNeedHttpContextForNotFoundPlanning(): Unit {
        let app = App()
        app.use({ ctx =>
            ctx.next()
        })
        app.get("/health", { ctx =>
            let _ = ctx.sendString("ok")
        })

        let plan = resolveAppDispatchPlan(app, "DELETE", "/missing")

        @Assert(plan.matched(), false)
        @Assert(plan.kindName(), "not-found")
        @Assert(plan.requestMethod, "DELETE")
        @Assert(plan.requestPath, "/missing")
        @Assert(plan.params.size, Int64(0))
        @Assert(plan.handlers.size, Int64(2))
        @Assert(plan.allowedMethods.size, Int64(0))
        match (plan.route) {
            case Some(_) => @Fail("not-found planning should not require a selected route")
            case None => ()
        }
    }

    @TestCase
    public func testMethodNotAllowedFallbackDoesNotShareMutableAllowListWithPlanMetadata(): Unit {
        let app = App()
        app.get("/users", { ctx =>
            let _ = ctx.sendString("users")
        })

        let plan = resolveAppDispatchPlan(app, "POST", "/users")
        @Assert(plan.kindName(), "method-not-allowed")
        @Assert(plan.allowedMethods.size, Int64(1))
        let _ = plan.allowedMethods.remove(at: Int64(0))
        @Assert(plan.allowedMethods.size, Int64(0))

        let carrier = DispatchPlanTrackingCarrier("POST", "/users")
        match (prepareCurrentCarrierDispatchContext(app, carrier, plan)) {
            case Some(ctx) => executePreparedCurrentCarrierDispatch(app, ctx)
            case None => @Fail("method-not-allowed planning should still build a dispatch context")
        }

        @Assert(carrier.responseStatus, UInt16(405))
        @Assert(carrier.header("allow") ?? "", "GET")
        @Assert(carrier.responseBody, "Method Not Allowed")
    }
}

func containsDispatchPlanMethod(methods: ArrayList<String>, target: String): Bool {
    for (method in methods) {
        if (method == target) {
            return true
        }
    }
    false
}

class DispatchPlanTrackingCarrier <: CurrentRequestCarrier {
    let methodText: String
    let pathText: String
    let body = DispatchPlanEmptyInputStream()
    let responseHeaders = HashMap<String, String>()
    public var responseStatus: UInt16 = 200
    public var responseBody: String = ""

    init(methodText: String, pathText: String) {
        this.methodText = methodText
        this.pathText = pathText
    }

    public func header(name: String): ?String {
        responseHeaders.get(name.trimAscii().toAsciiLower())
    }

    public override func rawHttpContext(): HttpContext {
        throw Exception("raw HttpContext should not be required in dispatch plan internal tests")
    }

    public override func upgradeWebSocketRaw(): WebSocket {
        throw Exception("websocket upgrade should not run in dispatch plan internal tests")
    }

    public override func openResponseTransportWriterRaw(): ResponseTransportWriter {
        throw Exception("response transport writer should not open in dispatch plan internal tests")
    }

    public override func requestMethod(): String {
        methodText
    }

    public override func requestPath(): String {
        pathText
    }

    public override func requestUrlString(): String {
        pathText
    }

    public override func requestVersionString(): String {
        "HTTP/1.1"
    }

    public override func requestRemoteAddr(): String {
        "127.0.0.1"
    }

    public override func requestQueryValue(key: String): ?String {
        let _ = key
        None
    }

    public override func requestFormValue(key: String): ?String {
        let _ = key
        None
    }

    public override func requestHeaderValue(key: String): ?String {
        let _ = key
        None
    }

    public override func requestHeaders(): HttpHeaders {
        HttpHeaders()
    }

    public override func requestBodyStream(): InputStream {
        body
    }

    public override func requestBodySize(): ?Int64 {
        Some(Int64(0))
    }

    public override func setResponseStatus(code: UInt16): Unit {
        responseStatus = code
    }

    public override func setResponseHeader(key: String, value: String): Unit {
        responseHeaders.add(key.trimAscii().toAsciiLower(), value)
    }

    public override func addResponseHeaders(headers: HttpHeaders): Unit {
        let _ = headers
    }

    public override func setResponseString(body: String): Unit {
        responseBody = body
    }

    public override func setResponseBytes(data: Array<UInt8>): Unit {
        responseBody = String.fromUtf8(data)
    }

    public override func attachResponseBodyStream(stream: InputStream): Unit {
        let _ = stream
    }
}

class DispatchPlanEmptyInputStream <: InputStream {
    public override func read(outBuf: Array<Byte>): Int64 {
        let _ = outBuf
        0
    }

    public func close(): Unit {}
}
