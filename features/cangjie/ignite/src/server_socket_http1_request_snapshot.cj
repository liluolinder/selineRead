package ignite

enum SocketHttp11RequestSnapshotErrorCode <: Equatable<SocketHttp11RequestSnapshotErrorCode> & ToString {
    | MethodMismatch
    | TargetMismatch

    public operator func ==(right: SocketHttp11RequestSnapshotErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11RequestSnapshotErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case MethodMismatch => 0
            case TargetMismatch => 1
        }
    }

    public func toString(): String {
        match (this) {
            case MethodMismatch => "METHOD_MISMATCH"
            case TargetMismatch => "TARGET_MISMATCH"
        }
    }
}

class SocketHttp11RequestSnapshotException <: Exception {
    let code: SocketHttp11RequestSnapshotErrorCode

    init(code: SocketHttp11RequestSnapshotErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

class SocketHttp11RequestSnapshot {
    let method: String
    let version: String
    let remoteAddress: String
    let rawTarget: String
    let targetForm: SocketHttp11RequestTargetForm
    let dispatchPath: ?String
    let queryString: String
    let authority: String
    let scheme: String
    let headers: Array<SocketHttp11Header>
    let bodyPlan: SocketHttp11RequestBodyPlan

    init(
        method: String,
        version: String,
        remoteAddress: String,
        rawTarget: String,
        targetForm: SocketHttp11RequestTargetForm,
        dispatchPath!: ?String = None,
        queryString!: String = "",
        authority!: String = "",
        scheme!: String = "",
        headers!: Array<SocketHttp11Header> = Array<SocketHttp11Header>(0, repeat: SocketHttp11Header("", "")),
        bodyPlan!: SocketHttp11RequestBodyPlan
    ) {
        this.method = method
        this.version = version
        this.remoteAddress = remoteAddress
        this.rawTarget = rawTarget
        this.targetForm = targetForm
        this.dispatchPath = dispatchPath
        this.queryString = queryString
        this.authority = authority
        this.scheme = scheme
        this.headers = cloneSocketHttp11Headers(headers)
        this.bodyPlan = SocketHttp11RequestBodyPlan(
            bodyPlan.framing,
            bodyPlan.declaredBodyBytes,
            bodyPlan.remainingNetworkBodyBytes,
            bodyPlan.requiresBodyStage,
            bodyPlan.needsMoreNetworkBytes,
            bodyPlan.prefetchedBodyBytes,
            bodyPlan.trailingBufferedBytes
        )
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

    func canResolveDispatchPlan(): Bool {
        match (dispatchPath) {
            case Some(_) => true
            case None => false
        }
    }

    func normalizedDispatchTarget(): String {
        match (dispatchPath) {
            case Some(path) =>
                if (queryString.size == 0) {
                    path
                } else {
                    path + "?" + queryString
                }
            case None => rawTarget
        }
    }

    func targetFormName(): String {
        targetForm.toString()
    }
}

func buildSocketHttp11RequestSnapshot(
    request: SocketHttp11SessionRequest,
    seed: SocketHttp11DispatchSeed,
    remoteAddress!: String = ""
): SocketHttp11RequestSnapshot {
    if (request.head.method != seed.requestMethod) {
        throw SocketHttp11RequestSnapshotException(
            SocketHttp11RequestSnapshotErrorCode.MethodMismatch,
            "socket HTTP/1.1 request snapshot requires request method and dispatch seed method to match"
        )
    }

    let normalizedTarget = request.head.target.trimAscii()
    if (normalizedTarget != seed.rawTarget) {
        throw SocketHttp11RequestSnapshotException(
            SocketHttp11RequestSnapshotErrorCode.TargetMismatch,
            "socket HTTP/1.1 request snapshot requires request target and dispatch seed target to match"
        )
    }

    SocketHttp11RequestSnapshot(
        request.head.method,
        request.head.version,
        remoteAddress.trimAscii(),
        seed.rawTarget,
        seed.targetForm,
        dispatchPath: seed.dispatchPath,
        queryString: seed.queryString,
        authority: seed.authority,
        scheme: seed.scheme,
        headers: request.head.headers,
        bodyPlan: request.bodyPlan
    )
}
