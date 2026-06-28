package ignite

import std.collection.{ArrayList, HashMap}
import std.env.getVariable
import std.io.InputStream
import std.net.{IPSocketAddress, TcpServerSocket, TcpSocket}
import stdx.net.http.{HttpContext, HttpHeaders, WebSocket}

let SOCKET_SERVER_ENGINE_SHELL_ACCEPT_LIMIT_ENV = "IGNITE_SOCKET_SERVER_ENGINE_SHELL_ACCEPT_LIMIT"

func runSocketServerEngineShellListen(
    option: ServerEngineListenOption,
    app: App,
    onReady: ?((ServerEngineReadySignal) -> Unit)
): Unit {
    if (option.tlsCertFile.size > 0 || option.tlsKeyFile.size > 0) {
        throw SocketServerEngineShellException(
            "socket server engine shell cleartext first-runnable path does not support TLS"
        )
    }
    let listener = TcpServerSocket(bindAt: IPSocketAddress.parse("${option.addr}:${option.port}"))
    listener.bind()
    try {
        if (let Some(cb) <- onReady) {
            cb(ServerEngineReadySignal())
        }
        serveSocketServerEngineShellTurns(
            listener,
            app,
            socketServerEngineShellAcceptedConnectionLimit()
        )
    } finally {
        if (!listener.isClosed()) {
            listener.close()
        }
    }
}

func serveSocketServerEngineShellTurns(
    listener: TcpServerSocket,
    app: App,
    acceptedConnectionLimit: Int64
): Unit {
    var acceptedConnectionCount: Int64 = 0
    while (acceptedConnectionCount < acceptedConnectionLimit) {
        serveSocketServerEngineShellTurn(listener, app)
        acceptedConnectionCount += 1
    }
}

func socketServerEngineShellAcceptedConnectionLimit(): Int64 {
    match (getVariable(SOCKET_SERVER_ENGINE_SHELL_ACCEPT_LIMIT_ENV)) {
        case Some(raw) =>
            let parsed = socketServerEngineShellParsePositiveInt64(raw.trimAscii())
            if (let Some(limit) <- parsed) {
                return limit
            }
            throw SocketServerEngineShellException(
                "${SOCKET_SERVER_ENGINE_SHELL_ACCEPT_LIMIT_ENV} must be a positive decimal integer"
            )
        case None => 1
    }
}

func socketServerEngineShellParsePositiveInt64(text: String): ?Int64 {
    if (text.size == 0) {
        return None
    }
    let chars = text.toRuneArray()
    var value: Int64 = 0
    for (ch in chars) {
        if (ch < r'0' || ch > r'9') {
            return None
        }
        value = value * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
    }
    if (value <= 0) {
        return None
    }
    Some(value)
}

func serveSocketServerEngineShellTurn(
    listener: TcpServerSocket,
    app: App
): Unit {
    let accepted = listener.accept()
    try {
        serveSocketServerEngineShellSocketTurns(accepted, app)
    } finally {
        if (!accepted.isClosed()) {
            accepted.close()
        }
    }
}

func serveSocketServerEngineShellSocketTurns(
    socket: TcpSocket,
    app: App
): Unit {
    var moreTurns = true
    while (moreTurns) {
        try {
            let requestWire = readSocketServerEngineShellRequestWire(socket)
            let request = openSocketServerEngineShellRequest(requestWire)
            let keepAliveAfterWrite =
                socketServerEngineShellShouldKeepAliveAfterWrite(request)
            let requestBodyBytes =
                readSocketServerEngineShellRequestBodyBytes(socket, request)
            let seed = buildSocketHttp11DispatchSeed(request)
            let carrier = SocketServerEngineShellCurrentRequestCarrier(
                request,
                seed,
                socket.remoteAddress.toString(),
                requestBodyBytes
            )
            app.handleRequest(carrier)
            let closeAfterWrite = !keepAliveAfterWrite
            let responseWire = buildSocketServerEngineShellResponseWire(
                request,
                carrier,
                closeAfterWrite
            )
            if (responseWire.size > 0) {
                socket.write(responseWire)
            }
            if (!keepAliveAfterWrite) {
                moreTurns = false
            }
        } catch (_: SocketServerEngineShellException) {
            // bad-request turn containment: malformed or incomplete request-head
            // or shell-owned body-stage error on this accepted socket — stop
            // the keep-alive loop and let the caller close the socket
            moreTurns = false
        }
    }
}

