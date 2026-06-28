package ignite

import std.collection.ArrayList

public enum SocketHttp11SessionErrorCode <: Equatable<SocketHttp11SessionErrorCode> & ToString {
    | InvalidState
    | InvalidContentLength
    | ConflictingContentLength
    | ContentLengthWithTransferEncoding
    | UnsupportedTransferEncoding

    public operator func ==(right: SocketHttp11SessionErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11SessionErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case InvalidState => 0
            case InvalidContentLength => 1
            case ConflictingContentLength => 2
            case ContentLengthWithTransferEncoding => 3
            case UnsupportedTransferEncoding => 4
        }
    }

    public func toString(): String {
        match (this) {
            case InvalidState => "INVALID_STATE"
            case InvalidContentLength => "INVALID_CONTENT_LENGTH"
            case ConflictingContentLength => "CONFLICTING_CONTENT_LENGTH"
            case ContentLengthWithTransferEncoding => "CONTENT_LENGTH_WITH_TRANSFER_ENCODING"
            case UnsupportedTransferEncoding => "UNSUPPORTED_TRANSFER_ENCODING"
        }
    }
}

public class SocketHttp11SessionException <: Exception {
    public let code: SocketHttp11SessionErrorCode

    public init(code: SocketHttp11SessionErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public enum SocketHttp11ConnectionState <: Equatable<SocketHttp11ConnectionState> & ToString {
    | ReceivingHead
    | AwaitingBody
    | ReadyToDispatch
    | WritingResponse
    | Closing
    | Closed
    | Failed

    public operator func ==(right: SocketHttp11ConnectionState): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11ConnectionState): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ReceivingHead => 0
            case AwaitingBody => 1
            case ReadyToDispatch => 2
            case WritingResponse => 3
            case Closing => 4
            case Closed => 5
            case Failed => 6
        }
    }

    public func toString(): String {
        match (this) {
            case ReceivingHead => "RECEIVING_HEAD"
            case AwaitingBody => "AWAITING_BODY"
            case ReadyToDispatch => "READY_TO_DISPATCH"
            case WritingResponse => "WRITING_RESPONSE"
            case Closing => "CLOSING"
            case Closed => "CLOSED"
            case Failed => "FAILED"
        }
    }
}

public class SocketHttp11SessionRequest {
    public let head: SocketHttp11RequestHead
    public let bodyPlan: SocketHttp11RequestBodyPlan
    public let keepAliveAllowed: Bool
    public let closeAfterResponse: Bool
    public let allowPipelining: Bool
    public let pipelinedBytesDetected: Bool
    public let closeReason: String

    public init(
        head: SocketHttp11RequestHead,
        bodyPlan: SocketHttp11RequestBodyPlan,
        keepAliveAllowed: Bool,
        closeAfterResponse: Bool,
        allowPipelining: Bool,
        pipelinedBytesDetected: Bool,
        closeReason: String
    ) {
        this.head = SocketHttp11RequestHead(
            head.method,
            head.target,
            head.version,
            head.headers,
            head.headBytes
        )
        this.bodyPlan = SocketHttp11RequestBodyPlan(
            bodyPlan.framing,
            bodyPlan.declaredBodyBytes,
            bodyPlan.remainingNetworkBodyBytes,
            bodyPlan.requiresBodyStage,
            bodyPlan.needsMoreNetworkBytes,
            bodyPlan.prefetchedBodyBytes,
            bodyPlan.trailingBufferedBytes
        )
        this.keepAliveAllowed = keepAliveAllowed
        this.closeAfterResponse = closeAfterResponse
        this.allowPipelining = allowPipelining
        this.pipelinedBytesDetected = pipelinedBytesDetected
        this.closeReason = closeReason
    }
}

public class SocketHttp11ConnectionSessionOption {
    public let headParseOption: SocketHttp11HeadParseOption

    public init(headParseOption!: SocketHttp11HeadParseOption = SocketHttp11HeadParseOption()) {
        this.headParseOption = headParseOption
    }
}

public class SocketHttp11ConnectionSession {
    public let option: SocketHttp11ConnectionSessionOption

    var _state: SocketHttp11ConnectionState = SocketHttp11ConnectionState.ReceivingHead
    var _headBuffer: ArrayList<UInt8> = ArrayList<UInt8>()
    var _currentRequest: ?SocketHttp11SessionRequest = None

    public init(option!: SocketHttp11ConnectionSessionOption = SocketHttp11ConnectionSessionOption()) {
        this.option = option
    }

    public func state(): SocketHttp11ConnectionState {
        _state
    }

    public func bufferedHeadBytes(): Int64 {
        _headBuffer.size
    }

    public func currentRequest(): ?SocketHttp11SessionRequest {
        _currentRequest
    }

    public func appendHeadBytes(bytes: Array<UInt8>): Unit {
        ensureSocketHttp11SessionState(
            _state,
            SocketHttp11ConnectionState.ReceivingHead,
            "socket session only buffers request-head bytes while receiving head"
        )
        for (b in bytes) {
            _headBuffer.add(b)
        }
    }

    public func tryOpenRequest(): ?SocketHttp11SessionRequest {
        ensureSocketHttp11SessionState(
            _state,
            SocketHttp11ConnectionState.ReceivingHead,
            "socket session can only parse a request while receiving head bytes"
        )
        let buffered = _headBuffer.toArray()
        match (tryParseSocketHttp11RequestHead(buffered, option: option.headParseOption)) {
            case Some(head) =>
                let tail = sliceSocketHttp11SessionBytes(buffered, head.bodyOffset, buffered.size)
                let request = buildSocketHttp11SessionRequest(head, tail)
                _currentRequest = Some(request)
                _headBuffer = ArrayList<UInt8>()
                if (request.bodyPlan.requiresBodyStage) {
                    _state = SocketHttp11ConnectionState.AwaitingBody
                } else {
                    _state = SocketHttp11ConnectionState.ReadyToDispatch
                }
                Some(request)
            case None => None
        }
    }

