package ignite

import std.net.{IPSocketAddress, TcpServerSocket, TcpSocket}

public class SocketHttp11CountLimitedAcceptLoopExperimentConnection {
    public let connectionIndex: Int64
    public let acceptedRemoteAddress: String
    public let serverObservedRequestWireBytes: Array<UInt8>
    public let clientObservedResponseWireBytes: Array<UInt8>
    public let runtime: SocketHttp11RuntimeExperimentResult
    public let transportClosedAfterResponse: Bool

    init(
        connectionIndex: Int64,
        acceptedRemoteAddress: String,
        serverObservedRequestWireBytes: Array<UInt8>,
        clientObservedResponseWireBytes: Array<UInt8>,
        runtime: SocketHttp11RuntimeExperimentResult,
        transportClosedAfterResponse: Bool
    ) {
        this.connectionIndex = connectionIndex
        this.acceptedRemoteAddress = acceptedRemoteAddress
        this.serverObservedRequestWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(serverObservedRequestWireBytes)
        this.clientObservedResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(clientObservedResponseWireBytes)
        this.runtime = runtime
        this.transportClosedAfterResponse = transportClosedAfterResponse
    }

    public func helperAllowsConnectionReuse(): Bool {
        runtime.finalConnectionState == SocketHttp11ConnectionState.ReceivingHead
    }

    public func experimentForcedCloseAgainstReusableHelper(): Bool {
        let helperReusable = helperAllowsConnectionReuse()
        transportClosedAfterResponse && helperReusable
    }

    public func serverObservedRequestText(): String {
        String.fromUtf8(serverObservedRequestWireBytes)
    }

    public func clientObservedResponseText(): String {
        String.fromUtf8(clientObservedResponseWireBytes)
    }
}

public class SocketHttp11CountLimitedAcceptLoopExperimentResult {
    public let listenerHost: String
    public let listenerPort: UInt16
    public let acceptedConnectionLimit: Int64
    public let acceptedConnectionCount: Int64
    public let explicitAcceptLoopOwnsLifecycle: Bool
    public let exitedBecauseAcceptedConnectionLimitReached: Bool
    public let firstConnection: SocketHttp11CountLimitedAcceptLoopExperimentConnection
    public let secondConnection: SocketHttp11CountLimitedAcceptLoopExperimentConnection
    public let firstConnectionClosedBeforeSecondAccept: Bool
    public let secondConnectionClosedAfterResponse: Bool

    init(
        listenerHost: String,
        listenerPort: UInt16,
        acceptedConnectionLimit: Int64,
        acceptedConnectionCount: Int64,
        explicitAcceptLoopOwnsLifecycle: Bool,
        exitedBecauseAcceptedConnectionLimitReached: Bool,
        firstConnection: SocketHttp11CountLimitedAcceptLoopExperimentConnection,
        secondConnection: SocketHttp11CountLimitedAcceptLoopExperimentConnection,
        firstConnectionClosedBeforeSecondAccept: Bool,
        secondConnectionClosedAfterResponse: Bool
    ) {
        this.listenerHost = listenerHost
        this.listenerPort = listenerPort
        this.acceptedConnectionLimit = acceptedConnectionLimit
        this.acceptedConnectionCount = acceptedConnectionCount
        this.explicitAcceptLoopOwnsLifecycle = explicitAcceptLoopOwnsLifecycle
        this.exitedBecauseAcceptedConnectionLimitReached =
            exitedBecauseAcceptedConnectionLimitReached
        this.firstConnection = firstConnection
        this.secondConnection = secondConnection
        this.firstConnectionClosedBeforeSecondAccept =
            firstConnectionClosedBeforeSecondAccept
        this.secondConnectionClosedAfterResponse = secondConnectionClosedAfterResponse
    }

    public func acceptedRemoteAddressesDiffer(): Bool {
        firstConnection.acceptedRemoteAddress != secondConnection.acceptedRemoteAddress
    }
}

