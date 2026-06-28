package ignite

import std.collection.ArrayList

public enum SocketHttp11RuntimeExperimentErrorCode <: Equatable<SocketHttp11RuntimeExperimentErrorCode> & ToString {
    | IncompleteRequest
    | BodyStageRequired

    public operator func ==(right: SocketHttp11RuntimeExperimentErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11RuntimeExperimentErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case IncompleteRequest => 0
            case BodyStageRequired => 1
        }
    }

    public func toString(): String {
        match (this) {
            case IncompleteRequest => "INCOMPLETE_REQUEST"
            case BodyStageRequired => "BODY_STAGE_REQUIRED"
        }
    }
}

public class SocketHttp11RuntimeExperimentException <: Exception {
    public let code: SocketHttp11RuntimeExperimentErrorCode

    public init(code: SocketHttp11RuntimeExperimentErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public class SocketHttp11RuntimeExperimentResult {
    public let request: SocketHttp11SessionRequest
    public let requestRemoteAddress: String
    public let requestRawTarget: String
    public let requestTargetFormName: String
    public let requestDispatchPath: String
    public let requestQueryString: String
    public let requestAuthority: String
    public let requestScheme: String
    public let responseVersion: String
    public let responseStatusCode: Int64
    public let responseReasonPhrase: String
    public let responseHeaders: Array<SocketHttp11Header>
    public let responseRequestedBodyMode: SocketHttp11ResponseBodyMode
    public let responseHeaderFraming: SocketHttp11ResponseHeaderFraming
    public let responseDeclaredBodyBytes: Int64
    public let responseKeepAliveAllowed: Bool
    public let responseCloseAfterWrite: Bool
    public let responseWritesPayloadBody: Bool
    public let responseUsesChunkedTransfer: Bool
    public let closeoutResponseRequestsClose: Bool
    public let closeoutShouldCloseConnection: Bool
    public let closeoutNextConnectionState: SocketHttp11ConnectionState
    public let closeoutCloseReason: String
    public let responderLabel: String
    public let logicalBodyBytes: Array<UInt8>
    public let responseWireBytes: Array<UInt8>
    public let finalConnectionState: SocketHttp11ConnectionState

    init(
        request: SocketHttp11SessionRequest,
        requestSnapshot: SocketHttp11RequestSnapshot,
        responseSnapshot: SocketHttp11ResponseSnapshot,
        closeout: SocketHttp11RuntimeTurnCloseout,
        responderLabel: String,
        logicalBodyBytes: Array<UInt8>,
        responseWireBytes: Array<UInt8>,
        finalConnectionState: SocketHttp11ConnectionState
    ) {
        this.request = request
        this.requestRemoteAddress = requestSnapshot.remoteAddress
        this.requestRawTarget = requestSnapshot.rawTarget
        this.requestTargetFormName = requestSnapshot.targetFormName()
        this.requestDispatchPath = requestSnapshot.dispatchPath ?? ""
        this.requestQueryString = requestSnapshot.queryString
        this.requestAuthority = requestSnapshot.authority
        this.requestScheme = requestSnapshot.scheme
        this.responseVersion = responseSnapshot.version
        this.responseStatusCode = responseSnapshot.statusCode
        this.responseReasonPhrase = responseSnapshot.reasonPhrase
        this.responseHeaders = cloneSocketHttp11RuntimeExperimentHeaders(responseSnapshot.headers)
        this.responseRequestedBodyMode = responseSnapshot.requestedBodyMode
        this.responseHeaderFraming = responseSnapshot.headerFraming
        this.responseDeclaredBodyBytes = responseSnapshot.declaredBodyBytes
        this.responseKeepAliveAllowed = responseSnapshot.keepAliveAllowed
        this.responseCloseAfterWrite = responseSnapshot.closeAfterWrite
        this.responseWritesPayloadBody = responseSnapshot.writesPayloadBody()
        this.responseUsesChunkedTransfer = responseSnapshot.usesChunkedTransfer()
        this.closeoutResponseRequestsClose = closeout.responseRequestsClose
        this.closeoutShouldCloseConnection = closeout.shouldCloseConnection
        this.closeoutNextConnectionState = closeout.nextConnectionState
        this.closeoutCloseReason = closeout.closeReason
        this.responderLabel = responderLabel
        this.logicalBodyBytes = cloneSocketHttp11RuntimeExperimentBytes(logicalBodyBytes)
        this.responseWireBytes = cloneSocketHttp11RuntimeExperimentBytes(responseWireBytes)
        this.finalConnectionState = finalConnectionState
    }

    public func responseHeader(name: String): ?String {
        let normalized = name.trimAscii().toAsciiLower()
        for (header in responseHeaders) {
            if (header.name == normalized) {
                return Some(header.value)
            }
        }
        None
    }

    public func requestCanResolveDispatchPath(): Bool {
        requestDispatchPath.size > 0
    }

    public func normalizedDispatchTarget(): String {
        if (requestDispatchPath.size == 0) {
            return requestRawTarget
        }
        if (requestQueryString.size == 0) {
            return requestDispatchPath
        }
        requestDispatchPath + "?" + requestQueryString
    }
}

class SocketHttp11RuntimeExperimentDraft {
    let responderLabel: String
    let statusCode: Int64
    let headers: Array<SocketHttp11Header>
    let bodyMode: SocketHttp11ResponseBodyMode
    let logicalBodyBytes: Array<UInt8>
    let closeAfterWrite: Bool

    init(
        responderLabel: String,
        statusCode: Int64,
        headers: Array<SocketHttp11Header>,
        bodyMode: SocketHttp11ResponseBodyMode,
        logicalBodyBytes: Array<UInt8>,
        closeAfterWrite: Bool
    ) {
        this.responderLabel = responderLabel
        this.statusCode = statusCode
        this.headers = cloneSocketHttp11RuntimeExperimentHeaders(headers)
        this.bodyMode = bodyMode
        this.logicalBodyBytes = cloneSocketHttp11RuntimeExperimentBytes(logicalBodyBytes)
        this.closeAfterWrite = closeAfterWrite
    }
}

public func runSocketHttp11RuntimeExperiment(
    requestWire: Array<UInt8>,
    remoteAddress!: String = ""
): SocketHttp11RuntimeExperimentResult {
    let session = SocketHttp11ConnectionSession()
    session.appendHeadBytes(requestWire)
    let request = match (session.tryOpenRequest()) {
        case Some(request) => request
        case None =>
            throw SocketHttp11RuntimeExperimentException(
                SocketHttp11RuntimeExperimentErrorCode.IncompleteRequest,
                "socket HTTP/1.1 runtime experiment requires one complete request head before a single-turn experiment can begin"
            )
    }

    if (request.bodyPlan.requiresBodyStage) {
        throw SocketHttp11RuntimeExperimentException(
            SocketHttp11RuntimeExperimentErrorCode.BodyStageRequired,
            "socket HTTP/1.1 runtime experiment intentionally stops before request body-stage handoff"
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

func resolveSocketHttp11RuntimeExperimentDraft(
    requestSnapshot: SocketHttp11RequestSnapshot
): SocketHttp11RuntimeExperimentDraft {
    let method = requestSnapshot.method.trimAscii().toAsciiUpper()
    if (method != "GET" && method != "HEAD") {
        return buildSocketHttp11RuntimeExperimentDraft(
            "method-not-allowed",
            405,
            "method not allowed",
            SocketHttp11ResponseBodyMode.KnownLength
        )
    }

    let routeKey = requestSnapshot.dispatchPath ?? requestSnapshot.rawTarget
    match (routeKey) {
        case "/health" =>
            buildSocketHttp11RuntimeExperimentDraft(
                "health",
                200,
                "ok",
                SocketHttp11ResponseBodyMode.KnownLength
            )
        case "/stream" =>
            buildSocketHttp11RuntimeExperimentDraft(
                "stream",
                200,
                "stream",
                SocketHttp11ResponseBodyMode.UnknownLength
            )
        case "/close" =>
            buildSocketHttp11RuntimeExperimentDraft(
                "close",
                202,
                "bye",
                SocketHttp11ResponseBodyMode.KnownLength,
                closeAfterWrite: true
            )
        case _ =>
            buildSocketHttp11RuntimeExperimentDraft(
                "not-found",
                404,
                "not found",
                SocketHttp11ResponseBodyMode.KnownLength
            )
    }
}

func buildSocketHttp11RuntimeExperimentDraft(
    responderLabel: String,
    statusCode: Int64,
    bodyText: String,
    bodyMode: SocketHttp11ResponseBodyMode,
    closeAfterWrite!: Bool = false
): SocketHttp11RuntimeExperimentDraft {
    let headers = ArrayList<SocketHttp11Header>()
    headers.add(SocketHttp11Header("content-type", "text/plain; charset=utf-8"))
    headers.add(SocketHttp11Header("x-ignite-runtime-experiment", responderLabel))
    SocketHttp11RuntimeExperimentDraft(
        responderLabel,
        statusCode,
        headers.toArray(),
        bodyMode,
        bodyText.toArray(),
        closeAfterWrite
    )
}

func appendSocketHttp11RuntimeExperimentBytes(out: ArrayList<UInt8>, bytes: Array<UInt8>): Unit {
    for (b in bytes) {
        out.add(b)
    }
}

func cloneSocketHttp11RuntimeExperimentBytes(bytes: Array<UInt8>): Array<UInt8> {
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

func cloneSocketHttp11RuntimeExperimentHeaders(
    headers: Array<SocketHttp11Header>
): Array<SocketHttp11Header> {
    let out = Array<SocketHttp11Header>(headers.size, repeat: SocketHttp11Header("", ""))
    var i: Int64 = 0
    while (i < headers.size) {
        let header = headers[i]
        out[i] = SocketHttp11Header(header.name, header.value)
        i += 1
    }
    out
}
