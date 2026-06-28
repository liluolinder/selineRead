package jinguissl.contract

internal let _contractProviderGateSourceLibraryVersion: String = "0.6.21"

public enum ContractProviderServerAttachStatus <: Equatable<ContractProviderServerAttachStatus> & ToString {
    | PrecheckOnly
    | Experimental
    | Stable

    public operator func ==(right: ContractProviderServerAttachStatus): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderServerAttachStatus): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case PrecheckOnly => 0
            case Experimental => 1
            case Stable => 2
        }
    }

    public func toString(): String {
        match (this) {
            case PrecheckOnly => "PRECHECK_ONLY"
            case Experimental => "EXPERIMENTAL"
            case Stable => "STABLE"
        }
    }
}

public enum ContractProviderErrorPhase <: Equatable<ContractProviderErrorPhase> & ToString {
    | ProviderSelection
    | TlsPrecheck
    | TlsHandshake
    | TlsVerify
    | ProviderRuntime

    public operator func ==(right: ContractProviderErrorPhase): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderErrorPhase): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ProviderSelection => 0
            case TlsPrecheck => 1
            case TlsHandshake => 2
            case TlsVerify => 3
            case ProviderRuntime => 4
        }
    }

    public func toString(): String {
        match (this) {
            case ProviderSelection => "PROVIDER_SELECTION"
            case TlsPrecheck => "TLS_PRECHECK"
            case TlsHandshake => "TLS_HANDSHAKE"
            case TlsVerify => "TLS_VERIFY"
            case ProviderRuntime => "PROVIDER_RUNTIME"
        }
    }
}

public enum ContractProviderErrorFamily <: Equatable<ContractProviderErrorFamily> & ToString {
    | BadInput
    | VerifyFailed
    | KeyNotFound
    | CryptoUnavailable
    | ComplianceRejected
    | Unsupported
    | InternalError
    | TlsPrecheckError
    | TlsHandshakeError
    | TlsVerifyError
    | ProviderUnavailable

    public operator func ==(right: ContractProviderErrorFamily): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderErrorFamily): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case BadInput => 0
            case VerifyFailed => 1
            case KeyNotFound => 2
            case CryptoUnavailable => 3
            case ComplianceRejected => 4
            case Unsupported => 5
            case InternalError => 6
            case TlsPrecheckError => 7
            case TlsHandshakeError => 8
            case TlsVerifyError => 9
            case ProviderUnavailable => 10
        }
    }

    public func toString(): String {
        match (this) {
            case BadInput => "BAD_INPUT"
            case VerifyFailed => "VERIFY_FAILED"
            case KeyNotFound => "KEY_NOT_FOUND"
            case CryptoUnavailable => "CRYPTO_UNAVAILABLE"
            case ComplianceRejected => "COMPLIANCE_REJECTED"
            case Unsupported => "UNSUPPORTED"
            case InternalError => "INTERNAL_ERROR"
            case TlsPrecheckError => "TLS_PRECHECK_ERROR"
            case TlsHandshakeError => "TLS_HANDSHAKE_ERROR"
            case TlsVerifyError => "TLS_VERIFY_ERROR"
            case ProviderUnavailable => "PROVIDER_UNAVAILABLE"
        }
    }
}

public class ContractProviderCapabilityRecord {
    public let providerId: String
    public let providerVersion: String
    public let platformScope: String
    public let cjScope: String
    public let supportsClientTls: Bool
    public let supportsServerTlsAttach: Bool
    public let supportsX509Verify: Bool
    public let supportsAlpnH2: Bool
    public let supportsMtls: Bool
    public let supportsSessionCache: Bool
    public let experimental: Bool
    public let defaultEligible: Bool
    public let unsupportedReasons: Array<String>
    public let notes: Array<String>

