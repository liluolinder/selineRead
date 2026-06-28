import ignite.*

main() {
    printSocketDoubleAcceptCase(
        "health-then-health",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n",
        "GET /health?connection=2 HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketDoubleAcceptCase(
        "health-then-close",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n",
        "GET /close HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketDoubleAcceptBlockedCase(
        "health-then-body-stage-gap",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n",
        "POST /health HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nabc"
    )
}

func printSocketDoubleAcceptCase(
    label: String,
    firstWire: String,
    secondWire: String
): Unit {
    let result = runSocketHttp11DoubleAcceptExperiment(
        firstWire.toArray(),
        secondWire.toArray()
    )
    println("=== ${label} ===")
    println("listener=127.0.0.1:${result.listenerPort}")
    println("distinctConnections=${result.acceptedDistinctConnectionsServedSequentially}")
    println("firstAcceptedRemote=${result.firstConnection.acceptedRemoteAddress}")
    println("secondAcceptedRemote=${result.secondConnection.acceptedRemoteAddress}")
    println("firstClosedBeforeSecondConnect=${result.firstConnectionClosedBeforeSecondConnect}")
    println("secondClosedAfterResponse=${result.secondConnectionClosedAfterResponse}")
    println("firstResponder=${result.firstConnection.runtime.responderLabel}")
    println("secondResponder=${result.secondConnection.runtime.responderLabel}")
    println("firstHelperReuse=${result.firstConnection.helperAllowsConnectionReuse()}")
    println("secondHelperReuse=${result.secondConnection.helperAllowsConnectionReuse()}")
    println(
        "firstForcedClose=${result.firstConnection.experimentForcedCloseAgainstReusableHelper()}"
    )
    println(
        "secondForcedClose=${result.secondConnection.experimentForcedCloseAgainstReusableHelper()}"
    )
    println(result.firstConnection.clientObservedResponseText())
    println(result.secondConnection.clientObservedResponseText())
    println("")
}

func printSocketDoubleAcceptBlockedCase(
    label: String,
    firstWire: String,
    secondWire: String
): Unit {
    println("=== ${label} ===")
    try {
        let _ = runSocketHttp11DoubleAcceptExperiment(
            firstWire.toArray(),
            secondWire.toArray()
        )
        println("unexpected-success")
    } catch (e: SocketHttp11DoubleAcceptExperimentException) {
        println("listener=127.0.0.1:${e.listenerPort}")
        println("failedConnection=${e.failedConnectionIndex}")
        println("blocked=${e.runtimeCode.toString()}")
        println("firstClosedBeforeSecondConnect=${e.firstConnectionClosedBeforeSecondConnect}")
        println("failedConnectionClosedAfterResponse=${e.failedConnectionClosedAfterResponse}")
        println("firstResponseBytes=${e.clientObservedFirstConnectionResponseWireBytes.size}")
        println("failedConnectionResponseBytes=${e.clientObservedFailedConnectionResponseWireBytes.size}")
        println(e.message)
    }
    println("")
}
