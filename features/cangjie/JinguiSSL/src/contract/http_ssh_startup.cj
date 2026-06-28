package jinguissl.contract

import std.collection.ArrayList
import jinguissl_core.crypto.error.{CryptoErrorCode, CryptoException}
import jinguissl_core.crypto.utils.csprngIsAvailable
import jinguissl.runtime.{StartupProfileCatalogEntry, jinguiListStartupProfileCatalog}

public class ContractHttpSshStartupReadinessReport {
    public let randomAvailable: Bool
    public let aes: ContractAesStartupSelfCheckReport
    public let aesCurrentReleasePlan: ContractAesCurrentReleasePlanReport
    public let capability: ContractCapabilityInfo
    public let httpTlsReady: Bool
    public let sshReady: Bool
    public let x509Ready: Bool
    public let overallReady: Bool
    public let productionAccelerationReady: Bool
    public let warnings: Array<String>

    public init(
        randomAvailable: Bool,
        aes: ContractAesStartupSelfCheckReport,
        aesCurrentReleasePlan: ContractAesCurrentReleasePlanReport,
        capability: ContractCapabilityInfo,
        httpTlsReady: Bool,
        sshReady: Bool,
        x509Ready: Bool,
        overallReady: Bool,
        productionAccelerationReady: Bool,
        warnings: Array<String>
    ) {
        this.randomAvailable = randomAvailable
        this.aes = aes
        this.aesCurrentReleasePlan = aesCurrentReleasePlan
        this.capability = capability
        this.httpTlsReady = httpTlsReady
        this.sshReady = sshReady
        this.x509Ready = x509Ready
        this.overallReady = overallReady
        this.productionAccelerationReady = productionAccelerationReady
        this.warnings = warnings.clone()
    }
}

public class ContractHttpSshStartupReadinessOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractHttpSshStartupReadinessReport

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractHttpSshStartupReadinessReport = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "HTTP/SSH startup readiness outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "HTTP/SSH startup readiness outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "HTTP/SSH startup readiness outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "HTTP/SSH startup readiness outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "HTTP/SSH startup readiness outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "HTTP/SSH startup readiness outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "HTTP/SSH startup readiness outcome result must be empty when ok is false"
                    )
                case None => ()
            }
        }
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractHttpSshStartupPolicy {
    public let requireRandom: Bool
    public let requireHttpTls: Bool
    public let requireSsh: Bool
    public let requireX509: Bool
    public let requireAcceleration: Bool
    public let requireCurrentReleasePrimaryBackend: Bool
    public let requireDirectStdxTlsServerConfigBridge: Bool

    public init(
        requireRandom!: Bool = true,
        requireHttpTls!: Bool = true,
        requireSsh!: Bool = true,
        requireX509!: Bool = true,
        requireAcceleration!: Bool = false,
        requireCurrentReleasePrimaryBackend!: Bool = false,
        requireDirectStdxTlsServerConfigBridge!: Bool = false
    ) {
        this.requireRandom = requireRandom
        this.requireHttpTls = requireHttpTls
        this.requireSsh = requireSsh
        this.requireX509 = requireX509
        this.requireAcceleration = requireAcceleration
        this.requireCurrentReleasePrimaryBackend = requireCurrentReleasePrimaryBackend
        this.requireDirectStdxTlsServerConfigBridge = requireDirectStdxTlsServerConfigBridge
    }
}

public enum ContractHttpSshStartupProfile <: Equatable<ContractHttpSshStartupProfile> & ToString {
    | LibraryDefault
    | HttpClientLibrary
    | HttpServerLibrary
    | SshClientLibrary
    | SshServerLibrary
    | ProductionAccelerated

    public operator func ==(right: ContractHttpSshStartupProfile): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractHttpSshStartupProfile): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case LibraryDefault => 0
            case HttpClientLibrary => 1
            case HttpServerLibrary => 2
            case SshClientLibrary => 3
            case SshServerLibrary => 4
            case ProductionAccelerated => 5
        }
    }

    public func toString(): String {
        match (this) {
            case LibraryDefault => "LIBRARY_DEFAULT"
            case HttpClientLibrary => "HTTP_CLIENT_LIBRARY"
            case HttpServerLibrary => "HTTP_SERVER_LIBRARY"
            case SshClientLibrary => "SSH_CLIENT_LIBRARY"
            case SshServerLibrary => "SSH_SERVER_LIBRARY"
            case ProductionAccelerated => "PRODUCTION_ACCELERATED"
        }
    }
}

public class ContractHttpSshStartupProfileTemplate {
    public let profile: ContractHttpSshStartupProfile
    public let label: String
    public let policy: ContractHttpSshStartupPolicy
    public let defaultAesEngine: ContractAesEngineKind
    public let defaultAesBackendHint: String
    public let notes: Array<String>

