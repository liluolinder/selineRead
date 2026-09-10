package chui.desktop

/** Contract-only Harmony graphics paths. No host completion is inferred on a non-Harmony build. */
protected enum HarmonyGraphicsPath {
    | OpenGLES
    | Vulkan
}

protected func harmonyGraphicsPathName(path: HarmonyGraphicsPath): String {
    match (path) {
        case HarmonyGraphicsPath.OpenGLES => "opengles"
        case HarmonyGraphicsPath.Vulkan => "vulkan"
    }
}

protected struct PlatformCapabilityReceipt {
    public let platform: String
    public let capability: String
    public let contractAvailable: Bool
    public let softwareConformanceComplete: Bool
    public let hostRuntimeComplete: Bool
    public let fieldProofPending: Bool
    public let detail: String

    public init(platform: String, capability: String, detail: String) {
        this.platform = platform
        this.capability = capability
        this.contractAvailable = true
        // Static capability discovery is intentionally not treated as a test execution receipt.
        this.softwareConformanceComplete = false
        this.hostRuntimeComplete = false
        this.fieldProofPending = true
        this.detail = detail
    }
}

protected func harmonyGraphicsCapability(path: HarmonyGraphicsPath): PlatformCapabilityReceipt {
    PlatformCapabilityReceipt("harmonyos", harmonyGraphicsPathName(path),
        "adapter contract available; software execution and Harmony device proof pending")
}

protected func desktopWindowShapeCapability(platform: String): PlatformCapabilityReceipt {
    if (platform != "windows" && platform != "linux-x11" && platform != "linux-wayland") {
        throw IllegalArgumentException("desktop shape conformance requires windows or linux")
    }
    PlatformCapabilityReceipt(platform, "shaped-window",
        "binary mask contract available; software execution and target compositor proof pending")
}
