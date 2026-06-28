package ignite

import std.fs.{File, OpenMode}
import std.collection.ArrayList
import std.io.InputStream
import std.net.TcpSocket
import stdx.net.http.{ServerBuilder, Server, HttpRequestDistributor, HttpRequestHandler, HttpContext, HttpHeaders, WebSocket}
import ignite.api2
import jinguissl.live.{
    ContractAcceptedTransportDescriptor,
    ContractHttpServerAttachPlan,
    ContractHttpServerAttachResult,
    ContractHttpServerAcceptedTransportSession,
    ContractHttpServerAcceptedTransportTls13X25519Request,
    ContractHttpServerLibraryStartupRequest,
    ContractTlsRecordContentType,
    ContractHttpServerTlsConfigRequest,
    ContractTlsHttpNegotiationPolicy,
    contractAttachAcceptedTransportTls13X25519,
    contractAttachAcceptedTransportTls13X25519Request,
    contractCloseAcceptedTransportSession,
    contractPlanHttpServerAttachRequest
}

public class ServerTransportTouchpoint {
    public let candidateOrder: String
    public let blockedCandidates: String
    public let selectedBackend: String
    public let selectedReason: String
    public let providerId: String
    public let publicPath: String
    public let riskLevel: String
    public let tlsEnabled: Bool
    public let fallbackReason: String

    public init(
        candidateOrder: String,
        blockedCandidates: String,
        selectedBackend: String,
        selectedReason: String,
        providerId: String,
        publicPath: String,
        riskLevel: String,
        tlsEnabled: Bool,
        fallbackReason: String
    ) {
        this.candidateOrder = candidateOrder
        this.blockedCandidates = blockedCandidates
        this.selectedBackend = selectedBackend
        this.selectedReason = selectedReason
        this.providerId = providerId
        this.publicPath = publicPath
        this.riskLevel = riskLevel
        this.tlsEnabled = tlsEnabled
        this.fallbackReason = fallbackReason
    }

    public func toJson(): String {
        #"{"candidateOrder":"# + "\"" + serverEscapeJson(candidateOrder) + "\"" +
        #","blockedCandidates":"# + "\"" + serverEscapeJson(blockedCandidates) + "\"" +
        #","selectedBackend":"# + "\"" + serverEscapeJson(selectedBackend) + "\"" +
        #","selectedReason":"# + "\"" + serverEscapeJson(selectedReason) + "\"" +
        #","providerId":"# + "\"" + serverEscapeJson(providerId) + "\"" +
        #","publicPath":"# + "\"" + serverEscapeJson(publicPath) + "\"" +
        #","riskLevel":"# + "\"" + serverEscapeJson(riskLevel) + "\"" +
        #","tlsEnabled":"# + serverBoolToJson(tlsEnabled) +
        #","fallbackReason":"# + "\"" + serverEscapeJson(fallbackReason) + "\"" +
        #"}"#
    }
}

public class ServerStartupObserveEvent {
    public let phase: String
    public let addr: String
    public let port: UInt16
    public let scheme: String
    public let tlsEnabled: Bool
    public let transportTouchpoint: ?ServerTransportTouchpoint
    public let jinguiAttachResultSnapshot: ?ServerJinguiHttpServerAttachResultSnapshot
    public let failureStage: String
    public let failureCode: String
    public let igniteErrorCode: String
    public let failureSource: String
    public let hint: String
    public let message: String

    public init(
        phase: String,
        addr: String,
        port: UInt16,
        scheme: String,
        tlsEnabled: Bool,
        transportTouchpoint!: ?ServerTransportTouchpoint = None,
        jinguiAttachResultSnapshot!: ?ServerJinguiHttpServerAttachResultSnapshot = None,
        failureStage!: String = "-",
        failureCode!: String = "-",
        igniteErrorCode!: String = "-",
        failureSource!: String = "-",
        hint!: String = "-",
        message!: String = ""
    ) {
        this.phase = phase
        this.addr = addr
        this.port = port
        this.scheme = scheme
        this.tlsEnabled = tlsEnabled
        this.transportTouchpoint = transportTouchpoint
        this.jinguiAttachResultSnapshot = jinguiAttachResultSnapshot
        this.failureStage = failureStage
        this.failureCode = failureCode
        this.igniteErrorCode = igniteErrorCode
        this.failureSource = failureSource
        this.hint = hint
        this.message = message
    }

    public func toJson(): String {
        let touchpointJson = if (let Some(touchpoint) <- transportTouchpoint) {
            touchpoint.toJson()
        } else {
            "null"
        }
        let jinguiAttachJson = if (
            let Some(snapshot) <- jinguiAttachResultSnapshot
        ) {
            snapshot.toJson()
        } else {
            "null"
        }
        #"{"phase":"# + "\"" + serverEscapeJson(phase) + "\"" +
        #","addr":"# + "\"" + serverEscapeJson(addr) + "\"" +
        #","port":"# + "${port}" +
        #","scheme":"# + "\"" + serverEscapeJson(scheme) + "\"" +
        #","tlsEnabled":"# + serverBoolToJson(tlsEnabled) +
        #","failureStage":"# + "\"" + serverEscapeJson(failureStage) + "\"" +
        #","failureCode":"# + "\"" + serverEscapeJson(failureCode) + "\"" +
        #","igniteErrorCode":"# + "\"" + serverEscapeJson(igniteErrorCode) + "\"" +
        #","failureSource":"# + "\"" + serverEscapeJson(failureSource) + "\"" +
        #","hint":"# + "\"" + serverEscapeJson(hint) + "\"" +
        #","message":"# + "\"" + serverEscapeJson(message) + "\"" +
        #","transportTouchpoint":"# + touchpointJson +
        #","jinguiAttachResultSnapshot":"# + jinguiAttachJson +
        #"}"#
    }
}

public type ServerStartupObserveHook = (ServerStartupObserveEvent) -> Unit
public type ServerPreparedTlsMaterialLoader = () -> api2.PreparedHttpServerTlsMaterial
public type ServerJinguiAcceptedTransportSessionHook =
    (ServerJinguiAcceptedTransportSessionSnapshot) -> Unit
public type ServerJinguiAcceptedTransportAttachedSessionReadyHook =
    (ContractHttpServerAcceptedTransportSession) -> Unit
public type ServerJinguiAcceptedTransportAttachedSessionEncodedRequestRecordsBuilder =
    (ContractHttpServerAcceptedTransportSession) -> Array<Array<Byte>>
public type ServerJinguiAcceptedTransportAttachedSessionEncodedRequestWireFragmentsBuilder =
    (ContractHttpServerAcceptedTransportSession) -> Array<Array<Byte>>

public class ServerJinguiHttpServerAttachResultSnapshot {
    public let tlsVersion: String
    public let cipherSuite: String
    public let negotiatedAlpn: String
    public let requestedServerName: String
    public let acknowledgedServerName: Bool
    public let secureSessionReady: Bool
    public let attachSurface: String

    public init(
        tlsVersion: String,
        cipherSuite: String,
        negotiatedAlpn: String,
        requestedServerName: String,
        acknowledgedServerName: Bool,
        secureSessionReady: Bool,
        attachSurface: String
    ) {
        this.tlsVersion = tlsVersion
        this.cipherSuite = cipherSuite
        this.negotiatedAlpn = negotiatedAlpn
        this.requestedServerName = requestedServerName
        this.acknowledgedServerName = acknowledgedServerName
        this.secureSessionReady = secureSessionReady
        this.attachSurface = attachSurface
    }

    public func toJson(): String {
        #"{"tlsVersion":"# + "\"" + serverEscapeJson(tlsVersion) + "\"" +
        #","cipherSuite":"# + "\"" + serverEscapeJson(cipherSuite) + "\"" +
        #","negotiatedAlpn":"# + "\"" + serverEscapeJson(negotiatedAlpn) + "\"" +
        #","requestedServerName":"# + "\"" + serverEscapeJson(requestedServerName) + "\"" +
        #","acknowledgedServerName":"# + serverBoolToJson(acknowledgedServerName) +
        #","secureSessionReady":"# + serverBoolToJson(secureSessionReady) +
        #","attachSurface":"# + "\"" + serverEscapeJson(attachSurface) + "\"" +
        #"}"#
    }
}

public func buildServerJinguiHttpServerAttachResultSnapshot(
    attachResult: ContractHttpServerAttachResult
): ServerJinguiHttpServerAttachResultSnapshot {
    ServerJinguiHttpServerAttachResultSnapshot(
        attachResult.tlsVersion.toString(),
        attachResult.cipherSuite,
        attachResult.negotiatedAlpn,
        attachResult.requestedServerName,
        attachResult.acknowledgedServerName,
        attachResult.secureSessionReady,
        attachResult.attachSurface
    )
}

public class ServerJinguiAcceptedTransportDescriptorSnapshot {
    public let transportId: String
    public let transportKind: String
    public let localEndpoint: String
    public let remoteEndpoint: String

    public init(
        transportId: String,
        transportKind: String,
        localEndpoint: String,
        remoteEndpoint: String
    ) {
        this.transportId = transportId
        this.transportKind = transportKind
        this.localEndpoint = localEndpoint
        this.remoteEndpoint = remoteEndpoint
    }

    public func toJson(): String {
        #"{"transportId":"# + "\"" + serverEscapeJson(transportId) + "\"" +
        #","transportKind":"# + "\"" + serverEscapeJson(transportKind) + "\"" +
        #","localEndpoint":"# + "\"" + serverEscapeJson(localEndpoint) + "\"" +
        #","remoteEndpoint":"# + "\"" + serverEscapeJson(remoteEndpoint) + "\"" +
        #"}"#
    }
}

public func buildServerJinguiAcceptedTransportDescriptorSnapshot(
    transport: ContractAcceptedTransportDescriptor
): ServerJinguiAcceptedTransportDescriptorSnapshot {
    ServerJinguiAcceptedTransportDescriptorSnapshot(
        transport.transportId,
        transport.transportKind,
        transport.localEndpoint,
        transport.remoteEndpoint
    )
}

public class ServerJinguiAcceptedTransportSessionSnapshot {
    public let transport: ServerJinguiAcceptedTransportDescriptorSnapshot
    public let status: String
    public let jinguiAttachResultSnapshot: ServerJinguiHttpServerAttachResultSnapshot
    public let secureSessionReady: Bool
    public let recordChannelVersion: String
    public let closeReason: String

    public init(
        transport: ServerJinguiAcceptedTransportDescriptorSnapshot,
        status: String,
        jinguiAttachResultSnapshot: ServerJinguiHttpServerAttachResultSnapshot,
        secureSessionReady: Bool,
        recordChannelVersion: String,
        closeReason: String
    ) {
        this.transport = transport
        this.status = status
        this.jinguiAttachResultSnapshot = jinguiAttachResultSnapshot
        this.secureSessionReady = secureSessionReady
        this.recordChannelVersion = recordChannelVersion
        this.closeReason = closeReason
    }

    public func toJson(): String {
        #"{"transport":"# + transport.toJson() +
        #","status":"# + "\"" + serverEscapeJson(status) + "\"" +
        #","jinguiAttachResultSnapshot":"# + jinguiAttachResultSnapshot.toJson() +
        #","secureSessionReady":"# + serverBoolToJson(secureSessionReady) +
        #","recordChannelVersion":"# + "\"" + serverEscapeJson(recordChannelVersion) + "\"" +
        #","closeReason":"# + "\"" + serverEscapeJson(closeReason) + "\"" +
        #"}"#
    }
}

public func buildServerJinguiAcceptedTransportSessionSnapshot(
    session: ContractHttpServerAcceptedTransportSession
): ServerJinguiAcceptedTransportSessionSnapshot {
    ServerJinguiAcceptedTransportSessionSnapshot(
        buildServerJinguiAcceptedTransportDescriptorSnapshot(session.transport),
        session.status.toString(),
        buildServerJinguiHttpServerAttachResultSnapshot(session.result),
        session.secureSessionReady,
        session.recordChannel.version.toString(),
        session.closeReason
    )
}

func serverJinguiAcceptedTransportLogicalRequestPathOnly(target: String): String {
    if (let Some(queryIndex) <- target.indexOf("?")) {
        return target[..queryIndex]
    }
    target
}

func serverJinguiAcceptedTransportLogicalRequestQueryString(
    target: String
): String {
    if (let Some(queryIndex) <- target.indexOf("?")) {
        if (queryIndex + 1 >= target.size) {
            return ""
        }
        return target[queryIndex + 1..target.size]
    }
    ""
}

