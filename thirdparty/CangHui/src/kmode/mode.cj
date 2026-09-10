package chui.kmode

@When[debug]
import std.env.{getCommandLine, getVariable}

@When[debug]
public func kModeDebugDefault(): Bool {
    true
}

@When[!debug]
public func kModeDebugDefault(): Bool {
    false
}

/**
 * kMode is a compiler-debug-only facility.
 *
 * Release artifacts fail closed even when a launcher supplies historical
 * environment or argv opt-ins. This is a build boundary, not a preference.
 */
public func kModeEnabled(): Bool {
    kModeDebugDefault()
}

@When[debug]
public func kModeStdioRequested(): Bool {
    if (environmentValue("CANGHUI_KMODE_TRANSPORT") == "stdio") {
        return true
    }
    for (arg in getCommandLine()) {
        if (arg == "--kmode-stdio") {
            return true
        }
    }
    false
}

@When[!debug]
public func kModeStdioRequested(): Bool {
    false
}

@When[debug]
func environmentValue(name: String): String {
    match (getVariable(name)) {
        case Some(value) => value.trimAscii()
        case None => ""
    }
}

public class KModePolicy {
    public let enabled: Bool
    public let capabilities: Array<KModeCapability>

    public init(
        enabled!: Bool = kModeEnabled(),
        capabilities!: Array<KModeCapability> = [
            KModeCapability.Inspect,
            KModeCapability.Invoke,
            KModeCapability.Mutate,
            KModeCapability.Admin
        ]
    ) {
        this.enabled = enabled && kModeDebugDefault()
        this.capabilities = capabilities
    }

    public func allows(capability: KModeCapability): Bool {
        if (!enabled) {
            return false
        }
        for (candidate in capabilities) {
            if (candidate == capability || candidate == KModeCapability.Admin) {
                return true
            }
        }
        false
    }
}
