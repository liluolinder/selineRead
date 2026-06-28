package ignite

import std.collection.ArrayList

public enum SocketHttp11WriterErrorCode <: Equatable<SocketHttp11WriterErrorCode> & ToString {
    | InvalidStatusCode
    | InvalidKnownLength
    | ReservedProtocolHeader
    | BodyForbiddenByStatus
    | InvalidState
    | BodyNotAllowed
    | KnownLengthOverflow
    | KnownLengthIncomplete

    public operator func ==(right: SocketHttp11WriterErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11WriterErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case InvalidStatusCode => 0
            case InvalidKnownLength => 1
            case ReservedProtocolHeader => 2
            case BodyForbiddenByStatus => 3
            case InvalidState => 4
            case BodyNotAllowed => 5
            case KnownLengthOverflow => 6
            case KnownLengthIncomplete => 7
        }
    }

    public func toString(): String {
        match (this) {
            case InvalidStatusCode => "INVALID_STATUS_CODE"
            case InvalidKnownLength => "INVALID_KNOWN_LENGTH"
            case ReservedProtocolHeader => "RESERVED_PROTOCOL_HEADER"
            case BodyForbiddenByStatus => "BODY_FORBIDDEN_BY_STATUS"
            case InvalidState => "INVALID_STATE"
            case BodyNotAllowed => "BODY_NOT_ALLOWED"
            case KnownLengthOverflow => "KNOWN_LENGTH_OVERFLOW"
            case KnownLengthIncomplete => "KNOWN_LENGTH_INCOMPLETE"
        }
    }
}

public class SocketHttp11WriterException <: Exception {
    public let code: SocketHttp11WriterErrorCode

    public init(code: SocketHttp11WriterErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public enum SocketHttp11ResponseBodyMode <: Equatable<SocketHttp11ResponseBodyMode> & ToString {
    | Bodyless
    | KnownLength
    | UnknownLength

    public operator func ==(right: SocketHttp11ResponseBodyMode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11ResponseBodyMode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Bodyless => 0
            case KnownLength => 1
            case UnknownLength => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Bodyless => "BODYLESS"
            case KnownLength => "KNOWN_LENGTH"
            case UnknownLength => "UNKNOWN_LENGTH"
        }
    }
}

public enum SocketHttp11ResponseHeaderFraming <: Equatable<SocketHttp11ResponseHeaderFraming> & ToString {
    | Bodyless
    | ContentLength
    | Chunked

    public operator func ==(right: SocketHttp11ResponseHeaderFraming): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11ResponseHeaderFraming): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Bodyless => 0
            case ContentLength => 1
            case Chunked => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Bodyless => "BODYLESS"
            case ContentLength => "CONTENT_LENGTH"
            case Chunked => "CHUNKED"
        }
    }
}

public enum SocketHttp11WriterLifecycleState <: Equatable<SocketHttp11WriterLifecycleState> & ToString {
    | Ready
    | HeadCommitted
    | BodyStreaming
    | Completed
    | Failed

    public operator func ==(right: SocketHttp11WriterLifecycleState): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11WriterLifecycleState): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Ready => 0
            case HeadCommitted => 1
            case BodyStreaming => 2
            case Completed => 3
            case Failed => 4
        }
    }

    public func toString(): String {
        match (this) {
            case Ready => "READY"
            case HeadCommitted => "HEAD_COMMITTED"
            case BodyStreaming => "BODY_STREAMING"
            case Completed => "COMPLETED"
            case Failed => "FAILED"
        }
    }
}

public class SocketHttp11ResponseWriteOption {
    public let reasonPhrase: String
    public let closeAfterWrite: Bool

    public init(reasonPhrase!: String = "", closeAfterWrite!: Bool = false) {
        this.reasonPhrase = reasonPhrase.trimAscii()
        this.closeAfterWrite = closeAfterWrite
    }
}

public class SocketHttp11ResponseWritePlan {
    public let version: String
    public let statusCode: Int64
    public let reasonPhrase: String
    public let headers: Array<SocketHttp11Header>
    public let requestedBodyMode: SocketHttp11ResponseBodyMode
    public let headerFraming: SocketHttp11ResponseHeaderFraming
    public let declaredBodyBytes: Int64
    public let suppressesBodyForHead: Bool
    public let suppressesBodyForStatus: Bool
    public let keepAliveAllowed: Bool
    public let closeAfterWrite: Bool
    public let headBytes: Array<UInt8>