func serverJinguiAcceptedTransportReadQueryValue(
    queryString: String,
    key: String
): ?String {
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

func buildServerJinguiAcceptedTransportLogicalRequestHeadersWithAuthority(
    authority: String,
    headers: ?HttpHeaders
): HttpHeaders {
    let out = if (let Some(value) <- headers) {
        cloneServerEngineHeaders(value)
    } else {
        HttpHeaders()
    }
    if (authority.size > 0) {
        let existingHost = out.getFirst("host") ?? ""
        if (existingHost.size == 0) {
            out.add("host", authority)
        }
    }
    out
}

public class ServerJinguiAcceptedTransportH2PseudoHeaders {
    public let method: String
    public let path: String
    public let authority: String

    public init(
        method: String,
        path: String,
        authority!: String = ""
    ) {
        this.method = method
        this.path = path
        this.authority = authority
    }
}

public class ServerJinguiAcceptedTransportLogicalRequest {
    public let method: String
    public let path: String
    public let urlString: String
    public let versionString: String
    public let headers: HttpHeaders
    public let bodyBytes: Array<UInt8>
    public let queryString: String

    public init(
        method: String,
        path: String,
        urlString!: String = "",
        versionString!: String = "h2",
        headers!: ?HttpHeaders = None,
        bodyBytes!: Array<UInt8> = []
    ) {
        let resolvedUrlString = if (urlString.size > 0) {
            urlString
        } else {
            path
        }
        let resolvedPathTarget = if (path.size > 0) {
            path
        } else {
            resolvedUrlString
        }
        this.method = method
        this.path =
            serverJinguiAcceptedTransportLogicalRequestPathOnly(
                resolvedPathTarget
            )
        this.urlString = resolvedUrlString
        this.versionString = if (versionString.size > 0) {
            versionString
        } else {
            "h2"
        }
        this.headers = if (let Some(value) <- headers) {
            cloneServerEngineHeaders(value)
        } else {
            HttpHeaders()
        }
        this.bodyBytes = cloneServerEngineUInt8Array(bodyBytes)
        this.queryString =
            serverJinguiAcceptedTransportLogicalRequestQueryString(
                resolvedUrlString
            )
    }
}

public func buildServerJinguiAcceptedTransportLogicalRequestFromH2PseudoHeaders(
    pseudoHeaders: ServerJinguiAcceptedTransportH2PseudoHeaders,
    headers!: ?HttpHeaders = None,
    bodyBytes!: Array<UInt8> = []
): ServerJinguiAcceptedTransportLogicalRequest {
    let projectedHeaders =
        buildServerJinguiAcceptedTransportLogicalRequestHeadersWithAuthority(
            pseudoHeaders.authority,
            headers
        )
    ServerJinguiAcceptedTransportLogicalRequest(
        pseudoHeaders.method,
        pseudoHeaders.path,
        urlString: pseudoHeaders.path,
        versionString: "h2",
        headers: Some(projectedHeaders),
        bodyBytes: bodyBytes
    )
}

func serverJinguiAcceptedTransportH2FieldNameIsPseudo(name: String): Bool {
    let runes = name.toRuneArray()
    runes.size > 0 && runes[0] == r':'
}

public func buildServerJinguiAcceptedTransportH2PseudoHeadersFromDecodedHeaderFields(
    headerFields: Array<JinguiAcceptedTransportH2DecodedHeaderField>
): ServerJinguiAcceptedTransportH2PseudoHeaders {
    var method = ""
    var path = ""
    var authority = ""
    for (field in headerFields) {
        if (field.name == ":method") {
            method = field.value
            continue
        }
        if (field.name == ":path") {
            path = field.value
            continue
        }
        if (field.name == ":authority") {
            authority = field.value
            continue
        }
        if (field.name == ":scheme") {
            continue
        }
        if (serverJinguiAcceptedTransportH2FieldNameIsPseudo(field.name)) {
            throw Exception(
                "H2 decoded header-field projection does not support pseudo header `${field.name}` in this bounded seam"
            )
        }
    }
    if (method.size == 0) {
        throw Exception(
            "H2 decoded header-field projection requires `:method` in this bounded seam"
        )
    }
    if (path.size == 0) {
        throw Exception(
            "H2 decoded header-field projection requires `:path` in this bounded seam"
        )
    }
    ServerJinguiAcceptedTransportH2PseudoHeaders(
        method,
        path,
        authority: authority
    )
}

public func buildServerJinguiAcceptedTransportLogicalRequestFromDecodedH2HeaderFields(
    headerFields: Array<JinguiAcceptedTransportH2DecodedHeaderField>,
    bodyBytes!: Array<UInt8> = []
): ServerJinguiAcceptedTransportLogicalRequest {
    let pseudoHeaders =
        buildServerJinguiAcceptedTransportH2PseudoHeadersFromDecodedHeaderFields(
            headerFields
        )
    let headers = HttpHeaders()
    for (field in headerFields) {
        if (
            field.name == ":method" ||
            field.name == ":path" ||
            field.name == ":authority" ||
            field.name == ":scheme"
        ) {
            continue
        }
        if (serverJinguiAcceptedTransportH2FieldNameIsPseudo(field.name)) {
            throw Exception(
                "H2 decoded header-field logical-request projection does not support pseudo header `${field.name}` in this bounded seam"
            )
        }
        headers.add(field.name, field.value)
    }
    buildServerJinguiAcceptedTransportLogicalRequestFromH2PseudoHeaders(
        pseudoHeaders,
        headers: Some(headers),
        bodyBytes: bodyBytes
    )
}

public func buildServerJinguiAcceptedTransportH2PseudoHeadersFromHeaderBlock(
    headerBlock: JinguiAcceptedTransportH2HeaderBlockSnapshot
): ServerJinguiAcceptedTransportH2PseudoHeaders {
    buildServerJinguiAcceptedTransportH2PseudoHeadersFromDecodedHeaderFields(
        parseJinguiAcceptedTransportH2HeaderFields(headerBlock)
    )
}

public func buildServerJinguiAcceptedTransportLogicalRequestFromH2HeaderBlock(
    headerBlock: JinguiAcceptedTransportH2HeaderBlockSnapshot,
    bodyBytes!: Array<UInt8> = []
): ServerJinguiAcceptedTransportLogicalRequest {
    buildServerJinguiAcceptedTransportLogicalRequestFromDecodedH2HeaderFields(
        parseJinguiAcceptedTransportH2HeaderFields(headerBlock),
        bodyBytes: bodyBytes
    )
}

public class ServerJinguiAcceptedTransportTls13ClientHelloCapture {
    public let encodedClientHello: Array<Byte>
    public let consumedRecordCount: Int64
    public let consumedRecordWireByteCount: Int64

    public init(
        encodedClientHello: Array<Byte>,
        consumedRecordCount: Int64,
        consumedRecordWireByteCount: Int64
    ) {
        if (
            encodedClientHello.size == 0 ||
            consumedRecordCount <= 0 ||
            consumedRecordWireByteCount <= 0
        ) {
            throw Exception(
                "accepted-socket TLS client-hello capture fields are invalid"
            )
        }
        this.encodedClientHello = cloneServerEngineByteWindow(
            encodedClientHello,
            0,
            encodedClientHello.size
        )
        this.consumedRecordCount = consumedRecordCount
        this.consumedRecordWireByteCount = consumedRecordWireByteCount
    }
}

public class ServerJinguiAcceptedTransportSocketAttachedSessionResult {
    public let capture: ServerJinguiAcceptedTransportTls13ClientHelloCapture
    public let session: ContractHttpServerAcceptedTransportSession
    public let readySnapshot: ServerJinguiAcceptedTransportSessionSnapshot

    public init(
        capture: ServerJinguiAcceptedTransportTls13ClientHelloCapture,
        session: ContractHttpServerAcceptedTransportSession,
        readySnapshot: ServerJinguiAcceptedTransportSessionSnapshot
    ) {
        this.capture = capture
        this.session = session
        this.readySnapshot = readySnapshot
    }
}

public class ServerJinguiAcceptedTransportSocketResponseTurnResult {
    public let session: ContractHttpServerAcceptedTransportSession
    public let readySnapshot: ServerJinguiAcceptedTransportSessionSnapshot
    public let responseStatus: UInt16
    public let responseHeaders: HttpHeaders
    public let socketWriteCount: Int64
    public let totalEncodedSocketBytes: Int64

    public init(
        session: ContractHttpServerAcceptedTransportSession,
        readySnapshot: ServerJinguiAcceptedTransportSessionSnapshot,
        responseStatus: UInt16,
        responseHeaders: HttpHeaders,
        socketWriteCount: Int64,
        totalEncodedSocketBytes: Int64
    ) {
        this.session = session
        this.readySnapshot = readySnapshot
        this.responseStatus = responseStatus
        this.responseHeaders = responseHeaders
        this.socketWriteCount = socketWriteCount
        this.totalEncodedSocketBytes = totalEncodedSocketBytes
    }
}

class ServerJinguiAcceptedTransportEmptyInputStream <: InputStream {
    public override func read(outBuf: Array<Byte>): Int64 {
        let _ = outBuf
        0
    }

    public func close(): Unit {}
}

class ServerJinguiAcceptedTransportBytesInputStream <: InputStream {
    let bytes: Array<UInt8>
    var offset: Int64 = 0

    init(bytes: Array<UInt8>) {
        this.bytes = bytes
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

class ServerJinguiAcceptedTransportSocketResponseCarrier <: CurrentRequestCarrier {
    let logicalRequest: ServerJinguiAcceptedTransportLogicalRequest
    let socket: TcpSocket
    let requestBodyStreamValue: InputStream
    public let responseHeaders = HttpHeaders()
    public var responseStatus: UInt16 = 200
    public var socketWriteCount: Int64 = 0
    public var totalEncodedSocketBytes: Int64 = 0

    init(
        logicalRequest: ServerJinguiAcceptedTransportLogicalRequest,
        socket: TcpSocket
    ) {
        this.logicalRequest = logicalRequest
        this.socket = socket
        this.requestBodyStreamValue = if (logicalRequest.bodyBytes.size > 0) {
            ServerJinguiAcceptedTransportBytesInputStream(logicalRequest.bodyBytes)
        } else {
            ServerJinguiAcceptedTransportEmptyInputStream()
        }
    }

    func writeSocketResponseBytes(bytes: Array<UInt8>): Unit {
        socketWriteCount += 1
        totalEncodedSocketBytes += bytes.size
        socket.write(bytes)
    }

    public override func rawHttpContext(): HttpContext {
        throw Exception("raw HttpContext should not be required for accepted transport socket response carrier")
    }

    public override func upgradeWebSocketRaw(): WebSocket {
        throw Exception("websocket upgrade should not run for accepted transport socket response carrier")
    }

    public override func openResponseTransportWriterRaw(): ResponseTransportWriter {
        openSinkBackedResponseTransportWriter({ bytes =>
            writeSocketResponseBytes(bytes)
        })
    }

    public override func requestMethod(): String {
        logicalRequest.method
    }

    public override func requestPath(): String {
        logicalRequest.path
    }

    public override func requestUrlString(): String {
        logicalRequest.urlString
    }

    public override func requestVersionString(): String {
        logicalRequest.versionString
    }

    public override func requestRemoteAddr(): String {
        socket.remoteAddress.toString()
    }

    public override func requestQueryValue(key: String): ?String {
        serverJinguiAcceptedTransportReadQueryValue(
            logicalRequest.queryString,
            key
        )
    }

    public override func requestFormValue(key: String): ?String {
        let _ = key
        None
    }

    public override func requestHeaderValue(key: String): ?String {
        logicalRequest.headers.getFirst(key)
    }

    public override func requestHeaders(): HttpHeaders {
        logicalRequest.headers
    }

    public override func requestBodyStream(): InputStream {
        requestBodyStreamValue
    }

    public override func requestBodySize(): ?Int64 {
        Some(logicalRequest.bodyBytes.size)
    }

    public override func setResponseStatus(code: UInt16): Unit {
        responseStatus = code
    }

    public override func setResponseHeader(key: String, value: String): Unit {
        responseHeaders.add(key, value)
    }

    public override func addResponseHeaders(headers: HttpHeaders): Unit {
        for ((name, values) in headers) {
            for (value in values) {
                setResponseHeader(name, value)
            }
        }
    }

    public override func setResponseString(body: String): Unit {
        let _ = body
        throw Exception(
            "response string should be intercepted by accepted transport socket response carrier wrapper"
        )
    }

    public override func setResponseBytes(data: Array<UInt8>): Unit {
        let _ = data
        throw Exception(
            "response bytes should be intercepted by accepted transport socket response carrier wrapper"
        )
    }

    public override func attachResponseBodyStream(stream: InputStream): Unit {
        let _ = stream
        throw Exception(
            "response stream should be intercepted by accepted transport socket response carrier wrapper"
        )
    }
}

/// Incrementally accumulates accepted-session TLS record wire until one or more
/// complete encoded records are available.
///
/// This helper is intentionally bounded: it only restores complete record
/// boundaries from fragmented bytes and does not claim live socket ownership,
/// backpressure, or generic incremental TLS parser semantics.
public class JinguiAcceptedTransportRecordWireAccumulator {
    var _buffer = ArrayList<Byte>()
    var _readCursor: Int64 = 0

    public init() {}

    public func append(fragment: Array<Byte>): Unit {
        if (fragment.size == 0) {
            return
        }
        for (b in fragment) {
            _buffer.add(b)
        }
    }

    public func drainCompleteRecords(): Array<Array<Byte>> {
        let out = ArrayList<Array<Byte>>()
        while (true) {
            let remaining = bufferedByteCount()
            if (remaining < 5) {
                break
            }
            let payloadLen =
                (Int64(UInt8(_buffer[_readCursor + 3])) << 8) +
                Int64(UInt8(_buffer[_readCursor + 4]))
            let recordSize = Int64(5) + payloadLen
            if (remaining < recordSize) {
                break
            }
            out.add(
                cloneServerEngineByteListWindow(
                    _buffer,
                    _readCursor,
                    recordSize
                )
            )
            _readCursor += recordSize
        }
        compactBuffer()
        out.toArray()
    }

    public func bufferedByteCount(): Int64 {
        _buffer.size - _readCursor
    }

    func compactBuffer(): Unit {
        if (_readCursor <= 0) {
            return
        }
        if (_readCursor >= _buffer.size) {
            _buffer = ArrayList<Byte>()
            _readCursor = 0
            return
        }
        let next = ArrayList<Byte>()
        var i = _readCursor
        while (i < _buffer.size) {
            next.add(_buffer[i])
            i += 1
        }
        _buffer = next
        _readCursor = 0
    }
}

class JinguiAcceptedTransportTls13ClientHelloAccumulator {
    var _buffer = ArrayList<Byte>()

    public init() {}

    public func appendHandshakeRecord(
        encodedRecord: Array<Byte>
    ): ?Array<Byte> {
        if (encodedRecord.size < 5) {
            throw Exception(
                "accepted-socket TLS client-hello capture expected one complete TLS record header"
            )
        }
        if (UInt8(encodedRecord[0]) != UInt8(0x16)) {
            throw Exception(
                "accepted-socket TLS client-hello capture expected handshake record contentType=22, got=${Int64(UInt8(encodedRecord[0]))}"
            )
        }
        let payloadLen =
            (Int64(UInt8(encodedRecord[3])) << 8) +
            Int64(UInt8(encodedRecord[4]))
        if (encodedRecord.size != Int64(5) + payloadLen) {
            throw Exception(
                "accepted-socket TLS client-hello capture record payload length mismatch, recordBytes=${encodedRecord.size}, payloadLen=${payloadLen}"
            )
        }
        var i: Int64 = 5
        while (i < encodedRecord.size) {
            _buffer.add(encodedRecord[i])
            i += 1
        }
        if (_buffer.size < 4) {
            return None
        }
        if (UInt8(_buffer[0]) != UInt8(0x1)) {
            throw Exception(
                "accepted-socket TLS client-hello capture expected handshakeType=1, got=${Int64(UInt8(_buffer[0]))}"
            )
        }
        let clientHelloLen =
            (Int64(UInt8(_buffer[1])) << 16) +
            (Int64(UInt8(_buffer[2])) << 8) +
            Int64(UInt8(_buffer[3]))
        let totalClientHelloBytes = Int64(4) + clientHelloLen
        if (_buffer.size < totalClientHelloBytes) {
            return None
        }
        if (_buffer.size > totalClientHelloBytes) {
            throw Exception(
                "accepted-socket TLS client-hello capture first cut does not support trailing handshake bytes beyond one ClientHello, bufferedHandshakeBytes=${_buffer.size}, expectedClientHelloBytes=${totalClientHelloBytes}"
            )
        }
        Some(
            cloneServerEngineByteListWindow(
                _buffer,
                0,
                totalClientHelloBytes
            )
        )
    }

    public func bufferedHandshakeByteCount(): Int64 {
        _buffer.size
    }
}

func captureJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloCore(
    acceptedSocket: TcpSocket,
    readChunkSize!: Int64 = 4096
): ServerJinguiAcceptedTransportTls13ClientHelloCapture {
    let recordAccumulator = JinguiAcceptedTransportRecordWireAccumulator()
    let clientHelloAccumulator =
        JinguiAcceptedTransportTls13ClientHelloAccumulator()
    let chunkSize = if (readChunkSize > 0) {
        readChunkSize
    } else {
        4096
    }
    let buf = Array<UInt8>(chunkSize, repeat: 0)
    var consumedRecordCount: Int64 = 0
    var consumedRecordWireByteCount: Int64 = 0
    while (true) {
        let n = acceptedSocket.read(buf)
        if (n <= 0) {
            break
        }
        recordAccumulator.append(serverEngineUInt8ToByteArray(buf[..n]))
        let readyRecords = recordAccumulator.drainCompleteRecords()
        var i: Int64 = 0
        while (i < readyRecords.size) {
            let record = readyRecords[i]
            consumedRecordCount += 1
            consumedRecordWireByteCount += record.size
            if (
                let Some(encodedClientHello) <-
                    clientHelloAccumulator.appendHandshakeRecord(record)
            ) {
                if (
                    i + 1 < readyRecords.size ||
                    recordAccumulator.bufferedByteCount() != 0
                ) {
                    throw Exception(
                        "accepted-socket TLS client-hello capture first cut does not support trailing TLS record wire beyond one ClientHello, trailingReadyRecords=${readyRecords.size - (i + 1)}, trailingBufferedRecordWireBytes=${recordAccumulator.bufferedByteCount()}"
                    )
                }
                return ServerJinguiAcceptedTransportTls13ClientHelloCapture(
                    encodedClientHello,
                    consumedRecordCount,
                    consumedRecordWireByteCount
                )
            }
            i += 1
        }
    }
    throw Exception(
        "accepted-socket TLS client-hello capture expected one complete ClientHello before socket read ended, consumedRecordCount=${consumedRecordCount}, consumedRecordWireBytes=${consumedRecordWireByteCount}, bufferedRecordWireBytes=${recordAccumulator.bufferedByteCount()}, bufferedHandshakeBytes=${clientHelloAccumulator.bufferedHandshakeByteCount()}"
    )
}

/// Splits one complete concatenated TLS record wire into encoded record slices.
///
/// This helper only works on already-buffered complete wire bytes. It does not
/// claim incremental stream parsing or accepted-socket runtime ownership.
public func splitJinguiAcceptedTransportRecordWire(
    encodedWire: Array<Byte>
): Array<Array<Byte>> {
    let out = ArrayList<Array<Byte>>()
    var cursor: Int64 = 0
    while (cursor < encodedWire.size) {
        let remaining = encodedWire.size - cursor
        if (remaining < 5) {
            throw Exception(
                "TLS record wire truncated before full header at offset=${cursor}, remaining=${remaining}"
            )
        }
        let payloadLen =
            (Int64(UInt8(encodedWire[cursor + 3])) << 8) +
            Int64(UInt8(encodedWire[cursor + 4]))
        let recordSize = Int64(5) + payloadLen
        if (remaining < recordSize) {
            throw Exception(
                "TLS record wire truncated before full payload at offset=${cursor}, recordSize=${recordSize}, remaining=${remaining}"
            )
        }
        out.add(
            cloneServerEngineByteWindow(
                encodedWire,
                cursor,
                recordSize
            )
        )
        cursor += recordSize
    }
    out.toArray()
}

/// Snapshot of one complete H2 frame wire.
///
/// This helper is intentionally bounded to already-buffered complete frame
/// bytes. It restores only header fields plus payload and does not claim HPACK
/// ownership, stream lifecycle semantics, flow-control, or accepted-socket
/// runtime ownership.
public class JinguiAcceptedTransportH2FrameWireSnapshot {
    public let payloadLength: Int64
    public let frameType: UInt8
    public let flags: UInt8
    public let streamId: Int64
    public let payload: Array<Byte>

    public init(
        payloadLength: Int64,
        frameType: UInt8,
        flags: UInt8,
        streamId: Int64,
        payload: Array<Byte>
    ) {
        this.payloadLength = payloadLength
        this.frameType = frameType
        this.flags = flags
        this.streamId = streamId
        this.payload = cloneServerEngineByteWindow(payload, 0, payload.size)
    }
}

/// Parses one complete H2 frame wire into a bounded header + payload snapshot.
///
/// This helper requires exactly one complete frame and does not claim
/// concatenated-wire ownership or higher-level H2 semantics.
public func parseJinguiAcceptedTransportH2FrameWire(
    encodedWire: Array<Byte>
): JinguiAcceptedTransportH2FrameWireSnapshot {
    if (encodedWire.size < 9) {
        throw Exception(
            "H2 frame wire truncated before full header, remaining=${encodedWire.size}"
        )
    }
    let payloadLen =
        (Int64(UInt8(encodedWire[0])) << 16) +
        (Int64(UInt8(encodedWire[1])) << 8) +
        Int64(UInt8(encodedWire[2]))
    let frameSize = Int64(9) + payloadLen
    if (encodedWire.size < frameSize) {
        throw Exception(
            "H2 frame wire truncated before full payload, frameSize=${frameSize}, remaining=${encodedWire.size}"
        )
    }
    if (encodedWire.size > frameSize) {
        throw Exception(
            "H2 frame wire contains trailing bytes after one complete frame, frameSize=${frameSize}, total=${encodedWire.size}"
        )
    }
    let streamId =
        ((Int64(UInt8(encodedWire[5])) & 0x7f) << 24) +
        (Int64(UInt8(encodedWire[6])) << 16) +
        (Int64(UInt8(encodedWire[7])) << 8) +
        Int64(UInt8(encodedWire[8]))
    JinguiAcceptedTransportH2FrameWireSnapshot(
        payloadLen,
        UInt8(encodedWire[3]),
        UInt8(encodedWire[4]),
        streamId,
        cloneServerEngineByteWindow(encodedWire, 9, payloadLen)
    )
}

/// Splits complete concatenated H2 frame wire into individual frame slices.
///
/// This helper only restores complete frame boundaries from already-buffered
/// bytes. It does not claim incremental parser ownership or runtime ownership.
public func splitJinguiAcceptedTransportH2FrameWire(
    encodedWire: Array<Byte>
): Array<Array<Byte>> {
    let out = ArrayList<Array<Byte>>()
    var cursor: Int64 = 0
    while (cursor < encodedWire.size) {
        let remaining = encodedWire.size - cursor
        if (remaining < 9) {
            throw Exception(
                "H2 frame wire truncated before full header at offset=${cursor}, remaining=${remaining}"
            )
        }
        let payloadLen =
            (Int64(UInt8(encodedWire[cursor])) << 16) +
            (Int64(UInt8(encodedWire[cursor + 1])) << 8) +
            Int64(UInt8(encodedWire[cursor + 2]))
        let frameSize = Int64(9) + payloadLen
        if (remaining < frameSize) {
            throw Exception(
                "H2 frame wire truncated before full payload at offset=${cursor}, frameSize=${frameSize}, remaining=${remaining}"
            )
        }
        out.add(
            cloneServerEngineByteWindow(
                encodedWire,
                cursor,
                frameSize
            )
        )
        cursor += frameSize
    }
    out.toArray()
}

/// Incrementally accumulates fragmented H2 frame wire until one or more
/// complete frames are available.
///
/// This helper restores only complete frame boundaries from fragmented bytes
/// and does not claim live socket ownership, flow-control, or generic H2
/// incremental parser semantics.
public class JinguiAcceptedTransportH2FrameWireAccumulator {
    var _buffer = ArrayList<Byte>()
    var _readCursor: Int64 = 0

    public init() {}

    public func append(fragment: Array<Byte>): Unit {
        if (fragment.size == 0) {
            return
        }
        for (b in fragment) {
            _buffer.add(b)
        }
    }

    public func drainCompleteFrames(): Array<Array<Byte>> {
        let out = ArrayList<Array<Byte>>()
        while (true) {
            let remaining = bufferedByteCount()
            if (remaining < 9) {
                break
            }
            let payloadLen =
                (Int64(UInt8(_buffer[_readCursor])) << 16) +
                (Int64(UInt8(_buffer[_readCursor + 1])) << 8) +
                Int64(UInt8(_buffer[_readCursor + 2]))
            let frameSize = Int64(9) + payloadLen
            if (remaining < frameSize) {
                break
            }
            out.add(
                cloneServerEngineByteListWindow(
                    _buffer,
                    _readCursor,
                    frameSize
                )
            )
            _readCursor += frameSize
        }
        compactBuffer()
        out.toArray()
    }

    public func bufferedByteCount(): Int64 {
        _buffer.size - _readCursor
    }

    func compactBuffer(): Unit {
        if (_readCursor <= 0) {
            return
        }
        if (_readCursor >= _buffer.size) {
            _buffer = ArrayList<Byte>()
            _readCursor = 0
            return
        }
        let next = ArrayList<Byte>()
        var i = _readCursor
        while (i < _buffer.size) {
            next.add(_buffer[i])
            i += 1
        }
        _buffer = next
        _readCursor = 0
    }
}

public class JinguiAcceptedTransportH2HeaderBlockFragmentSnapshot {
    public let frameType: UInt8
    public let streamId: Int64
    public let endHeaders: Bool
    public let endStream: Bool
    public let padded: Bool
    public let padLength: Int64
    public let priorityPresented: Bool
    public let exclusiveDependency: Bool
    public let streamDependency: Int64
    public let weight: Int64
    public let headerBlockFragment: Array<Byte>

    public init(
        frameType: UInt8,
        streamId: Int64,
        endHeaders: Bool,
        endStream: Bool,
        padded: Bool,
        padLength: Int64,
        priorityPresented: Bool,
        exclusiveDependency: Bool,
        streamDependency: Int64,
        weight: Int64,
        headerBlockFragment: Array<Byte>
    ) {
        this.frameType = frameType
        this.streamId = streamId
        this.endHeaders = endHeaders
        this.endStream = endStream
        this.padded = padded
        this.padLength = padLength
        this.priorityPresented = priorityPresented
        this.exclusiveDependency = exclusiveDependency
        this.streamDependency = streamDependency
        this.weight = weight
        this.headerBlockFragment =
            cloneServerEngineByteWindow(
                headerBlockFragment,
                0,
                headerBlockFragment.size
            )
    }
}

public class JinguiAcceptedTransportH2HeaderBlockSnapshot {
    public let streamId: Int64
    public let endStream: Bool
    public let padded: Bool
    public let priorityPresented: Bool
    public let exclusiveDependency: Bool
    public let streamDependency: Int64
    public let weight: Int64
    public let headerBlockFragment: Array<Byte>

    public init(
        streamId: Int64,
        endStream: Bool,
        padded: Bool,
        priorityPresented: Bool,
        exclusiveDependency: Bool,
        streamDependency: Int64,
        weight: Int64,
        headerBlockFragment: Array<Byte>
    ) {
        this.streamId = streamId
        this.endStream = endStream
        this.padded = padded
        this.priorityPresented = priorityPresented
        this.exclusiveDependency = exclusiveDependency
        this.streamDependency = streamDependency
        this.weight = weight
        this.headerBlockFragment =
            cloneServerEngineByteWindow(
                headerBlockFragment,
                0,
                headerBlockFragment.size
            )
    }
}

func serverJinguiAcceptedTransportH2HasFlag(
    flags: UInt8,
    mask: UInt8
): Bool {
    (Int64(flags) & Int64(mask)) != 0
}

public func parseJinguiAcceptedTransportH2HeaderBlockFragment(
    frame: JinguiAcceptedTransportH2FrameWireSnapshot
): JinguiAcceptedTransportH2HeaderBlockFragmentSnapshot {
    let isHeaders = frame.frameType == UInt8(0x1)
    let isContinuation = frame.frameType == UInt8(0x9)
    if (!isHeaders && !isContinuation) {
        throw Exception(
            "H2 header-block fragment requires HEADERS or CONTINUATION frame, got type=${Int64(frame.frameType)}"
        )
    }

    let endHeaders =
        serverJinguiAcceptedTransportH2HasFlag(
            frame.flags,
            UInt8(0x4)
        )
    let endStream = isHeaders &&
        serverJinguiAcceptedTransportH2HasFlag(
            frame.flags,
            UInt8(0x1)
        )
    let padded = isHeaders &&
        serverJinguiAcceptedTransportH2HasFlag(
            frame.flags,
            UInt8(0x8)
        )
    let priorityPresented = isHeaders &&
        serverJinguiAcceptedTransportH2HasFlag(
            frame.flags,
            UInt8(0x20)
        )

    var cursor: Int64 = 0
    var padLength: Int64 = 0
    if (padded) {
        if (frame.payload.size < 1) {
            throw Exception(
                "H2 HEADERS payload truncated before pad length, streamId=${frame.streamId}"
            )
        }
        padLength = Int64(UInt8(frame.payload[0]))
        cursor += 1
    }

    var exclusiveDependency = false
    var streamDependency: Int64 = 0
    var weight: Int64 = 0
    if (priorityPresented) {
        if (frame.payload.size - cursor < 5) {
            throw Exception(
                "H2 HEADERS payload truncated before priority fields, streamId=${frame.streamId}"
            )
        }
        exclusiveDependency =
            (Int64(UInt8(frame.payload[cursor])) & 0x80) != 0
        streamDependency =
            ((Int64(UInt8(frame.payload[cursor])) & 0x7f) << 24) +
            (Int64(UInt8(frame.payload[cursor + 1])) << 16) +
            (Int64(UInt8(frame.payload[cursor + 2])) << 8) +
            Int64(UInt8(frame.payload[cursor + 3]))
        weight = Int64(UInt8(frame.payload[cursor + 4]))
        cursor += 5
    }

    let remaining = frame.payload.size - cursor
    if (remaining < padLength) {
        throw Exception(
            "H2 header-block payload padding exceeds remaining bytes, streamId=${frame.streamId}, remaining=${remaining}, padLength=${padLength}"
        )
    }
    let fragmentSize = remaining - padLength

    JinguiAcceptedTransportH2HeaderBlockFragmentSnapshot(
        frame.frameType,
        frame.streamId,
        endHeaders,
        endStream,
        padded,
        padLength,
        priorityPresented,
        exclusiveDependency,
        streamDependency,
        weight,
        cloneServerEngineByteWindow(
            frame.payload,
            cursor,
            fragmentSize
        )
    )
}

public class JinguiAcceptedTransportH2HeaderBlockAccumulator {
    let _ready = ArrayList<JinguiAcceptedTransportH2HeaderBlockSnapshot>()
    var _open: Bool = false
    var _openStreamId: Int64 = 0
    var _openEndStream: Bool = false
    var _openPadded: Bool = false
    var _openPriorityPresented: Bool = false
    var _openExclusiveDependency: Bool = false
    var _openStreamDependency: Int64 = 0
    var _openWeight: Int64 = 0
    var _openHeaderBlock = ArrayList<Byte>()

    public init() {}

    public func append(
        frame: JinguiAcceptedTransportH2FrameWireSnapshot
    ): Unit {
        if (!_open) {
            if (frame.frameType != UInt8(0x1)) {
                throw Exception(
                    "H2 header-block accumulator expects HEADERS frame first, got type=${Int64(frame.frameType)}"
                )
            }
        } else {
            if (frame.frameType != UInt8(0x9)) {
                throw Exception(
                    "H2 header-block accumulator expects CONTINUATION while one header block is open, got type=${Int64(frame.frameType)}"
                )
            }
            if (frame.streamId != _openStreamId) {
                throw Exception(
                    "H2 CONTINUATION streamId must match open header block streamId=${_openStreamId}, got=${frame.streamId}"
                )
            }
        }
        let fragment = parseJinguiAcceptedTransportH2HeaderBlockFragment(frame)
        if (!_open) {
            _open = true
            _openStreamId = fragment.streamId
            _openEndStream = fragment.endStream
            _openPadded = fragment.padded
            _openPriorityPresented = fragment.priorityPresented
            _openExclusiveDependency = fragment.exclusiveDependency
            _openStreamDependency = fragment.streamDependency
            _openWeight = fragment.weight
            _openHeaderBlock = ArrayList<Byte>()
            appendJinguiAcceptedTransportH2HeaderBlockBytes(
                _openHeaderBlock,
                fragment.headerBlockFragment
            )
            if (fragment.endHeaders) {
                sealOpenHeaderBlock()
            }
            return
        }
        appendJinguiAcceptedTransportH2HeaderBlockBytes(
            _openHeaderBlock,
            fragment.headerBlockFragment
        )
        if (fragment.endHeaders) {
            sealOpenHeaderBlock()
        }
    }

    public func drainCompleteHeaderBlocks(
    ): Array<JinguiAcceptedTransportH2HeaderBlockSnapshot> {
        let out = _ready.toArray()
        _ready.clear()
        out
    }

    public func hasOpenHeaderBlock(): Bool {
        _open
    }

    public func bufferedHeaderBlockByteCount(): Int64 {
        _openHeaderBlock.size
    }

    func sealOpenHeaderBlock(): Unit {
        _ready.add(
            JinguiAcceptedTransportH2HeaderBlockSnapshot(
                _openStreamId,
                _openEndStream,
                _openPadded,
                _openPriorityPresented,
                _openExclusiveDependency,
                _openStreamDependency,
                _openWeight,
                _openHeaderBlock.toArray()
            )
        )
        _open = false
        _openStreamId = 0
        _openEndStream = false
        _openPadded = false
        _openPriorityPresented = false
        _openExclusiveDependency = false
        _openStreamDependency = 0
        _openWeight = 0
        _openHeaderBlock = ArrayList<Byte>()
    }
}

/// Chains fragmented live H2 wire into assembled HEADERS/CONTINUATION-only
/// header blocks.
///
/// This helper intentionally stays narrow: it reuses the existing frame-wire
/// accumulator plus header-block accumulator, and it does not claim DATA/body
/// frame ownership, generic frame dispatch, or runtime lifecycle ownership.
public class JinguiAcceptedTransportH2HeaderBlockIngressAccumulator {
    let _frameAccumulator = JinguiAcceptedTransportH2FrameWireAccumulator()
    let _headerBlockAccumulator = JinguiAcceptedTransportH2HeaderBlockAccumulator()

    public init() {}

    public func append(fragment: Array<Byte>): Unit {
        _frameAccumulator.append(fragment)
        for (frameWire in _frameAccumulator.drainCompleteFrames()) {
            _headerBlockAccumulator.append(
                parseJinguiAcceptedTransportH2FrameWire(frameWire)
            )
        }
    }

    public func drainCompleteHeaderBlocks(
    ): Array<JinguiAcceptedTransportH2HeaderBlockSnapshot> {
        _headerBlockAccumulator.drainCompleteHeaderBlocks()
    }

    public func bufferedByteCount(): Int64 {
        _frameAccumulator.bufferedByteCount()
    }

    public func hasOpenHeaderBlock(): Bool {
        _headerBlockAccumulator.hasOpenHeaderBlock()
    }

    public func bufferedHeaderBlockByteCount(): Int64 {
        _headerBlockAccumulator.bufferedHeaderBlockByteCount()
    }
}

/// Incrementally accumulates fragmented accepted-session TLS record wire,
/// opens complete application-data records, and drains assembled H2 header
/// blocks.
///
/// This helper intentionally stays bounded: it restores complete TLS record
/// boundaries, reuses the existing plaintext H2 header-block ingress
/// accumulator, and does not claim socket-read ownership, DATA/body frame
/// ownership, generic H2 multiplexing, flow-control, stream lifecycle, or
/// runtime closure.
public class JinguiAcceptedTransportApplicationDataH2HeaderBlockIngressAccumulator {
    let _session: ContractHttpServerAcceptedTransportSession
    let _recordAccumulator = JinguiAcceptedTransportRecordWireAccumulator()
    let _headerBlockIngressAccumulator =
        JinguiAcceptedTransportH2HeaderBlockIngressAccumulator()

    public init(session: ContractHttpServerAcceptedTransportSession) {
        ensureServerJinguiAcceptedTransportSessionCodecReady(session)
        _session = session
    }

    public func append(fragment: Array<Byte>): Unit {
        ensureServerJinguiAcceptedTransportSessionCodecReady(_session)
        _recordAccumulator.append(fragment)
        for (encodedRecord in _recordAccumulator.drainCompleteRecords()) {
            _headerBlockIngressAccumulator.append(
                _session.recordChannel.openApplicationData(encodedRecord)
            )
        }
    }

    public func drainCompleteHeaderBlocks(
    ): Array<JinguiAcceptedTransportH2HeaderBlockSnapshot> {
        _headerBlockIngressAccumulator.drainCompleteHeaderBlocks()
    }

    public func bufferedRecordWireByteCount(): Int64 {
        _recordAccumulator.bufferedByteCount()
    }

    public func bufferedH2FrameWireByteCount(): Int64 {
        _headerBlockIngressAccumulator.bufferedByteCount()
    }

    public func hasOpenHeaderBlock(): Bool {
        _headerBlockIngressAccumulator.hasOpenHeaderBlock()
    }

    public func bufferedHeaderBlockByteCount(): Int64 {
        _headerBlockIngressAccumulator.bufferedHeaderBlockByteCount()
    }
}

/// Incrementally accumulates fragmented accepted-session TLS record wire and
/// drains at most one logical request from one complete H2 header block.
///
/// This helper intentionally stays one-request-bounded: it reuses the
/// accepted-session fragmented-record-wire header-block ingress seam plus the
/// existing header-block logical-request projection, and it does not claim
/// socket-read ownership, DATA/body frame ownership, generic H2 multiplexing,
/// flow-control, stream lifecycle, or runtime closure.
public class JinguiAcceptedTransportApplicationDataH2HeaderBlockLogicalRequestAccumulator {
    let _headerBlockIngressAccumulator:
        JinguiAcceptedTransportApplicationDataH2HeaderBlockIngressAccumulator
    let _bodyBytes: Array<UInt8>
    let _ready = ArrayList<ServerJinguiAcceptedTransportLogicalRequest>()
    var _sealedLogicalRequest = false

    public init(
        session: ContractHttpServerAcceptedTransportSession,
        bodyBytes!: Array<UInt8> = []
    ) {
        _headerBlockIngressAccumulator =
            JinguiAcceptedTransportApplicationDataH2HeaderBlockIngressAccumulator(
                session
            )
        _bodyBytes = cloneServerEngineUInt8Array(bodyBytes)
    }

    public func append(fragment: Array<Byte>): Unit {
        _headerBlockIngressAccumulator.append(fragment)
        let completedHeaderBlocks =
            _headerBlockIngressAccumulator.drainCompleteHeaderBlocks()
        if (completedHeaderBlocks.size == 0) {
            return
        }
        let projectedCount = completedHeaderBlocks.size + if (_sealedLogicalRequest) {
            1
        } else {
            0
        }
        if (projectedCount > 1) {
            throw Exception(
                "accepted-session fragmented-record-wire logical-request projection expects exactly one complete H2 header block while the packet stays one-request-bounded, got count=${projectedCount}"
            )
        }
        _ready.add(
            buildServerJinguiAcceptedTransportLogicalRequestFromH2HeaderBlock(
                completedHeaderBlocks[0],
                bodyBytes: _bodyBytes
            )
        )
        _sealedLogicalRequest = true
    }

    public func drainCompleteLogicalRequests(
    ): Array<ServerJinguiAcceptedTransportLogicalRequest> {
        if (_ready.size == 0) {
            return []
        }
        let out = _ready.toArray()
        _ready.clear()
        out
    }

    public func bufferedRecordWireByteCount(): Int64 {
        _headerBlockIngressAccumulator.bufferedRecordWireByteCount()
    }

    public func bufferedH2FrameWireByteCount(): Int64 {
        _headerBlockIngressAccumulator.bufferedH2FrameWireByteCount()
    }

    public func hasOpenHeaderBlock(): Bool {
        _headerBlockIngressAccumulator.hasOpenHeaderBlock()
    }

    public func bufferedHeaderBlockByteCount(): Int64 {
        _headerBlockIngressAccumulator.bufferedHeaderBlockByteCount()
    }
}

/// Incrementally accumulates fragmented accepted-session TLS record wire and
/// drains at most one logical request from one complete H2 header block plus
/// same-stream DATA frames terminated by END_STREAM.
///
/// This helper intentionally stays one-request-bounded: it restores complete
/// TLS record boundaries, reuses the existing H2 frame wire accumulator plus
/// header-block accumulator plus request projection seam, and it does not
/// claim socket-read ownership, generic H2 multiplexing, flow-control, stream
/// lifecycle, or runtime closure.
public class JinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestAccumulator {
    let _session: ContractHttpServerAcceptedTransportSession
    let _recordAccumulator = JinguiAcceptedTransportRecordWireAccumulator()
    let _frameAccumulator = JinguiAcceptedTransportH2FrameWireAccumulator()
    let _headerBlockAccumulator = JinguiAcceptedTransportH2HeaderBlockAccumulator()
    let _ready = ArrayList<ServerJinguiAcceptedTransportLogicalRequest>()
    var _sealedLogicalRequest = false
    var _completedHeaderBlock: ?JinguiAcceptedTransportH2HeaderBlockSnapshot = None
    var _bodyBytes = ArrayList<Byte>()

    public init(session: ContractHttpServerAcceptedTransportSession) {
        ensureServerJinguiAcceptedTransportSessionCodecReady(session)
        _session = session
    }

    public func append(fragment: Array<Byte>): Unit {
        ensureServerJinguiAcceptedTransportSessionCodecReady(_session)
        _recordAccumulator.append(fragment)
        for (encodedRecord in _recordAccumulator.drainCompleteRecords()) {
            _frameAccumulator.append(
                _session.recordChannel.openApplicationData(encodedRecord)
            )
            for (frameWire in _frameAccumulator.drainCompleteFrames()) {
                appendParsedFrame(
                    parseJinguiAcceptedTransportH2FrameWire(frameWire)
                )
            }
        }
    }

    public func drainCompleteLogicalRequests(
    ): Array<ServerJinguiAcceptedTransportLogicalRequest> {
        if (_ready.size == 0) {
            return []
        }
        let out = _ready.toArray()
        _ready.clear()
        out
    }

    public func bufferedRecordWireByteCount(): Int64 {
        _recordAccumulator.bufferedByteCount()
    }

    public func bufferedH2FrameWireByteCount(): Int64 {
        _frameAccumulator.bufferedByteCount()
    }

    public func hasOpenHeaderBlock(): Bool {
        _headerBlockAccumulator.hasOpenHeaderBlock()
    }

    public func bufferedHeaderBlockByteCount(): Int64 {
        _headerBlockAccumulator.bufferedHeaderBlockByteCount()
    }

    public func bufferedBodyByteCount(): Int64 {
        _bodyBytes.size
    }

    func appendParsedFrame(frame: JinguiAcceptedTransportH2FrameWireSnapshot): Unit {
        if (_sealedLogicalRequest) {
            throw Exception(
                "accepted-session fragmented-record-wire headers-plus-data logical-request projection stays one-request-bounded and rejects additional H2 frames after one logical request, got type=${Int64(frame.frameType)}, streamId=${frame.streamId}"
            )
        }
        match (_completedHeaderBlock) {
            case None =>
                _headerBlockAccumulator.append(frame)
            case Some(headerBlock) =>
                appendBodyFrame(
                    headerBlock,
                    frame
                )
        }
        let completedHeaderBlocks =
            _headerBlockAccumulator.drainCompleteHeaderBlocks()
        if (completedHeaderBlocks.size == 0) {
            return
        }
        let projectedCount = completedHeaderBlocks.size + match (_completedHeaderBlock) {
            case Some(_) => 1
            case None => 0
        }
        if (projectedCount > 1) {
            throw Exception(
                "accepted-session fragmented-record-wire headers-plus-data logical-request projection expects exactly one complete H2 header block before DATA accumulation while the packet stays one-request-bounded, got count=${projectedCount}"
            )
        }
        let headerBlock = completedHeaderBlocks[0]
        if (headerBlock.endStream) {
            throw Exception(
                "accepted-session fragmented-record-wire headers-plus-data logical-request projection expects at least one same-stream H2 DATA frame after one complete H2 header block"
            )
        }
        _completedHeaderBlock = Some(headerBlock)
    }

    func appendBodyFrame(
        headerBlock: JinguiAcceptedTransportH2HeaderBlockSnapshot,
        frame: JinguiAcceptedTransportH2FrameWireSnapshot
    ): Unit {
        if (frame.frameType != UInt8(0x0)) {
            throw Exception(
                "accepted-session fragmented-record-wire headers-plus-data logical-request projection stays inside one request boundary and only accepts same-stream DATA after one complete H2 header block, got type=${Int64(frame.frameType)}, streamId=${frame.streamId}"
            )
        }
        let dataFrame =
            parseJinguiAcceptedTransportH2DataFrame(frame)
        if (dataFrame.streamId != headerBlock.streamId) {
            throw Exception(
                "accepted-session fragmented-record-wire headers-plus-data logical-request projection requires same-stream DATA, headerStreamId=${headerBlock.streamId}, dataStreamId=${dataFrame.streamId}"
            )
        }
        for (b in dataFrame.dataBytes) {
            _bodyBytes.add(b)
        }
        if (!dataFrame.endStream) {
            return
        }
        if (_bodyBytes.size == 0) {
            throw Exception(
                "accepted-session fragmented-record-wire headers-plus-data logical-request projection expects at least one same-stream H2 DATA frame after one complete H2 header block"
            )
        }
        _ready.add(
            buildServerJinguiAcceptedTransportLogicalRequestFromH2HeaderBlock(
                headerBlock,
                bodyBytes: serverEngineByteToUInt8Array(_bodyBytes.toArray())
            )
        )
        _sealedLogicalRequest = true
        _completedHeaderBlock = None
        _bodyBytes = ArrayList<Byte>()
    }
}

public class JinguiAcceptedTransportH2DataFrameSnapshot {
    public let streamId: Int64
    public let endStream: Bool
    public let padded: Bool
    public let padLength: Int64
    public let dataBytes: Array<Byte>

    public init(
        streamId: Int64,
        endStream: Bool,
        padded: Bool,
        padLength: Int64,
        dataBytes: Array<Byte>
    ) {
        this.streamId = streamId
        this.endStream = endStream
        this.padded = padded
        this.padLength = padLength
        this.dataBytes =
            cloneServerEngineByteWindow(
                dataBytes,
                0,
                dataBytes.size
            )
    }
}

public func parseJinguiAcceptedTransportH2DataFrame(
    frame: JinguiAcceptedTransportH2FrameWireSnapshot
): JinguiAcceptedTransportH2DataFrameSnapshot {
    if (frame.frameType != UInt8(0x0)) {
        throw Exception(
            "H2 DATA frame parse requires DATA frame type=0, got type=${Int64(frame.frameType)}"
        )
    }
    let endStream =
        serverJinguiAcceptedTransportH2HasFlag(
            frame.flags,
            UInt8(0x1)
        )
    let padded =
        serverJinguiAcceptedTransportH2HasFlag(
            frame.flags,
            UInt8(0x8)
        )
    var cursor: Int64 = 0
    var padLength: Int64 = 0
    if (padded) {
        if (frame.payload.size < 1) {
            throw Exception(
                "H2 DATA payload truncated before pad length, streamId=${frame.streamId}"
            )
        }
        padLength = Int64(UInt8(frame.payload[0]))
        cursor += 1
    }
    let remaining = frame.payload.size - cursor
    if (remaining < padLength) {
        throw Exception(
            "H2 DATA payload padding exceeds remaining bytes, streamId=${frame.streamId}, remaining=${remaining}, padLength=${padLength}"
        )
    }
    let dataSize = remaining - padLength
    JinguiAcceptedTransportH2DataFrameSnapshot(
        frame.streamId,
        endStream,
        padded,
        padLength,
        cloneServerEngineByteWindow(
            frame.payload,
            cursor,
            dataSize
        )
    )
}

func appendJinguiAcceptedTransportH2HeaderBlockBytes(
    out: ArrayList<Byte>,
    bytes: Array<Byte>
): Unit {
    for (b in bytes) {
        out.add(b)
    }
}

public class JinguiAcceptedTransportH2DecodedHeaderField {
    public let name: String
    public let value: String
    public let representationKind: String
    public let staticIndex: Int64
    public let nameStaticIndex: Int64

    public init(
        name: String,
        value: String,
        representationKind: String,
        staticIndex: Int64,
        nameStaticIndex: Int64
    ) {
        this.name = name
        this.value = value
        this.representationKind = representationKind
        this.staticIndex = staticIndex
        this.nameStaticIndex = nameStaticIndex
    }
}

class ServerJinguiAcceptedTransportH2StaticHeaderField {
    let name: String
    let value: String

    init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

class ServerJinguiAcceptedTransportH2HpackIntegerDecodeResult {
    let value: Int64
    let nextCursor: Int64

    init(value: Int64, nextCursor: Int64) {
        this.value = value
        this.nextCursor = nextCursor
    }
}

class ServerJinguiAcceptedTransportH2HpackStringDecodeResult {
    let text: String
    let nextCursor: Int64

    init(text: String, nextCursor: Int64) {
        this.text = text
        this.nextCursor = nextCursor
    }
}

class ServerJinguiAcceptedTransportH2DecodedHeaderFieldParseResult {
    let field: JinguiAcceptedTransportH2DecodedHeaderField
    let nextCursor: Int64

    init(
        field: JinguiAcceptedTransportH2DecodedHeaderField,
        nextCursor: Int64
    ) {
        this.field = field
        this.nextCursor = nextCursor
    }
}

public func parseJinguiAcceptedTransportH2HeaderFields(
    headerBlock: JinguiAcceptedTransportH2HeaderBlockSnapshot
): Array<JinguiAcceptedTransportH2DecodedHeaderField> {
    parseJinguiAcceptedTransportH2HeaderFieldsFromBytes(
        headerBlock.headerBlockFragment
    )
}

func parseJinguiAcceptedTransportH2HeaderFieldsFromBytes(
    headerBlockFragment: Array<Byte>
): Array<JinguiAcceptedTransportH2DecodedHeaderField> {
    let out = ArrayList<JinguiAcceptedTransportH2DecodedHeaderField>()
    var cursor: Int64 = 0
    while (cursor < headerBlockFragment.size) {
        let lead = Int64(UInt8(headerBlockFragment[cursor]))
        if ((lead & 0x80) != 0) {
            let indexed =
                decodeServerJinguiAcceptedTransportH2HpackInteger(
                    headerBlockFragment,
                    cursor,
                    7
                )
            if (indexed.value <= 0) {
                throw Exception(
                    "H2 HPACK indexed header field requires static index >= 1, got index=${indexed.value}"
                )
            }
            let entry =
                serverJinguiAcceptedTransportH2StaticHeaderFieldByIndex(
                    indexed.value
                )
            out.add(
                JinguiAcceptedTransportH2DecodedHeaderField(
                    entry.name,
                    entry.value,
                    "indexed",
                    indexed.value,
                    indexed.value
                )
            )
            cursor = indexed.nextCursor
            continue
        }
        if ((lead & 0x40) != 0) {
            let decoded =
                parseServerJinguiAcceptedTransportH2LiteralHeaderField(
                    headerBlockFragment,
                    cursor,
                    6,
                    "literal-with-indexing"
                )
            out.add(decoded.field)
            cursor = decoded.nextCursor
            continue
        }
        if ((lead & 0x20) != 0) {
            throw Exception(
                "H2 HPACK dynamic table size update is unsupported in this bounded seam at offset=${cursor}"
            )
        }
        let representationKind =
            if ((lead & 0x10) != 0) {
                "literal-never-indexed"
            } else {
                "literal-without-indexing"
            }
        let decoded =
            parseServerJinguiAcceptedTransportH2LiteralHeaderField(
                headerBlockFragment,
                cursor,
                4,
                representationKind
            )
        out.add(decoded.field)
        cursor = decoded.nextCursor
    }
    out.toArray()
}

func parseServerJinguiAcceptedTransportH2LiteralHeaderField(
    headerBlockFragment: Array<Byte>,
    cursor: Int64,
    prefixBits: Int64,
    representationKind: String
): ServerJinguiAcceptedTransportH2DecodedHeaderFieldParseResult {
    let nameIndex =
        decodeServerJinguiAcceptedTransportH2HpackInteger(
            headerBlockFragment,
            cursor,
            prefixBits
        )
    var nextCursor = nameIndex.nextCursor
    var name = ""
    var nameStaticIndex: Int64 = 0
    if (nameIndex.value == 0) {
        let decodedName =
            decodeServerJinguiAcceptedTransportH2HpackString(
                headerBlockFragment,
                nextCursor
            )
        name = decodedName.text
        nextCursor = decodedName.nextCursor
    } else {
        let entry =
            serverJinguiAcceptedTransportH2StaticHeaderFieldByIndex(
                nameIndex.value
            )
        name = entry.name
        nameStaticIndex = nameIndex.value
    }
    let decodedValue =
        decodeServerJinguiAcceptedTransportH2HpackString(
            headerBlockFragment,
            nextCursor
        )
    ServerJinguiAcceptedTransportH2DecodedHeaderFieldParseResult(
        JinguiAcceptedTransportH2DecodedHeaderField(
            name,
            decodedValue.text,
            representationKind,
            0,
            nameStaticIndex
        ),
        decodedValue.nextCursor
    )
}

func decodeServerJinguiAcceptedTransportH2HpackInteger(
    bytes: Array<Byte>,
    cursor: Int64,
    prefixBits: Int64
): ServerJinguiAcceptedTransportH2HpackIntegerDecodeResult {
    if (cursor >= bytes.size) {
        throw Exception(
            "H2 HPACK integer decode cursor is out of range, cursor=${cursor}, size=${bytes.size}"
        )
    }
    let prefixMask =
        serverJinguiAcceptedTransportH2HpackPrefixMask(prefixBits)
    var value =
        Int64(UInt8(bytes[cursor])) & prefixMask
    var nextCursor = cursor + 1
    if (value < prefixMask) {
        return ServerJinguiAcceptedTransportH2HpackIntegerDecodeResult(
            value,
            nextCursor
        )
    }
    var multiplier: Int64 = 0
    while (true) {
        if (nextCursor >= bytes.size) {
            throw Exception(
                "H2 HPACK integer decode truncated after prefix saturation at offset=${cursor}"
            )
        }
        let octet = Int64(UInt8(bytes[nextCursor]))
        value += (octet & 0x7f) << multiplier
        nextCursor += 1
        if ((octet & 0x80) == 0) {
            break
        }
        multiplier += 7
        if (multiplier > 56) {
            throw Exception(
                "H2 HPACK integer decode exceeded bounded Int64 range at offset=${cursor}"
            )
        }
    }
    ServerJinguiAcceptedTransportH2HpackIntegerDecodeResult(
        value,
        nextCursor
    )
}

func decodeServerJinguiAcceptedTransportH2HpackString(
    bytes: Array<Byte>,
    cursor: Int64
): ServerJinguiAcceptedTransportH2HpackStringDecodeResult {
    if (cursor >= bytes.size) {
        throw Exception(
            "H2 HPACK string decode cursor is out of range, cursor=${cursor}, size=${bytes.size}"
        )
    }
    let huffman =
        (Int64(UInt8(bytes[cursor])) & 0x80) != 0
    if (huffman) {
        throw Exception(
            "H2 HPACK Huffman string is unsupported in this bounded seam at offset=${cursor}"
        )
    }
    let lengthResult =
        decodeServerJinguiAcceptedTransportH2HpackInteger(
            bytes,
            cursor,
            7
        )
    let remaining = bytes.size - lengthResult.nextCursor
    if (remaining < lengthResult.value) {
        throw Exception(
            "H2 HPACK string payload truncated, offset=${cursor}, remaining=${remaining}, expected=${lengthResult.value}"
        )
    }
    let raw =
        cloneServerEngineByteWindow(
            bytes,
            lengthResult.nextCursor,
            lengthResult.value
        )
    let utf8 = Array<UInt8>(raw.size, repeat: 0)
    var i: Int64 = 0
    while (i < raw.size) {
        utf8[i] = UInt8(raw[i])
        i += 1
    }
    ServerJinguiAcceptedTransportH2HpackStringDecodeResult(
        String.fromUtf8(utf8),
        lengthResult.nextCursor + lengthResult.value
    )
}

func serverJinguiAcceptedTransportH2HpackPrefixMask(
    prefixBits: Int64
): Int64 {
    if (prefixBits == 4) {
        return 0x0f
    }
    if (prefixBits == 5) {
        return 0x1f
    }
    if (prefixBits == 6) {
        return 0x3f
    }
    if (prefixBits == 7) {
        return 0x7f
    }
    throw Exception(
        "unsupported H2 HPACK prefix bits=${prefixBits}"
    )
}

func serverJinguiAcceptedTransportH2StaticHeaderFieldByIndex(
    index: Int64
): ServerJinguiAcceptedTransportH2StaticHeaderField {
    if (index == 1) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":authority", "") }
    if (index == 2) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":method", "GET") }
    if (index == 3) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":method", "POST") }
    if (index == 4) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":path", "/") }
    if (index == 5) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":path", "/index.html") }
    if (index == 6) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":scheme", "http") }
    if (index == 7) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":scheme", "https") }
    if (index == 8) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":status", "200") }
    if (index == 9) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":status", "204") }
    if (index == 10) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":status", "206") }
    if (index == 11) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":status", "304") }
    if (index == 12) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":status", "400") }
    if (index == 13) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":status", "404") }
    if (index == 14) { return ServerJinguiAcceptedTransportH2StaticHeaderField(":status", "500") }
    if (index == 15) { return ServerJinguiAcceptedTransportH2StaticHeaderField("accept-charset", "") }
    if (index == 16) { return ServerJinguiAcceptedTransportH2StaticHeaderField("accept-encoding", "gzip, deflate") }
    if (index == 17) { return ServerJinguiAcceptedTransportH2StaticHeaderField("accept-language", "") }
    if (index == 18) { return ServerJinguiAcceptedTransportH2StaticHeaderField("accept-ranges", "") }
    if (index == 19) { return ServerJinguiAcceptedTransportH2StaticHeaderField("accept", "") }
    if (index == 20) { return ServerJinguiAcceptedTransportH2StaticHeaderField("access-control-allow-origin", "") }
    if (index == 21) { return ServerJinguiAcceptedTransportH2StaticHeaderField("age", "") }
    if (index == 22) { return ServerJinguiAcceptedTransportH2StaticHeaderField("allow", "") }
    if (index == 23) { return ServerJinguiAcceptedTransportH2StaticHeaderField("authorization", "") }
    if (index == 24) { return ServerJinguiAcceptedTransportH2StaticHeaderField("cache-control", "") }
    if (index == 25) { return ServerJinguiAcceptedTransportH2StaticHeaderField("content-disposition", "") }
    if (index == 26) { return ServerJinguiAcceptedTransportH2StaticHeaderField("content-encoding", "") }
    if (index == 27) { return ServerJinguiAcceptedTransportH2StaticHeaderField("content-language", "") }
    if (index == 28) { return ServerJinguiAcceptedTransportH2StaticHeaderField("content-length", "") }
    if (index == 29) { return ServerJinguiAcceptedTransportH2StaticHeaderField("content-location", "") }
    if (index == 30) { return ServerJinguiAcceptedTransportH2StaticHeaderField("content-range", "") }
    if (index == 31) { return ServerJinguiAcceptedTransportH2StaticHeaderField("content-type", "") }
    if (index == 32) { return ServerJinguiAcceptedTransportH2StaticHeaderField("cookie", "") }
    if (index == 33) { return ServerJinguiAcceptedTransportH2StaticHeaderField("date", "") }
    if (index == 34) { return ServerJinguiAcceptedTransportH2StaticHeaderField("etag", "") }
    if (index == 35) { return ServerJinguiAcceptedTransportH2StaticHeaderField("expect", "") }
    if (index == 36) { return ServerJinguiAcceptedTransportH2StaticHeaderField("expires", "") }
    if (index == 37) { return ServerJinguiAcceptedTransportH2StaticHeaderField("from", "") }
    if (index == 38) { return ServerJinguiAcceptedTransportH2StaticHeaderField("host", "") }
    if (index == 39) { return ServerJinguiAcceptedTransportH2StaticHeaderField("if-match", "") }
    if (index == 40) { return ServerJinguiAcceptedTransportH2StaticHeaderField("if-modified-since", "") }
    if (index == 41) { return ServerJinguiAcceptedTransportH2StaticHeaderField("if-none-match", "") }
    if (index == 42) { return ServerJinguiAcceptedTransportH2StaticHeaderField("if-range", "") }
    if (index == 43) { return ServerJinguiAcceptedTransportH2StaticHeaderField("if-unmodified-since", "") }
    if (index == 44) { return ServerJinguiAcceptedTransportH2StaticHeaderField("last-modified", "") }
    if (index == 45) { return ServerJinguiAcceptedTransportH2StaticHeaderField("link", "") }
    if (index == 46) { return ServerJinguiAcceptedTransportH2StaticHeaderField("location", "") }
    if (index == 47) { return ServerJinguiAcceptedTransportH2StaticHeaderField("max-forwards", "") }
    if (index == 48) { return ServerJinguiAcceptedTransportH2StaticHeaderField("proxy-authenticate", "") }
    if (index == 49) { return ServerJinguiAcceptedTransportH2StaticHeaderField("proxy-authorization", "") }
    if (index == 50) { return ServerJinguiAcceptedTransportH2StaticHeaderField("range", "") }
    if (index == 51) { return ServerJinguiAcceptedTransportH2StaticHeaderField("referer", "") }
    if (index == 52) { return ServerJinguiAcceptedTransportH2StaticHeaderField("refresh", "") }
    if (index == 53) { return ServerJinguiAcceptedTransportH2StaticHeaderField("retry-after", "") }
    if (index == 54) { return ServerJinguiAcceptedTransportH2StaticHeaderField("server", "") }
    if (index == 55) { return ServerJinguiAcceptedTransportH2StaticHeaderField("set-cookie", "") }
    if (index == 56) { return ServerJinguiAcceptedTransportH2StaticHeaderField("strict-transport-security", "") }
    if (index == 57) { return ServerJinguiAcceptedTransportH2StaticHeaderField("transfer-encoding", "") }
    if (index == 58) { return ServerJinguiAcceptedTransportH2StaticHeaderField("user-agent", "") }
    if (index == 59) { return ServerJinguiAcceptedTransportH2StaticHeaderField("vary", "") }
    if (index == 60) { return ServerJinguiAcceptedTransportH2StaticHeaderField("via", "") }
    if (index == 61) { return ServerJinguiAcceptedTransportH2StaticHeaderField("www-authenticate", "") }
    throw Exception(
        "H2 HPACK static-only decode cannot resolve index=${index} without dynamic table support"
    )
}

