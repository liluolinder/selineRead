package ignite

import std.collection.ArrayList
import std.convert.*
import std.net.{IPSocketAddress, TcpServerSocket, TcpSocket}

public enum SocketHttp11KeepAliveTwoTurnExperimentErrorCode <: Equatable<SocketHttp11KeepAliveTwoTurnExperimentErrorCode> & ToString {
    | IncompleteRequest
    | BodyStageRequired
    | FirstTurnDidNotRemainReusable

    public operator func ==(right: SocketHttp11KeepAliveTwoTurnExperimentErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11KeepAliveTwoTurnExperimentErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case IncompleteRequest => 0
            case BodyStageRequired => 1
            case FirstTurnDidNotRemainReusable => 2
        }
    }

    public func toString(): String {
        match (this) {
            case IncompleteRequest => "INCOMPLETE_REQUEST"
            case BodyStageRequired => "BODY_STAGE_REQUIRED"
            case FirstTurnDidNotRemainReusable => "FIRST_TURN_DID_NOT_REMAIN_REUSABLE"
        }
    }
}

public class SocketHttp11KeepAliveTwoTurnExperimentTurn {
    public let turnIndex: Int64
    public let serverObservedRequestWireBytes: Array<UInt8>
    public let clientObservedResponseWireBytes: Array<UInt8>
    public let runtime: SocketHttp11RuntimeExperimentResult

    init(
        turnIndex: Int64,
        serverObservedRequestWireBytes: Array<UInt8>,
        clientObservedResponseWireBytes: Array<UInt8>,
        runtime: SocketHttp11RuntimeExperimentResult
    ) {
        this.turnIndex = turnIndex
        this.serverObservedRequestWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(serverObservedRequestWireBytes)
        this.clientObservedResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(clientObservedResponseWireBytes)
        this.runtime = runtime
    }

    public func helperAllowsConnectionReuse(): Bool {
        runtime.finalConnectionState == SocketHttp11ConnectionState.ReceivingHead
    }

    public func serverObservedRequestText(): String {
        String.fromUtf8(serverObservedRequestWireBytes)
    }

    public func clientObservedResponseText(): String {
        String.fromUtf8(clientObservedResponseWireBytes)
    }
}

public class SocketHttp11KeepAliveTwoTurnExperimentResult {
    public let listenerHost: String
    public let listenerPort: UInt16
    public let acceptedRemoteAddress: String
    public let firstTurn: SocketHttp11KeepAliveTwoTurnExperimentTurn
    public let secondTurn: SocketHttp11KeepAliveTwoTurnExperimentTurn
    public let sameAcceptedConnectionServedBothTurns: Bool
    public let transportStayedOpenBetweenTurns: Bool
    public let transportClosedAfterSecondTurn: Bool

    init(
        listenerHost: String,
        listenerPort: UInt16,
        acceptedRemoteAddress: String,
        firstTurn: SocketHttp11KeepAliveTwoTurnExperimentTurn,
        secondTurn: SocketHttp11KeepAliveTwoTurnExperimentTurn,
        sameAcceptedConnectionServedBothTurns: Bool,
        transportStayedOpenBetweenTurns: Bool,
        transportClosedAfterSecondTurn: Bool
    ) {
        this.listenerHost = listenerHost
        this.listenerPort = listenerPort
        this.acceptedRemoteAddress = acceptedRemoteAddress
        this.firstTurn = firstTurn
        this.secondTurn = secondTurn
        this.sameAcceptedConnectionServedBothTurns = sameAcceptedConnectionServedBothTurns
        this.transportStayedOpenBetweenTurns = transportStayedOpenBetweenTurns
        this.transportClosedAfterSecondTurn = transportClosedAfterSecondTurn
    }

    public func helperAllowedReuseAfterFirstTurn(): Bool {
        firstTurn.helperAllowsConnectionReuse()
    }

    public func helperAllowedReuseAfterSecondTurn(): Bool {
        secondTurn.helperAllowsConnectionReuse()
    }

    public func experimentForcedFinalCloseAgainstReusableHelper(): Bool {
        transportClosedAfterSecondTurn && helperAllowedReuseAfterSecondTurn()
    }
}

