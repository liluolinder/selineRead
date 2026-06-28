package ignite.tests

import ignite.*

@Test
public class SocketHttp11CountLimitedAcceptLoopExperimentTestSuite {
    @TestCase
    public func testCountLimitedAcceptLoopServesTwoConnectionsThenStopsAtLimit(): Unit {
        let result = runSocketHttp11CountLimitedAcceptLoopExperiment(
            "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray(),
            "GET /health?connection=2 HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray()
        )

        @Assert(result.listenerHost, "127.0.0.1")
        @Assert(result.listenerPort > 0, true)
        @Assert(result.acceptedConnectionLimit, 2)
        @Assert(result.acceptedConnectionCount, 2)
        @Assert(result.explicitAcceptLoopOwnsLifecycle, true)
        @Assert(result.exitedBecauseAcceptedConnectionLimitReached, true)
        @Assert(result.firstConnectionClosedBeforeSecondAccept, true)
        @Assert(result.secondConnectionClosedAfterResponse, true)
        @Assert(result.firstConnection.connectionIndex, 1)
        @Assert(result.secondConnection.connectionIndex, 2)
        @Assert(result.acceptedRemoteAddressesDiffer(), true)
        @Assert(
            result.firstConnection.serverObservedRequestText(),
            "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        @Assert(
            result.secondConnection.serverObservedRequestText(),
            "GET /health?connection=2 HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        @Assert(result.firstConnection.runtime.responderLabel, "health")
        @Assert(result.secondConnection.runtime.responderLabel, "health")
        @Assert(result.firstConnection.runtime.requestDispatchPath, "/health")
        @Assert(result.secondConnection.runtime.requestDispatchPath, "/health")
        @Assert(result.secondConnection.runtime.requestQueryString, "connection=2")
        @Assert(result.firstConnection.helperAllowsConnectionReuse(), true)
        @Assert(result.secondConnection.helperAllowsConnectionReuse(), true)
        @Assert(result.firstConnection.experimentForcedCloseAgainstReusableHelper(), true)
        @Assert(result.secondConnection.experimentForcedCloseAgainstReusableHelper(), true)
        @Assert(
            result.secondConnection.clientObservedResponseText(),
            "HTTP/1.1 200 OK\r\n" +
            "content-type: text/plain; charset=utf-8\r\n" +
            "x-ignite-runtime-experiment: health\r\n" +
            "content-length: 2\r\n\r\n" +
            "ok"
        )
    }

    @TestCase
    public func testCountLimitedAcceptLoopLetsSecondConnectionOwnCloseRequest(): Unit {
        let result = runSocketHttp11CountLimitedAcceptLoopExperiment(
            "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray(),
            "GET /close HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray()
        )

        @Assert(result.acceptedConnectionLimit, 2)
        @Assert(result.acceptedConnectionCount, 2)
        @Assert(result.explicitAcceptLoopOwnsLifecycle, true)
        @Assert(result.exitedBecauseAcceptedConnectionLimitReached, true)
        @Assert(result.firstConnectionClosedBeforeSecondAccept, true)
        @Assert(result.secondConnectionClosedAfterResponse, true)
        @Assert(result.firstConnection.helperAllowsConnectionReuse(), true)
        @Assert(result.firstConnection.experimentForcedCloseAgainstReusableHelper(), true)
        @Assert(result.secondConnection.runtime.responderLabel, "close")
        @Assert(result.secondConnection.runtime.responseStatusCode, 202)
        @Assert(result.secondConnection.runtime.responseCloseAfterWrite, true)
        @Assert(result.secondConnection.runtime.closeoutShouldCloseConnection, true)
        @Assert(result.secondConnection.helperAllowsConnectionReuse(), false)
        @Assert(result.secondConnection.experimentForcedCloseAgainstReusableHelper(), false)
        @Assert(
            result.secondConnection.clientObservedResponseText(),
            "HTTP/1.1 202 Accepted\r\n" +
            "content-type: text/plain; charset=utf-8\r\n" +
            "x-ignite-runtime-experiment: close\r\n" +
            "content-length: 3\r\n" +
            "connection: close\r\n\r\n" +
            "bye"
        )
    }

    @TestCase
    public func testCountLimitedAcceptLoopKeepsBodyStageGapBlockedBeforeLimit(): Unit {
        try {
            let _ = runSocketHttp11CountLimitedAcceptLoopExperiment(
                "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray(),
                "POST /health HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nabc".toArray()
            )
            @Fail("count-limited accept-loop experiment should keep the body-stage boundary blocked")
        } catch (e: SocketHttp11CountLimitedAcceptLoopExperimentException) {
            @Assert(e.runtimeCode, SocketHttp11RuntimeExperimentErrorCode.BodyStageRequired)
            @Assert(e.failedConnectionIndex, 2)
            @Assert(e.listenerHost, "127.0.0.1")
            @Assert(e.listenerPort > 0, true)
            @Assert(e.acceptedConnectionLimit, 2)
            @Assert(e.completedConnectionCount, 1)
            @Assert(e.explicitAcceptLoopOwnsLifecycle, true)
            @Assert(e.stoppedBeforeAcceptedConnectionLimitReached, true)
            @Assert(e.failedConnectionAcceptedRemoteAddress.size > 0, true)
            @Assert(e.firstConnectionClosedBeforeSecondAccept, true)
            @Assert(e.failedConnectionClosedAfterResponse, true)
            if (let Some(firstConnection) <- e.firstCompletedConnection) {
                @Assert(firstConnection.runtime.responderLabel, "health")
                @Assert(firstConnection.helperAllowsConnectionReuse(), true)
                @Assert(firstConnection.experimentForcedCloseAgainstReusableHelper(), true)
            } else {
                @Fail("first connection should complete before second-connection body-stage failure")
            }
            @Assert(
                e.clientObservedFirstConnectionResponseText(),
                "HTTP/1.1 200 OK\r\n" +
                "content-type: text/plain; charset=utf-8\r\n" +
                "x-ignite-runtime-experiment: health\r\n" +
                "content-length: 2\r\n\r\n" +
                "ok"
            )
            @Assert(e.clientObservedFailedConnectionResponseWireBytes.size, 0)
            @Assert(
                socketHttp11CountLimitedAcceptLoopContains(
                    e.failedConnectionRequestText(),
                    "POST /health HTTP/1.1"
                ),
                true
            )
        }
    }
}

func socketHttp11CountLimitedAcceptLoopContains(text: String, target: String): Bool {
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