func ensureServerJinguiAcceptedTransportSessionCodecReady(
    session: ContractHttpServerAcceptedTransportSession
): Unit {
    if (!session.secureSessionReady) {
        throw Exception(
            "accepted transport/session application-data codec requires secureSessionReady=true, got status=${session.status.toString()}"
        )
    }
}

func buildServerContractHttpServerAttachPlan(
    material: api2.PreparedHttpServerTlsMaterial
): ContractHttpServerAttachPlan {
    let requireHttp2Alpn = containsServerAlpnProtocol(
        material.normalizedAlpnProtocols,
        "h2"
    )
    contractPlanHttpServerAttachRequest(
        ContractHttpServerLibraryStartupRequest(
            ContractHttpServerTlsConfigRequest(
                material.certPem,
                material.keyPem,
                alpnProtocols: material.normalizedAlpnProtocols,
                requireHttp2Alpn: requireHttp2Alpn
            )
        )
    )
}

public class ServerTransportRoutingBundle {
    public let selectionRequest: api2.BackendSelectionRequest
    public let selectionDecision: api2.BackendSelectionDecision
    public let tlsAttachPlan: api2.TlsAttachPlan

    public init(
        selectionRequest: api2.BackendSelectionRequest,
        selectionDecision: api2.BackendSelectionDecision,
        tlsAttachPlan: api2.TlsAttachPlan
    ) {
        this.selectionRequest = selectionRequest
        this.selectionDecision = selectionDecision
        this.tlsAttachPlan = tlsAttachPlan
    }
}