public class SocketHttp11KeepAliveTwoTurnExperimentException <: Exception {
    public let code: SocketHttp11KeepAliveTwoTurnExperimentErrorCode
    public let failedTurnIndex: Int64
    public let listenerHost: String
    public let listenerPort: UInt16
    public let acceptedRemoteAddress: String
    public let firstCompletedTurn: ?SocketHttp11KeepAliveTwoTurnExperimentTurn
    public let failedTurnRequestWireBytes: Array<UInt8>
    public let clientObservedFirstTurnResponseWireBytes: Array<UInt8>
    public let clientObservedFailedTurnResponseWireBytes: Array<UInt8>

    public init(
        code: SocketHttp11KeepAliveTwoTurnExperimentErrorCode,
        failedTurnIndex: Int64,
        message: String,
        listenerHost: String,
        listenerPort: UInt16,
        acceptedRemoteAddress: String,
        firstCompletedTurn: ?SocketHttp11KeepAliveTwoTurnExperimentTurn,
        failedTurnRequestWireBytes: Array<UInt8>,
        clientObservedFirstTurnResponseWireBytes: Array<UInt8>,
        clientObservedFailedTurnResponseWireBytes: Array<UInt8>
    ) {
        super(message)
        this.code = code
        this.failedTurnIndex = failedTurnIndex
        this.listenerHost = listenerHost
        this.listenerPort = listenerPort
        this.acceptedRemoteAddress = acceptedRemoteAddress
        this.firstCompletedTurn = firstCompletedTurn
        this.failedTurnRequestWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(failedTurnRequestWireBytes)
        this.clientObservedFirstTurnResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(clientObservedFirstTurnResponseWireBytes)
        this.clientObservedFailedTurnResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(clientObservedFailedTurnResponseWireBytes)
    }

    public func failedTurnRequestText(): String {
        String.fromUtf8(failedTurnRequestWireBytes)
    }

    public func clientObservedFirstTurnResponseText(): String {
        String.fromUtf8(clientObservedFirstTurnResponseWireBytes)
    }

    public func clientObservedFailedTurnResponseText(): String {
        String.fromUtf8(clientObservedFailedTurnResponseWireBytes)
    }
}

class SocketHttp11KeepAliveTwoTurnClientCompletion {
    let firstTurnResponseWireBytes: Array<UInt8>
    let secondTurnResponseWireBytes: Array<UInt8>
    let transportClosedAfterSecondTurn: Bool

    init(
        firstTurnResponseWireBytes: Array<UInt8>,
        secondTurnResponseWireBytes: Array<UInt8>,
        transportClosedAfterSecondTurn: Bool
    ) {
        this.firstTurnResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(firstTurnResponseWireBytes)
        this.secondTurnResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(secondTurnResponseWireBytes)
        this.transportClosedAfterSecondTurn = transportClosedAfterSecondTurn
    }
}

class SocketHttp11KeepAliveTwoTurnTurnExecutionResult {
    let turn: ?SocketHttp11KeepAliveTwoTurnExperimentTurn
    let failureCode: ?SocketHttp11KeepAliveTwoTurnExperimentErrorCode
    let failureMessage: String
    let failedTurnRequestWireBytes: Array<UInt8>

    init(turn: SocketHttp11KeepAliveTwoTurnExperimentTurn) {
        this.turn = Some(turn)
        this.failureCode = None
        this.failureMessage = ""
        this.failedTurnRequestWireBytes = Array<UInt8>(0, repeat: 0)
    }

    init(
        failureCode: SocketHttp11KeepAliveTwoTurnExperimentErrorCode,
        failureMessage: String,
        failedTurnRequestWireBytes: Array<UInt8>
    ) {
        this.turn = None
        this.failureCode = Some(failureCode)
        this.failureMessage = failureMessage
        this.failedTurnRequestWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(failedTurnRequestWireBytes)
    }
}