    public init(
        profile: ContractHttpSshStartupProfile,
        label: String,
        policy: ContractHttpSshStartupPolicy,
        defaultAesEngine: ContractAesEngineKind,
        notes: Array<String>,
        defaultAesBackendHint!: String = ""
    ) {
        if (label.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "HTTP/SSH startup profile label must not be empty"
            )
        }
        if (notes.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "HTTP/SSH startup profile notes must not be empty"
            )
        }
        this.profile = profile
        this.label = label.trimAscii()
        this.policy = ContractHttpSshStartupPolicy(
            requireRandom: policy.requireRandom,
            requireHttpTls: policy.requireHttpTls,
            requireSsh: policy.requireSsh,
            requireX509: policy.requireX509,
            requireAcceleration: policy.requireAcceleration,
            requireCurrentReleasePrimaryBackend: policy.requireCurrentReleasePrimaryBackend,
            requireDirectStdxTlsServerConfigBridge: policy.requireDirectStdxTlsServerConfigBridge
        )
        this.defaultAesEngine = defaultAesEngine
        this.defaultAesBackendHint = defaultAesBackendHint.trimAscii()
        this.notes = notes.clone()
    }
}

public func contractHttpSshStartupReadiness(
    requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    aesBackendHint!: String = ""
): ContractHttpSshStartupReadinessReport {
    try {
        let capability = contractCapabilityInfo()
        let aesCurrentReleasePlan = contractAesCurrentReleasePlan(
            requestedEngine: requestedAesEngine,
            backendHint: aesBackendHint
        )
        let aes = aesCurrentReleasePlan.startup
        let randomAvailable = contractRandomAvailable()
        let httpTlsReady = contractStartupHasAllFeatures(
            capability.httpTlsFeatures,
            [
                "tls12-rsa",
                "tls13-x25519",
                "http-server-tls-config-validation",
                "http-client-trust-material-preparation",
                "alpn-normalization"
            ]
        )
        let sshReady = contractStartupHasAllFeatures(
            capability.sshFeatures,
            [
                "transport-packet-protection",
                "x25519-kex",
                "rsa-sha2-hostkey",
                "client-initial-handshake-facade",
                "server-initial-handshake-facade",
                "session-runtime-snapshot-facade"
            ]
        )
        let x509Ready = contractStartupHasAllFeatures(
            capability.x509Features,
            [
                "certificate-chain-verify",
                "hostname-policy",
                "leaf-pin-spki-sha256",
                "private-key-parse-rsa-pkcs1-pkcs8",
                "private-key-parse-ec-pkcs8"
            ]
        )
        let overallReady = randomAvailable && httpTlsReady && sshReady && x509Ready
        let warnings = ArrayList<String>()
        if (!randomAvailable) {
            warnings.add("system CSPRNG is unavailable; HTTP/SSH startup should fail closed")
        }
        if (!aes.acceleratedBackendReady) {
            warnings.add("AES accelerated backend is not ready; software or shim path may be used")
        }
        for (warning in aesCurrentReleasePlan.warnings) {
            warnings.add(warning)
        }
        if (!capability.directStdxTlsServerConfigBridge) {
            warnings.add("direct stdx.net.tls.TlsServerConfig bridge is not provided; use contract-level preparation APIs")
        }
        if (!httpTlsReady) {
            warnings.add("HTTP/TLS facade capability set is incomplete for startup expectations")
        }
        if (!sshReady) {
            warnings.add("SSH facade capability set is incomplete for startup expectations")
        }
        if (!x509Ready) {
            warnings.add("X.509 facade capability set is incomplete for startup expectations")
        }
        ContractHttpSshStartupReadinessReport(
            randomAvailable,
            aes,
            aesCurrentReleasePlan,
            capability,
            httpTlsReady,
            sshReady,
            x509Ready,
            overallReady,
            aes.acceleratedBackendReady,
            warnings.toArray()
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            contractMapStartupCryptoExceptionToErrorCode(e),
            "HTTP/SSH startup readiness failed: ${e.message}"
        )
    }
}