func socketServerEngineShellShouldKeepAliveAfterWrite(
    request: SocketHttp11SessionRequest
): Bool {
    if (request.closeAfterResponse) {
        return false
    }
    match (request.head.header("connection")) {
        case Some(val) =>
            if (socketServerEngineShellConnectionHasCloseToken(val)) {
                return false
            }
            socketServerEngineShellConnectionHasKeepAliveToken(val)
        case None => socketServerEngineShellIsHttp11(request)
    }
}

func socketServerEngineShellIsHttp11(
    request: SocketHttp11SessionRequest
): Bool {
    request.head.version.trimAscii().toAsciiUpper() == "HTTP/1.1"
}

func socketServerEngineShellConnectionHasCloseToken(value: String): Bool {
    socketServerEngineShellConnectionHasToken(value, "close")
}

func socketServerEngineShellConnectionHasKeepAliveToken(value: String): Bool {
    socketServerEngineShellConnectionHasToken(value, "keep-alive")
}

func socketServerEngineShellConnectionHasToken(
    value: String,
    target: String
): Bool {
    for (token in value.split(",")) {
        let normalized = token.trimAscii().toAsciiLower()
        if (normalized == target) {
            return true
        }
    }
    false
}

func readSocketServerEngineShellRequestWire(socket: TcpSocket): Array<UInt8> {
    let out = ArrayList<UInt8>()
    let buf = Array<UInt8>(4096, repeat: 0)
    while (true) {
        let n = socket.read(buf)
        if (n <= 0) {
            break
        }
        appendSocketServerEngineShellBytes(out, buf[..n])
        let snapshot = out.toArray()
        try {
            if ((tryParseSocketHttp11RequestHead(snapshot)).isSome()) {
                return snapshot
            }
        } catch (e: SocketHttp11HeadException) {
            throw SocketServerEngineShellException(
                "socket server engine shell request-head parse failed: ${e.message}"
            )
        }
    }
    out.toArray()
}

func readSocketServerEngineShellRequestBodyBytes(
    socket: TcpSocket,
    request: SocketHttp11SessionRequest
): Array<UInt8> {
    let prefetched = socketServerEngineShellCloneBytes(request.bodyPlan.prefetchedBodyBytes)
    if (!request.bodyPlan.requiresBodyStage) {
        return prefetched
    }
    if (request.bodyPlan.framing == SocketHttp11RequestBodyFraming.ContentLength) {
        if (request.bodyPlan.hasTrailingBufferedBytes()) {
            throw SocketServerEngineShellException(
                "socket server engine shell content-length body-stage first cut does not support pipelined bytes"
            )
        }
        let remaining = request.bodyPlan.remainingNetworkBodyBytes
        if (remaining <= 0) {
            return prefetched
        }
        let tail = socketServerEngineShellReadExactBytes(socket, remaining)
        if (tail.size != remaining) {
            throw SocketServerEngineShellException(
                "socket server engine shell content-length body-stage first cut did not receive the declared body bytes"
            )
        }
        let out = ArrayList<UInt8>()
        appendSocketServerEngineShellBytes(out, prefetched)
        appendSocketServerEngineShellBytes(out, tail)
        return out.toArray()
    }
    if (request.bodyPlan.framing == SocketHttp11RequestBodyFraming.Chunked) {
        return socketServerEngineShellDecodeChunkedBody(socket, prefetched)
    }
    throw SocketServerEngineShellException(
        "socket server engine shell request body-stage first cut supports only Content-Length and chunked framing"
    )
}