    public init(
        version: String,
        statusCode: Int64,
        reasonPhrase: String,
        headers: Array<SocketHttp11Header>,
        requestedBodyMode: SocketHttp11ResponseBodyMode,
        headerFraming: SocketHttp11ResponseHeaderFraming,
        declaredBodyBytes: Int64,
        suppressesBodyForHead: Bool,
        suppressesBodyForStatus: Bool,
        keepAliveAllowed: Bool,
        closeAfterWrite: Bool,
        headBytes: Array<UInt8>
    ) {
        this.version = version
        this.statusCode = statusCode
        this.reasonPhrase = reasonPhrase
        this.headers = cloneSocketHttp11WriterHeaders(headers)
        this.requestedBodyMode = requestedBodyMode
        this.headerFraming = headerFraming
        this.declaredBodyBytes = declaredBodyBytes
        this.suppressesBodyForHead = suppressesBodyForHead
        this.suppressesBodyForStatus = suppressesBodyForStatus
        this.keepAliveAllowed = keepAliveAllowed
        this.closeAfterWrite = closeAfterWrite
        this.headBytes = cloneSocketHttp11WriterBytes(headBytes)
    }

    public func writesPayloadBody(): Bool {
        if (suppressesBodyForHead || suppressesBodyForStatus) {
            return false
        }
        match (headerFraming) {
            case SocketHttp11ResponseHeaderFraming.Bodyless => false
            case SocketHttp11ResponseHeaderFraming.ContentLength => declaredBodyBytes > 0
            case SocketHttp11ResponseHeaderFraming.Chunked => true
        }
    }

    public func header(name: String): ?String {
        let normalized = name.trimAscii().toAsciiLower()
        for (header in headers) {
            if (header.name == normalized) {
                return Some(header.value)
            }
        }
        None
    }

    public func usesChunkedTransfer(): Bool {
        headerFraming == SocketHttp11ResponseHeaderFraming.Chunked
    }
}

public class SocketHttp11ResponseWriterLifecycle {
    public let plan: SocketHttp11ResponseWritePlan

    var _state: SocketHttp11WriterLifecycleState = SocketHttp11WriterLifecycleState.Ready
    var _bodyBytesWritten: Int64 = 0

    public init(plan: SocketHttp11ResponseWritePlan) {
        this.plan = SocketHttp11ResponseWritePlan(
            plan.version,
            plan.statusCode,
            plan.reasonPhrase,
            plan.headers,
            plan.requestedBodyMode,
            plan.headerFraming,
            plan.declaredBodyBytes,
            plan.suppressesBodyForHead,
            plan.suppressesBodyForStatus,
            plan.keepAliveAllowed,
            plan.closeAfterWrite,
            plan.headBytes
        )
    }

    public func state(): SocketHttp11WriterLifecycleState {
        _state
    }

    public func bodyBytesWritten(): Int64 {
        _bodyBytesWritten
    }

    public func shouldCloseConnection(): Bool {
        plan.closeAfterWrite
    }

    public func takeHeadBytes(): Array<UInt8> {
        ensureSocketHttp11WriterState(
            _state,
            SocketHttp11WriterLifecycleState.Ready,
            "socket HTTP/1.1 response writer can only commit response head once"
        )
        _state = SocketHttp11WriterLifecycleState.HeadCommitted
        cloneSocketHttp11WriterBytes(plan.headBytes)
    }

