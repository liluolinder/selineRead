import ignite.*

main() {
    printSocketAcceptOnceCase(
        "health",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketAcceptOnceCase(
        "stream",
        "GET /stream HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketAcceptOnceCase(
        "close",
        "GET /close HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketAcceptOnceBlockedCase(
        "body-stage-gap",
        "POST /health HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nabc"
    )
}

func printSocketAcceptOnceCase(label: String, wire: String): Unit {
    let result = runSocketHttp11AcceptOnceExperiment(wire.toArray())
    println("=== ${label} ===")
    println("listener=127.0.0.1:${result.listenerPort}")
    println("acceptedRemote=${result.acceptedRemoteAddress}")
    println("responder=${result.runtime.responderLabel}")
    println("status=${result.runtime.responseStatusCode}")
    println("helperReuse=${result.helperAllowsConnectionReuse()}")
    println("forcedCloseByExperiment=${result.experimentForcedCloseAgainstReusableHelper()}")
    println("transportClosed=${result.transportClosedAfterServeOnce}")
    println(result.clientObservedResponseText())
    println("")
}

func printSocketAcceptOnceBlockedCase(label: String, wire: String): Unit {
    println("=== ${label} ===")
    try {
        let _ = runSocketHttp11AcceptOnceExperiment(wire.toArray())
        println("unexpected-success")
    } catch (e: SocketHttp11AcceptOnceExperimentException) {
        println("listener=127.0.0.1:${e.listenerPort}")
        println("blocked=${e.runtimeCode.toString()}")
        println("responseBytes=${e.clientObservedResponseWireBytes.size}")
        println(e.message)
    }
    println("")
}