public class SocketHttp11CountLimitedAcceptLoopExperimentException <: Exception {
    public let runtimeCode: SocketHttp11RuntimeExperimentErrorCode
    public let failedConnectionIndex: Int64
    public let listenerHost: String
    public let listenerPort: UInt16
    public let acceptedConnectionLimit: Int64
    public let completedConnectionCount: Int64
    public let explicitAcceptLoopOwnsLifecycle: Bool
    public let stoppedBeforeAcceptedConnectionLimitReached: Bool
    public let firstCompletedConnection: ?SocketHttp11CountLimitedAcceptLoopExperimentConnection
    public let failedConnectionAcceptedRemoteAddress: String
    public let failedConnectionRequestWireBytes: Array<UInt8>
    public let clientObservedFirstConnectionResponseWireBytes: Array<UInt8>
    public let clientObservedFailedConnectionResponseWireBytes: Array<UInt8>
    public let firstConnectionClosedBeforeSecondAccept: Bool
    public let failedConnectionClosedAfterResponse: Bool

    public init(
        runtimeCode: SocketHttp11RuntimeExperimentErrorCode,
        failedConnectionIndex: Int64,
        message: String,
        listenerHost: String,
        listenerPort: UInt16,
        acceptedConnectionLimit: Int64,
        completedConnectionCount: Int64,
        explicitAcceptLoopOwnsLifecycle: Bool,
        stoppedBeforeAcceptedConnectionLimitReached: Bool,
        firstCompletedConnection: ?SocketHttp11CountLimitedAcceptLoopExperimentConnection,
        failedConnectionAcceptedRemoteAddress: String,
        failedConnectionRequestWireBytes: Array<UInt8>,
        clientObservedFirstConnectionResponseWireBytes: Array<UInt8>,
        clientObservedFailedConnectionResponseWireBytes: Array<UInt8>,
        firstConnectionClosedBeforeSecondAccept: Bool,
        failedConnectionClosedAfterResponse: Bool
    ) {
        super(message)
        this.runtimeCode = runtimeCode
        this.failedConnectionIndex = failedConnectionIndex
        this.listenerHost = listenerHost
        this.listenerPort = listenerPort
        this.acceptedConnectionLimit = acceptedConnectionLimit
        this.completedConnectionCount = completedConnectionCount
        this.explicitAcceptLoopOwnsLifecycle = explicitAcceptLoopOwnsLifecycle
        this.stoppedBeforeAcceptedConnectionLimitReached =
            stoppedBeforeAcceptedConnectionLimitReached
        this.firstCompletedConnection = firstCompletedConnection
        this.failedConnectionAcceptedRemoteAddress = failedConnectionAcceptedRemoteAddress
        this.failedConnectionRequestWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(failedConnectionRequestWireBytes)
        this.clientObservedFirstConnectionResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(
                clientObservedFirstConnectionResponseWireBytes
            )
        this.clientObservedFailedConnectionResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(
                clientObservedFailedConnectionResponseWireBytes
            )
        this.firstConnectionClosedBeforeSecondAccept =
            firstConnectionClosedBeforeSecondAccept
        this.failedConnectionClosedAfterResponse = failedConnectionClosedAfterResponse
    }

    public func failedConnectionRequestText(): String {
        String.fromUtf8(failedConnectionRequestWireBytes)
    }

    public func clientObservedFirstConnectionResponseText(): String {
        String.fromUtf8(clientObservedFirstConnectionResponseWireBytes)
    }

    public func clientObservedFailedConnectionResponseText(): String {
        String.fromUtf8(clientObservedFailedConnectionResponseWireBytes)
    }
}

class SocketHttp11CountLimitedAcceptLoopClientConnectionCompletion {
    let responseWireBytes: Array<UInt8>
    let transportClosedAfterResponse: Bool