public func contractTryHttpSshStartupReadiness(
    requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    aesBackendHint!: String = ""
): ContractHttpSshStartupReadinessOutcome {
    try {
        let result = contractHttpSshStartupReadiness(
            requestedAesEngine: requestedAesEngine,
            aesBackendHint: aesBackendHint
        )
        ContractHttpSshStartupReadinessOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpSshStartupReadinessOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractRequireHttpSshStartupReadiness(
    policy!: ContractHttpSshStartupPolicy = ContractHttpSshStartupPolicy(),
    requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    aesBackendHint!: String = ""
): ContractHttpSshStartupReadinessReport {
    let report = contractHttpSshStartupReadiness(
        requestedAesEngine: requestedAesEngine,
        aesBackendHint: aesBackendHint
    )
    let failures = contractCollectHttpSshStartupPolicyFailures(report, policy)
    if (failures.size > 0) {
        let message = contractJoinStartupMessages(
            failures,
            "HTTP/SSH startup requirements are not satisfied: "
        )
        if (policy.requireRandom && !report.randomAvailable) {
            throw ContractException(ContractErrorCode.CryptoUnavailable, message)
        }
        throw ContractException(ContractErrorCode.Unsupported, message)
    }
    report
}

public func contractTryRequireHttpSshStartupReadiness(
    policy!: ContractHttpSshStartupPolicy = ContractHttpSshStartupPolicy(),
    requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    aesBackendHint!: String = ""
): ContractHttpSshStartupReadinessOutcome {
    try {
        let result = contractRequireHttpSshStartupReadiness(
            policy: policy,
            requestedAesEngine: requestedAesEngine,
            aesBackendHint: aesBackendHint
        )
        ContractHttpSshStartupReadinessOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpSshStartupReadinessOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractDescribeHttpSshStartupProfile(
    profile: ContractHttpSshStartupProfile
): ContractHttpSshStartupProfileTemplate {
    let entry = contractRuntimeStartupProfileEntry(profile)
    ContractHttpSshStartupProfileTemplate(
        profile,
        entry.label,
        ContractHttpSshStartupPolicy(
            requireRandom: entry.requireRandom,
            requireHttpTls: entry.requiresHttpTls,
            requireSsh: entry.requiresSsh,
            requireX509: entry.requiresX509,
            requireAcceleration: entry.requiresAcceleration,
            requireCurrentReleasePrimaryBackend: entry.requireCurrentReleasePrimaryBackend,
            requireDirectStdxTlsServerConfigBridge: entry.requireDirectStdxTlsServerConfigBridge
        ),
        contractRuntimeDefaultAesEngineKind(entry.defaultAesEngineKind),
        entry.notes,
        defaultAesBackendHint: entry.defaultAesBackendHint
    )
}

private func contractRuntimeStartupProfileEntry(profile: ContractHttpSshStartupProfile): StartupProfileCatalogEntry {
    let catalog = jinguiListStartupProfileCatalog()
    let index = profile.ordinalValue()
    if (index < 0 || index >= catalog.size) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "runtime startup profile catalog is missing the requested profile"
        )
    }
    let entry = catalog[index]
    if (entry.label != contractHttpSshStartupProfileExpectedLabel(profile)) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "runtime startup profile catalog order does not match contract profile order"
        )
    }
    entry
}

private func contractHttpSshStartupProfileExpectedLabel(profile: ContractHttpSshStartupProfile): String {
    match (profile) {
        case ContractHttpSshStartupProfile.LibraryDefault => "library-default"
        case ContractHttpSshStartupProfile.HttpClientLibrary => "http-client-library"
        case ContractHttpSshStartupProfile.HttpServerLibrary => "http-server-library"
        case ContractHttpSshStartupProfile.SshClientLibrary => "ssh-client-library"
        case ContractHttpSshStartupProfile.SshServerLibrary => "ssh-server-library"
        case ContractHttpSshStartupProfile.ProductionAccelerated => "production-accelerated"
    }
}

private func contractRuntimeDefaultAesEngineKind(defaultAesEngineKind: Int64): ContractAesEngineKind {
    match (defaultAesEngineKind) {
        case 0 => ContractAesEngineKind.Auto
        case 1 => ContractAesEngineKind.Software
        case 2 => ContractAesEngineKind.Hardware
        case _ => throw ContractException(
            ContractErrorCode.BadInput,
            "unsupported defaultAesEngineKind ${defaultAesEngineKind} from runtime startup profile catalog"
        )
    }
}

public func contractListHttpSshStartupProfiles(): Array<ContractHttpSshStartupProfileTemplate> {
    [
        contractDescribeHttpSshStartupProfile(ContractHttpSshStartupProfile.LibraryDefault),
        contractDescribeHttpSshStartupProfile(ContractHttpSshStartupProfile.HttpClientLibrary),
        contractDescribeHttpSshStartupProfile(ContractHttpSshStartupProfile.HttpServerLibrary),
        contractDescribeHttpSshStartupProfile(ContractHttpSshStartupProfile.SshClientLibrary),
        contractDescribeHttpSshStartupProfile(ContractHttpSshStartupProfile.SshServerLibrary),
        contractDescribeHttpSshStartupProfile(ContractHttpSshStartupProfile.ProductionAccelerated)
    ]
}

