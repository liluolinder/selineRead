package ignite

enum SocketHttp11RequestTargetForm <: Equatable<SocketHttp11RequestTargetForm> & ToString {
    | OriginForm
    | AbsoluteForm
    | AuthorityForm
    | AsteriskForm

    public operator func ==(right: SocketHttp11RequestTargetForm): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11RequestTargetForm): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case OriginForm => 0
            case AbsoluteForm => 1
            case AuthorityForm => 2
            case AsteriskForm => 3
        }
    }

    public func toString(): String {
        match (this) {
            case OriginForm => "origin-form"
            case AbsoluteForm => "absolute-form"
            case AuthorityForm => "authority-form"
            case AsteriskForm => "asterisk-form"
        }
    }
}

enum SocketHttp11DispatchSeedErrorCode <: Equatable<SocketHttp11DispatchSeedErrorCode> & ToString {
    | InvalidTarget
    | FragmentNotAllowed
    | UnsupportedAbsoluteScheme
    | MissingAbsoluteAuthority

    public operator func ==(right: SocketHttp11DispatchSeedErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SocketHttp11DispatchSeedErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case InvalidTarget => 0
            case FragmentNotAllowed => 1
            case UnsupportedAbsoluteScheme => 2
            case MissingAbsoluteAuthority => 3
        }
    }

    public func toString(): String {
        match (this) {
            case InvalidTarget => "INVALID_TARGET"
            case FragmentNotAllowed => "FRAGMENT_NOT_ALLOWED"
            case UnsupportedAbsoluteScheme => "UNSUPPORTED_ABSOLUTE_SCHEME"
            case MissingAbsoluteAuthority => "MISSING_ABSOLUTE_AUTHORITY"
        }
    }
}

class SocketHttp11DispatchSeedException <: Exception {
    let code: SocketHttp11DispatchSeedErrorCode

