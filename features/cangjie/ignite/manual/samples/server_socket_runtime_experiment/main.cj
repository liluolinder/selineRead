import ignite.*

main() {
    printSocketRuntimeExperimentCase(
        "health",
        "GET /health HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketRuntimeExperimentCase(
        "stream",
        "GET /stream HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketRuntimeExperimentCase(
        "close",
        "GET /close HTTP/1.1\r\nHost: example.com\r\n\r\n"
    )
    printSocketRuntimeExperimentBlockedCase(
        "body-stage-gap",
        "POST /health HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nabc"
    )
}

func printSocketRuntimeExperimentCase(label: String, wire: String): Unit {
    let result = runSocketHttp11RuntimeExperiment(
        wire.toArray(),
        remoteAddress: "127.0.0.1:19070"
    )
    println("=== ${label} ===")
    println("responder=${result.responderLabel}")
    println("target=${result.normalizedDispatchTarget()}")
    println("status=${result.responseStatusCode}")
    println("framing=${result.responseHeaderFraming.toString()}")
    println("closeReason=${result.closeoutCloseReason}")
    println("finalState=${result.finalConnectionState.toString()}")
    println(String.fromUtf8(result.responseWireBytes))
    println("")
}

func printSocketRuntimeExperimentBlockedCase(label: String, wire: String): Unit {
    println("=== ${label} ===")
    try {
        let _ = runSocketHttp11RuntimeExperiment(wire.toArray())
        println("unexpected-success")
    } catch (e: SocketHttp11RuntimeExperimentException) {
        println("blocked=${e.code.toString()}")
        println(e.message)
    }
    println("")
}
