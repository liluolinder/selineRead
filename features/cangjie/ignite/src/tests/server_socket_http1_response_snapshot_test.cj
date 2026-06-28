package ignite.tests

import ignite.*

@Test
public class SocketHttp11ResponseSnapshotTestSuite {
    @TestCase
    public func testResponseSnapshotPreservesKnownLengthEnvelope(): Unit {
        let request = openSocketHttp11ResponseSnapshotTestRequest(
            "GET /hello HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            200,
            socketHttp11ResponseSnapshotSingleHeader("content-type", "text/plain"),
            SocketHttp11ResponseBodyMode.KnownLength,
            declaredBodyBytes: 5
        )
        let snapshot = buildSocketHttp11ResponseSnapshot(plan)

        @Assert(snapshot.version, "HTTP/1.1")
        @Assert(snapshot.statusCode, 200)
        @Assert(snapshot.reasonPhrase, "OK")
        @Assert(snapshot.requestedBodyMode, SocketHttp11ResponseBodyMode.KnownLength)
        @Assert(snapshot.headerFraming, SocketHttp11ResponseHeaderFraming.ContentLength)
        @Assert(snapshot.declaredBodyBytes, 5)
        @Assert(snapshot.keepAliveAllowed, true)
        @Assert(snapshot.closeAfterWrite, false)
        @Assert(snapshot.header("content-type") ?? "", "text/plain")
        @Assert(snapshot.header("content-length") ?? "", "5")
        @Assert(snapshot.header("connection").isNone(), true)
        @Assert(snapshot.writesPayloadBody(), true)
        @Assert(snapshot.usesChunkedTransfer(), false)
        @Assert(snapshot.shouldCloseConnection(), false)
    }

    @TestCase
    public func testResponseSnapshotPreservesChunkedUnknownLengthIntent(): Unit {
        let request = openSocketHttp11ResponseSnapshotTestRequest(
            "GET /stream HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            200,
            socketHttp11ResponseSnapshotSingleHeader("content-type", "text/plain"),
            SocketHttp11ResponseBodyMode.UnknownLength
        )
        let snapshot = buildSocketHttp11ResponseSnapshot(plan)

        @Assert(snapshot.statusCode, 200)
        @Assert(snapshot.requestedBodyMode, SocketHttp11ResponseBodyMode.UnknownLength)
        @Assert(snapshot.headerFraming, SocketHttp11ResponseHeaderFraming.Chunked)
        @Assert(snapshot.declaredBodyBytes, -1)
        @Assert(snapshot.header("transfer-encoding") ?? "", "chunked")
        @Assert(snapshot.writesPayloadBody(), true)
        @Assert(snapshot.usesChunkedTransfer(), true)
        @Assert(snapshot.shouldCloseConnection(), false)
    }

    @TestCase
    public func testResponseSnapshotPreservesBodySuppressionAndCloseIntent(): Unit {
        let headRequest = openSocketHttp11ResponseSnapshotTestRequest(
            "HEAD /hello HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let headPlan = buildSocketHttp11ResponseWritePlan(
            headRequest,
            200,
            socketHttp11ResponseSnapshotSingleHeader("content-type", "text/plain"),
            SocketHttp11ResponseBodyMode.KnownLength,
            declaredBodyBytes: 7
        )
        let headSnapshot = buildSocketHttp11ResponseSnapshot(headPlan)

        @Assert(headSnapshot.suppressesBodyForHead, true)
        @Assert(headSnapshot.suppressesBodyForStatus, false)
        @Assert(headSnapshot.writesPayloadBody(), false)
        @Assert(headSnapshot.header("content-length") ?? "", "7")

        let closeRequest = openSocketHttp11ResponseSnapshotTestRequest(
            "GET /bye HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"
        )
        let closePlan = buildSocketHttp11ResponseWritePlan(
            closeRequest,
            204,
            Array<SocketHttp11Header>(0, repeat: SocketHttp11Header("", "")),
            SocketHttp11ResponseBodyMode.Bodyless
        )
        let closeSnapshot = buildSocketHttp11ResponseSnapshot(closePlan)

        @Assert(closeSnapshot.suppressesBodyForStatus, true)
        @Assert(closeSnapshot.keepAliveAllowed, false)
        @Assert(closeSnapshot.closeAfterWrite, true)
        @Assert(closeSnapshot.header("connection") ?? "", "close")
        @Assert(closeSnapshot.writesPayloadBody(), false)
        @Assert(closeSnapshot.shouldCloseConnection(), true)
    }
}

func openSocketHttp11ResponseSnapshotTestRequest(wire: String): SocketHttp11SessionRequest {
    let session = SocketHttp11ConnectionSession()
    session.appendHeadBytes(wire.toArray())
    match (session.tryOpenRequest()) {
        case Some(request) => request
        case None => @Fail("complete HTTP/1.1 request should open before response snapshot tests")
    }
}

func socketHttp11ResponseSnapshotSingleHeader(
    name: String,
    value: String
): Array<SocketHttp11Header> {
    let out = Array<SocketHttp11Header>(1, repeat: SocketHttp11Header("", ""))
    out[0] = SocketHttp11Header(name, value)
    out
}
