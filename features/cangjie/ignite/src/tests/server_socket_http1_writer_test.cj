package ignite.tests

import ignite.*

@Test
public class SocketHttp11ResponseWriterTestSuite {
    @TestCase
    public func testWriterPlanBuildsKnownLengthHeadAndLifecycle(): Unit {
        let request = openSocketHttp11WriterTestRequest(
            "GET /hello HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            200,
            socketHttp11WriterSingleHeader("content-type", "text/plain"),
            SocketHttp11ResponseBodyMode.KnownLength,
            declaredBodyBytes: 5
        )

        @Assert(plan.headerFraming, SocketHttp11ResponseHeaderFraming.ContentLength)
        @Assert(plan.declaredBodyBytes, 5)
        @Assert(plan.suppressesBodyForHead, false)
        @Assert(plan.suppressesBodyForStatus, false)
        @Assert(plan.keepAliveAllowed, true)
        @Assert(plan.closeAfterWrite, false)
        @Assert(plan.writesPayloadBody(), true)
        @Assert(plan.header("content-type") ?? "", "text/plain")
        @Assert(plan.header("content-length") ?? "", "5")
        @Assert(plan.header("connection") ?? "", "")

        let expectedHead =
            "HTTP/1.1 200 OK\r\n" +
            "content-type: text/plain\r\n" +
            "content-length: 5\r\n\r\n"
        @Assert(String.fromUtf8(plan.headBytes), expectedHead)

        let writer = SocketHttp11ResponseWriterLifecycle(plan)
        @Assert(writer.state(), SocketHttp11WriterLifecycleState.Ready)
        @Assert(String.fromUtf8(writer.takeHeadBytes()), expectedHead)
        @Assert(writer.state(), SocketHttp11WriterLifecycleState.HeadCommitted)
        @Assert(String.fromUtf8(writer.writeBodyChunk("he".toArray())), "he")
        @Assert(String.fromUtf8(writer.writeBodyChunk("llo".toArray())), "llo")
        @Assert(writer.bodyBytesWritten(), 5)
        @Assert(String.fromUtf8(writer.finish()), "")
        @Assert(writer.state(), SocketHttp11WriterLifecycleState.Completed)
        @Assert(writer.shouldCloseConnection(), false)
    }

    @TestCase
    public func testWriterPlanBuildsChunkedUnknownLengthLifecycle(): Unit {
        let request = openSocketHttp11WriterTestRequest(
            "GET /stream HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            200,
            socketHttp11WriterSingleHeader("content-type", "text/plain"),
            SocketHttp11ResponseBodyMode.UnknownLength
        )

        @Assert(plan.headerFraming, SocketHttp11ResponseHeaderFraming.Chunked)
        @Assert(plan.declaredBodyBytes, -1)
        @Assert(plan.writesPayloadBody(), true)
        @Assert(plan.usesChunkedTransfer(), true)
        @Assert(plan.header("transfer-encoding") ?? "", "chunked")
        @Assert(plan.closeAfterWrite, false)

        let writer = SocketHttp11ResponseWriterLifecycle(plan)
        let _ = writer.takeHeadBytes()
        @Assert(String.fromUtf8(writer.writeBodyChunk("abc".toArray())), "3\r\nabc\r\n")
        @Assert(String.fromUtf8(writer.writeBodyChunk("de".toArray())), "2\r\nde\r\n")
        @Assert(writer.bodyBytesWritten(), 5)
        @Assert(String.fromUtf8(writer.finish()), "0\r\n\r\n")
        @Assert(writer.state(), SocketHttp11WriterLifecycleState.Completed)
    }

    @TestCase
    public func testWriterPlanSuppressesHeadBodyButKeepsKnownLengthHeader(): Unit {
        let request = openSocketHttp11WriterTestRequest(
            "HEAD /hello HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            200,
            socketHttp11WriterSingleHeader("content-type", "text/plain"),
            SocketHttp11ResponseBodyMode.KnownLength,
            declaredBodyBytes: 7
        )

        @Assert(plan.headerFraming, SocketHttp11ResponseHeaderFraming.ContentLength)
        @Assert(plan.suppressesBodyForHead, true)
        @Assert(plan.suppressesBodyForStatus, false)
        @Assert(plan.declaredBodyBytes, 7)
        @Assert(plan.writesPayloadBody(), false)
        @Assert(plan.header("content-length") ?? "", "7")
        @Assert(plan.header("transfer-encoding") ?? "", "")

        let writer = SocketHttp11ResponseWriterLifecycle(plan)
        let _ = writer.takeHeadBytes()
        assertSocketHttp11WriterChunkFailure(
            writer,
            "ignored".toArray(),
            SocketHttp11WriterErrorCode.BodyNotAllowed
        )

        let cleanWriter = SocketHttp11ResponseWriterLifecycle(plan)
        let _ = cleanWriter.takeHeadBytes()
        @Assert(String.fromUtf8(cleanWriter.finish()), "")
        @Assert(cleanWriter.state(), SocketHttp11WriterLifecycleState.Completed)
    }