func socketServerEngineShellReadExactBytes(socket: TcpSocket, expectedBytes: Int64): Array<UInt8> {
    let out = ArrayList<UInt8>()
    let buf = Array<UInt8>(4096, repeat: 0)
    var remaining = expectedBytes
    while (remaining > 0) {
        let limit = if (remaining < buf.size) { remaining } else { buf.size }
        let chunk = Array<UInt8>(limit, repeat: 0)
        let n = socket.read(chunk)
        if (n <= 0) {
            break
        }
        appendSocketServerEngineShellBytes(out, chunk[..n])
        remaining -= n
    }
    out.toArray()
}

func socketServerEngineShellDecodeChunkedBody(
    socket: TcpSocket,
    prefetched: Array<UInt8>
): Array<UInt8> {
    let network = ArrayList<UInt8>()
    appendSocketServerEngineShellBytes(network, prefetched)
    let decoded = ArrayList<UInt8>()
    var cursor: Int64 = 0
    while (true) {
        let sizeLineEnd = socketServerEngineShellEnsureCrlfLine(socket, network, cursor)
        let chunkSize = socketServerEngineShellParseChunkSizeLine(network, cursor, sizeLineEnd)
        cursor = sizeLineEnd + 2
        if (chunkSize == 0) {
            cursor = socketServerEngineShellConsumeChunkedTrailers(socket, network, cursor)
            if (cursor < network.size) {
                throw SocketServerEngineShellException(
                    "socket server engine shell chunked body-stage first cut does not support pipelined bytes"
                )
            }
            return decoded.toArray()
        }
        socketServerEngineShellEnsureBufferedBytes(socket, network, cursor + chunkSize + 2)
        var i: Int64 = 0
        while (i < chunkSize) {
            decoded.add(network[cursor + i])
            i += 1
        }
        cursor += chunkSize
        if (network[cursor] != UInt8(13) || network[cursor + 1] != UInt8(10)) {
            throw SocketServerEngineShellException(
                "socket server engine shell chunked body-stage first cut requires CRLF after each chunk payload"
            )
        }
        cursor += 2
    }
    throw SocketServerEngineShellException(
        "socket server engine shell chunked body-stage first cut reached an unreachable decoder state"
    )
}

func socketServerEngineShellConsumeChunkedTrailers(
    socket: TcpSocket,
    network: ArrayList<UInt8>,
    start: Int64
): Int64 {
    var cursor = start
    while (true) {
        let lineEnd = socketServerEngineShellEnsureCrlfLine(socket, network, cursor)
        if (lineEnd == cursor) {
            return lineEnd + 2
        }
        socketServerEngineShellValidateChunkedTrailerLine(network, cursor, lineEnd)
        cursor = lineEnd + 2
    }
    throw SocketServerEngineShellException(
        "socket server engine shell chunked body-stage first cut reached an unreachable trailer state"
    )
}

func socketServerEngineShellValidateChunkedTrailerLine(
    network: ArrayList<UInt8>,
    start: Int64,
    end: Int64
): Unit {
    let colon = socketServerEngineShellFindByteInRange(network, start, end, UInt8(58))
    if (colon <= start) {
        throw SocketServerEngineShellException(
            "socket server engine shell chunked body-stage first cut received an invalid trailer line"
        )
    }
    var i = start
    while (i < colon) {
        if (!socketServerEngineShellIsHttp11TokenByte(network[i])) {
            throw SocketServerEngineShellException(
                "socket server engine shell chunked body-stage first cut received an invalid trailer line"
            )
        }
        i += 1
    }
}

func socketServerEngineShellEnsureCrlfLine(
    socket: TcpSocket,
    network: ArrayList<UInt8>,
    start: Int64
): Int64 {
    while (true) {
        let found = socketServerEngineShellFindCrlf(network, start)
        if (found >= 0) {
            return found
        }
        if (socketServerEngineShellReadMore(socket, network) <= 0) {
            throw SocketServerEngineShellException(
                "socket server engine shell chunked body-stage first cut received an incomplete chunk line"
            )
        }
    }
    throw SocketServerEngineShellException(
        "socket server engine shell chunked body-stage first cut reached an unreachable line state"
    )
}