class SocketHttp11KeepAliveTwoTurnServerCompletion {
    let acceptedRemoteAddress: String
    let firstCompletedTurn: ?SocketHttp11KeepAliveTwoTurnExperimentTurn
    let secondCompletedTurn: ?SocketHttp11KeepAliveTwoTurnExperimentTurn
    let failureCode: ?SocketHttp11KeepAliveTwoTurnExperimentErrorCode
    let failedTurnIndex: Int64
    let failureMessage: String
    let failedTurnRequestWireBytes: Array<UInt8>

    init(
        acceptedRemoteAddress: String,
        firstCompletedTurn: SocketHttp11KeepAliveTwoTurnExperimentTurn,
        secondCompletedTurn: SocketHttp11KeepAliveTwoTurnExperimentTurn
    ) {
        this.acceptedRemoteAddress = acceptedRemoteAddress
        this.firstCompletedTurn = Some(firstCompletedTurn)
        this.secondCompletedTurn = Some(secondCompletedTurn)
        this.failureCode = None
        this.failedTurnIndex = 0
        this.failureMessage = ""
        this.failedTurnRequestWireBytes = Array<UInt8>(0, repeat: 0)
    }

    init(
        acceptedRemoteAddress: String,
        firstCompletedTurn: ?SocketHttp11KeepAliveTwoTurnExperimentTurn,
        failedTurnIndex: Int64,
        failureCode: SocketHttp11KeepAliveTwoTurnExperimentErrorCode,
        failureMessage: String,
        failedTurnRequestWireBytes: Array<UInt8>
    ) {
        this.acceptedRemoteAddress = acceptedRemoteAddress
        this.firstCompletedTurn = firstCompletedTurn
        this.secondCompletedTurn = None
        this.failureCode = Some(failureCode)
        this.failedTurnIndex = failedTurnIndex
        this.failureMessage = failureMessage
        this.failedTurnRequestWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(failedTurnRequestWireBytes)
    }
}

public func runSocketHttp11KeepAliveTwoTurnExperiment(
    firstRequestWire: Array<UInt8>,
    secondRequestWire: Array<UInt8>,
    listenerHost!: String = "127.0.0.1"
): SocketHttp11KeepAliveTwoTurnExperimentResult {
    let listener = TcpServerSocket(bindAt: IPSocketAddress.parse("${listenerHost}:0"))
    listener.bind()
    let listenerPort = match ((listener.localAddress as IPSocketAddress)?.port) {
        case Some(port) => port
        case None =>
            throw Exception("socket keepalive two-turn experiment listener port is unavailable")
    }

    let serverFuture = spawn {
        serveSocketHttp11KeepAliveTwoTurn(listener)
    }

    let clientCompletion = runSocketHttp11KeepAliveTwoTurnClient(
        listenerHost,
        listenerPort,
        firstRequestWire,
        secondRequestWire
    )
    let completion = serverFuture.get(Duration.second * 5)

    match (completion.secondCompletedTurn) {
        case Some(secondTurn) =>
            let firstCompletedTurn = match (completion.firstCompletedTurn) {
                case Some(firstCompletedTurn) => firstCompletedTurn
                case None =>
                    throw Exception(
                        "socket keepalive two-turn experiment lost first-turn completion"
                    )
            }
            SocketHttp11KeepAliveTwoTurnExperimentResult(
                listenerHost,
                listenerPort,
                completion.acceptedRemoteAddress,
                firstCompletedTurn,
                secondTurn,
                true,
                true,
                clientCompletion.transportClosedAfterSecondTurn
            )
        case None =>
            throw SocketHttp11KeepAliveTwoTurnExperimentException(
                completion.failureCode ??
                    SocketHttp11KeepAliveTwoTurnExperimentErrorCode.IncompleteRequest,
                completion.failedTurnIndex,
                completion.failureMessage,
                listenerHost,
                listenerPort,
                completion.acceptedRemoteAddress,
                completion.firstCompletedTurn,
                completion.failedTurnRequestWireBytes,
                clientCompletion.firstTurnResponseWireBytes,
                clientCompletion.secondTurnResponseWireBytes
            )
    }
}