    init(responseWireBytes: Array<UInt8>, transportClosedAfterResponse: Bool) {
        this.responseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(responseWireBytes)
        this.transportClosedAfterResponse = transportClosedAfterResponse
    }
}

class SocketHttp11CountLimitedAcceptLoopClientCompletion {
    let firstConnectionResponseWireBytes: Array<UInt8>
    let firstConnectionClosedBeforeSecondAccept: Bool
    let secondConnectionResponseWireBytes: Array<UInt8>
    let secondConnectionClosedAfterResponse: Bool

    init(
        firstConnectionResponseWireBytes: Array<UInt8>,
        firstConnectionClosedBeforeSecondAccept: Bool,
        secondConnectionResponseWireBytes: Array<UInt8>,
        secondConnectionClosedAfterResponse: Bool
    ) {
        this.firstConnectionResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(firstConnectionResponseWireBytes)
        this.firstConnectionClosedBeforeSecondAccept =
            firstConnectionClosedBeforeSecondAccept
        this.secondConnectionResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(secondConnectionResponseWireBytes)
        this.secondConnectionClosedAfterResponse = secondConnectionClosedAfterResponse
    }
}

class SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection {
    let acceptedRemoteAddress: String
    let serverObservedRequestWireBytes: Array<UInt8>
    let runtime: ?SocketHttp11RuntimeExperimentResult
    let runtimeCode: ?SocketHttp11RuntimeExperimentErrorCode
    let runtimeMessage: String

    init(
        acceptedRemoteAddress: String,
        serverObservedRequestWireBytes: Array<UInt8>,
        runtime: SocketHttp11RuntimeExperimentResult
    ) {
        this.acceptedRemoteAddress = acceptedRemoteAddress
        this.serverObservedRequestWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(serverObservedRequestWireBytes)
        this.runtime = Some(runtime)
        this.runtimeCode = None
        this.runtimeMessage = ""
    }

    init(
        acceptedRemoteAddress: String,
        serverObservedRequestWireBytes: Array<UInt8>,
        runtimeCode: SocketHttp11RuntimeExperimentErrorCode,
        runtimeMessage: String
    ) {
        this.acceptedRemoteAddress = acceptedRemoteAddress
        this.serverObservedRequestWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(serverObservedRequestWireBytes)
        this.runtime = None
        this.runtimeCode = Some(runtimeCode)
        this.runtimeMessage = runtimeMessage
    }
}

class SocketHttp11CountLimitedAcceptLoopServerCompletion {
    let acceptedConnectionLimit: Int64
    let acceptedConnectionCount: Int64
    let explicitAcceptLoopOwnsLifecycle: Bool
    let exitedBecauseAcceptedConnectionLimitReached: Bool
    let firstCompletedConnection: ?SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection
    let secondCompletedConnection: ?SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection
    let failureCode: ?SocketHttp11RuntimeExperimentErrorCode
    let failedConnectionIndex: Int64
    let failedConnectionAcceptedRemoteAddress: String
    let failureMessage: String
    let failedConnectionRequestWireBytes: Array<UInt8>

    init(
        acceptedConnectionLimit: Int64,
        acceptedConnectionCount: Int64,
        firstCompletedConnection: SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection,
        secondCompletedConnection: SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection
    ) {
        this.acceptedConnectionLimit = acceptedConnectionLimit
        this.acceptedConnectionCount = acceptedConnectionCount
        this.explicitAcceptLoopOwnsLifecycle = true
        this.exitedBecauseAcceptedConnectionLimitReached = true
        this.firstCompletedConnection = Some(firstCompletedConnection)
        this.secondCompletedConnection = Some(secondCompletedConnection)
        this.failureCode = None
        this.failedConnectionIndex = 0
        this.failedConnectionAcceptedRemoteAddress = ""
        this.failureMessage = ""
        this.failedConnectionRequestWireBytes = Array<UInt8>(0, repeat: 0)
    }

