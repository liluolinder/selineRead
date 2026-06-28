package ignite

import std.net.{IPSocketAddress, TcpServerSocket, TcpSocket}

public class SocketHttp11DoubleAcceptExperimentConnection {
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

public class SocketHttp11DoubleAcceptExperimentResult {
    public let listenerHost: String
    public let listenerPort: UInt16
    public let firstConnection: SocketHttp11DoubleAcceptExperimentConnection
    public let secondConnection: SocketHttp11DoubleAcceptExperimentConnection
    public let acceptedDistinctConnectionsServedSequentially: Bool
    public let firstConnectionClosedBeforeSecondConnect: Bool
    public let secondConnectionClosedAfterResponse: Bool

    init(
        listenerHost: String,
        listenerPort: UInt16,
        firstConnection: SocketHttp11DoubleAcceptExperimentConnection,
        secondConnection: SocketHttp11DoubleAcceptExperimentConnection,
        acceptedDistinctConnectionsServedSequentially: Bool,
        firstConnectionClosedBeforeSecondConnect: Bool,
        secondConnectionClosedAfterResponse: Bool
    ) {
        this.listenerHost = listenerHost
        this.listenerPort = listenerPort
        this.firstConnection = firstConnection
        this.secondConnection = secondConnection
        this.acceptedDistinctConnectionsServedSequentially =
            acceptedDistinctConnectionsServedSequentially
        this.firstConnectionClosedBeforeSecondConnect =
            firstConnectionClosedBeforeSecondConnect
        this.secondConnectionClosedAfterResponse = secondConnectionClosedAfterResponse
    }

    public func acceptedRemoteAddressesDiffer(): Bool {
        firstConnection.acceptedRemoteAddress != secondConnection.acceptedRemoteAddress
    }
}

public class SocketHttp11DoubleAcceptExperimentException <: Exception {
    public let runtimeCode: SocketHttp11RuntimeExperimentErrorCode
    public let failedConnectionIndex: Int64
    public let listenerHost: String
    public let listenerPort: UInt16
    public let firstCompletedConnection: ?SocketHttp11DoubleAcceptExperimentConnection
    public let failedConnectionAcceptedRemoteAddress: String
    public let failedConnectionRequestWireBytes: Array<UInt8>
    public let clientObservedFirstConnectionResponseWireBytes: Array<UInt8>
    public let clientObservedFailedConnectionResponseWireBytes: Array<UInt8>
    public let firstConnectionClosedBeforeSecondConnect: Bool
    public let failedConnectionClosedAfterResponse: Bool