func socketServerEngineShellFindCrlf(network: ArrayList<UInt8>, start: Int64): Int64 {
    var i = start
    while (i + 1 < network.size) {
        if (network[i] == UInt8(13) && network[i + 1] == UInt8(10)) {
            return i
        }
        i += 1
    }
    -1
}

func socketServerEngineShellFindByteInRange(
    network: ArrayList<UInt8>,
    start: Int64,
    end: Int64,
    target: UInt8
): Int64 {
    var i = start
    while (i < end) {
        if (network[i] == target) {
            return i
        }
        i += 1
    }
    -1
}

func socketServerEngineShellIsHttp11TokenByte(value: UInt8): Bool {
    if (
        (value >= UInt8(48) && value <= UInt8(57)) ||
        (value >= UInt8(65) && value <= UInt8(90)) ||
        (value >= UInt8(97) && value <= UInt8(122))
    ) {
        return true
    }
    value == UInt8(33) ||
    value == UInt8(35) ||
    value == UInt8(36) ||
    value == UInt8(37) ||
    value == UInt8(38) ||
    value == UInt8(39) ||
    value == UInt8(42) ||
    value == UInt8(43) ||
    value == UInt8(45) ||
    value == UInt8(46) ||
    value == UInt8(94) ||
    value == UInt8(95) ||
    value == UInt8(96) ||
    value == UInt8(124) ||
    value == UInt8(126)
}

func socketServerEngineShellEnsureBufferedBytes(
    socket: TcpSocket,
    network: ArrayList<UInt8>,
    requiredSize: Int64
): Unit {
    while (network.size < requiredSize) {
        if (socketServerEngineShellReadMore(socket, network) <= 0) {
            throw SocketServerEngineShellException(
                "socket server engine shell chunked body-stage first cut received an incomplete chunk payload"
            )
        }
    }
}

func socketServerEngineShellReadMore(socket: TcpSocket, out: ArrayList<UInt8>): Int64 {
    let buf = Array<UInt8>(4096, repeat: 0)
    let n = socket.read(buf)
    if (n > 0) {
        appendSocketServerEngineShellBytes(out, buf[..n])
    }
    n
}

func socketServerEngineShellParseChunkSizeLine(
    network: ArrayList<UInt8>,
    start: Int64,
    end: Int64
): Int64 {
    var i = start
    var seenDigit = false
    var out: Int64 = 0
    while (i < end) {
        let b = network[i]
        if (b == UInt8(59)) {
            break
        }
        let digit = socketServerEngineShellHexDigitValue(b)
        if (digit < 0) {
            throw SocketServerEngineShellException(
                "socket server engine shell chunked body-stage first cut received an invalid chunk size"
            )
        }
        seenDigit = true
        out = out * 16 + digit
        i += 1
    }
    if (!seenDigit) {
        throw SocketServerEngineShellException(
            "socket server engine shell chunked body-stage first cut requires a chunk size"
        )
    }
    out
}

func socketServerEngineShellHexDigitValue(b: UInt8): Int64 {
    if (b >= UInt8(48) && b <= UInt8(57)) {
        return Int64(b) - Int64(UInt8(48))
    }
    if (b >= UInt8(65) && b <= UInt8(70)) {
        return Int64(b) - Int64(UInt8(65)) + 10
    }
    if (b >= UInt8(97) && b <= UInt8(102)) {
        return Int64(b) - Int64(UInt8(97)) + 10
    }
    -1
}