public func contractRequireHttpSshStartupProfile(
    profile: ContractHttpSshStartupProfile,
    requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    aesBackendHint!: String = ""
): ContractHttpSshStartupReadinessReport {
    let template = contractDescribeHttpSshStartupProfile(profile)
    let effectiveAesEngine = if (requestedAesEngine == ContractAesEngineKind.Auto) {
        template.defaultAesEngine
    } else {
        requestedAesEngine
    }
    let effectiveBackendHint = if (aesBackendHint.trimAscii().size > 0) {
        aesBackendHint.trimAscii()
    } else {
        template.defaultAesBackendHint
    }
    contractRequireHttpSshStartupReadiness(
        policy: template.policy,
        requestedAesEngine: effectiveAesEngine,
        aesBackendHint: effectiveBackendHint
    )
}

public func contractTryRequireHttpSshStartupProfile(
    profile: ContractHttpSshStartupProfile,
    requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    aesBackendHint!: String = ""
): ContractHttpSshStartupReadinessOutcome {
    try {
        let result = contractRequireHttpSshStartupProfile(
            profile,
            requestedAesEngine: requestedAesEngine,
            aesBackendHint: aesBackendHint
        )
        ContractHttpSshStartupReadinessOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpSshStartupReadinessOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractRandomAvailable(): Bool {
    csprngIsAvailable()
}

private func contractStartupHasAllFeatures(
    features: Array<String>,
    required: Array<String>
): Bool {
    for (item in required) {
        var found = false
        for (feature in features) {
            if (feature == item) {
                found = true
                break
            }
        }
        if (!found) {
            return false
        }
    }
    true
}

private func contractCollectHttpSshStartupPolicyFailures(
    report: ContractHttpSshStartupReadinessReport,
    policy: ContractHttpSshStartupPolicy
): Array<String> {
    let failures = ArrayList<String>()
    if (policy.requireRandom && !report.randomAvailable) {
        failures.add("system CSPRNG is unavailable")
    }
    if (policy.requireHttpTls && !report.httpTlsReady) {
        failures.add("HTTP/TLS capability set is incomplete")
    }
    if (policy.requireSsh && !report.sshReady) {
        failures.add("SSH capability set is incomplete")
    }
    if (policy.requireX509 && !report.x509Ready) {
        failures.add("X.509 capability set is incomplete")
    }
    if (policy.requireAcceleration && !report.productionAccelerationReady) {
        failures.add("accelerated AES backend is required but not ready")
    }
    if (policy.requireCurrentReleasePrimaryBackend) {
        if (!report.aesCurrentReleasePlan.primaryBackendAvailable) {
            failures.add(
                "current release primary AES backend is unavailable: ${report.aesCurrentReleasePlan.primaryBackend}"
            )
        } else if (!report.aesCurrentReleasePlan.usingPrimaryBackend) {
            failures.add(
                "current release requires primary AES backend ${report.aesCurrentReleasePlan.primaryBackend}, but startup resolved ${report.aes.selectedEngine.backend}"
            )
        }
    }
    if (
        policy.requireDirectStdxTlsServerConfigBridge &&
        !report.capability.directStdxTlsServerConfigBridge
    ) {
        failures.add("direct stdx.net.tls.TlsServerConfig bridge is required but unavailable")
    }
    failures.toArray()
}

private func contractJoinStartupMessages(
    messages: Array<String>,
    prefix: String
): String {
    if (messages.size == 0) {
        return prefix.trimAscii()
    }
    var text = prefix
    var first = true
    for (message in messages) {
        if (first) {
            text = "${text}${message}"
            first = false
        } else {
            text = "${text}; ${message}"
        }
    }
    text
}

private func contractMapStartupCryptoExceptionToErrorCode(
    exception: CryptoException
): ContractErrorCode {
    if (exception.code == CryptoErrorCode.ParseError) {
        return ContractErrorCode.VerifyFailed
    }
    if (exception.code == CryptoErrorCode.Unsupported) {
        return ContractErrorCode.Unsupported
    }
    contractMapCryptoErrorCode(exception.code)
}

private func contractMapCryptoErrorCode(code: CryptoErrorCode): ContractErrorCode {
    match (code) {
        case CryptoErrorCode.InvalidArgument => ContractErrorCode.BadInput
        case CryptoErrorCode.OutOfBounds => ContractErrorCode.BadInput
        case CryptoErrorCode.DivideByZero => ContractErrorCode.InternalError
        case CryptoErrorCode.NoModInverse => ContractErrorCode.InternalError
        case CryptoErrorCode.ComplianceRejected => ContractErrorCode.ComplianceRejected
        case CryptoErrorCode.ParseError => ContractErrorCode.VerifyFailed
        case CryptoErrorCode.Unsupported => ContractErrorCode.Unsupported
        case CryptoErrorCode.InternalError => ContractErrorCode.InternalError
    }
}