    @TestCase
    public func testWriterPlanCarriesConnectionCloseIntoResponseHead(): Unit {
        let request = openSocketHttp11WriterTestRequest(
            "GET /bye HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"
        )
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            200,
            Array<SocketHttp11Header>(0, repeat: SocketHttp11Header("", "")),
            SocketHttp11ResponseBodyMode.Bodyless
        )

        @Assert(plan.headerFraming, SocketHttp11ResponseHeaderFraming.Bodyless)
        @Assert(plan.keepAliveAllowed, false)
        @Assert(plan.closeAfterWrite, true)
        @Assert(plan.header("connection") ?? "", "close")
        @Assert(
            String.fromUtf8(plan.headBytes),
            "HTTP/1.1 200 OK\r\nconnection: close\r\n\r\n"
        )

        let writer = SocketHttp11ResponseWriterLifecycle(plan)
        let _ = writer.takeHeadBytes()
        @Assert(String.fromUtf8(writer.finish()), "")
        @Assert(writer.shouldCloseConnection(), true)
    }

    @TestCase
    public func testWriterPlanRejectsInvalidInputsAndReservedHeaders(): Unit {
        let request = openSocketHttp11WriterTestRequest(
            "GET /fail HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )

        assertSocketHttp11WriterBuildFailure(
            request,
            99,
            Array<SocketHttp11Header>(0, repeat: SocketHttp11Header("", "")),
            SocketHttp11ResponseBodyMode.Bodyless,
            -1,
            SocketHttp11WriterErrorCode.InvalidStatusCode
        )

        assertSocketHttp11WriterBuildFailure(
            request,
            200,
            socketHttp11WriterSingleHeader("content-length", "5"),
            SocketHttp11ResponseBodyMode.Bodyless,
            -1,
            SocketHttp11WriterErrorCode.ReservedProtocolHeader
        )

        assertSocketHttp11WriterBuildFailure(
            request,
            200,
            Array<SocketHttp11Header>(0, repeat: SocketHttp11Header("", "")),
            SocketHttp11ResponseBodyMode.KnownLength,
            -1,
            SocketHttp11WriterErrorCode.InvalidKnownLength
        )

        assertSocketHttp11WriterBuildFailure(
            request,
            204,
            Array<SocketHttp11Header>(0, repeat: SocketHttp11Header("", "")),
            SocketHttp11ResponseBodyMode.UnknownLength,
            -1,
            SocketHttp11WriterErrorCode.BodyForbiddenByStatus
        )
    }

    @TestCase
    public func testWriterLifecycleRejectsIncompleteKnownLengthFinish(): Unit {
        let request = openSocketHttp11WriterTestRequest(
            "GET /partial HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let plan = buildSocketHttp11ResponseWritePlan(
            request,
            200,
            Array<SocketHttp11Header>(0, repeat: SocketHttp11Header("", "")),
            SocketHttp11ResponseBodyMode.KnownLength,
            declaredBodyBytes: 4
        )
        let writer = SocketHttp11ResponseWriterLifecycle(plan)

        let _ = writer.takeHeadBytes()
        let _ = writer.writeBodyChunk("ab".toArray())
        try {
            let _ = writer.finish()
            @Fail("known-length response should fail when body bytes are incomplete")
        } catch (e: SocketHttp11WriterException) {
            @Assert(e.code, SocketHttp11WriterErrorCode.KnownLengthIncomplete)
            @Assert(writer.state(), SocketHttp11WriterLifecycleState.Failed)
        }
    }
}

func openSocketHttp11WriterTestRequest(wire: String): SocketHttp11SessionRequest {
    let session = SocketHttp11ConnectionSession()
    session.appendHeadBytes(wire.toArray())
    match (session.tryOpenRequest()) {
        case Some(request) => request
        case None => @Fail("complete HTTP/1.1 request should open before writer tests")
    }
}

func socketHttp11WriterSingleHeader(name: String, value: String): Array<SocketHttp11Header> {
    let out = Array<SocketHttp11Header>(1, repeat: SocketHttp11Header("", ""))
    out[0] = SocketHttp11Header(name, value)
    out
}

func assertSocketHttp11WriterBuildFailure(
    request: SocketHttp11SessionRequest,
    statusCode: Int64,
    headers: Array<SocketHttp11Header>,
    bodyMode: SocketHttp11ResponseBodyMode,
    declaredBodyBytes: Int64,
    expectedCode: SocketHttp11WriterErrorCode
): Unit {
    try {
        let _ = buildSocketHttp11ResponseWritePlan(
            request,
            statusCode,
            headers,
            bodyMode,
            declaredBodyBytes: declaredBodyBytes
        )
        @Fail("socket HTTP/1.1 response writer plan should have failed")
    } catch (e: SocketHttp11WriterException) {
        @Assert(e.code, expectedCode)
    }
}

func assertSocketHttp11WriterChunkFailure(
    writer: SocketHttp11ResponseWriterLifecycle,
    bytes: Array<UInt8>,
    expectedCode: SocketHttp11WriterErrorCode
): Unit {
    try {
        let _ = writer.writeBodyChunk(bytes)
        @Fail("socket HTTP/1.1 response writer chunk write should have failed")
    } catch (e: SocketHttp11WriterException) {
        @Assert(e.code, expectedCode)
    }
}
