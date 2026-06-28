package ignite.api2

public enum ServerStartupErrorCode <: Equatable<ServerStartupErrorCode> & ToString {
    | AddressInUse
    | PermissionDenied
    | AddressUnavailable
    | BadInput
    | InternalError

    public operator func ==(right: ServerStartupErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ServerStartupErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case AddressInUse => 0
            case PermissionDenied => 1
            case AddressUnavailable => 2
            case BadInput => 3
            case InternalError => 4
        }
    }

    public func toString(): String {
        match (this) {
            case AddressInUse => "ADDRESS_IN_USE"
            case PermissionDenied => "PERMISSION_DENIED"
            case AddressUnavailable => "ADDRESS_UNAVAILABLE"
            case BadInput => "BAD_INPUT"
            case InternalError => "INTERNAL_ERROR"
        }
    }
}

public class ServerStartupFailureSnapshot {
    public let stage: String
    public let listenErrorCode: String
    public let igniteErrorCode: String
    public let hint: String

    public init(
        stage: String,
        listenErrorCode: String,
        igniteErrorCode: String,
        hint: String
    ) {
        this.stage = stage
        this.listenErrorCode = listenErrorCode
        this.igniteErrorCode = igniteErrorCode
        this.hint = hint
    }
}

public func serverStartupFailureSnapshot(message: String): ServerStartupFailureSnapshot {
    let code = classifyServerStartupErrorCode(message)
    ServerStartupFailureSnapshot(
        "listen_startup",
        code.toString(),
        serverStartupToIgniteErrorCode(code),
        serverStartupHintForCode(code)
    )
}

public func serverStartupToIgniteErrorCode(code: ServerStartupErrorCode): String {
    "LISTEN_${code.toString()}"
}

public func classifyServerStartupErrorCode(message: String): ServerStartupErrorCode {
    let trimmed = message.trimAscii()
    let lower = trimmed.toAsciiLower()
    if (
        lower.contains("address already in use") ||
        lower.contains("already in use") ||
        lower.contains("eaddrinuse") ||
        lower.contains("port already in use") ||
        lower.contains("port in use") ||
        trimmed.contains("端口已被占用") ||
        trimmed.contains("地址已在使用")
    ) {
        return ServerStartupErrorCode.AddressInUse
    }
    if (
        lower.contains("permission denied") ||
        lower.contains("operation not permitted") ||
        lower.contains("eacces") ||
        trimmed.contains("权限不足") ||
        trimmed.contains("拒绝访问")
    ) {
        return ServerStartupErrorCode.PermissionDenied
    }
    if (
        lower.contains("cannot assign requested address") ||
        lower.contains("eaddrnotavail") ||
        lower.contains("address not available") ||
        trimmed.contains("无法分配请求的地址")
    ) {
        return ServerStartupErrorCode.AddressUnavailable
    }
    if (
        lower.contains("invalid argument") ||
        lower.contains("bad address") ||
        lower.contains("invalid port") ||
        trimmed.contains("参数无效") ||
        trimmed.contains("地址格式无效")
    ) {
        return ServerStartupErrorCode.BadInput
    }
    ServerStartupErrorCode.InternalError
}

func serverStartupHintForCode(code: ServerStartupErrorCode): String {
    match (code) {
        case ServerStartupErrorCode.AddressInUse =>
            "check whether the port is already occupied or the previous process has not exited"
        case ServerStartupErrorCode.PermissionDenied =>
            "check listen port permissions, capability, sandbox policy, or privileged port usage"
        case ServerStartupErrorCode.AddressUnavailable =>
            "check the bind address, local interface status, and whether the requested host still exists on this node after IP changes; use 0.0.0.0 when you need a wildcard bind"
        case ServerStartupErrorCode.BadInput =>
            "check addr/port input, bind arguments, and startup parameter normalization"
        case ServerStartupErrorCode.InternalError =>
            "check server engine exception details and runtime environment"
    }
}
