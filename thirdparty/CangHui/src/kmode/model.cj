package chui.kmode

public let KMODE_PROTOCOL = "canghui.kmode.v0"
public let KMODE_SCHEMA_REF = "canghui://schemas/kmode-call-v0"
public let KMODE_CHANNEL_PROTOCOL = "canghui.kmode.channel.v0"

public enum KModeCapability <: Equatable<KModeCapability> {
    | Inspect
    | Invoke
    | Mutate
    | Admin

    public operator func ==(other: KModeCapability): Bool {
        kModeCapabilityName(this) == kModeCapabilityName(other)
    }

    public operator func !=(other: KModeCapability): Bool {
        !(this == other)
    }
}

public func kModeCapabilityName(capability: KModeCapability): String {
    match (capability) {
        case KModeCapability.Inspect => "inspect"
        case KModeCapability.Invoke => "invoke"
        case KModeCapability.Mutate => "mutate"
        case KModeCapability.Admin => "admin"
    }
}

public enum KModeOperation <: Equatable<KModeOperation> {
    | Health
    | List
    | Describe
    | Invoke
    | Shutdown

    public operator func ==(other: KModeOperation): Bool {
        kModeOperationName(this) == kModeOperationName(other)
    }

    public operator func !=(other: KModeOperation): Bool {
        !(this == other)
    }
}

public func kModeOperationName(operation: KModeOperation): String {
    match (operation) {
        case KModeOperation.Health => "health"
        case KModeOperation.List => "list"
        case KModeOperation.Describe => "describe"
        case KModeOperation.Invoke => "invoke"
        case KModeOperation.Shutdown => "shutdown"
    }
}

public func parseKModeOperation(value: String): KModeOperation {
    match (value) {
        case "health" => KModeOperation.Health
        case "list" => KModeOperation.List
        case "describe" => KModeOperation.Describe
        case "invoke" => KModeOperation.Invoke
        case "shutdown" => KModeOperation.Shutdown
        case _ => throw IllegalArgumentException("unknown kMode operation: " + value)
    }
}

public type KModeHandler = (String) -> String

public class KModeEndpoint {
    public let name: String
    public let description: String
    public let capability: KModeCapability
    let handler: KModeHandler

    public init(
        name: String,
        description: String,
        capability: KModeCapability,
        handler: KModeHandler
    ) {
        validateKModeEndpointName(name)
        if (description.isEmpty()) {
            throw IllegalArgumentException("kMode endpoint description must not be empty")
        }
        this.name = name
        this.description = description
        this.capability = capability
        this.handler = handler
    }

    public func invoke(payload: String): String {
        handler(payload)
    }
}

public class KModeRequest {
    public let id: Int64
    public let operation: KModeOperation
    public let endpoint: String
    public let payload: String

    public init(
        id: Int64,
        operation: KModeOperation,
        endpoint!: String = "",
        payload!: String = ""
    ) {
        if (id < 0) {
            throw IllegalArgumentException("kMode request id must be non-negative")
        }
        if ((operation == KModeOperation.Describe || operation == KModeOperation.Invoke) &&
            endpoint.isEmpty()) {
            throw IllegalArgumentException("kMode describe/invoke requires an endpoint")
        }
        this.id = id
        this.operation = operation
        this.endpoint = endpoint
        this.payload = payload
    }
}

public class KModeResponse {
    public let id: Int64
    public let ok: Bool
    public let status: String
    public let payload: String
    public let errorCode: Int64
    public let errorMessage: String

    public init(
        id: Int64,
        ok: Bool,
        status: String,
        payload!: String = "",
        errorCode!: Int64 = 0,
        errorMessage!: String = ""
    ) {
        this.id = id
        this.ok = ok
        this.status = status
        this.payload = payload
        this.errorCode = errorCode
        this.errorMessage = errorMessage
    }
}

public func validateKModeEndpointName(name: String): Unit {
    if (name.isEmpty()) {
        throw IllegalArgumentException("kMode endpoint name must not be empty")
    }
    let runes = name.toRuneArray()
    var segmentStart = true
    for (r in runes) {
        if (r == r'.') {
            if (segmentStart) {
                throw IllegalArgumentException("kMode endpoint name has an empty segment: " + name)
            }
            segmentStart = true
        } else {
            let letter = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z')
            let digit = r >= r'0' && r <= r'9'
            if (!letter && !digit) {
                throw IllegalArgumentException(
                    "kMode endpoint names accept letters, digits and dots only: " + name
                )
            }
            if (segmentStart && digit) {
                throw IllegalArgumentException(
                    "kMode endpoint segments must start with a letter: " + name
                )
            }
            segmentStart = false
        }
    }
    if (segmentStart) {
        throw IllegalArgumentException("kMode endpoint name must not end with a dot: " + name)
    }
}