    public func markRequestBodyReady(): Unit {
        ensureSocketHttp11SessionState(
            _state,
            SocketHttp11ConnectionState.AwaitingBody,
            "socket session can only mark request body ready after a body-stage handoff"
        )
        _state = SocketHttp11ConnectionState.ReadyToDispatch
    }

    public func beginResponseWrite(): Unit {
        ensureSocketHttp11SessionState(
            _state,
            SocketHttp11ConnectionState.ReadyToDispatch,
            "socket session can only begin response write once request dispatch is ready"
        )
        _state = SocketHttp11ConnectionState.WritingResponse
    }

    public func finishResponseWrite(): Unit {
        ensureSocketHttp11SessionState(
            _state,
            SocketHttp11ConnectionState.WritingResponse,
            "socket session can only finish a response while the writer stage is active"
        )
        var shouldClose = true
        if (let Some(request) <- _currentRequest) {
            shouldClose = request.closeAfterResponse
        }
        _currentRequest = None
        if (shouldClose) {
            _state = SocketHttp11ConnectionState.Closing
        } else {
            _state = SocketHttp11ConnectionState.ReceivingHead
        }
    }

    public func markClosing(): Unit {
        if (_state == SocketHttp11ConnectionState.Closed) {
            return
        }
        _state = SocketHttp11ConnectionState.Closing
    }

    public func markClosed(): Unit {
        _state = SocketHttp11ConnectionState.Closed
        _currentRequest = None
        _headBuffer = ArrayList<UInt8>()
    }

    public func markFailed(): Unit {
        _state = SocketHttp11ConnectionState.Failed
        _currentRequest = None
        _headBuffer = ArrayList<UInt8>()
    }
}

func buildSocketHttp11SessionRequest(
    head: SocketHttp11RequestHead,
    tail: Array<UInt8>
): SocketHttp11SessionRequest {
    let connectionCloseRequested = socketHttp11ConnectionCloseRequested(head)
    let allowPipelining = false
    let bodyPlan = try {
        buildSocketHttp11RequestBodyPlan(head, tail)
    } catch (e: SocketHttp11BodyPlanException) {
        throw mapSocketHttp11BodyPlanException(e)
    }
    let pipelinedBytesDetected = bodyPlan.hasTrailingBufferedBytes()
    let closeAfterResponse = connectionCloseRequested || pipelinedBytesDetected
    let closeReason = if (pipelinedBytesDetected) {
        "pipelining_not_supported"
    } else if (connectionCloseRequested) {
        "connection_close_header"
    } else {
        "-"
    }
    SocketHttp11SessionRequest(
        head,
        bodyPlan,
        !closeAfterResponse,
        closeAfterResponse,
        allowPipelining,
        pipelinedBytesDetected,
        closeReason
    )
}

func ensureSocketHttp11SessionState(
    actual: SocketHttp11ConnectionState,
    expected: SocketHttp11ConnectionState,
    message: String
): Unit {
    if (actual != expected) {
        throw SocketHttp11SessionException(
            SocketHttp11SessionErrorCode.InvalidState,
            "${message}: expected ${expected.toString()}, got ${actual.toString()}"
        )
    }
}

func socketHttp11ConnectionCloseRequested(head: SocketHttp11RequestHead): Bool {
    let out = ArrayList<String>()
    let values = socketHttp11HeaderValues(head, "connection")
    for (value in values) {
        let parts = value.split(",")
        for (part in parts) {
            let token = part.trimAscii().toAsciiLower()
            if (token.size > 0) {
                out.add(token)
            }
        }
    }
    socketHttp11StringArrayContains(out.toArray(), "close")
}

func socketHttp11HeaderValues(head: SocketHttp11RequestHead, name: String): Array<String> {
    let normalized = name.trimAscii().toAsciiLower()
    let out = ArrayList<String>()
    for (header in head.headers) {
        if (header.name == normalized) {
            out.add(header.value)
        }
    }
    out.toArray()
}

func mapSocketHttp11BodyPlanException(e: SocketHttp11BodyPlanException): SocketHttp11SessionException {
    let sessionCode = match (e.code) {
        case SocketHttp11BodyPlanErrorCode.InvalidContentLength => SocketHttp11SessionErrorCode.InvalidContentLength
        case SocketHttp11BodyPlanErrorCode.ConflictingContentLength =>
            SocketHttp11SessionErrorCode.ConflictingContentLength
        case SocketHttp11BodyPlanErrorCode.ContentLengthWithTransferEncoding =>
            SocketHttp11SessionErrorCode.ContentLengthWithTransferEncoding
        case SocketHttp11BodyPlanErrorCode.UnsupportedTransferEncoding =>
            SocketHttp11SessionErrorCode.UnsupportedTransferEncoding
    }
    SocketHttp11SessionException(sessionCode, e.message)
}

func socketHttp11StringArrayContains(values: Array<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    false
}

func sliceSocketHttp11SessionBytes(bytes: Array<UInt8>, start: Int64, end: Int64): Array<UInt8> {
    if (end <= start) {
        return Array<UInt8>(0, repeat: 0)
    }
    let length = end - start
    let out = Array<UInt8>(length, repeat: 0)
    var i: Int64 = 0
    while (i < length) {
        out[i] = bytes[start + i]
        i += 1
    }
    out
}