public class ServerTlsIngressContext {
    public let transportRoutingBundle: ServerTransportRoutingBundle
    public let transportTouchpoint: ServerTransportTouchpoint
    public let preparedTlsMaterialLoader: ?ServerPreparedTlsMaterialLoader

    public init(
        transportRoutingBundle: ServerTransportRoutingBundle,
        transportTouchpoint: ServerTransportTouchpoint,
        preparedTlsMaterialLoader!: ?ServerPreparedTlsMaterialLoader = None
    ) {
        this.transportRoutingBundle = transportRoutingBundle
        this.transportTouchpoint = transportTouchpoint
        this.preparedTlsMaterialLoader = preparedTlsMaterialLoader
    }

    public func hasPreparedTlsMaterial(): Bool {
        if (let Some(_) <- preparedTlsMaterialLoader) {
            return true
        }
        false
    }

    public func loadPreparedTlsMaterial(): api2.PreparedHttpServerTlsMaterial {
        if (let Some(loader) <- preparedTlsMaterialLoader) {
            return loader()
        }
        throw Exception("prepared TLS material loader is unavailable")
    }

    public func loadJinguiHttpServerAttachPlanSnapshot(): ServerJinguiHttpServerAttachPlanSnapshot {
        let material = loadPreparedTlsMaterial()
        let plan = buildServerContractHttpServerAttachPlan(material)
        ServerJinguiHttpServerAttachPlanSnapshot(
            plan.planningGate.providerId,
            plan.attachSurface,
            plan.listenerOwned,
            plan.expectedTlsVersion.toString(),
            plan.expectedAlpnProtocols,
            plan.planningGate.status.toString(),
            plan.planningGate.readyNow,
            plan.planningGate.publicPath,
            plan.planningGate.releasePath,
            plan.planningGate.selectedReason,
            plan.planningGate.warnings,
            plan.stableAttachGate.status.toString(),
            plan.stableAttachGate.readyNow,
            plan.stableAttachGate.publicPath,
            plan.stableAttachGate.releasePath,
            plan.stableAttachGate.selectedReason,
            plan.stableAttachGate.blockedCandidates,
            plan.startup.material.validation.keyAlgorithm.toString()
        )
    }

