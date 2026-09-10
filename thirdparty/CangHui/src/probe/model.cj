package chui.probe

public let CUI_PROBE_PROTOCOL = "cui.probe.v0"
public let CUI_PROBE_SCHEMA_REF = "canghui://schemas/cui-probe-v0"

public enum ProbeKind <: Equatable<ProbeKind> {
    | Function
    | Component

    public operator func ==(other: ProbeKind): Bool {
        probeKindName(this) == probeKindName(other)
    }

    public operator func !=(other: ProbeKind): Bool {
        !(this == other)
    }
}

public func probeKindName(kind: ProbeKind): String {
    match (kind) {
        case ProbeKind.Function => "function"
        case ProbeKind.Component => "component"
    }
}

public type ProbeHandler = (String) -> String

public class ProbeEndpoint {
    public let name: String
    public let description: String
    public let kind: ProbeKind
    let handler: ProbeHandler

    public init(name: String, description: String, kind: ProbeKind, handler: ProbeHandler) {
        validateProbeName(name)
        if (description.isEmpty()) {
            throw IllegalArgumentException("probe description must not be empty")
        }
        this.name = name
        this.description = description
        this.kind = kind
        this.handler = handler
    }

    public func run(payload: String): String {
        handler(payload)
    }
}

public func validateProbeName(name: String): Unit {
    if (name.isEmpty()) {
        throw IllegalArgumentException("probe name must not be empty")
    }
    var segmentStart = true
    for (r in name.toRuneArray()) {
        if (r == r'.') {
            if (segmentStart) {
                throw IllegalArgumentException("probe name has an empty segment: " + name)
            }
            segmentStart = true
        } else {
            let letter = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z')
            let digit = r >= r'0' && r <= r'9'
            let allowed = letter || digit || r == r'-' || r == r'_'
            if (!allowed || (segmentStart && !letter)) {
                throw IllegalArgumentException(
                    "probe segments must start with a letter and contain letters, digits, '-' or '_': " + name
                )
            }
            segmentStart = false
        }
    }
    if (segmentStart) {
        throw IllegalArgumentException("probe name must not end with a dot: " + name)
    }
}
