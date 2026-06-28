package ignite.tests

import ignite.*

@Test
public class SocketHttp11KeepAliveTwoTurnExperimentTestSuite {
    @TestCase
    public func testKeepAliveTwoTurnExperimentReusesOneConnectionAcrossTwoHealthTurns(): Unit {
        let result = runSocketHttp11KeepAliveTwoTurnExperiment(
            "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray(),
            "GET /health?turn=2 HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray()
        )

        @Assert(result.listenerHost, "127.0.0.1")
        @Assert(result.listenerPort > 0, true)
        @Assert(result.acceptedRemoteAddress.size > 0, true)
        @Assert(result.sameAcceptedConnectionServedBothTurns, true)
        @Assert(result.transportStayedOpenBetweenTurns, true)
        @Assert(result.transportClosedAfterSecondTurn, true)
        @Assert(result.firstTurn.turnIndex, 1)
        @Assert(result.secondTurn.turnIndex, 2)
        @Assert(
            result.firstTurn.serverObservedRequestText(),
            "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        @Assert(
            result.secondTurn.serverObservedRequestText(),
            "GET /health?turn=2 HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        @Assert(result.firstTurn.runtime.responderLabel, "health")
        @Assert(result.secondTurn.runtime.responderLabel, "health")
        @Assert(result.firstTurn.runtime.requestDispatchPath, "/health")
        @Assert(result.secondTurn.runtime.requestDispatchPath, "/health")
        @Assert(result.secondTurn.runtime.requestQueryString, "turn=2")
        @Assert(result.helperAllowedReuseAfterFirstTurn(), true)
        @Assert(result.helperAllowedReuseAfterSecondTurn(), true)
        @Assert(result.experimentForcedFinalCloseAgainstReusableHelper(), true)
        @Assert(
            result.secondTurn.clientObservedResponseText(),
            "HTTP/1.1 200 OK\r\n" +
            "content-type: text/plain; charset=utf-8\r\n" +
            "x-ignite-runtime-experiment: health\r\n" +
            "content-length: 2\r\n\r\n" +
            "ok"
        )
    }

    @TestCase
    public func testKeepAliveTwoTurnExperimentLetsSecondTurnOwnCloseRequest(): Unit {
        let result = runSocketHttp11KeepAliveTwoTurnExperiment(
            "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray(),
            "GET /close HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray()
        )

        @Assert(result.helperAllowedReuseAfterFirstTurn(), true)
        @Assert(result.firstTurn.runtime.closeoutShouldCloseConnection, false)
        @Assert(result.secondTurn.runtime.responderLabel, "close")
        @Assert(result.secondTurn.runtime.responseStatusCode, 202)
        @Assert(result.secondTurn.runtime.responseCloseAfterWrite, true)
        @Assert(result.secondTurn.runtime.closeoutShouldCloseConnection, true)
        @Assert(result.helperAllowedReuseAfterSecondTurn(), false)
        @Assert(result.experimentForcedFinalCloseAgainstReusableHelper(), false)
        @Assert(result.transportClosedAfterSecondTurn, true)
        @Assert(
            result.secondTurn.clientObservedResponseText(),
            "HTTP/1.1 202 Accepted\r\n" +
            "content-type: text/plain; charset=utf-8\r\n" +
            "x-ignite-runtime-experiment: close\r\n" +
            "content-length: 3\r\n" +
            "connection: close\r\n\r\n" +
            "bye"
        )
    }

    @TestCase
    public func testKeepAliveTwoTurnExperimentKeepsBodyStageGapBlockedOnSecondTurn(): Unit {
        try {
            let _ = runSocketHttp11KeepAliveTwoTurnExperiment(
                "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n".toArray(),
                "POST /health HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nabc".toArray()
            )
            @Fail("keepalive two-turn experiment should keep the body-stage boundary blocked")
        } catch (e: SocketHttp11KeepAliveTwoTurnExperimentException) {
            @Assert(e.code, SocketHttp11KeepAliveTwoTurnExperimentErrorCode.BodyStageRequired)
            @Assert(e.failedTurnIndex, 2)
            @Assert(e.listenerHost, "127.0.0.1")
            @Assert(e.listenerPort > 0, true)
            @Assert(e.acceptedRemoteAddress.size > 0, true)
            if (let Some(firstTurn) <- e.firstCompletedTurn) {
                @Assert(firstTurn.runtime.responderLabel, "health")
                @Assert(firstTurn.helperAllowsConnectionReuse(), true)
            } else {
                @Fail("first turn should complete before second-turn body-stage failure")
            }
            @Assert(
                e.clientObservedFirstTurnResponseText(),
                "HTTP/1.1 200 OK\r\n" +
                "content-type: text/plain; charset=utf-8\r\n" +
                "x-ignite-runtime-experiment: health\r\n" +
                "content-length: 2\r\n\r\n" +
                "ok"
            )
            @Assert(e.clientObservedFailedTurnResponseWireBytes.size, 0)
            @Assert(
                socketHttp11KeepAliveTwoTurnContains(
                    e.failedTurnRequestText(),
                    "POST /health HTTP/1.1"
                ),
                true
            )
        }
    }
}

func socketHttp11KeepAliveTwoTurnContains(text: String, target: String): Bool {
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
