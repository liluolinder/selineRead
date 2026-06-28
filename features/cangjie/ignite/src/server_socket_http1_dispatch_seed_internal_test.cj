package ignite

@Test
public class SocketHttp11DispatchSeedInternalTestSuite {
    @TestCase
    public func testBuildDispatchSeedFromOriginFormAndResolvePlan(): Unit {
        let app = App()
        app.get("/users/:id", { ctx =>
            let _ = ctx.sendString(ctx.params("id"))
        })

        let request = openSocketHttp11DispatchSeedTestRequest(
            "GET /users/42?expand=1 HTTP/1.1\r\nHost: api.example.com\r\n\r\n"
        )
        let seed = buildSocketHttp11DispatchSeed(request)

        @Assert(seed.requestMethod, "GET")
        @Assert(seed.targetFormName(), "origin-form")
        @Assert(seed.authority, "api.example.com")
        @Assert(seed.scheme, "")
        @Assert(seed.queryString, "expand=1")
        @Assert(seed.normalizedDispatchTarget(), "/users/42?expand=1")
        @Assert(seed.canResolveDispatchPlan(), true)
        match (seed.dispatchPath) {
            case Some(path) => @Assert(path, "/users/42")
            case None => @Fail("origin-form request should expose a dispatch path")
        }

        match (tryResolveSocketHttp11PlannedDispatch(app, request)) {
            case Some(planned) =>
                @Assert(planned.seed.targetFormName(), "origin-form")
                @Assert(planned.plan.matched(), true)
                @Assert(planned.plan.requestPath, "/users/42")
                @Assert(planned.plan.params.get("id") ?? "", "42")
            case None => @Fail("origin-form request should resolve an app dispatch plan")
        }
    }

    @TestCase
    public func testBuildDispatchSeedFromAbsoluteFormAndResolvePlan(): Unit {
        let app = App()
        app.get("/health/live", { ctx =>
            let _ = ctx.sendString("ok")
        })

        let request = openSocketHttp11DispatchSeedTestRequest(
            "GET http://127.0.0.1:8080/health/live?probe=1 HTTP/1.1\r\nHost: ignored.example.com\r\n\r\n"
        )
        let seed = buildSocketHttp11DispatchSeed(request)

        @Assert(seed.targetFormName(), "absolute-form")
        @Assert(seed.authority, "127.0.0.1:8080")
        @Assert(seed.scheme, "http")
        @Assert(seed.queryString, "probe=1")
        @Assert(seed.normalizedDispatchTarget(), "/health/live?probe=1")
        @Assert(seed.canResolveDispatchPlan(), true)
        match (seed.dispatchPath) {
            case Some(path) => @Assert(path, "/health/live")
            case None => @Fail("absolute-form request should expose a dispatch path")
        }

        match (tryResolveSocketHttp11PlannedDispatch(app, request)) {
            case Some(planned) =>
                @Assert(planned.plan.matched(), true)
                @Assert(planned.plan.requestPath, "/health/live")
            case None => @Fail("absolute-form request should resolve an app dispatch plan")
        }
    }

    @TestCase
    public func testAuthorityAndAsteriskTargetsStayNonDispatchable(): Unit {
        let connectRequest = openSocketHttp11DispatchSeedTestRequest(
            "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\n\r\n"
        )
        let connectSeed = buildSocketHttp11DispatchSeed(connectRequest)
        @Assert(connectSeed.targetFormName(), "authority-form")
        @Assert(connectSeed.authority, "example.com:443")
        @Assert(connectSeed.canResolveDispatchPlan(), false)
        match (connectSeed.dispatchPath) {
            case Some(_) => @Fail("authority-form target should stay non-dispatchable")
            case None => ()
        }

        let optionsRequest = openSocketHttp11DispatchSeedTestRequest(
            "OPTIONS * HTTP/1.1\r\nHost: api.example.com\r\n\r\n"
        )
        let optionsSeed = buildSocketHttp11DispatchSeed(optionsRequest)
        @Assert(optionsSeed.targetFormName(), "asterisk-form")
        @Assert(optionsSeed.authority, "api.example.com")
        @Assert(optionsSeed.canResolveDispatchPlan(), false)
        match (optionsSeed.dispatchPath) {
            case Some(_) => @Fail("asterisk-form target should stay non-dispatchable")
            case None => ()
        }
    }

    @TestCase
    public func testDispatchSeedRejectsFragmentAndMissingAuthorityTargets(): Unit {
        let fragmented = openSocketHttp11DispatchSeedTestRequest(
            "GET /bad#frag HTTP/1.1\r\nHost: api.example.com\r\n\r\n"
        )
        assertSocketHttp11DispatchSeedFailure(
            fragmented,
            SocketHttp11DispatchSeedErrorCode.FragmentNotAllowed
        )

        let missingAuthority = openSocketHttp11DispatchSeedTestRequest(
            "GET http:///broken HTTP/1.1\r\nHost: api.example.com\r\n\r\n"
        )
        assertSocketHttp11DispatchSeedFailure(
            missingAuthority,
            SocketHttp11DispatchSeedErrorCode.MissingAbsoluteAuthority
        )
    }
}

func openSocketHttp11DispatchSeedTestRequest(wire: String): SocketHttp11SessionRequest {
    let session = SocketHttp11ConnectionSession()
    session.appendHeadBytes(wire.toArray())
    match (session.tryOpenRequest()) {
        case Some(request) => request
        case None => @Fail("complete HTTP/1.1 request should open before dispatch-seed tests")
    }
}

func assertSocketHttp11DispatchSeedFailure(
    request: SocketHttp11SessionRequest,
    expected: SocketHttp11DispatchSeedErrorCode
): Unit {
    try {
        let _ = buildSocketHttp11DispatchSeed(request)
        @Fail("expected dispatch seed helper to reject the request target")
    } catch (e: SocketHttp11DispatchSeedException) {
        @Assert(e.code, expected)
    }
}