    init(
        acceptedConnectionLimit: Int64,
        acceptedConnectionCount: Int64,
        firstCompletedConnection: ?SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection,
        secondCompletedConnection: ?SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection,
        failedConnectionIndex: Int64,
        failedConnectionAcceptedRemoteAddress: String,
        failureCode: SocketHttp11RuntimeExperimentErrorCode,
        failureMessage: String,
        failedConnectionRequestWireBytes: Array<UInt8>
    ) {
        this.acceptedConnectionLimit = acceptedConnectionLimit
        this.acceptedConnectionCount = acceptedConnectionCount
        this.explicitAcceptLoopOwnsLifecycle = true
        this.exitedBecauseAcceptedConnectionLimitReached = false
        this.firstCompletedConnection = firstCompletedConnection
        this.secondCompletedConnection = secondCompletedConnection
        this.failureCode = Some(failureCode)
        this.failedConnectionIndex = failedConnectionIndex
        this.failedConnectionAcceptedRemoteAddress = failedConnectionAcceptedRemoteAddress
        this.failureMessage = failureMessage
        this.failedConnectionRequestWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(failedConnectionRequestWireBytes)
    }
}

public func runSocketHttp11CountLimitedAcceptLoopExperiment(
    firstRequestWire: Array<UInt8>,
    secondRequestWire: Array<UInt8>,
    listenerHost!: String = "127.0.0.1"
): SocketHttp11CountLimitedAcceptLoopExperimentResult {
    let acceptedConnectionLimit: Int64 = 2
    let listener = TcpServerSocket(bindAt: IPSocketAddress.parse("${listenerHost}:0"))
    listener.bind()
    let listenerPort = match ((listener.localAddress as IPSocketAddress)?.port) {
        case Some(port) => port
        case None =>
            throw Exception(
                "socket count-limited accept-loop experiment listener port is unavailable"
            )
    }

    let serverFuture = spawn {
        serveSocketHttp11CountLimitedAcceptLoopExperiment(
            listener,
            acceptedConnectionLimit
        )
    }

    let clientCompletion = runSocketHttp11CountLimitedAcceptLoopClient(
        listenerHost,
        listenerPort,
        firstRequestWire,
        secondRequestWire
    )
    let completion = serverFuture.get(Duration.second * 5)

    match (completion.secondCompletedConnection) {
        case Some(secondCompletedConnection) =>
            let firstCompletedConnection = match (completion.firstCompletedConnection) {
                case Some(firstCompletedConnection) => firstCompletedConnection
                case None =>
                    throw Exception(
                        "socket count-limited accept-loop experiment lost first-connection completion"
                    )
            }
            SocketHttp11CountLimitedAcceptLoopExperimentResult(
                listenerHost,
                listenerPort,
                completion.acceptedConnectionLimit,
                completion.acceptedConnectionCount,
                completion.explicitAcceptLoopOwnsLifecycle,
                completion.exitedBecauseAcceptedConnectionLimitReached,
                buildSocketHttp11CountLimitedAcceptLoopExperimentConnection(
                    1,
                    firstCompletedConnection,
                    clientCompletion.firstConnectionResponseWireBytes,
                    clientCompletion.firstConnectionClosedBeforeSecondAccept
                ),
                buildSocketHttp11CountLimitedAcceptLoopExperimentConnection(
                    2,
                    secondCompletedConnection,
                    clientCompletion.secondConnectionResponseWireBytes,
                    clientCompletion.secondConnectionClosedAfterResponse
                ),
                clientCompletion.firstConnectionClosedBeforeSecondAccept,
                clientCompletion.secondConnectionClosedAfterResponse
            )
        case None =>
            let stoppedBeforeAcceptedConnectionLimitReached =
                completion.acceptedConnectionCount < completion.acceptedConnectionLimit
            throw SocketHttp11CountLimitedAcceptLoopExperimentException(
                completion.failureCode ??
                    SocketHttp11RuntimeExperimentErrorCode.IncompleteRequest,
                completion.failedConnectionIndex,
                completion.failureMessage,
                listenerHost,
                listenerPort,
                completion.acceptedConnectionLimit,
                completion.acceptedConnectionCount,
                completion.explicitAcceptLoopOwnsLifecycle,
                stoppedBeforeAcceptedConnectionLimitReached,
                buildSocketHttp11CountLimitedAcceptLoopFirstCompletedConnection(
                    completion.firstCompletedConnection,
                    clientCompletion.firstConnectionResponseWireBytes,
                    clientCompletion.firstConnectionClosedBeforeSecondAccept
                ),
                completion.failedConnectionAcceptedRemoteAddress,
                completion.failedConnectionRequestWireBytes,
                clientCompletion.firstConnectionResponseWireBytes,
                clientCompletion.secondConnectionResponseWireBytes,
                clientCompletion.firstConnectionClosedBeforeSecondAccept,
                if (completion.failedConnectionIndex == 1) {
                    clientCompletion.firstConnectionClosedBeforeSecondAccept
                } else {
                    clientCompletion.secondConnectionClosedAfterResponse
                }
            )
    }
}

