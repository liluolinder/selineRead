package ignite

import std.collection.ArrayList
import std.net.{IPSocketAddress, TcpServerSocket, TcpSocket}

public class SocketHttp11AcceptOnceExperimentResult {
    public let listenerHost: String
    public let listenerPort: UInt16
    public let acceptedRemoteAddress: String
    public let serverObservedRequestWireBytes: Array<UInt8>
    public let clientObservedResponseWireBytes: Array<UInt8>
    public let runtime: SocketHttp11RuntimeExperimentResult
    public let experimentOwnsServeOnceLifecycle: Bool
    public let transportClosedAfterServeOnce: Bool

    init(
        listenerHost: String,
        listenerPort: UInt16,
        acceptedRemoteAddress: String,
        serverObservedRequestWireBytes: Array<UInt8>,
        clientObservedResponseWireBytes: Array<UInt8>,
        runtime: SocketHttp11RuntimeExperimentResult,
        experimentOwnsServeOnceLifecycle: Bool,
        transportClosedAfterServeOnce: Bool
    ) {
        this.listenerHost = listenerHost
        this.listenerPort = listenerPort
        this.acceptedRemoteAddress = acceptedRemoteAddress
        this.serverObservedRequestWireBytes = cloneSocketHttp11RuntimeExperimentBytes(serverObservedRequestWireBytes)
        this.clientObservedResponseWireBytes = cloneSocketHttp11RuntimeExperimentBytes(clientObservedResponseWireBytes)
        this.runtime = runtime
        this.experimentOwnsServeOnceLifecycle = experimentOwnsServeOnceLifecycle
        this.transportClosedAfterServeOnce = transportClosedAfterServeOnce
    }

    public func helperAllowsConnectionReuse(): Bool {
        runtime.finalConnectionState == SocketHttp11ConnectionState.ReceivingHead
    }

    public func experimentForcedCloseAgainstReusableHelper(): Bool {
        let helperReusable = helperAllowsConnectionReuse()
        transportClosedAfterServeOnce && helperReusable
    }

    public func serverObservedRequestText(): String {
        String.fromUtf8(serverObservedRequestWireBytes)
    }

    public func clientObservedResponseText(): String {
        String.fromUtf8(clientObservedResponseWireBytes)
    }
}

public class SocketHttp11AcceptOnceExperimentException <: Exception {
    public let runtimeCode: SocketHttp11RuntimeExperimentErrorCode
    public let listenerHost: String
    public let listenerPort: UInt16
    public let acceptedRemoteAddress: String
    public let serverObservedRequestWireBytes: Array<UInt8>
    public let clientObservedResponseWireBytes: Array<UInt8>

    public init(
        runtimeCode: SocketHttp11RuntimeExperimentErrorCode,
        message: String,
        listenerHost: String,
        listenerPort: UInt16,
        acceptedRemoteAddress: String,
        serverObservedRequestWireBytes: Array<UInt8>,
        clientObservedResponseWireBytes: Array<UInt8>
    ) {
        super(message)
        this.runtimeCode = runtimeCode
        this.listenerHost = listenerHost
        this.listenerPort = listenerPort
        this.acceptedRemoteAddress = acceptedRemoteAddress
        this.serverObservedRequestWireBytes = cloneSocketHttp11RuntimeExperimentBytes(serverObservedRequestWireBytes)
        this.clientObservedResponseWireBytes = cloneSocketHttp11RuntimeExperimentBytes(clientObservedResponseWireBytes)
    }

    public func serverObservedRequestText(): String {
        String.fromUtf8(serverObservedRequestWireBytes)
    }

    public func clientObservedResponseText(): String {
        String.fromUtf8(clientObservedResponseWireBytes)
    }
}

class SocketHttp11AcceptOnceExperimentServerCompletion {
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
        this.serverObservedRequestWireBytes = cloneSocketHttp11RuntimeExperimentBytes(serverObservedRequestWireBytes)
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
        this.serverObservedRequestWireBytes = cloneSocketHttp11RuntimeExperimentBytes(serverObservedRequestWireBytes)
        this.runtime = None
        this.runtimeCode = Some(runtimeCode)
        this.runtimeMessage = runtimeMessage
    }
}

