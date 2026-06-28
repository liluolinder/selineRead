package ignite.tests

import ignite.*

@Test
public class SocketHttp11RuntimeExperimentTestSuite {
    @TestCase
    public func testRuntimeExperimentBuildsKnownLengthHealthTurn(): Unit {
        let result = runSocketHttp11RuntimeExperiment(
            "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray(),
            remoteAddress: "127.0.0.1:9000"
        )

        @Assert(result.request.head.method, "GET")
        @Assert(result.requestDispatchPath, "/health")
        @Assert(result.requestRemoteAddress, "127.0.0.1:9000")
        @Assert(result.responseStatusCode, 200)
        @Assert(result.responseHeaderFraming, SocketHttp11ResponseHeaderFraming.ContentLength)
        @Assert(result.responseDeclaredBodyBytes, 2)
        @Assert(result.responseCloseAfterWrite, false)
        @Assert(result.responderLabel, "health")
        @Assert(String.fromUtf8(result.logicalBodyBytes), "ok")
        @Assert(result.closeoutShouldCloseConnection, false)
        @Assert(result.closeoutNextConnectionState, SocketHttp11ConnectionState.ReceivingHead)
        @Assert(result.finalConnectionState, SocketHttp11ConnectionState.ReceivingHead)
        @Assert(
            String.fromUtf8(result.responseWireBytes),
            "HTTP/1.1 200 OK\r\n" +
            "content-type: text/plain; charset=utf-8\r\n" +
            "x-ignite-runtime-experiment: health\r\n" +
            "content-length: 2\r\n\r\n" +
            "ok"
        )
    }

    @TestCase
    public func testRuntimeExperimentBuildsChunkedStreamTurn(): Unit {
        let result = runSocketHttp11RuntimeExperiment(
            "GET /stream HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray()
        )

        @Assert(result.responseStatusCode, 200)
        @Assert(result.responseHeaderFraming, SocketHttp11ResponseHeaderFraming.Chunked)
        @Assert(result.responseDeclaredBodyBytes, -1)
        @Assert(result.responseHeader("transfer-encoding") ?? "", "chunked")
        @Assert(result.responderLabel, "stream")
        @Assert(result.closeoutShouldCloseConnection, false)
        @Assert(result.finalConnectionState, SocketHttp11ConnectionState.ReceivingHead)
        @Assert(
            String.fromUtf8(result.responseWireBytes),
            "HTTP/1.1 200 OK\r\n" +
            "content-type: text/plain; charset=utf-8\r\n" +
            "x-ignite-runtime-experiment: stream\r\n" +
            "transfer-encoding: chunked\r\n\r\n" +
            "6\r\nstream\r\n" +
            "0\r\n\r\n"
        )
    }

    @TestCase
    public func testRuntimeExperimentCarriesCloseAfterWriteTurn(): Unit {
        let result = runSocketHttp11RuntimeExperiment(
            "GET /close HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray()
        )

        @Assert(result.responseStatusCode, 202)
        @Assert(result.responseCloseAfterWrite, true)
        @Assert(result.responseKeepAliveAllowed, false)
        @Assert(result.responseHeader("connection") ?? "", "close")
        @Assert(result.responderLabel, "close")
        @Assert(result.closeoutResponseRequestsClose, true)
        @Assert(result.closeoutShouldCloseConnection, true)
        @Assert(result.closeoutCloseReason, "response_close_after_write")
        @Assert(result.finalConnectionState, SocketHttp11ConnectionState.Closing)
        @Assert(
            String.fromUtf8(result.responseWireBytes),
            "HTTP/1.1 202 Accepted\r\n" +
            "content-type: text/plain; charset=utf-8\r\n" +
            "x-ignite-runtime-experiment: close\r\n" +
            "content-length: 3\r\n" +
            "connection: close\r\n\r\n" +
            "bye"
        )
    }

    @TestCase
    public func testRuntimeExperimentHonestGapStopsAtBodyStageBoundary(): Unit {
        try {
            let _ = runSocketHttp11RuntimeExperiment(
                "POST /health HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nabc".toArray()
            )
            @Fail("runtime experiment should refuse requests that still require body-stage handoff")
        } catch (e: SocketHttp11RuntimeExperimentException) {
            @Assert(e.code, SocketHttp11RuntimeExperimentErrorCode.BodyStageRequired)
        }
    }
}