func buildSocketHttp11CountLimitedAcceptLoopExperimentConnection(
    connectionIndex: Int64,
    completedConnection: SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection,
    clientObservedResponseWireBytes: Array<UInt8>,
    transportClosedAfterResponse: Bool
): SocketHttp11CountLimitedAcceptLoopExperimentConnection {
    let runtime = match (completedConnection.runtime) {
        case Some(runtime) => runtime
        case None =>
            throw Exception(
                "socket count-limited accept-loop experiment lost runtime completion"
            )
    }
    SocketHttp11CountLimitedAcceptLoopExperimentConnection(
        connectionIndex,
        completedConnection.acceptedRemoteAddress,
        completedConnection.serverObservedRequestWireBytes,
        clientObservedResponseWireBytes,
        runtime,
        transportClosedAfterResponse
    )
}

func buildSocketHttp11CountLimitedAcceptLoopFirstCompletedConnection(
    completedConnection: ?SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection,
    clientObservedResponseWireBytes: Array<UInt8>,
    transportClosedAfterResponse: Bool
): ?SocketHttp11CountLimitedAcceptLoopExperimentConnection {
    match (completedConnection) {
        case Some(completedConnection) =>
            Some(
                buildSocketHttp11CountLimitedAcceptLoopExperimentConnection(
                    1,
                    completedConnection,
                    clientObservedResponseWireBytes,
                    transportClosedAfterResponse
                )
            )
        case None => None
    }
}

func serveSocketHttp11CountLimitedAcceptLoopExperiment(
    listener: TcpServerSocket,
    acceptedConnectionLimit: Int64
): SocketHttp11CountLimitedAcceptLoopServerCompletion {
    var acceptedConnectionCount: Int64 = 0
    var firstCompletedConnection: ?SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection =
        None
    var secondCompletedConnection: ?SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection =
        None

    try {
        while (acceptedConnectionCount < acceptedConnectionLimit) {
            let connectionIndex = acceptedConnectionCount + 1
            let accepted = listener.accept()
            let acceptedRemoteAddress = accepted.remoteAddress.toString()
            let completedConnection = try {
                executeSocketHttp11CountLimitedAcceptLoopAcceptedConnection(
                    accepted,
                    acceptedRemoteAddress
                )
            } finally {
                if (!accepted.isClosed()) {
                    accepted.close()
                }
            }

            match (completedConnection.runtime) {
                case Some(_) =>
                    if (connectionIndex == 1) {
                        firstCompletedConnection = Some(completedConnection)
                    } else if (connectionIndex == 2) {
                        secondCompletedConnection = Some(completedConnection)
                    }
                    acceptedConnectionCount += 1
                case None =>
                    return SocketHttp11CountLimitedAcceptLoopServerCompletion(
                        acceptedConnectionLimit,
                        acceptedConnectionCount,
                        firstCompletedConnection,
                        secondCompletedConnection,
                        connectionIndex,
                        acceptedRemoteAddress,
                        completedConnection.runtimeCode ??
                            SocketHttp11RuntimeExperimentErrorCode.IncompleteRequest,
                        completedConnection.runtimeMessage,
                        completedConnection.serverObservedRequestWireBytes
                    )
            }
        }

        let requiredFirstCompletedConnection = match (firstCompletedConnection) {
            case Some(firstCompletedConnection) => firstCompletedConnection
            case None =>
                throw Exception(
                    "socket count-limited accept-loop experiment lost first connection in loop"
                )
        }
        let requiredSecondCompletedConnection = match (secondCompletedConnection) {
            case Some(secondCompletedConnection) => secondCompletedConnection
            case None =>
                throw Exception(
                    "socket count-limited accept-loop experiment lost second connection in loop"
                )
        }

        SocketHttp11CountLimitedAcceptLoopServerCompletion(
            acceptedConnectionLimit,
            acceptedConnectionCount,
            requiredFirstCompletedConnection,
            requiredSecondCompletedConnection
        )
    } finally {
        if (!listener.isClosed()) {
            listener.close()
        }
    }
}