    public init(
        providerId: String,
        providerVersion: String,
        platformScope: String,
        cjScope: String,
        supportsClientTls: Bool,
        supportsServerTlsAttach: Bool,
        supportsX509Verify: Bool,
        supportsAlpnH2: Bool,
        supportsMtls: Bool,
        supportsSessionCache: Bool,
        experimental: Bool,
        defaultEligible: Bool,
        unsupportedReasons: Array<String>,
        notes: Array<String>
    ) {
        if (
            providerId.trimAscii().size == 0 ||
            providerVersion.trimAscii().size == 0 ||
            platformScope.trimAscii().size == 0 ||
            cjScope.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider capability record string fields must not be empty"
            )
        }
        this.providerId = providerId.trimAscii()
        this.providerVersion = providerVersion.trimAscii()
        this.platformScope = platformScope.trimAscii()
        this.cjScope = cjScope.trimAscii()
        this.supportsClientTls = supportsClientTls
        this.supportsServerTlsAttach = supportsServerTlsAttach
        this.supportsX509Verify = supportsX509Verify
        this.supportsAlpnH2 = supportsAlpnH2
        this.supportsMtls = supportsMtls
        this.supportsSessionCache = supportsSessionCache
        this.experimental = experimental
        this.defaultEligible = defaultEligible
        this.unsupportedReasons = unsupportedReasons.clone()
        this.notes = notes.clone()
    }
}

public class ContractProviderAttachContractInfo {
    public let providerId: String
    public let supportsTlsPrecheck: Bool
    public let supportsClientTls: Bool
    public let supportsServerTlsAttach: Bool
    public let supportsX509Verify: Bool
    public let supportsHostOrSni: Bool
    public let supportsVerifyMode: Bool
    public let supportsHandshakeTimeout: Bool
    public let supportsSessionCache: Bool
    public let tlsPrecheckInputs: Array<String>
    public let tlsAttachInputs: Array<String>
    public let x509VerifyInputs: Array<String>
    public let failureFields: Array<String>
    public let unsupportedReasons: Array<String>
    public let notes: Array<String>

    public init(
        providerId: String,
        supportsTlsPrecheck: Bool,
        supportsClientTls: Bool,
        supportsServerTlsAttach: Bool,
        supportsX509Verify: Bool,
        supportsHostOrSni: Bool,
        supportsVerifyMode: Bool,
        supportsHandshakeTimeout: Bool,
        supportsSessionCache: Bool,
        tlsPrecheckInputs: Array<String>,
        tlsAttachInputs: Array<String>,
        x509VerifyInputs: Array<String>,
        failureFields: Array<String>,
        unsupportedReasons: Array<String>,
        notes: Array<String>
    ) {
        if (providerId.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider attach contract providerId must not be empty"
            )
        }
        if (tlsPrecheckInputs.size == 0 || x509VerifyInputs.size == 0 || failureFields.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider attach contract input/output fields must not be empty"
            )
        }
        this.providerId = providerId.trimAscii()
        this.supportsTlsPrecheck = supportsTlsPrecheck
        this.supportsClientTls = supportsClientTls
        this.supportsServerTlsAttach = supportsServerTlsAttach
        this.supportsX509Verify = supportsX509Verify
        this.supportsHostOrSni = supportsHostOrSni
        this.supportsVerifyMode = supportsVerifyMode
        this.supportsHandshakeTimeout = supportsHandshakeTimeout
        this.supportsSessionCache = supportsSessionCache
        this.tlsPrecheckInputs = tlsPrecheckInputs.clone()
        this.tlsAttachInputs = tlsAttachInputs.clone()
        this.x509VerifyInputs = x509VerifyInputs.clone()
        this.failureFields = failureFields.clone()
        this.unsupportedReasons = unsupportedReasons.clone()
        this.notes = notes.clone()
    }
}

public class ContractProviderServerAttachBoundary {
    public let providerId: String
    public let status: ContractProviderServerAttachStatus
    public let stableAttach: Bool
    public let blockingLayer: String
    public let recommendedFallback: String
    public let detail: String
    public let unsupportedReasons: Array<String>

    public init(
        providerId: String,
        status: ContractProviderServerAttachStatus,
        stableAttach: Bool,
        blockingLayer: String,
        recommendedFallback: String,
        detail: String,
        unsupportedReasons: Array<String>
    ) {
        if (
            providerId.trimAscii().size == 0 ||
            blockingLayer.trimAscii().size == 0 ||
            recommendedFallback.trimAscii().size == 0 ||
            detail.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider server attach boundary string fields must not be empty"
            )
        }
        this.providerId = providerId.trimAscii()
        this.status = status
        this.stableAttach = stableAttach
        this.blockingLayer = blockingLayer.trimAscii()
        this.recommendedFallback = recommendedFallback.trimAscii()
        this.detail = detail.trimAscii()
        this.unsupportedReasons = unsupportedReasons.clone()
    }
}