func openSocketServerEngineShellRequest(requestWire: Array<UInt8>): SocketHttp11SessionRequest {
    let session = SocketHttp11ConnectionSession()
    session.appendHeadBytes(requestWire)
    try {
        match (session.tryOpenRequest()) {
            case Some(request) => request
            case None =>
                throw SocketServerEngineShellException(
                    "socket server engine shell requires one complete HTTP/1.1 request head before it can dispatch"
                )
        }
    } catch (e: SocketHttp11HeadException) {
        throw SocketServerEngineShellException(
            "socket server engine shell request-head parse failed: ${e.message}"
        )
    } catch (e: SocketHttp11SessionException) {
        throw SocketServerEngineShellException(
            "socket server engine shell request session failed: ${e.message}"
        )
    }
}

func buildSocketServerEngineShellResponseWire(
    request: SocketHttp11SessionRequest,
    carrier: SocketServerEngineShellCurrentRequestCarrier,
    closeAfterWrite: Bool
): Array<UInt8> {
    let responseBytes = carrier.responseBodyBytes()
    let responseHeaders = carrier.responseHeadersForSocket()
    let responseHasChunkedTransfer = carrier.responseHeader("transfer-encoding") ?? ""
    let responseContentLength = carrier.responseHeader("content-length") ?? ""
    let statusCode = Int64(carrier.responseStatusCode())
    let bodyMode = if (isSocketHttp11ResponseBodyForbiddenStatus(statusCode)) {
        SocketHttp11ResponseBodyMode.Bodyless
    } else if (responseHasChunkedTransfer.toAsciiLower() == "chunked") {
        SocketHttp11ResponseBodyMode.UnknownLength
    } else {
        SocketHttp11ResponseBodyMode.KnownLength
    }
    let declaredBodyBytes = if (bodyMode == SocketHttp11ResponseBodyMode.KnownLength) {
        socketServerEngineShellKnownLengthBytesForResponse(
            request,
            responseBytes.size,
            responseContentLength
        )
    } else {
        0
    }
    let plan = buildSocketHttp11ResponseWritePlan(
        request,
        statusCode,
        responseHeaders,
        bodyMode,
        declaredBodyBytes: declaredBodyBytes,
        option: SocketHttp11ResponseWriteOption(closeAfterWrite: closeAfterWrite)
    )
    let writer = SocketHttp11ResponseWriterLifecycle(plan)
    let out = ArrayList<UInt8>()
    appendSocketServerEngineShellBytes(out, writer.takeHeadBytes())
    if (plan.writesPayloadBody() && responseBytes.size > 0) {
        appendSocketServerEngineShellBytes(out, writer.writeBodyChunk(responseBytes))
    }
    appendSocketServerEngineShellBytes(out, writer.finish())
    out.toArray()
}

func socketServerEngineShellKnownLengthBytesForResponse(
    request: SocketHttp11SessionRequest,
    responseBytesSize: Int64,
    responseContentLength: String
): Int64 {
    if (request.head.method.trimAscii().toAsciiUpper() != "HEAD") {
        return responseBytesSize
    }
    let declared = responseContentLength.trimAscii()
    if (declared.size == 0) {
        return responseBytesSize
    }
    match (socketServerEngineShellParseNonNegativeInt64(declared)) {
        case Some(value) => value
        case None =>
            throw SocketServerEngineShellException(
                "socket server engine shell HEAD response content-length must be a non-negative decimal integer"
            )
    }
}

func socketServerEngineShellParseNonNegativeInt64(text: String): ?Int64 {
    if (text.size == 0) {
        return None
    }
    let chars = text.toRuneArray()
    var value: Int64 = 0
    for (ch in chars) {
        if (ch < r'0' || ch > r'9') {
            return None
        }
        value = value * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
    }
    Some(value)
}

func appendSocketServerEngineShellBytes(out: ArrayList<UInt8>, bytes: Array<UInt8>): Unit {
    for (b in bytes) {
        out.add(b)
    }
}

func socketServerEngineShellCloneBytes(bytes: Array<UInt8>): Array<UInt8> {
    if (bytes.size == 0) {
        return Array<UInt8>(0, repeat: 0)
    }
    let out = Array<UInt8>(bytes.size, repeat: 0)
    var i: Int64 = 0
    while (i < bytes.size) {
        out[i] = bytes[i]
        i += 1
    }
    out
}

