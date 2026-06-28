package ignite.tests

import ignite.*

@Test
public class SocketHttp11ConnectionSessionTestSuite {
    @TestCase
    public func testSessionBuffersPartialHeadUntilRequestCanOpen(): Unit {
        let session = SocketHttp11ConnectionSession()
        session.appendHeadBytes("POST /upload HTTP/1.1\r\nHost: example.com\r\n".toArray())

        match (session.tryOpenRequest()) {
            case Some(_) => @Fail("partial head should not open a request")
            case None =>
                @Assert(session.state(), SocketHttp11ConnectionState.ReceivingHead)
                @Assert(session.bufferedHeadBytes() > 0, true)
        }

        session.appendHeadBytes("Content-Length: 4\r\n\r\nab".toArray())

        match (session.tryOpenRequest()) {
            case Some(request) =>
                @Assert(session.state(), SocketHttp11ConnectionState.AwaitingBody)
                @Assert(request.head.method, "POST")
                @Assert(request.bodyPlan.framing, SocketHttp11RequestBodyFraming.ContentLength)
                @Assert(request.bodyPlan.declaredBodyBytes, 4)
                @Assert(request.bodyPlan.remainingNetworkBodyBytes, 2)
                @Assert(request.bodyPlan.requiresBodyStage, true)
                @Assert(request.bodyPlan.needsMoreNetworkBytes, true)
                @Assert(String.fromUtf8(request.bodyPlan.prefetchedBodyBytes), "ab")
                @Assert(request.bodyPlan.trailingBufferedBytes.size, 0)
            case None => @Fail("complete head should open a request")
        }
    }

    @TestCase
    public func testSessionMovesThroughKeepAliveBodylessRequest(): Unit {
        let session = SocketHttp11ConnectionSession()
        session.appendHeadBytes("GET /hello HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray())

        match (session.tryOpenRequest()) {
            case Some(request) =>
                @Assert(session.state(), SocketHttp11ConnectionState.ReadyToDispatch)
                @Assert(request.keepAliveAllowed, true)
                @Assert(request.closeAfterResponse, false)
                @Assert(request.allowPipelining, false)
                @Assert(request.pipelinedBytesDetected, false)
                @Assert(request.closeReason, "-")
                @Assert(request.bodyPlan.framing, SocketHttp11RequestBodyFraming.Bodyless)
                @Assert(request.bodyPlan.requiresBodyStage, false)
            case None => @Fail("bodyless request should open")
        }

        session.beginResponseWrite()
        @Assert(session.state(), SocketHttp11ConnectionState.WritingResponse)
        session.finishResponseWrite()
        @Assert(session.state(), SocketHttp11ConnectionState.ReceivingHead)
    }

    @TestCase
    public func testSessionRejectsBufferedPipeliningForInitialModel(): Unit {
        let session = SocketHttp11ConnectionSession()
        let wire =
            "GET /first HTTP/1.1\r\nHost: example.com\r\n\r\n" +
            "GET /second HTTP/1.1\r\nHost: example.com\r\n\r\n"
        session.appendHeadBytes(wire.toArray())

        match (session.tryOpenRequest()) {
            case Some(request) =>
                @Assert(session.state(), SocketHttp11ConnectionState.ReadyToDispatch)
                @Assert(request.allowPipelining, false)
                @Assert(request.pipelinedBytesDetected, true)
                @Assert(request.keepAliveAllowed, false)
                @Assert(request.closeAfterResponse, true)
                @Assert(request.closeReason, "pipelining_not_supported")
                @Assert(String.fromUtf8(request.bodyPlan.trailingBufferedBytes), "GET /second HTTP/1.1\r\nHost: example.com\r\n\r\n")
            case None => @Fail("first request should still open")
        }
    }

    @TestCase
    public func testSessionHonorsConnectionCloseAndClosingTransition(): Unit {
        let session = SocketHttp11ConnectionSession()
        session.appendHeadBytes(
            "GET /bye HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n".toArray()
        )

        match (session.tryOpenRequest()) {
            case Some(request) =>
                @Assert(request.keepAliveAllowed, false)
                @Assert(request.closeAfterResponse, true)
                @Assert(request.closeReason, "connection_close_header")
            case None => @Fail("request should open")
        }

        session.beginResponseWrite()
        session.finishResponseWrite()
        @Assert(session.state(), SocketHttp11ConnectionState.Closing)
        session.markClosed()
        @Assert(session.state(), SocketHttp11ConnectionState.Closed)
    }

    @TestCase
    public func testSessionBuildsChunkedBodyPlan(): Unit {
        let session = SocketHttp11ConnectionSession()
        session.appendHeadBytes(
            "POST /stream HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nWiki\r\n".toArray()
        )

        match (session.tryOpenRequest()) {
            case Some(request) =>
                @Assert(session.state(), SocketHttp11ConnectionState.AwaitingBody)
                @Assert(request.bodyPlan.framing, SocketHttp11RequestBodyFraming.Chunked)
                @Assert(request.bodyPlan.declaredBodyBytes, -1)
                @Assert(request.bodyPlan.remainingNetworkBodyBytes, -1)
                @Assert(request.bodyPlan.requiresBodyStage, true)
                @Assert(request.bodyPlan.needsMoreNetworkBytes, true)
                @Assert(String.fromUtf8(request.bodyPlan.prefetchedBodyBytes), "4\r\nWiki\r\n")
            case None => @Fail("chunked request should open")
        }
    }

    @TestCase
    public func testSessionRejectsMixedOrConflictingBodyFramingHeaders(): Unit {
        assertSocketHttp11SessionFailure(
            "POST /bad HTTP/1.1\r\nHost: example.com\r\nContent-Length: 4\r\nTransfer-Encoding: chunked\r\n\r\n".toArray(),
            SocketHttp11SessionErrorCode.ContentLengthWithTransferEncoding
        )

        assertSocketHttp11SessionFailure(
            "POST /bad HTTP/1.1\r\nHost: example.com\r\nContent-Length: 4\r\nContent-Length: 5\r\n\r\n".toArray(),
            SocketHttp11SessionErrorCode.ConflictingContentLength
        )
    }
}

func assertSocketHttp11SessionFailure(
    bytes: Array<UInt8>,
    expectedCode: SocketHttp11SessionErrorCode
): Unit {
    let session = SocketHttp11ConnectionSession()
    session.appendHeadBytes(bytes)
    try {
        let _ = session.tryOpenRequest()
        @Fail("socket HTTP/1.1 session parse should have failed")
    } catch (e: SocketHttp11SessionException) {
        @Assert(e.code, expectedCode)
    }
}