func serveSocketHttp11KeepAliveTwoTurn(
    listener: TcpServerSocket
): SocketHttp11KeepAliveTwoTurnServerCompletion {
    try {
        let accepted = listener.accept()
        try {
            let remoteAddress = accepted.remoteAddress.toString()
            let session = SocketHttp11ConnectionSession()

            let firstTurnResult = executeSocketHttp11KeepAliveTwoTurn(
                accepted,
                session,
                1,
                remoteAddress
            )
            match (firstTurnResult.turn) {
                case Some(firstTurn) =>
                    if (!firstTurn.helperAllowsConnectionReuse()) {
                        return SocketHttp11KeepAliveTwoTurnServerCompletion(
                            remoteAddress,
                            Some(firstTurn),
                            1,
                            SocketHttp11KeepAliveTwoTurnExperimentErrorCode.FirstTurnDidNotRemainReusable,
                            "socket keepalive two-turn experiment requires first turn to remain reusable before second turn can begin",
                            firstTurn.serverObservedRequestWireBytes
                        )
                    }

                    let secondTurnResult = executeSocketHttp11KeepAliveTwoTurn(
                        accepted,
                        session,
                        2,
                        remoteAddress
                    )
                    match (secondTurnResult.turn) {
                        case Some(secondTurn) =>
                            SocketHttp11KeepAliveTwoTurnServerCompletion(
                                remoteAddress,
                                firstTurn,
                                secondTurn
                            )
                        case None =>
                            SocketHttp11KeepAliveTwoTurnServerCompletion(
                                remoteAddress,
                                Some(firstTurn),
                                2,
                                secondTurnResult.failureCode ??
                                    SocketHttp11KeepAliveTwoTurnExperimentErrorCode.IncompleteRequest,
                                secondTurnResult.failureMessage,
                                secondTurnResult.failedTurnRequestWireBytes
                            )
                    }
                case None =>
                    SocketHttp11KeepAliveTwoTurnServerCompletion(
                        remoteAddress,
                        None,
                        1,
                        firstTurnResult.failureCode ??
                            SocketHttp11KeepAliveTwoTurnExperimentErrorCode.IncompleteRequest,
                        firstTurnResult.failureMessage,
                        firstTurnResult.failedTurnRequestWireBytes
                    )
            }
        } finally {
            if (!accepted.isClosed()) {
                accepted.close()
            }
        }
    } finally {
        if (!listener.isClosed()) {
            listener.close()
        }
    }
}

func executeSocketHttp11KeepAliveTwoTurn(
    socket: TcpSocket,
    session: SocketHttp11ConnectionSession,
    turnIndex: Int64,
    remoteAddress: String
): SocketHttp11KeepAliveTwoTurnTurnExecutionResult {
    let requestWire = readSocketHttp11AcceptOnceRequestWire(socket)
    try {
        let runtime = runSocketHttp11KeepAliveExperimentTurn(
            session,
            requestWire,
            remoteAddress
        )
        if (runtime.responseWireBytes.size > 0) {
            socket.write(runtime.responseWireBytes)
        }
        SocketHttp11KeepAliveTwoTurnTurnExecutionResult(
            SocketHttp11KeepAliveTwoTurnExperimentTurn(
                turnIndex,
                requestWire,
                runtime.responseWireBytes,
                runtime
            )
        )
    } catch (e: SocketHttp11RuntimeExperimentException) {
        SocketHttp11KeepAliveTwoTurnTurnExecutionResult(
            mapSocketHttp11KeepAliveTwoTurnExperimentErrorCode(e.code),
            e.message,
            requestWire
        )
    }
}