func socketServerEngineShellReadInputStream(stream: InputStream): Array<UInt8> {
    let out = ArrayList<UInt8>()
    let buf = Array<Byte>(4096, repeat: 0)
    while (true) {
        let n = stream.read(buf)
        if (n <= 0) {
            break
        }
        var i: Int64 = 0
        while (i < n) {
            out.add(UInt8(buf[i]))
            i += 1
        }
    }
    out.toArray()
}

func socketServerEngineShellReadQueryValue(queryString: String, key: String): ?String {
    let trimmed = queryString.trimAscii()
    if (trimmed.size == 0) {
        return None
    }
    let parts = trimmed.split("&")
    for (part in parts) {
        let kv = part.split("=", 2)
        if (kv.size >= 1) {
            let candidateKey = kv[0].trimAscii()
            if (candidateKey == key) {
                if (kv.size == 2) {
                    return Some(kv[1])
                }
                return Some("")
            }
        }
    }
    None
}

class SocketServerEngineShellBytesInputStream <: InputStream {
    let bytes: Array<UInt8>
    var offset: Int64 = 0

    init(bytes: Array<UInt8>) {
        this.bytes = socketServerEngineShellCloneBytes(bytes)
    }

    public override func read(outBuf: Array<Byte>): Int64 {
        if (offset >= bytes.size || outBuf.size == 0) {
            return 0
        }
        let remaining = bytes.size - offset
        let limit = if (outBuf.size < remaining) { outBuf.size } else { remaining }
        var i: Int64 = 0
        while (i < limit) {
            outBuf[i] = bytes[offset + i]
            i += 1
        }
        offset += limit
        limit
    }
}

class SocketServerEngineShellResponseTransportWriter <: ResponseTransportWriter {
    let carrier: SocketServerEngineShellCurrentRequestCarrier

    init(carrier: SocketServerEngineShellCurrentRequestCarrier) {
        this.carrier = carrier
    }

    public override func write(data: Array<UInt8>): Unit {
        carrier.appendResponseBodyBytes(data)
    }
}

class SocketServerEngineShellCurrentRequestCarrier <: CurrentRequestCarrier {
    let request: SocketHttp11SessionRequest
    let seed: SocketHttp11DispatchSeed
    let remoteAddress: String
    let requestHeadersValue: HttpHeaders
    let requestBodyBytesValue: Array<UInt8>
    let responseHeadersValue: HashMap<String, String>
    var responseBodyBytesValue: ArrayList<UInt8> = ArrayList<UInt8>()
    var responseStatusCodeValue: UInt16 = 200

    init(
        request: SocketHttp11SessionRequest,
        seed: SocketHttp11DispatchSeed,
        remoteAddress: String,
        requestBodyBytes: Array<UInt8>
    ) {
        this.request = request
        this.seed = seed
        this.remoteAddress = remoteAddress
        this.requestHeadersValue = buildSocketServerEngineShellRequestHeaders(request)
        this.requestBodyBytesValue = socketServerEngineShellCloneBytes(requestBodyBytes)
        this.responseHeadersValue = HashMap<String, String>()
        this.responseBodyBytesValue = ArrayList<UInt8>()
    }

    public override func rawHttpContext(): HttpContext {
        throw SocketServerEngineShellException(
            "socket server engine shell does not expose raw HttpContext"
        )
    }

    public override func upgradeWebSocketRaw(): WebSocket {
        throw SocketServerEngineShellException(
            "socket server engine shell cleartext first-runnable path does not support WebSocket upgrade"
        )
    }

    public override func openResponseTransportWriterRaw(): ResponseTransportWriter {
        SocketServerEngineShellResponseTransportWriter(this)
    }

    public override func requestMethod(): String {
        request.head.method.trimAscii().toAsciiUpper()
    }

    public override func requestPath(): String {
        match (seed.dispatchPath) {
            case Some(path) => path
            case None => seed.rawTarget
        }
    }

