package ignite

import std.collection.ArrayList

public enum SocketHttp11HeadErrorCode <: Equatable<SocketHttp11HeadErrorCode> & ToString {
    | LimitExceeded
    | MalformedRequestLine
    | UnsupportedVersion
    | MalformedHeader
    | InvalidHeaderName

    public operator func ==(right: SocketHttp11HeadErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11HeadErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case LimitExceeded => 0
            case MalformedRequestLine => 1
            case UnsupportedVersion => 2
            case MalformedHeader => 3
            case InvalidHeaderName => 4
        }
    }

    public func toString(): String {
        match (this) {
            case LimitExceeded => "LIMIT_EXCEEDED"
            case MalformedRequestLine => "MALFORMED_REQUEST_LINE"
            case UnsupportedVersion => "UNSUPPORTED_VERSION"
            case MalformedHeader => "MALFORMED_HEADER"
            case InvalidHeaderName => "INVALID_HEADER_NAME"
        }
    }
}

public class SocketHttp11HeadException <: Exception {
    public let code: SocketHttp11HeadErrorCode

    public init(code: SocketHttp11HeadErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public struct SocketHttp11Header {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

public class SocketHttp11RequestHead {
    public let method: String
    public let target: String
    public let version: String
    public let headers: Array<SocketHttp11Header>
    public let headBytes: Int64
    public let bodyOffset: Int64

    public init(
        method: String,
        target: String,
        version: String,
        headers: Array<SocketHttp11Header>,
        headBytes: Int64
    ) {
        this.method = method
        this.target = target
        this.version = version
        this.headers = cloneSocketHttp11Headers(headers)
        this.headBytes = headBytes
        this.bodyOffset = headBytes
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
}

public class SocketHttp11HeadParseOption {
    public let maxHeaderBytes: Int64
    public let maxHeaderCount: Int64
    public let maxRequestLineBytes: Int64

    public init(
        maxHeaderBytes!: Int64 = 16 * 1024,
        maxHeaderCount!: Int64 = 100,
        maxRequestLineBytes!: Int64 = 4 * 1024
    ) {
        this.maxHeaderBytes = if (maxHeaderBytes > 0) { maxHeaderBytes } else { 16 * 1024 }
        this.maxHeaderCount = if (maxHeaderCount > 0) { maxHeaderCount } else { 100 }
        this.maxRequestLineBytes = if (maxRequestLineBytes > 0) { maxRequestLineBytes } else { 4 * 1024 }
    }
}

public func tryParseSocketHttp11RequestHead(
    bytes: Array<UInt8>,
    option!: SocketHttp11HeadParseOption = SocketHttp11HeadParseOption()
): ?SocketHttp11RequestHead {
    let headStart = findSocketHttp11HeadTerminator(bytes)
    if (headStart < 0) {
        if (bytes.size > option.maxHeaderBytes) {
            throw SocketHttp11HeadException(
                SocketHttp11HeadErrorCode.LimitExceeded,
                "HTTP/1.1 request head exceeds configured byte limit before terminator"
            )
        }
        return None
    }

    let consumedBytes = headStart + 4
    if (consumedBytes > option.maxHeaderBytes) {
        throw SocketHttp11HeadException(
            SocketHttp11HeadErrorCode.LimitExceeded,
            "HTTP/1.1 request head exceeds configured byte limit"
        )
    }

    let headText = decodeSocketHttp11HeadText(bytes, headStart)
    let lines = headText.split("\r\n")
    if (lines.size == 0) {
        throw SocketHttp11HeadException(
            SocketHttp11HeadErrorCode.MalformedRequestLine,
            "missing HTTP/1.1 request line"
        )
    }

    let requestLine = lines[0]
    if (requestLine.size == 0) {
        throw SocketHttp11HeadException(
            SocketHttp11HeadErrorCode.MalformedRequestLine,
            "empty HTTP/1.1 request line"
        )
    }
    if (requestLine.size > option.maxRequestLineBytes) {
        throw SocketHttp11HeadException(
            SocketHttp11HeadErrorCode.LimitExceeded,
            "HTTP/1.1 request line exceeds configured byte limit"
        )
    }

    let requestLineParts = requestLine.split(" ")
    if (requestLineParts.size != 3) {
        throw SocketHttp11HeadException(
            SocketHttp11HeadErrorCode.MalformedRequestLine,
            "HTTP/1.1 request line must contain method, target, and version"
        )
    }

    let method = requestLineParts[0]
    let target = requestLineParts[1]
    let version = requestLineParts[2]
    let validMethod = isSocketHttp11Token(method)
    if (method.size == 0 || target.size == 0 || !validMethod) {
        throw SocketHttp11HeadException(
            SocketHttp11HeadErrorCode.MalformedRequestLine,
            "HTTP/1.1 request line contains an invalid method or target"
        )
    }
    if (version != "HTTP/1.1") {
        throw SocketHttp11HeadException(
            SocketHttp11HeadErrorCode.UnsupportedVersion,
            "only HTTP/1.1 request heads are accepted by the socket parser foundation"
        )
    }

    let headers = ArrayList<SocketHttp11Header>()
    for (i in 1..lines.size) {
        let line = lines[i]
        if (line.size == 0) {
            throw SocketHttp11HeadException(
                SocketHttp11HeadErrorCode.MalformedHeader,
                "unexpected empty header line before terminator"
            )
        }
        if (headers.size >= option.maxHeaderCount) {
            throw SocketHttp11HeadException(
                SocketHttp11HeadErrorCode.LimitExceeded,
                "HTTP/1.1 header count exceeds configured limit"
            )
        }

        let colonIndex = line.indexOf(":")
        if (let None <- colonIndex) {
            throw SocketHttp11HeadException(
                SocketHttp11HeadErrorCode.MalformedHeader,
                "HTTP/1.1 header line must contain a name and ':'"
            )
        }
        let colon = colonIndex ?? -1
        if (colon <= 0) {
            throw SocketHttp11HeadException(
                SocketHttp11HeadErrorCode.MalformedHeader,
                "HTTP/1.1 header line must contain a name and ':'"
            )
        }

        let name = line[..colon]
        if (!isSocketHttp11HeaderName(name)) {
            throw SocketHttp11HeadException(
                SocketHttp11HeadErrorCode.InvalidHeaderName,
                "HTTP/1.1 header name contains an invalid token character"
            )
        }

        let value = line[colon + 1..line.size].trimAscii()
        headers.add(SocketHttp11Header(name.toAsciiLower(), value))
    }

    Some(
        SocketHttp11RequestHead(
            method,
            target,
            version,
            headers.toArray(),
            consumedBytes
        )
    )
}

func cloneSocketHttp11Headers(headers: Array<SocketHttp11Header>): Array<SocketHttp11Header> {
    let out = Array<SocketHttp11Header>(headers.size, repeat: SocketHttp11Header("", ""))
    for (i in 0..headers.size) {
        out[i] = SocketHttp11Header(headers[i].name, headers[i].value)
    }
    out
}

func findSocketHttp11HeadTerminator(bytes: Array<UInt8>): Int64 {
    if (bytes.size < 4) {
        return -1
    }
    var i: Int64 = 0
    while (i <= bytes.size - 4) {
        if (
            bytes[i] == UInt8(13) &&
            bytes[i + 1] == UInt8(10) &&
            bytes[i + 2] == UInt8(13) &&
            bytes[i + 3] == UInt8(10)
        ) {
            return i
        }
        i += 1
    }
    -1
}

func decodeSocketHttp11HeadText(bytes: Array<UInt8>, length: Int64): String {
    if (length <= 0) {
        return ""
    }
    let out = Array<UInt8>(length, repeat: 0)
    for (i in 0..length) {
        out[i] = bytes[i]
    }
    String.fromUtf8(out)
}

func isSocketHttp11HeaderName(input: String): Bool {
    if (input.size == 0) {
        return false
    }
    isSocketHttp11Token(input)
}

func isSocketHttp11Token(input: String): Bool {
    let allowed = "!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".toRuneArray()
    for (ch in input.toRuneArray()) {
        if (!socketHttp11AllowedContains(allowed, ch)) {
            return false
        }
    }
    true
}

func socketHttp11AllowedContains(allowed: Array<Rune>, target: Rune): Bool {
    for (item in allowed) {
        if (item == target) {
            return true
        }
    }
    false
}