    public func writeBodyChunk(bytes: Array<UInt8>): Array<UInt8> {
        ensureSocketHttp11WriterOpenState(
            _state,
            "socket HTTP/1.1 response writer can only write body chunks after head commit"
        )
        if (bytes.size == 0) {
            return Array<UInt8>(0, repeat: 0)
        }
        if (!plan.writesPayloadBody()) {
            _state = SocketHttp11WriterLifecycleState.Failed
            throw SocketHttp11WriterException(
                SocketHttp11WriterErrorCode.BodyNotAllowed,
                "socket HTTP/1.1 response writer rejects payload bytes for current plan"
            )
        }

        match (plan.headerFraming) {
            case SocketHttp11ResponseHeaderFraming.Bodyless =>
                _state = SocketHttp11WriterLifecycleState.Failed
                throw SocketHttp11WriterException(
                    SocketHttp11WriterErrorCode.BodyNotAllowed,
                    "socket HTTP/1.1 response writer rejects payload bytes for bodyless framing"
                )
            case SocketHttp11ResponseHeaderFraming.ContentLength =>
                let nextTotal = _bodyBytesWritten + bytes.size
                if (nextTotal > plan.declaredBodyBytes) {
                    _state = SocketHttp11WriterLifecycleState.Failed
                    throw SocketHttp11WriterException(
                        SocketHttp11WriterErrorCode.KnownLengthOverflow,
                        "socket HTTP/1.1 response writer body bytes exceed declared content-length"
                    )
                }
                _bodyBytesWritten = nextTotal
                _state = SocketHttp11WriterLifecycleState.BodyStreaming
                cloneSocketHttp11WriterBytes(bytes)
            case SocketHttp11ResponseHeaderFraming.Chunked =>
                _bodyBytesWritten += bytes.size
                _state = SocketHttp11WriterLifecycleState.BodyStreaming
                buildSocketHttp11ChunkedResponseFrame(bytes)
        }
    }

    public func finish(): Array<UInt8> {
        ensureSocketHttp11WriterOpenState(
            _state,
            "socket HTTP/1.1 response writer can only finish while head/body stage is open"
        )

        let out = match (plan.headerFraming) {
            case SocketHttp11ResponseHeaderFraming.Bodyless =>
                Array<UInt8>(0, repeat: 0)
            case SocketHttp11ResponseHeaderFraming.ContentLength =>
                if (plan.writesPayloadBody() && _bodyBytesWritten != plan.declaredBodyBytes) {
                    _state = SocketHttp11WriterLifecycleState.Failed
                    throw SocketHttp11WriterException(
                        SocketHttp11WriterErrorCode.KnownLengthIncomplete,
                        "socket HTTP/1.1 response writer finished before declared content-length was fully written"
                    )
                }
                Array<UInt8>(0, repeat: 0)
            case SocketHttp11ResponseHeaderFraming.Chunked =>
                if (plan.writesPayloadBody()) {
                    "0\r\n\r\n".toArray()
                } else {
                    Array<UInt8>(0, repeat: 0)
                }
        }

        _state = SocketHttp11WriterLifecycleState.Completed
        out
    }
}

public func buildSocketHttp11ResponseWritePlan(
    request: SocketHttp11SessionRequest,
    statusCode: Int64,
    headers: Array<SocketHttp11Header>,
    bodyMode: SocketHttp11ResponseBodyMode,
    declaredBodyBytes!: Int64 = -1,
    option!: SocketHttp11ResponseWriteOption = SocketHttp11ResponseWriteOption()
): SocketHttp11ResponseWritePlan {
    if (statusCode < 100 || statusCode > 999) {
        throw SocketHttp11WriterException(
            SocketHttp11WriterErrorCode.InvalidStatusCode,
            "socket HTTP/1.1 response writer requires a three-digit status code"
        )
    }

    let normalizedHeaders = normalizeSocketHttp11ResponseHeaders(headers)
    let knownLength = resolveSocketHttp11KnownLength(bodyMode, declaredBodyBytes)
    let suppressesBodyForHead = request.head.method.trimAscii().toAsciiUpper() == "HEAD"
    let suppressesBodyForStatus = isSocketHttp11ResponseBodyForbiddenStatus(statusCode)
    let unknownLengthBody = bodyMode == SocketHttp11ResponseBodyMode.UnknownLength
    let knownLengthBody = bodyMode == SocketHttp11ResponseBodyMode.KnownLength

    if (suppressesBodyForStatus && unknownLengthBody) {
        throw SocketHttp11WriterException(
            SocketHttp11WriterErrorCode.BodyForbiddenByStatus,
            "socket HTTP/1.1 response status forbids unknown-length payload bodies"
        )
    }
    if (
        suppressesBodyForStatus &&
        knownLengthBody &&
        knownLength > 0
    ) {
        throw SocketHttp11WriterException(
            SocketHttp11WriterErrorCode.BodyForbiddenByStatus,
            "socket HTTP/1.1 response status forbids non-empty payload bodies"
        )
    }

    let headerFraming = decideSocketHttp11ResponseHeaderFraming(
        bodyMode,
        suppressesBodyForHead,
        suppressesBodyForStatus
    )
    let plannedBodyBytes = if (headerFraming == SocketHttp11ResponseHeaderFraming.ContentLength) {
        knownLength
    } else if (headerFraming == SocketHttp11ResponseHeaderFraming.Chunked) {
        -1
    } else {
        0
    }
    let reasonPhrase = resolveSocketHttp11ReasonPhrase(statusCode, option.reasonPhrase)
    let closeAfterWrite = request.closeAfterResponse || option.closeAfterWrite
    let responseHeaders = buildSocketHttp11PlannedResponseHeaders(
        normalizedHeaders,
        headerFraming,
        plannedBodyBytes,
        closeAfterWrite
    )
    let headBytes = serializeSocketHttp11ResponseHead(
        request.head.version,
        statusCode,
        reasonPhrase,
        responseHeaders
    )

    SocketHttp11ResponseWritePlan(
        request.head.version,
        statusCode,
        reasonPhrase,
        responseHeaders,
        bodyMode,
        headerFraming,
        plannedBodyBytes,
        suppressesBodyForHead,
        suppressesBodyForStatus,
        !closeAfterWrite,
        closeAfterWrite,
        headBytes
    )
}