    public override func requestUrlString(): String {
        seed.normalizedDispatchTarget()
    }

    public override func requestVersionString(): String {
        request.head.version
    }

    public override func requestRemoteAddr(): String {
        remoteAddress
    }

    public override func requestQueryValue(key: String): ?String {
        socketServerEngineShellReadQueryValue(seed.queryString, key)
    }

    public override func requestFormValue(key: String): ?String {
        let _ = key
        None
    }

    public override func requestHeaderValue(key: String): ?String {
        request.head.header(key)
    }

    public override func requestHeaders(): HttpHeaders {
        requestHeadersValue
    }

    public override func requestBodyStream(): InputStream {
        SocketServerEngineShellBytesInputStream(requestBodyBytesValue)
    }

    public override func requestBodySize(): ?Int64 {
        Some(requestBodyBytesValue.size)
    }

    public override func setResponseStatus(code: UInt16): Unit {
        ensureSocketServerEngineShellFinalStatusSupported(code)
        responseStatusCodeValue = code
    }

    public override func setResponseHeader(key: String, value: String): Unit {
        responseHeadersValue.add(key.trimAscii().toAsciiLower(), value.trimAscii())
    }

    public override func addResponseHeaders(headers: HttpHeaders): Unit {
        for ((name, values) in headers) {
            for (value in values) {
                setResponseHeader(name, value)
            }
        }
    }

    public override func setResponseString(body: String): Unit {
        replaceResponseBodyBytes(body.toArray())
    }

    public override func setResponseBytes(data: Array<UInt8>): Unit {
        replaceResponseBodyBytes(data)
    }

    public override func attachResponseBodyStream(stream: InputStream): Unit {
        try {
            replaceResponseBodyBytes(socketServerEngineShellReadInputStream(stream))
        } finally {
            match (stream) {
                case closable: Resource => closable.close()
                case _ => ()
            }
        }
    }

    public func responseStatusCode(): UInt16 {
        responseStatusCodeValue
    }

    public func responseHeader(name: String): ?String {
        responseHeadersValue.get(name.trimAscii().toAsciiLower())
    }

    public func responseHeadersForSocket(): Array<SocketHttp11Header> {
        let out = ArrayList<SocketHttp11Header>()
        for ((name, value) in responseHeadersValue) {
            let normalized = name.trimAscii().toAsciiLower()
            if (normalized == "content-length" || normalized == "transfer-encoding" || normalized == "connection") {
                continue
            }
            out.add(SocketHttp11Header(normalized, value.trimAscii()))
        }
        out.toArray()
    }

    public func responseBodyBytes(): Array<UInt8> {
        let out = Array<UInt8>(responseBodyBytesValue.size, repeat: 0)
        var i: Int64 = 0
        while (i < responseBodyBytesValue.size) {
            out[i] = responseBodyBytesValue[i]
            i += 1
        }
        out
    }

    func appendResponseBodyBytes(bytes: Array<UInt8>): Unit {
        for (b in bytes) {
            responseBodyBytesValue.add(b)
        }
    }

    func replaceResponseBodyBytes(bytes: Array<UInt8>): Unit {
        responseBodyBytesValue = ArrayList<UInt8>()
        appendResponseBodyBytes(bytes)
    }
}

func ensureSocketServerEngineShellFinalStatusSupported(code: UInt16): Unit {
    let numeric = Int64(code)
    if (numeric < 100 || numeric > 999) {
        throw SocketServerEngineShellException(
            "socket server engine shell final route response status must be between 100 and 999"
        )
    }
    if (numeric >= 100 && numeric < 200) {
        throw SocketServerEngineShellException(
            "socket server engine shell does not support informational 1xx statuses as final route responses"
        )
    }
}

func buildSocketServerEngineShellRequestHeaders(request: SocketHttp11SessionRequest): HttpHeaders {
    let headers = HttpHeaders()
    for (header in request.head.headers) {
        headers.add(header.name, header.value)
    }
    headers
}