    public func buildJinguiHttpServerAttachResultSnapshot(
        attachResult: ContractHttpServerAttachResult
    ): ServerJinguiHttpServerAttachResultSnapshot {
        buildServerJinguiHttpServerAttachResultSnapshot(attachResult)
    }

    public func buildJinguiAcceptedTransportTls13X25519Request(
        transport: ContractAcceptedTransportDescriptor,
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ContractHttpServerAcceptedTransportTls13X25519Request {
        let plan = buildServerContractHttpServerAttachPlan(loadPreparedTlsMaterial())
        ContractHttpServerAcceptedTransportTls13X25519Request(
            transport,
            plan,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
    }

    public func attachJinguiAcceptedTransportTls13X25519Request(
        request: ContractHttpServerAcceptedTransportTls13X25519Request
    ): ContractHttpServerAcceptedTransportSession {
        contractAttachAcceptedTransportTls13X25519Request(request)
    }

    public func attachJinguiAcceptedTransportTls13X25519(
        transport: ContractAcceptedTransportDescriptor,
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ContractHttpServerAcceptedTransportSession {
        contractAttachAcceptedTransportTls13X25519(
            transport,
            buildServerContractHttpServerAttachPlan(loadPreparedTlsMaterial()),
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
    }

    public func closeJinguiAcceptedTransportSession(
        session: ContractHttpServerAcceptedTransportSession,
        reason!: String = "close_notify"
    ): ContractHttpServerAcceptedTransportSession {
        contractCloseAcceptedTransportSession(session, reason: reason)
    }

    public func sealJinguiAcceptedTransportApplicationData(
        session: ContractHttpServerAcceptedTransportSession,
        plaintext: Array<Byte>
    ): Array<Byte> {
        ensureServerJinguiAcceptedTransportSessionCodecReady(session)
        session.recordChannel.sealApplicationData(plaintext)
    }

    public func openJinguiAcceptedTransportApplicationData(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecord: Array<Byte>
    ): Array<Byte> {
        ensureServerJinguiAcceptedTransportSessionCodecReady(session)
        session.recordChannel.openApplicationData(encodedRecord)
    }

    public func sealJinguiAcceptedTransportApplicationDataFragments(
        session: ContractHttpServerAcceptedTransportSession,
        plaintext: Array<Byte>,
        maxFragmentLen!: Int64 = 16384
    ): Array<Array<Byte>> {
        ensureServerJinguiAcceptedTransportSessionCodecReady(session)
        session.recordChannel.sealFragments(
            ContractTlsRecordContentType.ApplicationData,
            plaintext,
            maxFragmentLen: maxFragmentLen
        )
    }

    public func openAndReassembleJinguiAcceptedTransportApplicationData(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecords: Array<Array<Byte>>
    ): Array<Byte> {
        ensureServerJinguiAcceptedTransportSessionCodecReady(session)
        session.recordChannel.openAndReassemble(encodedRecords)
    }

    public func openAndIngressJinguiAcceptedTransportApplicationDataH2HeaderBlocks(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecords: Array<Array<Byte>>
    ): Array<JinguiAcceptedTransportH2HeaderBlockSnapshot> {
        let headerAccumulator = JinguiAcceptedTransportH2HeaderBlockAccumulator()
        for (
            frame in
                openAndParseJinguiAcceptedTransportApplicationDataH2FramesCore(
                    session,
                    encodedRecords
                )
        ) {
            headerAccumulator.append(frame)
        }
        headerAccumulator.drainCompleteHeaderBlocks()
    }

    public func buildJinguiAcceptedTransportApplicationDataH2HeaderBlockIngressAccumulator(
        session: ContractHttpServerAcceptedTransportSession
    ): JinguiAcceptedTransportApplicationDataH2HeaderBlockIngressAccumulator {
        JinguiAcceptedTransportApplicationDataH2HeaderBlockIngressAccumulator(
            session
        )
    }

    public func buildJinguiAcceptedTransportApplicationDataH2HeaderBlockLogicalRequestAccumulator(
        session: ContractHttpServerAcceptedTransportSession,
        bodyBytes!: Array<UInt8> = []
    ): JinguiAcceptedTransportApplicationDataH2HeaderBlockLogicalRequestAccumulator {
        JinguiAcceptedTransportApplicationDataH2HeaderBlockLogicalRequestAccumulator(
            session,
            bodyBytes: bodyBytes
        )
    }

    public func buildJinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestAccumulator(
        session: ContractHttpServerAcceptedTransportSession
    ): JinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestAccumulator {
        JinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestAccumulator(
            session
        )
    }

    func openAndParseJinguiAcceptedTransportApplicationDataH2FramesCore(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecords: Array<Array<Byte>>
    ): Array<JinguiAcceptedTransportH2FrameWireSnapshot> {
        let plaintext =
            openAndReassembleJinguiAcceptedTransportApplicationData(
                session,
                encodedRecords
            )
        let frames = ArrayList<JinguiAcceptedTransportH2FrameWireSnapshot>()
        for (frameWire in splitJinguiAcceptedTransportH2FrameWire(plaintext)) {
            frames.add(
                parseJinguiAcceptedTransportH2FrameWire(frameWire)
            )
        }
        frames.toArray()
    }

    func openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2LeadingHeaderBlockCore(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecords: Array<Array<Byte>>,
        missingHeaderBlockMessage: String,
        bodyBytesResolver: (
            JinguiAcceptedTransportH2HeaderBlockSnapshot,
            Array<JinguiAcceptedTransportH2FrameWireSnapshot>
        ) -> Array<UInt8>
    ): ServerJinguiAcceptedTransportLogicalRequest {
        let headerAccumulator = JinguiAcceptedTransportH2HeaderBlockAccumulator()
        var completedHeaderBlock: ?JinguiAcceptedTransportH2HeaderBlockSnapshot =
            None
        let tailFrames = ArrayList<JinguiAcceptedTransportH2FrameWireSnapshot>()
        for (
            frame in
                openAndParseJinguiAcceptedTransportApplicationDataH2FramesCore(
                    session,
                    encodedRecords
                )
        ) {
            if (let Some(_) <- completedHeaderBlock) {
                tailFrames.add(frame)
                continue
            }
            headerAccumulator.append(frame)
            let completed =
                headerAccumulator.drainCompleteHeaderBlocks()
            if (completed.size > 1) {
                throw Exception(
                    "accepted-session application-data logical-request builder core expects at most one leading complete H2 header block while the packet stays one-request-bounded, got count=${completed.size}"
                )
            }
            if (completed.size == 1) {
                completedHeaderBlock = Some(completed[0])
            }
        }
        match (completedHeaderBlock) {
            case Some(headerBlock) =>
                buildServerJinguiAcceptedTransportLogicalRequestFromH2HeaderBlock(
                    headerBlock,
                    bodyBytes: bodyBytesResolver(
                        headerBlock,
                        tailFrames.toArray()
                    )
                )
            case None =>
                throw Exception(missingHeaderBlockMessage)
        }
    }

    func resolveJinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestBodyBytes(
        headerBlock: JinguiAcceptedTransportH2HeaderBlockSnapshot,
        tailFrames: Array<JinguiAcceptedTransportH2FrameWireSnapshot>
    ): Array<UInt8> {
        let bodyBytes = ArrayList<Byte>()
        var sawDataFrame = false
        for (frame in tailFrames) {
            if (frame.frameType != UInt8(0x0)) {
                throw Exception(
                    "accepted-session application-data headers-plus-data logical-request projection stays inside one request boundary and only accepts same-stream DATA after one complete H2 header block, got type=${Int64(frame.frameType)}, streamId=${frame.streamId}"
                )
            }
            let dataFrame =
                parseJinguiAcceptedTransportH2DataFrame(frame)
            if (dataFrame.streamId != headerBlock.streamId) {
                throw Exception(
                    "accepted-session application-data headers-plus-data logical-request projection requires same-stream DATA, headerStreamId=${headerBlock.streamId}, dataStreamId=${dataFrame.streamId}"
                )
            }
            for (b in dataFrame.dataBytes) {
                bodyBytes.add(b)
            }
            sawDataFrame = true
        }
        if (!sawDataFrame) {
            throw Exception(
                "accepted-session application-data headers-plus-data logical-request projection expects at least one same-stream H2 DATA frame after one complete H2 header block"
            )
        }
        serverEngineByteToUInt8Array(bodyBytes.toArray())
    }

    func resolveJinguiAcceptedTransportApplicationDataH2HeaderBlockLogicalRequestBodyBytes(
        tailFrames: Array<JinguiAcceptedTransportH2FrameWireSnapshot>,
        bodyBytes: Array<UInt8>
    ): Array<UInt8> {
        if (tailFrames.size == 0) {
            return bodyBytes
        }
        let headerAccumulator = JinguiAcceptedTransportH2HeaderBlockAccumulator()
        for (frame in tailFrames) {
            headerAccumulator.append(frame)
        }
        let completedHeaderBlocks =
            headerAccumulator.drainCompleteHeaderBlocks()
        if (completedHeaderBlocks.size != 0) {
            throw Exception(
                "accepted-session application-data logical-request projection expects exactly one complete H2 header block, got count=${completedHeaderBlocks.size + 1}"
            )
        }
        bodyBytes
    }

    public func openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2HeadersPlusData(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecords: Array<Array<Byte>>
    ): ServerJinguiAcceptedTransportLogicalRequest {
        openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2LeadingHeaderBlockCore(
            session,
            encodedRecords,
            "accepted-session application-data headers-plus-data logical-request projection expects exactly one complete H2 header block before DATA accumulation",
            { headerBlock, tailFrames =>
                resolveJinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestBodyBytes(
                    headerBlock,
                    tailFrames
                )
            }
        )
    }

    public func openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2HeaderBlock(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecords: Array<Array<Byte>>,
        bodyBytes!: Array<UInt8> = []
    ): ServerJinguiAcceptedTransportLogicalRequest {
        openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2LeadingHeaderBlockCore(
            session,
            encodedRecords,
            "accepted-session application-data logical-request projection expects exactly one complete H2 header block, got count=0",
            { _, tailFrames =>
                resolveJinguiAcceptedTransportApplicationDataH2HeaderBlockLogicalRequestBodyBytes(
                    tailFrames,
                    bodyBytes
                )
            }
        )
    }

    public func openJinguiAcceptedTransportApplicationDataResponseTransportWriter(
        session: ContractHttpServerAcceptedTransportSession,
        downstream: ResponseTransportWriter,
        maxFragmentLen!: Int64 = 16384
    ): ResponseTransportWriter {
        ensureServerJinguiAcceptedTransportSessionCodecReady(session)
        wrapResponseTransportWriter(downstream, { plaintext =>
            serverEngineByteRecordChunksToUInt8(
                sealJinguiAcceptedTransportApplicationDataFragments(
                    session,
                    serverEngineUInt8ToByteArray(plaintext),
                    maxFragmentLen: maxFragmentLen
                )
            )
        })
    }

    public func wrapCurrentRequestCarrierWithJinguiAcceptedTransportApplicationDataResponse(
        session: ContractHttpServerAcceptedTransportSession,
        downstream: CurrentRequestCarrier,
        maxFragmentLen!: Int64 = 16384
    ): CurrentRequestCarrier {
        wrapCurrentRequestCarrierResponseWriter(downstream, { =>
            openJinguiAcceptedTransportApplicationDataResponseTransportWriter(
                session,
                downstream.openResponseTransportWriterRaw(),
                maxFragmentLen: maxFragmentLen
            )
        })
    }

    public func buildJinguiAcceptedTransportSessionSnapshot(
        session: ContractHttpServerAcceptedTransportSession
    ): ServerJinguiAcceptedTransportSessionSnapshot {
        buildServerJinguiAcceptedTransportSessionSnapshot(session)
    }
}

public class ServerJinguiHttpServerAttachPlanSnapshot {
    public let providerId: String
    public let attachSurface: String
    public let listenerOwned: Bool
    public let expectedTlsVersion: String
    public let expectedAlpnProtocols: Array<String>
    public let planningStatus: String
    public let planningReady: Bool
    public let planningPublicPath: String
    public let planningReleasePath: String
    public let planningSelectedReason: String
    public let planningWarnings: Array<String>
    public let stableAttachStatus: String
    public let stableAttachReady: Bool
    public let stableAttachPublicPath: String
    public let stableAttachReleasePath: String
    public let stableAttachSelectedReason: String
    public let stableAttachBlockedCandidates: Array<String>
    public let materialKeyAlgorithm: String

    public init(
        providerId: String,
        attachSurface: String,
        listenerOwned: Bool,
        expectedTlsVersion: String,
        expectedAlpnProtocols: Array<String>,
        planningStatus: String,
        planningReady: Bool,
        planningPublicPath: String,
        planningReleasePath: String,
        planningSelectedReason: String,
        planningWarnings: Array<String>,
        stableAttachStatus: String,
        stableAttachReady: Bool,
        stableAttachPublicPath: String,
        stableAttachReleasePath: String,
        stableAttachSelectedReason: String,
        stableAttachBlockedCandidates: Array<String>,
        materialKeyAlgorithm: String
    ) {
        this.providerId = providerId
        this.attachSurface = attachSurface
        this.listenerOwned = listenerOwned
        this.expectedTlsVersion = expectedTlsVersion
        this.expectedAlpnProtocols = expectedAlpnProtocols.clone()
        this.planningStatus = planningStatus
        this.planningReady = planningReady
        this.planningPublicPath = planningPublicPath
        this.planningReleasePath = planningReleasePath
        this.planningSelectedReason = planningSelectedReason
        this.planningWarnings = planningWarnings.clone()
        this.stableAttachStatus = stableAttachStatus
        this.stableAttachReady = stableAttachReady
        this.stableAttachPublicPath = stableAttachPublicPath
        this.stableAttachReleasePath = stableAttachReleasePath
        this.stableAttachSelectedReason = stableAttachSelectedReason
        this.stableAttachBlockedCandidates = stableAttachBlockedCandidates.clone()
        this.materialKeyAlgorithm = materialKeyAlgorithm
    }
}

public class ServerEngineListenOption {
    public let addr: String
    public let port: UInt16
    public let readTimeout: Duration
    public let writeTimeout: Duration
    public let readHeaderTimeout: Duration
    public let maxRequestBodySize: Int64
    public let tlsCertFile: String
    public let tlsKeyFile: String
    public let enableTlsPrecheck: Bool
    public let serverPreferredBackendHint: String
    public let allowExperimentalServerBackend: Bool
    public let preparedTlsMaterialLoader: ?ServerPreparedTlsMaterialLoader
    public let transportRoutingBundle: ?ServerTransportRoutingBundle
    public let transportTouchpoint: ?ServerTransportTouchpoint
    public let tlsIngressContext: ?ServerTlsIngressContext
    public let jinguiAcceptedTransportSessionHook:
        ?ServerJinguiAcceptedTransportSessionHook

    public init(
        addr: String,
        port: UInt16,
        readTimeout: Duration,
        writeTimeout: Duration,
        readHeaderTimeout: Duration,
        maxRequestBodySize: Int64,
        tlsCertFile: String,
        tlsKeyFile: String,
        enableTlsPrecheck: Bool,
        serverPreferredBackendHint!: String = "",
        allowExperimentalServerBackend!: Bool = false,
        preparedTlsMaterialLoader!: ?ServerPreparedTlsMaterialLoader = None,
        transportRoutingBundle!: ?ServerTransportRoutingBundle = None,
        transportTouchpoint!: ?ServerTransportTouchpoint = None,
        tlsIngressContext!: ?ServerTlsIngressContext = None,
        jinguiAcceptedTransportSessionHook!:
            ?ServerJinguiAcceptedTransportSessionHook = None
    ) {
        this.addr = addr
        this.port = port
        this.readTimeout = readTimeout
        this.writeTimeout = writeTimeout
        this.readHeaderTimeout = readHeaderTimeout
        this.maxRequestBodySize = maxRequestBodySize
        this.tlsCertFile = tlsCertFile
        this.tlsKeyFile = tlsKeyFile
        this.enableTlsPrecheck = enableTlsPrecheck
        this.serverPreferredBackendHint = serverPreferredBackendHint
        this.allowExperimentalServerBackend = allowExperimentalServerBackend
        this.preparedTlsMaterialLoader = preparedTlsMaterialLoader
        this.transportRoutingBundle = transportRoutingBundle
        this.transportTouchpoint = transportTouchpoint
        this.tlsIngressContext = tlsIngressContext
        this.jinguiAcceptedTransportSessionHook =
            jinguiAcceptedTransportSessionHook
    }

    public func loadPreparedTlsMaterial(): api2.PreparedHttpServerTlsMaterial {
        if (let Some(loader) <- preparedTlsMaterialLoader) {
            return loader()
        }
        if (let Some(context) <- tlsIngressContext) {
            return context.loadPreparedTlsMaterial()
        }
        throw Exception("prepared TLS material loader is unavailable")
    }

    public func loadTransportRoutingBundle(): ServerTransportRoutingBundle {
        if (let Some(bundle) <- transportRoutingBundle) {
            return bundle
        }
        if (let Some(context) <- tlsIngressContext) {
            return context.transportRoutingBundle
        }
        throw Exception("server transport routing bundle is unavailable")
    }

    public func loadTlsIngressContext(): ServerTlsIngressContext {
        if (let Some(context) <- tlsIngressContext) {
            return context
        }
        if (let Some(bundle) <- transportRoutingBundle) {
            if (let Some(touchpoint) <- transportTouchpoint) {
                return ServerTlsIngressContext(
                    bundle,
                    touchpoint,
                    preparedTlsMaterialLoader: preparedTlsMaterialLoader
                )
            }
        }
        throw Exception("server TLS ingress context is unavailable")
    }

    public func loadJinguiHttpServerAttachPlanSnapshot(): ServerJinguiHttpServerAttachPlanSnapshot {
        loadTlsIngressContext().loadJinguiHttpServerAttachPlanSnapshot()
    }

    public func buildJinguiHttpServerAttachResultSnapshot(
        attachResult: ContractHttpServerAttachResult
    ): ServerJinguiHttpServerAttachResultSnapshot {
        if (let Some(context) <- tlsIngressContext) {
            return context.buildJinguiHttpServerAttachResultSnapshot(attachResult)
        }
        buildServerJinguiHttpServerAttachResultSnapshot(attachResult)
    }

    public func buildJinguiAcceptedTransportTls13X25519Request(
        transport: ContractAcceptedTransportDescriptor,
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ContractHttpServerAcceptedTransportTls13X25519Request {
        loadTlsIngressContext().buildJinguiAcceptedTransportTls13X25519Request(
            transport,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
    }

    public func attachJinguiAcceptedTransportTls13X25519Request(
        request: ContractHttpServerAcceptedTransportTls13X25519Request
    ): ContractHttpServerAcceptedTransportSession {
        loadTlsIngressContext().attachJinguiAcceptedTransportTls13X25519Request(
            request
        )
    }

    public func attachJinguiAcceptedTransportTls13X25519(
        transport: ContractAcceptedTransportDescriptor,
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ContractHttpServerAcceptedTransportSession {
        loadTlsIngressContext().attachJinguiAcceptedTransportTls13X25519(
            transport,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
    }

    public func closeJinguiAcceptedTransportSession(
        session: ContractHttpServerAcceptedTransportSession,
        reason!: String = "close_notify"
    ): ContractHttpServerAcceptedTransportSession {
        loadTlsIngressContext().closeJinguiAcceptedTransportSession(
            session,
            reason: reason
        )
    }

    public func captureJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHello(
        acceptedSocket: TcpSocket,
        readChunkSize!: Int64 = 4096
    ): ServerJinguiAcceptedTransportTls13ClientHelloCapture {
        captureJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloCore(
            acceptedSocket,
            readChunkSize: readChunkSize
        )
    }

    func attachJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloX25519Core(
        acceptedSocket: TcpSocket,
        serverKeyExchangePrivate: Array<Byte>,
        transportId!: String = "accepted-transport",
        readChunkSize!: Int64 = 4096,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy(),
        notifyReadySnapshot!: Bool = true
    ): ServerJinguiAcceptedTransportSocketAttachedSessionResult {
        let capture =
            captureJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHello(
                acceptedSocket,
                readChunkSize: readChunkSize
            )
        let transport = buildServerAcceptedTransportDescriptorFromSocket(
            acceptedSocket,
            transportId
        )
        let session = attachJinguiAcceptedTransportTls13X25519(
            transport,
            capture.encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
        let readySnapshot = if (notifyReadySnapshot) {
            notifyJinguiAcceptedTransportSession(session)
        } else {
            buildJinguiAcceptedTransportSessionSnapshot(session)
        }
        ServerJinguiAcceptedTransportSocketAttachedSessionResult(
            capture,
            session,
            readySnapshot
        )
    }

    public func attachJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloX25519(
        acceptedSocket: TcpSocket,
        serverKeyExchangePrivate: Array<Byte>,
        transportId!: String = "accepted-transport",
        readChunkSize!: Int64 = 4096,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ServerJinguiAcceptedTransportSocketAttachedSessionResult {
        attachJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloX25519Core(
            acceptedSocket,
            serverKeyExchangePrivate,
            transportId: transportId,
            readChunkSize: readChunkSize,
            policy: policy,
            notifyReadySnapshot: true
        )
    }

    public func sealJinguiAcceptedTransportApplicationData(
        session: ContractHttpServerAcceptedTransportSession,
        plaintext: Array<Byte>
    ): Array<Byte> {
        loadTlsIngressContext().sealJinguiAcceptedTransportApplicationData(
            session,
            plaintext
        )
    }

    public func openJinguiAcceptedTransportApplicationData(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecord: Array<Byte>
    ): Array<Byte> {
        loadTlsIngressContext().openJinguiAcceptedTransportApplicationData(
            session,
            encodedRecord
        )
    }

    public func sealJinguiAcceptedTransportApplicationDataFragments(
        session: ContractHttpServerAcceptedTransportSession,
        plaintext: Array<Byte>,
        maxFragmentLen!: Int64 = 16384
    ): Array<Array<Byte>> {
        loadTlsIngressContext()
            .sealJinguiAcceptedTransportApplicationDataFragments(
                session,
                plaintext,
                maxFragmentLen: maxFragmentLen
            )
    }

    public func openAndReassembleJinguiAcceptedTransportApplicationData(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecords: Array<Array<Byte>>
    ): Array<Byte> {
        loadTlsIngressContext()
            .openAndReassembleJinguiAcceptedTransportApplicationData(
                session,
                encodedRecords
            )
    }

    public func openAndIngressJinguiAcceptedTransportApplicationDataH2HeaderBlocks(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecords: Array<Array<Byte>>
    ): Array<JinguiAcceptedTransportH2HeaderBlockSnapshot> {
        loadTlsIngressContext()
            .openAndIngressJinguiAcceptedTransportApplicationDataH2HeaderBlocks(
                session,
                encodedRecords
            )
    }

    public func buildJinguiAcceptedTransportApplicationDataH2HeaderBlockIngressAccumulator(
        session: ContractHttpServerAcceptedTransportSession
    ): JinguiAcceptedTransportApplicationDataH2HeaderBlockIngressAccumulator {
        loadTlsIngressContext()
            .buildJinguiAcceptedTransportApplicationDataH2HeaderBlockIngressAccumulator(
                session
            )
    }

    public func buildJinguiAcceptedTransportApplicationDataH2HeaderBlockLogicalRequestAccumulator(
        session: ContractHttpServerAcceptedTransportSession,
        bodyBytes!: Array<UInt8> = []
    ): JinguiAcceptedTransportApplicationDataH2HeaderBlockLogicalRequestAccumulator {
        loadTlsIngressContext()
            .buildJinguiAcceptedTransportApplicationDataH2HeaderBlockLogicalRequestAccumulator(
                session,
                bodyBytes: bodyBytes
            )
    }

    public func buildJinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestAccumulator(
        session: ContractHttpServerAcceptedTransportSession
    ): JinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestAccumulator {
        loadTlsIngressContext()
            .buildJinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestAccumulator(
                session
            )
    }

    public func openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2HeaderBlock(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecords: Array<Array<Byte>>,
        bodyBytes!: Array<UInt8> = []
    ): ServerJinguiAcceptedTransportLogicalRequest {
        loadTlsIngressContext()
            .openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2HeaderBlock(
                session,
                encodedRecords,
                bodyBytes: bodyBytes
            )
    }

    public func openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2HeadersPlusData(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRecords: Array<Array<Byte>>
    ): ServerJinguiAcceptedTransportLogicalRequest {
        loadTlsIngressContext()
            .openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2HeadersPlusData(
                session,
                encodedRecords
            )
    }

    public func openJinguiAcceptedTransportApplicationDataResponseTransportWriter(
        session: ContractHttpServerAcceptedTransportSession,
        downstream: ResponseTransportWriter,
        maxFragmentLen!: Int64 = 16384
    ): ResponseTransportWriter {
        loadTlsIngressContext()
            .openJinguiAcceptedTransportApplicationDataResponseTransportWriter(
                session,
                downstream,
                maxFragmentLen: maxFragmentLen
            )
    }

    public func wrapCurrentRequestCarrierWithJinguiAcceptedTransportApplicationDataResponse(
        session: ContractHttpServerAcceptedTransportSession,
        downstream: CurrentRequestCarrier,
        maxFragmentLen!: Int64 = 16384
    ): CurrentRequestCarrier {
        loadTlsIngressContext()
            .wrapCurrentRequestCarrierWithJinguiAcceptedTransportApplicationDataResponse(
                session,
                downstream,
                maxFragmentLen: maxFragmentLen
            )
    }

    public func buildJinguiAcceptedTransportSessionSnapshot(
        session: ContractHttpServerAcceptedTransportSession
    ): ServerJinguiAcceptedTransportSessionSnapshot {
        loadTlsIngressContext().buildJinguiAcceptedTransportSessionSnapshot(
            session
        )
    }

    public func notifyJinguiAcceptedTransportSessionSnapshot(
        snapshot: ServerJinguiAcceptedTransportSessionSnapshot
    ): Unit {
        if (let Some(hook) <- jinguiAcceptedTransportSessionHook) {
            hook(snapshot)
        }
    }

    public func notifyJinguiAcceptedTransportSession(
        session: ContractHttpServerAcceptedTransportSession
    ): ServerJinguiAcceptedTransportSessionSnapshot {
        let snapshot = buildJinguiAcceptedTransportSessionSnapshot(session)
        notifyJinguiAcceptedTransportSessionSnapshot(snapshot)
        snapshot
    }

    func serveJinguiAcceptedTransportSessionLogicalRequestTurnCore(
        session: ContractHttpServerAcceptedTransportSession,
        acceptedSocket: TcpSocket,
        app: App,
        request: ServerJinguiAcceptedTransportLogicalRequest,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let readySnapshot = notifyJinguiAcceptedTransportSession(session)
        let carrier = ServerJinguiAcceptedTransportSocketResponseCarrier(
            request,
            acceptedSocket
        )
        let wrappedCarrier =
            wrapCurrentRequestCarrierWithJinguiAcceptedTransportApplicationDataResponse(
                session,
                carrier,
                maxFragmentLen: maxFragmentLen
            )
        try {
            app.handleRequest(wrappedCarrier)
            ServerJinguiAcceptedTransportSocketResponseTurnResult(
                session,
                readySnapshot,
                carrier.responseStatus,
                cloneServerEngineHeaders(carrier.responseHeaders),
                carrier.socketWriteCount,
                carrier.totalEncodedSocketBytes
            )
        } finally {
            if (closeSocketAfterTurn && !acceptedSocket.isClosed()) {
                acceptedSocket.close()
            }
        }
    }

    func serveJinguiAcceptedTransportSessionApplicationDataLogicalRequestTurnBuildAndServeCore(
        session: ContractHttpServerAcceptedTransportSession,
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestRecords: Array<Array<Byte>>,
        requestBuilder: (
            ContractHttpServerAcceptedTransportSession,
            Array<Array<Byte>>
        ) -> ServerJinguiAcceptedTransportLogicalRequest,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let request = requestBuilder(session, encodedRequestRecords)
        serveJinguiAcceptedTransportSessionLogicalRequestTurnCore(
            session,
            acceptedSocket,
            app,
            request,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    func buildJinguiAcceptedTransportLogicalRequestFromApplicationDataFragmentedRecordWireH2HeaderBlockCore(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRequestWireFragments: Array<Array<Byte>>,
        bodyBytes!: Array<UInt8> = []
    ): ServerJinguiAcceptedTransportLogicalRequest {
        let requestAccumulator =
            buildJinguiAcceptedTransportApplicationDataH2HeaderBlockLogicalRequestAccumulator(
                session,
                bodyBytes: bodyBytes
            )
        var request: ?ServerJinguiAcceptedTransportLogicalRequest = None
        var requestCount: Int64 = 0
        for (fragment in encodedRequestWireFragments) {
            requestAccumulator.append(fragment)
            let completed = requestAccumulator.drainCompleteLogicalRequests()
            if (completed.size == 0) {
                continue
            }
            request = Some(completed[0])
            requestCount += Int64(completed.size)
        }
        if (requestCount != 1) {
            throw Exception(
                "accepted-session application-data fragmented-record-wire request-turn expects exactly one logical request, got count=${requestCount}"
            )
        }
        let bufferedRecordWireBytes =
            requestAccumulator.bufferedRecordWireByteCount()
        let bufferedH2FrameWireBytes =
            requestAccumulator.bufferedH2FrameWireByteCount()
        let hasOpenHeaderBlock =
            requestAccumulator.hasOpenHeaderBlock()
        let bufferedHeaderBlockBytes =
            requestAccumulator.bufferedHeaderBlockByteCount()
        if (
            bufferedRecordWireBytes != 0 ||
            bufferedH2FrameWireBytes != 0 ||
            hasOpenHeaderBlock ||
            bufferedHeaderBlockBytes != 0
        ) {
            throw Exception(
                "accepted-session application-data fragmented-record-wire request-turn expects fully drained ingress after one logical request, bufferedRecordWireBytes=${bufferedRecordWireBytes}, bufferedH2FrameWireBytes=${bufferedH2FrameWireBytes}, hasOpenHeaderBlock=${hasOpenHeaderBlock}, bufferedHeaderBlockBytes=${bufferedHeaderBlockBytes}"
            )
        }
        match (request) {
            case Some(logicalRequest) => logicalRequest
            case None =>
                throw Exception(
                    "accepted-session application-data fragmented-record-wire request-turn expected one logical request after count check"
                )
        }
    }

    func buildJinguiAcceptedTransportLogicalRequestFromApplicationDataFragmentedRecordWireH2HeadersPlusDataCore(
        session: ContractHttpServerAcceptedTransportSession,
        encodedRequestWireFragments: Array<Array<Byte>>
    ): ServerJinguiAcceptedTransportLogicalRequest {
        let requestAccumulator =
            buildJinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestAccumulator(
                session
            )
        var request: ?ServerJinguiAcceptedTransportLogicalRequest = None
        var requestCount: Int64 = 0
        for (fragment in encodedRequestWireFragments) {
            requestAccumulator.append(fragment)
            let completed = requestAccumulator.drainCompleteLogicalRequests()
            if (completed.size == 0) {
                continue
            }
            request = Some(completed[0])
            requestCount += Int64(completed.size)
        }
        if (requestCount != 1) {
            throw Exception(
                "accepted-session application-data fragmented-record-wire headers-plus-data request-turn expects exactly one logical request, got count=${requestCount}"
            )
        }
        let bufferedRecordWireBytes =
            requestAccumulator.bufferedRecordWireByteCount()
        let bufferedH2FrameWireBytes =
            requestAccumulator.bufferedH2FrameWireByteCount()
        let hasOpenHeaderBlock =
            requestAccumulator.hasOpenHeaderBlock()
        let bufferedHeaderBlockBytes =
            requestAccumulator.bufferedHeaderBlockByteCount()
        let bufferedBodyBytes =
            requestAccumulator.bufferedBodyByteCount()
        if (
            bufferedRecordWireBytes != 0 ||
            bufferedH2FrameWireBytes != 0 ||
            hasOpenHeaderBlock ||
            bufferedHeaderBlockBytes != 0 ||
            bufferedBodyBytes != 0
        ) {
            throw Exception(
                "accepted-session application-data fragmented-record-wire headers-plus-data request-turn expects fully drained ingress after one logical request, bufferedRecordWireBytes=${bufferedRecordWireBytes}, bufferedH2FrameWireBytes=${bufferedH2FrameWireBytes}, hasOpenHeaderBlock=${hasOpenHeaderBlock}, bufferedHeaderBlockBytes=${bufferedHeaderBlockBytes}, bufferedBodyBytes=${bufferedBodyBytes}"
            )
        }
        match (request) {
            case Some(logicalRequest) => logicalRequest
            case None =>
                throw Exception(
                    "accepted-session application-data fragmented-record-wire headers-plus-data request-turn expected one logical request after count check"
                )
        }
    }

    func buildJinguiAcceptedTransportLogicalRequestFromAcceptedSocketApplicationDataFragmentedRecordWireH2HeadersPlusDataCore(
        session: ContractHttpServerAcceptedTransportSession,
        acceptedSocket: TcpSocket,
        readChunkSize!: Int64 = 4096
    ): ServerJinguiAcceptedTransportLogicalRequest {
        let requestAccumulator =
            buildJinguiAcceptedTransportApplicationDataH2HeadersPlusDataLogicalRequestAccumulator(
                session
            )
        let chunkSize = if (readChunkSize > 0) {
            readChunkSize
        } else {
            4096
        }
        let buf = Array<UInt8>(chunkSize, repeat: 0)
        while (true) {
            let n = acceptedSocket.read(buf)
            if (n <= 0) {
                break
            }
            requestAccumulator.append(
                serverEngineUInt8ToByteArray(buf[..n])
            )
            let completed = requestAccumulator.drainCompleteLogicalRequests()
            if (completed.size == 0) {
                continue
            }
            if (completed.size != 1) {
                throw Exception(
                    "accepted-session accepted-socket fragmented-record-wire headers-plus-data request-turn expects exactly one logical request, got count=${completed.size}"
                )
            }
            let bufferedRecordWireBytes =
                requestAccumulator.bufferedRecordWireByteCount()
            let bufferedH2FrameWireBytes =
                requestAccumulator.bufferedH2FrameWireByteCount()
            let hasOpenHeaderBlock =
                requestAccumulator.hasOpenHeaderBlock()
            let bufferedHeaderBlockBytes =
                requestAccumulator.bufferedHeaderBlockByteCount()
            let bufferedBodyBytes =
                requestAccumulator.bufferedBodyByteCount()
            if (
                bufferedRecordWireBytes != 0 ||
                bufferedH2FrameWireBytes != 0 ||
                hasOpenHeaderBlock ||
                bufferedHeaderBlockBytes != 0 ||
                bufferedBodyBytes != 0
            ) {
                throw Exception(
                    "accepted-session accepted-socket fragmented-record-wire headers-plus-data request-turn expects fully drained ingress after one logical request, bufferedRecordWireBytes=${bufferedRecordWireBytes}, bufferedH2FrameWireBytes=${bufferedH2FrameWireBytes}, hasOpenHeaderBlock=${hasOpenHeaderBlock}, bufferedHeaderBlockBytes=${bufferedHeaderBlockBytes}, bufferedBodyBytes=${bufferedBodyBytes}"
                )
            }
            return completed[0]
        }
        let bufferedRecordWireBytes =
            requestAccumulator.bufferedRecordWireByteCount()
        let bufferedH2FrameWireBytes =
            requestAccumulator.bufferedH2FrameWireByteCount()
        let hasOpenHeaderBlock =
            requestAccumulator.hasOpenHeaderBlock()
        let bufferedHeaderBlockBytes =
            requestAccumulator.bufferedHeaderBlockByteCount()
        let bufferedBodyBytes =
            requestAccumulator.bufferedBodyByteCount()
        throw Exception(
            "accepted-session accepted-socket fragmented-record-wire headers-plus-data request-turn expected one logical request before socket read ended, bufferedRecordWireBytes=${bufferedRecordWireBytes}, bufferedH2FrameWireBytes=${bufferedH2FrameWireBytes}, hasOpenHeaderBlock=${hasOpenHeaderBlock}, bufferedHeaderBlockBytes=${bufferedHeaderBlockBytes}, bufferedBodyBytes=${bufferedBodyBytes}"
        )
    }

    func serveJinguiAcceptedTransportSessionApplicationDataFragmentedRecordWireLogicalRequestTurnBuildAndServeCore(
        session: ContractHttpServerAcceptedTransportSession,
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestWireFragments: Array<Array<Byte>>,
        requestBuilder: (
            ContractHttpServerAcceptedTransportSession,
            Array<Array<Byte>>
        ) -> ServerJinguiAcceptedTransportLogicalRequest,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let request = requestBuilder(session, encodedRequestWireFragments)
        serveJinguiAcceptedTransportSessionLogicalRequestTurnCore(
            session,
            acceptedSocket,
            app,
            request,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSocketLogicalRequest(
        acceptedSocket: TcpSocket,
        app: App,
        request: ServerJinguiAcceptedTransportLogicalRequest,
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        transportId!: String = "accepted-transport",
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let transport = buildServerAcceptedTransportDescriptorFromSocket(
            acceptedSocket,
            transportId
        )
        let session = attachJinguiAcceptedTransportTls13X25519(
            transport,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
        serveJinguiAcceptedTransportSessionLogicalRequestTurnCore(
            session,
            acceptedSocket,
            app,
            request,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloLogicalRequest(
        acceptedSocket: TcpSocket,
        app: App,
        request: ServerJinguiAcceptedTransportLogicalRequest,
        serverKeyExchangePrivate: Array<Byte>,
        transportId!: String = "accepted-transport",
        readChunkSize!: Int64 = 4096,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let attached =
            attachJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloX25519Core(
                acceptedSocket,
                serverKeyExchangePrivate,
                transportId: transportId,
                readChunkSize: readChunkSize,
                policy: policy,
                notifyReadySnapshot: false
            )
        serveJinguiAcceptedTransportSessionLogicalRequestTurnCore(
            attached.session,
            acceptedSocket,
            app,
            request,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSessionApplicationDataFragmentedRecordWireH2ProvidedBodyRequestTurn(
        session: ContractHttpServerAcceptedTransportSession,
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestWireFragments: Array<Array<Byte>>,
        bodyBytes!: Array<UInt8> = [],
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        serveJinguiAcceptedTransportSessionApplicationDataFragmentedRecordWireLogicalRequestTurnBuildAndServeCore(
            session,
            acceptedSocket,
            app,
            encodedRequestWireFragments,
            { currentSession, currentEncodedRequestWireFragments =>
                buildJinguiAcceptedTransportLogicalRequestFromApplicationDataFragmentedRecordWireH2HeaderBlockCore(
                    currentSession,
                    currentEncodedRequestWireFragments,
                    bodyBytes: bodyBytes
                )
            },
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSessionApplicationDataFragmentedRecordWireH2HeadersPlusDataRequestTurn(
        session: ContractHttpServerAcceptedTransportSession,
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestWireFragments: Array<Array<Byte>>,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        serveJinguiAcceptedTransportSessionApplicationDataFragmentedRecordWireLogicalRequestTurnBuildAndServeCore(
            session,
            acceptedSocket,
            app,
            encodedRequestWireFragments,
            { currentSession, currentEncodedRequestWireFragments =>
                buildJinguiAcceptedTransportLogicalRequestFromApplicationDataFragmentedRecordWireH2HeadersPlusDataCore(
                    currentSession,
                    currentEncodedRequestWireFragments
                )
            },
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSessionAcceptedSocketApplicationDataFragmentedRecordWireH2HeadersPlusDataRequestTurn(
        session: ContractHttpServerAcceptedTransportSession,
        acceptedSocket: TcpSocket,
        app: App,
        readChunkSize!: Int64 = 4096,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let request =
            buildJinguiAcceptedTransportLogicalRequestFromAcceptedSocketApplicationDataFragmentedRecordWireH2HeadersPlusDataCore(
                session,
                acceptedSocket,
                readChunkSize: readChunkSize
            )
        serveJinguiAcceptedTransportSessionLogicalRequestTurnCore(
            session,
            acceptedSocket,
            app,
            request,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSocketApplicationDataFragmentedRecordWireH2ProvidedBodyRequestTurn(
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestWireFragmentsBuilder:
            ServerJinguiAcceptedTransportAttachedSessionEncodedRequestWireFragmentsBuilder,
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        bodyBytes!: Array<UInt8> = [],
        transportId!: String = "accepted-transport",
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let transport = buildServerAcceptedTransportDescriptorFromSocket(
            acceptedSocket,
            transportId
        )
        let session = attachJinguiAcceptedTransportTls13X25519(
            transport,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
        serveJinguiAcceptedTransportSessionApplicationDataFragmentedRecordWireH2ProvidedBodyRequestTurn(
            session,
            acceptedSocket,
            app,
            encodedRequestWireFragmentsBuilder(session),
            bodyBytes: bodyBytes,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSocketApplicationDataFragmentedRecordWireH2HeadersPlusDataRequestTurn(
        acceptedSocket: TcpSocket,
        app: App,
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        transportId!: String = "accepted-transport",
        readChunkSize!: Int64 = 4096,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy(),
        attachedSessionReadyHook!:
            ?ServerJinguiAcceptedTransportAttachedSessionReadyHook = None
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let transport = buildServerAcceptedTransportDescriptorFromSocket(
            acceptedSocket,
            transportId
        )
        let session = attachJinguiAcceptedTransportTls13X25519(
            transport,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
        if (let Some(hook) <- attachedSessionReadyHook) {
            hook(session)
        }
        serveJinguiAcceptedTransportSessionAcceptedSocketApplicationDataFragmentedRecordWireH2HeadersPlusDataRequestTurn(
            session,
            acceptedSocket,
            app,
            readChunkSize: readChunkSize,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloApplicationDataFragmentedRecordWireH2HeadersPlusDataRequestTurn(
        acceptedSocket: TcpSocket,
        app: App,
        serverKeyExchangePrivate: Array<Byte>,
        transportId!: String = "accepted-transport",
        readChunkSize!: Int64 = 4096,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy(),
        attachedSessionReadyHook!:
            ?ServerJinguiAcceptedTransportAttachedSessionReadyHook = None
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let attached =
            attachJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloX25519Core(
                acceptedSocket,
                serverKeyExchangePrivate,
                transportId: transportId,
                readChunkSize: readChunkSize,
                policy: policy,
                notifyReadySnapshot: false
            )
        if (let Some(hook) <- attachedSessionReadyHook) {
            hook(attached.session)
        }
        serveJinguiAcceptedTransportSessionAcceptedSocketApplicationDataFragmentedRecordWireH2HeadersPlusDataRequestTurn(
            attached.session,
            acceptedSocket,
            app,
            readChunkSize: readChunkSize,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSessionApplicationDataH2ProvidedBodyRequestTurn(
        session: ContractHttpServerAcceptedTransportSession,
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestRecords: Array<Array<Byte>>,
        bodyBytes!: Array<UInt8> = [],
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        serveJinguiAcceptedTransportSessionApplicationDataLogicalRequestTurnBuildAndServeCore(
            session,
            acceptedSocket,
            app,
            encodedRequestRecords,
            { currentSession, currentEncodedRequestRecords =>
                openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2HeaderBlock(
                    currentSession,
                    currentEncodedRequestRecords,
                    bodyBytes: bodyBytes
                )
            },
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSessionApplicationDataH2HeadersPlusDataRequestTurn(
        session: ContractHttpServerAcceptedTransportSession,
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestRecords: Array<Array<Byte>>,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        serveJinguiAcceptedTransportSessionApplicationDataLogicalRequestTurnBuildAndServeCore(
            session,
            acceptedSocket,
            app,
            encodedRequestRecords,
            { currentSession, currentEncodedRequestRecords =>
                openAndBuildJinguiAcceptedTransportLogicalRequestFromApplicationDataH2HeadersPlusData(
                    currentSession,
                    currentEncodedRequestRecords
                )
            },
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSessionApplicationDataH2BodylessRequestTurn(
        session: ContractHttpServerAcceptedTransportSession,
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestRecords: Array<Array<Byte>>,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        serveJinguiAcceptedTransportSessionApplicationDataH2ProvidedBodyRequestTurn(
            session,
            acceptedSocket,
            app,
            encodedRequestRecords,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSocketApplicationDataH2ProvidedBodyRequestTurn(
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestRecordsBuilder:
            ServerJinguiAcceptedTransportAttachedSessionEncodedRequestRecordsBuilder,
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        bodyBytes!: Array<UInt8> = [],
        transportId!: String = "accepted-transport",
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let transport = buildServerAcceptedTransportDescriptorFromSocket(
            acceptedSocket,
            transportId
        )
        let session = attachJinguiAcceptedTransportTls13X25519(
            transport,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
        serveJinguiAcceptedTransportSessionApplicationDataH2ProvidedBodyRequestTurn(
            session,
            acceptedSocket,
            app,
            encodedRequestRecordsBuilder(session),
            bodyBytes: bodyBytes,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSocketApplicationDataH2BodylessRequestTurn(
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestRecordsBuilder:
            ServerJinguiAcceptedTransportAttachedSessionEncodedRequestRecordsBuilder,
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        transportId!: String = "accepted-transport",
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let transport = buildServerAcceptedTransportDescriptorFromSocket(
            acceptedSocket,
            transportId
        )
        let session = attachJinguiAcceptedTransportTls13X25519(
            transport,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
        serveJinguiAcceptedTransportSocketApplicationDataH2ProvidedBodyRequestTurn(
            acceptedSocket,
            app,
            encodedRequestRecordsBuilder,
            encodedClientHello,
            serverKeyExchangePrivate,
            transportId: transportId,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn,
            policy: policy
        )
    }

    public func serveJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloApplicationDataH2BodylessRequestTurn(
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestRecordsBuilder:
            ServerJinguiAcceptedTransportAttachedSessionEncodedRequestRecordsBuilder,
        serverKeyExchangePrivate: Array<Byte>,
        transportId!: String = "accepted-transport",
        readChunkSize!: Int64 = 4096,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let attached =
            attachJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloX25519Core(
                acceptedSocket,
                serverKeyExchangePrivate,
                transportId: transportId,
                readChunkSize: readChunkSize,
                policy: policy,
                notifyReadySnapshot: false
            )
        serveJinguiAcceptedTransportSessionApplicationDataH2BodylessRequestTurn(
            attached.session,
            acceptedSocket,
            app,
            encodedRequestRecordsBuilder(attached.session),
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }

    public func serveJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloApplicationDataH2ProvidedBodyRequestTurn(
        acceptedSocket: TcpSocket,
        app: App,
        encodedRequestRecordsBuilder:
            ServerJinguiAcceptedTransportAttachedSessionEncodedRequestRecordsBuilder,
        serverKeyExchangePrivate: Array<Byte>,
        bodyBytes!: Array<UInt8> = [],
        transportId!: String = "accepted-transport",
        readChunkSize!: Int64 = 4096,
        maxFragmentLen!: Int64 = 16384,
        closeSocketAfterTurn!: Bool = true,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ): ServerJinguiAcceptedTransportSocketResponseTurnResult {
        let attached =
            attachJinguiAcceptedTransportSocketFragmentedTlsHandshakeClientHelloX25519Core(
                acceptedSocket,
                serverKeyExchangePrivate,
                transportId: transportId,
                readChunkSize: readChunkSize,
                policy: policy,
                notifyReadySnapshot: false
            )
        serveJinguiAcceptedTransportSessionApplicationDataH2ProvidedBodyRequestTurn(
            attached.session,
            acceptedSocket,
            app,
            encodedRequestRecordsBuilder(attached.session),
            bodyBytes: bodyBytes,
            maxFragmentLen: maxFragmentLen,
            closeSocketAfterTurn: closeSocketAfterTurn
        )
    }
}

public class ServerEngineReadySignal {
    public let jinguiAttachResultSnapshot: ?ServerJinguiHttpServerAttachResultSnapshot

    public init(
        jinguiAttachResultSnapshot!: ?ServerJinguiHttpServerAttachResultSnapshot = None
    ) {
        this.jinguiAttachResultSnapshot = jinguiAttachResultSnapshot
    }
}

public interface ServerEngine {
    func listen(
        option: ServerEngineListenOption,
        app: App,
        onReady: ?((ServerEngineReadySignal) -> Unit)
    ): Unit

    func shutdown(): Unit
}

public interface ServerEngineTransportTouchpointOverride {
    func overrideTransportTouchpoint(
        addr: String,
        port: UInt16,
        tlsEnabled: Bool,
        baseTouchpoint: ServerTransportTouchpoint
    ): ServerTransportTouchpoint
}

public class SocketServerEngineShellException <: Exception {
    public init(message: String) {
        super(message)
    }
}

public class SocketServerEngineShell <: ServerEngine & ServerEngineTransportTouchpointOverride {
    public init() {}

    public override func overrideTransportTouchpoint(
        addr: String,
        port: UInt16,
        tlsEnabled: Bool,
        baseTouchpoint: ServerTransportTouchpoint
    ): ServerTransportTouchpoint {
        let _ = addr
        let _ = port
        let _ = tlsEnabled
        buildServerEngineOverrideTouchpoint(
            baseTouchpoint,
            "ignite-socket-server-shell",
            "opt_in_engine_shell_selected",
            "opt-in-engine-shell",
            "experimental",
            "cleartext_h1_first_runnable"
        )
    }

    public override func listen(
        option: ServerEngineListenOption,
        app: App,
        onReady: ?((ServerEngineReadySignal) -> Unit)
    ): Unit {
        runSocketServerEngineShellListen(option, app, onReady)
    }

    public override func shutdown(): Unit {}
}

public class StdxServerEngine <: ServerEngine {
    var _server: ?Server = None

    public init() {}

    public override func listen(
        option: ServerEngineListenOption,
        app: App,
        onReady: ?((ServerEngineReadySignal) -> Unit)
    ): Unit {
        let distributor = StdxServerEngineDistributor(app)
        let builder = ServerBuilder()
            .addr(option.addr)
            .port(option.port)
            .distributor(distributor)
            .readTimeout(option.readTimeout)
            .writeTimeout(option.writeTimeout)
            .readHeaderTimeout(option.readHeaderTimeout)
            .maxRequestBodySize(option.maxRequestBodySize)

        let hasTls = option.tlsCertFile.size > 0 && option.tlsKeyFile.size > 0
        if (hasTls) {
            let ingressContext = option.loadTlsIngressContext()
            let preparedMaterial = ingressContext.loadPreparedTlsMaterial()
            let tlsCfg = api2.buildStdxTlsServerConfigFromPreparedMaterial(
                preparedMaterial
            )
            let _ = builder.tlsConfig(tlsCfg)
        }

        let server = builder
            .afterBind({ =>
                if (let Some(cb) <- onReady) {
                    cb(ServerEngineReadySignal())
                }
            })
            .build()

        _server = server
        server.serve()
    }

    public override func shutdown(): Unit {
        if (let Some(s) <- _server) {
            s.closeGracefully()
            _server = None
        }
    }
}

class StdxServerEngineLambdaHandler <: HttpRequestHandler {
    let fn: (HttpContext) -> Unit

    init(fn: (HttpContext) -> Unit) {
        this.fn = fn
    }

    public func handle(ctx: HttpContext): Unit {
        fn(ctx)
    }
}

class StdxServerEngineAppMainHandler <: HttpRequestHandler {
    let app: App

    init(app: App) {
        this.app = app
    }

    public func handle(ctx: HttpContext): Unit {
        app.handleRequest(wrapCurrentRequestCarrier(ctx))
    }
}

class StdxServerEngineDistributor <: HttpRequestDistributor {
    let mainHandler: StdxServerEngineAppMainHandler

    init(app: App) {
        this.mainHandler = StdxServerEngineAppMainHandler(app)
    }

    private func usePathForLint(path: String): Unit {
        if (path.size >= 0) { }
    }

    private func useHandlerForLint(handler: HttpRequestHandler): Unit {
        let _ = handler
    }

    public func register(path: String, handler: HttpRequestHandler): Unit {
        usePathForLint(path)
        useHandlerForLint(handler)
    }

    public func registerRoute(path: String, handler: (HttpContext) -> Unit): Unit {
        usePathForLint(path)
        useHandlerForLint(StdxServerEngineLambdaHandler(handler))
    }

    public func distribute(path: String): HttpRequestHandler {
        usePathForLint(path)
        mainHandler
    }
}

func buildServerTransportRoutingBundle(
    addr: String,
    port: UInt16,
    tlsEnabled: Bool,
    preferredBackendHint!: String = "",
    allowExperimental!: Bool = false
): ServerTransportRoutingBundle {
    let normalizedHost = normalizeServerTouchpointHost(addr, port)
    let scheme = if (tlsEnabled) { "https" } else { "http" }
    let request = api2.BackendSelectionRequest(
        "server",
        scheme,
        false,
        false,
        false,
        preferredBackendHint,
        allowExperimental,
        0,
        "sni=" + normalizedHost
    )
    let decision = api2.selectBackend(request)
    let tlsPlan = api2.buildTlsAttachPlan(
        request,
        decision,
        normalizedHost
    )
    ServerTransportRoutingBundle(
        request,
        decision,
        tlsPlan
    )
}

func buildServerTransportTouchpoint(
    bundle: ServerTransportRoutingBundle
): ServerTransportTouchpoint {
    let decision = bundle.selectionDecision
    let tlsPlan = bundle.tlsAttachPlan
    ServerTransportTouchpoint(
        joinServerTouchpointFields(decision.candidateOrder),
        joinServerTouchpointFields(decision.blockedCandidates),
        normalizeServerBackendId(decision.selectedBackend),
        decision.selectedReason,
        normalizeServerProviderId(tlsPlan.providerId, tlsPlan.tlsEnabled),
        decision.publicPath,
        decision.riskLevel,
        tlsPlan.tlsEnabled,
        tlsPlan.fallbackReason
    )
}

func resolveServerTransportTouchpoint(
    engine: ServerEngine,
    addr: String,
    port: UInt16,
    baseTouchpoint: ServerTransportTouchpoint
): ServerTransportTouchpoint {
    let tlsEnabled = baseTouchpoint.tlsEnabled
    if (let Some(provider) <- (engine as ServerEngineTransportTouchpointOverride)) {
        return provider.overrideTransportTouchpoint(
            addr,
            port,
            tlsEnabled,
            baseTouchpoint
        )
    }
    baseTouchpoint
}

func buildServerEngineOverrideTouchpoint(
    baseTouchpoint: ServerTransportTouchpoint,
    selectedBackend: String,
    selectedReason: String,
    publicPath: String,
    riskLevel: String,
    fallbackReason: String
): ServerTransportTouchpoint {
    let candidateOrder = prependServerTouchpointCandidate(
        baseTouchpoint.candidateOrder,
        selectedBackend
    )
    ServerTransportTouchpoint(
        candidateOrder,
        baseTouchpoint.blockedCandidates,
        selectedBackend,
        selectedReason,
        baseTouchpoint.providerId,
        publicPath,
        riskLevel,
        baseTouchpoint.tlsEnabled,
        fallbackReason
    )
}

func normalizeServerTouchpointHost(addr: String, port: UInt16): String {
    let trimmed = addr.trimAscii()
    if (trimmed == "0.0.0.0" || trimmed == "::" || trimmed == "[::]") {
        return "127.0.0.1:${port}"
    }
    "${trimmed}:${port}"
}

func containsServerAlpnProtocol(values: Array<String>, target: String): Bool {
    let normalizedTarget = target.trimAscii().toAsciiLower()
    for (value in values) {
        if (value.trimAscii().toAsciiLower() == normalizedTarget) {
            return true
        }
    }
    false
}

func serverEngineUInt8ToByteArray(input: Array<UInt8>): Array<Byte> {
    let out = Array<Byte>(input.size, repeat: 0)
    var i: Int64 = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}

func cloneServerEngineUInt8Array(input: Array<UInt8>): Array<UInt8> {
    let out = Array<UInt8>(input.size, repeat: 0)
    var i: Int64 = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}

func cloneServerEngineByteWindow(
    input: Array<Byte>,
    start: Int64,
    size: Int64
): Array<Byte> {
    let out = Array<Byte>(size, repeat: 0)
    var i: Int64 = 0
    while (i < size) {
        out[i] = input[start + i]
        i += 1
    }
    out
}

func cloneServerEngineHeaders(headers: HttpHeaders): HttpHeaders {
    let out = HttpHeaders()
    for ((name, values) in headers) {
        for (value in values) {
            out.add(name, value)
        }
    }
    out
}

func buildServerAcceptedTransportDescriptorFromSocket(
    socket: TcpSocket,
    transportId: String
): ContractAcceptedTransportDescriptor {
    ContractAcceptedTransportDescriptor(
        transportId,
        localEndpoint: socket.localAddress.toString(),
        remoteEndpoint: socket.remoteAddress.toString()
    )
}

func cloneServerEngineByteListWindow(
    input: ArrayList<Byte>,
    start: Int64,
    size: Int64
): Array<Byte> {
    let out = Array<Byte>(size, repeat: 0)
    var i: Int64 = 0
    while (i < size) {
        out[i] = input[start + i]
        i += 1
    }
    out
}

func serverEngineByteToUInt8Array(input: Array<Byte>): Array<UInt8> {
    let out = Array<UInt8>(input.size, repeat: 0)
    var i: Int64 = 0
    while (i < input.size) {
        out[i] = UInt8(input[i])
        i += 1
    }
    out
}

func serverEngineByteRecordChunksToUInt8(
    records: Array<Array<Byte>>
): Array<Array<UInt8>> {
    let out = ArrayList<Array<UInt8>>()
    for (record in records) {
        out.add(serverEngineByteToUInt8Array(record))
    }
    out.toArray()
}

func joinServerTouchpointFields(values: Array<String>): String {
    if (values.size == 0) {
        return "-"
    }
    var out = ""
    var first = true
    for (value in values) {
        if (!first) {
            out += ","
        }
        first = false
        out += value
    }
    out
}

func prependServerTouchpointCandidate(existing: String, candidate: String): String {
    if (candidate.size == 0) {
        return existing
    }
    if (existing.size == 0 || existing == "-") {
        return candidate
    }
    candidate + "," + existing
}

func normalizeServerBackendId(raw: String): String {
    if (raw == "stdx-default") {
        return "stdx-http-server"
    }
    if (raw.size == 0) {
        return "-"
    }
    raw
}

func normalizeServerProviderId(raw: String, tlsEnabled: Bool): String {
    if (!tlsEnabled || raw.size == 0) {
        return "-"
    }
    if (raw == "stdx") {
        return "tls:stdx-default"
    }
    if (raw == "jinguissl") {
        return "tls:jinguissl"
    }
    "tls:" + raw
}

func serverBoolToJson(value: Bool): String {
    if (value) { "true" } else { "false" }
}

func serverEscapeJson(value: String): String {
    escapeJsonText(value)
}