func normalizeSocketHttp11ResponseHeaders(headers: Array<SocketHttp11Header>): Array<SocketHttp11Header> {
    let out = ArrayList<SocketHttp11Header>()
    for (header in headers) {
        let name = header.name.trimAscii().toAsciiLower()
        if (isSocketHttp11ReservedResponseHeader(name)) {
            throw SocketHttp11WriterException(
                SocketHttp11WriterErrorCode.ReservedProtocolHeader,
                "socket HTTP/1.1 response writer owns content-length/transfer-encoding/connection headers"
            )
        }
        out.add(SocketHttp11Header(name, header.value.trimAscii()))
    }
    out.toArray()
}

func resolveSocketHttp11KnownLength(bodyMode: SocketHttp11ResponseBodyMode, declaredBodyBytes: Int64): Int64 {
    if (bodyMode != SocketHttp11ResponseBodyMode.KnownLength) {
        return 0
    }
    if (declaredBodyBytes < 0) {
        throw SocketHttp11WriterException(
            SocketHttp11WriterErrorCode.InvalidKnownLength,
            "socket HTTP/1.1 response writer requires known-length bodies to be non-negative"
        )
    }
    declaredBodyBytes
}

func decideSocketHttp11ResponseHeaderFraming(
    bodyMode: SocketHttp11ResponseBodyMode,
    suppressesBodyForHead: Bool,
    suppressesBodyForStatus: Bool
): SocketHttp11ResponseHeaderFraming {
    if (suppressesBodyForStatus) {
        return SocketHttp11ResponseHeaderFraming.Bodyless
    }
    match (bodyMode) {
        case SocketHttp11ResponseBodyMode.Bodyless =>
            SocketHttp11ResponseHeaderFraming.Bodyless
        case SocketHttp11ResponseBodyMode.KnownLength =>
            SocketHttp11ResponseHeaderFraming.ContentLength
        case SocketHttp11ResponseBodyMode.UnknownLength =>
            if (suppressesBodyForHead) {
                SocketHttp11ResponseHeaderFraming.Bodyless
            } else {
                SocketHttp11ResponseHeaderFraming.Chunked
            }
    }
}

func buildSocketHttp11PlannedResponseHeaders(
    userHeaders: Array<SocketHttp11Header>,
    framing: SocketHttp11ResponseHeaderFraming,
    declaredBodyBytes: Int64,
    closeAfterWrite: Bool
): Array<SocketHttp11Header> {
    let out = ArrayList<SocketHttp11Header>()
    for (header in userHeaders) {
        out.add(SocketHttp11Header(header.name, header.value))
    }
    if (framing == SocketHttp11ResponseHeaderFraming.ContentLength) {
        out.add(SocketHttp11Header("content-length", declaredBodyBytes.toString()))
    } else if (framing == SocketHttp11ResponseHeaderFraming.Chunked) {
        out.add(SocketHttp11Header("transfer-encoding", "chunked"))
    }
    if (closeAfterWrite) {
        out.add(SocketHttp11Header("connection", "close"))
    }
    out.toArray()
}

