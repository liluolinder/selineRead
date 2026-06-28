import ignite.*

main() {
    printSocketCountLimitedAcceptLoopCase(
        "health-then-health",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n",
        "GET /health?connection=2 HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketCountLimitedAcceptLoopCase(
        "health-then-close",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n",
        "GET /close HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketCountLimitedAcceptLoopBlockedCase(
        "health-then-body-stage-gap",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n",
        "POST /health HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nabc"
    )
}

func printSocketCountLimitedAcceptLoopCase(
    label: String,
    firstWire: String,
    secondWire: String
): Unit {
    let result = runSocketHttp11CountLimitedAcceptLoopExperiment(
        firstWire.toArray(),
        secondWire.toArray()
    )
    println("=== ${label} ===")
    println("listener=127.0.0.1:${result.listenerPort}")
    println("acceptedConnectionLimit=${result.acceptedConnectionLimit}")
    println("acceptedConnectionCount=${result.acceptedConnectionCount}")
    println("explicitAcceptLoopOwnsLifecycle=${result.explicitAcceptLoopOwnsLifecycle}")
    println(
        "exitedBecauseAcceptedConnectionLimitReached=${result.exitedBecauseAcceptedConnectionLimitReached}"
    )
    println("firstAcceptedRemote=${result.firstConnection.acceptedRemoteAddress}")
    println("secondAcceptedRemote=${result.secondConnection.acceptedRemoteAddress}")
    println("firstClosedBeforeSecondAccept=${result.firstConnectionClosedBeforeSecondAccept}")
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

func printSocketCountLimitedAcceptLoopBlockedCase(
    label: String,
    firstWire: String,
    secondWire: String
): Unit {
    println("=== ${label} ===")
    try {
        let _ = runSocketHttp11CountLimitedAcceptLoopExperiment(
            firstWire.toArray(),
            secondWire.toArray()
        )
        println("unexpected-success")
    } catch (e: SocketHttp11CountLimitedAcceptLoopExperimentException) {
        println("listener=127.0.0.1:${e.listenerPort}")
        println("acceptedConnectionLimit=${e.acceptedConnectionLimit}")
        println("completedConnectionCount=${e.completedConnectionCount}")
        println("failedConnection=${e.failedConnectionIndex}")
        println("blocked=${e.runtimeCode.toString()}")
        println("stoppedBeforeLimit=${e.stoppedBeforeAcceptedConnectionLimitReached}")
        println("firstClosedBeforeSecondAccept=${e.firstConnectionClosedBeforeSecondAccept}")
        println("failedConnectionClosedAfterResponse=${e.failedConnectionClosedAfterResponse}")
        println("firstResponseBytes=${e.clientObservedFirstConnectionResponseWireBytes.size}")
        println("failedConnectionResponseBytes=${e.clientObservedFailedConnectionResponseWireBytes.size}")
        println(e.message)
    }
    println("")
}
