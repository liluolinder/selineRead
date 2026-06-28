package ignite.tests

import ignite.*

@Test
public class SocketHttp11AcceptOnceExperimentTestSuite {
    @TestCase
    public func testAcceptOnceExperimentServesChunkedStreamTurnOverRealSocket(): Unit {
        let result = runSocketHttp11AcceptOnceExperiment(
            "GET /stream HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray()
        )

        @Assert(result.listenerHost, "127.0.0.1")
        @Assert(result.listenerPort > 0, true)
        @Assert(result.acceptedRemoteAddress.size > 0, true)
        @Assert(
            result.serverObservedRequestText(),
            "GET /stream HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        @Assert(result.runtime.responderLabel, "stream")
        @Assert(result.runtime.responseStatusCode, 200)
        @Assert(result.runtime.responseHeaderFraming, SocketHttp11ResponseHeaderFraming.Chunked)
        @Assert(result.runtime.closeoutShouldCloseConnection, false)
        @Assert(result.helperAllowsConnectionReuse(), true)
        @Assert(result.transportClosedAfterServeOnce, true)
        @Assert(result.experimentForcedCloseAgainstReusableHelper(), true)
        @Assert(
            result.clientObservedResponseText(),
            "HTTP/1.1 200 OK\r\n" +
            "content-type: text/plain; charset=utf-8\r\n" +
            "x-ignite-runtime-experiment: stream\r\n" +
            "transfer-encoding: chunked\r\n\r\n" +
            "6\r\nstream\r\n" +
            "0\r\n\r\n"
        )
    }

    @TestCase
    public func testAcceptOnceExperimentKeepsServeOnceForcedCloseHonesty(): Unit {
        let result = runSocketHttp11AcceptOnceExperiment(
            "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray()
        )

        @Assert(result.runtime.responderLabel, "health")
        @Assert(result.runtime.responseStatusCode, 200)
        @Assert(result.runtime.responseCloseAfterWrite, false)
        @Assert(result.runtime.closeoutShouldCloseConnection, false)
        @Assert(result.runtime.finalConnectionState, SocketHttp11ConnectionState.ReceivingHead)
        @Assert(result.helperAllowsConnectionReuse(), true)
        @Assert(result.transportClosedAfterServeOnce, true)
        @Assert(result.experimentOwnsServeOnceLifecycle, true)
        @Assert(result.experimentForcedCloseAgainstReusableHelper(), true)
        @Assert(
            result.clientObservedResponseText(),
            "HTTP/1.1 200 OK\r\n" +
            "content-type: text/plain; charset=utf-8\r\n" +
            "x-ignite-runtime-experiment: health\r\n" +
            "content-length: 2\r\n\r\n" +
            "ok"
        )
    }

    @TestCase
    public func testAcceptOnceExperimentKeepsBodyStageGapBlockedOnRealSocketTurn(): Unit {
        try {
            let _ = runSocketHttp11AcceptOnceExperiment(
                "POST /health HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nabc".toArray()
            )
            @Fail("accept-once experiment should keep the body-stage boundary blocked")
        } catch (e: SocketHttp11AcceptOnceExperimentException) {
            @Assert(e.runtimeCode, SocketHttp11RuntimeExperimentErrorCode.BodyStageRequired)
            @Assert(e.listenerHost, "127.0.0.1")
            @Assert(e.listenerPort > 0, true)
            @Assert(e.acceptedRemoteAddress.size > 0, true)
            @Assert(e.clientObservedResponseWireBytes.size, 0)
            @Assert(
                socketHttp11AcceptOnceContains(
                    e.serverObservedRequestText(),
                    "POST /health HTTP/1.1"
                ),
                true
            )
        }
    }
}

func socketHttp11AcceptOnceContains(text: String, target: String): Bool {
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