func serializeSocketHttp11ResponseHead(
    version: String,
    statusCode: Int64,
    reasonPhrase: String,
    headers: Array<SocketHttp11Header>
): Array<UInt8> {
    let out = ArrayList<UInt8>()
    appendSocketHttp11WriterText(out, "${version} ${statusCode} ${reasonPhrase}\r\n")
    for (header in headers) {
        appendSocketHttp11WriterText(out, "${header.name}: ${header.value}\r\n")
    }
    appendSocketHttp11WriterText(out, "\r\n")
    out.toArray()
}

func appendSocketHttp11WriterText(out: ArrayList<UInt8>, text: String): Unit {
    for (b in text.toArray()) {
        out.add(b)
    }
}

func resolveSocketHttp11ReasonPhrase(statusCode: Int64, configured: String): String {
    let phrase = configured.trimAscii()
    if (phrase.size > 0) {
        return phrase
    }
    defaultSocketHttp11ReasonPhrase(statusCode)
}

func defaultSocketHttp11ReasonPhrase(statusCode: Int64): String {
    match (statusCode) {
        case 100 => "Continue"
        case 101 => "Switching Protocols"
        case 200 => "OK"
        case 201 => "Created"
        case 202 => "Accepted"
        case 204 => "No Content"
        case 206 => "Partial Content"
        case 301 => "Moved Permanently"
        case 302 => "Found"
        case 304 => "Not Modified"
        case 400 => "Bad Request"
        case 401 => "Unauthorized"
        case 403 => "Forbidden"
        case 404 => "Not Found"
        case 405 => "Method Not Allowed"
        case 409 => "Conflict"
        case 413 => "Payload Too Large"
        case 500 => "Internal Server Error"
        case 501 => "Not Implemented"
        case 502 => "Bad Gateway"
        case 503 => "Service Unavailable"
        case 504 => "Gateway Timeout"
        case _ => "Status"
    }
}

func isSocketHttp11ResponseBodyForbiddenStatus(statusCode: Int64): Bool {
    (statusCode >= 100 && statusCode < 200) || statusCode == 204 || statusCode == 304
}

func isSocketHttp11ReservedResponseHeader(name: String): Bool {
    name == "content-length" || name == "transfer-encoding" || name == "connection"
}

func ensureSocketHttp11WriterState(
    actual: SocketHttp11WriterLifecycleState,
    expected: SocketHttp11WriterLifecycleState,
    message: String
): Unit {
    if (actual != expected) {
        throw SocketHttp11WriterException(
            SocketHttp11WriterErrorCode.InvalidState,
            "${message}: expected ${expected.toString()}, got ${actual.toString()}"
        )
    }
}

func ensureSocketHttp11WriterOpenState(actual: SocketHttp11WriterLifecycleState, message: String): Unit {
    if (
        actual == SocketHttp11WriterLifecycleState.Ready ||
        actual == SocketHttp11WriterLifecycleState.Completed ||
        actual == SocketHttp11WriterLifecycleState.Failed
    ) {
        throw SocketHttp11WriterException(
            SocketHttp11WriterErrorCode.InvalidState,
            "${message}: got ${actual.toString()}"
        )
    }
}

func buildSocketHttp11ChunkedResponseFrame(bytes: Array<UInt8>): Array<UInt8> {
    let out = ArrayList<UInt8>()
    appendSocketHttp11WriterText(out, "${socketHttp11Int64ToHex(bytes.size)}\r\n")
    for (b in bytes) {
        out.add(b)
    }
    appendSocketHttp11WriterText(out, "\r\n")
    out.toArray()
}

func socketHttp11Int64ToHex(value: Int64): String {
    if (value < 10) {
        return value.toString()
    }
    let hex = "0123456789abcdef".toRuneArray()
    if (value < 16) {
        return hex[value].toString()
    }
    socketHttp11Int64ToHex(value / 16) + hex[value % 16].toString()
}

func cloneSocketHttp11WriterHeaders(headers: Array<SocketHttp11Header>): Array<SocketHttp11Header> {
    let out = Array<SocketHttp11Header>(headers.size, repeat: SocketHttp11Header("", ""))
    for (i in 0..headers.size) {
        out[i] = SocketHttp11Header(headers[i].name, headers[i].value)
    }
    out
}

func cloneSocketHttp11WriterBytes(bytes: Array<UInt8>): Array<UInt8> {
    if (bytes.size == 0) {
        return Array<UInt8>(0, repeat: 0)
    }
    let out = Array<UInt8>(bytes.size, repeat: 0)
    for (i in 0..bytes.size) {
        out[i] = bytes[i]
    }
    out
}