    init(code: SocketHttp11DispatchSeedErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

class SocketHttp11DispatchSeed {
    let requestMethod: String
    let rawTarget: String
    let targetForm: SocketHttp11RequestTargetForm
    let dispatchPath: ?String
    let queryString: String
    let authority: String
    let scheme: String

    init(
        requestMethod: String,
        rawTarget: String,
        targetForm: SocketHttp11RequestTargetForm,
        dispatchPath!: ?String = None,
        queryString!: String = "",
        authority!: String = "",
        scheme!: String = ""
    ) {
        this.requestMethod = requestMethod
        this.rawTarget = rawTarget
        this.targetForm = targetForm
        this.dispatchPath = dispatchPath
        this.queryString = queryString
        this.authority = authority
        this.scheme = scheme
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

class SocketHttp11PlannedDispatch {
    let seed: SocketHttp11DispatchSeed
    let plan: AppDispatchPlan

    init(seed: SocketHttp11DispatchSeed, plan: AppDispatchPlan) {
        this.seed = seed
        this.plan = plan
    }
}

func buildSocketHttp11DispatchSeed(request: SocketHttp11SessionRequest): SocketHttp11DispatchSeed {
    let rawTarget = request.head.target.trimAscii()
    if (rawTarget.size == 0) {
        throw SocketHttp11DispatchSeedException(
            SocketHttp11DispatchSeedErrorCode.InvalidTarget,
            "HTTP/1.1 dispatch seed requires a non-empty request target"
        )
    }
    if (socketHttp11DispatchSeedContainsChar(rawTarget, r'#')) {
        throw SocketHttp11DispatchSeedException(
            SocketHttp11DispatchSeedErrorCode.FragmentNotAllowed,
            "HTTP/1.1 dispatch seed rejects request targets that contain fragments"
        )
    }
    if (rawTarget == "*") {
        return SocketHttp11DispatchSeed(
            request.head.method,
            rawTarget,
            SocketHttp11RequestTargetForm.AsteriskForm,
            authority: request.head.header("host") ?? ""
        )
    }
    if (rawTarget.startsWith("/")) {
        return buildSocketHttp11OriginDispatchSeed(request, rawTarget)
    }

    let lower = rawTarget.toAsciiLower()
    if (lower.startsWith("http://")) {
        return buildSocketHttp11AbsoluteDispatchSeed(request, rawTarget, "http", 7)
    }
    if (lower.startsWith("https://")) {
        return buildSocketHttp11AbsoluteDispatchSeed(request, rawTarget, "https", 8)
    }
    if (socketHttp11DispatchSeedContainsChar(rawTarget, r':')) {
        return SocketHttp11DispatchSeed(
            request.head.method,
            rawTarget,
            SocketHttp11RequestTargetForm.AuthorityForm,
            authority: rawTarget
        )
    }
    throw SocketHttp11DispatchSeedException(
        SocketHttp11DispatchSeedErrorCode.UnsupportedAbsoluteScheme,
        "HTTP/1.1 dispatch seed supports only origin-form, absolute-form(http/https), authority-form, and '*' targets"
    )
}

func tryResolveSocketHttp11PlannedDispatch(
    app: App,
    request: SocketHttp11SessionRequest
): ?SocketHttp11PlannedDispatch {
    let seed = buildSocketHttp11DispatchSeed(request)
    match (seed.dispatchPath) {
        case Some(path) =>
            Some(SocketHttp11PlannedDispatch(seed, resolveAppDispatchPlan(app, request.head.method, path)))
        case None => None
    }
}

func buildSocketHttp11OriginDispatchSeed(
    request: SocketHttp11SessionRequest,
    rawTarget: String
): SocketHttp11DispatchSeed {
    let (path, queryString) = splitSocketHttp11TargetPathAndQuery(rawTarget)
    SocketHttp11DispatchSeed(
        request.head.method,
        rawTarget,
        SocketHttp11RequestTargetForm.OriginForm,
        dispatchPath: Some(path),
        queryString: queryString,
        authority: request.head.header("host") ?? ""
    )
}

func buildSocketHttp11AbsoluteDispatchSeed(
    request: SocketHttp11SessionRequest,
    rawTarget: String,
    scheme: String,
    prefixLen: Int64
): SocketHttp11DispatchSeed {
    let tail = socketHttp11DispatchSeedSliceFrom(rawTarget, prefixLen)
    if (tail.size == 0) {
        throw SocketHttp11DispatchSeedException(
            SocketHttp11DispatchSeedErrorCode.MissingAbsoluteAuthority,
            "HTTP/1.1 absolute-form target must include an authority"
        )
    }

    let slashIndex = socketHttp11DispatchSeedIndexOfChar(tail, r'/')
    let queryIndex = socketHttp11DispatchSeedIndexOfChar(tail, r'?')
    var authorityEnd = tail.size
    if (slashIndex >= 0 && queryIndex >= 0) {
        authorityEnd = if (slashIndex < queryIndex) { slashIndex } else { queryIndex }
    } else if (slashIndex >= 0) {
        authorityEnd = slashIndex
    } else if (queryIndex >= 0) {
        authorityEnd = queryIndex
    }

    let authority = socketHttp11DispatchSeedSliceRange(tail, 0, authorityEnd).trimAscii()
    if (authority.size == 0) {
        throw SocketHttp11DispatchSeedException(
            SocketHttp11DispatchSeedErrorCode.MissingAbsoluteAuthority,
            "HTTP/1.1 absolute-form target must include an authority"
        )
    }

    let remainder = socketHttp11DispatchSeedSliceFrom(tail, authorityEnd)
    let normalizedTarget = if (remainder.size == 0) {
        "/"
    } else if (remainder.toRuneArray()[0] == r'?') {
        "/" + remainder
    } else {
        remainder
    }
    let (path, queryString) = splitSocketHttp11TargetPathAndQuery(normalizedTarget)
    SocketHttp11DispatchSeed(
        request.head.method,
        rawTarget,
        SocketHttp11RequestTargetForm.AbsoluteForm,
        dispatchPath: Some(path),
        queryString: queryString,
        authority: authority,
        scheme: scheme
    )
}

func splitSocketHttp11TargetPathAndQuery(target: String): (String, String) {
    let queryIndex = socketHttp11DispatchSeedIndexOfChar(target, r'?')
    if (queryIndex < 0) {
        return (normalizedSocketHttp11TargetPath(target), "")
    }
    let path = socketHttp11DispatchSeedSliceRange(target, 0, queryIndex)
    let queryString = socketHttp11DispatchSeedSliceFrom(target, queryIndex + 1)
    (normalizedSocketHttp11TargetPath(path), queryString)
}

func normalizedSocketHttp11TargetPath(rawPath: String): String {
    let trimmed = rawPath.trimAscii()
    if (trimmed.size == 0) {
        return "/"
    }
    if (!trimmed.startsWith("/")) {
        throw SocketHttp11DispatchSeedException(
            SocketHttp11DispatchSeedErrorCode.InvalidTarget,
            "HTTP/1.1 dispatch seed requires a path that begins with '/'"
        )
    }
    trimmed
}

func socketHttp11DispatchSeedContainsChar(text: String, ch: Rune): Bool {
    socketHttp11DispatchSeedIndexOfChar(text, ch) >= 0
}

func socketHttp11DispatchSeedIndexOfChar(text: String, ch: Rune): Int64 {
    let runes = text.toRuneArray()
    for (i in 0..runes.size) {
        if (runes[i] == ch) {
            return i
        }
    }
    -1
}

func socketHttp11DispatchSeedSliceFrom(text: String, start: Int64): String {
    let runes = text.toRuneArray()
    if (start <= 0) {
        return text
    }
    if (start >= runes.size) {
        return ""
    }
    var out = ""
    for (i in start..runes.size) {
        out += runes[i].toString()
    }
    out
}

func socketHttp11DispatchSeedSliceRange(text: String, start: Int64, end: Int64): String {
    let runes = text.toRuneArray()
    if (start >= end || start >= runes.size || end <= 0) {
        return ""
    }
    var st = start
    var ed = end
    if (st < 0) {
        st = 0
    }
    if (ed > runes.size) {
        ed = runes.size
    }
    var out = ""
    for (i in st..ed) {
        out += runes[i].toString()
    }
    out
}
