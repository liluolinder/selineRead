package ignite

class SocketHttp11ResponseSnapshot {
    let version: String
    let statusCode: Int64
    let reasonPhrase: String
    let headers: Array<SocketHttp11Header>
    let requestedBodyMode: SocketHttp11ResponseBodyMode
    let headerFraming: SocketHttp11ResponseHeaderFraming
    let declaredBodyBytes: Int64
    let suppressesBodyForHead: Bool
    let suppressesBodyForStatus: Bool
    let keepAliveAllowed: Bool
    let closeAfterWrite: Bool

    init(
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
        closeAfterWrite: Bool
    ) {
        this.version = version
        this.statusCode = statusCode
        this.reasonPhrase = reasonPhrase
        this.headers = cloneSocketHttp11ResponseSnapshotHeaders(headers)
        this.requestedBodyMode = requestedBodyMode
        this.headerFraming = headerFraming
        this.declaredBodyBytes = declaredBodyBytes
        this.suppressesBodyForHead = suppressesBodyForHead
        this.suppressesBodyForStatus = suppressesBodyForStatus
        this.keepAliveAllowed = keepAliveAllowed
        this.closeAfterWrite = closeAfterWrite
    }

    func header(name: String): ?String {
        let normalized = name.trimAscii().toAsciiLower()
        for (header in headers) {
            if (header.name == normalized) {
                return Some(header.value)
            }
        }
        None
    }

    func writesPayloadBody(): Bool {
        if (suppressesBodyForHead || suppressesBodyForStatus) {
            return false
        }
        match (headerFraming) {
            case SocketHttp11ResponseHeaderFraming.Bodyless => false
            case SocketHttp11ResponseHeaderFraming.ContentLength => declaredBodyBytes > 0
            case SocketHttp11ResponseHeaderFraming.Chunked => true
        }
    }

    func usesChunkedTransfer(): Bool {
        headerFraming == SocketHttp11ResponseHeaderFraming.Chunked
    }

    func shouldCloseConnection(): Bool {
        closeAfterWrite
    }
}

func buildSocketHttp11ResponseSnapshot(
    plan: SocketHttp11ResponseWritePlan
): SocketHttp11ResponseSnapshot {
    SocketHttp11ResponseSnapshot(
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
        plan.closeAfterWrite
    )
}

func cloneSocketHttp11ResponseSnapshotHeaders(
    headers: Array<SocketHttp11Header>
): Array<SocketHttp11Header> {
    let out = Array<SocketHttp11Header>(headers.size, repeat: SocketHttp11Header("", ""))
    var i = 0
    while (i < headers.size) {
        let header = headers[i]
        out[i] = SocketHttp11Header(header.name, header.value)
        i += 1
    }
    out
}
