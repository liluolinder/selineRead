package cuic

/**
 * Build-time gate for privileged developer channels.
 *
 * Release builds retain explicit refusal functions so command compatibility is
 * stable, but cannot enter kMode/probe, debug, or device-capture execution.
 */
@When[debug]
public func debugChannelBuildEnabled(): Bool {
    true
}

@When[!debug]
public func debugChannelBuildEnabled(): Bool {
    false
}

/** This positive marker must never occur in a release executable. */
@When[debug]
public func debugChannelBuildMarker(): String {
    "CANGHUI_PRIVILEGED_DEBUG_BUILD=1"
}

@When[!debug]
public func debugChannelBuildMarker(): String {
    ""
}

func requireDebugChannelBuild(operation: String): Unit {
    if (!debugChannelBuildEnabled()) {
        throw CuicError(
            "${operation} is unavailable in release cuic; rebuild cuic with cjpm build -g"
        )
    }
    if (debugChannelBuildMarker().isEmpty()) {
        throw CuicError("privileged debug build marker is unavailable")
    }
}