    public init(
        runtimeCode: SocketHttp11RuntimeExperimentErrorCode,
        failedConnectionIndex: Int64,
        message: String,
        listenerHost: String,
        listenerPort: UInt16,
        firstCompletedConnection: ?SocketHttp11DoubleAcceptExperimentConnection,
        failedConnectionAcceptedRemoteAddress: String,
        failedConnectionRequestWireBytes: Array<UInt8>,
        clientObservedFirstConnectionResponseWireBytes: Array<UInt8>,
        clientObservedFailedConnectionResponseWireBytes: Array<UInt8>,
        firstConnectionClosedBeforeSecondConnect: Bool,
        failedConnectionClosedAfterResponse: Bool
    ) {
        super(message)
        this.runtimeCode = runtimeCode
        this.failedConnectionIndex = failedConnectionIndex
        this.listenerHost = listenerHost
        this.listenerPort = listenerPort
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
        this.firstConnectionClosedBeforeSecondConnect =
            firstConnectionClosedBeforeSecondConnect
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

class SocketHttp11DoubleAcceptClientConnectionCompletion {
    let responseWireBytes: Array<UInt8>
    let transportClosedAfterResponse: Bool

    init(responseWireBytes: Array<UInt8>, transportClosedAfterResponse: Bool) {
        this.responseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(responseWireBytes)
        this.transportClosedAfterResponse = transportClosedAfterResponse
    }
}

class SocketHttp11DoubleAcceptClientCompletion {
    let firstConnectionResponseWireBytes: Array<UInt8>
    let firstConnectionClosedBeforeSecondConnect: Bool
    let secondConnectionResponseWireBytes: Array<UInt8>
    let secondConnectionClosedAfterResponse: Bool

    init(
        firstConnectionResponseWireBytes: Array<UInt8>,
        firstConnectionClosedBeforeSecondConnect: Bool,
        secondConnectionResponseWireBytes: Array<UInt8>,
        secondConnectionClosedAfterResponse: Bool
    ) {
        this.firstConnectionResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(firstConnectionResponseWireBytes)
        this.firstConnectionClosedBeforeSecondConnect =
            firstConnectionClosedBeforeSecondConnect
        this.secondConnectionResponseWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(secondConnectionResponseWireBytes)
        this.secondConnectionClosedAfterResponse = secondConnectionClosedAfterResponse
    }
}

class SocketHttp11DoubleAcceptServerAcceptedConnection {
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

class SocketHttp11DoubleAcceptServerCompletion {
    let firstCompletedConnection: ?SocketHttp11DoubleAcceptServerAcceptedConnection
    let secondCompletedConnection: ?SocketHttp11DoubleAcceptServerAcceptedConnection
    let failureCode: ?SocketHttp11RuntimeExperimentErrorCode
    let failedConnectionIndex: Int64
    let failedConnectionAcceptedRemoteAddress: String
    let failureMessage: String
    let failedConnectionRequestWireBytes: Array<UInt8>

    init(
        firstCompletedConnection: SocketHttp11DoubleAcceptServerAcceptedConnection,
        secondCompletedConnection: SocketHttp11DoubleAcceptServerAcceptedConnection
    ) {
        this.firstCompletedConnection = Some(firstCompletedConnection)
        this.secondCompletedConnection = Some(secondCompletedConnection)
        this.failureCode = None
        this.failedConnectionIndex = 0
        this.failedConnectionAcceptedRemoteAddress = ""
        this.failureMessage = ""
        this.failedConnectionRequestWireBytes = Array<UInt8>(0, repeat: 0)
    }

    init(
        firstCompletedConnection: ?SocketHttp11DoubleAcceptServerAcceptedConnection,
        failedConnectionIndex: Int64,
        failedConnectionAcceptedRemoteAddress: String,
        failureCode: SocketHttp11RuntimeExperimentErrorCode,
        failureMessage: String,
        failedConnectionRequestWireBytes: Array<UInt8>
    ) {
        this.firstCompletedConnection = firstCompletedConnection
        this.secondCompletedConnection = None
        this.failureCode = Some(failureCode)
        this.failedConnectionIndex = failedConnectionIndex
        this.failedConnectionAcceptedRemoteAddress = failedConnectionAcceptedRemoteAddress
        this.failureMessage = failureMessage
        this.failedConnectionRequestWireBytes =
            cloneSocketHttp11RuntimeExperimentBytes(failedConnectionRequestWireBytes)
    }
}

public func runSocketHttp11DoubleAcceptExperiment(
    firstRequestWire: Array<UInt8>,
    secondRequestWire: Array<UInt8>,
    listenerHost!: String = "127.0.0.1"
): SocketHttp11DoubleAcceptExperimentResult {
    let listener = TcpServerSocket(bindAt: IPSocketAddress.parse("${listenerHost}:0"))
    listener.bind()
    let listenerPort = match ((listener.localAddress as IPSocketAddress)?.port) {
        case Some(port) => port
        case None =>
            throw Exception("socket double-accept experiment listener port is unavailable")
    }

    let serverFuture = spawn {
        serveSocketHttp11DoubleAcceptExperiment(listener)
    }

    let clientCompletion = runSocketHttp11DoubleAcceptClient(
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
                        "socket double-accept experiment lost first-connection completion"
                    )
            }
            SocketHttp11DoubleAcceptExperimentResult(
                listenerHost,
                listenerPort,
                buildSocketHttp11DoubleAcceptExperimentConnection(
                    1,
                    firstCompletedConnection,
                    clientCompletion.firstConnectionResponseWireBytes,
                    clientCompletion.firstConnectionClosedBeforeSecondConnect
                ),
                buildSocketHttp11DoubleAcceptExperimentConnection(
                    2,
                    secondCompletedConnection,
                    clientCompletion.secondConnectionResponseWireBytes,
                    clientCompletion.secondConnectionClosedAfterResponse
                ),
                true,
                clientCompletion.firstConnectionClosedBeforeSecondConnect,
                clientCompletion.secondConnectionClosedAfterResponse
            )
        case None =>
            throw SocketHttp11DoubleAcceptExperimentException(
                completion.failureCode ??
                    SocketHttp11RuntimeExperimentErrorCode.IncompleteRequest,
                completion.failedConnectionIndex,
                completion.failureMessage,
                listenerHost,
                listenerPort,
                buildSocketHttp11DoubleAcceptFirstCompletedConnection(
                    completion.firstCompletedConnection,
                    clientCompletion.firstConnectionResponseWireBytes,
                    clientCompletion.firstConnectionClosedBeforeSecondConnect
                ),
                completion.failedConnectionAcceptedRemoteAddress,
                completion.failedConnectionRequestWireBytes,
                clientCompletion.firstConnectionResponseWireBytes,
                clientCompletion.secondConnectionResponseWireBytes,
                clientCompletion.firstConnectionClosedBeforeSecondConnect,
                if (completion.failedConnectionIndex == 1) {
                    clientCompletion.firstConnectionClosedBeforeSecondConnect
                } else {
                    clientCompletion.secondConnectionClosedAfterResponse
                }
            )
    }
}

func buildSocketHttp11DoubleAcceptExperimentConnection(
    connectionIndex: Int64,
    completedConnection: SocketHttp11DoubleAcceptServerAcceptedConnection,
    clientObservedResponseWireBytes: Array<UInt8>,
    transportClosedAfterResponse: Bool
): SocketHttp11DoubleAcceptExperimentConnection {
    let runtime = match (completedConnection.runtime) {
        case Some(runtime) => runtime
        case None =>
            throw Exception("socket double-accept experiment lost runtime completion")
    }
    SocketHttp11DoubleAcceptExperimentConnection(
        connectionIndex,
        completedConnection.acceptedRemoteAddress,
        completedConnection.serverObservedRequestWireBytes,
        clientObservedResponseWireBytes,
        runtime,
        transportClosedAfterResponse
    )
}

func buildSocketHttp11DoubleAcceptFirstCompletedConnection(
    completedConnection: ?SocketHttp11DoubleAcceptServerAcceptedConnection,
    clientObservedResponseWireBytes: Array<UInt8>,
    transportClosedAfterResponse: Bool
): ?SocketHttp11DoubleAcceptExperimentConnection {
    match (completedConnection) {
        case Some(completedConnection) =>
            Some(
                buildSocketHttp11DoubleAcceptExperimentConnection(
                    1,
                    completedConnection,
                    clientObservedResponseWireBytes,
                    transportClosedAfterResponse
                )
            )
        case None => None
    }
}

func serveSocketHttp11DoubleAcceptExperiment(
    listener: TcpServerSocket
): SocketHttp11DoubleAcceptServerCompletion {
    try {
        let firstAccepted = listener.accept()
        let firstRemoteAddress = firstAccepted.remoteAddress.toString()
        let firstConnection = try {
            executeSocketHttp11DoubleAcceptAcceptedConnection(
                firstAccepted,
                firstRemoteAddress
            )
        } finally {
            if (!firstAccepted.isClosed()) {
                firstAccepted.close()
            }
        }

        match (firstConnection.runtime) {
            case Some(_) =>
                let secondAccepted = listener.accept()
                let secondRemoteAddress = secondAccepted.remoteAddress.toString()
                let secondConnection = try {
                    executeSocketHttp11DoubleAcceptAcceptedConnection(
                        secondAccepted,
                        secondRemoteAddress
                    )
                } finally {
                    if (!secondAccepted.isClosed()) {
                        secondAccepted.close()
                    }
                }

                match (secondConnection.runtime) {
                    case Some(_) =>
                        SocketHttp11DoubleAcceptServerCompletion(
                            firstConnection,
                            secondConnection
                        )
                    case None =>
                        SocketHttp11DoubleAcceptServerCompletion(
                            Some(firstConnection),
                            2,
                            secondRemoteAddress,
                            secondConnection.runtimeCode ??
                                SocketHttp11RuntimeExperimentErrorCode.IncompleteRequest,
                            secondConnection.runtimeMessage,
                            secondConnection.serverObservedRequestWireBytes
                        )
                }
            case None =>
                SocketHttp11DoubleAcceptServerCompletion(
                    None,
                    1,
                    firstRemoteAddress,
                    firstConnection.runtimeCode ??
                        SocketHttp11RuntimeExperimentErrorCode.IncompleteRequest,
                    firstConnection.runtimeMessage,
                    firstConnection.serverObservedRequestWireBytes
                )
        }
    } finally {
        if (!listener.isClosed()) {
            listener.close()
        }
    }
}

func executeSocketHttp11DoubleAcceptAcceptedConnection(
    accepted: TcpSocket,
    remoteAddress: String
): SocketHttp11DoubleAcceptServerAcceptedConnection {
    let requestWire = readSocketHttp11AcceptOnceRequestWire(accepted)
    try {
        let runtime = runSocketHttp11RuntimeExperiment(
            requestWire,
            remoteAddress: remoteAddress
        )
        if (runtime.responseWireBytes.size > 0) {
            accepted.write(runtime.responseWireBytes)
        }
        SocketHttp11DoubleAcceptServerAcceptedConnection(
            remoteAddress,
            requestWire,
            runtime
        )
    } catch (e: SocketHttp11RuntimeExperimentException) {
        SocketHttp11DoubleAcceptServerAcceptedConnection(
            remoteAddress,
            requestWire,
            e.code,
            e.message
        )
    }
}

func runSocketHttp11DoubleAcceptClient(
    listenerHost: String,
    listenerPort: UInt16,
    firstRequestWire: Array<UInt8>,
    secondRequestWire: Array<UInt8>
): SocketHttp11DoubleAcceptClientCompletion {
    let firstConnection = runSocketHttp11DoubleAcceptClientConnection(
        listenerHost,
        listenerPort,
        firstRequestWire
    )
    if (firstConnection.responseWireBytes.size == 0) {
        return SocketHttp11DoubleAcceptClientCompletion(
            firstConnection.responseWireBytes,
            false,
            Array<UInt8>(0, repeat: 0),
            false
        )
    }

    let secondConnection = runSocketHttp11DoubleAcceptClientConnection(
        listenerHost,
        listenerPort,
        secondRequestWire
    )
    SocketHttp11DoubleAcceptClientCompletion(
        firstConnection.responseWireBytes,
        firstConnection.transportClosedAfterResponse,
        secondConnection.responseWireBytes,
        secondConnection.transportClosedAfterResponse
    )
}

func runSocketHttp11DoubleAcceptClientConnection(
    listenerHost: String,
    listenerPort: UInt16,
    requestWire: Array<UInt8>
): SocketHttp11DoubleAcceptClientConnectionCompletion {
    let socket = TcpSocket(IPSocketAddress.parse("${listenerHost}:${listenerPort}"))
    socket.connect()
    try {
        socket.write(requestWire)
        SocketHttp11DoubleAcceptClientConnectionCompletion(
            readSocketHttp11AcceptOnceResponseWire(socket),
            true
        )
    } finally {
        if (!socket.isClosed()) {
            socket.close()
        }
    }
}
