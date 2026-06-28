package jinguissl.contract

public enum ContractErrorCode <: Equatable<ContractErrorCode> & ToString {
    | BadInput
    | KeyNotFound
    | VerifyFailed
    | CryptoUnavailable
    | ComplianceRejected
    | Unsupported
    | InternalError

    public operator func ==(right: ContractErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case BadInput => 0
            case KeyNotFound => 1
            case VerifyFailed => 2
            case CryptoUnavailable => 3
            case ComplianceRejected => 4
            case Unsupported => 5
            case InternalError => 6
        }
    }

    public func toString(): String {
        match (this) {
            case BadInput => "BAD_INPUT"
            case KeyNotFound => "KEY_NOT_FOUND"
            case VerifyFailed => "VERIFY_FAILED"
            case CryptoUnavailable => "CRYPTO_UNAVAILABLE"
            case ComplianceRejected => "COMPLIANCE_REJECTED"
            case Unsupported => "UNSUPPORTED"
            case InternalError => "INTERNAL_ERROR"
        }
    }
}

public class ContractException <: Exception {
    public let code: ContractErrorCode

    public init(code: ContractErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public enum ContractIgniteCryptoErrorCode <: Equatable<ContractIgniteCryptoErrorCode> & ToString {
    | BadEnvelope
    | KeyNotFound
    | DecryptFailed
    | CryptoUnavailable

    public operator func ==(right: ContractIgniteCryptoErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractIgniteCryptoErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case BadEnvelope => 0
            case KeyNotFound => 1
            case DecryptFailed => 2
            case CryptoUnavailable => 3
        }
    }

    public func toString(): String {
        match (this) {
            case BadEnvelope => "BAD_ENVELOPE"
            case KeyNotFound => "KEY_NOT_FOUND"
            case DecryptFailed => "DECRYPT_FAILED"
            case CryptoUnavailable => "CRYPTO_UNAVAILABLE"
        }
    }
}

public let CONTRACT_FACADE_API_VERSION: String = "1.0.0"
public let CONTRACT_FACADE_STABILITY_LEVEL: String = "L1"
public let CONTRACT_FACADE_FREEZE_DATE: String = "2026-03-24"

public class ContractFacadeInfo {
    public let apiVersion: String
    public let stabilityLevel: String
    public let freezeDate: String
    public let stableDomains: Array<String>
    public let importRule: String

    public init(
        apiVersion: String,
        stabilityLevel: String,
        freezeDate: String,
        stableDomains: Array<String>,
        importRule: String
    ) {
        if (apiVersion.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "contract facade api version must not be empty")
        }
        if (stabilityLevel.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "contract facade stability level must not be empty")
        }
        if (freezeDate.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "contract facade freeze date must not be empty")
        }
        if (stableDomains.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "contract facade stable domains must not be empty")
        }
        this.apiVersion = apiVersion.trimAscii()
        this.stabilityLevel = stabilityLevel.trimAscii()
        this.freezeDate = freezeDate.trimAscii()
        this.stableDomains = stableDomains.clone()
        this.importRule = importRule.trimAscii()
    }
}

public func contractFacadeInfo(): ContractFacadeInfo {
    ContractFacadeInfo(
        CONTRACT_FACADE_API_VERSION,
        CONTRACT_FACADE_STABILITY_LEVEL,
        CONTRACT_FACADE_FREEZE_DATE,
        [
            "envelope",
            "x509",
            "tls12",
            "tls13",
            "ssh",
            "hkdf",
            "random"
        ],
        "import jinguissl.contract.* only; avoid deep import from jinguissl.crypto.* in app/framework layers"
    )
}

public class ContractCapabilityInfo {
    public let stableDomains: Array<String>
    public let httpTlsFeatures: Array<String>
    public let sshFeatures: Array<String>
    public let x509Features: Array<String>
    public let directStdxTlsServerConfigBridge: Bool
    public let notes: Array<String>

    public init(
        stableDomains: Array<String>,
        httpTlsFeatures: Array<String>,
        sshFeatures: Array<String>,
        x509Features: Array<String>,
        directStdxTlsServerConfigBridge: Bool,
        notes: Array<String>
    ) {
        if (stableDomains.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "contract capability stable domains must not be empty")
        }
        if (httpTlsFeatures.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "contract capability HTTP/TLS feature list must not be empty")
        }
        if (sshFeatures.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "contract capability SSH feature list must not be empty")
        }
        if (x509Features.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "contract capability X.509 feature list must not be empty")
        }
        if (notes.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "contract capability notes must not be empty")
        }
        this.stableDomains = stableDomains.clone()
        this.httpTlsFeatures = httpTlsFeatures.clone()
        this.sshFeatures = sshFeatures.clone()
        this.x509Features = x509Features.clone()
        this.directStdxTlsServerConfigBridge = directStdxTlsServerConfigBridge
        this.notes = notes.clone()
    }
}

public func contractCapabilityInfo(): ContractCapabilityInfo {
    ContractCapabilityInfo(
        [
            "envelope",
            "x509",
            "tls12",
            "tls13",
            "ssh",
            "hkdf",
            "random"
        ],
        [
            "tls12-rsa",
            "tls12-ecdhe-p256",
            "tls12-ecdhe-p384",
            "tls13-x25519",
            "tls13-p256",
            "tls13-p384",
            "tls13-client-auth",
            "tls13-session-ticket-psk",
            "tls13-key-update",
            "http-server-tls-config-validation",
            "http-server-tls-material-preparation",
            "http-client-tls-config-validation",
            "http-client-trust-material-preparation",
            "alpn-normalization"
        ],
        [
            "transport-packet-protection",
            "x25519-kex",
            "ecdh-p256-kex",
            "rsa-sha2-hostkey",
            "ecdsa-p256-hostkey",
            "ecdsa-p384-hostkey",
            "ed25519-hostkey",
            "host-signing-material-facade",
            "client-initial-handshake-facade",
            "server-initial-handshake-facade",
            "host-verification-required-modes",
            "session-runtime-snapshot-facade"
        ],
        [
            "pem-der-parse",
            "pem-bundle-normalization",
            "certificate-chain-verify",
            "http-client-peer-certificate-verify",
            "hostname-policy",
            "leaf-pin-der-sha256",
            "leaf-pin-spki-sha256",
            "private-key-parse-rsa-pkcs1-pkcs8",
            "private-key-parse-ec-pkcs8"
        ],
        false,
        [
            "apps/frameworks should import jinguissl.contract.* only",
            "direct stdx.net.tls.TlsServerConfig bridge is not provided in this repo",
            "use contractValidateHttpServerTlsConfigInput before external TLS server config construction",
            "HTTP/SSH-facing contract surface is prioritized over deep crypto internals"
        ]
    )
}