func executeSocketHttp11CountLimitedAcceptLoopAcceptedConnection(
    accepted: TcpSocket,
    remoteAddress: String
): SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection {
    let requestWire = readSocketHttp11AcceptOnceRequestWire(accepted)
    try {
        let runtime = runSocketHttp11RuntimeExperiment(
            requestWire,
            remoteAddress: remoteAddress
        )
        if (runtime.responseWireBytes.size > 0) {
            accepted.write(runtime.responseWireBytes)
        }
        SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection(
            remoteAddress,
            requestWire,
            runtime
        )
    } catch (e: SocketHttp11RuntimeExperimentException) {
        SocketHttp11CountLimitedAcceptLoopServerAcceptedConnection(
            remoteAddress,
            requestWire,
            e.code,
            e.message
        )
    }
}

func runSocketHttp11CountLimitedAcceptLoopClient(
    listenerHost: String,
    listenerPort: UInt16,
    firstRequestWire: Array<UInt8>,
    secondRequestWire: Array<UInt8>
): SocketHttp11CountLimitedAcceptLoopClientCompletion {
    let firstConnection = runSocketHttp11CountLimitedAcceptLoopClientConnection(
        listenerHost,
        listenerPort,
        firstRequestWire
    )
    if (firstConnection.responseWireBytes.size == 0) {
        return SocketHttp11CountLimitedAcceptLoopClientCompletion(
            firstConnection.responseWireBytes,
            false,
            Array<UInt8>(0, repeat: 0),
            false
        )
    }

    let secondConnection = runSocketHttp11CountLimitedAcceptLoopClientConnection(
        listenerHost,
        listenerPort,
        secondRequestWire
    )
    SocketHttp11CountLimitedAcceptLoopClientCompletion(
        firstConnection.responseWireBytes,
        firstConnection.transportClosedAfterResponse,
        secondConnection.responseWireBytes,
        secondConnection.transportClosedAfterResponse
    )
}

func runSocketHttp11CountLimitedAcceptLoopClientConnection(
    listenerHost: String,
    listenerPort: UInt16,
    requestWire: Array<UInt8>
): SocketHttp11CountLimitedAcceptLoopClientConnectionCompletion {
    let socket = TcpSocket(IPSocketAddress.parse("${listenerHost}:${listenerPort}"))
    socket.connect()
    try {
        socket.write(requestWire)
        SocketHttp11CountLimitedAcceptLoopClientConnectionCompletion(
            readSocketHttp11AcceptOnceResponseWire(socket),
            true
        )
    } finally {
        if (!socket.isClosed()) {
            socket.close()
        }
    }
}
