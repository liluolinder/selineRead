package ignite

import std.collection.ArrayList

public enum SocketHttp11BodyPlanErrorCode <: Equatable<SocketHttp11BodyPlanErrorCode> & ToString {
    | InvalidContentLength
    | ConflictingContentLength
    | ContentLengthWithTransferEncoding
    | UnsupportedTransferEncoding

    public operator func ==(right: SocketHttp11BodyPlanErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11BodyPlanErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case InvalidContentLength => 0
            case ConflictingContentLength => 1
            case ContentLengthWithTransferEncoding => 2
            case UnsupportedTransferEncoding => 3
        }
    }

    public func toString(): String {
        match (this) {
            case InvalidContentLength => "INVALID_CONTENT_LENGTH"
            case ConflictingContentLength => "CONFLICTING_CONTENT_LENGTH"
            case ContentLengthWithTransferEncoding => "CONTENT_LENGTH_WITH_TRANSFER_ENCODING"
            case UnsupportedTransferEncoding => "UNSUPPORTED_TRANSFER_ENCODING"
        }
    }
}

public class SocketHttp11BodyPlanException <: Exception {
    public let code: SocketHttp11BodyPlanErrorCode

    public init(code: SocketHttp11BodyPlanErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public enum SocketHttp11RequestBodyFraming <: Equatable<SocketHttp11RequestBodyFraming> & ToString {
    | Bodyless
    | ContentLength
    | Chunked

    public operator func ==(right: SocketHttp11RequestBodyFraming): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11RequestBodyFraming): Bool {
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

public class SocketHttp11RequestBodyPlan {
    public let framing: SocketHttp11RequestBodyFraming
    public let declaredBodyBytes: Int64
    public let remainingNetworkBodyBytes: Int64
    public let requiresBodyStage: Bool
    public let needsMoreNetworkBytes: Bool
    public let prefetchedBodyBytes: Array<UInt8>
    public let trailingBufferedBytes: Array<UInt8>

    public init(
        framing: SocketHttp11RequestBodyFraming,
        declaredBodyBytes: Int64,
        remainingNetworkBodyBytes: Int64,
        requiresBodyStage: Bool,
        needsMoreNetworkBytes: Bool,
        prefetchedBodyBytes: Array<UInt8>,
        trailingBufferedBytes: Array<UInt8>
    ) {
        this.framing = framing
        this.declaredBodyBytes = declaredBodyBytes
        this.remainingNetworkBodyBytes = remainingNetworkBodyBytes
        this.requiresBodyStage = requiresBodyStage
        this.needsMoreNetworkBytes = needsMoreNetworkBytes
        this.prefetchedBodyBytes = cloneSocketHttp11BodyBytes(prefetchedBodyBytes)
        this.trailingBufferedBytes = cloneSocketHttp11BodyBytes(trailingBufferedBytes)
    }

    public func bufferedBodyBytes(): Int64 {
        prefetchedBodyBytes.size
    }

    public func hasTrailingBufferedBytes(): Bool {
        trailingBufferedBytes.size > 0
    }

    public func supportsBoundedRelay(): Bool {
        framing == SocketHttp11RequestBodyFraming.ContentLength
    }
}

public func buildSocketHttp11RequestBodyPlan(
    head: SocketHttp11RequestHead,
    tail: Array<UInt8>
): SocketHttp11RequestBodyPlan {
    let transferEncodingTokens = collectSocketHttp11BodyCommaTokens(head, "transfer-encoding")
    let contentLengthValues = collectSocketHttp11BodyHeaderValues(head, "content-length")

    if (transferEncodingTokens.size > 0 && contentLengthValues.size > 0) {
        throw SocketHttp11BodyPlanException(
            SocketHttp11BodyPlanErrorCode.ContentLengthWithTransferEncoding,
            "HTTP/1.1 body plan rejects requests that mix content-length and transfer-encoding"
        )
    }

    if (transferEncodingTokens.size > 0) {
        if (!isSocketHttp11ChunkedOnlyTransferEncoding(transferEncodingTokens)) {
            throw SocketHttp11BodyPlanException(
                SocketHttp11BodyPlanErrorCode.UnsupportedTransferEncoding,
                "HTTP/1.1 body plan currently supports only chunked request transfer-encoding"
            )
        }
        return SocketHttp11RequestBodyPlan(
            SocketHttp11RequestBodyFraming.Chunked,
            -1,
            -1,
            true,
            true,
            tail,
            Array<UInt8>(0, repeat: 0)
        )
    }

    if (contentLengthValues.size > 0) {
        let declaredBodyBytes = parseSocketHttp11ContentLengthValues(contentLengthValues)
        let bodyPrefixBytes = if (tail.size > declaredBodyBytes) { declaredBodyBytes } else { tail.size }
        let prefetched = sliceSocketHttp11BodyBytes(tail, 0, bodyPrefixBytes)
        let trailing = if (tail.size > declaredBodyBytes) {
            sliceSocketHttp11BodyBytes(tail, declaredBodyBytes, tail.size)
        } else {
            Array<UInt8>(0, repeat: 0)
        }
        let remainingNetworkBodyBytes = declaredBodyBytes - prefetched.size
        let requiresBodyStage = declaredBodyBytes > 0
        let needsMoreNetworkBytes = remainingNetworkBodyBytes > 0
        return SocketHttp11RequestBodyPlan(
            SocketHttp11RequestBodyFraming.ContentLength,
            declaredBodyBytes,
            remainingNetworkBodyBytes,
            requiresBodyStage,
            needsMoreNetworkBytes,
            prefetched,
            trailing
        )
    }

    SocketHttp11RequestBodyPlan(
        SocketHttp11RequestBodyFraming.Bodyless,
        0,
        0,
        false,
        false,
        Array<UInt8>(0, repeat: 0),
        tail
    )
}

func collectSocketHttp11BodyHeaderValues(head: SocketHttp11RequestHead, name: String): Array<String> {
    let normalized = name.trimAscii().toAsciiLower()
    let out = ArrayList<String>()
    for (header in head.headers) {
        if (header.name == normalized) {
            out.add(header.value)
        }
    }
    out.toArray()
}

func collectSocketHttp11BodyCommaTokens(head: SocketHttp11RequestHead, name: String): Array<String> {
    let out = ArrayList<String>()
    let values = collectSocketHttp11BodyHeaderValues(head, name)
    for (value in values) {
        let parts = value.split(",")
        for (part in parts) {
            let token = part.trimAscii().toAsciiLower()
            if (token.size > 0) {
                out.add(token)
            }
        }
    }
    out.toArray()
}

func parseSocketHttp11ContentLengthValues(values: Array<String>): Int64 {
    var parsed: ?Int64 = None
    for (value in values) {
        let raw = value.trimAscii()
        let current = parseSocketHttp11BodyInt64Strict(raw)
        if (let None <- current) {
            throw SocketHttp11BodyPlanException(
                SocketHttp11BodyPlanErrorCode.InvalidContentLength,
                "HTTP/1.1 content-length must be a non-negative integer"
            )
        }
        let bodyBytes = current ?? -1
        if (bodyBytes < 0) {
            throw SocketHttp11BodyPlanException(
                SocketHttp11BodyPlanErrorCode.InvalidContentLength,
                "HTTP/1.1 content-length must be a non-negative integer"
            )
        }
        match (parsed) {
            case Some(existing) =>
                if (existing != bodyBytes) {
                    throw SocketHttp11BodyPlanException(
                        SocketHttp11BodyPlanErrorCode.ConflictingContentLength,
                        "HTTP/1.1 content-length headers must agree before the body stage begins"
                    )
                }
            case None =>
                parsed = Some(bodyBytes)
        }
    }
    parsed ?? 0
}

func isSocketHttp11ChunkedOnlyTransferEncoding(tokens: Array<String>): Bool {
    tokens.size == 1 && tokens[0] == "chunked"
}

func parseSocketHttp11BodyInt64Strict(text: String): ?Int64 {
    let raw = text.trimAscii()
    if (raw.size == 0) {
        return None
    }
    let chars = raw.toRuneArray()
    var i: Int64 = 0
    var sign: Int64 = 1
    if (chars[0] == r'-') {
        sign = -1
        i = 1
    } else if (chars[0] == r'+') {
        i = 1
    }
    if (i >= chars.size) {
        return None
    }
    var out: Int64 = 0
    while (i < chars.size) {
        let ch = chars[i]
        if (ch < r'0' || ch > r'9') {
            return None
        }
        out = out * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
        i += 1
    }
    Some(out * sign)
}

func cloneSocketHttp11BodyBytes(bytes: Array<UInt8>): Array<UInt8> {
    let out = Array<UInt8>(bytes.size, repeat: 0)
    for (i in 0..bytes.size) {
        out[i] = bytes[i]
    }
    out
}

func sliceSocketHttp11BodyBytes(bytes: Array<UInt8>, start: Int64, end: Int64): Array<UInt8> {
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
