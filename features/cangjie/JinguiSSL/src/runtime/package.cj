package jinguissl.runtime

public func jinguiRuntimePackageName(): String {
    "jinguissl_runtime"
}

public func jinguiRuntimeCompatibilityMarker(): Int64 {
    0x524B4954
}

public class RuntimeSurfaceDescriptor {
    public let packageName: String
    public let compatibilityMarker: Int64
    public let runtimeVersionTag: String

    public init(packageName: String, compatibilityMarker: Int64, runtimeVersionTag: String) {
        this.packageName = packageName
        this.compatibilityMarker = compatibilityMarker
        this.runtimeVersionTag = runtimeVersionTag
    }
}

public func jinguiRuntimeSurfaceDescriptor(): RuntimeSurfaceDescriptor {
    RuntimeSurfaceDescriptor(
        jinguiRuntimePackageName(),
        jinguiRuntimeCompatibilityMarker(),
        "0.1.0"
    )
}

// Runtime-owned startup catalog mirror used by old-live compatibility wrappers.
// It stays dependency-light so later packets can delegate profile facts safely.
public class StartupProfileCatalogEntry {
    public let label: String
    public let requiresHttpTls: Bool
    public let requiresSsh: Bool
    public let requiresX509: Bool
    public let requiresAcceleration: Bool
    public let notes: Array<String>
    public let requireRandom: Bool
    public let requireCurrentReleasePrimaryBackend: Bool
    public let requireDirectStdxTlsServerConfigBridge: Bool
    public let defaultAesEngineKind: Int64
    public let defaultAesBackendHint: String

    public init(
        label: String,
        requiresHttpTls: Bool,
        requiresSsh: Bool,
        requiresX509: Bool,
        requiresAcceleration: Bool,
        notes: Array<String>,
        requireRandom: Bool,
        requireCurrentReleasePrimaryBackend: Bool,
        requireDirectStdxTlsServerConfigBridge: Bool,
        defaultAesEngineKind: Int64,
        defaultAesBackendHint: String
    ) {
        this.label = label
        this.requiresHttpTls = requiresHttpTls
        this.requiresSsh = requiresSsh
        this.requiresX509 = requiresX509
        this.requiresAcceleration = requiresAcceleration
        this.notes = notes
        this.requireRandom = requireRandom
        this.requireCurrentReleasePrimaryBackend = requireCurrentReleasePrimaryBackend
        this.requireDirectStdxTlsServerConfigBridge = requireDirectStdxTlsServerConfigBridge
        this.defaultAesEngineKind = defaultAesEngineKind
        this.defaultAesBackendHint = defaultAesBackendHint
    }
}

public func jinguiListStartupProfileCatalog(): Array<StartupProfileCatalogEntry> {
    [
        StartupProfileCatalogEntry(
            "library-default",
            true,
            true,
            true,
            false,
            [
                "default profile for libraries that expose both HTTP/TLS and SSH-facing capabilities",
                "does not require accelerated AES backend"
            ],
            true,
            false,
            false,
            0,
            ""
        ),
        StartupProfileCatalogEntry(
            "http-client-library",
            true,
            false,
            true,
            false,
            [
                "optimized for HTTPS client stacks that need TLS and certificate validation",
                "SSH readiness is not required"
            ],
            true,
            false,
            false,
            0,
            ""
        ),
        StartupProfileCatalogEntry(
            "http-server-library",
            true,
            false,
            true,
            false,
            [
                "optimized for HTTPS server stacks that still prepare certificate material in-library",
                "direct stdx.net.tls.TlsServerConfig bridge is not required by default"
            ],
            true,
            false,
            false,
            0,
            ""
        ),
        StartupProfileCatalogEntry(
            "ssh-client-library",
            false,
            true,
            false,
            false,
            [
                "optimized for SSH client stacks that do not depend on X.509",
                "HTTP/TLS readiness is not required"
            ],
            true,
            false,
            false,
            0,
            ""
        ),
        StartupProfileCatalogEntry(
            "ssh-server-library",
            false,
            true,
            false,
            false,
            [
                "optimized for SSH server stacks that terminate SSH without X.509 requirements",
                "HTTP/TLS readiness is not required"
            ],
            true,
            false,
            false,
            0,
            ""
        ),
        StartupProfileCatalogEntry(
            "production-accelerated",
            true,
            true,
            true,
            true,
            [
                "requires the full HTTP/TLS + SSH + X.509 capability set",
                "fails closed when accelerated AES backend is unavailable",
                "pins the profile to the current release primary AES backend"
            ],
            true,
            true,
            false,
            2,
            "armv8-ce"
        )
    ]
}