func runSocketHttp11KeepAliveExperimentTurn(
    session: SocketHttp11ConnectionSession,
    requestWire: Array<UInt8>,
    remoteAddress: String
): SocketHttp11RuntimeExperimentResult {
    session.appendHeadBytes(requestWire)
    let request = match (session.tryOpenRequest()) {
        case Some(request) => request
        case None =>
            throw SocketHttp11RuntimeExperimentException(
                SocketHttp11RuntimeExperimentErrorCode.IncompleteRequest,
                "socket keepalive two-turn experiment requires one complete request head before a turn can begin"
            )
    }

    if (request.bodyPlan.requiresBodyStage) {
        throw SocketHttp11RuntimeExperimentException(
            SocketHttp11RuntimeExperimentErrorCode.BodyStageRequired,
            "socket keepalive two-turn experiment intentionally stops before request body-stage handoff"
        )
    }

    let seed = buildSocketHttp11DispatchSeed(request)
    let requestSnapshot = buildSocketHttp11RequestSnapshot(
        request,
        seed,
        remoteAddress: remoteAddress
    )
    let draft = resolveSocketHttp11RuntimeExperimentDraft(requestSnapshot)
    let declaredBodyBytes = if (draft.bodyMode == SocketHttp11ResponseBodyMode.KnownLength) {
        draft.logicalBodyBytes.size
    } else {
        -1
    }
    let plan = buildSocketHttp11ResponseWritePlan(
        request,
        draft.statusCode,
        draft.headers,
        draft.bodyMode,
        declaredBodyBytes: declaredBodyBytes,
        option: SocketHttp11ResponseWriteOption(closeAfterWrite: draft.closeAfterWrite)
    )
    let responseSnapshot = buildSocketHttp11ResponseSnapshot(plan)

    try {
        session.beginResponseWrite()
        let writer = SocketHttp11ResponseWriterLifecycle(plan)
        let responseWire = ArrayList<UInt8>()
        appendSocketHttp11RuntimeExperimentBytes(responseWire, writer.takeHeadBytes())
        if (responseSnapshot.writesPayloadBody() && draft.logicalBodyBytes.size > 0) {
            appendSocketHttp11RuntimeExperimentBytes(
                responseWire,
                writer.writeBodyChunk(draft.logicalBodyBytes)
            )
        }
        appendSocketHttp11RuntimeExperimentBytes(responseWire, writer.finish())

        let closeout = buildSocketHttp11RuntimeTurnCloseout(request, responseSnapshot)
        session.finishResponseWrite()
        if (closeout.shouldCloseConnection) {
            session.markClosing()
        }

        SocketHttp11RuntimeExperimentResult(
            request,
            requestSnapshot,
            responseSnapshot,
            closeout,
            draft.responderLabel,
            draft.logicalBodyBytes,
            responseWire.toArray(),
            session.state()
        )
    } catch (e: Exception) {
        session.markFailed()
        throw e
    }
}

func runSocketHttp11KeepAliveTwoTurnClient(
    listenerHost: String,
    listenerPort: UInt16,
    firstRequestWire: Array<UInt8>,
    secondRequestWire: Array<UInt8>
): SocketHttp11KeepAliveTwoTurnClientCompletion {
    let socket = TcpSocket(IPSocketAddress.parse("${listenerHost}:${listenerPort}"))
    socket.connect()
    try {
        socket.write(firstRequestWire)
        let firstResponseWire = readSocketHttp11KeepAliveResponseWire(socket)
        socket.write(secondRequestWire)
        let secondResponseWire = readSocketHttp11KeepAliveResponseWire(socket)
        let transportClosedAfterSecondTurn = readSocketHttp11KeepAlivePeerClosed(socket)
        SocketHttp11KeepAliveTwoTurnClientCompletion(
            firstResponseWire,
            secondResponseWire,
            transportClosedAfterSecondTurn
        )
    } finally {
        if (!socket.isClosed()) {
            socket.close()
        }
    }
}

