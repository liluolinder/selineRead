package ignite

public class ResponseWriter {
    let _writer: ResponseTransportWriter

    public init(currentRequestCarrier: CurrentRequestCarrier) {
        if (shouldEmitChunkedTransferHeader(currentRequestCarrier.requestVersionString())) {
            currentRequestCarrier.setResponseHeader("transfer-encoding", "chunked")
        }
        _writer = openResponseTransportWriter(currentRequestCarrier)
    }

    public func write(data: Array<UInt8>): Unit {
        _writer.write(data)
    }

    public func writeString(data: String): Unit {
        _writer.write(data.toArray())
    }
}

public class SseWriter {
    let _currentRequestCarrier: CurrentRequestCarrier
    var _writer: ?ResponseTransportWriter = None

    public init(currentRequestCarrier: CurrentRequestCarrier) {
        _currentRequestCarrier = currentRequestCarrier
        currentRequestCarrier.setResponseStatus(200)
        currentRequestCarrier.setResponseHeader("content-type", "text/event-stream")
        currentRequestCarrier.setResponseHeader("cache-control", "no-cache")
        currentRequestCarrier.setResponseHeader("x-accel-buffering", "no")
        let protocol = currentRequestCarrier.requestVersionString()
        if (shouldEmitConnectionKeepAliveHeader(protocol)) {
            currentRequestCarrier.setResponseHeader("connection", "keep-alive")
        }
        if (shouldEmitChunkedTransferHeader(protocol)) {
            currentRequestCarrier.setResponseHeader("transfer-encoding", "chunked")
        }
    }

    func ensureWriter(): ResponseTransportWriter {
        match (_writer) {
            case Some(w) => w
            case None =>
                let w = openResponseTransportWriter(_currentRequestCarrier)
                _writer = w
                w
        }
    }

    public func sendEvent(data: String, event!: String = "", id!: String = ""): Unit {
        let w = ensureWriter()
        var msg = ""
        if (id.size > 0) {
            msg += "id: ${id}\n"
        }
        if (event.size > 0) {
            msg += "event: ${event}\n"
        }
        let lines = data.split("\n")
        for (line in lines) {
            msg += "data: ${line}\n"
        }
        msg += "\n"
        w.write(msg.toArray())
    }

    public func sendComment(comment: String): Unit {
        let w = ensureWriter()
        w.write(": ${comment}\n\n".toArray())
    }

    public func sendRetry(millis: Int64): Unit {
        let w = ensureWriter()
        w.write("retry: ${millis}\n\n".toArray())
    }

    /// Minimal heartbeat helper for SSE keepalive comments.
    /// Public close/flush controls are still limited by the current stdx-backed transport surface.
    public func sendHeartbeat(comment!: String = "ping"): Unit {
        sendComment(comment)
    }
}

func shouldEmitChunkedTransferHeader(protocol: String): Bool {
    return !isHttp2Protocol(protocol)
}

func shouldEmitConnectionKeepAliveHeader(protocol: String): Bool {
    return !isHttp2Protocol(protocol)
}

func isHttp2Protocol(protocol: String): Bool {
    let text = protocol.trimAscii().toAsciiLower()
    if (text.size == 0) {
        return false
    }
    if (text == "h2" || text == "h2c") {
        return true
    }
    let containsSlashForm = containsText(text, "http/2")
    if (containsSlashForm) {
        return true
    }
    containsText(text, "http2")
}

func containsText(text: String, pattern: String): Bool {
    let a = text.toRuneArray()
    let b = pattern.toRuneArray()
    if (b.size == 0) {
        return true
    }
    if (a.size < b.size) {
        return false
    }
    var i: Int64 = 0
    while (i <= a.size - b.size) {
        var ok = true
        var j: Int64 = 0
        while (j < b.size) {
            if (a[i + j] != b[j]) {
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