public func runSocketHttp11AcceptOnceExperiment(
    requestWire: Array<UInt8>,
    listenerHost!: String = "127.0.0.1"
): SocketHttp11AcceptOnceExperimentResult {
    let listener = TcpServerSocket(bindAt: IPSocketAddress.parse("${listenerHost}:0"))
    listener.bind()
    let listenerPort = match ((listener.localAddress as IPSocketAddress)?.port) {
        case Some(port) => port
        case None =>
            throw Exception("socket accept-once experiment listener port is unavailable")
    }

    let serverFuture = spawn {
        serveSocketHttp11AcceptOnceTurn(listener)
    }

    let clientObservedResponseWireBytes =
        runSocketHttp11AcceptOnceClient(listenerHost, listenerPort, requestWire)
    let completion = serverFuture.get(Duration.second * 5)

    match (completion.runtime) {
        case Some(runtime) =>
            SocketHttp11AcceptOnceExperimentResult(
                listenerHost,
                listenerPort,
                completion.acceptedRemoteAddress,
                completion.serverObservedRequestWireBytes,
                clientObservedResponseWireBytes,
                runtime,
                true,
                true
            )
        case None =>
            throw SocketHttp11AcceptOnceExperimentException(
                completion.runtimeCode ??
                    SocketHttp11RuntimeExperimentErrorCode.IncompleteRequest,
                completion.runtimeMessage,
                listenerHost,
                listenerPort,
                completion.acceptedRemoteAddress,
                completion.serverObservedRequestWireBytes,
                clientObservedResponseWireBytes
            )
    }
}

func serveSocketHttp11AcceptOnceTurn(
    listener: TcpServerSocket
): SocketHttp11AcceptOnceExperimentServerCompletion {
    try {
        let accepted = listener.accept()
        try {
            let requestWire = readSocketHttp11AcceptOnceRequestWire(accepted)
            let remoteAddress = accepted.remoteAddress.toString()
            try {
                let runtime = runSocketHttp11RuntimeExperiment(
                    requestWire,
                    remoteAddress: remoteAddress
                )
                if (runtime.responseWireBytes.size > 0) {
                    accepted.write(runtime.responseWireBytes)
                }
                SocketHttp11AcceptOnceExperimentServerCompletion(
                    remoteAddress,
                    requestWire,
                    runtime
                )
            } catch (e: SocketHttp11RuntimeExperimentException) {
                SocketHttp11AcceptOnceExperimentServerCompletion(
                    remoteAddress,
                    requestWire,
                    e.code,
                    e.message
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

func readSocketHttp11AcceptOnceRequestWire(socket: TcpSocket): Array<UInt8> {
    let out = ArrayList<UInt8>()
    let buf = Array<UInt8>(4096, repeat: 0)
    while (true) {
        let n = socket.read(buf)
        if (n <= 0) {
            break
        }
        appendSocketHttp11RuntimeExperimentBytes(out, buf[..n])
        let snapshot = out.toArray()
        if ((tryParseSocketHttp11RequestHead(snapshot)).isSome()) {
            return snapshot
        }
    }
    out.toArray()
}

func runSocketHttp11AcceptOnceClient(
    listenerHost: String,
    listenerPort: UInt16,
    requestWire: Array<UInt8>
): Array<UInt8> {
    let socket = TcpSocket(IPSocketAddress.parse("${listenerHost}:${listenerPort}"))
    socket.connect()
    try {
        socket.write(requestWire)
        readSocketHttp11AcceptOnceResponseWire(socket)
    } finally {
        if (!socket.isClosed()) {
            socket.close()
        }
    }
}

func readSocketHttp11AcceptOnceResponseWire(socket: TcpSocket): Array<UInt8> {
    let out = ArrayList<UInt8>()
    let buf = Array<UInt8>(4096, repeat: 0)
    while (true) {
        let n = socket.read(buf)
        if (n <= 0) {
            break
        }
        appendSocketHttp11RuntimeExperimentBytes(out, buf[..n])
    }
    out.toArray()
}