func readSocketHttp11KeepAliveResponseWire(socket: TcpSocket): Array<UInt8> {
    let out = ArrayList<UInt8>()
    let buf = Array<UInt8>(4096, repeat: 0)
    var headerEnd: Int64 = -1
    var expectedTotalBytes: Int64 = -1
    var usesChunked = false
    while (true) {
        let n = socket.read(buf)
        if (n <= 0) {
            break
        }
        appendSocketHttp11RuntimeExperimentBytes(out, buf[..n])
        let snapshot = out.toArray()
        if (headerEnd < 0) {
            headerEnd = findSocketHttp11KeepAliveHeaderEnd(snapshot)
            if (headerEnd >= 0) {
                let headBytes = sliceSocketHttp11SessionBytes(snapshot, 0, headerEnd)
                usesChunked = socketHttp11KeepAliveResponseUsesChunked(headBytes)
                if (!usesChunked) {
                    let contentLength = socketHttp11KeepAliveResponseContentLength(headBytes)
                    if (contentLength >= 0) {
                        expectedTotalBytes = headerEnd + contentLength
                    } else {
                        expectedTotalBytes = headerEnd
                    }
                }
            }
        }
        if (headerEnd >= 0) {
            if (usesChunked) {
                if (socketHttp11KeepAliveChunkedResponseComplete(snapshot, headerEnd)) {
                    return snapshot
                }
            } else if (expectedTotalBytes >= 0 && snapshot.size >= expectedTotalBytes) {
                return sliceSocketHttp11SessionBytes(snapshot, 0, expectedTotalBytes)
            }
        }
    }
    out.toArray()
}

func readSocketHttp11KeepAlivePeerClosed(socket: TcpSocket): Bool {
    let buf = Array<UInt8>(1, repeat: 0)
    socket.read(buf) <= 0
}

func findSocketHttp11KeepAliveHeaderEnd(bytes: Array<UInt8>): Int64 {
    if (bytes.size < 4) {
        return -1
    }
    var i: Int64 = 0
    while (i <= bytes.size - 4) {
        if (bytes[i] == 13 &&
            bytes[i + 1] == 10 &&
            bytes[i + 2] == 13 &&
            bytes[i + 3] == 10) {
            return i + 4
        }
        i += 1
    }
    -1
}

func socketHttp11KeepAliveResponseUsesChunked(headBytes: Array<UInt8>): Bool {
    let headText = String.fromUtf8(headBytes)
    let lines = headText.split("\r\n")
    for (line in lines) {
        let trimmed = line.trimAscii()
        if (trimmed.size == 0) {
            continue
        }
        if (trimmed.toAsciiLower().startsWith("transfer-encoding:")) {
            if (let Some(colonIndex) <- trimmed.indexOf(":")) {
                let value = trimmed[colonIndex + 1 ..].trimAscii().toAsciiLower()
                return value.contains("chunked")
            }
        }
    }
    false
}

func socketHttp11KeepAliveResponseContentLength(headBytes: Array<UInt8>): Int64 {
    let headText = String.fromUtf8(headBytes)
    let lines = headText.split("\r\n")
    for (line in lines) {
        let trimmed = line.trimAscii()
        if (trimmed.size == 0) {
            continue
        }
        if (trimmed.toAsciiLower().startsWith("content-length:")) {
            if (let Some(colonIndex) <- trimmed.indexOf(":")) {
                let value = trimmed[colonIndex + 1 ..].trimAscii()
                return Int64.parse(value)
            }
        }
    }
    -1
}

func socketHttp11KeepAliveChunkedResponseComplete(
    bytes: Array<UInt8>,
    headerEnd: Int64
): Bool {
    if (bytes.size < headerEnd + 5) {
        return false
    }
    let terminator = "\r\n0\r\n\r\n".toArray()
    var i = headerEnd
    while (i <= bytes.size - terminator.size) {
        var matched = true
        var j: Int64 = 0
        while (j < terminator.size) {
            if (bytes[i + j] != terminator[j]) {
                matched = false
                break
            }
            j += 1
        }
        if (matched) {
            return true
        }
        i += 1
    }
    false
}

func mapSocketHttp11KeepAliveTwoTurnExperimentErrorCode(
    code: SocketHttp11RuntimeExperimentErrorCode
): SocketHttp11KeepAliveTwoTurnExperimentErrorCode {
    match (code) {
        case SocketHttp11RuntimeExperimentErrorCode.IncompleteRequest =>
            SocketHttp11KeepAliveTwoTurnExperimentErrorCode.IncompleteRequest
        case SocketHttp11RuntimeExperimentErrorCode.BodyStageRequired =>
            SocketHttp11KeepAliveTwoTurnExperimentErrorCode.BodyStageRequired
    }
}
