import ignite.*

main() {
    printSocketKeepAliveTwoTurnCase(
        "health-then-health",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n",
        "GET /health?turn=2 HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketKeepAliveTwoTurnCase(
        "health-then-close",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n",
        "GET /close HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketKeepAliveTwoTurnBlockedCase(
        "health-then-body-stage-gap",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n",
        "POST /health HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nabc"
    )
}

func printSocketKeepAliveTwoTurnCase(
    label: String,
    firstWire: String,
    secondWire: String
): Unit {
    let result = runSocketHttp11KeepAliveTwoTurnExperiment(
        firstWire.toArray(),
        secondWire.toArray()
    )
    println("=== ${label} ===")
    println("listener=127.0.0.1:${result.listenerPort}")
    println("acceptedRemote=${result.acceptedRemoteAddress}")
    println("sameConnection=${result.sameAcceptedConnectionServedBothTurns}")
    println("stayedOpenBetweenTurns=${result.transportStayedOpenBetweenTurns}")
    println("closedAfterSecondTurn=${result.transportClosedAfterSecondTurn}")
    println("firstResponder=${result.firstTurn.runtime.responderLabel}")
    println("secondResponder=${result.secondTurn.runtime.responderLabel}")
    println("firstHelperReuse=${result.helperAllowedReuseAfterFirstTurn()}")
    println("secondHelperReuse=${result.helperAllowedReuseAfterSecondTurn()}")
    println(
        "experimentForcedFinalClose=${result.experimentForcedFinalCloseAgainstReusableHelper()}"
    )
    println(result.firstTurn.clientObservedResponseText())
    println(result.secondTurn.clientObservedResponseText())
    println("")
}

func printSocketKeepAliveTwoTurnBlockedCase(
    label: String,
    firstWire: String,
    secondWire: String
): Unit {
    println("=== ${label} ===")
    try {
        let _ = runSocketHttp11KeepAliveTwoTurnExperiment(
            firstWire.toArray(),
            secondWire.toArray()
        )
        println("unexpected-success")
    } catch (e: SocketHttp11KeepAliveTwoTurnExperimentException) {
        println("listener=127.0.0.1:${e.listenerPort}")
        println("failedTurn=${e.failedTurnIndex}")
        println("blocked=${e.code.toString()}")
        println("firstResponseBytes=${e.clientObservedFirstTurnResponseWireBytes.size}")
        println("failedTurnResponseBytes=${e.clientObservedFailedTurnResponseWireBytes.size}")
        println(e.message)
    }
    println("")
}