public class ContractProviderErrorDescriptor {
    public let providerId: String
    public let family: ContractProviderErrorFamily
    public let phase: ContractProviderErrorPhase
    public let retryable: Bool
    public let fallbackSuggested: Bool
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let detail: String

    public init(
        providerId: String,
        family: ContractProviderErrorFamily,
        phase: ContractProviderErrorPhase,
        retryable: Bool,
        fallbackSuggested: Bool,
        detail: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None
    ) {
        if (providerId.trimAscii().size == 0 || detail.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider error descriptor string fields must not be empty"
            )
        }
        this.providerId = providerId.trimAscii()
        this.family = family
        this.phase = phase
        this.retryable = retryable
        this.fallbackSuggested = fallbackSuggested
        this.code = code
        this.igniteCode = igniteCode
        this.detail = detail.trimAscii()
    }
}

public class ContractProviderFallbackDecision {
    public let providerId: String
    public let fallbackSuggested: Bool
    public let fallbackTarget: String
    public let retryable: Bool
    public let mustSurface: Bool
    public let reason: String

    public init(
        providerId: String,
        fallbackSuggested: Bool,
        fallbackTarget: String,
        retryable: Bool,
        mustSurface: Bool,
        reason: String
    ) {
        if (providerId.trimAscii().size == 0 || reason.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider fallback decision string fields must not be empty"
            )
        }
        this.providerId = providerId.trimAscii()
        this.fallbackSuggested = fallbackSuggested
        this.fallbackTarget = fallbackTarget.trimAscii()
        this.retryable = retryable
        this.mustSurface = mustSurface
        this.reason = reason.trimAscii()
    }
}

public func contractProviderCapabilityRecord(): ContractProviderCapabilityRecord {
    ContractProviderCapabilityRecord(
        "jinguissl",
        _contractProviderGateSourceLibraryVersion,
        "primary darwin/aarch64; compile-target linux/ohos aarch64; x86_64 deferred to 0.7; loongarch64/riscv64 reserved skeletons",
        "cjc >= 1.1.0",
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        [
            "direct stdx.net.tls.TlsServerConfig bridge is unavailable",
            "full browser-grade HTTPS/H2 runtime closure remains outside this contract"
        ],
        [
            "client TLS, X.509 verification, ALPN normalization, and session cache are available through jinguissl.contract.*",
            "server integrations may use the stable accepted-transport attach contract path for listener-owned TLS1.3 X25519 attach",
            "mTLS should remain experimental until a dedicated stable mTLS contract is published"
        ]
    )
}

public func contractProviderAttachContractInfo(): ContractProviderAttachContractInfo {
    ContractProviderAttachContractInfo(
        "jinguissl",
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        [
            "serverName",
            "alpnProtocols",
            "certificatePem",
            "privateKeyPem",
            "trustAnchorsPem",
            "verifyMode",
            "handshakeTimeoutMs"
        ],
        [
            "serverName",
            "alpnProtocols",
            "certificatePem",
            "privateKeyPem",
            "clientAuthPolicy",
            "sessionTicketPolicy",
            "handshakeTimeoutMs"
        ],
        [
            "peerCertificatePem",
            "peerChainPem",
            "trustAnchorsPem",
            "expectedHost",
            "verifyMode",
            "pins"
        ],
        [
            "family",
            "phase",
            "retryable",
            "fallbackSuggested",
            "contractCode",
            "igniteCode",
            "message"
        ],
        [],
        [
            "TLS precheck is a stable contract surface today",
            "client TLS and X.509 verify are stable library contracts",
            "server attach fields are now backed by the stable accepted-transport attach contract path"
        ]
    )
}

public func contractProviderServerAttachBoundary(): ContractProviderServerAttachBoundary {
    ContractProviderServerAttachBoundary(
        "jinguissl",
        ContractProviderServerAttachStatus.Stable,
        true,
        "jinguissl stable accepted-transport contract",
        "stdx-default remains a manual fallback if provider attach fails before connection consumption",
        "this repository publishes a listener-owned stable accepted-transport TLS1.3 X25519 attach entrypoint",
        []
    )
}
