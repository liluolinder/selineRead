package ignite.tests

import ignite.*

@Test
public class SocketHttp11RuntimeTurnCloseoutTestSuite {
    @TestCase
    public func testTurnCloseoutKeepsConnectionReusableWhenBothSidesAllowKeepAlive(): Unit {
        let request = openSocketHttp11TurnCloseoutRequest(
            "GET /hello HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            200,
            socketHttp11TurnCloseoutSingleHeader("content-type", "text/plain"),
            SocketHttp11ResponseBodyMode.KnownLength,
            declaredBodyBytes: 5
        )
        let response = buildSocketHttp11ResponseSnapshot(plan)
        let closeout = buildSocketHttp11RuntimeTurnCloseout(request, response)

        @Assert(closeout.requestCloseAfterResponse, false)
        @Assert(closeout.responseRequestsClose, false)
        @Assert(closeout.shouldCloseConnection, false)
        @Assert(closeout.nextConnectionState, SocketHttp11ConnectionState.ReceivingHead)
        @Assert(closeout.canReuseConnection(), true)
        @Assert(closeout.closeReason, "-")
    }

    @TestCase
    public func testTurnCloseoutPreservesRequestSideCloseReason(): Unit {
        let request = openSocketHttp11TurnCloseoutRequest(
            "GET /bye HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"
        )
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            204,
            Array<SocketHttp11Header>(0, repeat: SocketHttp11Header("", "")),
            SocketHttp11ResponseBodyMode.Bodyless
        )
        let response = buildSocketHttp11ResponseSnapshot(plan)
        let closeout = buildSocketHttp11RuntimeTurnCloseout(request, response)

        @Assert(closeout.requestCloseAfterResponse, true)
        @Assert(closeout.responseRequestsClose, true)
        @Assert(closeout.shouldCloseConnection, true)
        @Assert(closeout.nextConnectionState, SocketHttp11ConnectionState.Closing)
        @Assert(closeout.canReuseConnection(), false)
        @Assert(closeout.closeReason, "connection_close_header")
    }

    @TestCase
    public func testTurnCloseoutLetsResponseForceCloseWithoutRequestCloseHeader(): Unit {
        let request = openSocketHttp11TurnCloseoutRequest(
            "GET /drain HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            200,
            socketHttp11TurnCloseoutSingleHeader("content-type", "text/plain"),
            SocketHttp11ResponseBodyMode.Bodyless,
            option: SocketHttp11ResponseWriteOption(closeAfterWrite: true)
        )
        let response = buildSocketHttp11ResponseSnapshot(plan)
        let closeout = buildSocketHttp11RuntimeTurnCloseout(request, response)

        @Assert(closeout.requestCloseAfterResponse, false)
        @Assert(response.keepAliveAllowed, false)
        @Assert(response.closeAfterWrite, true)
        @Assert(closeout.responseRequestsClose, true)
        @Assert(closeout.shouldCloseConnection, true)
        @Assert(closeout.nextConnectionState, SocketHttp11ConnectionState.Closing)
        @Assert(closeout.closeReason, "response_close_after_write")
    }

    @TestCase
    public func testTurnCloseoutPreservesPipeliningCloseReason(): Unit {
        let wire =
            "GET /first HTTP/1.1\r\nHost: example.com\r\n\r\n" +
            "GET /second HTTP/1.1\r\nHost: example.com\r\n\r\n"
        let request = openSocketHttp11TurnCloseoutRequest(wire)
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            200,
            Array<SocketHttp11Header>(0, repeat: SocketHttp11Header("", "")),
            SocketHttp11ResponseBodyMode.Bodyless
        )
        let response = buildSocketHttp11ResponseSnapshot(plan)
        let closeout = buildSocketHttp11RuntimeTurnCloseout(request, response)

        @Assert(request.closeAfterResponse, true)
        @Assert(request.closeReason, "pipelining_not_supported")
        @Assert(closeout.shouldCloseConnection, true)
        @Assert(closeout.closeReason, "pipelining_not_supported")
        @Assert(closeout.nextConnectionState, SocketHttp11ConnectionState.Closing)
    }
}

func openSocketHttp11TurnCloseoutRequest(wire: String): SocketHttp11SessionRequest {
    let session = SocketHttp11ConnectionSession()
    session.appendHeadBytes(wire.toArray())
    match (session.tryOpenRequest()) {
        case Some(request) => request
        case None => @Fail("complete HTTP/1.1 request should open before turn closeout tests")
    }
}

func socketHttp11TurnCloseoutSingleHeader(
    name: String,
    value: String
): Array<SocketHttp11Header> {
    let out = Array<SocketHttp11Header>(1, repeat: SocketHttp11Header("", ""))
    out[0] = SocketHttp11Header(name, value)
    out
}
