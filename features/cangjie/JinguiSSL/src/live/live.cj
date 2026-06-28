package jinguissl.live

import std.collection.{ArrayList, HashMap}
import jinguissl_core.crypto.aes.{
    AesEngine,
    AesEngineKind,
    AesGcmContext,
    AesHardwareMountPoint,
    AesHardwareRoadmapEntry,
    AesNativeBridgeCallShape,
    AesNativeBridgeContract,
    AesNativeBridgeSpec,
    AesHardwareProbe,
    aesDefaultHardwareBackendHint,
    aesGcmDecryptWithContext,
    aesGcmEncryptWithContext,
    aesHardwareRoadmap,
    aesListHardwareMountPoints,
    aesNativeBridgeDescribeCallShape,
    aesNewGcmContext,
    aesOpenNativeBridge,
    aesProbeHardware,
    aesResolveEngine,
    aesResolveEngineWithNativeBridge
}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.chacha20.{chacha20Poly1305Decrypt, chacha20Poly1305Encrypt}
import jinguissl_core.crypto.compliance.{TLS_VERSION_1_2, TLS_VERSION_1_3, TlsVersion}
import jinguissl_core.crypto.digest.{HashAlgorithm, hkdf, hkdfExpand, hkdfExtract, sha256}
import jinguissl_core.crypto.ecc.{EcPrivateKey, EcPublicKey, NamedCurve, ecPublicFromPrivateKey}
import jinguissl_core.crypto.error.*
import jinguissl_core.crypto.rsa.{RsaPrivateKey, RsaPublicKey}
import jinguissl_core.crypto.ssh.{
    SSH_DEFAULT_PACKET_BLOCK_SIZE,
    SshClientInitialHandshakeResult,
    SshHandshakeCoordinator,
    SshHostVerificationPolicy,
    SshKexEcdhInitMessage,
    SshKexEcdhReplyMessage,
    SshHostVerificationResult,
    SshKexExchangeTranscript,
    SshKexInitMessage,
    SshNegotiatedAlgorithms,
    SshServerInitialHandshakeResult,
    SshTransportPacket,
    SshVersionBanner,
    SshX25519KexResult,
    sshBuildKexEcdhInitX25519,
    sshBuildDefaultKexInit,
    sshBuildVersionBanner,
    sshClientProcessKexEcdhReplyX25519,
    sshBuildEd25519HostKeyBlobFromSeed,
    sshCompleteClientInitialHandshakeX25519WithHostVerificationRequirement,
    sshCompleteServerInitialHandshakeX25519Ecdsa,
    sshCompleteServerInitialHandshakeX25519Ed25519,
    sshCompleteServerInitialHandshakeX25519Rsa,
    sshComputeHostKeySha256,
    sshDecodeKexEcdhInit,
    sshDecodeKexEcdhReply,
    sshDecodeNewKeys,
    sshDecodeTransportPacket,
    sshDecodeVersionBanner,
    sshDecodeKexInit,
    sshEncodeKexEcdhInit,
    sshEncodeKexEcdhReply,
    sshEncodeNewKeys,
    sshEncodeEcdsaHostPublicKey,
    sshEncodeKexInit,
    sshEncodeTransportPacket,
    sshEncodeVersionBanner,
    sshEncodeRsaHostPublicKey,
    sshExtractHostKeyAlgorithm,
    sshExtractHostSignatureAlgorithm,
    sshNegotiateKexInit,
    sshServerProcessKexEcdhInitX25519,
    sshSignExchangeHashEcdsa,
    sshSignExchangeHashEd25519,
    sshSignExchangeHashRsa,
    sshVerifyServerHostSignature
}
import jinguissl_core.crypto.tls.{
    TLS_SESSION_DEFAULT_TTL_SECONDS,
    TlsAeadRecordLayer,
    TlsAlertDescription,
    TlsAlertLevel,
    TlsAlertMessage,
    TlsChacha20Poly1305RecordLayer,
    TlsSessionCache,
    TlsSessionCacheStats,
    TlsSessionIdentity,
    TlsSessionTicket,
    Tls12HandshakeSecrets,
    Tls12KeyExchange,
    TlsAeadAlgorithm,
    TlsContentType,
    tlsCreateSessionTicket,
    tlsDecodeAlert,
    tlsDecodeAlertRecord,
    tlsDecodeServerHelloHandshake,
    tlsDecodeSessionTicket,
    tlsEncodeAlert,
    tlsEncodeAlertRecord,
    tlsEncodeRecord,
    tlsEncodeSessionTicket,
    tlsIsCloseNotifyAlert,
    tlsIsSessionTicketExpired,
    Tls13AuthFlight,
    Tls13AuthFlightRole,
    Tls13HandshakeSecrets,
    TlsHttpNegotiationPolicy,
    Tls13ServerHandshakeFlight,
    tls12BuildCertificateHandshakeFromDerChain,
    tls12BuildClientHello,
    tls12CreateClientRecordLayer,
    tls12CreateClientRecordLayerChacha20Poly1305,
    tls12CreateServerRecordLayer,
    tls12CreateServerRecordLayerChacha20Poly1305,
    tls12BuildEcdheClientKeyExchange,
    tls12BuildEcdheServerKeyExchange,
    tls12BuildRsaClientKeyExchange,
    tls12BuildServerHello,
    tls12DeriveSecretsFromEcdhe,
    tls12DeriveSecretsFromPreMaster,
    tls12ExtractClientRandom,
    tls12ExtractServerRandom,
    tls12ParseEcdheClientKeyExchange,
    tls12ParseEcdheServerKeyExchange,
    tls12ProcessRsaClientKeyExchange,
    tls12VerifyCertificateChainFromHandshake,
    tls13BuildHttpClientHelloX25519,
    tls13BuildClientHelloPskFromSessionTicket,
    tls13BuildClientHelloPskFromSessionTickets,
    tls13BuildKeyUpdateHandshake,
    tls13BuildNewSessionTicketFromSessionTicket,
    tls13BuildServerHelloForPskBySessionTickets,
    tls13BuildServerHelloForPskFromSessionTicket,
    tls13CipherSuiteAeadAlgorithm,
    tls13CipherSuiteIvLen,
    tls13CipherSuiteKeyLen,
    TLS13_CIPHER_SUITE_AES_128_GCM_SHA256,
    TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256,
    tls13DecodeKeyUpdateHandshake,
    tls13ExtractClientPskIdentity,
    tls13ExtractServerSelectedPskIdentity,
    tls13DecodeSessionTicketFromNewSessionTicket,
    tls13DeriveEarlyDataSecrets,
    tls13DeriveApplicationTrafficKeyIv,
    tls13DeriveExporterMasterSecret,
    tls13DeriveNextApplicationTrafficSecret,
    tls13DeriveSecretsFromPskAndX25519ForCipherSuite,
    tls13ExportKeyingMaterial,
    tls13SelectPskIdentityFromSessionTickets,
    tls13VerifyClientPskBinder,
    tls13BuildHttpServerHandshakeContextX25519,
    tls13ProcessServerHandshakeFlightX25519,
    tls13ValidateHttpClientResult
}
import jinguissl_core.crypto.utils.{constantTimeEquals, csprngBytes, csprngIsAvailable}
import jinguissl_core.crypto.x25519.{x25519GeneratePrivateKey, x25519PublicFromPrivate}
import jinguissl.runtime.{StartupProfileCatalogEntry, jinguiListStartupProfileCatalog}
import jinguissl_core.crypto.x509.{
    X509Certificate,
    X509VerificationPolicy,
    x509ExtractEcPublicKey,
    x509ParsePem,
    x509ParsePemChain,
    x509ParseEcPrivateKeyPkcs8Pem,
    x509ParseRsaPrivateKeyPkcs1Pem,
    x509ParseRsaPrivateKeyPkcs8Pem,
    x509ExtractRsaPublicKey,
    x509VerifyCertificateChain
}

/* LIBRARY_VERSION migrated from monolith — keep in sync with jinguissl_core */
private let LIBRARY_VERSION: String = "0.6.21"

private let CONTRACT_AES_GCM_CONTEXT_CACHE_MAX: Int64 = 16
private let _contractAesGcmContextCache = ArrayList<ContractAesGcmContextCacheEntry>()

private class ContractAesGcmContextCacheEntry {
    let key: Array<Byte>
    let context: AesGcmContext

    init(key: Array<Byte>, context: AesGcmContext) {
        this.key = key
        this.context = context
    }
}

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

public enum ContractAeadAlgorithm <: Equatable<ContractAeadAlgorithm> & ToString {
    | Aes256Gcm
    | Chacha20Poly1305

    public operator func ==(right: ContractAeadAlgorithm): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractAeadAlgorithm): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Aes256Gcm => 0
            case Chacha20Poly1305 => 1
        }
    }

    public func toString(): String {
        match (this) {
            case Aes256Gcm => "AES-256-GCM"
            case Chacha20Poly1305 => "CHACHA20-POLY1305"
        }
    }
}

public enum ContractKdfHash <: Equatable<ContractKdfHash> & ToString {
    | Sha1
    | Sha256
    | Sha384
    | Sha512

    public operator func ==(right: ContractKdfHash): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractKdfHash): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Sha1 => 0
            case Sha256 => 1
            case Sha384 => 2
            case Sha512 => 3
        }
    }

    public func toString(): String {
        match (this) {
            case Sha1 => "HKDF-SHA1"
            case Sha256 => "HKDF-SHA256"
            case Sha384 => "HKDF-SHA384"
            case Sha512 => "HKDF-SHA512"
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
            "http-server-initial-handshake-facade",
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
        if (
            providerId.trimAscii().size == 0 ||
            reason.trimAscii().size == 0
        ) {
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

public enum ContractProviderSmokeFixtureCategory <: Equatable<ContractProviderSmokeFixtureCategory> & ToString {
    | Success
    | PrecheckFail
    | HandshakeFail
    | VerifyFail
    | ProviderUnavailable

    public operator func ==(right: ContractProviderSmokeFixtureCategory): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderSmokeFixtureCategory): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Success => 0
            case PrecheckFail => 1
            case HandshakeFail => 2
            case VerifyFail => 3
            case ProviderUnavailable => 4
        }
    }

    public func toString(): String {
        match (this) {
            case Success => "SUCCESS"
            case PrecheckFail => "PRECHECK_FAIL"
            case HandshakeFail => "HANDSHAKE_FAIL"
            case VerifyFail => "VERIFY_FAIL"
            case ProviderUnavailable => "PROVIDER_UNAVAILABLE"
        }
    }
}

public class ContractProviderSmokeFixtureInfo {
    public let providerId: String
    public let fixtureId: String
    public let category: ContractProviderSmokeFixtureCategory
    public let summary: String
    public let artifacts: Array<String>
    public let entrypoints: Array<String>
    public let expectedPhase: ?ContractProviderErrorPhase
    public let expectedCode: ?ContractErrorCode
    public let expectedFamily: ?ContractProviderErrorFamily
    public let notes: Array<String>

    public init(
        providerId: String,
        fixtureId: String,
        category: ContractProviderSmokeFixtureCategory,
        summary: String,
        artifacts: Array<String>,
        entrypoints: Array<String>,
        notes!: Array<String>,
        expectedPhase!: ?ContractProviderErrorPhase = None,
        expectedCode!: ?ContractErrorCode = None,
        expectedFamily!: ?ContractProviderErrorFamily = None
    ) {
        if (
            providerId.trimAscii().size == 0 ||
            fixtureId.trimAscii().size == 0 ||
            summary.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke fixture string fields must not be empty"
            )
        }
        if (artifacts.size == 0 || entrypoints.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke fixture artifacts and entrypoints must not be empty"
            )
        }
        this.providerId = providerId.trimAscii()
        this.fixtureId = fixtureId.trimAscii()
        this.category = category
        this.summary = summary.trimAscii()
        this.artifacts = artifacts.clone()
        this.entrypoints = entrypoints.clone()
        this.expectedPhase = expectedPhase
        this.expectedCode = expectedCode
        this.expectedFamily = expectedFamily
        this.notes = notes.clone()
    }
}

public enum ContractProviderSmokeExecutionMode <: Equatable<ContractProviderSmokeExecutionMode> & ToString {
    | PrecheckPath
    | VerifyPath
    | ProviderSelectionPath
    | MetadataOnly

    public operator func ==(right: ContractProviderSmokeExecutionMode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderSmokeExecutionMode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case PrecheckPath => 0
            case VerifyPath => 1
            case ProviderSelectionPath => 2
            case MetadataOnly => 3
        }
    }

    public func toString(): String {
        match (this) {
            case PrecheckPath => "PRECHECK_PATH"
            case VerifyPath => "VERIFY_PATH"
            case ProviderSelectionPath => "PROVIDER_SELECTION_PATH"
            case MetadataOnly => "METADATA_ONLY"
        }
    }
}

public class ContractProviderSmokeBaselineRequest {
    public let fixtureId: String

    public init(fixtureId: String) {
        if (fixtureId.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke baseline request fixtureId must not be empty"
            )
        }
        this.fixtureId = fixtureId.trimAscii()
    }
}

public class ContractProviderSmokeBaselineReport {
    public let providerId: String
    public let fixture: ContractProviderSmokeFixtureInfo
    public let executionMode: ContractProviderSmokeExecutionMode
    public let expectedSuccess: Bool
    public let expectedDescriptor: ?ContractProviderErrorDescriptor
    public let expectedFallback: ?ContractProviderFallbackDecision
    public let capability: ContractProviderCapabilityRecord
    public let attachBoundary: ContractProviderServerAttachBoundary
    public let warnings: Array<String>

    public init(
        providerId: String,
        fixture: ContractProviderSmokeFixtureInfo,
        executionMode: ContractProviderSmokeExecutionMode,
        expectedSuccess: Bool,
        capability: ContractProviderCapabilityRecord,
        attachBoundary: ContractProviderServerAttachBoundary,
        warnings: Array<String>,
        expectedDescriptor!: ?ContractProviderErrorDescriptor = None,
        expectedFallback!: ?ContractProviderFallbackDecision = None
    ) {
        if (providerId.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke baseline report providerId must not be empty"
            )
        }
        if (expectedSuccess) {
            match (expectedDescriptor) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline success report must not carry expected descriptor"
                    )
                case None => ()
            }
            match (expectedFallback) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline success report must not carry fallback decision"
                    )
                case None => ()
            }
        } else {
            match (expectedDescriptor) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline failure report must carry expected descriptor"
                    )
            }
            match (expectedFallback) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline failure report must carry fallback decision"
                    )
            }
        }
        this.providerId = providerId.trimAscii()
        this.fixture = fixture
        this.executionMode = executionMode
        this.expectedSuccess = expectedSuccess
        this.expectedDescriptor = expectedDescriptor
        this.expectedFallback = expectedFallback
        this.capability = capability
        this.attachBoundary = attachBoundary
        this.warnings = warnings.clone()
    }
}

public class ContractProviderSmokeBaselineOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractProviderSmokeBaselineReport

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractProviderSmokeBaselineReport = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke baseline outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome result must be empty when ok is false"
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

public class ContractProviderSmokeSuiteRequest {
    public let fixtureIds: Array<String>

    public init(fixtureIds!: Array<String> = []) {
        let normalized = ArrayList<String>()
        for (fixtureId in fixtureIds) {
            let trimmed = fixtureId.trimAscii()
            if (trimmed.size == 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider smoke suite request fixtureIds must not contain empty values"
                )
            }
            normalized.add(trimmed)
        }
        this.fixtureIds = normalized.toArray()
    }
}

public class ContractProviderSmokeSuiteReport {
    public let providerId: String
    public let baselines: Array<ContractProviderSmokeBaselineReport>
    public let totalFixtureCount: Int64
    public let successFixtureCount: Int64
    public let failureFixtureCount: Int64
    public let precheckPathCount: Int64
    public let verifyPathCount: Int64
    public let providerSelectionPathCount: Int64
    public let metadataOnlyCount: Int64
    public let recommendedOrder: Array<String>
    public let capability: ContractProviderCapabilityRecord
    public let attachBoundary: ContractProviderServerAttachBoundary
    public let warnings: Array<String>

    public init(
        providerId: String,
        baselines: Array<ContractProviderSmokeBaselineReport>,
        totalFixtureCount: Int64,
        successFixtureCount: Int64,
        failureFixtureCount: Int64,
        precheckPathCount: Int64,
        verifyPathCount: Int64,
        providerSelectionPathCount: Int64,
        metadataOnlyCount: Int64,
        recommendedOrder: Array<String>,
        capability: ContractProviderCapabilityRecord,
        attachBoundary: ContractProviderServerAttachBoundary,
        warnings: Array<String>
    ) {
        if (providerId.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report providerId must not be empty"
            )
        }
        if (baselines.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report must contain at least one baseline"
            )
        }
        if (recommendedOrder.size != baselines.size) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report recommended order must match baseline count"
            )
        }
        if (totalFixtureCount != Int64(baselines.size)) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report totalFixtureCount must match baseline count"
            )
        }
        if (successFixtureCount + failureFixtureCount != totalFixtureCount) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report success/failure counts must match totalFixtureCount"
            )
        }
        if (
            precheckPathCount +
            verifyPathCount +
            providerSelectionPathCount +
            metadataOnlyCount != totalFixtureCount
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report execution-mode counts must match totalFixtureCount"
            )
        }
        this.providerId = providerId.trimAscii()
        this.baselines = baselines.clone()
        this.totalFixtureCount = totalFixtureCount
        this.successFixtureCount = successFixtureCount
        this.failureFixtureCount = failureFixtureCount
        this.precheckPathCount = precheckPathCount
        this.verifyPathCount = verifyPathCount
        this.providerSelectionPathCount = providerSelectionPathCount
        this.metadataOnlyCount = metadataOnlyCount
        this.recommendedOrder = recommendedOrder.clone()
        this.capability = capability
        this.attachBoundary = attachBoundary
        this.warnings = warnings.clone()
    }
}

public class ContractProviderSmokeSuiteOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractProviderSmokeSuiteReport

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractProviderSmokeSuiteReport = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome result must be empty when ok is false"
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

public class ContractProviderSmokeSelfCheckPolicy {
    public let requireClientTls: Bool
    public let requireX509Verify: Bool
    public let requireTlsPrecheck: Bool
    public let requireSuccessBaseline: Bool
    public let requirePrecheckCoverage: Bool
    public let requireVerifyCoverage: Bool
    public let requireProviderSelectionCoverage: Bool
    public let requireHandshakeCoverage: Bool
    public let requireFallbackPlan: Bool
    public let requireStableServerAttach: Bool
    public let requireDefaultEligible: Bool
    public let requireLiveHandshakeCoverage: Bool

    public init(
        requireClientTls!: Bool = true,
        requireX509Verify!: Bool = true,
        requireTlsPrecheck!: Bool = true,
        requireSuccessBaseline!: Bool = true,
        requirePrecheckCoverage!: Bool = true,
        requireVerifyCoverage!: Bool = true,
        requireProviderSelectionCoverage!: Bool = true,
        requireHandshakeCoverage!: Bool = true,
        requireFallbackPlan!: Bool = true,
        requireStableServerAttach!: Bool = false,
        requireDefaultEligible!: Bool = false,
        requireLiveHandshakeCoverage!: Bool = false
    ) {
        this.requireClientTls = requireClientTls
        this.requireX509Verify = requireX509Verify
        this.requireTlsPrecheck = requireTlsPrecheck
        this.requireSuccessBaseline = requireSuccessBaseline
        this.requirePrecheckCoverage = requirePrecheckCoverage
        this.requireVerifyCoverage = requireVerifyCoverage
        this.requireProviderSelectionCoverage = requireProviderSelectionCoverage
        this.requireHandshakeCoverage = requireHandshakeCoverage
        this.requireFallbackPlan = requireFallbackPlan
        this.requireStableServerAttach = requireStableServerAttach
        this.requireDefaultEligible = requireDefaultEligible
        this.requireLiveHandshakeCoverage = requireLiveHandshakeCoverage
    }
}

public class ContractProviderSmokeSelfCheckReport {
    public let policy: ContractProviderSmokeSelfCheckPolicy
    public let suite: ContractProviderSmokeSuiteReport
    public let supportsClientTls: Bool
    public let supportsX509Verify: Bool
    public let supportsTlsPrecheck: Bool
    public let hasSuccessBaseline: Bool
    public let hasPrecheckCoverage: Bool
    public let hasVerifyCoverage: Bool
    public let hasProviderSelectionCoverage: Bool
    public let hasHandshakeCoverage: Bool
    public let hasLiveHandshakeCoverage: Bool
    public let hasFallbackPlanCoverage: Bool
    public let stableServerAttach: Bool
    public let defaultEligible: Bool
    public let overallReady: Bool
    public let warnings: Array<String>

    public init(
        policy: ContractProviderSmokeSelfCheckPolicy,
        suite: ContractProviderSmokeSuiteReport,
        supportsClientTls: Bool,
        supportsX509Verify: Bool,
        supportsTlsPrecheck: Bool,
        hasSuccessBaseline: Bool,
        hasPrecheckCoverage: Bool,
        hasVerifyCoverage: Bool,
        hasProviderSelectionCoverage: Bool,
        hasHandshakeCoverage: Bool,
        hasLiveHandshakeCoverage: Bool,
        hasFallbackPlanCoverage: Bool,
        stableServerAttach: Bool,
        defaultEligible: Bool,
        overallReady: Bool,
        warnings: Array<String>
    ) {
        this.policy = policy
        this.suite = suite
        this.supportsClientTls = supportsClientTls
        this.supportsX509Verify = supportsX509Verify
        this.supportsTlsPrecheck = supportsTlsPrecheck
        this.hasSuccessBaseline = hasSuccessBaseline
        this.hasPrecheckCoverage = hasPrecheckCoverage
        this.hasVerifyCoverage = hasVerifyCoverage
        this.hasProviderSelectionCoverage = hasProviderSelectionCoverage
        this.hasHandshakeCoverage = hasHandshakeCoverage
        this.hasLiveHandshakeCoverage = hasLiveHandshakeCoverage
        this.hasFallbackPlanCoverage = hasFallbackPlanCoverage
        this.stableServerAttach = stableServerAttach
        this.defaultEligible = defaultEligible
        this.overallReady = overallReady
        this.warnings = warnings.clone()
    }
}

public class ContractProviderSmokeSelfCheckOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractProviderSmokeSelfCheckReport

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractProviderSmokeSelfCheckReport = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke self-check outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome result must be empty when ok is false"
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

public enum ContractProviderSmokeProfile <: Equatable<ContractProviderSmokeProfile> & ToString {
    | ProviderCandidate
    | AttachPlanning
    | DefaultHttpsEligible
    | LiveAttachExperimental
    | ProductionStrict

    public operator func ==(right: ContractProviderSmokeProfile): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderSmokeProfile): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ProviderCandidate => 0
            case AttachPlanning => 1
            case DefaultHttpsEligible => 2
            case LiveAttachExperimental => 3
            case ProductionStrict => 4
        }
    }

    public func toString(): String {
        match (this) {
            case ProviderCandidate => "PROVIDER_CANDIDATE"
            case AttachPlanning => "ATTACH_PLANNING"
            case DefaultHttpsEligible => "DEFAULT_HTTPS_ELIGIBLE"
            case LiveAttachExperimental => "LIVE_ATTACH_EXPERIMENTAL"
            case ProductionStrict => "PRODUCTION_STRICT"
        }
    }
}

public class ContractProviderSmokeProfileTemplate {
    public let profile: ContractProviderSmokeProfile
    public let label: String
    public let policy: ContractProviderSmokeSelfCheckPolicy
    public let notes: Array<String>

    public init(
        profile: ContractProviderSmokeProfile,
        label: String,
        policy: ContractProviderSmokeSelfCheckPolicy,
        notes: Array<String>
    ) {
        if (label.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke profile label must not be empty"
            )
        }
        if (notes.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke profile notes must not be empty"
            )
        }
        this.profile = profile
        this.label = label.trimAscii()
        this.policy = ContractProviderSmokeSelfCheckPolicy(
            requireClientTls: policy.requireClientTls,
            requireX509Verify: policy.requireX509Verify,
            requireTlsPrecheck: policy.requireTlsPrecheck,
            requireSuccessBaseline: policy.requireSuccessBaseline,
            requirePrecheckCoverage: policy.requirePrecheckCoverage,
            requireVerifyCoverage: policy.requireVerifyCoverage,
            requireProviderSelectionCoverage: policy.requireProviderSelectionCoverage,
            requireHandshakeCoverage: policy.requireHandshakeCoverage,
            requireFallbackPlan: policy.requireFallbackPlan,
            requireStableServerAttach: policy.requireStableServerAttach,
            requireDefaultEligible: policy.requireDefaultEligible,
            requireLiveHandshakeCoverage: policy.requireLiveHandshakeCoverage
        )
        this.notes = notes.clone()
    }
}

public enum ContractProviderConsumptionPath <: Equatable<ContractProviderConsumptionPath> & ToString {
    | HttpClientTls
    | HttpServerAttachPlanning
    | HttpServerStableAttach
    | SshClientLibrary
    | SshServerLibrary

    public operator func ==(right: ContractProviderConsumptionPath): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderConsumptionPath): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case HttpClientTls => 0
            case HttpServerAttachPlanning => 1
            case HttpServerStableAttach => 2
            case SshClientLibrary => 3
            case SshServerLibrary => 4
        }
    }

    public func toString(): String {
        match (this) {
            case HttpClientTls => "HTTP_CLIENT_TLS"
            case HttpServerAttachPlanning => "HTTP_SERVER_ATTACH_PLANNING"
            case HttpServerStableAttach => "HTTP_SERVER_STABLE_ATTACH"
            case SshClientLibrary => "SSH_CLIENT_LIBRARY"
            case SshServerLibrary => "SSH_SERVER_LIBRARY"
        }
    }
}

public class ContractProviderConsumptionPathGuide {
    public let path: ContractProviderConsumptionPath
    public let label: String
    public let consumerKind: String
    public let attemptAllowed: Bool
    public let useProviderSelection: Bool
    public let requiresUpperLayerAttachGlue: Bool
    public let publishedContractPath: Bool
    public let suggestedSmokeProfile: ?ContractProviderSmokeProfile
    public let suggestedFallbackTarget: String
    public let attachPlanMeaning: String
    public let notes: Array<String>

    public init(
        path: ContractProviderConsumptionPath,
        label: String,
        consumerKind: String,
        attemptAllowed: Bool,
        useProviderSelection: Bool,
        requiresUpperLayerAttachGlue: Bool,
        publishedContractPath: Bool,
        attachPlanMeaning: String,
        notes: Array<String>,
        suggestedSmokeProfile!: ?ContractProviderSmokeProfile = None,
        suggestedFallbackTarget!: String = ""
    ) {
        if (
            label.trimAscii().size == 0 ||
            consumerKind.trimAscii().size == 0 ||
            attachPlanMeaning.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption path guide string fields must not be empty"
            )
        }
        if (notes.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption path guide notes must not be empty"
            )
        }
        this.path = path
        this.label = label.trimAscii()
        this.consumerKind = consumerKind.trimAscii()
        this.attemptAllowed = attemptAllowed
        this.useProviderSelection = useProviderSelection
        this.requiresUpperLayerAttachGlue = requiresUpperLayerAttachGlue
        this.publishedContractPath = publishedContractPath
        this.suggestedSmokeProfile = suggestedSmokeProfile
        this.suggestedFallbackTarget = suggestedFallbackTarget.trimAscii()
        this.attachPlanMeaning = attachPlanMeaning.trimAscii()
        this.notes = notes.clone()
    }
}

public enum ContractProviderFallbackCauseCode <: Equatable<ContractProviderFallbackCauseCode> & ToString {
    | ProviderUnavailable
    | TlsHandshakeError
    | TlsVerifyError
    | TlsPrecheckError
    | TlsNotConfigured
    | CryptoUnavailable

    public operator func ==(right: ContractProviderFallbackCauseCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderFallbackCauseCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ProviderUnavailable => 0
            case TlsHandshakeError => 1
            case TlsVerifyError => 2
            case TlsPrecheckError => 3
            case TlsNotConfigured => 4
            case CryptoUnavailable => 5
        }
    }

    public func toString(): String {
        match (this) {
            case ProviderUnavailable => "provider_unavailable"
            case TlsHandshakeError => "tls_handshake_error"
            case TlsVerifyError => "tls_verify_error"
            case TlsPrecheckError => "tls_precheck_error"
            case TlsNotConfigured => "tls_not_configured"
            case CryptoUnavailable => "crypto_unavailable"
        }
    }
}

public enum ContractProviderFallbackOutcome <: Equatable<ContractProviderFallbackOutcome> & ToString {
    | SuggestedOnly
    | NoAutoFallback
    | NoFallback
    | ManualReview

    public operator func ==(right: ContractProviderFallbackOutcome): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderFallbackOutcome): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case SuggestedOnly => 0
            case NoAutoFallback => 1
            case NoFallback => 2
            case ManualReview => 3
        }
    }

    public func toString(): String {
        match (this) {
            case SuggestedOnly => "SUGGESTED_ONLY"
            case NoAutoFallback => "NO_AUTO_FALLBACK"
            case NoFallback => "NO_FALLBACK"
            case ManualReview => "MANUAL_REVIEW"
        }
    }
}

public class ContractProviderFallbackOutcomeGuide {
    public let causeCode: ContractProviderFallbackCauseCode
    public let wireName: String
    public let family: ContractProviderErrorFamily
    public let phase: ContractProviderErrorPhase
    public let defaultOutcome: ContractProviderFallbackOutcome
    public let consumedConnectionOutcome: ContractProviderFallbackOutcome
    public let stableDefaultOutcome: ContractProviderFallbackOutcome
    public let suggestedFallbackTarget: String
    public let mustSurface: Bool
    public let notes: Array<String>

    public init(
        causeCode: ContractProviderFallbackCauseCode,
        wireName: String,
        family: ContractProviderErrorFamily,
        phase: ContractProviderErrorPhase,
        defaultOutcome: ContractProviderFallbackOutcome,
        consumedConnectionOutcome: ContractProviderFallbackOutcome,
        stableDefaultOutcome: ContractProviderFallbackOutcome,
        mustSurface: Bool,
        notes: Array<String>,
        suggestedFallbackTarget!: String = ""
    ) {
        if (wireName.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider fallback outcome guide wireName must not be empty"
            )
        }
        if (notes.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider fallback outcome guide notes must not be empty"
            )
        }
        this.causeCode = causeCode
        this.wireName = wireName.trimAscii()
        this.family = family
        this.phase = phase
        this.defaultOutcome = defaultOutcome
        this.consumedConnectionOutcome = consumedConnectionOutcome
        this.stableDefaultOutcome = stableDefaultOutcome
        this.suggestedFallbackTarget = suggestedFallbackTarget.trimAscii()
        this.mustSurface = mustSurface
        this.notes = notes.clone()
    }
}

public class ContractProviderFallbackResolutionRequest {
    public let causeCode: ContractProviderFallbackCauseCode
    public let connectionConsumed: Bool
    public let alreadyOnStableDefault: Bool

    public init(
        causeCode: ContractProviderFallbackCauseCode,
        connectionConsumed!: Bool = false,
        alreadyOnStableDefault!: Bool = false
    ) {
        this.causeCode = causeCode
        this.connectionConsumed = connectionConsumed
        this.alreadyOnStableDefault = alreadyOnStableDefault
    }
}

public class ContractProviderFallbackResolution {
    public let guide: ContractProviderFallbackOutcomeGuide
    public let finalOutcome: ContractProviderFallbackOutcome
    public let fallbackTarget: String
    public let shouldRecord: Bool
    public let mustSurface: Bool
    public let notes: Array<String>

    public init(
        guide: ContractProviderFallbackOutcomeGuide,
        finalOutcome: ContractProviderFallbackOutcome,
        notes: Array<String>,
        fallbackTarget!: String = "",
        shouldRecord!: Bool = true,
        mustSurface!: Bool = false
    ) {
        if (notes.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider fallback resolution notes must not be empty"
            )
        }
        this.guide = guide
        this.finalOutcome = finalOutcome
        this.fallbackTarget = fallbackTarget.trimAscii()
        this.shouldRecord = shouldRecord
        this.mustSurface = mustSurface
        this.notes = notes.clone()
    }
}

public enum ContractProviderConsumptionGateStatus <: Equatable<ContractProviderConsumptionGateStatus> & ToString {
    | ProviderCandidate
    | PlanningOnly
    | LibraryContract
    | Blocked

    public operator func ==(right: ContractProviderConsumptionGateStatus): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderConsumptionGateStatus): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ProviderCandidate => 0
            case PlanningOnly => 1
            case LibraryContract => 2
            case Blocked => 3
        }
    }

    public func toString(): String {
        match (this) {
            case ProviderCandidate => "PROVIDER_CANDIDATE"
            case PlanningOnly => "PLANNING_ONLY"
            case LibraryContract => "LIBRARY_CONTRACT"
            case Blocked => "BLOCKED"
        }
    }
}

public class ContractProviderConsumptionGateReport {
    public let path: ContractProviderConsumptionPath
    public let guide: ContractProviderConsumptionPathGuide
    public let status: ContractProviderConsumptionGateStatus
    public let providerId: String
    public let selectedEntryId: String
    public let candidateOrder: Array<String>
    public let blockedCandidates: Array<String>
    public let publicPath: String
    public let releasePath: String
    public let riskLevel: String
    public let observabilityTags: Array<String>
    public let capability: ContractProviderCapabilityRecord
    public let attachBoundary: ContractProviderServerAttachBoundary
    public let smokeProfile: ?ContractProviderSmokeProfileTemplate
    public let smokeReadiness: ?ContractProviderSmokeSelfCheckReport
    public let readyNow: Bool
    public let fallbackTarget: String
    public let fallbackChain: Array<String>
    public let selectedReason: String
    public let warnings: Array<String>

    public init(
        path: ContractProviderConsumptionPath,
        guide: ContractProviderConsumptionPathGuide,
        status: ContractProviderConsumptionGateStatus,
        providerId: String,
        selectedEntryId: String,
        candidateOrder: Array<String>,
        blockedCandidates: Array<String>,
        publicPath: String,
        releasePath: String,
        riskLevel: String,
        observabilityTags: Array<String>,
        capability: ContractProviderCapabilityRecord,
        attachBoundary: ContractProviderServerAttachBoundary,
        readyNow: Bool,
        selectedReason: String,
        warnings: Array<String>,
        smokeProfile!: ?ContractProviderSmokeProfileTemplate = None,
        smokeReadiness!: ?ContractProviderSmokeSelfCheckReport = None,
        fallbackTarget!: String = "",
        fallbackChain!: Array<String> = []
    ) {
        if (path != guide.path) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report path must match guide.path"
            )
        }
        if (
            providerId.trimAscii().size == 0 ||
            publicPath.trimAscii().size == 0 ||
            releasePath.trimAscii().size == 0 ||
            riskLevel.trimAscii().size == 0 ||
            selectedReason.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report string fields must not be empty"
            )
        }
        if (candidateOrder.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report candidateOrder must not be empty"
            )
        }
        if (observabilityTags.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report observabilityTags must not be empty"
            )
        }
        let trimmedSelectedEntryId = selectedEntryId.trimAscii()
        if (readyNow) {
            if (trimmedSelectedEntryId.size == 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider consumption gate report selectedEntryId must exist when readyNow is true"
                )
            }
            if (blockedCandidates.size > 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider consumption gate report blockedCandidates must be empty when readyNow is true"
                )
            }
        } else {
            if (trimmedSelectedEntryId.size > 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider consumption gate report selectedEntryId must be empty when readyNow is false"
                )
            }
            if (blockedCandidates.size == 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider consumption gate report blockedCandidates must exist when readyNow is false"
                )
            }
        }
        if (warnings.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report warnings must not be empty"
            )
        }
        if (fallbackTarget.trimAscii().size == 0 && fallbackChain.size > 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report fallbackChain must be empty when fallbackTarget is empty"
            )
        }
        match (smokeProfile) {
            case Some(_) =>
                match (smokeReadiness) {
                    case Some(_) => ()
                    case None =>
                        throw ContractException(
                            ContractErrorCode.BadInput,
                            "provider consumption gate report smokeReadiness must exist when smokeProfile is present"
                        )
                }
            case None =>
                match (smokeReadiness) {
                    case Some(_) =>
                        throw ContractException(
                            ContractErrorCode.BadInput,
                            "provider consumption gate report smokeReadiness must be empty when smokeProfile is absent"
                        )
                    case None => ()
                }
        }
        this.path = path
        this.guide = guide
        this.status = status
        this.providerId = providerId.trimAscii()
        this.selectedEntryId = trimmedSelectedEntryId
        this.candidateOrder = candidateOrder.clone()
        this.blockedCandidates = blockedCandidates.clone()
        this.publicPath = publicPath.trimAscii()
        this.releasePath = releasePath.trimAscii()
        this.riskLevel = riskLevel.trimAscii()
        this.observabilityTags = observabilityTags.clone()
        this.capability = capability
        this.attachBoundary = attachBoundary
        this.smokeProfile = smokeProfile
        this.smokeReadiness = smokeReadiness
        this.readyNow = readyNow
        this.fallbackTarget = fallbackTarget.trimAscii()
        this.fallbackChain = fallbackChain.clone()
        this.selectedReason = selectedReason.trimAscii()
        this.warnings = warnings.clone()
    }
}

public class ContractProviderConsumptionGateOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractProviderConsumptionGateReport

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractProviderConsumptionGateReport = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome result must be empty when ok is false"
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

public func contractProviderCapabilityRecord(): ContractProviderCapabilityRecord {
    ContractProviderCapabilityRecord(
        "jinguissl",
        LIBRARY_VERSION,
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

public func contractProviderSmokeFixtureCatalog(): Array<ContractProviderSmokeFixtureInfo> {
    let fixtures = ArrayList<ContractProviderSmokeFixtureInfo>()
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "success-x509-policy-chain",
            ContractProviderSmokeFixtureCategory.Success,
            "policy root + intermediate + leaf chain verifies cleanly for the bundled host policy fixture",
            [
                "testdata/x509/policy_root.pem",
                "testdata/x509/policy_intermediate.pem",
                "testdata/x509/policy_leaf.pem",
                "testdata/x509/policy_leaf_key_pkcs8.pem"
            ],
            [
                "contractVerifyServerCertificatePem(...)",
                "contractVerifyServerCertificateChainPem(...)",
                "contractTls13VerifyHttpServerFlightX25519(...)"
            ],
            notes: [
                "recommended baseline success smoke for provider-side X.509 and TLS verification wiring",
                "hostname expectation matches the policy leaf fixture used throughout contract tests"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "precheck-cert-key-mismatch",
            ContractProviderSmokeFixtureCategory.PrecheckFail,
            "certificate chain and private key mismatch must fail before any TLS attach or handshake",
            [
                "testdata/x509/policy_leaf.pem",
                "testdata/x509/policy_intermediate.pem",
                "testdata/x509/rsa_2048_pkcs8.pem"
            ],
            [
                "contractValidateHttpServerTlsConfigInput(...)",
                "contractPrepareHttpServerTlsMaterial(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.TlsPrecheck),
            expectedCode: Some(ContractErrorCode.VerifyFailed),
            expectedFamily: Some(ContractProviderErrorFamily.TlsPrecheckError),
            notes: [
                "maps provider failures into a deterministic precheck bucket for upper-layer startup smoke",
                "useful when the provider advertises server material preparation but not final listener attach"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "verify-hostname-mismatch",
            ContractProviderSmokeFixtureCategory.VerifyFail,
            "server certificate verification must reject a hostname outside the policy leaf SAN set",
            [
                "testdata/x509/policy_root.pem",
                "testdata/x509/policy_intermediate.pem",
                "testdata/x509/policy_leaf.pem",
                "hostname: api.policy.example"
            ],
            [
                "contractVerifyServerCertificatePem(...)",
                "contractTryVerifyServerCertificateChainPem(...)",
                "contractTls13VerifyHttpServerFlightX25519(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.TlsVerify),
            expectedCode: Some(ContractErrorCode.VerifyFailed),
            expectedFamily: Some(ContractProviderErrorFamily.TlsVerifyError),
            notes: [
                "primary verify-fail baseline for HTTP client and provider-facing certificate checks"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "verify-pin-mismatch",
            ContractProviderSmokeFixtureCategory.VerifyFail,
            "leaf certificate pin mismatch must be surfaced as a verification failure instead of a parse/config error",
            [
                "testdata/x509/policy_root.pem",
                "testdata/x509/policy_intermediate.pem",
                "testdata/x509/policy_leaf.pem",
                "pin-policy: wrong-der-or-spki-pin"
            ],
            [
                "contractVerifyServerCertificatePem(...)",
                "contractComputeLeafPinsFromPem(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.TlsVerify),
            expectedCode: Some(ContractErrorCode.VerifyFailed),
            expectedFamily: Some(ContractProviderErrorFamily.TlsVerifyError),
            notes: [
                "helps upper layers distinguish trust-policy failures from precheck/input failures"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "verify-untrusted-chain",
            ContractProviderSmokeFixtureCategory.VerifyFail,
            "peer chain without a matching trust anchor must stay in the verify-fail bucket instead of being treated as provider unavailability",
            [
                "testdata/x509/policy_intermediate.pem",
                "testdata/x509/policy_leaf.pem",
                "trust-anchor: missing-policy-root"
            ],
            [
                "contractVerifyServerCertificateChainPem(...)",
                "contractTryVerifyServerCertificateChainPem(...)",
                "contractVerifyHttpClientPeerCertificatePem(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.TlsVerify),
            expectedCode: Some(ContractErrorCode.VerifyFailed),
            expectedFamily: Some(ContractProviderErrorFamily.TlsVerifyError),
            notes: [
                "represents a more realistic HTTPS peer verification failure than a synthetic parse error",
                "useful for provider selectors that want a trust-anchor-missing baseline"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "handshake-server-hello-decode",
            ContractProviderSmokeFixtureCategory.HandshakeFail,
            "server hello decode failure should be normalized into the handshake-fail bucket",
            [
                "inline: server hello decode failed",
                "operation: tls"
            ],
            [
                "contractDescribeProviderCryptoException(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.TlsHandshake),
            expectedCode: Some(ContractErrorCode.VerifyFailed),
            expectedFamily: Some(ContractProviderErrorFamily.TlsHandshakeError),
            notes: [
                "metadata fixture for provider adapters that need a deterministic handshake-failure baseline without mining test code"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "attach-stable-listener-unpublished",
            ContractProviderSmokeFixtureCategory.HandshakeFail,
            "server attach attempts that go beyond precheck/material preparation must currently fail closed because the stable listener attach contract is unpublished",
            [
                "scene: server",
                "requested-path: stable-listener-attach",
                "boundary: PRECHECK_ONLY"
            ],
            [
                "contractProviderServerAttachBoundary(...)",
                "contractDescribeProviderConsumptionPath(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.ProviderRuntime),
            expectedCode: Some(ContractErrorCode.Unsupported),
            expectedFamily: Some(ContractProviderErrorFamily.Unsupported),
            notes: [
                "documents attach failure as a planning/runtime contract issue rather than a fake successful attach",
                "aligns with the public rule that server attach must stop in upper-layer glue such as lisi/stdx"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "provider-not-linked",
            ContractProviderSmokeFixtureCategory.ProviderUnavailable,
            "provider selection should surface an unavailable provider explicitly when the candidate is not linked or gated off",
            [
                "detail: provider not linked",
                "backend-hint: none"
            ],
            [
                "contractDescribeProviderErrorCode(...)",
                "contractRecommendProviderFallback(...)",
                "contractTryResolveAesEngine(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.ProviderSelection),
            expectedCode: Some(ContractErrorCode.CryptoUnavailable),
            expectedFamily: Some(ContractProviderErrorFamily.ProviderUnavailable),
            notes: [
                "documents the intended fallback-to-stdx path when provider selection fails before runtime"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "provider-experimental-gated-off",
            ContractProviderSmokeFixtureCategory.ProviderUnavailable,
            "provider selection should also surface unavailable when upper-layer policy keeps experimental jinguissl attach attempts disabled",
            [
                "scene: server",
                "allowExperimental: false",
                "candidate: jinguissl-provider-candidate"
            ],
            [
                "contractDescribeProviderConsumptionPath(...)",
                "contractDescribeProviderFallbackOutcomeGuide(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.ProviderSelection),
            expectedCode: Some(ContractErrorCode.CryptoUnavailable),
            expectedFamily: Some(ContractProviderErrorFamily.ProviderUnavailable),
            notes: [
                "represents the more realistic case where jinguissl is present but intentionally not selected as a stable path",
                "helps upper layers keep candidate-order visibility without presenting a failed selection as the default route"
            ]
        )
    )
    fixtures.toArray()
}

public func contractRequireProviderSmokeFixture(
    fixtureId: String
): ContractProviderSmokeFixtureInfo {
    let normalizedFixtureId = fixtureId.trimAscii()
    if (normalizedFixtureId.size == 0) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "provider smoke fixture id must not be empty"
        )
    }
    for (fixture in contractProviderSmokeFixtureCatalog()) {
        if (fixture.fixtureId == normalizedFixtureId) {
            return fixture
        }
    }
    throw ContractException(
        ContractErrorCode.BadInput,
        "unknown provider smoke fixture: ${normalizedFixtureId}"
    )
}

public func contractDescribeProviderSmokeBaseline(
    fixtureId: String
): ContractProviderSmokeBaselineReport {
    contractDescribeProviderSmokeBaselineRequest(
        ContractProviderSmokeBaselineRequest(fixtureId)
    )
}

public func contractDescribeProviderSmokeBaselineRequest(
    request: ContractProviderSmokeBaselineRequest
): ContractProviderSmokeBaselineReport {
    let fixture = contractRequireProviderSmokeFixture(request.fixtureId)
    let capability = contractProviderCapabilityRecord()
    let attachBoundary = contractProviderServerAttachBoundary()
    let executionMode = contractProviderSmokeExecutionModeForFixture(fixture)
    let warnings = contractProviderSmokeWarnings(
        fixture,
        executionMode,
        capability,
        attachBoundary
    )
    if (fixture.category == ContractProviderSmokeFixtureCategory.Success) {
        return ContractProviderSmokeBaselineReport(
            capability.providerId,
            fixture,
            executionMode,
            true,
            capability,
            attachBoundary,
            warnings
        )
    }
    let descriptor = contractDescribeProviderErrorCode(
        contractProviderSmokeExpectedCode(fixture),
        phase: contractProviderSmokeExpectedPhase(fixture),
        detail: "provider smoke baseline ${fixture.fixtureId}: ${fixture.summary}"
    )
    let fallback = contractRecommendProviderFallback(descriptor)
    ContractProviderSmokeBaselineReport(
        capability.providerId,
        fixture,
        executionMode,
        false,
        capability,
        attachBoundary,
        warnings,
        expectedDescriptor: Some(descriptor),
        expectedFallback: Some(fallback)
    )
}

public func contractTryDescribeProviderSmokeBaselineRequest(
    request: ContractProviderSmokeBaselineRequest
): ContractProviderSmokeBaselineOutcome {
    try {
        let result = contractDescribeProviderSmokeBaselineRequest(request)
        return ContractProviderSmokeBaselineOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderSmokeBaselineOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractDescribeProviderSmokeSuite(): ContractProviderSmokeSuiteReport {
    contractDescribeProviderSmokeSuiteRequest(ContractProviderSmokeSuiteRequest())
}

public func contractDescribeProviderSmokeSuiteRequest(
    request: ContractProviderSmokeSuiteRequest
): ContractProviderSmokeSuiteReport {
    let fixtureIds = contractProviderSmokeSuiteFixtureIds(request)
    let baselines = ArrayList<ContractProviderSmokeBaselineReport>()
    let recommendedOrder = ArrayList<String>()
    let warnings = ArrayList<String>()
    let capability = contractProviderCapabilityRecord()
    let attachBoundary = contractProviderServerAttachBoundary()
    var successFixtureCount: Int64 = 0
    var failureFixtureCount: Int64 = 0
    var precheckPathCount: Int64 = 0
    var verifyPathCount: Int64 = 0
    var providerSelectionPathCount: Int64 = 0
    var metadataOnlyCount: Int64 = 0
    for (fixtureId in fixtureIds) {
        let baseline = contractDescribeProviderSmokeBaseline(fixtureId)
        baselines.add(baseline)
        recommendedOrder.add(baseline.fixture.fixtureId)
        if (baseline.expectedSuccess) {
            successFixtureCount += 1
        } else {
            failureFixtureCount += 1
        }
        match (baseline.executionMode) {
            case ContractProviderSmokeExecutionMode.PrecheckPath =>
                precheckPathCount += 1
            case ContractProviderSmokeExecutionMode.VerifyPath =>
                verifyPathCount += 1
            case ContractProviderSmokeExecutionMode.ProviderSelectionPath =>
                providerSelectionPathCount += 1
            case ContractProviderSmokeExecutionMode.MetadataOnly =>
                metadataOnlyCount += 1
        }
        for (warning in baseline.warnings) {
            contractAppendUniqueString(warnings, warning)
        }
    }
    if (metadataOnlyCount > 0) {
        contractAppendUniqueString(
            warnings,
            "metadata-only smoke baselines should be asserted through contract descriptors instead of being counted as live handshake regressions"
        )
    }
    ContractProviderSmokeSuiteReport(
        capability.providerId,
        baselines.toArray(),
        Int64(baselines.size),
        successFixtureCount,
        failureFixtureCount,
        precheckPathCount,
        verifyPathCount,
        providerSelectionPathCount,
        metadataOnlyCount,
        recommendedOrder.toArray(),
        capability,
        attachBoundary,
        warnings.toArray()
    )
}

public func contractTryDescribeProviderSmokeSuiteRequest(
    request: ContractProviderSmokeSuiteRequest
): ContractProviderSmokeSuiteOutcome {
    try {
        let result = contractDescribeProviderSmokeSuiteRequest(request)
        return ContractProviderSmokeSuiteOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderSmokeSuiteOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractProviderSmokeSelfCheck(
    policy!: ContractProviderSmokeSelfCheckPolicy = ContractProviderSmokeSelfCheckPolicy()
): ContractProviderSmokeSelfCheckReport {
    let suite = contractDescribeProviderSmokeSuite()
    let capability = suite.capability
    let attach = contractProviderAttachContractInfo()
    let hasSuccessBaseline = suite.successFixtureCount > 0
    let hasPrecheckCoverage = suite.precheckPathCount > 0
    let hasVerifyCoverage = suite.verifyPathCount > 0
    let hasProviderSelectionCoverage = suite.providerSelectionPathCount > 0
    let hasHandshakeCoverage = suite.metadataOnlyCount > 0
    let hasLiveHandshakeCoverage = false
    var hasFallbackPlanCoverage = true
    for (baseline in suite.baselines) {
        if (!baseline.expectedSuccess) {
            match (baseline.expectedFallback) {
                case Some(_) => ()
                case None =>
                    hasFallbackPlanCoverage = false
            }
        }
    }
    let warnings = ArrayList<String>()
    for (warning in suite.warnings) {
        contractAppendUniqueString(warnings, warning)
    }
    let overallReady = contractProviderSmokeSelfCheckRequirement(
        warnings,
        policy,
        capability,
        attach,
        suite,
        hasSuccessBaseline,
        hasPrecheckCoverage,
        hasVerifyCoverage,
        hasProviderSelectionCoverage,
        hasHandshakeCoverage,
        hasLiveHandshakeCoverage,
        hasFallbackPlanCoverage
    )
    ContractProviderSmokeSelfCheckReport(
        policy,
        suite,
        capability.supportsClientTls,
        capability.supportsX509Verify,
        attach.supportsTlsPrecheck,
        hasSuccessBaseline,
        hasPrecheckCoverage,
        hasVerifyCoverage,
        hasProviderSelectionCoverage,
        hasHandshakeCoverage,
        hasLiveHandshakeCoverage,
        hasFallbackPlanCoverage,
        suite.attachBoundary.stableAttach,
        capability.defaultEligible,
        overallReady,
        warnings.toArray()
    )
}

public func contractRequireProviderSmokeSelfCheck(
    policy!: ContractProviderSmokeSelfCheckPolicy = ContractProviderSmokeSelfCheckPolicy()
): ContractProviderSmokeSelfCheckReport {
    let report = contractProviderSmokeSelfCheck(policy: policy)
    if (!report.overallReady) {
        let detail = contractProviderSmokeSelfCheckFailureDetail(report)
        throw ContractException(ContractErrorCode.Unsupported, detail)
    }
    report
}

public func contractTryProviderSmokeSelfCheck(
    policy!: ContractProviderSmokeSelfCheckPolicy = ContractProviderSmokeSelfCheckPolicy()
): ContractProviderSmokeSelfCheckOutcome {
    try {
        let result = contractProviderSmokeSelfCheck(policy: policy)
        return ContractProviderSmokeSelfCheckOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderSmokeSelfCheckOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryRequireProviderSmokeSelfCheck(
    policy!: ContractProviderSmokeSelfCheckPolicy = ContractProviderSmokeSelfCheckPolicy()
): ContractProviderSmokeSelfCheckOutcome {
    try {
        let result = contractRequireProviderSmokeSelfCheck(policy: policy)
        return ContractProviderSmokeSelfCheckOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderSmokeSelfCheckOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractDescribeProviderSmokeProfile(
    profile: ContractProviderSmokeProfile
): ContractProviderSmokeProfileTemplate {
    match (profile) {
        case ContractProviderSmokeProfile.ProviderCandidate =>
            ContractProviderSmokeProfileTemplate(
                profile,
                "provider-candidate",
                ContractProviderSmokeSelfCheckPolicy(),
                [
                    "default public gate for the current release line",
                    "requires provider-candidate readiness but does not require stable attach or default HTTPS eligibility"
                ]
            )
        case ContractProviderSmokeProfile.AttachPlanning =>
            ContractProviderSmokeProfileTemplate(
                profile,
                "attach-planning",
                ContractProviderSmokeSelfCheckPolicy(
                    requireProviderSelectionCoverage: false,
                    requireHandshakeCoverage: false,
                    requireFallbackPlan: true
                ),
                [
                    "optimized for teams that are still planning upper-layer attach integration",
                    "focuses on client TLS, X.509 verify, TLS precheck, success baseline, and fallback discipline"
                ]
            )
        case ContractProviderSmokeProfile.DefaultHttpsEligible =>
            ContractProviderSmokeProfileTemplate(
                profile,
                "default-https-eligible",
                ContractProviderSmokeSelfCheckPolicy(
                    requireStableServerAttach: true,
                    requireDefaultEligible: true
                ),
                [
                    "intended for release gates that want to promote jinguissl beyond provider-candidate status",
                    "fails until stable server attach and default HTTPS eligibility become public facts"
                ]
            )
        case ContractProviderSmokeProfile.LiveAttachExperimental =>
            ContractProviderSmokeProfileTemplate(
                profile,
                "live-attach-experimental",
                ContractProviderSmokeSelfCheckPolicy(
                    requireStableServerAttach: true,
                    requireLiveHandshakeCoverage: true
                ),
                [
                    "intended for experimental live attach validation work",
                    "requires a published stable attach path and a real handshake coverage baseline"
                ]
            )
        case ContractProviderSmokeProfile.ProductionStrict =>
            ContractProviderSmokeProfileTemplate(
                profile,
                "production-strict",
                ContractProviderSmokeSelfCheckPolicy(
                    requireStableServerAttach: true,
                    requireDefaultEligible: true,
                    requireLiveHandshakeCoverage: true
                ),
                [
                    "strictest provider gate for future production promotion",
                    "requires stable attach, default HTTPS eligibility, and live handshake coverage"
                ]
            )
    }
}

public func contractListProviderSmokeProfiles(): Array<ContractProviderSmokeProfileTemplate> {
    [
        contractDescribeProviderSmokeProfile(ContractProviderSmokeProfile.ProviderCandidate),
        contractDescribeProviderSmokeProfile(ContractProviderSmokeProfile.AttachPlanning),
        contractDescribeProviderSmokeProfile(ContractProviderSmokeProfile.DefaultHttpsEligible),
        contractDescribeProviderSmokeProfile(ContractProviderSmokeProfile.LiveAttachExperimental),
        contractDescribeProviderSmokeProfile(ContractProviderSmokeProfile.ProductionStrict)
    ]
}

public func contractRequireProviderSmokeProfile(
    profile: ContractProviderSmokeProfile
): ContractProviderSmokeSelfCheckReport {
    let template = contractDescribeProviderSmokeProfile(profile)
    contractRequireProviderSmokeSelfCheck(policy: template.policy)
}

public func contractTryRequireProviderSmokeProfile(
    profile: ContractProviderSmokeProfile
): ContractProviderSmokeSelfCheckOutcome {
    try {
        let result = contractRequireProviderSmokeProfile(profile)
        return ContractProviderSmokeSelfCheckOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderSmokeSelfCheckOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractDescribeProviderConsumptionPath(
    path: ContractProviderConsumptionPath
): ContractProviderConsumptionPathGuide {
    match (path) {
        case ContractProviderConsumptionPath.HttpClientTls =>
            ContractProviderConsumptionPathGuide(
                path,
                "http-client-tls",
                "provider-selection",
                true,
                true,
                false,
                true,
                "for HTTPS client paths, buildTlsAttachPlan(...) can be treated as a real provider attempt plan because client TLS verify/handshake are published contract surfaces; it still does not promote jinguissl to the default path",
                [
                    "client TLS may attempt jinguissl when upper-layer selection explicitly allows the provider-candidate path",
                    "verify failures should stay in tls_verify_error / no-auto-fallback instead of being silently downgraded"
                ],
                suggestedSmokeProfile: Some(ContractProviderSmokeProfile.ProviderCandidate),
                suggestedFallbackTarget: "stdx-default"
            )
        case ContractProviderConsumptionPath.HttpServerAttachPlanning =>
            ContractProviderConsumptionPathGuide(
                path,
                "http-server-attach-planning",
                "provider-planning",
                true,
                true,
                true,
                true,
                "for HTTPS server paths, buildTlsAttachPlan(...) currently means precheck, material preparation, and planning metadata only; final listener attach must stop in upper-layer glue such as lisi/stdx",
                [
                    "this is the correct public path for server-side jinguissl consumption today",
                    "candidate-order visibility is allowed here, but it must not be described as a default listener switch"
                ],
                suggestedSmokeProfile: Some(ContractProviderSmokeProfile.AttachPlanning),
                suggestedFallbackTarget: "stdx-default"
            )
        case ContractProviderConsumptionPath.HttpServerStableAttach =>
            ContractProviderConsumptionPathGuide(
                path,
                "http-server-stable-attach",
                "stable-server-attach",
                true,
                true,
                false,
                true,
                "a stable HTTPS listener attach attempt may use the published stable accepted-transport TLS1.3 X25519 contract path; full browser-grade HTTPS/H2 runtime closure remains a separate consumer/runtime concern",
                [
                    "this path is source-owned by JinguiSSL-contract and is safe for provider-gate selection",
                    "use stdx-default only as a manual fallback when the provider attach fails before connection consumption"
                ],
                suggestedSmokeProfile: Some(ContractProviderSmokeProfile.DefaultHttpsEligible),
                suggestedFallbackTarget: "stdx-default"
            )
        case ContractProviderConsumptionPath.SshClientLibrary =>
            ContractProviderConsumptionPathGuide(
                path,
                "ssh-client-library",
                "library-contract",
                true,
                false,
                false,
                true,
                "buildTlsAttachPlan(...) does not apply to SSH client runtime; consume SSH through jinguissl.contract.* handshake, host verification, and runtime bundle facades directly",
                [
                    "SSH client usage is a published library path rather than a stdx/listener provider attach path",
                    "host verification, runtime bundle, and rekey remain the intended stable consumption points"
                ]
            )
        case ContractProviderConsumptionPath.SshServerLibrary =>
            ContractProviderConsumptionPathGuide(
                path,
                "ssh-server-library",
                "library-contract",
                true,
                false,
                false,
                true,
                "buildTlsAttachPlan(...) does not apply to SSH server runtime; consume SSH server material, initial handshake, and runtime bundles directly through jinguissl.contract.*",
                [
                    "SSH server usage is already exposed as a stable library contract",
                    "this path does not depend on stdx TLS attach bridging"
                ]
            )
    }
}

public func contractListProviderConsumptionPaths(): Array<ContractProviderConsumptionPathGuide> {
    [
        contractDescribeProviderConsumptionPath(ContractProviderConsumptionPath.HttpClientTls),
        contractDescribeProviderConsumptionPath(ContractProviderConsumptionPath.HttpServerAttachPlanning),
        contractDescribeProviderConsumptionPath(ContractProviderConsumptionPath.HttpServerStableAttach),
        contractDescribeProviderConsumptionPath(ContractProviderConsumptionPath.SshClientLibrary),
        contractDescribeProviderConsumptionPath(ContractProviderConsumptionPath.SshServerLibrary)
    ]
}

public func contractDescribeProviderFallbackOutcomeGuide(
    causeCode: ContractProviderFallbackCauseCode
): ContractProviderFallbackOutcomeGuide {
    match (causeCode) {
        case ContractProviderFallbackCauseCode.ProviderUnavailable =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.ProviderUnavailable,
                ContractProviderErrorPhase.ProviderSelection,
                ContractProviderFallbackOutcome.SuggestedOnly,
                ContractProviderFallbackOutcome.SuggestedOnly,
                ContractProviderFallbackOutcome.NoFallback,
                false,
                [
                    "allow provider-candidate selection failures to fall back to the current stable default path",
                    "if the current selection is already stdx-default, record no-fallback instead of pretending a second automatic downgrade exists"
                ],
                suggestedFallbackTarget: "stdx-default"
            )
        case ContractProviderFallbackCauseCode.TlsHandshakeError =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.TlsHandshakeError,
                ContractProviderErrorPhase.TlsHandshake,
                ContractProviderFallbackOutcome.SuggestedOnly,
                ContractProviderFallbackOutcome.ManualReview,
                ContractProviderFallbackOutcome.NoFallback,
                false,
                [
                    "handshake failures may allow cautious retry or fallback only when the connection was not consumed",
                    "once the connection is consumed, the outcome should move to manual-review instead of silent downgrade"
                ],
                suggestedFallbackTarget: "stdx-default"
            )
        case ContractProviderFallbackCauseCode.TlsVerifyError =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.TlsVerifyError,
                ContractProviderErrorPhase.TlsVerify,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                true,
                [
                    "certificate verification failures must remain operator-visible and should not be auto-fallen back",
                    "this is the expected bucket for hostname, pin, trust-anchor, and revocation failures"
                ]
            )
        case ContractProviderFallbackCauseCode.TlsPrecheckError =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.TlsPrecheckError,
                ContractProviderErrorPhase.TlsPrecheck,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                true,
                [
                    "TLS precheck/material preparation failures should be surfaced directly and must not auto-switch the default path",
                    "use this bucket for cert/key mismatch and similar input-contract failures"
                ]
            )
        case ContractProviderFallbackCauseCode.TlsNotConfigured =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.Unsupported,
                ContractProviderErrorPhase.TlsHandshake,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                true,
                [
                    "treat cleartext-or-unsupported peer paths as explicit no-auto-fallback failures",
                    "do not rewrite tls_not_configured into a successful provider attach story"
                ]
            )
        case ContractProviderFallbackCauseCode.CryptoUnavailable =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.CryptoUnavailable,
                ContractProviderErrorPhase.ProviderRuntime,
                ContractProviderFallbackOutcome.SuggestedOnly,
                ContractProviderFallbackOutcome.SuggestedOnly,
                ContractProviderFallbackOutcome.ManualReview,
                false,
                [
                    "crypto provider unavailability may suggest a return to the stable default path",
                    "if the stable default path is already active, escalate to manual-review instead of manufacturing another fallback"
                ],
                suggestedFallbackTarget: "stdx-default"
            )
    }
}

public func contractListProviderFallbackOutcomeGuides(): Array<ContractProviderFallbackOutcomeGuide> {
    [
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.ProviderUnavailable),
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.TlsHandshakeError),
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.TlsVerifyError),
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.TlsPrecheckError),
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.TlsNotConfigured),
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.CryptoUnavailable)
    ]
}

public func contractResolveProviderFallbackOutcome(
    request: ContractProviderFallbackResolutionRequest
): ContractProviderFallbackResolution {
    let guide = contractDescribeProviderFallbackOutcomeGuide(request.causeCode)
    let finalOutcome = if (request.connectionConsumed) {
        guide.consumedConnectionOutcome
    } else if (request.alreadyOnStableDefault) {
        guide.stableDefaultOutcome
    } else {
        guide.defaultOutcome
    }
    let fallbackTarget = if (finalOutcome == ContractProviderFallbackOutcome.SuggestedOnly) {
        guide.suggestedFallbackTarget
    } else {
        ""
    }
    let notes = ArrayList<String>()
    for (note in guide.notes) {
        notes.add(note)
    }
    match (finalOutcome) {
        case ContractProviderFallbackOutcome.SuggestedOnly =>
            notes.add("current result stays in suggested-only; upper layers may fall back to the stable default path if policy allows")
        case ContractProviderFallbackOutcome.NoAutoFallback =>
            notes.add("current result stays in no-auto-fallback; surface the error instead of auto-switching transport/provider")
        case ContractProviderFallbackOutcome.NoFallback =>
            notes.add("current result stays in no-fallback because no lower stable path remains to switch to")
        case ContractProviderFallbackOutcome.ManualReview =>
            notes.add("current result stays in manual-review; operator or higher-level retry logic must decide the next step")
    }
    ContractProviderFallbackResolution(
        guide,
        finalOutcome,
        notes.toArray(),
        fallbackTarget: fallbackTarget,
        shouldRecord: true,
        mustSurface: guide.mustSurface
    )
}

private func contractProviderConsumptionEntryId(
    path: ContractProviderConsumptionPath
): String {
    match (path) {
        case ContractProviderConsumptionPath.HttpClientTls => "jinguissl-provider-candidate"
        case ContractProviderConsumptionPath.HttpServerAttachPlanning => "jinguissl-provider-candidate"
        case ContractProviderConsumptionPath.HttpServerStableAttach => "jinguissl-provider-candidate"
        case ContractProviderConsumptionPath.SshClientLibrary => "jinguissl-library-direct"
        case ContractProviderConsumptionPath.SshServerLibrary => "jinguissl-library-direct"
    }
}

private func contractProviderConsumptionCandidateOrder(
    entryId: String,
    fallbackChain: Array<String>
): Array<String> {
    let order = ArrayList<String>()
    contractAppendUniqueString(order, entryId)
    for (fallback in fallbackChain) {
        contractAppendUniqueString(order, fallback)
    }
    order.toArray()
}

private func contractProviderConsumptionBlockedReason(
    guide: ContractProviderConsumptionPathGuide,
    smokeReadiness: ?ContractProviderSmokeSelfCheckReport
): String {
    if (!guide.publishedContractPath) {
        return "stable_attach_unpublished"
    }
    if (!guide.attemptAllowed) {
        return "attempt_not_allowed"
    }
    match (smokeReadiness) {
        case Some(value) =>
            if (!value.overallReady) {
                return "smoke_gate_not_ready"
            }
        case None => ()
    }
    "not_ready"
}

private func contractProviderConsumptionBlockedCandidates(
    entryId: String,
    guide: ContractProviderConsumptionPathGuide,
    smokeReadiness: ?ContractProviderSmokeSelfCheckReport,
    readyNow: Bool
): Array<String> {
    if (readyNow) {
        return []
    }
    ["${entryId}:${contractProviderConsumptionBlockedReason(guide, smokeReadiness)}"]
}

private func contractProviderConsumptionObservabilityTags(
    providerId: String,
    entryId: String,
    guide: ContractProviderConsumptionPathGuide,
    publicPath: String,
    releasePath: String,
    riskLevel: String,
    readyNow: Bool,
    selectedEntryId: String
): Array<String> {
    let tags = ArrayList<String>()
    let readyTag = if (readyNow) { "true" } else { "false" }
    let selectedTag = if (selectedEntryId.trimAscii().size > 0) {
        selectedEntryId.trimAscii()
    } else {
        "none"
    }
    let publishedTag = if (guide.publishedContractPath) { "true" } else { "false" }
    let providerSelectionTag = if (guide.useProviderSelection) { "true" } else { "false" }
    let attachGlueTag = if (guide.requiresUpperLayerAttachGlue) { "true" } else { "false" }
    contractAppendUniqueString(tags, "provider_id:${providerId}")
    contractAppendUniqueString(tags, "provider_entry:${entryId}")
    contractAppendUniqueString(tags, "selected_entry:${selectedTag}")
    contractAppendUniqueString(tags, "path:${guide.label}")
    contractAppendUniqueString(tags, "consumer_kind:${guide.consumerKind}")
    contractAppendUniqueString(tags, "public_path:${publicPath}")
    contractAppendUniqueString(tags, "release_path:${releasePath}")
    contractAppendUniqueString(tags, "risk_level:${riskLevel}")
    contractAppendUniqueString(tags, "ready_now:${readyTag}")
    contractAppendUniqueString(tags, "published_contract_path:${publishedTag}")
    contractAppendUniqueString(tags, "use_provider_selection:${providerSelectionTag}")
    contractAppendUniqueString(tags, "requires_upper_layer_attach_glue:${attachGlueTag}")
    tags.toArray()
}

public func contractDescribeProviderConsumptionGate(
    path: ContractProviderConsumptionPath
): ContractProviderConsumptionGateReport {
    let guide = contractDescribeProviderConsumptionPath(path)
    let capability = contractProviderCapabilityRecord()
    let attachBoundary = contractProviderServerAttachBoundary()
    let status = match (path) {
        case ContractProviderConsumptionPath.HttpClientTls =>
            ContractProviderConsumptionGateStatus.ProviderCandidate
        case ContractProviderConsumptionPath.HttpServerAttachPlanning =>
            ContractProviderConsumptionGateStatus.PlanningOnly
        case ContractProviderConsumptionPath.HttpServerStableAttach =>
            ContractProviderConsumptionGateStatus.ProviderCandidate
        case ContractProviderConsumptionPath.SshClientLibrary =>
            ContractProviderConsumptionGateStatus.LibraryContract
        case ContractProviderConsumptionPath.SshServerLibrary =>
            ContractProviderConsumptionGateStatus.LibraryContract
    }
    let publicPath = match (status) {
        case ContractProviderConsumptionGateStatus.ProviderCandidate => "provider-candidate"
        case ContractProviderConsumptionGateStatus.PlanningOnly => "attach-planning"
        case ContractProviderConsumptionGateStatus.LibraryContract => "library-contract"
        case ContractProviderConsumptionGateStatus.Blocked => "blocked"
    }
    let releasePath = match (status) {
        case ContractProviderConsumptionGateStatus.ProviderCandidate => "experimental-only"
        case ContractProviderConsumptionGateStatus.PlanningOnly => "experimental-only"
        case ContractProviderConsumptionGateStatus.LibraryContract => "library-direct"
        case ContractProviderConsumptionGateStatus.Blocked => "unsupported"
    }
    let riskLevel = match (status) {
        case ContractProviderConsumptionGateStatus.ProviderCandidate => "medium"
        case ContractProviderConsumptionGateStatus.PlanningOnly => "medium"
        case ContractProviderConsumptionGateStatus.LibraryContract => "low"
        case ContractProviderConsumptionGateStatus.Blocked => "high"
    }
    let warnings = ArrayList<String>()
    for (note in guide.notes) {
        contractAppendUniqueString(warnings, note)
    }
    if (guide.requiresUpperLayerAttachGlue || !guide.publishedContractPath) {
        contractAppendUniqueString(warnings, attachBoundary.detail)
        for (reason in attachBoundary.unsupportedReasons) {
            contractAppendUniqueString(warnings, reason)
        }
    }
    if (!guide.publishedContractPath) {
        for (reason in capability.unsupportedReasons) {
            contractAppendUniqueString(warnings, reason)
        }
    }
    let smokeProfile: ?ContractProviderSmokeProfileTemplate = if (
        let Some(profile) <- guide.suggestedSmokeProfile
    ) {
        Some(contractDescribeProviderSmokeProfile(profile))
    } else {
        None
    }
    let smokeReadiness: ?ContractProviderSmokeSelfCheckReport = match (smokeProfile) {
        case Some(template) =>
            let readiness = contractProviderSmokeSelfCheck(policy: template.policy)
            for (note in template.notes) {
                contractAppendUniqueString(warnings, note)
            }
            for (warning in readiness.warnings) {
                contractAppendUniqueString(warnings, warning)
            }
            Some(readiness)
        case None => None
    }
    if (guide.suggestedFallbackTarget.trimAscii().size > 0) {
        contractAppendUniqueString(
            warnings,
            "preferred fallback target remains ${guide.suggestedFallbackTarget}"
        )
    }
    let fallbackChain = ArrayList<String>()
    if (guide.suggestedFallbackTarget.trimAscii().size > 0) {
        fallbackChain.add(guide.suggestedFallbackTarget)
    }
    let smokeReady = match (smokeReadiness) {
        case Some(value) => value.overallReady
        case None => true
    }
    let readyNow = guide.attemptAllowed && guide.publishedContractPath && smokeReady
    let providerId = capability.providerId
    let entryId = contractProviderConsumptionEntryId(path)
    let candidateOrder = contractProviderConsumptionCandidateOrder(
        entryId,
        fallbackChain.toArray()
    )
    let selectedEntryId = if (readyNow) { entryId } else { "" }
    let blockedCandidates = contractProviderConsumptionBlockedCandidates(
        entryId,
        guide,
        smokeReadiness,
        readyNow
    )
    let observabilityTags = contractProviderConsumptionObservabilityTags(
        providerId,
        entryId,
        guide,
        publicPath,
        releasePath,
        riskLevel,
        readyNow,
        selectedEntryId
    )
    let selectedReason = match (status) {
        case ContractProviderConsumptionGateStatus.ProviderCandidate =>
            if (smokeReady) {
                "path is published as a provider-candidate route; upper layers may attempt jinguissl through provider selection and keep stdx-default as the stable fallback target"
            } else {
                let smokeDetail = match (smokeReadiness) {
                    case Some(value) => contractProviderSmokeSelfCheckFailureDetail(value)
                    case None => "provider-candidate smoke profile is unavailable"
                }
                "path is a provider-candidate route, but the mapped smoke gate is not ready: ${smokeDetail}"
            }
        case ContractProviderConsumptionGateStatus.PlanningOnly =>
            if (smokeReady) {
                "path is published for precheck, material preparation, and attach planning only; upper-layer glue must complete the final listener attach"
            } else {
                let smokeDetail = match (smokeReadiness) {
                    case Some(value) => contractProviderSmokeSelfCheckFailureDetail(value)
                    case None => "attach-planning smoke profile is unavailable"
                }
                "path remains planning-only, but the mapped attach-planning smoke gate is not ready: ${smokeDetail}"
            }
        case ContractProviderConsumptionGateStatus.LibraryContract =>
            "path is published as a stable library contract and does not depend on provider-selection or stdx attach glue"
        case ContractProviderConsumptionGateStatus.Blocked =>
            let smokeDetail = match (smokeReadiness) {
                case Some(value) => contractProviderSmokeSelfCheckFailureDetail(value)
                case None => "default HTTPS eligibility is unavailable"
            }
            "path is currently blocked because stable HTTPS listener attach is not a published jinguissl contract: ${smokeDetail}"
    }
    ContractProviderConsumptionGateReport(
        path,
        guide,
        status,
        providerId,
        selectedEntryId,
        candidateOrder,
        blockedCandidates,
        publicPath,
        releasePath,
        riskLevel,
        observabilityTags,
        capability,
        attachBoundary,
        readyNow,
        selectedReason,
        warnings.toArray(),
        smokeProfile: smokeProfile,
        smokeReadiness: smokeReadiness,
        fallbackTarget: guide.suggestedFallbackTarget,
        fallbackChain: fallbackChain.toArray()
    )
}

public func contractListProviderConsumptionGates(): Array<ContractProviderConsumptionGateReport> {
    [
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.HttpClientTls),
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.HttpServerAttachPlanning),
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.HttpServerStableAttach),
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.SshClientLibrary),
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.SshServerLibrary)
    ]
}

public func contractRequireProviderConsumptionGate(
    path: ContractProviderConsumptionPath
): ContractProviderConsumptionGateReport {
    let report = contractDescribeProviderConsumptionGate(path)
    if (!report.readyNow) {
        let warnings = ArrayList<String>()
        for (warning in report.warnings) {
            contractAppendUniqueString(warnings, warning)
        }
        if (report.fallbackTarget.trimAscii().size > 0) {
            contractAppendUniqueString(warnings, "suggested fallback target: ${report.fallbackTarget}")
        }
        let detail = contractJoinMessages(
            warnings.toArray(),
            "provider consumption gate ${report.publicPath} is not ready: ${report.selectedReason}; "
        )
        throw ContractException(ContractErrorCode.Unsupported, detail)
    }
    report
}

public func contractTryRequireProviderConsumptionGate(
    path: ContractProviderConsumptionPath
): ContractProviderConsumptionGateOutcome {
    try {
        let result = contractRequireProviderConsumptionGate(path)
        return ContractProviderConsumptionGateOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderConsumptionGateOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public class ContractAesHardwareMountPointInfo {
    public let backend: String
    public let available: Bool
    public let accelerated: Bool
    public let detected: Bool
    public let detail: String

    public init(
        backend: String,
        available: Bool,
        accelerated: Bool,
        detected: Bool,
        detail: String
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES hardware mount point backend must not be empty")
        }
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES hardware mount point detail must not be empty")
        }
        this.backend = backend.trimAscii()
        this.available = available
        this.accelerated = accelerated
        this.detected = detected
        this.detail = detail.trimAscii()
    }
}

public class ContractAesHardwareProbeInfo {
    public let available: Bool
    public let backend: String
    public let accelerated: Bool
    public let detail: String

    public init(
        available: Bool,
        backend: String,
        accelerated: Bool,
        detail: String
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES hardware probe backend must not be empty")
        }
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES hardware probe detail must not be empty")
        }
        this.available = available
        this.backend = backend.trimAscii()
        this.accelerated = accelerated
        this.detail = detail.trimAscii()
    }
}

public class ContractAesHardwareRoadmapEntry {
    public let architecture: String
    public let backend: String
    public let status: String
    public let targetVersion: String
    public let detail: String

    public init(
        architecture: String,
        backend: String,
        status: String,
        targetVersion: String,
        detail: String
    ) {
        if (
            architecture.trimAscii().size == 0 ||
            backend.trimAscii().size == 0 ||
            status.trimAscii().size == 0 ||
            targetVersion.trimAscii().size == 0 ||
            detail.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES hardware roadmap entry fields must not be empty"
            )
        }
        this.architecture = architecture.trimAscii()
        this.backend = backend.trimAscii()
        this.status = status.trimAscii()
        this.targetVersion = targetVersion.trimAscii()
        this.detail = detail.trimAscii()
    }
}

public enum ContractAesEngineKind <: Equatable<ContractAesEngineKind> & ToString {
    | Auto
    | Software
    | Hardware

    public operator func ==(right: ContractAesEngineKind): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractAesEngineKind): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Auto => 0
            case Software => 1
            case Hardware => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Auto => "AUTO"
            case Software => "SOFTWARE"
            case Hardware => "HARDWARE"
        }
    }
}

public class ContractAesEngineInfo {
    public let requested: ContractAesEngineKind
    public let active: ContractAesEngineKind
    public let backend: String
    public let accelerated: Bool
    public let detail: String

    public init(
        requested: ContractAesEngineKind,
        active: ContractAesEngineKind,
        backend: String,
        accelerated: Bool,
        detail: String
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES engine backend must not be empty")
        }
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES engine detail must not be empty")
        }
        this.requested = requested
        this.active = active
        this.backend = backend.trimAscii()
        this.accelerated = accelerated
        this.detail = detail.trimAscii()
    }
}

public class ContractAesEngineResolveOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractAesEngineInfo

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractAesEngineInfo = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES engine resolve outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome result must be empty when ok is false"
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

public class ContractAesNativeBridgeSpec {
    public let backend: String
    public let libraryPath: String
    public let symbolPrefix: String
    public let abiVersion: Int64

    public init(
        backend: String,
        libraryPath!: String = "",
        symbolPrefix!: String = "jinguissl_aes",
        abiVersion!: Int64 = 1
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES native bridge backend must not be empty")
        }
        if (symbolPrefix.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES native bridge symbol prefix must not be empty")
        }
        if (abiVersion <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES native bridge ABI version must be positive")
        }
        this.backend = backend.trimAscii()
        this.libraryPath = libraryPath.trimAscii()
        this.symbolPrefix = symbolPrefix.trimAscii()
        this.abiVersion = abiVersion
    }
}

public class ContractAesNativeBridgeContractInfo {
    public let backend: String
    public let abiVersion: Int64
    public let expandKeySymbol: String
    public let encryptBlocksSymbol: String
    public let decryptBlocksSymbol: String
    public let ghashMulSymbol: String
    public let detail: String

    public init(
        backend: String,
        abiVersion: Int64,
        expandKeySymbol: String,
        encryptBlocksSymbol: String,
        decryptBlocksSymbol: String,
        ghashMulSymbol: String,
        detail: String
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES native bridge contract backend must not be empty")
        }
        if (
            expandKeySymbol.trimAscii().size == 0 ||
            encryptBlocksSymbol.trimAscii().size == 0 ||
            decryptBlocksSymbol.trimAscii().size == 0 ||
            ghashMulSymbol.trimAscii().size == 0 ||
            detail.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES native bridge contract symbol/detail fields must not be empty"
            )
        }
        this.backend = backend.trimAscii()
        this.abiVersion = abiVersion
        this.expandKeySymbol = expandKeySymbol.trimAscii()
        this.encryptBlocksSymbol = encryptBlocksSymbol.trimAscii()
        this.decryptBlocksSymbol = decryptBlocksSymbol.trimAscii()
        this.ghashMulSymbol = ghashMulSymbol.trimAscii()
        this.detail = detail.trimAscii()
    }
}

public class ContractAesNativeBridgeCallShapeInfo {
    public let backend: String
    public let abiVersion: Int64
    public let keyBytes: Int64
    public let roundCount: Int64
    public let roundKeyWordCount: Int64
    public let expandedKeyBlobBytes: Int64
    public let blockBytes: Int64
    public let requiresBlockAlignedPayload: Bool

    public init(
        backend: String,
        abiVersion: Int64,
        keyBytes: Int64,
        roundCount: Int64,
        roundKeyWordCount: Int64,
        expandedKeyBlobBytes: Int64,
        blockBytes: Int64,
        requiresBlockAlignedPayload: Bool
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES native bridge call-shape backend must not be empty")
        }
        if (keyBytes <= 0 || roundCount <= 0 || roundKeyWordCount <= 0 || expandedKeyBlobBytes <= 0 || blockBytes <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES native bridge call-shape numeric fields must be positive"
            )
        }
        this.backend = backend.trimAscii()
        this.abiVersion = abiVersion
        this.keyBytes = keyBytes
        this.roundCount = roundCount
        this.roundKeyWordCount = roundKeyWordCount
        this.expandedKeyBlobBytes = expandedKeyBlobBytes
        this.blockBytes = blockBytes
        this.requiresBlockAlignedPayload = requiresBlockAlignedPayload
    }
}

public class ContractAesNativeBridgeDiagnostics {
    public let spec: ContractAesNativeBridgeSpec
    public let probe: ContractAesHardwareProbeInfo
    public let engine: ContractAesEngineInfo
    public let contract: ContractAesNativeBridgeContractInfo

    public init(
        spec: ContractAesNativeBridgeSpec,
        probe: ContractAesHardwareProbeInfo,
        engine: ContractAesEngineInfo,
        contract: ContractAesNativeBridgeContractInfo
    ) {
        this.spec = ContractAesNativeBridgeSpec(
            spec.backend,
            libraryPath: spec.libraryPath,
            symbolPrefix: spec.symbolPrefix,
            abiVersion: spec.abiVersion
        )
        this.probe = probe
        this.engine = engine
        this.contract = contract
    }
}

public class ContractAesNativeBridgeDiagnosticsOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractAesNativeBridgeDiagnostics

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractAesNativeBridgeDiagnostics = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES native bridge diagnostics outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome result must be empty when ok is false"
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

public enum ContractAesBackendReadiness <: Equatable<ContractAesBackendReadiness> & ToString {
    | AcceleratedReady
    | BridgeReady
    | SoftwareOnly
    | Unavailable

    public operator func ==(right: ContractAesBackendReadiness): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractAesBackendReadiness): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case AcceleratedReady => 0
            case BridgeReady => 1
            case SoftwareOnly => 2
            case Unavailable => 3
        }
    }

    public func toString(): String {
        match (this) {
            case AcceleratedReady => "ACCELERATED_READY"
            case BridgeReady => "BRIDGE_READY"
            case SoftwareOnly => "SOFTWARE_ONLY"
            case Unavailable => "UNAVAILABLE"
        }
    }
}

public class ContractAesBackendRecommendation {
    public let backendHint: String
    public let readiness: ContractAesBackendReadiness
    public let accelerated: Bool
    public let reason: String

    public init(
        backendHint: String,
        readiness: ContractAesBackendReadiness,
        accelerated: Bool,
        reason: String
    ) {
        if (backendHint.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES backend recommendation hint must not be empty")
        }
        if (reason.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES backend recommendation reason must not be empty")
        }
        this.backendHint = backendHint.trimAscii()
        this.readiness = readiness
        this.accelerated = accelerated
        this.reason = reason.trimAscii()
    }
}

public class ContractAesStartupSelfCheckReport {
    public let defaultBackendHint: String
    public let effectiveBackendHint: String
    public let recommendation: ContractAesBackendRecommendation
    public let selectedEngine: ContractAesEngineInfo
    public let acceleratedBackendReady: Bool
    public let mountPoints: Array<ContractAesHardwareMountPointInfo>
    public let diagnostics: ?ContractAesNativeBridgeDiagnostics

    public init(
        defaultBackendHint: String,
        effectiveBackendHint: String,
        recommendation: ContractAesBackendRecommendation,
        selectedEngine: ContractAesEngineInfo,
        acceleratedBackendReady: Bool,
        mountPoints: Array<ContractAesHardwareMountPointInfo>,
        diagnostics!: ?ContractAesNativeBridgeDiagnostics = None
    ) {
        if (effectiveBackendHint.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES startup self-check effective backend hint must not be empty")
        }
        if (mountPoints.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES startup self-check mount points must not be empty")
        }
        this.defaultBackendHint = defaultBackendHint.trimAscii()
        this.effectiveBackendHint = effectiveBackendHint.trimAscii()
        this.recommendation = recommendation
        this.selectedEngine = selectedEngine
        this.acceleratedBackendReady = acceleratedBackendReady
        this.mountPoints = mountPoints.clone()
        this.diagnostics = diagnostics
    }
}

public class ContractAesCurrentReleasePlanReport {
    public let currentReleaseSeries: String
    public let primaryBackend: String
    public let primaryArchitectures: Array<String>
    public let deferredBackends: Array<String>
    public let reservedBackends: Array<String>
    public let startup: ContractAesStartupSelfCheckReport
    public let usingPrimaryBackend: Bool
    public let primaryBackendAvailable: Bool
    public let warnings: Array<String>

    public init(
        currentReleaseSeries: String,
        primaryBackend: String,
        primaryArchitectures: Array<String>,
        deferredBackends: Array<String>,
        reservedBackends: Array<String>,
        startup: ContractAesStartupSelfCheckReport,
        usingPrimaryBackend: Bool,
        primaryBackendAvailable: Bool,
        warnings: Array<String>
    ) {
        if (currentReleaseSeries.trimAscii().size == 0 || primaryBackend.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES current release plan report release series and primary backend must not be empty"
            )
        }
        if (primaryArchitectures.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES current release plan report primary architectures must not be empty"
            )
        }
        this.currentReleaseSeries = currentReleaseSeries.trimAscii()
        this.primaryBackend = primaryBackend.trimAscii()
        this.primaryArchitectures = primaryArchitectures.clone()
        this.deferredBackends = deferredBackends.clone()
        this.reservedBackends = reservedBackends.clone()
        this.startup = startup
        this.usingPrimaryBackend = usingPrimaryBackend
        this.primaryBackendAvailable = primaryBackendAvailable
        this.warnings = warnings.clone()
    }
}

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
            throw ContractException(ContractErrorCode.BadInput, "HTTP/SSH startup profile label must not be empty")
        }
        if (notes.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "HTTP/SSH startup profile notes must not be empty")
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

public func contractAesListHardwareMountPoints(): Array<ContractAesHardwareMountPointInfo> {
    let mounts = aesListHardwareMountPoints()
    let converted = ArrayList<ContractAesHardwareMountPointInfo>()
    for (mount in mounts) {
        converted.add(contractFromAesHardwareMountPoint(mount))
    }
    converted.toArray()
}

public func contractAesHardwareRoadmap(): Array<ContractAesHardwareRoadmapEntry> {
    let entries = aesHardwareRoadmap()
    let converted = ArrayList<ContractAesHardwareRoadmapEntry>()
    for (entry in entries) {
        converted.add(contractFromAesHardwareRoadmapEntry(entry))
    }
    converted.toArray()
}

public func contractAesDefaultHardwareBackendHint(): String {
    aesDefaultHardwareBackendHint()
}

public func contractAesProbeHardware(backendHint!: String = ""): ContractAesHardwareProbeInfo {
    contractFromAesHardwareProbe(aesProbeHardware(backendHint: backendHint))
}

public func contractResolveAesEngine(
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    backendHint!: String = ""
): ContractAesEngineInfo {
    try {
        contractFromAesEngine(
            aesResolveEngine(
                requested: contractToAesEngineKind(requestedEngine),
                hardwareHint: backendHint
            )
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            contractMapCryptoExceptionToErrorCode(e, operation: "aes"),
            "AES engine resolve failed: ${e.message}"
        )
    }
}

public func contractTryResolveAesEngine(
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    backendHint!: String = ""
): ContractAesEngineResolveOutcome {
    try {
        let result = contractResolveAesEngine(requestedEngine: requestedEngine, backendHint: backendHint)
        ContractAesEngineResolveOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractAesEngineResolveOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractRequireAesAcceleratedBackend(
    backendHint!: String = ""
): ContractAesHardwareProbeInfo {
    let probe = contractAesProbeHardware(backendHint: backendHint)
    if (!probe.available || !probe.accelerated) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "AES accelerated backend is required: ${probe.detail}"
        )
    }
    probe
}

public func contractInspectAesNativeBridge(
    spec: ContractAesNativeBridgeSpec,
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto
): ContractAesNativeBridgeDiagnostics {
    try {
        let innerSpec = contractToAesNativeBridgeSpec(spec)
        let handle = aesOpenNativeBridge(innerSpec)
        let engine = aesResolveEngineWithNativeBridge(
            innerSpec,
            requested: contractToAesEngineKind(requestedEngine)
        )
        ContractAesNativeBridgeDiagnostics(
            spec,
            contractFromAesHardwareProbe(handle.probe),
            contractFromAesEngine(engine),
            contractFromAesNativeBridgeContract(handle.contract)
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            contractMapCryptoExceptionToErrorCode(e, operation: "aes"),
            "AES native bridge inspection failed: ${e.message}"
        )
    }
}

public func contractTryInspectAesNativeBridge(
    spec: ContractAesNativeBridgeSpec,
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto
): ContractAesNativeBridgeDiagnosticsOutcome {
    try {
        let result = contractInspectAesNativeBridge(spec, requestedEngine: requestedEngine)
        ContractAesNativeBridgeDiagnosticsOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractAesNativeBridgeDiagnosticsOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractDescribeAesNativeBridgeCallShape(
    spec: ContractAesNativeBridgeSpec,
    keyBytes: Int64
): ContractAesNativeBridgeCallShapeInfo {
    try {
        let innerSpec = contractToAesNativeBridgeSpec(spec)
        let handle = aesOpenNativeBridge(innerSpec)
        contractFromAesNativeBridgeCallShape(aesNativeBridgeDescribeCallShape(handle, keyBytes))
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            contractMapCryptoExceptionToErrorCode(e, operation: "aes"),
            "AES native bridge call-shape describe failed: ${e.message}"
        )
    }
}

public func contractRecommendAesBackend(): ContractAesBackendRecommendation {
    let mounts = contractAesListHardwareMountPoints()
    let armv8 = contractFindAesMountPoint(mounts, "armv8-ce")
    match (armv8) {
        case Some(value) =>
            if (value.available && value.accelerated) {
                return ContractAesBackendRecommendation(
                    "armv8-ce",
                    ContractAesBackendReadiness.AcceleratedReady,
                    true,
                    "ARMv8 CE native backend is available and accelerated on current runtime"
                )
            }
        case None => ()
    }

    let shim = contractFindAesMountPoint(mounts, "shim")
    match (shim) {
        case Some(value) =>
            if (value.available) {
                return ContractAesBackendRecommendation(
                    "shim",
                    ContractAesBackendReadiness.BridgeReady,
                    false,
                    "software shim backend is available for bridge-path validation but does not provide hardware acceleration"
                )
            }
        case None => ()
    }

    ContractAesBackendRecommendation(
        "none",
        ContractAesBackendReadiness.Unavailable,
        false,
        "no AES hardware backend is currently available; software AES remains usable"
    )
}

public func contractAesStartupSelfCheck(
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    backendHint!: String = ""
): ContractAesStartupSelfCheckReport {
    let mounts = contractAesListHardwareMountPoints()
    let recommendation = contractRecommendAesBackend()
    let defaultHint = contractAesDefaultHardwareBackendHint().trimAscii()
    let overrideHint = backendHint.trimAscii()
    let effectiveHint = if (overrideHint.size > 0) {
        overrideHint
    } else if (defaultHint.size > 0) {
        defaultHint
    } else {
        recommendation.backendHint
    }
    let selectedEngine = contractResolveAesEngine(requestedEngine: requestedEngine, backendHint: effectiveHint)
    let diagnostics: ?ContractAesNativeBridgeDiagnostics = if (selectedEngine.backend == "none") {
        None
    } else {
        Some(contractInspectAesNativeBridge(ContractAesNativeBridgeSpec(selectedEngine.backend), requestedEngine: requestedEngine))
    }
    ContractAesStartupSelfCheckReport(
        defaultHint,
        effectiveHint,
        recommendation,
        selectedEngine,
        selectedEngine.accelerated,
        mounts,
        diagnostics: diagnostics
    )
}

public func contractAesCurrentReleasePlan(
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    backendHint!: String = ""
): ContractAesCurrentReleasePlanReport {
    let startup = contractAesStartupSelfCheck(
        requestedEngine: requestedEngine,
        backendHint: backendHint
    )
    let roadmap = contractAesHardwareRoadmap()
    let primaryBackend = contractFindPrimaryAesRoadmapBackend(roadmap)
    let primaryArchitectures = contractCollectAesRoadmapArchitectures(
        roadmap,
        "PRIMARY_ACTIVE"
    )
    let deferredBackends = contractCollectAesRoadmapBackendsByPrefix(
        roadmap,
        "DEFERRED"
    )
    let reservedBackends = contractCollectAesRoadmapBackendsByPrefix(
        roadmap,
        "RESERVED"
    )
    let primaryMount = contractFindAesMountPoint(startup.mountPoints, primaryBackend)
    let primaryBackendAvailable = match (primaryMount) {
        case Some(value) => value.available && value.accelerated
        case None => false
    }
    let usingPrimaryBackend = startup.selectedEngine.backend == primaryBackend && startup.selectedEngine.accelerated
    let warnings = ArrayList<String>()
    if (!primaryBackendAvailable) {
        warnings.add("current release primary backend is unavailable on this runtime")
    }
    if (!usingPrimaryBackend) {
        warnings.add("selected AES backend is not the current 0.6 primary backend")
    }
    if (contractContainsString(deferredBackends, "aesni")) {
        warnings.add("x86_64 AES-NI remains deferred to 0.7 in the current release plan")
    }
    if (reservedBackends.size > 0) {
        warnings.add("loongarch64/riscv64 backends remain reserved skeletons in the current release plan")
    }
    ContractAesCurrentReleasePlanReport(
        "0.6",
        primaryBackend,
        primaryArchitectures,
        deferredBackends,
        reservedBackends,
        startup,
        usingPrimaryBackend,
        primaryBackendAvailable,
        warnings.toArray()
    )
}

public func contractRequireAesCurrentReleasePrimaryBackend(
    backendHint!: String = ""
): ContractAesCurrentReleasePlanReport {
    let report = contractAesCurrentReleasePlan(
        requestedEngine: ContractAesEngineKind.Hardware,
        backendHint: backendHint
    )
    if (!report.primaryBackendAvailable) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "current release primary backend is unavailable: ${report.primaryBackend}"
        )
    }
    if (!report.usingPrimaryBackend) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "current release requires primary backend ${report.primaryBackend}, but selected backend is ${report.startup.selectedEngine.backend}"
        )
    }
    report
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
        let httpTlsReady = contractHasAllFeatures(
            capability.httpTlsFeatures,
            [
                "tls12-rsa",
                "tls13-x25519",
                "http-server-tls-config-validation",
                "http-client-trust-material-preparation",
                "alpn-normalization"
            ]
        )
        let sshReady = contractHasAllFeatures(
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
        let x509Ready = contractHasAllFeatures(
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
            contractMapCryptoExceptionToErrorCode(e, operation: "startup"),
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
        let message = contractJoinMessages(
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
        throw ContractException(ContractErrorCode.BadInput, "runtime startup profile catalog is missing the requested profile")
    }
    let entry = catalog[index]
    if (entry.label != contractHttpSshStartupProfileExpectedLabel(profile)) {
        throw ContractException(ContractErrorCode.BadInput, "runtime startup profile catalog order does not match contract profile order")
    }
    entry
}

private func contractHttpSshStartupProfileExpectedLabel(profile: ContractHttpSshStartupProfile): String {
    match (profile) {
        case ContractHttpSshStartupProfile.LibraryDefault =>
            "library-default"
        case ContractHttpSshStartupProfile.HttpClientLibrary =>
            "http-client-library"
        case ContractHttpSshStartupProfile.HttpServerLibrary =>
            "http-server-library"
        case ContractHttpSshStartupProfile.SshClientLibrary =>
            "ssh-client-library"
        case ContractHttpSshStartupProfile.SshServerLibrary =>
            "ssh-server-library"
        case ContractHttpSshStartupProfile.ProductionAccelerated =>
            "production-accelerated"
    }
}

private func contractRuntimeDefaultAesEngineKind(defaultAesEngineKind: Int64): ContractAesEngineKind {
    match (defaultAesEngineKind) {
        case 0 => ContractAesEngineKind.Auto
        case 1 => ContractAesEngineKind.Software
        case 2 => ContractAesEngineKind.Hardware
        case _ =>
            throw ContractException(ContractErrorCode.BadInput, "runtime startup profile default AES engine kind is unsupported")
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

public func contractPrepareHttpServerLibraryStartupRequest(
    request: ContractHttpServerLibraryStartupRequest
): ContractHttpServerLibraryStartupBundle {
    let template = contractDescribeHttpSshStartupProfile(request.profile)
    contractRequireHttpTlsStartupProfile(template, "HTTP server startup")
    let readiness = contractRequireHttpSshStartupProfile(
        request.profile,
        requestedAesEngine: request.requestedAesEngine,
        aesBackendHint: request.aesBackendHint
    )
    let material = contractPrepareHttpServerTlsMaterialRequest(request.tls)
    ContractHttpServerLibraryStartupBundle(template, readiness, material)
}

public func contractPlanHttpServerAttachRequest(
    request: ContractHttpServerLibraryStartupRequest
): ContractHttpServerAttachPlan {
    let startup = contractPrepareHttpServerLibraryStartupRequest(request)
    ContractHttpServerAttachPlan(
        startup,
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.HttpServerAttachPlanning),
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.HttpServerStableAttach)
    )
}

public func contractTryPrepareHttpServerLibraryStartupRequest(
    request: ContractHttpServerLibraryStartupRequest
): ContractHttpServerLibraryStartupOutcome {
    try {
        let result = contractPrepareHttpServerLibraryStartupRequest(request)
        ContractHttpServerLibraryStartupOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpServerLibraryStartupOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareHttpClientLibraryStartupRequest(
    request: ContractHttpClientLibraryStartupRequest
): ContractHttpClientLibraryStartupBundle {
    let template = contractDescribeHttpSshStartupProfile(request.profile)
    contractRequireHttpTlsStartupProfile(template, "HTTP client startup")
    let readiness = contractRequireHttpSshStartupProfile(
        request.profile,
        requestedAesEngine: request.requestedAesEngine,
        aesBackendHint: request.aesBackendHint
    )
    let trust = contractPrepareHttpClientTlsTrustMaterialRequest(request.trust)
    ContractHttpClientLibraryStartupBundle(template, readiness, trust)
}

public func contractTryPrepareHttpClientLibraryStartupRequest(
    request: ContractHttpClientLibraryStartupRequest
): ContractHttpClientLibraryStartupOutcome {
    try {
        let result = contractPrepareHttpClientLibraryStartupRequest(request)
        ContractHttpClientLibraryStartupOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpClientLibraryStartupOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareSshServerLibraryStartupX25519RsaPkcs8Request(
    request: ContractSshServerLibraryStartupX25519RsaPkcs8Request
): ContractSshServerLibraryStartupBundle {
    try {
        let template = contractDescribeHttpSshStartupProfile(request.profile)
        contractRequireSshStartupProfile(template, "SSH server startup")
        let readiness = contractRequireHttpSshStartupProfile(
            request.profile,
            requestedAesEngine: request.requestedAesEngine,
            aesBackendHint: request.aesBackendHint
        )
        let hostPrivateKey = x509ParseRsaPrivateKeyPkcs8Pem(request.hostPrivateKeyPkcs8Pem)
        let handshake = contractSshCompleteServerInitialHandshakeX25519Rsa(
            contractToSshKexExchangeTranscript(request.transcript),
            request.serverPrivateKey,
            request.encodedClientInit,
            hostPrivateKey,
            contractToSshNegotiatedAlgorithms(request.negotiated),
            request.encodedClientNewKeys,
            request.encodedServerNewKeys,
            signatureAlgorithm: request.signatureAlgorithm,
            serverPublicKey: request.serverPublicKey
        )
        let runtime = contractSshCreateServerRuntimeRequest(ContractSshServerRuntimeRequest(handshake))
        ContractSshServerLibraryStartupBundle(template, readiness, handshake, runtime)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH server startup (RSA) failed: ${e.message}"
        )
    }
}

public func contractTryPrepareSshServerLibraryStartupX25519RsaPkcs8Request(
    request: ContractSshServerLibraryStartupX25519RsaPkcs8Request
): ContractSshServerLibraryStartupOutcome {
    try {
        let result = contractPrepareSshServerLibraryStartupX25519RsaPkcs8Request(request)
        ContractSshServerLibraryStartupOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerLibraryStartupOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareSshServerLibraryStartupX25519EcdsaPkcs8Request(
    request: ContractSshServerLibraryStartupX25519EcdsaPkcs8Request
): ContractSshServerLibraryStartupBundle {
    try {
        let template = contractDescribeHttpSshStartupProfile(request.profile)
        contractRequireSshStartupProfile(template, "SSH server startup")
        let readiness = contractRequireHttpSshStartupProfile(
            request.profile,
            requestedAesEngine: request.requestedAesEngine,
            aesBackendHint: request.aesBackendHint
        )
        let hostPrivateKey = x509ParseEcPrivateKeyPkcs8Pem(request.hostPrivateKeyPkcs8Pem)
        let handshake = contractSshCompleteServerInitialHandshakeX25519Ecdsa(
            contractToSshKexExchangeTranscript(request.transcript),
            request.serverPrivateKey,
            request.encodedClientInit,
            hostPrivateKey,
            contractToSshNegotiatedAlgorithms(request.negotiated),
            request.encodedClientNewKeys,
            request.encodedServerNewKeys,
            serverPublicKey: request.serverPublicKey
        )
        let runtime = contractSshCreateServerRuntimeRequest(ContractSshServerRuntimeRequest(handshake))
        ContractSshServerLibraryStartupBundle(template, readiness, handshake, runtime)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH server startup (ECDSA) failed: ${e.message}"
        )
    }
}

public func contractTryPrepareSshServerLibraryStartupX25519EcdsaPkcs8Request(
    request: ContractSshServerLibraryStartupX25519EcdsaPkcs8Request
): ContractSshServerLibraryStartupOutcome {
    try {
        let result = contractPrepareSshServerLibraryStartupX25519EcdsaPkcs8Request(request)
        ContractSshServerLibraryStartupOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerLibraryStartupOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareSshServerLibraryStartupX25519Ed25519SeedRequest(
    request: ContractSshServerLibraryStartupX25519Ed25519SeedRequest
): ContractSshServerLibraryStartupBundle {
    try {
        let template = contractDescribeHttpSshStartupProfile(request.profile)
        contractRequireSshStartupProfile(template, "SSH server startup")
        let readiness = contractRequireHttpSshStartupProfile(
            request.profile,
            requestedAesEngine: request.requestedAesEngine,
            aesBackendHint: request.aesBackendHint
        )
        let handshake = contractSshCompleteServerInitialHandshakeX25519Ed25519(
            contractToSshKexExchangeTranscript(request.transcript),
            request.serverPrivateKey,
            request.encodedClientInit,
            request.hostPrivateKeySeed,
            contractToSshNegotiatedAlgorithms(request.negotiated),
            request.encodedClientNewKeys,
            request.encodedServerNewKeys,
            serverPublicKey: request.serverPublicKey
        )
        let runtime = contractSshCreateServerRuntimeRequest(ContractSshServerRuntimeRequest(handshake))
        ContractSshServerLibraryStartupBundle(template, readiness, handshake, runtime)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH server startup (Ed25519) failed: ${e.message}"
        )
    }
}

public func contractTryPrepareSshServerLibraryStartupX25519Ed25519SeedRequest(
    request: ContractSshServerLibraryStartupX25519Ed25519SeedRequest
): ContractSshServerLibraryStartupOutcome {
    try {
        let result = contractPrepareSshServerLibraryStartupX25519Ed25519SeedRequest(request)
        ContractSshServerLibraryStartupOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerLibraryStartupOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareSshClientLibraryStartupX25519Request(
    request: ContractSshClientLibraryStartupX25519Request
): ContractSshClientLibraryStartupBundle {
    try {
        let template = contractDescribeHttpSshStartupProfile(request.profile)
        contractRequireSshStartupProfile(template, "SSH client startup")
        let readiness = contractRequireHttpSshStartupProfile(
            request.profile,
            requestedAesEngine: request.requestedAesEngine,
            aesBackendHint: request.aesBackendHint
        )
        let handshake = contractSshCompleteClientInitialHandshakeX25519Request(request.handshake)
        let runtime = contractSshCreateClientRuntimeRequest(ContractSshClientRuntimeRequest(handshake))
        ContractSshClientLibraryStartupBundle(template, readiness, handshake, runtime)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH client startup failed: ${e.message}"
        )
    }
}

public func contractTryPrepareSshClientLibraryStartupX25519Request(
    request: ContractSshClientLibraryStartupX25519Request
): ContractSshClientLibraryStartupOutcome {
    try {
        let result = contractPrepareSshClientLibraryStartupX25519Request(request)
        ContractSshClientLibraryStartupOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshClientLibraryStartupOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public class ContractAeadEnvelopeV1 {
    public let ver: Int64
    public let alg: String
    public let kid: String
    public let nonce: String
    public let aad: String
    public let ciphertext: String
    public let tag: String

    public init(
        ver: Int64,
        alg: String,
        kid: String,
        nonce: String,
        aad: String,
        ciphertext: String,
        tag: String
    ) {
        if (ver != 1) {
            throw ContractException(ContractErrorCode.BadInput, "envelope version must be 1")
        }

        let normalizedAlg = contractNormalizeAlgorithmToken(alg)
        let normalizedKid = kid.trimAscii()
        requireTokenAscii(normalizedKid, "kid")
        requireTokenAscii(nonce, "nonce")
        requireTokenAscii(aad, "aad", allowEmpty: true)
        requireTokenAscii(ciphertext, "ciphertext")
        requireTokenAscii(tag, "tag")

        if (nonce.size == 0 || ciphertext.size == 0 || tag.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "envelope fields must not be empty")
        }

        this.ver = ver
        this.alg = normalizedAlg
        this.kid = normalizedKid
        this.nonce = nonce
        this.aad = aad
        this.ciphertext = ciphertext
        this.tag = tag
    }

    public func algorithm(): ContractAeadAlgorithm {
        contractParseAlgorithmToken(alg)
    }

    public func toJsonString(): String {
        "{\"ver\":1,\"alg\":\"${alg}\",\"kid\":\"${kid}\",\"nonce\":\"${nonce}\",\"aad\":\"${aad}\",\"ciphertext\":\"${ciphertext}\",\"tag\":\"${tag}\"}"
    }

    public static func parseJson(text: String): ContractAeadEnvelopeV1 {
        let compact = removeAsciiSpaces(text)
        if (compact.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "envelope json must not be empty")
        }

        let ver = extractIntField(compact, "ver")
        let alg = extractStringField(compact, "alg")
        let kid = extractStringField(compact, "kid")
        let nonce = extractStringField(compact, "nonce")
        let aad = extractStringField(compact, "aad")
        let ciphertext = extractStringField(compact, "ciphertext")
        let tag = extractStringField(compact, "tag")
        ContractAeadEnvelopeV1(ver, alg, kid, nonce, aad, ciphertext, tag)
    }
}

public func contractParseEnvelopeJsonCompatV1(envelopeJson: String): ContractAeadEnvelopeV1 {
    let compact = removeAsciiSpaces(envelopeJson)
    if (compact.size == 0) {
        throw ContractException(ContractErrorCode.BadInput, "envelope json must not be empty")
    }

    if (indexOfString(compact, "\"ver\":") >= 0) {
        return ContractAeadEnvelopeV1.parseJson(compact)
    }

    let ver = extractIntField(compact, "v")
    let alg = extractStringField(compact, "alg")
    let kid = extractStringField(compact, "kid")
    let nonce = extractStringField(compact, "nonce")
    let aad = extractOptionalStringField(compact, "aad", "")
    let ciphertext = extractStringField(compact, "ct")
    let tag = extractStringField(compact, "tag")
    ContractAeadEnvelopeV1(ver, alg, kid, nonce, aad, ciphertext, tag)
}

public func contractEnvelopeToLegacyJsonV1(envelope: ContractAeadEnvelopeV1): String {
    "{\"v\":1,\"alg\":\"${envelope.alg}\",\"kid\":\"${envelope.kid}\",\"nonce\":\"${envelope.nonce}\",\"aad\":\"${envelope.aad}\",\"ct\":\"${envelope.ciphertext}\",\"tag\":\"${envelope.tag}\"}"
}

public class ContractX509PinPolicy {
    public let allowedLeafDerSha256: Array<Array<Byte>>
    public let allowedLeafSpkiSha256: Array<Array<Byte>>

    public init(
        allowedLeafDerSha256!: Array<Array<Byte>> = [],
        allowedLeafSpkiSha256!: Array<Array<Byte>> = []
    ) {
        this.allowedLeafDerSha256 = clonePinList(allowedLeafDerSha256, "leaf DER")
        this.allowedLeafSpkiSha256 = clonePinList(allowedLeafSpkiSha256, "leaf SPKI")
    }
}

public class ContractX509VerifyResult {
    public let chainLength: Int64
    public let leafSubjectCommonName: String
    public let leafIssuerCommonName: String
    public let trustAnchorCommonName: String
    public let leafDerSha256: Array<Byte>
    public let leafSpkiSha256: Array<Byte>

    public init(
        chainLength: Int64,
        leafSubjectCommonName: String,
        leafIssuerCommonName: String,
        trustAnchorCommonName: String,
        leafDerSha256: Array<Byte>,
        leafSpkiSha256: Array<Byte>
    ) {
        if (chainLength <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "verified certificate chain length must be > 0")
        }
        requireSha256Pin(leafDerSha256, "leafDerSha256")
        requireSha256Pin(leafSpkiSha256, "leafSpkiSha256")
        this.chainLength = chainLength
        this.leafSubjectCommonName = leafSubjectCommonName
        this.leafIssuerCommonName = leafIssuerCommonName
        this.trustAnchorCommonName = trustAnchorCommonName
        this.leafDerSha256 = leafDerSha256.clone()
        this.leafSpkiSha256 = leafSpkiSha256.clone()
    }
}

public class ContractX509VerifyOutcome {
    public let ok: Bool
    public let code: ContractErrorCode
    public let message: String
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractX509VerifyResult

    public init(
        ok: Bool,
        code: ContractErrorCode,
        message: String,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractX509VerifyResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "x509 verify outcome message must not be empty")
        }
        if (ok) {
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "x509 verify outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_value) =>
                    ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "x509 verify outcome result must exist when ok is true"
                    )
            }
        } else {
            match (igniteCode) {
                case Some(_value) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "x509 verify outcome ignite code must exist when ok is false"
                    )
            }
        }
        this.ok = ok
        this.code = code
        this.message = message.trimAscii()
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractEnvelopeOpenOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let plaintext: ?Array<Byte>

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        plaintext!: ?Array<Byte> = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "envelope outcome message must not be empty")
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "envelope outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "envelope outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (plaintext) {
                case Some(_value) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "envelope outcome plaintext must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_value) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "envelope outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_value) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "envelope outcome ignite code must exist when ok is false"
                    )
            }
            match (plaintext) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "envelope outcome plaintext must be empty when ok is false"
                    )
                case None => ()
            }
        }
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.plaintext = contractCloneOptionalBytes(plaintext)
    }
}

public class ContractHttpServerTlsConfigValidationResult {
    public let certificateChainLength: Int64
    public let leafSubjectCommonName: String
    public let leafIssuerCommonName: String
    public let keyAlgorithm: String
    public let normalizedAlpnProtocols: Array<String>

    public init(
        certificateChainLength: Int64,
        leafSubjectCommonName: String,
        leafIssuerCommonName: String,
        keyAlgorithm: String,
        normalizedAlpnProtocols: Array<String>
    ) {
        if (certificateChainLength <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "certificate chain must contain at least one certificate")
        }
        let normalizedKeyAlgorithm = keyAlgorithm.trimAscii().toAsciiUpper()
        if (normalizedKeyAlgorithm != "RSA" && normalizedKeyAlgorithm != "EC") {
            throw ContractException(ContractErrorCode.BadInput, "TLS server key algorithm must be RSA or EC")
        }
        if (normalizedAlpnProtocols.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS ALPN protocol list must not be empty")
        }
        this.certificateChainLength = certificateChainLength
        this.leafSubjectCommonName = leafSubjectCommonName
        this.leafIssuerCommonName = leafIssuerCommonName
        this.keyAlgorithm = normalizedKeyAlgorithm
        this.normalizedAlpnProtocols = normalizedAlpnProtocols.clone()
    }
}

public class ContractHttpServerTlsConfigValidationOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractHttpServerTlsConfigValidationResult

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractHttpServerTlsConfigValidationResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS config validation outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "TLS config validation outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractHttpServerTlsMaterial {
    public let validation: ContractHttpServerTlsConfigValidationResult
    public let certificateChainPemBlocks: Array<String>
    public let privateKeyPem: String

    public init(
        validation: ContractHttpServerTlsConfigValidationResult,
        certificateChainPemBlocks: Array<String>,
        privateKeyPem: String
    ) {
        if (certificateChainPemBlocks.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS server certificate PEM blocks must not be empty")
        }
        if (Int64(certificateChainPemBlocks.size) != validation.certificateChainLength) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS server certificate PEM block count must match validation result"
            )
        }
        let normalizedPrivateKeyPem = privateKeyPem.trimAscii()
        if (normalizedPrivateKeyPem.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS server private key PEM must not be empty")
        }
        this.validation = validation
        this.certificateChainPemBlocks = contractCloneTrimmedPemBlocks(
            certificateChainPemBlocks,
            "TLS server certificate PEM"
        )
        this.privateKeyPem = normalizedPrivateKeyPem
    }

    public func leafCertificatePem(): String {
        certificateChainPemBlocks[0]
    }

    public func certificateChainPemBundle(): String {
        contractJoinPemBlocks(certificateChainPemBlocks)
    }
}

public class ContractHttpServerTlsMaterialOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractHttpServerTlsMaterial

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractHttpServerTlsMaterial = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS server material outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "TLS server material outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractHttpClientTlsConfigValidationResult {
    public let trustAnchorCount: Int64
    public let intermediateCount: Int64
    public let normalizedHostname: String
    public let hasValidationTimeOverride: Bool
    public let allowedLeafDerPinCount: Int64
    public let allowedLeafSpkiPinCount: Int64
    public let negotiationPolicy: ContractTlsHttpNegotiationPolicyValidationResult

    public init(
        trustAnchorCount: Int64,
        intermediateCount: Int64,
        normalizedHostname: String,
        hasValidationTimeOverride: Bool,
        allowedLeafDerPinCount: Int64,
        allowedLeafSpkiPinCount: Int64,
        negotiationPolicy: ContractTlsHttpNegotiationPolicyValidationResult
    ) {
        if (trustAnchorCount <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS client trust anchors must not be empty")
        }
        if (intermediateCount < 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS client intermediate count must not be negative")
        }
        if (allowedLeafDerPinCount < 0 || allowedLeafSpkiPinCount < 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS client pin counts must not be negative")
        }
        if (negotiationPolicy.requireServerName && normalizedHostname.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS client hostname must not be empty when negotiation policy requires server name"
            )
        }
        this.trustAnchorCount = trustAnchorCount
        this.intermediateCount = intermediateCount
        this.normalizedHostname = normalizedHostname.trimAscii().toAsciiLower()
        this.hasValidationTimeOverride = hasValidationTimeOverride
        this.allowedLeafDerPinCount = allowedLeafDerPinCount
        this.allowedLeafSpkiPinCount = allowedLeafSpkiPinCount
        this.negotiationPolicy = negotiationPolicy
    }
}

public class ContractHttpClientTlsTrustMaterial {
    public let validation: ContractHttpClientTlsConfigValidationResult
    public let trustAnchorPemBlocks: Array<String>
    public let intermediatePemBlocks: Array<String>
    public let validationTime: String
    public let pinPolicy: ContractX509PinPolicy

    public init(
        validation: ContractHttpClientTlsConfigValidationResult,
        trustAnchorPemBlocks: Array<String>,
        intermediatePemBlocks!: Array<String> = [],
        validationTime!: String = "",
        pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy()
    ) {
        if (trustAnchorPemBlocks.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS client trust anchor PEM blocks must not be empty")
        }
        if (Int64(trustAnchorPemBlocks.size) != validation.trustAnchorCount) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS client trust anchor PEM block count must match validation result"
            )
        }
        if (Int64(intermediatePemBlocks.size) != validation.intermediateCount) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS client intermediate PEM block count must match validation result"
            )
        }
        this.validation = validation
        this.trustAnchorPemBlocks = contractCloneTrimmedPemBlocks(
            trustAnchorPemBlocks,
            "TLS client trust anchor PEM"
        )
        this.intermediatePemBlocks = contractCloneTrimmedPemBlocks(
            intermediatePemBlocks,
            "TLS client intermediate PEM"
        )
        this.validationTime = validationTime.trimAscii()
        this.pinPolicy = ContractX509PinPolicy(
            allowedLeafDerSha256: pinPolicy.allowedLeafDerSha256,
            allowedLeafSpkiSha256: pinPolicy.allowedLeafSpkiSha256
        )
    }

    public func trustAnchorsPemBundle(): String {
        contractJoinPemBlocks(trustAnchorPemBlocks)
    }

    public func intermediatesPemBundle(): String {
        contractJoinPemBlocks(intermediatePemBlocks)
    }
}

public class ContractHttpClientTlsTrustMaterialOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractHttpClientTlsTrustMaterial

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractHttpClientTlsTrustMaterial = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS client material outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "TLS client material outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractHttpClientTlsConfigValidationOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractHttpClientTlsConfigValidationResult

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractHttpClientTlsConfigValidationResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS client config validation outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "TLS client config validation outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractHttpServerLibraryStartupBundle {
    public let template: ContractHttpSshStartupProfileTemplate
    public let readiness: ContractHttpSshStartupReadinessReport
    public let material: ContractHttpServerTlsMaterial

    public init(
        template: ContractHttpSshStartupProfileTemplate,
        readiness: ContractHttpSshStartupReadinessReport,
        material: ContractHttpServerTlsMaterial
    ) {
        this.template = template
        this.readiness = readiness
        this.material = material
    }
}

public class ContractHttpServerAttachPlan {
    public let startup: ContractHttpServerLibraryStartupBundle
    public let planningGate: ContractProviderConsumptionGateReport
    public let stableAttachGate: ContractProviderConsumptionGateReport
    public let attachSurface: String
    public let listenerOwned: Bool
    public let expectedTlsVersion: ContractTlsVersion
    public let expectedAlpnProtocols: Array<String>

    public init(
        startup: ContractHttpServerLibraryStartupBundle,
        planningGate: ContractProviderConsumptionGateReport,
        stableAttachGate: ContractProviderConsumptionGateReport,
        attachSurface!: String = "accepted-socket",
        listenerOwned!: Bool = false,
        expectedTlsVersion!: ContractTlsVersion = ContractTlsVersion.Tls13
    ) {
        let normalizedSurface = attachSurface.trimAscii()
        if (normalizedSurface.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "HTTP server attach surface must not be empty")
        }
        if (!planningGate.readyNow) {
            throw ContractException(ContractErrorCode.Unsupported, "HTTP server attach planning gate is not ready")
        }
        if (planningGate.path != ContractProviderConsumptionPath.HttpServerAttachPlanning) {
            throw ContractException(ContractErrorCode.BadInput, "HTTP server attach plan requires the planning gate")
        }
        if (stableAttachGate.path != ContractProviderConsumptionPath.HttpServerStableAttach) {
            throw ContractException(ContractErrorCode.BadInput, "HTTP server attach plan requires the stable attach gate")
        }
        this.startup = startup
        this.planningGate = planningGate
        this.stableAttachGate = stableAttachGate
        this.attachSurface = normalizedSurface
        this.listenerOwned = listenerOwned
        this.expectedTlsVersion = expectedTlsVersion
        this.expectedAlpnProtocols = startup.material.validation.normalizedAlpnProtocols.clone()
    }
}

public class ContractHttpServerAttachResult {
    public let serverFlight: ContractTls13HttpServerFlight
    public let tlsVersion: ContractTlsVersion
    public let cipherSuite: String
    public let negotiatedAlpn: String
    public let requestedServerName: String
    public let acknowledgedServerName: Bool
    public let secureSessionReady: Bool
    public let attachSurface: String

    public init(
        serverFlight: ContractTls13HttpServerFlight,
        tlsVersion!: ContractTlsVersion = ContractTlsVersion.Tls13,
        cipherSuite!: String = "UNKNOWN",
        negotiatedAlpn!: String = "",
        requestedServerName!: String = "",
        acknowledgedServerName!: Bool = false,
        secureSessionReady!: Bool = false,
        attachSurface!: String = "accepted-socket"
    ) {
        let normalizedSurface = attachSurface.trimAscii()
        if (normalizedSurface.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "HTTP server attach result surface must not be empty")
        }
        this.serverFlight = serverFlight
        this.tlsVersion = tlsVersion
        this.cipherSuite = cipherSuite.trimAscii()
        this.negotiatedAlpn = negotiatedAlpn.trimAscii()
        this.requestedServerName = requestedServerName.trimAscii().toAsciiLower()
        this.acknowledgedServerName = acknowledgedServerName
        this.secureSessionReady = secureSessionReady
        this.attachSurface = normalizedSurface
    }
}

public class ContractHttpServerInitialHandshakeFacade {
    public let serverFlight: ContractTls13HttpServerFlight
    public let records: Array<Array<Byte>>
    public let recordCount: Int64
    public let wireBytes: Int64
    public let facadeSurface: String

    public init(
        serverFlight: ContractTls13HttpServerFlight,
        records: Array<Array<Byte>>,
        facadeSurface!: String = "http-server-initial-handshake-facade"
    ) {
        let normalizedSurface = facadeSurface.trimAscii()
        if (normalizedSurface.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "HTTP server initial handshake facade surface must not be empty")
        }
        if (records.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "HTTP server initial handshake records must not be empty")
        }
        this.serverFlight = serverFlight
        this.records = contractCloneRecordWire(records, "HTTP server initial handshake record")
        this.recordCount = Int64(this.records.size)
        this.wireBytes = contractCountRecordWireBytes(this.records)
        this.facadeSurface = normalizedSurface
    }
}

public enum ContractAcceptedTransportSessionStatus <: Equatable<ContractAcceptedTransportSessionStatus> & ToString {
    | Ready
    | Blocked
    | Failed
    | Closed

    public operator func ==(right: ContractAcceptedTransportSessionStatus): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractAcceptedTransportSessionStatus): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Ready => 0
            case Blocked => 1
            case Failed => 2
            case Closed => 3
        }
    }

    public func toString(): String {
        match (this) {
            case Ready => "READY"
            case Blocked => "BLOCKED"
            case Failed => "FAILED"
            case Closed => "CLOSED"
        }
    }
}

public class ContractAcceptedTransportDescriptor {
    public let transportId: String
    public let transportKind: String
    public let localEndpoint: String
    public let remoteEndpoint: String

    public init(
        transportId: String,
        transportKind!: String = "accepted-transport",
        localEndpoint!: String = "",
        remoteEndpoint!: String = ""
    ) {
        let normalizedId = transportId.trimAscii()
        let normalizedKind = transportKind.trimAscii()
        if (normalizedId.size == 0 || normalizedKind.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "accepted transport descriptor id/kind must not be empty"
            )
        }
        this.transportId = normalizedId
        this.transportKind = normalizedKind
        this.localEndpoint = localEndpoint.trimAscii()
        this.remoteEndpoint = remoteEndpoint.trimAscii()
    }
}

public class ContractHttpServerAcceptedTransportSession {
    public let transport: ContractAcceptedTransportDescriptor
    public let status: ContractAcceptedTransportSessionStatus
    public let result: ContractHttpServerAttachResult
    public let initialHandshake: ContractHttpServerInitialHandshakeFacade
    public let keyMaterial: ContractTls13ApplicationKeyMaterial
    public let recordChannel: ContractTlsRecordChannel
    public let closeReason: String

    public init(
        transport: ContractAcceptedTransportDescriptor,
        status: ContractAcceptedTransportSessionStatus,
        result: ContractHttpServerAttachResult,
        initialHandshake: ContractHttpServerInitialHandshakeFacade,
        keyMaterial: ContractTls13ApplicationKeyMaterial,
        recordChannel: ContractTlsRecordChannel,
        closeReason!: String = ""
    ) {
        if (status == ContractAcceptedTransportSessionStatus.Ready && !result.secureSessionReady) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "ready accepted transport session requires secureSessionReady=true"
            )
        }
        if (recordChannel.version != ContractTlsVersion.Tls13) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "accepted transport first cut supports TLS1.3 record channels only"
            )
        }
        this.transport = transport
        this.status = status
        this.result = result
        this.initialHandshake = initialHandshake
        this.keyMaterial = keyMaterial
        this.recordChannel = recordChannel
        this.closeReason = closeReason.trimAscii()
    }

    public prop secureSessionReady: Bool {
        get() {
            status == ContractAcceptedTransportSessionStatus.Ready && result.secureSessionReady
        }
    }
}

public class ContractHttpServerAcceptedTransportTls13X25519Request {
    public let transport: ContractAcceptedTransportDescriptor
    public let plan: ContractHttpServerAttachPlan
    public let encodedClientHello: Array<Byte>
    public let serverKeyExchangePrivate: Array<Byte>
    public let policy: ContractTlsHttpNegotiationPolicy

    public init(
        transport: ContractAcceptedTransportDescriptor,
        plan: ContractHttpServerAttachPlan,
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ) {
        if (encodedClientHello.size == 0 || serverKeyExchangePrivate.size != 32) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "accepted transport TLS1.3 X25519 request fields are invalid"
            )
        }
        this.transport = transport
        this.plan = plan
        this.encodedClientHello = encodedClientHello.clone()
        this.serverKeyExchangePrivate = serverKeyExchangePrivate.clone()
        this.policy = ContractTlsHttpNegotiationPolicy(
            requireServerName: policy.requireServerName,
            allowedServerNames: policy.allowedServerNames,
            alpnPreference: policy.alpnPreference
        )
    }
}

public class ContractHttpServerLibraryStartupOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractHttpServerLibraryStartupBundle

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractHttpServerLibraryStartupBundle = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "HTTP server startup outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "HTTP server startup outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractHttpClientLibraryStartupBundle {
    public let template: ContractHttpSshStartupProfileTemplate
    public let readiness: ContractHttpSshStartupReadinessReport
    public let trust: ContractHttpClientTlsTrustMaterial

    public init(
        template: ContractHttpSshStartupProfileTemplate,
        readiness: ContractHttpSshStartupReadinessReport,
        trust: ContractHttpClientTlsTrustMaterial
    ) {
        this.template = template
        this.readiness = readiness
        this.trust = trust
    }
}

public class ContractHttpClientLibraryStartupOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractHttpClientLibraryStartupBundle

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractHttpClientLibraryStartupBundle = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "HTTP client startup outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "HTTP client startup outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractHttpServerTlsConfigRequest {
    public let certificateChainPem: String
    public let privateKeyPem: String
    public let alpnProtocols: Array<String>
    public let requireHttp2Alpn: Bool

    public init(
        certificateChainPem: String,
        privateKeyPem: String,
        alpnProtocols!: Array<String> = ["h2", "http/1.1"],
        requireHttp2Alpn!: Bool = true
    ) {
        if (certificateChainPem.trimAscii().size == 0 || privateKeyPem.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "HTTP server TLS config request fields are invalid"
            )
        }
        this.certificateChainPem = certificateChainPem
        this.privateKeyPem = privateKeyPem
        this.alpnProtocols = alpnProtocols.clone()
        this.requireHttp2Alpn = requireHttp2Alpn
    }
}

public class ContractHttpClientTlsTrustRequest {
    public let trustAnchorsPemBundle: String
    public let intermediatesPemBundle: String
    public let hostname: String
    public let validationTime: String
    public let pinPolicy: ContractX509PinPolicy
    public let policy: ContractTlsHttpNegotiationPolicy

    public init(
        trustAnchorsPemBundle: String,
        intermediatesPemBundle!: String = "",
        hostname!: String = "",
        validationTime!: String = "",
        pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ) {
        if (trustAnchorsPemBundle.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "HTTP client TLS trust request trust anchors must not be empty"
            )
        }
        this.trustAnchorsPemBundle = trustAnchorsPemBundle
        this.intermediatesPemBundle = intermediatesPemBundle
        this.hostname = hostname
        this.validationTime = validationTime
        this.pinPolicy = ContractX509PinPolicy(
            allowedLeafDerSha256: pinPolicy.allowedLeafDerSha256,
            allowedLeafSpkiSha256: pinPolicy.allowedLeafSpkiSha256
        )
        this.policy = ContractTlsHttpNegotiationPolicy(
            requireServerName: policy.requireServerName,
            allowedServerNames: policy.allowedServerNames,
            alpnPreference: policy.alpnPreference
        )
    }
}

public class ContractHttpClientTlsPeerPemRequest {
    public let leafPem: String
    public let trust: ContractHttpClientTlsTrustRequest

    public init(
        leafPem: String,
        trust: ContractHttpClientTlsTrustRequest
    ) {
        if (leafPem.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "HTTP client TLS peer PEM request leaf certificate must not be empty"
            )
        }
        this.leafPem = leafPem
        this.trust = trust
    }
}

public class ContractHttpClientTlsPeerChainRequest {
    public let certificateChainPemBundle: String
    public let trust: ContractHttpClientTlsTrustRequest

    public init(
        certificateChainPemBundle: String,
        trust: ContractHttpClientTlsTrustRequest
    ) {
        if (certificateChainPemBundle.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "HTTP client TLS peer chain request certificate chain must not be empty"
            )
        }
        this.certificateChainPemBundle = certificateChainPemBundle
        this.trust = trust
    }
}

public class ContractHttpServerLibraryStartupRequest {
    public let tls: ContractHttpServerTlsConfigRequest
    public let profile: ContractHttpSshStartupProfile
    public let requestedAesEngine: ContractAesEngineKind
    public let aesBackendHint: String

    public init(
        tls: ContractHttpServerTlsConfigRequest,
        profile!: ContractHttpSshStartupProfile = ContractHttpSshStartupProfile.HttpServerLibrary,
        requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
        aesBackendHint!: String = ""
    ) {
        this.tls = tls
        this.profile = profile
        this.requestedAesEngine = requestedAesEngine
        this.aesBackendHint = aesBackendHint.trimAscii()
    }
}

public class ContractHttpClientLibraryStartupRequest {
    public let trust: ContractHttpClientTlsTrustRequest
    public let profile: ContractHttpSshStartupProfile
    public let requestedAesEngine: ContractAesEngineKind
    public let aesBackendHint: String

    public init(
        trust: ContractHttpClientTlsTrustRequest,
        profile!: ContractHttpSshStartupProfile = ContractHttpSshStartupProfile.HttpClientLibrary,
        requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
        aesBackendHint!: String = ""
    ) {
        this.trust = trust
        this.profile = profile
        this.requestedAesEngine = requestedAesEngine
        this.aesBackendHint = aesBackendHint.trimAscii()
    }
}

public class ContractTlsHttpNegotiationPolicyValidationResult {
    public let requireServerName: Bool
    public let normalizedAllowedServerNames: Array<String>
    public let normalizedAlpnPreference: Array<String>

    public init(
        requireServerName: Bool,
        normalizedAllowedServerNames: Array<String>,
        normalizedAlpnPreference: Array<String>
    ) {
        if (normalizedAlpnPreference.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS HTTP negotiation ALPN preference must not be empty")
        }
        this.requireServerName = requireServerName
        this.normalizedAllowedServerNames = normalizedAllowedServerNames.clone()
        this.normalizedAlpnPreference = normalizedAlpnPreference.clone()
    }
}

public class ContractTlsHttpNegotiationPolicyValidationOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractTlsHttpNegotiationPolicyValidationResult

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractTlsHttpNegotiationPolicyValidationResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS HTTP negotiation policy validation outcome message must not be empty"
            )
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "TLS HTTP negotiation policy validation outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractSshNegotiatedAlgorithms {
    public let kexAlgorithm: String
    public let serverHostKeyAlgorithm: String
    public let encryptionAlgorithmClientToServer: String
    public let encryptionAlgorithmServerToClient: String
    public let macAlgorithmClientToServer: String
    public let macAlgorithmServerToClient: String
    public let compressionAlgorithmClientToServer: String
    public let compressionAlgorithmServerToClient: String

    public init(
        kexAlgorithm: String,
        serverHostKeyAlgorithm: String,
        encryptionAlgorithmClientToServer: String,
        encryptionAlgorithmServerToClient: String,
        macAlgorithmClientToServer: String,
        macAlgorithmServerToClient: String,
        compressionAlgorithmClientToServer!: String = "none",
        compressionAlgorithmServerToClient!: String = "none"
    ) {
        if (
            kexAlgorithm.trimAscii().size == 0 ||
            serverHostKeyAlgorithm.trimAscii().size == 0 ||
            encryptionAlgorithmClientToServer.trimAscii().size == 0 ||
            encryptionAlgorithmServerToClient.trimAscii().size == 0 ||
            macAlgorithmClientToServer.trimAscii().size == 0 ||
            macAlgorithmServerToClient.trimAscii().size == 0 ||
            compressionAlgorithmClientToServer.trimAscii().size == 0 ||
            compressionAlgorithmServerToClient.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH negotiated algorithms must not contain empty fields"
            )
        }
        this.kexAlgorithm = kexAlgorithm.trimAscii()
        this.serverHostKeyAlgorithm = serverHostKeyAlgorithm.trimAscii()
        this.encryptionAlgorithmClientToServer = encryptionAlgorithmClientToServer.trimAscii()
        this.encryptionAlgorithmServerToClient = encryptionAlgorithmServerToClient.trimAscii()
        this.macAlgorithmClientToServer = macAlgorithmClientToServer.trimAscii()
        this.macAlgorithmServerToClient = macAlgorithmServerToClient.trimAscii()
        this.compressionAlgorithmClientToServer = compressionAlgorithmClientToServer.trimAscii()
        this.compressionAlgorithmServerToClient = compressionAlgorithmServerToClient.trimAscii()
    }
}

public class ContractSshKexExchangeTranscript {
    public let clientBannerLine: Array<Byte>
    public let serverBannerLine: Array<Byte>
    public let clientKexInitPayload: Array<Byte>
    public let serverKexInitPayload: Array<Byte>

    public init(
        clientBannerLine: Array<Byte>,
        serverBannerLine: Array<Byte>,
        clientKexInitPayload: Array<Byte>,
        serverKexInitPayload: Array<Byte>
    ) {
        _ = contractToSshKexExchangeTranscript(
            clientBannerLine,
            serverBannerLine,
            clientKexInitPayload,
            serverKexInitPayload
        )
        this.clientBannerLine = clientBannerLine.clone()
        this.serverBannerLine = serverBannerLine.clone()
        this.clientKexInitPayload = clientKexInitPayload.clone()
        this.serverKexInitPayload = serverKexInitPayload.clone()
    }
}

public class ContractSshVersionBanner {
    public let protocolVersion: String
    public let softwareVersion: String
    public let comments: String

    public init(protocolVersion: String, softwareVersion: String, comments!: String = "") {
        this.protocolVersion = protocolVersion
        this.softwareVersion = softwareVersion
        this.comments = comments
    }
}

public class ContractSshBuildVersionBannerRequest {
    public let softwareVersion: String
    public let comments: String

    public init(softwareVersion: String, comments!: String = "") {
        this.softwareVersion = softwareVersion
        this.comments = comments
    }
}

public class ContractSshEncodeVersionBannerRequest {
    public let banner: ContractSshVersionBanner

    public init(banner: ContractSshVersionBanner) {
        this.banner = banner
    }
}

public class ContractSshDecodeVersionBannerRequest {
    public let encodedLine: Array<Byte>

    public init(encodedLine: Array<Byte>) {
        this.encodedLine = encodedLine.clone()
    }
}

public class ContractSshBuildTranscriptFromPreludeRequest {
    public let clientBanner: ContractSshVersionBanner
    public let serverBanner: ContractSshVersionBanner
    public let clientKexInit: ContractSshKexInitMessage
    public let serverKexInit: ContractSshKexInitMessage

    public init(
        clientBanner: ContractSshVersionBanner,
        serverBanner: ContractSshVersionBanner,
        clientKexInit: ContractSshKexInitMessage,
        serverKexInit: ContractSshKexInitMessage
    ) {
        this.clientBanner = clientBanner
        this.serverBanner = serverBanner
        this.clientKexInit = clientKexInit
        this.serverKexInit = serverKexInit
    }
}

public class ContractSshKexEcdhInitMessage {
    public let clientEphemeralPublicKey: Array<Byte>

    public init(clientEphemeralPublicKey: Array<Byte>) {
        if (clientEphemeralPublicKey.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH KEX_ECDH_INIT client ephemeral public key must not be empty"
            )
        }
        this.clientEphemeralPublicKey = clientEphemeralPublicKey.clone()
    }
}

public class ContractSshKexEcdhReplyMessage {
    public let serverHostKey: Array<Byte>
    public let serverEphemeralPublicKey: Array<Byte>
    public let signature: Array<Byte>

    public init(
        serverHostKey: Array<Byte>,
        serverEphemeralPublicKey: Array<Byte>,
        signature: Array<Byte>
    ) {
        if (
            serverHostKey.size == 0 ||
            serverEphemeralPublicKey.size == 0 ||
            signature.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH KEX_ECDH_REPLY fields must not be empty"
            )
        }
        this.serverHostKey = serverHostKey.clone()
        this.serverEphemeralPublicKey = serverEphemeralPublicKey.clone()
        this.signature = signature.clone()
    }
}

public class ContractSshEncodeKexEcdhInitRequest {
    public let message: ContractSshKexEcdhInitMessage

    public init(message: ContractSshKexEcdhInitMessage) {
        this.message = message
    }
}

public class ContractSshDecodeKexEcdhInitRequest {
    public let encoded: Array<Byte>

    public init(encoded: Array<Byte>) {
        if (encoded.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH encoded KEX_ECDH_INIT payload must not be empty"
            )
        }
        this.encoded = encoded.clone()
    }
}

public class ContractSshEncodeKexEcdhReplyRequest {
    public let message: ContractSshKexEcdhReplyMessage

    public init(message: ContractSshKexEcdhReplyMessage) {
        this.message = message
    }
}

public class ContractSshDecodeKexEcdhReplyRequest {
    public let encoded: Array<Byte>

    public init(encoded: Array<Byte>) {
        if (encoded.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH encoded KEX_ECDH_REPLY payload must not be empty"
            )
        }
        this.encoded = encoded.clone()
    }
}

public class ContractSshEncodeNewKeysRequest {
    public init() {}
}

public class ContractSshDecodeNewKeysRequest {
    public let encoded: Array<Byte>

    public init(encoded: Array<Byte>) {
        if (encoded.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH encoded NEWKEYS payload must not be empty"
            )
        }
        this.encoded = encoded.clone()
    }
}

public class ContractSshKexInitMessage {
    public let cookie: Array<Byte>
    public let kexAlgorithms: Array<String>
    public let serverHostKeyAlgorithms: Array<String>
    public let encryptionAlgorithmsClientToServer: Array<String>
    public let encryptionAlgorithmsServerToClient: Array<String>
    public let macAlgorithmsClientToServer: Array<String>
    public let macAlgorithmsServerToClient: Array<String>
    public let compressionAlgorithmsClientToServer: Array<String>
    public let compressionAlgorithmsServerToClient: Array<String>
    public let languagesClientToServer: Array<String>
    public let languagesServerToClient: Array<String>
    public let firstKexPacketFollows: Bool
    public let reserved: Int64

    public init(
        cookie: Array<Byte>,
        kexAlgorithms: Array<String>,
        serverHostKeyAlgorithms: Array<String>,
        encryptionAlgorithmsClientToServer: Array<String>,
        encryptionAlgorithmsServerToClient: Array<String>,
        macAlgorithmsClientToServer: Array<String>,
        macAlgorithmsServerToClient: Array<String>,
        compressionAlgorithmsClientToServer: Array<String>,
        compressionAlgorithmsServerToClient: Array<String>,
        languagesClientToServer!: Array<String> = [],
        languagesServerToClient!: Array<String> = [],
        firstKexPacketFollows!: Bool = false,
        reserved!: Int64 = 0
    ) {
        _ = contractToSshKexInitMessage(
            cookie,
            kexAlgorithms,
            serverHostKeyAlgorithms,
            encryptionAlgorithmsClientToServer,
            encryptionAlgorithmsServerToClient,
            macAlgorithmsClientToServer,
            macAlgorithmsServerToClient,
            compressionAlgorithmsClientToServer,
            compressionAlgorithmsServerToClient,
            languagesClientToServer: languagesClientToServer,
            languagesServerToClient: languagesServerToClient,
            firstKexPacketFollows: firstKexPacketFollows,
            reserved: reserved
        )
        this.cookie = cookie.clone()
        this.kexAlgorithms = contractCloneStringArray(kexAlgorithms)
        this.serverHostKeyAlgorithms = contractCloneStringArray(serverHostKeyAlgorithms)
        this.encryptionAlgorithmsClientToServer = contractCloneStringArray(encryptionAlgorithmsClientToServer)
        this.encryptionAlgorithmsServerToClient = contractCloneStringArray(encryptionAlgorithmsServerToClient)
        this.macAlgorithmsClientToServer = contractCloneStringArray(macAlgorithmsClientToServer)
        this.macAlgorithmsServerToClient = contractCloneStringArray(macAlgorithmsServerToClient)
        this.compressionAlgorithmsClientToServer = contractCloneStringArray(compressionAlgorithmsClientToServer)
        this.compressionAlgorithmsServerToClient = contractCloneStringArray(compressionAlgorithmsServerToClient)
        this.languagesClientToServer = contractCloneStringArray(languagesClientToServer)
        this.languagesServerToClient = contractCloneStringArray(languagesServerToClient)
        this.firstKexPacketFollows = firstKexPacketFollows
        this.reserved = reserved
    }
}

public class ContractSshBuildDefaultKexInitRequest {
    public let cookie: Array<Byte>

    public init(cookie!: Array<Byte> = []) {
        if (cookie.size != 0 && cookie.size != 16) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH default KEXINIT cookie must be empty or 16 bytes"
            )
        }
        this.cookie = cookie.clone()
    }
}

public class ContractSshEncodeKexInitRequest {
    public let message: ContractSshKexInitMessage

    public init(message: ContractSshKexInitMessage) {
        this.message = message
    }
}

public class ContractSshDecodeKexInitRequest {
    public let encoded: Array<Byte>

    public init(encoded: Array<Byte>) {
        if (encoded.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH encoded KEXINIT payload must not be empty"
            )
        }
        this.encoded = encoded.clone()
    }
}

public class ContractSshNegotiateKexInitRequest {
    public let client: ContractSshKexInitMessage
    public let server: ContractSshKexInitMessage

    public init(client: ContractSshKexInitMessage, server: ContractSshKexInitMessage) {
        this.client = client
        this.server = server
    }
}

public class ContractSshBuildTranscriptFromKexInitRequest {
    public let clientBannerLine: Array<Byte>
    public let serverBannerLine: Array<Byte>
    public let clientKexInit: ContractSshKexInitMessage
    public let serverKexInit: ContractSshKexInitMessage

    public init(
        clientBannerLine: Array<Byte>,
        serverBannerLine: Array<Byte>,
        clientKexInit: ContractSshKexInitMessage,
        serverKexInit: ContractSshKexInitMessage
    ) {
        if (clientBannerLine.size == 0 || serverBannerLine.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH transcript banners must not be empty"
            )
        }
        this.clientBannerLine = clientBannerLine.clone()
        this.serverBannerLine = serverBannerLine.clone()
        this.clientKexInit = clientKexInit
        this.serverKexInit = serverKexInit
    }
}

public class ContractSshX25519InitResult {
    public let encodedInit: Array<Byte>
    public let clientPublicKey: Array<Byte>

    public init(encodedInit: Array<Byte>, clientPublicKey: Array<Byte>) {
        if (encodedInit.size == 0 || clientPublicKey.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH X25519 init result fields must not be empty"
            )
        }
        this.encodedInit = encodedInit.clone()
        this.clientPublicKey = clientPublicKey.clone()
    }
}

public class ContractSshBuildKexEcdhInitX25519Request {
    public let clientPrivateKey: Array<Byte>

    public init(clientPrivateKey: Array<Byte>) {
        if (clientPrivateKey.size != 32) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH X25519 client private key must be 32 bytes"
            )
        }
        this.clientPrivateKey = clientPrivateKey.clone()
    }
}

public class ContractSshServerProcessKexEcdhInitX25519Result {
    public let encodedReply: Array<Byte>
    public let session: ContractSshSessionState

    public init(encodedReply: Array<Byte>, session: ContractSshSessionState) {
        if (encodedReply.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH server KEX reply must not be empty"
            )
        }
        this.encodedReply = encodedReply.clone()
        this.session = session
    }
}

public class ContractSshServerProcessKexEcdhInitX25519Request {
    public let transcript: ContractSshKexExchangeTranscript
    public let serverPrivateKey: Array<Byte>
    public let encodedClientInit: Array<Byte>
    public let hostSigning: ContractSshHostSigningResult
    public let serverPublicKey: Array<Byte>

    public init(
        transcript: ContractSshKexExchangeTranscript,
        serverPrivateKey: Array<Byte>,
        encodedClientInit: Array<Byte>,
        hostSigning: ContractSshHostSigningResult,
        serverPublicKey!: Array<Byte> = []
    ) {
        if (serverPrivateKey.size != 32 || encodedClientInit.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH server KEX request fields are invalid"
            )
        }
        this.transcript = transcript
        this.serverPrivateKey = serverPrivateKey.clone()
        this.encodedClientInit = encodedClientInit.clone()
        this.hostSigning = hostSigning
        this.serverPublicKey = serverPublicKey.clone()
    }
}

public class ContractSshClientProcessKexEcdhReplyX25519Request {
    public let transcript: ContractSshKexExchangeTranscript
    public let clientPrivateKey: Array<Byte>
    public let encodedClientInit: Array<Byte>
    public let encodedServerReply: Array<Byte>
    public let policy: ContractSshHostVerificationPolicy

    public init(
        transcript: ContractSshKexExchangeTranscript,
        clientPrivateKey: Array<Byte>,
        encodedClientInit: Array<Byte>,
        encodedServerReply: Array<Byte>,
        policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
    ) {
        if (
            clientPrivateKey.size != 32 ||
            encodedClientInit.size == 0 ||
            encodedServerReply.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH client KEX request fields are invalid"
            )
        }
        this.transcript = transcript
        this.clientPrivateKey = clientPrivateKey.clone()
        this.encodedClientInit = encodedClientInit.clone()
        this.encodedServerReply = encodedServerReply.clone()
        this.policy = policy
    }
}

public class ContractSshHostVerificationPolicy {
    public let negotiatedHostKeyAlgorithm: String
    public let expectedHostKeySha256: Array<Byte>
    public let requireKnownHost: Bool
    public let requireHostSignature: Bool
    public let allowLegacyRsaSha1: Bool
    public let requireVerifiedHost: Bool

    public init(
        negotiatedHostKeyAlgorithm!: String = "",
        expectedHostKeySha256!: Array<Byte> = [],
        requireKnownHost!: Bool = false,
        requireHostSignature!: Bool = true,
        allowLegacyRsaSha1!: Bool = false,
        requireVerifiedHost!: Bool = true
    ) {
        let normalizedNegotiated = negotiatedHostKeyAlgorithm.trimAscii().toAsciiLower()
        if (expectedHostKeySha256.size != 0 && expectedHostKeySha256.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "SSH expected host key fingerprint must be SHA-256 sized")
        }
        if (requireKnownHost && expectedHostKeySha256.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH known-host verification requires expected host key fingerprint"
            )
        }

        this.negotiatedHostKeyAlgorithm = normalizedNegotiated
        this.expectedHostKeySha256 = expectedHostKeySha256.clone()
        this.requireKnownHost = requireKnownHost
        this.requireHostSignature = requireHostSignature
        this.allowLegacyRsaSha1 = allowLegacyRsaSha1
        this.requireVerifiedHost = requireVerifiedHost
    }
}

public class ContractSshVerifyHostIdentityRequest {
    public let exchangeHash: Array<Byte>
    public let serverHostKey: Array<Byte>
    public let hostSignature: Array<Byte>
    public let policy: ContractSshHostVerificationPolicy

    public init(
        exchangeHash: Array<Byte>,
        serverHostKey: Array<Byte>,
        hostSignature: Array<Byte>,
        policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
    ) {
        if (exchangeHash.size == 0 || serverHostKey.size == 0 || hostSignature.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH host verification request fields must not be empty"
            )
        }
        this.exchangeHash = exchangeHash.clone()
        this.serverHostKey = serverHostKey.clone()
        this.hostSignature = hostSignature.clone()
        this.policy = policy
    }
}

public class ContractSshHostVerificationResult {
    public let hostKeyAlgorithm: String
    public let hostSignatureAlgorithm: String
    public let hostKeySha256: Array<Byte>
    public let hostSignatureVerified: Bool

    public init(
        hostKeyAlgorithm: String,
        hostSignatureAlgorithm: String,
        hostKeySha256: Array<Byte>,
        hostSignatureVerified: Bool
    ) {
        if (hostKeyAlgorithm.size == 0 || hostSignatureAlgorithm.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH host verification algorithms must not be empty")
        }
        if (hostKeySha256.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "SSH host key fingerprint must be SHA-256 sized")
        }
        this.hostKeyAlgorithm = hostKeyAlgorithm
        this.hostSignatureAlgorithm = hostSignatureAlgorithm
        this.hostKeySha256 = hostKeySha256.clone()
        this.hostSignatureVerified = hostSignatureVerified
    }

    public func hostIdentity(): ContractSshHostIdentitySummary {
        ContractSshHostIdentitySummary(
            hostKeyAlgorithm,
            hostSignatureAlgorithm,
            hostKeySha256,
            signatureVerified: Some(hostSignatureVerified)
        )
    }
}

public class ContractSshHostVerificationOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractSshHostVerificationResult

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractSshHostVerificationResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH host verification outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "SSH host verification outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractSshHostIdentitySummary {
    public let hostKeyAlgorithm: String
    public let hostSignatureAlgorithm: String
    public let hostKeySha256: Array<Byte>
    public let signatureVerified: ?Bool

    public init(
        hostKeyAlgorithm: String,
        hostSignatureAlgorithm: String,
        hostKeySha256: Array<Byte>,
        signatureVerified!: ?Bool = None
    ) {
        if (hostKeyAlgorithm.size == 0 || hostSignatureAlgorithm.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH host identity summary algorithms must not be empty")
        }
        if (hostKeySha256.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "SSH host identity summary fingerprint must be SHA-256 sized")
        }
        this.hostKeyAlgorithm = hostKeyAlgorithm
        this.hostSignatureAlgorithm = hostSignatureAlgorithm
        this.hostKeySha256 = hostKeySha256.clone()
        this.signatureVerified = signatureVerified
    }
}

public class ContractSshSessionSnapshot {
    public let sessionId: Array<Byte>
    public let hostIdentity: ContractSshHostIdentitySummary
    public let hostVerification: ?ContractSshHostVerificationResult

    public init(
        sessionId: Array<Byte>,
        hostIdentity: ContractSshHostIdentitySummary,
        hostVerification!: ?ContractSshHostVerificationResult = None
    ) {
        if (sessionId.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH session snapshot session id must not be empty")
        }
        this.sessionId = sessionId.clone()
        this.hostIdentity = hostIdentity
        this.hostVerification = hostVerification
    }

    public func requireHostVerification(): ContractSshHostVerificationResult {
        match (hostVerification) {
            case Some(value) => value
            case None =>
                throw ContractException(
                    ContractErrorCode.VerifyFailed,
                    "SSH session snapshot host identity verification is unavailable"
                )
        }
    }
}

public class ContractSshRuntimeSnapshot {
    public let session: ContractSshSessionSnapshot
    public let writeSequence: Int64
    public let readSequence: Int64

    public init(
        session: ContractSshSessionSnapshot,
        writeSequence: Int64,
        readSequence: Int64
    ) {
        if (writeSequence < 0 || readSequence < 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH runtime snapshot sequence counters must not be negative")
        }
        this.session = session
        this.writeSequence = writeSequence
        this.readSequence = readSequence
    }

    public func sessionId(): Array<Byte> {
        session.sessionId.clone()
    }

    public func hostIdentity(): ContractSshHostIdentitySummary {
        session.hostIdentity
    }

    public func hostVerification(): ?ContractSshHostVerificationResult {
        session.hostVerification
    }
}

public class ContractSshHostSigningResult {
    public let serverHostKey: Array<Byte>
    public let hostSignature: Array<Byte>
    public let hostKeyAlgorithm: String
    public let hostSignatureAlgorithm: String
    public let hostKeySha256: Array<Byte>

    public init(
        serverHostKey: Array<Byte>,
        hostSignature: Array<Byte>,
        hostKeyAlgorithm: String,
        hostSignatureAlgorithm: String,
        hostKeySha256: Array<Byte>
    ) {
        if (serverHostKey.size == 0 || hostSignature.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH host signing result fields must not be empty")
        }
        if (hostKeyAlgorithm.size == 0 || hostSignatureAlgorithm.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH host signing algorithms must not be empty")
        }
        if (hostKeySha256.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "SSH host signing fingerprint must be SHA-256 sized")
        }
        this.serverHostKey = serverHostKey.clone()
        this.hostSignature = hostSignature.clone()
        this.hostKeyAlgorithm = hostKeyAlgorithm
        this.hostSignatureAlgorithm = hostSignatureAlgorithm
        this.hostKeySha256 = hostKeySha256.clone()
    }
}

public class ContractSshHostSigningOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractSshHostSigningResult

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractSshHostSigningResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH host signing outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "SSH host signing outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractSshHostSigningRsaPkcs8Request {
    public let hostPrivateKeyPkcs8Pem: String
    public let exchangeHash: Array<Byte>
    public let signatureAlgorithm: String

    public init(
        hostPrivateKeyPkcs8Pem: String,
        exchangeHash: Array<Byte>,
        signatureAlgorithm!: String = "rsa-sha2-256"
    ) {
        if (
            hostPrivateKeyPkcs8Pem.trimAscii().size == 0 ||
            exchangeHash.size == 0 ||
            signatureAlgorithm.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH RSA host signing request fields are invalid"
            )
        }
        this.hostPrivateKeyPkcs8Pem = hostPrivateKeyPkcs8Pem
        this.exchangeHash = exchangeHash.clone()
        this.signatureAlgorithm = signatureAlgorithm.trimAscii()
    }
}

public class ContractSshHostSigningEcdsaPkcs8Request {
    public let hostPrivateKeyPkcs8Pem: String
    public let exchangeHash: Array<Byte>

    public init(
        hostPrivateKeyPkcs8Pem: String,
        exchangeHash: Array<Byte>
    ) {
        if (
            hostPrivateKeyPkcs8Pem.trimAscii().size == 0 ||
            exchangeHash.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH ECDSA host signing request fields are invalid"
            )
        }
        this.hostPrivateKeyPkcs8Pem = hostPrivateKeyPkcs8Pem
        this.exchangeHash = exchangeHash.clone()
    }
}

public class ContractSshHostSigningEd25519SeedRequest {
    public let hostPrivateKeySeed: Array<Byte>
    public let exchangeHash: Array<Byte>

    public init(
        hostPrivateKeySeed: Array<Byte>,
        exchangeHash: Array<Byte>
    ) {
        if (
            hostPrivateKeySeed.size != 32 ||
            exchangeHash.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH Ed25519 host signing request fields are invalid"
            )
        }
        this.hostPrivateKeySeed = hostPrivateKeySeed.clone()
        this.exchangeHash = exchangeHash.clone()
    }
}

public class ContractSshServerInitialHandshakeX25519RsaRequest {
    public let transcript: ContractSshKexExchangeTranscript
    public let serverPrivateKey: Array<Byte>
    public let encodedClientInit: Array<Byte>
    public let hostPrivateKey: RsaPrivateKey
    public let negotiated: ContractSshNegotiatedAlgorithms
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>
    public let signatureAlgorithm: String
    public let serverPublicKey: Array<Byte>

    public init(
        transcript: ContractSshKexExchangeTranscript,
        serverPrivateKey: Array<Byte>,
        encodedClientInit: Array<Byte>,
        hostPrivateKey: RsaPrivateKey,
        negotiated: ContractSshNegotiatedAlgorithms,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>,
        signatureAlgorithm!: String = "rsa-sha2-256",
        serverPublicKey!: Array<Byte> = []
    ) {
        if (
            serverPrivateKey.size != 32 ||
            encodedClientInit.size == 0 ||
            encodedClientNewKeys.size == 0 ||
            encodedServerNewKeys.size == 0 ||
            signatureAlgorithm.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH RSA server handshake request fields are invalid"
            )
        }
        this.transcript = transcript
        this.serverPrivateKey = serverPrivateKey.clone()
        this.encodedClientInit = encodedClientInit.clone()
        this.hostPrivateKey = hostPrivateKey
        this.negotiated = negotiated
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
        this.signatureAlgorithm = signatureAlgorithm.trimAscii()
        this.serverPublicKey = serverPublicKey.clone()
    }
}

public class ContractSshServerInitialHandshakeX25519EcdsaRequest {
    public let transcript: ContractSshKexExchangeTranscript
    public let serverPrivateKey: Array<Byte>
    public let encodedClientInit: Array<Byte>
    public let hostPrivateKey: EcPrivateKey
    public let negotiated: ContractSshNegotiatedAlgorithms
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>
    public let serverPublicKey: Array<Byte>

    public init(
        transcript: ContractSshKexExchangeTranscript,
        serverPrivateKey: Array<Byte>,
        encodedClientInit: Array<Byte>,
        hostPrivateKey: EcPrivateKey,
        negotiated: ContractSshNegotiatedAlgorithms,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>,
        serverPublicKey!: Array<Byte> = []
    ) {
        if (
            serverPrivateKey.size != 32 ||
            encodedClientInit.size == 0 ||
            encodedClientNewKeys.size == 0 ||
            encodedServerNewKeys.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH ECDSA server handshake request fields are invalid"
            )
        }
        this.transcript = transcript
        this.serverPrivateKey = serverPrivateKey.clone()
        this.encodedClientInit = encodedClientInit.clone()
        this.hostPrivateKey = hostPrivateKey
        this.negotiated = negotiated
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
        this.serverPublicKey = serverPublicKey.clone()
    }
}

public class ContractSshServerInitialHandshakeX25519Ed25519Request {
    public let transcript: ContractSshKexExchangeTranscript
    public let serverPrivateKey: Array<Byte>
    public let encodedClientInit: Array<Byte>
    public let hostPrivateKeySeed: Array<Byte>
    public let negotiated: ContractSshNegotiatedAlgorithms
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>
    public let serverPublicKey: Array<Byte>

    public init(
        transcript: ContractSshKexExchangeTranscript,
        serverPrivateKey: Array<Byte>,
        encodedClientInit: Array<Byte>,
        hostPrivateKeySeed: Array<Byte>,
        negotiated: ContractSshNegotiatedAlgorithms,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>,
        serverPublicKey!: Array<Byte> = []
    ) {
        if (
            serverPrivateKey.size != 32 ||
            encodedClientInit.size == 0 ||
            hostPrivateKeySeed.size != 32 ||
            encodedClientNewKeys.size == 0 ||
            encodedServerNewKeys.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH Ed25519 server handshake request fields are invalid"
            )
        }
        this.transcript = transcript
        this.serverPrivateKey = serverPrivateKey.clone()
        this.encodedClientInit = encodedClientInit.clone()
        this.hostPrivateKeySeed = hostPrivateKeySeed.clone()
        this.negotiated = negotiated
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
        this.serverPublicKey = serverPublicKey.clone()
    }
}

public class ContractSshClientInitialHandshakeX25519Request {
    public let transcript: ContractSshKexExchangeTranscript
    public let clientPrivateKey: Array<Byte>
    public let encodedClientInit: Array<Byte>
    public let encodedServerReply: Array<Byte>
    public let negotiated: ContractSshNegotiatedAlgorithms
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>
    public let policy: ContractSshHostVerificationPolicy

    public init(
        transcript: ContractSshKexExchangeTranscript,
        clientPrivateKey: Array<Byte>,
        encodedClientInit: Array<Byte>,
        encodedServerReply: Array<Byte>,
        negotiated: ContractSshNegotiatedAlgorithms,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>,
        policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
    ) {
        if (
            clientPrivateKey.size != 32 ||
            encodedClientInit.size == 0 ||
            encodedServerReply.size == 0 ||
            encodedClientNewKeys.size == 0 ||
            encodedServerNewKeys.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH client handshake request fields are invalid"
            )
        }
        this.transcript = transcript
        this.clientPrivateKey = clientPrivateKey.clone()
        this.encodedClientInit = encodedClientInit.clone()
        this.encodedServerReply = encodedServerReply.clone()
        this.negotiated = negotiated
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
        this.policy = policy
    }
}

public class ContractSshServerInitialHandshakeResult {
    public let encodedReply: Array<Byte>
    public let sharedSecret: Array<Byte>
    public let exchangeHash: Array<Byte>
    public let sessionId: Array<Byte>
    public let clientEphemeralPublicKey: Array<Byte>
    public let serverEphemeralPublicKey: Array<Byte>
    public let serverHostKey: Array<Byte>
    public let hostSignature: Array<Byte>
    public let hostKeyAlgorithm: String
    public let hostSignatureAlgorithm: String
    public let hostKeySha256: Array<Byte>
    let _transport: ContractSshTransportChannel

    public init(
        encodedReply: Array<Byte>,
        sharedSecret: Array<Byte>,
        exchangeHash: Array<Byte>,
        sessionId: Array<Byte>,
        clientEphemeralPublicKey: Array<Byte>,
        serverEphemeralPublicKey: Array<Byte>,
        serverHostKey: Array<Byte>,
        hostSignature: Array<Byte>,
        hostKeyAlgorithm: String,
        hostSignatureAlgorithm: String,
        hostKeySha256: Array<Byte>,
        transport: ContractSshTransportChannel
    ) {
        if (
            encodedReply.size == 0 ||
            sharedSecret.size == 0 ||
            exchangeHash.size == 0 ||
            sessionId.size == 0 ||
            clientEphemeralPublicKey.size == 0 ||
            serverEphemeralPublicKey.size == 0 ||
            serverHostKey.size == 0 ||
            hostSignature.size == 0
        ) {
            throw ContractException(ContractErrorCode.BadInput, "SSH server handshake result fields must not be empty")
        }
        if (hostKeyAlgorithm.size == 0 || hostSignatureAlgorithm.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH server handshake algorithms must not be empty")
        }
        if (hostKeySha256.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "SSH server handshake fingerprint must be SHA-256 sized")
        }
        this.encodedReply = encodedReply.clone()
        this.sharedSecret = sharedSecret.clone()
        this.exchangeHash = exchangeHash.clone()
        this.sessionId = sessionId.clone()
        this.clientEphemeralPublicKey = clientEphemeralPublicKey.clone()
        this.serverEphemeralPublicKey = serverEphemeralPublicKey.clone()
        this.serverHostKey = serverHostKey.clone()
        this.hostSignature = hostSignature.clone()
        this.hostKeyAlgorithm = hostKeyAlgorithm
        this.hostSignatureAlgorithm = hostSignatureAlgorithm
        this.hostKeySha256 = hostKeySha256.clone()
        this._transport = transport
    }

    public func transport(): ContractSshTransportChannel {
        _transport
    }

    public func sessionSnapshot(): ContractSshSessionSnapshot {
        ContractSshSessionSnapshot(
            sessionId,
            ContractSshHostIdentitySummary(
                hostKeyAlgorithm,
                hostSignatureAlgorithm,
                hostKeySha256
            )
        )
    }
}

public class ContractSshClientInitialHandshakeResult {
    public let sharedSecret: Array<Byte>
    public let exchangeHash: Array<Byte>
    public let sessionId: Array<Byte>
    public let clientEphemeralPublicKey: Array<Byte>
    public let serverEphemeralPublicKey: Array<Byte>
    public let serverHostKey: Array<Byte>
    public let hostSignature: Array<Byte>
    public let hostKeyAlgorithm: String
    public let hostSignatureAlgorithm: String
    public let hostKeySha256: Array<Byte>
    public let hostVerification: ?ContractSshHostVerificationResult
    let _transport: ContractSshTransportChannel

    public init(
        sharedSecret: Array<Byte>,
        exchangeHash: Array<Byte>,
        sessionId: Array<Byte>,
        clientEphemeralPublicKey: Array<Byte>,
        serverEphemeralPublicKey: Array<Byte>,
        serverHostKey: Array<Byte>,
        hostSignature: Array<Byte>,
        hostKeyAlgorithm: String,
        hostSignatureAlgorithm: String,
        hostKeySha256: Array<Byte>,
        transport: ContractSshTransportChannel,
        hostVerification!: ?ContractSshHostVerificationResult = None
    ) {
        if (
            sharedSecret.size == 0 ||
            exchangeHash.size == 0 ||
            sessionId.size == 0 ||
            clientEphemeralPublicKey.size == 0 ||
            serverEphemeralPublicKey.size == 0 ||
            serverHostKey.size == 0 ||
            hostSignature.size == 0
        ) {
            throw ContractException(ContractErrorCode.BadInput, "SSH client handshake result fields must not be empty")
        }
        if (hostKeyAlgorithm.size == 0 || hostSignatureAlgorithm.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH client handshake algorithms must not be empty")
        }
        if (hostKeySha256.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "SSH client handshake fingerprint must be SHA-256 sized")
        }
        this.sharedSecret = sharedSecret.clone()
        this.exchangeHash = exchangeHash.clone()
        this.sessionId = sessionId.clone()
        this.clientEphemeralPublicKey = clientEphemeralPublicKey.clone()
        this.serverEphemeralPublicKey = serverEphemeralPublicKey.clone()
        this.serverHostKey = serverHostKey.clone()
        this.hostSignature = hostSignature.clone()
        this.hostKeyAlgorithm = hostKeyAlgorithm
        this.hostSignatureAlgorithm = hostSignatureAlgorithm
        this.hostKeySha256 = hostKeySha256.clone()
        this._transport = transport
        this.hostVerification = hostVerification
    }

    public func requireHostVerification(): ContractSshHostVerificationResult {
        match (hostVerification) {
            case Some(value) => value
            case None =>
                throw ContractException(
                    ContractErrorCode.VerifyFailed,
                    "SSH host identity verification is unavailable"
                )
        }
    }

    public func transport(): ContractSshTransportChannel {
        _transport
    }

    public func sessionSnapshot(): ContractSshSessionSnapshot {
        ContractSshSessionSnapshot(
            sessionId,
            ContractSshHostIdentitySummary(
                hostKeyAlgorithm,
                hostSignatureAlgorithm,
                hostKeySha256,
                signatureVerified: contractTryHostVerificationSignatureVerified(hostVerification)
            ),
            hostVerification: hostVerification
        )
    }
}

public class ContractSshServerInitialHandshakeOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractSshServerInitialHandshakeResult

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractSshServerInitialHandshakeResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH server handshake outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "SSH server handshake outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractSshClientInitialHandshakeOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractSshClientInitialHandshakeResult

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractSshClientInitialHandshakeResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH client handshake outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "SSH client handshake outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractSshSessionState {
    public let sharedSecret: Array<Byte>
    public let exchangeHash: Array<Byte>
    public let sessionId: Array<Byte>
    public let clientEphemeralPublicKey: Array<Byte>
    public let serverEphemeralPublicKey: Array<Byte>
    public let serverHostKey: Array<Byte>
    public let hostSignature: Array<Byte>
    public let hostKeyAlgorithm: String
    public let hostSignatureAlgorithm: String
    public let hostKeySha256: Array<Byte>
    public let hostVerification: ?ContractSshHostVerificationResult

    public init(
        sharedSecret: Array<Byte>,
        exchangeHash: Array<Byte>,
        sessionId: Array<Byte>,
        clientEphemeralPublicKey: Array<Byte>,
        serverEphemeralPublicKey: Array<Byte>,
        serverHostKey: Array<Byte>,
        hostSignature: Array<Byte>,
        hostKeyAlgorithm: String,
        hostSignatureAlgorithm: String,
        hostKeySha256: Array<Byte>,
        hostVerification!: ?ContractSshHostVerificationResult = None
    ) {
        if (
            sharedSecret.size == 0 ||
            exchangeHash.size == 0 ||
            sessionId.size == 0 ||
            clientEphemeralPublicKey.size == 0 ||
            serverEphemeralPublicKey.size == 0 ||
            serverHostKey.size == 0 ||
            hostSignature.size == 0
        ) {
            throw ContractException(ContractErrorCode.BadInput, "SSH session state fields must not be empty")
        }
        if (hostKeyAlgorithm.size == 0 || hostSignatureAlgorithm.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH session state algorithms must not be empty")
        }
        if (hostKeySha256.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "SSH session state fingerprint must be SHA-256 sized")
        }
        this.sharedSecret = sharedSecret.clone()
        this.exchangeHash = exchangeHash.clone()
        this.sessionId = sessionId.clone()
        this.clientEphemeralPublicKey = clientEphemeralPublicKey.clone()
        this.serverEphemeralPublicKey = serverEphemeralPublicKey.clone()
        this.serverHostKey = serverHostKey.clone()
        this.hostSignature = hostSignature.clone()
        this.hostKeyAlgorithm = hostKeyAlgorithm
        this.hostSignatureAlgorithm = hostSignatureAlgorithm
        this.hostKeySha256 = hostKeySha256.clone()
        this.hostVerification = hostVerification
    }

    public func requireHostVerification(): ContractSshHostVerificationResult {
        match (hostVerification) {
            case Some(value) => value
            case None =>
                throw ContractException(
                    ContractErrorCode.VerifyFailed,
                    "SSH host identity verification is unavailable"
                )
        }
    }

    public func snapshot(): ContractSshSessionSnapshot {
        ContractSshSessionSnapshot(
            sessionId,
            ContractSshHostIdentitySummary(
                hostKeyAlgorithm,
                hostSignatureAlgorithm,
                hostKeySha256,
                signatureVerified: contractTryHostVerificationSignatureVerified(hostVerification)
            ),
            hostVerification: hostVerification
        )
    }
}

public class ContractSshServerRuntime {
    public let initialHandshake: ContractSshServerInitialHandshakeResult
    let _currentSession: ContractSshSessionState

    public init(
        initialHandshake: ContractSshServerInitialHandshakeResult,
        currentSession!: ?ContractSshSessionState = None
    ) {
        this.initialHandshake = initialHandshake
        this._currentSession = contractResolveSshServerRuntimeSessionState(
            initialHandshake,
            currentSession
        )
    }

    public prop writeSequence: Int64 {
        get() {
            initialHandshake.transport().writeSequence
        }
    }

    public prop readSequence: Int64 {
        get() {
            initialHandshake.transport().readSequence
        }
    }

    public func sessionId(): Array<Byte> {
        initialHandshake.transport().sessionId()
    }

    public func currentSession(): ContractSshSessionState {
        _currentSession
    }

    public func transport(): ContractSshTransportChannel {
        initialHandshake.transport()
    }

    public func snapshot(): ContractSshRuntimeSnapshot {
        ContractSshRuntimeSnapshot(currentSession().snapshot(), writeSequence, readSequence)
    }

    public func resetTransportCounters(): Unit {
        initialHandshake.transport().resetTransportCounters()
    }

    public func seal(payload: Array<Byte>, randomPadding!: Array<Byte> = []): Array<Byte> {
        initialHandshake.transport().seal(payload, randomPadding: randomPadding)
    }

    public func open(encodedPacket: Array<Byte>): ContractSshTransportPacket {
        initialHandshake.transport().open(encodedPacket)
    }
}

public class ContractSshClientRuntime {
    public let initialHandshake: ContractSshClientInitialHandshakeResult
    let _currentSession: ContractSshSessionState

    public init(
        initialHandshake: ContractSshClientInitialHandshakeResult,
        currentSession!: ?ContractSshSessionState = None
    ) {
        this.initialHandshake = initialHandshake
        this._currentSession = contractResolveSshClientRuntimeSessionState(
            initialHandshake,
            currentSession
        )
    }

    public prop writeSequence: Int64 {
        get() {
            initialHandshake.transport().writeSequence
        }
    }

    public prop readSequence: Int64 {
        get() {
            initialHandshake.transport().readSequence
        }
    }

    public func sessionId(): Array<Byte> {
        initialHandshake.transport().sessionId()
    }

    public func currentSession(): ContractSshSessionState {
        _currentSession
    }

    public func transport(): ContractSshTransportChannel {
        initialHandshake.transport()
    }

    public func hostVerification(): ?ContractSshHostVerificationResult {
        _currentSession.hostVerification
    }

    public func requireHostVerification(): ContractSshHostVerificationResult {
        _currentSession.requireHostVerification()
    }

    public func snapshot(): ContractSshRuntimeSnapshot {
        ContractSshRuntimeSnapshot(currentSession().snapshot(), writeSequence, readSequence)
    }

    public func resetTransportCounters(): Unit {
        initialHandshake.transport().resetTransportCounters()
    }

    public func seal(payload: Array<Byte>, randomPadding!: Array<Byte> = []): Array<Byte> {
        initialHandshake.transport().seal(payload, randomPadding: randomPadding)
    }

    public func open(encodedPacket: Array<Byte>): ContractSshTransportPacket {
        initialHandshake.transport().open(encodedPacket)
    }
}

public class ContractSshServerRuntimeRequest {
    public let result: ContractSshServerInitialHandshakeResult

    public init(result: ContractSshServerInitialHandshakeResult) {
        this.result = result
    }
}

public class ContractSshClientRuntimeRequest {
    public let result: ContractSshClientInitialHandshakeResult

    public init(result: ContractSshClientInitialHandshakeResult) {
        this.result = result
    }
}

public class ContractSshServerRuntimeRekeyRequest {
    public let runtime: ContractSshServerRuntime
    public let kexResult: SshX25519KexResult
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>

    public init(
        runtime: ContractSshServerRuntime,
        kexResult: SshX25519KexResult,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>
    ) {
        if (encodedClientNewKeys.size == 0 || encodedServerNewKeys.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH server runtime rekey NEWKEYS frames must not be empty"
            )
        }
        this.runtime = runtime
        this.kexResult = kexResult
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
    }
}

public class ContractSshClientRuntimeRekeyRequest {
    public let runtime: ContractSshClientRuntime
    public let kexResult: SshX25519KexResult
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>
    public let policy: ContractSshHostVerificationPolicy

    public init(
        runtime: ContractSshClientRuntime,
        kexResult: SshX25519KexResult,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>,
        policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
    ) {
        if (encodedClientNewKeys.size == 0 || encodedServerNewKeys.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH client runtime rekey NEWKEYS frames must not be empty"
            )
        }
        this.runtime = runtime
        this.kexResult = kexResult
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
        this.policy = policy
    }
}

public class ContractSshServerRuntimeSessionRekeyRequest {
    public let runtime: ContractSshServerRuntime
    public let session: ContractSshSessionState
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>

    public init(
        runtime: ContractSshServerRuntime,
        session: ContractSshSessionState,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>
    ) {
        if (encodedClientNewKeys.size == 0 || encodedServerNewKeys.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH server runtime session rekey NEWKEYS frames must not be empty"
            )
        }
        this.runtime = runtime
        this.session = session
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
    }
}

public class ContractSshClientRuntimeSessionRekeyRequest {
    public let runtime: ContractSshClientRuntime
    public let session: ContractSshSessionState
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>
    public let policy: ContractSshHostVerificationPolicy

    public init(
        runtime: ContractSshClientRuntime,
        session: ContractSshSessionState,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>,
        policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
    ) {
        if (encodedClientNewKeys.size == 0 || encodedServerNewKeys.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH client runtime session rekey NEWKEYS frames must not be empty"
            )
        }
        this.runtime = runtime
        this.session = session
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
        this.policy = policy
    }
}

public class ContractSshServerRuntimeRekeyResult {
    public let runtime: ContractSshServerRuntime
    public let session: ContractSshSessionState

    public init(
        runtime: ContractSshServerRuntime,
        session: ContractSshSessionState
    ) {
        this.runtime = runtime
        this.session = session
    }
}

public class ContractSshClientRuntimeRekeyResult {
    public let runtime: ContractSshClientRuntime
    public let session: ContractSshSessionState

    public init(
        runtime: ContractSshClientRuntime,
        session: ContractSshSessionState
    ) {
        this.runtime = runtime
        this.session = session
    }
}

public class ContractSshServerRuntimeBundle {
    public let runtime: ContractSshServerRuntime
    public let session: ContractSshSessionState
    public let snapshot: ContractSshRuntimeSnapshot

    public init(
        runtime: ContractSshServerRuntime,
        session: ContractSshSessionState,
        snapshot: ContractSshRuntimeSnapshot
    ) {
        this.runtime = runtime
        this.session = session
        this.snapshot = snapshot
    }
}

public class ContractSshClientRuntimeBundle {
    public let runtime: ContractSshClientRuntime
    public let session: ContractSshSessionState
    public let snapshot: ContractSshRuntimeSnapshot

    public init(
        runtime: ContractSshClientRuntime,
        session: ContractSshSessionState,
        snapshot: ContractSshRuntimeSnapshot
    ) {
        this.runtime = runtime
        this.session = session
        this.snapshot = snapshot
    }
}

public class ContractSshServerRuntimeOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractSshServerRuntimeBundle

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractSshServerRuntimeBundle = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH server runtime outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "SSH server runtime outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractSshClientRuntimeOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractSshClientRuntimeBundle

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractSshClientRuntimeBundle = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH client runtime outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "SSH client runtime outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractSshServerLibraryStartupX25519RsaPkcs8Request {
    public let transcript: ContractSshKexExchangeTranscript
    public let serverPrivateKey: Array<Byte>
    public let encodedClientInit: Array<Byte>
    public let hostPrivateKeyPkcs8Pem: String
    public let negotiated: ContractSshNegotiatedAlgorithms
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>
    public let signatureAlgorithm: String
    public let serverPublicKey: Array<Byte>
    public let profile: ContractHttpSshStartupProfile
    public let requestedAesEngine: ContractAesEngineKind
    public let aesBackendHint: String

    public init(
        transcript: ContractSshKexExchangeTranscript,
        serverPrivateKey: Array<Byte>,
        encodedClientInit: Array<Byte>,
        hostPrivateKeyPkcs8Pem: String,
        negotiated: ContractSshNegotiatedAlgorithms,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>,
        signatureAlgorithm!: String = "rsa-sha2-256",
        serverPublicKey!: Array<Byte> = [],
        profile!: ContractHttpSshStartupProfile = ContractHttpSshStartupProfile.SshServerLibrary,
        requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
        aesBackendHint!: String = ""
    ) {
        if (
            serverPrivateKey.size != 32 ||
            encodedClientInit.size == 0 ||
            hostPrivateKeyPkcs8Pem.trimAscii().size == 0 ||
            encodedClientNewKeys.size == 0 ||
            encodedServerNewKeys.size == 0 ||
            signatureAlgorithm.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH server startup RSA request fields are invalid"
            )
        }
        this.transcript = transcript
        this.serverPrivateKey = serverPrivateKey.clone()
        this.encodedClientInit = encodedClientInit.clone()
        this.hostPrivateKeyPkcs8Pem = hostPrivateKeyPkcs8Pem
        this.negotiated = negotiated
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
        this.signatureAlgorithm = signatureAlgorithm.trimAscii()
        this.serverPublicKey = serverPublicKey.clone()
        this.profile = profile
        this.requestedAesEngine = requestedAesEngine
        this.aesBackendHint = aesBackendHint.trimAscii()
    }
}

public class ContractSshServerLibraryStartupX25519EcdsaPkcs8Request {
    public let transcript: ContractSshKexExchangeTranscript
    public let serverPrivateKey: Array<Byte>
    public let encodedClientInit: Array<Byte>
    public let hostPrivateKeyPkcs8Pem: String
    public let negotiated: ContractSshNegotiatedAlgorithms
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>
    public let serverPublicKey: Array<Byte>
    public let profile: ContractHttpSshStartupProfile
    public let requestedAesEngine: ContractAesEngineKind
    public let aesBackendHint: String

    public init(
        transcript: ContractSshKexExchangeTranscript,
        serverPrivateKey: Array<Byte>,
        encodedClientInit: Array<Byte>,
        hostPrivateKeyPkcs8Pem: String,
        negotiated: ContractSshNegotiatedAlgorithms,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>,
        serverPublicKey!: Array<Byte> = [],
        profile!: ContractHttpSshStartupProfile = ContractHttpSshStartupProfile.SshServerLibrary,
        requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
        aesBackendHint!: String = ""
    ) {
        if (
            serverPrivateKey.size != 32 ||
            encodedClientInit.size == 0 ||
            hostPrivateKeyPkcs8Pem.trimAscii().size == 0 ||
            encodedClientNewKeys.size == 0 ||
            encodedServerNewKeys.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH server startup ECDSA request fields are invalid"
            )
        }
        this.transcript = transcript
        this.serverPrivateKey = serverPrivateKey.clone()
        this.encodedClientInit = encodedClientInit.clone()
        this.hostPrivateKeyPkcs8Pem = hostPrivateKeyPkcs8Pem
        this.negotiated = negotiated
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
        this.serverPublicKey = serverPublicKey.clone()
        this.profile = profile
        this.requestedAesEngine = requestedAesEngine
        this.aesBackendHint = aesBackendHint.trimAscii()
    }
}

public class ContractSshServerLibraryStartupX25519Ed25519SeedRequest {
    public let transcript: ContractSshKexExchangeTranscript
    public let serverPrivateKey: Array<Byte>
    public let encodedClientInit: Array<Byte>
    public let hostPrivateKeySeed: Array<Byte>
    public let negotiated: ContractSshNegotiatedAlgorithms
    public let encodedClientNewKeys: Array<Byte>
    public let encodedServerNewKeys: Array<Byte>
    public let serverPublicKey: Array<Byte>
    public let profile: ContractHttpSshStartupProfile
    public let requestedAesEngine: ContractAesEngineKind
    public let aesBackendHint: String

    public init(
        transcript: ContractSshKexExchangeTranscript,
        serverPrivateKey: Array<Byte>,
        encodedClientInit: Array<Byte>,
        hostPrivateKeySeed: Array<Byte>,
        negotiated: ContractSshNegotiatedAlgorithms,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>,
        serverPublicKey!: Array<Byte> = [],
        profile!: ContractHttpSshStartupProfile = ContractHttpSshStartupProfile.SshServerLibrary,
        requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
        aesBackendHint!: String = ""
    ) {
        if (
            serverPrivateKey.size != 32 ||
            encodedClientInit.size == 0 ||
            hostPrivateKeySeed.size != 32 ||
            encodedClientNewKeys.size == 0 ||
            encodedServerNewKeys.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH server startup Ed25519 request fields are invalid"
            )
        }
        this.transcript = transcript
        this.serverPrivateKey = serverPrivateKey.clone()
        this.encodedClientInit = encodedClientInit.clone()
        this.hostPrivateKeySeed = hostPrivateKeySeed.clone()
        this.negotiated = negotiated
        this.encodedClientNewKeys = encodedClientNewKeys.clone()
        this.encodedServerNewKeys = encodedServerNewKeys.clone()
        this.serverPublicKey = serverPublicKey.clone()
        this.profile = profile
        this.requestedAesEngine = requestedAesEngine
        this.aesBackendHint = aesBackendHint.trimAscii()
    }
}

public class ContractSshClientLibraryStartupX25519Request {
    public let handshake: ContractSshClientInitialHandshakeX25519Request
    public let profile: ContractHttpSshStartupProfile
    public let requestedAesEngine: ContractAesEngineKind
    public let aesBackendHint: String

    public init(
        handshake: ContractSshClientInitialHandshakeX25519Request,
        profile!: ContractHttpSshStartupProfile = ContractHttpSshStartupProfile.SshClientLibrary,
        requestedAesEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
        aesBackendHint!: String = ""
    ) {
        this.handshake = handshake
        this.profile = profile
        this.requestedAesEngine = requestedAesEngine
        this.aesBackendHint = aesBackendHint.trimAscii()
    }
}

public class ContractSshServerLibraryStartupBundle {
    public let template: ContractHttpSshStartupProfileTemplate
    public let readiness: ContractHttpSshStartupReadinessReport
    public let handshake: ContractSshServerInitialHandshakeResult
    public let runtime: ContractSshServerRuntime

    public init(
        template: ContractHttpSshStartupProfileTemplate,
        readiness: ContractHttpSshStartupReadinessReport,
        handshake: ContractSshServerInitialHandshakeResult,
        runtime: ContractSshServerRuntime
    ) {
        this.template = template
        this.readiness = readiness
        this.handshake = handshake
        this.runtime = runtime
    }
}

public class ContractSshClientLibraryStartupBundle {
    public let template: ContractHttpSshStartupProfileTemplate
    public let readiness: ContractHttpSshStartupReadinessReport
    public let handshake: ContractSshClientInitialHandshakeResult
    public let runtime: ContractSshClientRuntime

    public init(
        template: ContractHttpSshStartupProfileTemplate,
        readiness: ContractHttpSshStartupReadinessReport,
        handshake: ContractSshClientInitialHandshakeResult,
        runtime: ContractSshClientRuntime
    ) {
        this.template = template
        this.readiness = readiness
        this.handshake = handshake
        this.runtime = runtime
    }
}

public class ContractSshServerLibraryStartupOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractSshServerLibraryStartupBundle

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractSshServerLibraryStartupBundle = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH server startup outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "SSH server startup outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractSshClientLibraryStartupOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractSshClientLibraryStartupBundle

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractSshClientLibraryStartupBundle = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH client startup outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "SSH client startup outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractSshTransportPacket {
    public let packetLength: Int64
    public let payload: Array<Byte>
    public let padding: Array<Byte>

    public init(packetLength: Int64, payload: Array<Byte>, padding: Array<Byte>) {
        if (packetLength <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "SSH packet length must be positive")
        }
        this.packetLength = packetLength
        this.payload = payload.clone()
        this.padding = padding.clone()
    }
}

public class ContractSshEncodeTransportPacketRequest {
    public let payload: Array<Byte>
    public let blockSize: Int64
    public let randomPadding: Array<Byte>

    public init(
        payload: Array<Byte>,
        blockSize!: Int64 = SSH_DEFAULT_PACKET_BLOCK_SIZE,
        randomPadding!: Array<Byte> = []
    ) {
        this.payload = payload.clone()
        this.blockSize = blockSize
        this.randomPadding = randomPadding.clone()
    }
}

public class ContractSshDecodeTransportPacketRequest {
    public let encodedPacket: Array<Byte>
    public let blockSize: Int64

    public init(
        encodedPacket: Array<Byte>,
        blockSize!: Int64 = SSH_DEFAULT_PACKET_BLOCK_SIZE
    ) {
        this.encodedPacket = encodedPacket.clone()
        this.blockSize = blockSize
    }
}

public class ContractSshTransportChannel {
    let _coordinator: SshHandshakeCoordinator

    public init(coordinator: SshHandshakeCoordinator) {
        if (!coordinator.isActive) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH transport channel requires an active handshake coordinator"
            )
        }
        this._coordinator = coordinator
    }

    public prop writeSequence: Int64 {
        get() {
            try {
                _coordinator.writeSequence
            } catch (e: CryptoException) {
                throw ContractException(
                    mapCryptoErrorForOperation(e, "ssh"),
                    "SSH write sequence is unavailable: ${e.message}"
                )
            }
        }
    }

    public prop readSequence: Int64 {
        get() {
            try {
                _coordinator.readSequence
            } catch (e: CryptoException) {
                throw ContractException(
                    mapCryptoErrorForOperation(e, "ssh"),
                    "SSH read sequence is unavailable: ${e.message}"
                )
            }
        }
    }

    public func sessionId(): Array<Byte> {
        try {
            _coordinator.sessionId()
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "ssh"),
                "SSH session id is unavailable: ${e.message}"
            )
        }
    }

    public func resetTransportCounters(): Unit {
        try {
            _coordinator.resetTransportCounters()
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "ssh"),
                "SSH transport counter reset failed: ${e.message}"
            )
        }
    }

    public func seal(payload: Array<Byte>, randomPadding!: Array<Byte> = []): Array<Byte> {
        try {
            _coordinator.seal(payload, randomPadding: randomPadding)
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "ssh"),
                "SSH packet seal failed: ${e.message}"
            )
        }
    }

    public func open(encodedPacket: Array<Byte>): ContractSshTransportPacket {
        try {
            contractFromSshTransportPacket(_coordinator.open(encodedPacket))
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "ssh"),
                "SSH packet open failed: ${e.message}"
            )
        }
    }
}

public class ContractTlsHttpNegotiationPolicy {
    public let requireServerName: Bool
    public let allowedServerNames: Array<String>
    public let alpnPreference: Array<String>

    public init(
        requireServerName!: Bool = true,
        allowedServerNames!: Array<String> = [],
        alpnPreference!: Array<String> = []
    ) {
        this.requireServerName = requireServerName
        this.allowedServerNames = allowedServerNames.clone()
        this.alpnPreference = alpnPreference.clone()
    }
}

public func contractValidateTlsHttpNegotiationPolicy(
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractTlsHttpNegotiationPolicyValidationResult {
    try {
        let normalized = contractToTlsHttpNegotiationPolicy(policy)
        ContractTlsHttpNegotiationPolicyValidationResult(
            normalized.requireServerName,
            normalized.allowedServerNames,
            normalized.alpnPreference
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS HTTP negotiation policy validation failed: ${e.message}"
        )
    }
}

public func contractTryValidateTlsHttpNegotiationPolicy(
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractTlsHttpNegotiationPolicyValidationOutcome {
    try {
        let result = contractValidateTlsHttpNegotiationPolicy(policy: policy)
        ContractTlsHttpNegotiationPolicyValidationOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractTlsHttpNegotiationPolicyValidationOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public enum ContractTls12KeyExchange <: Equatable<ContractTls12KeyExchange> & ToString {
    | Rsa
    | EcdheP256
    | EcdheP384

    public operator func ==(right: ContractTls12KeyExchange): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractTls12KeyExchange): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Rsa => 0
            case EcdheP256 => 1
            case EcdheP384 => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Rsa => "TLS12-RSA"
            case EcdheP256 => "TLS12-ECDHE-P256"
            case EcdheP384 => "TLS12-ECDHE-P384"
        }
    }
}

public class ContractTls12ClientHello {
    public let encodedClientHello: Array<Byte>
    public let clientRandom: Array<Byte>

    public init(encodedClientHello: Array<Byte>, clientRandom: Array<Byte>) {
        if (encodedClientHello.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 ClientHello must not be empty")
        }
        if (clientRandom.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 client random must be 32 bytes")
        }
        this.encodedClientHello = encodedClientHello.clone()
        this.clientRandom = clientRandom.clone()
    }
}

public class ContractTls12ServerHello {
    public let encodedServerHello: Array<Byte>
    public let serverRandom: Array<Byte>

    public init(encodedServerHello: Array<Byte>, serverRandom: Array<Byte>) {
        if (encodedServerHello.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 ServerHello must not be empty")
        }
        if (serverRandom.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 server random must be 32 bytes")
        }
        this.encodedServerHello = encodedServerHello.clone()
        this.serverRandom = serverRandom.clone()
    }
}

public class ContractTls12RsaClientKeyExchange {
    public let encodedClientKeyExchange: Array<Byte>
    public let preMasterSecret: Array<Byte>

    public init(encodedClientKeyExchange: Array<Byte>, preMasterSecret: Array<Byte>) {
        if (encodedClientKeyExchange.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 RSA ClientKeyExchange must not be empty")
        }
        if (preMasterSecret.size != 48) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 RSA pre-master secret must be 48 bytes")
        }
        this.encodedClientKeyExchange = encodedClientKeyExchange.clone()
        this.preMasterSecret = preMasterSecret.clone()
    }
}

public class ContractTls12EcdheServerKeyExchange {
    public let encodedServerKeyExchange: Array<Byte>
    public let serverPrivateScalar: Array<Byte>

    public init(encodedServerKeyExchange: Array<Byte>, serverPrivateScalar: Array<Byte>) {
        if (encodedServerKeyExchange.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 ECDHE ServerKeyExchange must not be empty")
        }
        if (serverPrivateScalar.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 ECDHE server private scalar must not be empty")
        }
        this.encodedServerKeyExchange = encodedServerKeyExchange.clone()
        this.serverPrivateScalar = serverPrivateScalar.clone()
    }
}

public class ContractTls12EcdheClientKeyExchange {
    public let encodedClientKeyExchange: Array<Byte>
    public let clientPrivateScalar: Array<Byte>

    public init(encodedClientKeyExchange: Array<Byte>, clientPrivateScalar: Array<Byte>) {
        if (encodedClientKeyExchange.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 ECDHE ClientKeyExchange must not be empty")
        }
        if (clientPrivateScalar.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 ECDHE client private scalar must not be empty")
        }
        this.encodedClientKeyExchange = encodedClientKeyExchange.clone()
        this.clientPrivateScalar = clientPrivateScalar.clone()
    }
}

public class ContractTls12HandshakeSecrets {
    public let masterSecret: Array<Byte>
    public let clientWriteKey: Array<Byte>
    public let clientWriteIv: Array<Byte>
    public let serverWriteKey: Array<Byte>
    public let serverWriteIv: Array<Byte>

    public init(
        masterSecret: Array<Byte>,
        clientWriteKey: Array<Byte>,
        clientWriteIv: Array<Byte>,
        serverWriteKey: Array<Byte>,
        serverWriteIv: Array<Byte>
    ) {
        if (
            masterSecret.size == 0 ||
            clientWriteKey.size == 0 ||
            clientWriteIv.size == 0 ||
            serverWriteKey.size == 0 ||
            serverWriteIv.size == 0
        ) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 handshake secrets must not be empty")
        }
        this.masterSecret = masterSecret.clone()
        this.clientWriteKey = clientWriteKey.clone()
        this.clientWriteIv = clientWriteIv.clone()
        this.serverWriteKey = serverWriteKey.clone()
        this.serverWriteIv = serverWriteIv.clone()
    }
}

public class ContractTls12HttpClientHelloRequest {
    public let keyExchange: ContractTls12KeyExchange
    public let sessionId: Array<Byte>
    public let serverName: String
    public let alpnProtocols: Array<String>
    public let requestOcspStapling: Bool

    public init(
        keyExchange: ContractTls12KeyExchange,
        sessionId!: Array<Byte> = [],
        serverName!: String = "",
        alpnProtocols!: Array<String> = [],
        requestOcspStapling!: Bool = false
    ) {
        this.keyExchange = keyExchange
        this.sessionId = sessionId.clone()
        this.serverName = serverName
        this.alpnProtocols = alpnProtocols.clone()
        this.requestOcspStapling = requestOcspStapling
    }
}

public class ContractTls12HttpServerHelloRequest {
    public let encodedClientHello: Array<Byte>
    public let keyExchange: ContractTls12KeyExchange

    public init(
        encodedClientHello: Array<Byte>,
        keyExchange: ContractTls12KeyExchange
    ) {
        if (encodedClientHello.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.2 HTTP ServerHello request encoded ClientHello must not be empty"
            )
        }
        this.encodedClientHello = encodedClientHello.clone()
        this.keyExchange = keyExchange
    }
}

public class ContractTls12CertificateHandshakeFromPemChainRequest {
    public let certChainPemBundle: String

    public init(certChainPemBundle: String) {
        if (certChainPemBundle.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.2 certificate handshake request PEM bundle must not be empty"
            )
        }
        this.certChainPemBundle = certChainPemBundle
    }
}

public class ContractTls12VerifyCertificateHandshakeForHttpRequest {
    public let encodedCertificateHandshake: Array<Byte>
    public let trust: ContractHttpClientTlsTrustRequest

    public init(
        encodedCertificateHandshake: Array<Byte>,
        trust: ContractHttpClientTlsTrustRequest
    ) {
        if (encodedCertificateHandshake.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.2 certificate verify request handshake must not be empty"
            )
        }
        this.encodedCertificateHandshake = encodedCertificateHandshake.clone()
        this.trust = trust
    }
}

public class ContractTls12RsaClientKeyExchangeFromLeafPemRequest {
    public let serverLeafPem: String

    public init(serverLeafPem: String) {
        if (serverLeafPem.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.2 RSA ClientKeyExchange request server leaf certificate must not be empty"
            )
        }
        this.serverLeafPem = serverLeafPem
    }
}

public class ContractTls12ProcessRsaClientKeyExchangeRequest {
    public let serverPrivateKeyPkcs8Pem: String
    public let encodedClientKeyExchange: Array<Byte>

    public init(
        serverPrivateKeyPkcs8Pem: String,
        encodedClientKeyExchange: Array<Byte>
    ) {
        if (
            serverPrivateKeyPkcs8Pem.trimAscii().size == 0 ||
            encodedClientKeyExchange.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.2 RSA ClientKeyExchange process request fields are invalid"
            )
        }
        this.serverPrivateKeyPkcs8Pem = serverPrivateKeyPkcs8Pem
        this.encodedClientKeyExchange = encodedClientKeyExchange.clone()
    }
}

public class ContractTls12DeriveSecretsFromPreMasterRequest {
    public let preMasterSecret: Array<Byte>
    public let clientRandom: Array<Byte>
    public let serverRandom: Array<Byte>
    public let keyLen: Int64
    public let ivLen: Int64

    public init(
        preMasterSecret: Array<Byte>,
        clientRandom: Array<Byte>,
        serverRandom: Array<Byte>,
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12
    ) {
        if (
            preMasterSecret.size == 0 ||
            clientRandom.size != 32 ||
            serverRandom.size != 32 ||
            keyLen <= 0 ||
            ivLen <= 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.2 pre-master secret derivation request fields are invalid"
            )
        }
        this.preMasterSecret = preMasterSecret.clone()
        this.clientRandom = clientRandom.clone()
        this.serverRandom = serverRandom.clone()
        this.keyLen = keyLen
        this.ivLen = ivLen
    }
}

public class ContractTls12EcdheServerKeyExchangeRequest {
    public let keyExchange: ContractTls12KeyExchange
    public let serverPrivateScalar: ?Array<Byte>

    public init(
        keyExchange: ContractTls12KeyExchange,
        serverPrivateScalar!: ?Array<Byte> = None
    ) {
        if (let Some(value) <- serverPrivateScalar) {
            if (value.size == 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS1.2 ECDHE server key exchange request scalar must not be empty"
                )
            }
            this.serverPrivateScalar = Some(value.clone())
        } else {
            this.serverPrivateScalar = None
        }
        this.keyExchange = keyExchange
    }
}

public class ContractTls12EcdheClientKeyExchangeRequest {
    public let keyExchange: ContractTls12KeyExchange
    public let clientPrivateScalar: ?Array<Byte>

    public init(
        keyExchange: ContractTls12KeyExchange,
        clientPrivateScalar!: ?Array<Byte> = None
    ) {
        if (let Some(value) <- clientPrivateScalar) {
            if (value.size == 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS1.2 ECDHE client key exchange request scalar must not be empty"
                )
            }
            this.clientPrivateScalar = Some(value.clone())
        } else {
            this.clientPrivateScalar = None
        }
        this.keyExchange = keyExchange
    }
}

public class ContractTls12DeriveClientSecretsFromEcdheRequest {
    public let keyExchange: ContractTls12KeyExchange
    public let clientPrivateScalar: Array<Byte>
    public let encodedServerKeyExchange: Array<Byte>
    public let clientRandom: Array<Byte>
    public let serverRandom: Array<Byte>
    public let keyLen: Int64
    public let ivLen: Int64

    public init(
        keyExchange: ContractTls12KeyExchange,
        clientPrivateScalar: Array<Byte>,
        encodedServerKeyExchange: Array<Byte>,
        clientRandom: Array<Byte>,
        serverRandom: Array<Byte>,
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12
    ) {
        if (
            clientPrivateScalar.size == 0 ||
            encodedServerKeyExchange.size == 0 ||
            clientRandom.size != 32 ||
            serverRandom.size != 32 ||
            keyLen <= 0 ||
            ivLen <= 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.2 ECDHE client secret derivation request fields are invalid"
            )
        }
        this.keyExchange = keyExchange
        this.clientPrivateScalar = clientPrivateScalar.clone()
        this.encodedServerKeyExchange = encodedServerKeyExchange.clone()
        this.clientRandom = clientRandom.clone()
        this.serverRandom = serverRandom.clone()
        this.keyLen = keyLen
        this.ivLen = ivLen
    }
}

public class ContractTls12DeriveServerSecretsFromEcdheRequest {
    public let keyExchange: ContractTls12KeyExchange
    public let serverPrivateScalar: Array<Byte>
    public let encodedClientKeyExchange: Array<Byte>
    public let clientRandom: Array<Byte>
    public let serverRandom: Array<Byte>
    public let keyLen: Int64
    public let ivLen: Int64

    public init(
        keyExchange: ContractTls12KeyExchange,
        serverPrivateScalar: Array<Byte>,
        encodedClientKeyExchange: Array<Byte>,
        clientRandom: Array<Byte>,
        serverRandom: Array<Byte>,
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12
    ) {
        if (
            serverPrivateScalar.size == 0 ||
            encodedClientKeyExchange.size == 0 ||
            clientRandom.size != 32 ||
            serverRandom.size != 32 ||
            keyLen <= 0 ||
            ivLen <= 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.2 ECDHE server secret derivation request fields are invalid"
            )
        }
        this.keyExchange = keyExchange
        this.serverPrivateScalar = serverPrivateScalar.clone()
        this.encodedClientKeyExchange = encodedClientKeyExchange.clone()
        this.clientRandom = clientRandom.clone()
        this.serverRandom = serverRandom.clone()
        this.keyLen = keyLen
        this.ivLen = ivLen
    }
}

public class ContractTls13HttpClientHelloX25519Request {
    public let serverName: String
    public let alpnProtocols: Array<String>
    public let clientPrivateKey: ?Array<Byte>

    public init(
        serverName: String,
        alpnProtocols!: Array<String> = [],
        clientPrivateKey!: ?Array<Byte> = None
    ) {
        if (serverName.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 HTTP ClientHello request server name must not be empty"
            )
        }
        if (let Some(value) <- clientPrivateKey) {
            if (value.size != 32) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS1.3 HTTP ClientHello request private key must be 32 bytes"
                )
            }
            this.clientPrivateKey = Some(value.clone())
        } else {
            this.clientPrivateKey = None
        }
        this.serverName = serverName.trimAscii()
        this.alpnProtocols = alpnProtocols.clone()
    }
}

public class ContractTls13HttpClientHelloX25519 {
    public let encodedClientHello: Array<Byte>
    public let clientPrivateKey: Array<Byte>
    public let clientPublicKey: Array<Byte>

    public init(
        encodedClientHello: Array<Byte>,
        clientPrivateKey: Array<Byte>,
        clientPublicKey: Array<Byte>
    ) {
        if (encodedClientHello.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 encoded ClientHello must not be empty")
        }
        if (clientPrivateKey.size != 32 || clientPublicKey.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 X25519 private/public key must be 32 bytes")
        }
        this.encodedClientHello = encodedClientHello.clone()
        this.clientPrivateKey = clientPrivateKey.clone()
        this.clientPublicKey = clientPublicKey.clone()
    }
}

public class ContractTls13HttpServerFlightX25519Request {
    public let encodedClientHello: Array<Byte>
    public let serverKeyExchangePrivate: Array<Byte>
    public let certChainPemBundle: String
    public let certificatePrivateKeyPkcs8Pem: String
    public let policy: ContractTlsHttpNegotiationPolicy

    public init(
        encodedClientHello: Array<Byte>,
        serverKeyExchangePrivate: Array<Byte>,
        certChainPemBundle: String,
        certificatePrivateKeyPkcs8Pem: String,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ) {
        if (
            encodedClientHello.size == 0 ||
            serverKeyExchangePrivate.size != 32 ||
            certChainPemBundle.trimAscii().size == 0 ||
            certificatePrivateKeyPkcs8Pem.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 HTTP server flight request fields are invalid"
            )
        }
        this.encodedClientHello = encodedClientHello.clone()
        this.serverKeyExchangePrivate = serverKeyExchangePrivate.clone()
        this.certChainPemBundle = certChainPemBundle
        this.certificatePrivateKeyPkcs8Pem = certificatePrivateKeyPkcs8Pem
        this.policy = ContractTlsHttpNegotiationPolicy(
            requireServerName: policy.requireServerName,
            allowedServerNames: policy.allowedServerNames,
            alpnPreference: policy.alpnPreference
        )
    }
}

public class ContractTls13HttpServerFlight {
    public let serverHello: Array<Byte>
    public let encryptedExtensions: Array<Byte>
    public let certificateHandshake: Array<Byte>
    public let certificateVerifyHandshake: Array<Byte>
    public let finishedHandshake: Array<Byte>
    public let transcriptHash: Array<Byte>
    public let selectedAlpn: String
    public let requestedServerName: String
    public let acknowledgedServerName: Bool

    public init(
        serverHello: Array<Byte>,
        encryptedExtensions: Array<Byte>,
        certificateHandshake: Array<Byte>,
        certificateVerifyHandshake: Array<Byte>,
        finishedHandshake: Array<Byte>,
        transcriptHash: Array<Byte>,
        selectedAlpn!: String = "",
        requestedServerName!: String = "",
        acknowledgedServerName!: Bool = false
    ) {
        if (
            serverHello.size == 0 ||
            encryptedExtensions.size == 0 ||
            certificateHandshake.size == 0 ||
            certificateVerifyHandshake.size == 0 ||
            finishedHandshake.size == 0
        ) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 HTTP server flight messages must not be empty")
        }
        if (transcriptHash.size != 32) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 transcript hash must be SHA-256 sized")
        }

        this.serverHello = serverHello.clone()
        this.encryptedExtensions = encryptedExtensions.clone()
        this.certificateHandshake = certificateHandshake.clone()
        this.certificateVerifyHandshake = certificateVerifyHandshake.clone()
        this.finishedHandshake = finishedHandshake.clone()
        this.transcriptHash = transcriptHash.clone()
        this.selectedAlpn = selectedAlpn.trimAscii()
        this.requestedServerName = requestedServerName.trimAscii().toAsciiLower()
        this.acknowledgedServerName = acknowledgedServerName
    }
}

public class ContractTls13HttpVerifyServerFlightX25519Request {
    public let clientHello: ContractTls13HttpClientHelloX25519
    public let serverFlight: ContractTls13HttpServerFlight
    public let trust: ContractHttpClientTlsTrustRequest

    public init(
        clientHello: ContractTls13HttpClientHelloX25519,
        serverFlight: ContractTls13HttpServerFlight,
        trust: ContractHttpClientTlsTrustRequest
    ) {
        this.clientHello = clientHello
        this.serverFlight = serverFlight
        this.trust = trust
    }
}

public class ContractTls13ApplicationKeyMaterial {
    public let clientWriteKey: Array<Byte>
    public let clientWriteIv: Array<Byte>
    public let serverWriteKey: Array<Byte>
    public let serverWriteIv: Array<Byte>

    public init(
        clientWriteKey: Array<Byte>,
        clientWriteIv: Array<Byte>,
        serverWriteKey: Array<Byte>,
        serverWriteIv: Array<Byte>
    ) {
        if (
            clientWriteKey.size == 0 ||
            clientWriteIv.size == 0 ||
            serverWriteKey.size == 0 ||
            serverWriteIv.size == 0
        ) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 key material must not be empty")
        }
        this.clientWriteKey = clientWriteKey.clone()
        this.clientWriteIv = clientWriteIv.clone()
        this.serverWriteKey = serverWriteKey.clone()
        this.serverWriteIv = serverWriteIv.clone()
    }
}

public class ContractTls13CipherBinding {
    public let cipherSuite: Int64
    public let cipherSuiteName: String
    public let algorithm: ContractAeadAlgorithm
    public let keyLen: Int64
    public let ivLen: Int64

    public init(
        cipherSuite: Int64,
        cipherSuiteName: String,
        algorithm: ContractAeadAlgorithm,
        keyLen: Int64,
        ivLen: Int64
    ) {
        if (cipherSuite < 0 || cipherSuite > 65535) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 cipher suite must be uint16")
        }
        if (cipherSuiteName.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 cipher suite name must not be empty")
        }
        if (keyLen <= 0 || ivLen <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 cipher binding key/iv lengths must be > 0")
        }
        this.cipherSuite = cipherSuite
        this.cipherSuiteName = cipherSuiteName.trimAscii()
        this.algorithm = algorithm
        this.keyLen = keyLen
        this.ivLen = ivLen
    }
}

public class ContractTls13KeyUpdatePlan {
    public let encodedKeyUpdate: Array<Byte>
    public let requestPeerUpdate: Bool
    public let nextTrafficSecret: Array<Byte>
    public let nextWriteKey: Array<Byte>
    public let nextWriteIv: Array<Byte>

    public init(
        encodedKeyUpdate: Array<Byte>,
        requestPeerUpdate: Bool,
        nextTrafficSecret: Array<Byte>,
        nextWriteKey: Array<Byte>,
        nextWriteIv: Array<Byte>
    ) {
        if (encodedKeyUpdate.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 KeyUpdate handshake must not be empty")
        }
        if (nextTrafficSecret.size == 0 || nextWriteKey.size == 0 || nextWriteIv.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 key update plan traffic secret and key material must not be empty"
            )
        }
        this.encodedKeyUpdate = encodedKeyUpdate.clone()
        this.requestPeerUpdate = requestPeerUpdate
        this.nextTrafficSecret = nextTrafficSecret.clone()
        this.nextWriteKey = nextWriteKey.clone()
        this.nextWriteIv = nextWriteIv.clone()
    }
}

public class ContractTls13ExporterMasterSecretRequest {
    public let masterSecret: Array<Byte>
    public let transcriptHash: Array<Byte>

    public init(masterSecret: Array<Byte>, transcriptHash: Array<Byte>) {
        if (masterSecret.size == 0 || transcriptHash.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 exporter master secret request fields must not be empty"
            )
        }
        this.masterSecret = masterSecret.clone()
        this.transcriptHash = transcriptHash.clone()
    }
}

public class ContractTls13ExportKeyingMaterialRequest {
    public let exporterMasterSecret: Array<Byte>
    public let exporterLabel: String
    public let context: Array<Byte>
    public let outputLen: Int64

    public init(
        exporterMasterSecret: Array<Byte>,
        exporterLabel: String,
        context!: Array<Byte> = [],
        outputLen!: Int64 = 32
    ) {
        if (exporterMasterSecret.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 export keying material request exporter master secret must not be empty"
            )
        }
        if (exporterLabel.trimAscii().size == 0 || outputLen <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 export keying material request fields are invalid"
            )
        }
        this.exporterMasterSecret = exporterMasterSecret.clone()
        this.exporterLabel = exporterLabel.trimAscii()
        this.context = context.clone()
        this.outputLen = outputLen
    }
}

public class ContractTls13KeyUpdateRequest {
    public let currentTrafficSecret: Array<Byte>
    public let requestPeerUpdate: Bool
    public let keyLen: Int64
    public let ivLen: Int64

    public init(
        currentTrafficSecret: Array<Byte>,
        requestPeerUpdate!: Bool = false,
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12
    ) {
        if (currentTrafficSecret.size == 0 || keyLen <= 0 || ivLen <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 key update request fields are invalid"
            )
        }
        this.currentTrafficSecret = currentTrafficSecret.clone()
        this.requestPeerUpdate = requestPeerUpdate
        this.keyLen = keyLen
        this.ivLen = ivLen
    }
}

public class ContractTls13PeerKeyUpdateRequest {
    public let currentTrafficSecret: Array<Byte>
    public let encodedKeyUpdate: Array<Byte>
    public let keyLen: Int64
    public let ivLen: Int64

    public init(
        currentTrafficSecret: Array<Byte>,
        encodedKeyUpdate: Array<Byte>,
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12
    ) {
        if (currentTrafficSecret.size == 0 || encodedKeyUpdate.size == 0 || keyLen <= 0 || ivLen <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 peer key update request fields are invalid"
            )
        }
        this.currentTrafficSecret = currentTrafficSecret.clone()
        this.encodedKeyUpdate = encodedKeyUpdate.clone()
        this.keyLen = keyLen
        this.ivLen = ivLen
    }
}

public class ContractTls13PskX25519DerivedSecrets {
    public let cipherBinding: ContractTls13CipherBinding
    public let keyMaterial: ContractTls13ApplicationKeyMaterial
    public let clientAppTrafficSecret: Array<Byte>
    public let serverAppTrafficSecret: Array<Byte>
    public let masterSecret: Array<Byte>

    public init(
        cipherBinding: ContractTls13CipherBinding,
        keyMaterial: ContractTls13ApplicationKeyMaterial,
        clientAppTrafficSecret: Array<Byte>,
        serverAppTrafficSecret: Array<Byte>,
        masterSecret: Array<Byte>
    ) {
        if (clientAppTrafficSecret.size == 0 || serverAppTrafficSecret.size == 0 || masterSecret.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK+X25519 derived secrets must not contain empty traffic/master secret"
            )
        }
        this.cipherBinding = cipherBinding
        this.keyMaterial = keyMaterial
        this.clientAppTrafficSecret = clientAppTrafficSecret.clone()
        this.serverAppTrafficSecret = serverAppTrafficSecret.clone()
        this.masterSecret = masterSecret.clone()
    }
}

public class ContractTls13PskX25519ChannelSet {
    public let secrets: ContractTls13PskX25519DerivedSecrets
    public let clientChannel: ContractTlsRecordChannel
    public let serverChannel: ContractTlsRecordChannel

    public init(
        secrets: ContractTls13PskX25519DerivedSecrets,
        clientChannel: ContractTlsRecordChannel,
        serverChannel: ContractTlsRecordChannel
    ) {
        if (clientChannel.version != ContractTlsVersion.Tls13 || serverChannel.version != ContractTlsVersion.Tls13) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK+X25519 channel set requires TLS1.3 record channels"
            )
        }
        if (clientChannel.algorithm != secrets.cipherBinding.algorithm) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK+X25519 client channel algorithm must match cipher binding"
            )
        }
        if (serverChannel.algorithm != secrets.cipherBinding.algorithm) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK+X25519 server channel algorithm must match cipher binding"
            )
        }
        this.secrets = secrets
        this.clientChannel = clientChannel
        this.serverChannel = serverChannel
    }
}

public class ContractTls13PskX25519TrafficUpdateResult {
    public let encodedKeyUpdate: Array<Byte>
    public let requestPeerUpdate: Bool
    public let channels: ContractTls13PskX25519ChannelSet

    public init(
        encodedKeyUpdate: Array<Byte>,
        requestPeerUpdate: Bool,
        channels: ContractTls13PskX25519ChannelSet
    ) {
        if (encodedKeyUpdate.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK+X25519 KeyUpdate handshake must not be empty"
            )
        }
        this.encodedKeyUpdate = encodedKeyUpdate.clone()
        this.requestPeerUpdate = requestPeerUpdate
        this.channels = channels
    }
}

public class ContractTls13PskX25519PeerUpdateOrchestrationResult {
    public let incomingRequestPeerUpdate: Bool
    public let responseRequired: Bool
    public let encodedResponseKeyUpdate: Array<Byte>
    public let channels: ContractTls13PskX25519ChannelSet

    public init(
        incomingRequestPeerUpdate: Bool,
        responseRequired: Bool,
        encodedResponseKeyUpdate: Array<Byte>,
        channels: ContractTls13PskX25519ChannelSet
    ) {
        if (responseRequired && encodedResponseKeyUpdate.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK+X25519 peer update orchestration requires non-empty response KeyUpdate"
            )
        }
        if (!responseRequired && encodedResponseKeyUpdate.size != 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK+X25519 peer update orchestration response must be empty when not required"
            )
        }
        this.incomingRequestPeerUpdate = incomingRequestPeerUpdate
        this.responseRequired = responseRequired
        this.encodedResponseKeyUpdate = encodedResponseKeyUpdate.clone()
        this.channels = channels
    }
}

public enum ContractTlsVersion <: Equatable<ContractTlsVersion> & ToString {
    | Tls12
    | Tls13

    public operator func ==(right: ContractTlsVersion): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractTlsVersion): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Tls12 => 0
            case Tls13 => 1
        }
    }

    public func toString(): String {
        match (this) {
            case Tls12 => "TLS1.2"
            case Tls13 => "TLS1.3"
        }
    }
}

public enum ContractTlsEndpointRole <: Equatable<ContractTlsEndpointRole> & ToString {
    | Client
    | Server

    public operator func ==(right: ContractTlsEndpointRole): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractTlsEndpointRole): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Client => 0
            case Server => 1
        }
    }

    public func toString(): String {
        match (this) {
            case Client => "CLIENT"
            case Server => "SERVER"
        }
    }
}

public enum ContractTlsRecordContentType <: Equatable<ContractTlsRecordContentType> & ToString {
    | ChangeCipherSpec
    | Alert
    | Handshake
    | ApplicationData

    public operator func ==(right: ContractTlsRecordContentType): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractTlsRecordContentType): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ChangeCipherSpec => 0
            case Alert => 1
            case Handshake => 2
            case ApplicationData => 3
        }
    }

    public func toString(): String {
        match (this) {
            case ChangeCipherSpec => "CHANGE_CIPHER_SPEC"
            case Alert => "ALERT"
            case Handshake => "HANDSHAKE"
            case ApplicationData => "APPLICATION_DATA"
        }
    }
}

public class ContractTlsRecordPlaintext {
    public let version: ContractTlsVersion
    public let contentType: ContractTlsRecordContentType
    public let fragment: Array<Byte>

    public init(
        version: ContractTlsVersion,
        contentType: ContractTlsRecordContentType,
        fragment: Array<Byte>
    ) {
        this.version = version
        this.contentType = contentType
        this.fragment = fragment.clone()
    }
}

public class ContractTlsRecordChannel {
    public let version: ContractTlsVersion
    public let algorithm: ContractAeadAlgorithm

    let _aesLayer: ?TlsAeadRecordLayer
    let _chachaLayer: ?TlsChacha20Poly1305RecordLayer

    public init(
        version: ContractTlsVersion,
        algorithm: ContractAeadAlgorithm,
        aesLayer!: ?TlsAeadRecordLayer = None,
        chachaLayer!: ?TlsChacha20Poly1305RecordLayer = None
    ) {
        match (algorithm) {
            case ContractAeadAlgorithm.Aes256Gcm =>
                if (let Some(_layer) <- aesLayer) {
                    if (let Some(_unexpected) <- chachaLayer) {
                        throw ContractException(
                            ContractErrorCode.BadInput,
                            "TLS record channel for AES must not carry ChaCha layer"
                        )
                    }
                } else {
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "TLS record channel for AES requires AES layer"
                    )
                }
            case ContractAeadAlgorithm.Chacha20Poly1305 =>
                if (let Some(_layer) <- chachaLayer) {
                    if (let Some(_unexpected) <- aesLayer) {
                        throw ContractException(
                            ContractErrorCode.BadInput,
                            "TLS record channel for ChaCha20-Poly1305 must not carry AES layer"
                        )
                    }
                } else {
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "TLS record channel for ChaCha20-Poly1305 requires ChaCha layer"
                    )
                }
        }

        this.version = version
        this.algorithm = algorithm
        this._aesLayer = aesLayer
        this._chachaLayer = chachaLayer
    }

    public prop writeSequence: Int64 {
        get() {
            match (algorithm) {
                case ContractAeadAlgorithm.Aes256Gcm =>
                    if (let Some(layer) <- _aesLayer) {
                        return layer.writeSequence
                    }
                    throw ContractException(ContractErrorCode.InternalError, "TLS AES record layer is unavailable")
                case ContractAeadAlgorithm.Chacha20Poly1305 =>
                    if (let Some(layer) <- _chachaLayer) {
                        return layer.writeSequence
                    }
                    throw ContractException(ContractErrorCode.InternalError, "TLS ChaCha20 record layer is unavailable")
            }
        }
    }

    public prop readSequence: Int64 {
        get() {
            match (algorithm) {
                case ContractAeadAlgorithm.Aes256Gcm =>
                    if (let Some(layer) <- _aesLayer) {
                        return layer.readSequence
                    }
                    throw ContractException(ContractErrorCode.InternalError, "TLS AES record layer is unavailable")
                case ContractAeadAlgorithm.Chacha20Poly1305 =>
                    if (let Some(layer) <- _chachaLayer) {
                        return layer.readSequence
                    }
                    throw ContractException(ContractErrorCode.InternalError, "TLS ChaCha20 record layer is unavailable")
            }
        }
    }

    public func resetSequences(): Unit {
        match (algorithm) {
            case ContractAeadAlgorithm.Aes256Gcm =>
                if (let Some(layer) <- _aesLayer) {
                    layer.resetSequences()
                    return
                }
                throw ContractException(ContractErrorCode.InternalError, "TLS AES record layer is unavailable")
            case ContractAeadAlgorithm.Chacha20Poly1305 =>
                if (let Some(layer) <- _chachaLayer) {
                    layer.resetSequences()
                    return
                }
                throw ContractException(ContractErrorCode.InternalError, "TLS ChaCha20 record layer is unavailable")
        }
    }

    public func seal(
        contentType: ContractTlsRecordContentType,
        plaintext: Array<Byte>
    ): Array<Byte> {
        try {
            match (algorithm) {
                case ContractAeadAlgorithm.Aes256Gcm =>
                    if (let Some(layer) <- _aesLayer) {
                        return layer.seal(contractToTlsContentType(contentType), plaintext)
                    }
                    throw ContractException(ContractErrorCode.InternalError, "TLS AES record layer is unavailable")
                case ContractAeadAlgorithm.Chacha20Poly1305 =>
                    if (let Some(layer) <- _chachaLayer) {
                        return layer.seal(contractToTlsContentType(contentType), plaintext)
                    }
                    throw ContractException(ContractErrorCode.InternalError, "TLS ChaCha20 record layer is unavailable")
            }
        } catch (e: ContractException) {
            throw e
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS record seal failed: ${e.message}"
            )
        }
    }

    public func open(encodedRecord: Array<Byte>): ContractTlsRecordPlaintext {
        try {
            let plain = match (algorithm) {
                case ContractAeadAlgorithm.Aes256Gcm =>
                    if (let Some(layer) <- _aesLayer) {
                        layer.open(encodedRecord)
                    } else {
                        throw ContractException(ContractErrorCode.InternalError, "TLS AES record layer is unavailable")
                    }
                case ContractAeadAlgorithm.Chacha20Poly1305 =>
                    if (let Some(layer) <- _chachaLayer) {
                        layer.open(encodedRecord)
                    } else {
                        throw ContractException(ContractErrorCode.InternalError, "TLS ChaCha20 record layer is unavailable")
                    }
            }
            ContractTlsRecordPlaintext(
                contractFromTlsVersion(plain.version),
                contractFromTlsContentType(plain.contentType),
                plain.fragment
            )
        } catch (e: ContractException) {
            throw e
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS record open failed: ${e.message}"
            )
        }
    }

    public func sealApplicationData(plaintext: Array<Byte>): Array<Byte> {
        seal(ContractTlsRecordContentType.ApplicationData, plaintext)
    }

    public func openApplicationData(encodedRecord: Array<Byte>): Array<Byte> {
        let plain = open(encodedRecord)
        if (plain.contentType != ContractTlsRecordContentType.ApplicationData) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS record content type is not APPLICATION_DATA"
            )
        }
        plain.fragment
    }

    public func sealFragments(
        contentType: ContractTlsRecordContentType,
        plaintext: Array<Byte>,
        maxFragmentLen!: Int64 = 16384
    ): Array<Array<Byte>> {
        try {
            match (algorithm) {
                case ContractAeadAlgorithm.Aes256Gcm =>
                    if (let Some(layer) <- _aesLayer) {
                        return layer.sealFragments(
                            contractToTlsContentType(contentType),
                            plaintext,
                            maxFragmentLen: maxFragmentLen
                        )
                    }
                    throw ContractException(ContractErrorCode.InternalError, "TLS AES record layer is unavailable")
                case ContractAeadAlgorithm.Chacha20Poly1305 =>
                    if (let Some(layer) <- _chachaLayer) {
                        return layer.sealFragments(
                            contractToTlsContentType(contentType),
                            plaintext,
                            maxFragmentLen: maxFragmentLen
                        )
                    }
                    throw ContractException(ContractErrorCode.InternalError, "TLS ChaCha20 record layer is unavailable")
            }
        } catch (e: ContractException) {
            throw e
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS record fragment sealing failed: ${e.message}"
            )
        }
    }

    public func openAndReassemble(
        encodedRecords: Array<Array<Byte>>,
        expectedContentType!: ContractTlsRecordContentType = ContractTlsRecordContentType.ApplicationData
    ): Array<Byte> {
        try {
            match (algorithm) {
                case ContractAeadAlgorithm.Aes256Gcm =>
                    if (let Some(layer) <- _aesLayer) {
                        return layer.openAndReassemble(
                            encodedRecords,
                            expectedContentType: contractToTlsContentType(expectedContentType)
                        )
                    }
                    throw ContractException(ContractErrorCode.InternalError, "TLS AES record layer is unavailable")
                case ContractAeadAlgorithm.Chacha20Poly1305 =>
                    if (let Some(layer) <- _chachaLayer) {
                        return layer.openAndReassemble(
                            encodedRecords,
                            expectedContentType: contractToTlsContentType(expectedContentType)
                        )
                    }
                    throw ContractException(ContractErrorCode.InternalError, "TLS ChaCha20 record layer is unavailable")
            }
        } catch (e: ContractException) {
            throw e
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS record fragment open failed: ${e.message}"
            )
        }
    }

    public func sendCloseNotify(): Array<Byte> {
        seal(
            ContractTlsRecordContentType.Alert,
            contractTlsEncodeAlertPayload(
                ContractTlsAlertLevel.AlertWarning,
                ContractTlsAlertDescription.AlertCloseNotify
            )
        )
    }

    public func openAlert(encodedRecord: Array<Byte>): ContractTlsAlertMessage {
        let plain = open(encodedRecord)
        if (plain.contentType != ContractTlsRecordContentType.Alert) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS record content type is not ALERT"
            )
        }
        contractTlsDecodeAlertPayload(plain.fragment)
    }
}

public class ContractTls12RecordChannelRequest {
    public let secrets: ContractTls12HandshakeSecrets
    public let algorithm: ContractAeadAlgorithm

    public init(
        secrets: ContractTls12HandshakeSecrets,
        algorithm!: ContractAeadAlgorithm = ContractAeadAlgorithm.Aes256Gcm
    ) {
        this.secrets = secrets
        this.algorithm = algorithm
    }
}

public class ContractTls13RecordChannelRequest {
    public let keyMaterial: ContractTls13ApplicationKeyMaterial
    public let algorithm: ContractAeadAlgorithm

    public init(
        keyMaterial: ContractTls13ApplicationKeyMaterial,
        algorithm!: ContractAeadAlgorithm = ContractAeadAlgorithm.Aes256Gcm
    ) {
        this.keyMaterial = keyMaterial
        this.algorithm = algorithm
    }
}

public class ContractTls13PskClientHelloFromSessionCacheRequest {
    public let cache: ContractTlsSessionCache
    public let identity: ContractTlsSessionIdentity
    public let nowUnixSeconds: Int64
    public let sessionId: Array<Byte>

    public init(
        cache: ContractTlsSessionCache,
        identity: ContractTlsSessionIdentity,
        nowUnixSeconds!: Int64 = 0,
        sessionId!: Array<Byte> = []
    ) {
        this.cache = cache
        this.identity = identity
        this.nowUnixSeconds = nowUnixSeconds
        this.sessionId = sessionId.clone()
    }
}

public class ContractTls13PskClientHelloFromSessionCacheWithPolicyRequest {
    public let cache: ContractTlsSessionCache
    public let identity: ContractTlsSessionIdentity
    public let policy: ContractTls13SessionTicketPolicy
    public let nowUnixSeconds: Int64
    public let sessionId: Array<Byte>

    public init(
        cache: ContractTlsSessionCache,
        identity: ContractTlsSessionIdentity,
        policy!: ContractTls13SessionTicketPolicy = ContractTls13SessionTicketPolicy(),
        nowUnixSeconds!: Int64 = 0,
        sessionId!: Array<Byte> = []
    ) {
        this.cache = cache
        this.identity = identity
        this.policy = ContractTls13SessionTicketPolicy(
            minRemainingTtlSeconds: policy.minRemainingTtlSeconds,
            renewBeforeExpirySeconds: policy.renewBeforeExpirySeconds,
            requiredServerName: policy.requiredServerName,
            requiredAlpnProtocol: policy.requiredAlpnProtocol
        )
        this.nowUnixSeconds = nowUnixSeconds
        this.sessionId = sessionId.clone()
    }
}

public enum ContractTlsAlertLevel <: Equatable<ContractTlsAlertLevel> & ToString {
    | AlertWarning
    | AlertFatal

    public operator func ==(right: ContractTlsAlertLevel): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractTlsAlertLevel): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case AlertWarning => 0
            case AlertFatal => 1
        }
    }

    public func toString(): String {
        match (this) {
            case AlertWarning => "WARNING"
            case AlertFatal => "FATAL"
        }
    }
}

public enum ContractTlsAlertDescription <: Equatable<ContractTlsAlertDescription> & ToString {
    | AlertCloseNotify
    | AlertUnexpectedMessage
    | AlertBadRecordMac
    | AlertDecryptionFailedReserved
    | AlertRecordOverflow
    | AlertHandshakeFailure
    | AlertBadCertificate
    | AlertUnsupportedCertificate
    | AlertCertificateRevoked
    | AlertCertificateExpired
    | AlertCertificateUnknown
    | AlertIllegalParameter
    | AlertUnknownCa
    | AlertAccessDenied
    | AlertDecodeError
    | AlertDecryptError
    | AlertProtocolVersion
    | AlertInsufficientSecurity
    | AlertInternalError
    | AlertUserCanceled
    | AlertMissingExtension
    | AlertUnsupportedExtension
    | AlertUnrecognizedName
    | AlertBadCertificateStatusResponse
    | AlertUnknownPskIdentity
    | AlertCertificateRequired
    | AlertNoApplicationProtocol

    public operator func ==(right: ContractTlsAlertDescription): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractTlsAlertDescription): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case AlertCloseNotify => 0
            case AlertUnexpectedMessage => 1
            case AlertBadRecordMac => 2
            case AlertDecryptionFailedReserved => 3
            case AlertRecordOverflow => 4
            case AlertHandshakeFailure => 5
            case AlertBadCertificate => 6
            case AlertUnsupportedCertificate => 7
            case AlertCertificateRevoked => 8
            case AlertCertificateExpired => 9
            case AlertCertificateUnknown => 10
            case AlertIllegalParameter => 11
            case AlertUnknownCa => 12
            case AlertAccessDenied => 13
            case AlertDecodeError => 14
            case AlertDecryptError => 15
            case AlertProtocolVersion => 16
            case AlertInsufficientSecurity => 17
            case AlertInternalError => 18
            case AlertUserCanceled => 19
            case AlertMissingExtension => 20
            case AlertUnsupportedExtension => 21
            case AlertUnrecognizedName => 22
            case AlertBadCertificateStatusResponse => 23
            case AlertUnknownPskIdentity => 24
            case AlertCertificateRequired => 25
            case AlertNoApplicationProtocol => 26
        }
    }

    public func toString(): String {
        match (this) {
            case AlertCloseNotify => "CLOSE_NOTIFY"
            case AlertUnexpectedMessage => "UNEXPECTED_MESSAGE"
            case AlertBadRecordMac => "BAD_RECORD_MAC"
            case AlertDecryptionFailedReserved => "DECRYPTION_FAILED_RESERVED"
            case AlertRecordOverflow => "RECORD_OVERFLOW"
            case AlertHandshakeFailure => "HANDSHAKE_FAILURE"
            case AlertBadCertificate => "BAD_CERTIFICATE"
            case AlertUnsupportedCertificate => "UNSUPPORTED_CERTIFICATE"
            case AlertCertificateRevoked => "CERTIFICATE_REVOKED"
            case AlertCertificateExpired => "CERTIFICATE_EXPIRED"
            case AlertCertificateUnknown => "CERTIFICATE_UNKNOWN"
            case AlertIllegalParameter => "ILLEGAL_PARAMETER"
            case AlertUnknownCa => "UNKNOWN_CA"
            case AlertAccessDenied => "ACCESS_DENIED"
            case AlertDecodeError => "DECODE_ERROR"
            case AlertDecryptError => "DECRYPT_ERROR"
            case AlertProtocolVersion => "PROTOCOL_VERSION"
            case AlertInsufficientSecurity => "INSUFFICIENT_SECURITY"
            case AlertInternalError => "INTERNAL_ERROR"
            case AlertUserCanceled => "USER_CANCELED"
            case AlertMissingExtension => "MISSING_EXTENSION"
            case AlertUnsupportedExtension => "UNSUPPORTED_EXTENSION"
            case AlertUnrecognizedName => "UNRECOGNIZED_NAME"
            case AlertBadCertificateStatusResponse => "BAD_CERTIFICATE_STATUS_RESPONSE"
            case AlertUnknownPskIdentity => "UNKNOWN_PSK_IDENTITY"
            case AlertCertificateRequired => "CERTIFICATE_REQUIRED"
            case AlertNoApplicationProtocol => "NO_APPLICATION_PROTOCOL"
        }
    }
}

public class ContractTlsAlertMessage {
    public let level: ContractTlsAlertLevel
    public let description: ContractTlsAlertDescription

    public init(level: ContractTlsAlertLevel, description: ContractTlsAlertDescription) {
        this.level = level
        this.description = description
    }

    public prop isCloseNotify: Bool {
        get() {
            description == ContractTlsAlertDescription.AlertCloseNotify
        }
    }
}

public class ContractTlsAlertPayloadRequest {
    public let level: ContractTlsAlertLevel
    public let description: ContractTlsAlertDescription

    public init(level: ContractTlsAlertLevel, description: ContractTlsAlertDescription) {
        this.level = level
        this.description = description
    }
}

public class ContractTlsAlertPayloadDecodeRequest {
    public let encodedAlert: Array<Byte>

    public init(encodedAlert: Array<Byte>) {
        if (encodedAlert.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS alert payload decode request must not be empty")
        }
        this.encodedAlert = encodedAlert.clone()
    }
}

public class ContractTlsPlaintextRecordRequest {
    public let version: ContractTlsVersion
    public let contentType: ContractTlsRecordContentType
    public let payload: Array<Byte>

    public init(
        version: ContractTlsVersion,
        contentType: ContractTlsRecordContentType,
        payload: Array<Byte>
    ) {
        this.version = version
        this.contentType = contentType
        this.payload = payload.clone()
    }
}

public class ContractTlsAlertRecordRequest {
    public let version: ContractTlsVersion
    public let level: ContractTlsAlertLevel
    public let description: ContractTlsAlertDescription

    public init(
        version: ContractTlsVersion,
        level: ContractTlsAlertLevel,
        description: ContractTlsAlertDescription
    ) {
        this.version = version
        this.level = level
        this.description = description
    }
}

public class ContractTlsAlertRecordDecodeRequest {
    public let encodedRecord: Array<Byte>

    public init(encodedRecord: Array<Byte>) {
        if (encodedRecord.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS alert record decode request must not be empty")
        }
        this.encodedRecord = encodedRecord.clone()
    }
}

public class ContractTlsAlertDecodeOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractTlsAlertMessage

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractTlsAlertMessage = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS alert decode outcome message must not be empty")
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "TLS alert decode outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "TLS alert decode outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "TLS alert decode outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "TLS alert decode outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "TLS alert decode outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "TLS alert decode outcome result must be empty when ok is false"
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

public class ContractTlsSessionIdentity {
    public let version: ContractTlsVersion
    public let resumptionId: Array<Byte>
    public let serverName: String
    public let alpnProtocol: String

    public init(
        version: ContractTlsVersion,
        resumptionId: Array<Byte>,
        serverName!: String = "",
        alpnProtocol!: String = ""
    ) {
        if (resumptionId.size == 0 || resumptionId.size > 65535) {
            throw ContractException(ContractErrorCode.BadInput, "TLS session resumption id length is invalid")
        }
        this.version = version
        this.resumptionId = resumptionId.clone()
        this.serverName = serverName.trimAscii().toAsciiLower()
        this.alpnProtocol = alpnProtocol.trimAscii().toAsciiLower()
    }
}

public class ContractTlsSessionTicket {
    public let version: Int64
    public let identity: ContractTlsSessionIdentity
    public let secret: Array<Byte>
    public let nonce: Array<Byte>
    public let issuedAtUnixSeconds: Int64
    public let expiresAtUnixSeconds: Int64

    public init(
        version: Int64,
        identity: ContractTlsSessionIdentity,
        secret: Array<Byte>,
        nonce: Array<Byte>,
        issuedAtUnixSeconds: Int64,
        expiresAtUnixSeconds: Int64
    ) {
        if (version <= 0 || version > 255) {
            throw ContractException(ContractErrorCode.BadInput, "TLS session ticket version is invalid")
        }
        if (secret.size == 0 || secret.size > 65535) {
            throw ContractException(ContractErrorCode.BadInput, "TLS session ticket secret length is invalid")
        }
        if (issuedAtUnixSeconds <= 0 || expiresAtUnixSeconds <= issuedAtUnixSeconds) {
            throw ContractException(ContractErrorCode.BadInput, "TLS session ticket validity window is invalid")
        }
        this.version = version
        this.identity = identity
        this.secret = secret.clone()
        this.nonce = nonce.clone()
        this.issuedAtUnixSeconds = issuedAtUnixSeconds
        this.expiresAtUnixSeconds = expiresAtUnixSeconds
    }
}

public class ContractTls13SessionTicketPolicy {
    public let minRemainingTtlSeconds: Int64
    public let renewBeforeExpirySeconds: Int64
    public let requiredServerName: String
    public let requiredAlpnProtocol: String

    public init(
        minRemainingTtlSeconds!: Int64 = 1,
        renewBeforeExpirySeconds!: Int64 = 300,
        requiredServerName!: String = "",
        requiredAlpnProtocol!: String = ""
    ) {
        if (minRemainingTtlSeconds < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 ticket min remaining ttl must be >= 0"
            )
        }
        if (renewBeforeExpirySeconds < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 ticket renew-before-expiry seconds must be >= 0"
            )
        }
        this.minRemainingTtlSeconds = minRemainingTtlSeconds
        this.renewBeforeExpirySeconds = renewBeforeExpirySeconds
        this.requiredServerName = requiredServerName.trimAscii().toAsciiLower()
        this.requiredAlpnProtocol = requiredAlpnProtocol.trimAscii().toAsciiLower()
    }
}

public class ContractTls13SessionTicketLifecycleResult {
    public let usable: Bool
    public let shouldRenew: Bool
    public let reason: String
    public let nowUnixSeconds: Int64
    public let remainingTtlSeconds: Int64

    public init(
        usable: Bool,
        shouldRenew: Bool,
        reason: String,
        nowUnixSeconds: Int64,
        remainingTtlSeconds: Int64
    ) {
        if (reason.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 ticket lifecycle reason must not be empty")
        }
        if (nowUnixSeconds <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 ticket lifecycle nowUnixSeconds must be > 0")
        }
        this.usable = usable
        this.shouldRenew = shouldRenew
        this.reason = reason.trimAscii()
        this.nowUnixSeconds = nowUnixSeconds
        this.remainingTtlSeconds = remainingTtlSeconds
    }
}

public class ContractTls13NewSessionTicketRequest {
    public let ticket: ContractTlsSessionTicket
    public let ticketAgeAdd: Int64

    public init(
        ticket: ContractTlsSessionTicket,
        ticketAgeAdd!: Int64 = 0
    ) {
        this.ticket = ticket
        this.ticketAgeAdd = ticketAgeAdd
    }
}

public class ContractTls13StoreNewSessionTicketRequest {
    public let cache: ContractTlsSessionCache
    public let encodedNewSessionTicket: Array<Byte>

    public init(
        cache: ContractTlsSessionCache,
        encodedNewSessionTicket: Array<Byte>
    ) {
        if (encodedNewSessionTicket.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 store NewSessionTicket request payload must not be empty"
            )
        }
        this.cache = cache
        this.encodedNewSessionTicket = encodedNewSessionTicket.clone()
    }
}

public class ContractTls13SessionTicketLifecycleRequest {
    public let ticket: ContractTlsSessionTicket
    public let policy: ContractTls13SessionTicketPolicy
    public let nowUnixSeconds: Int64

    public init(
        ticket: ContractTlsSessionTicket,
        policy!: ContractTls13SessionTicketPolicy = ContractTls13SessionTicketPolicy(),
        nowUnixSeconds!: Int64 = 0
    ) {
        this.ticket = ticket
        this.policy = ContractTls13SessionTicketPolicy(
            minRemainingTtlSeconds: policy.minRemainingTtlSeconds,
            renewBeforeExpirySeconds: policy.renewBeforeExpirySeconds,
            requiredServerName: policy.requiredServerName,
            requiredAlpnProtocol: policy.requiredAlpnProtocol
        )
        this.nowUnixSeconds = nowUnixSeconds
    }
}

public class ContractTlsSessionCacheStats {
    public let size: Int64
    public let hits: Int64
    public let misses: Int64
    public let evictions: Int64
    public let expiredRemovals: Int64

    public init(size: Int64, hits: Int64, misses: Int64, evictions: Int64, expiredRemovals: Int64) {
        this.size = size
        this.hits = hits
        this.misses = misses
        this.evictions = evictions
        this.expiredRemovals = expiredRemovals
    }
}

public class ContractTlsSessionCache {
    let _inner: TlsSessionCache

    public init(maxEntries!: Int64 = 1024, defaultTtlSeconds!: Int64 = TLS_SESSION_DEFAULT_TTL_SECONDS) {
        try {
            this._inner = TlsSessionCache(maxEntries: maxEntries, defaultTtlSeconds: defaultTtlSeconds)
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session cache initialization failed: ${e.message}"
            )
        }
    }

    public prop size: Int64 {
        get() {
            _inner.size
        }
    }

    public func stats(): ContractTlsSessionCacheStats {
        contractFromTlsSessionCacheStats(_inner.stats())
    }

    public func store(ticket: ContractTlsSessionTicket): ContractTlsSessionTicket {
        try {
            let stored = _inner.store(contractToTlsSessionTicket(ticket))
            contractFromTlsSessionTicket(stored)
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session ticket store failed: ${e.message}"
            )
        }
    }

    public func storeFromSecret(
        identity: ContractTlsSessionIdentity,
        secret: Array<Byte>,
        nonce!: Array<Byte> = [],
        nowUnixSeconds!: Int64 = 0,
        ttlSeconds!: Int64 = 0
    ): ContractTlsSessionTicket {
        try {
            let stored = _inner.storeFromSecret(
                contractToTlsSessionIdentity(identity),
                secret,
                nonce: nonce,
                nowUnixSeconds: nowUnixSeconds,
                ttlSeconds: ttlSeconds
            )
            contractFromTlsSessionTicket(stored)
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session ticket store-from-secret failed: ${e.message}"
            )
        }
    }

    public func load(
        identity: ContractTlsSessionIdentity,
        nowUnixSeconds!: Int64 = 0
    ): ?ContractTlsSessionTicket {
        try {
            let loaded = _inner.load(
                contractToTlsSessionIdentity(identity),
                nowUnixSeconds: nowUnixSeconds
            )
            if (let Some(ticket) <- loaded) {
                return Some(contractFromTlsSessionTicket(ticket))
            }
            None
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session ticket load failed: ${e.message}"
            )
        }
    }

    public func remove(identity: ContractTlsSessionIdentity): Bool {
        try {
            _inner.remove(contractToTlsSessionIdentity(identity))
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session ticket remove failed: ${e.message}"
            )
        }
    }

    public func purgeExpired(nowUnixSeconds!: Int64 = 0): Int64 {
        try {
            _inner.purgeExpired(nowUnixSeconds: nowUnixSeconds)
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session cache purge failed: ${e.message}"
            )
        }
    }

    public func clear(): Unit {
        _inner.clear()
    }
}

public class ContractTls13EarlyDataReplayStats {
    public let size: Int64
    public let hits: Int64
    public let misses: Int64
    public let evictions: Int64
    public let expiredRemovals: Int64
    public let rejects: Int64

    public init(
        size: Int64,
        hits: Int64,
        misses: Int64,
        evictions: Int64,
        expiredRemovals: Int64,
        rejects: Int64
    ) {
        this.size = size
        this.hits = hits
        this.misses = misses
        this.evictions = evictions
        this.expiredRemovals = expiredRemovals
        this.rejects = rejects
    }
}

public class ContractTls13EarlyDataReplayCache {
    let _maxEntries: Int64
    let _defaultWindowSeconds: Int64
    let _entries = ArrayList<ContractTls13EarlyDataReplayEntry>()

    var _hits: Int64 = 0
    var _misses: Int64 = 0
    var _evictions: Int64 = 0
    var _expiredRemovals: Int64 = 0
    var _rejects: Int64 = 0

    public init(maxEntries!: Int64 = 2048, defaultWindowSeconds!: Int64 = 600) {
        if (maxEntries <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 early data replay cache maxEntries must be positive"
            )
        }
        if (defaultWindowSeconds <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 early data replay cache default window must be positive"
            )
        }
        this._maxEntries = maxEntries
        this._defaultWindowSeconds = defaultWindowSeconds
    }

    public prop size: Int64 {
        get() {
            _entries.size
        }
    }

    public func stats(): ContractTls13EarlyDataReplayStats {
        ContractTls13EarlyDataReplayStats(
            _entries.size,
            _hits,
            _misses,
            _evictions,
            _expiredRemovals,
            _rejects
        )
    }

    public func contains(replayKey: String, nowUnixSeconds!: Int64 = 0): Bool {
        let normalizedKey = contractNormalizeReplayKey(replayKey)
        let now = contractResolveReplayUnixSeconds(nowUnixSeconds)
        purgeExpiredInternal(now)
        let (index, found) = findEntryByKey(normalizedKey)
        if (index < 0) {
            _misses += 1
            return false
        }
        match (found) {
            case Some(entry) =>
                if (entry.isExpired(now)) {
                    _entries.remove(at: index)
                    _expiredRemovals += 1
                    _misses += 1
                    return false
                }
                _hits += 1
                true
            case None =>
                _misses += 1
                false
        }
    }

    public func remember(
        replayKey: String,
        nowUnixSeconds!: Int64 = 0,
        ttlSeconds!: Int64 = 0
    ): Bool {
        let normalizedKey = contractNormalizeReplayKey(replayKey)
        let now = contractResolveReplayUnixSeconds(nowUnixSeconds)
        purgeExpiredInternal(now)
        let (index, found) = findEntryByKey(normalizedKey)
        if (index >= 0) {
            match (found) {
                case Some(entry) =>
                    if (!entry.isExpired(now)) {
                        _hits += 1
                        _rejects += 1
                        return false
                    }
                    _entries.remove(at: index)
                    _expiredRemovals += 1
                case None =>
                    ()
            }
        }

        let effectiveTtl = if (ttlSeconds > 0) {
            ttlSeconds
        } else {
            _defaultWindowSeconds
        }
        let expiresAt = now + effectiveTtl
        _entries.add(
            ContractTls13EarlyDataReplayEntry(
                normalizedKey,
                now,
                expiresAt
            )
        )
        trimToCapacity()
        _misses += 1
        true
    }

    public func purgeExpired(nowUnixSeconds!: Int64 = 0): Int64 {
        let now = contractResolveReplayUnixSeconds(nowUnixSeconds)
        purgeExpiredInternal(now)
    }

    public func clear(): Unit {
        while (_entries.size > 0) {
            _entries.remove(at: _entries.size - 1)
        }
    }

    private func purgeExpiredInternal(nowUnixSeconds: Int64): Int64 {
        var removed: Int64 = 0
        var i = _entries.size - 1
        while (i >= 0) {
            if (_entries[i].isExpired(nowUnixSeconds)) {
                _entries.remove(at: i)
                removed += 1
            }
            i -= 1
        }
        _expiredRemovals += removed
        removed
    }

    private func trimToCapacity(): Unit {
        while (_entries.size > _maxEntries) {
            _entries.remove(at: 0)
            _evictions += 1
        }
    }

    private func findEntryByKey(replayKey: String): (Int64, ?ContractTls13EarlyDataReplayEntry) {
        var idx: Int64 = 0
        for (entry in _entries) {
            if (entry.replayKey == replayKey) {
                return (idx, Some(entry))
            }
            idx += 1
        }
        (-1, None)
    }
}

class ContractTls13EarlyDataReplayEntry {
    public let replayKey: String
    public let acceptedAtUnixSeconds: Int64
    public let expiresAtUnixSeconds: Int64

    public init(replayKey: String, acceptedAtUnixSeconds: Int64, expiresAtUnixSeconds: Int64) {
        if (replayKey.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 early data replay key must not be empty")
        }
        if (acceptedAtUnixSeconds <= 0 || expiresAtUnixSeconds <= acceptedAtUnixSeconds) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 early data replay entry lifetime is invalid"
            )
        }
        this.replayKey = replayKey
        this.acceptedAtUnixSeconds = acceptedAtUnixSeconds
        this.expiresAtUnixSeconds = expiresAtUnixSeconds
    }

    public func isExpired(nowUnixSeconds: Int64): Bool {
        nowUnixSeconds >= expiresAtUnixSeconds
    }
}

private func contractNormalizeReplayKey(replayKey: String): String {
    let normalized = replayKey.trimAscii()
    if (normalized.size == 0) {
        throw ContractException(ContractErrorCode.BadInput, "TLS1.3 early data replay key must not be empty")
    }
    normalized
}

private func contractResolveReplayUnixSeconds(nowUnixSeconds: Int64): Int64 {
    if (nowUnixSeconds > 0) {
        return nowUnixSeconds
    }
    1
}

public func contractTlsCreateSessionTicket(
    identity: ContractTlsSessionIdentity,
    secret: Array<Byte>,
    nonce!: Array<Byte> = [],
    nowUnixSeconds!: Int64 = 0,
    ttlSeconds!: Int64 = TLS_SESSION_DEFAULT_TTL_SECONDS
): ContractTlsSessionTicket {
    try {
        let ticket = tlsCreateSessionTicket(
            contractToTlsSessionIdentity(identity),
            secret,
            nonce: nonce,
            nowUnixSeconds: nowUnixSeconds,
            ttlSeconds: ttlSeconds
        )
        contractFromTlsSessionTicket(ticket)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS session ticket creation failed: ${e.message}"
        )
    }
}

public func contractTlsEncodeSessionTicket(ticket: ContractTlsSessionTicket): Array<Byte> {
    try {
        tlsEncodeSessionTicket(contractToTlsSessionTicket(ticket))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS session ticket encoding failed: ${e.message}"
        )
    }
}

public func contractTlsDecodeSessionTicket(encoded: Array<Byte>): ContractTlsSessionTicket {
    try {
        contractFromTlsSessionTicket(tlsDecodeSessionTicket(encoded))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS session ticket decoding failed: ${e.message}"
        )
    }
}

public func contractTlsIsSessionTicketExpired(
    ticket: ContractTlsSessionTicket,
    nowUnixSeconds!: Int64 = 0
): Bool {
    try {
        tlsIsSessionTicketExpired(contractToTlsSessionTicket(ticket), nowUnixSeconds: nowUnixSeconds)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS session ticket expiry check failed: ${e.message}"
        )
    }
}

public func contractTlsEncodeAlertPayload(
    level: ContractTlsAlertLevel,
    description: ContractTlsAlertDescription
): Array<Byte> {
    try {
        tlsEncodeAlert(contractToTlsAlertLevel(level), contractToTlsAlertDescription(description))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS alert payload encoding failed: ${e.message}"
        )
    }
}

public func contractTlsEncodeAlertPayloadRequest(
    request: ContractTlsAlertPayloadRequest
): Array<Byte> {
    contractTlsEncodeAlertPayload(request.level, request.description)
}

public func contractTlsDecodeAlertPayload(
    encodedAlert: Array<Byte>
): ContractTlsAlertMessage {
    try {
        contractFromTlsAlertMessage(tlsDecodeAlert(encodedAlert))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS alert payload decoding failed: ${e.message}"
        )
    }
}

public func contractTlsDecodeAlertPayloadRequest(
    request: ContractTlsAlertPayloadDecodeRequest
): ContractTlsAlertMessage {
    contractTlsDecodeAlertPayload(request.encodedAlert)
}

public func contractTryTlsDecodeAlertPayload(
    encodedAlert: Array<Byte>
): ContractTlsAlertDecodeOutcome {
    try {
        let result = contractTlsDecodeAlertPayload(encodedAlert)
        return ContractTlsAlertDecodeOutcome(true, "TLS alert payload decoded", result: Some(result))
    } catch (e: ContractException) {
        return ContractTlsAlertDecodeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapExceptionToIgniteCryptoErrorCode(e))
        )
    }
}

public func contractTryTlsDecodeAlertPayloadRequest(
    request: ContractTlsAlertPayloadDecodeRequest
): ContractTlsAlertDecodeOutcome {
    contractTryTlsDecodeAlertPayload(request.encodedAlert)
}

public func contractTlsEncodePlaintextRecord(
    version: ContractTlsVersion,
    contentType: ContractTlsRecordContentType,
    payload: Array<Byte>
): Array<Byte> {
    try {
        tlsEncodeRecord(
            contractToTlsContentType(contentType),
            contractToTlsVersion(version),
            payload
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS plaintext record encoding failed: ${e.message}"
        )
    }
}

public func contractTlsEncodePlaintextRecordRequest(
    request: ContractTlsPlaintextRecordRequest
): Array<Byte> {
    contractTlsEncodePlaintextRecord(
        request.version,
        request.contentType,
        request.payload
    )
}

public func contractTlsEncodeAlertRecord(
    version: ContractTlsVersion,
    level: ContractTlsAlertLevel,
    description: ContractTlsAlertDescription
): Array<Byte> {
    try {
        tlsEncodeAlertRecord(
            contractToTlsVersion(version),
            contractToTlsAlertLevel(level),
            contractToTlsAlertDescription(description)
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS alert record encoding failed: ${e.message}"
        )
    }
}

public func contractTlsEncodeAlertRecordRequest(
    request: ContractTlsAlertRecordRequest
): Array<Byte> {
    contractTlsEncodeAlertRecord(request.version, request.level, request.description)
}

public func contractTlsDecodeAlertRecord(encodedRecord: Array<Byte>): ContractTlsAlertMessage {
    try {
        contractFromTlsAlertMessage(tlsDecodeAlertRecord(encodedRecord))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS alert record decoding failed: ${e.message}"
        )
    }
}

public func contractTlsDecodeAlertRecordRequest(
    request: ContractTlsAlertRecordDecodeRequest
): ContractTlsAlertMessage {
    contractTlsDecodeAlertRecord(request.encodedRecord)
}

public func contractTryTlsDecodeAlertRecord(
    encodedRecord: Array<Byte>
): ContractTlsAlertDecodeOutcome {
    try {
        let result = contractTlsDecodeAlertRecord(encodedRecord)
        return ContractTlsAlertDecodeOutcome(true, "TLS alert record decoded", result: Some(result))
    } catch (e: ContractException) {
        return ContractTlsAlertDecodeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapExceptionToIgniteCryptoErrorCode(e))
        )
    }
}

public func contractTryTlsDecodeAlertRecordRequest(
    request: ContractTlsAlertRecordDecodeRequest
): ContractTlsAlertDecodeOutcome {
    contractTryTlsDecodeAlertRecord(request.encodedRecord)
}

public func contractTlsIsCloseNotifyAlert(alert: ContractTlsAlertMessage): Bool {
    tlsIsCloseNotifyAlert(
        TlsAlertMessage(
            contractToTlsAlertLevel(alert.level),
            contractToTlsAlertDescription(alert.description)
        )
    )
}

public func contractTls13DeriveExporterMasterSecret(
    masterSecret: Array<Byte>,
    transcriptHash: Array<Byte>
): Array<Byte> {
    try {
        tls13DeriveExporterMasterSecret(masterSecret, transcriptHash)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 exporter master secret derivation failed: ${e.message}"
        )
    }
}

public func contractTls13DeriveExporterMasterSecretRequest(
    request: ContractTls13ExporterMasterSecretRequest
): Array<Byte> {
    contractTls13DeriveExporterMasterSecret(
        request.masterSecret,
        request.transcriptHash
    )
}

public func contractTls13ExportKeyingMaterial(
    exporterMasterSecret: Array<Byte>,
    exporterLabel: String,
    context!: Array<Byte> = [],
    outputLen!: Int64 = 32
): Array<Byte> {
    try {
        tls13ExportKeyingMaterial(
            exporterMasterSecret,
            exporterLabel,
            context: context,
            outputLen: outputLen
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 keying material export failed: ${e.message}"
        )
    }
}

public func contractTls13ExportKeyingMaterialRequest(
    request: ContractTls13ExportKeyingMaterialRequest
): Array<Byte> {
    contractTls13ExportKeyingMaterial(
        request.exporterMasterSecret,
        request.exporterLabel,
        context: request.context,
        outputLen: request.outputLen
    )
}

public func contractTls13DeriveNextApplicationTrafficSecret(
    currentTrafficSecret: Array<Byte>
): Array<Byte> {
    try {
        tls13DeriveNextApplicationTrafficSecret(currentTrafficSecret)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 next application traffic secret derivation failed: ${e.message}"
        )
    }
}

public func contractTls13DeriveApplicationTrafficKeyIv(
    applicationTrafficSecret: Array<Byte>,
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12
): (Array<Byte>, Array<Byte>) {
    try {
        tls13DeriveApplicationTrafficKeyIv(applicationTrafficSecret, keyLen: keyLen, ivLen: ivLen)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 application traffic key/iv derivation failed: ${e.message}"
        )
    }
}

public func contractTls13ResolveCipherBinding(cipherSuite: Int64): ContractTls13CipherBinding {
    try {
        let algorithm = contractFromTlsAeadAlgorithm(tls13CipherSuiteAeadAlgorithm(cipherSuite))
        ContractTls13CipherBinding(
            cipherSuite,
            contractTls13CipherSuiteName(cipherSuite),
            algorithm,
            tls13CipherSuiteKeyLen(cipherSuite),
            tls13CipherSuiteIvLen(cipherSuite)
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 cipher binding resolve failed: ${e.message}"
        )
    }
}

public func contractTls13ResolveCipherBindingFromServerHello(
    encodedServerHello: Array<Byte>
): ContractTls13CipherBinding {
    try {
        let serverHello = tlsDecodeServerHelloHandshake(encodedServerHello)
        contractTls13ResolveCipherBinding(serverHello.cipherSuite)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 cipher binding resolve from ServerHello failed: ${e.message}"
        )
    }
}

public func contractTls13ResolveCipherBindingFromServerFlight(
    serverFlight: ContractTls13HttpServerFlight
): ContractTls13CipherBinding {
    contractTls13ResolveCipherBindingFromServerHello(serverFlight.serverHello)
}

public func contractBuildHttpServerAttachResultFromTls13Flight(
    serverFlight: ContractTls13HttpServerFlight
): ContractHttpServerAttachResult {
    let binding = contractTls13ResolveCipherBindingFromServerFlight(serverFlight)
    ContractHttpServerAttachResult(
        serverFlight,
        tlsVersion: ContractTlsVersion.Tls13,
        cipherSuite: binding.cipherSuiteName,
        negotiatedAlpn: serverFlight.selectedAlpn,
        requestedServerName: serverFlight.requestedServerName,
        acknowledgedServerName: serverFlight.acknowledgedServerName,
        secureSessionReady: false,
        attachSurface: "accepted-socket-flight"
    )
}

public func contractBuildHttpServerInitialHandshakeFacade(
    session: ContractHttpServerAcceptedTransportSession
): ContractHttpServerInitialHandshakeFacade {
    session.initialHandshake
}

private func contractBuildHttpServerInitialHandshakeFacadeFromContext(
    flight: ContractTls13HttpServerFlight,
    secrets: Tls13HandshakeSecrets,
    binding: ContractTls13CipherBinding
): ContractHttpServerInitialHandshakeFacade {
    let (clientHandshakeKey, clientHandshakeIv) = contractTls13DeriveApplicationTrafficKeyIv(
        secrets.clientHsTrafficSecret,
        keyLen: binding.keyLen,
        ivLen: binding.ivLen
    )
    let (serverHandshakeKey, serverHandshakeIv) = contractTls13DeriveApplicationTrafficKeyIv(
        secrets.serverHsTrafficSecret,
        keyLen: binding.keyLen,
        ivLen: binding.ivLen
    )
    let handshakeKeyMaterial = ContractTls13ApplicationKeyMaterial(
        clientHandshakeKey,
        clientHandshakeIv,
        serverHandshakeKey,
        serverHandshakeIv
    )
    let handshakeChannel = contractTls13CreateServerRecordChannel(
        handshakeKeyMaterial,
        algorithm: binding.algorithm
    )
    let records = ArrayList<Array<Byte>>()
    records.add(
        contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            flight.serverHello
        )
    )
    records.add(handshakeChannel.seal(ContractTlsRecordContentType.Handshake, flight.encryptedExtensions))
    records.add(handshakeChannel.seal(ContractTlsRecordContentType.Handshake, flight.certificateHandshake))
    records.add(handshakeChannel.seal(ContractTlsRecordContentType.Handshake, flight.certificateVerifyHandshake))
    records.add(handshakeChannel.seal(ContractTlsRecordContentType.Handshake, flight.finishedHandshake))
    ContractHttpServerInitialHandshakeFacade(flight, records.toArray())
}

public func contractAttachAcceptedTransportTls13X25519Request(
    request: ContractHttpServerAcceptedTransportTls13X25519Request
): ContractHttpServerAcceptedTransportSession {
    contractAttachAcceptedTransportTls13X25519(
        request.transport,
        request.plan,
        request.encodedClientHello,
        request.serverKeyExchangePrivate,
        policy: request.policy
    )
}

private func contractWithStableAcceptedTransportSurface(
    session: ContractHttpServerAcceptedTransportSession
): ContractHttpServerAcceptedTransportSession {
    if (!session.secureSessionReady) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "stable accepted transport publication requires a ready secure session"
        )
    }
    ContractHttpServerAcceptedTransportSession(
        session.transport,
        ContractAcceptedTransportSessionStatus.Ready,
        ContractHttpServerAttachResult(
            session.result.serverFlight,
            tlsVersion: session.result.tlsVersion,
            cipherSuite: session.result.cipherSuite,
            negotiatedAlpn: session.result.negotiatedAlpn,
            requestedServerName: session.result.requestedServerName,
            acknowledgedServerName: session.result.acknowledgedServerName,
            secureSessionReady: true,
            attachSurface: "stable-accepted-transport-session"
        ),
        session.initialHandshake,
        session.keyMaterial,
        session.recordChannel
    )
}

public func contractAttachStableAcceptedTransportTls13X25519Request(
    request: ContractHttpServerAcceptedTransportTls13X25519Request
): ContractHttpServerAcceptedTransportSession {
    contractAttachStableAcceptedTransportTls13X25519(
        request.transport,
        request.plan,
        request.encodedClientHello,
        request.serverKeyExchangePrivate,
        policy: request.policy
    )
}

public func contractAttachStableAcceptedTransportTls13X25519(
    transport: ContractAcceptedTransportDescriptor,
    plan: ContractHttpServerAttachPlan,
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractHttpServerAcceptedTransportSession {
    if (!plan.stableAttachGate.readyNow) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "stable accepted transport attach requires a ready HttpServerStableAttach gate"
        )
    }
    contractWithStableAcceptedTransportSurface(
        contractAttachAcceptedTransportTls13X25519(
            transport,
            plan,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
    )
}

public func contractAttachAcceptedTransportTls13X25519(
    transport: ContractAcceptedTransportDescriptor,
    plan: ContractHttpServerAttachPlan,
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractHttpServerAcceptedTransportSession {
    try {
        let material = plan.startup.material
        let certChain = x509ParsePemChain(material.certificateChainPemBundle())
        if (certChain.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "accepted transport certificate chain must not be empty")
        }
        let certChainDer = contractDerChainFromCertificates(certChain)
        let certificatePrivateKeyRsa: ?RsaPrivateKey = contractTryParseRsaPrivateKeyPkcs8Pem(material.privateKeyPem)
        let certificatePrivateKeyEcdsa: ?EcPrivateKey = if (let Some(_value) <- certificatePrivateKeyRsa) {
            None
        } else {
            contractTryParseEcPrivateKeyPkcs8Pem(material.privateKeyPem)
        }
        if (
            !contractIsSomeRsaPrivateKey(certificatePrivateKeyRsa) &&
            !contractIsSomeEcPrivateKey(certificatePrivateKeyEcdsa)
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "accepted transport certificate private key must be PKCS8 RSA or EC"
            )
        }

        let serverKeyShare = x25519PublicFromPrivate(serverKeyExchangePrivate)
        let context = tls13BuildHttpServerHandshakeContextX25519(
            encodedClientHello,
            serverKeyExchangePrivate,
            serverKeyShare,
            certChainDer,
            certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
            certificatePrivateKeyRsa: certificatePrivateKeyRsa,
            policy: contractToTlsHttpNegotiationPolicy(policy)
        )
        let flight = contractFromTls13ServerHandshakeFlight(context.flight)
        let binding = contractTls13ResolveCipherBindingFromServerFlight(flight)
        let keyMaterial = ContractTls13ApplicationKeyMaterial(
            context.secrets.clientWriteKey,
            context.secrets.clientWriteIv,
            context.secrets.serverWriteKey,
            context.secrets.serverWriteIv
        )
        let serverChannel = contractTls13CreateServerRecordChannel(
            keyMaterial,
            algorithm: binding.algorithm
        )
        let initialHandshake = contractBuildHttpServerInitialHandshakeFacadeFromContext(
            flight,
            context.secrets,
            binding
        )
        let result = ContractHttpServerAttachResult(
            flight,
            tlsVersion: ContractTlsVersion.Tls13,
            cipherSuite: binding.cipherSuiteName,
            negotiatedAlpn: flight.selectedAlpn,
            requestedServerName: flight.requestedServerName,
            acknowledgedServerName: flight.acknowledgedServerName,
            secureSessionReady: true,
            attachSurface: "accepted-transport-session"
        )
        ContractHttpServerAcceptedTransportSession(
            transport,
            ContractAcceptedTransportSessionStatus.Ready,
            result,
            initialHandshake,
            keyMaterial,
            serverChannel
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "accepted transport TLS1.3 X25519 attach failed: ${e.message}"
        )
    }
}

public func contractCloseAcceptedTransportSession(
    session: ContractHttpServerAcceptedTransportSession,
    reason!: String = "close_notify"
): ContractHttpServerAcceptedTransportSession {
    ContractHttpServerAcceptedTransportSession(
        session.transport,
        ContractAcceptedTransportSessionStatus.Closed,
        ContractHttpServerAttachResult(
            session.result.serverFlight,
            tlsVersion: session.result.tlsVersion,
            cipherSuite: session.result.cipherSuite,
            negotiatedAlpn: session.result.negotiatedAlpn,
            requestedServerName: session.result.requestedServerName,
            acknowledgedServerName: session.result.acknowledgedServerName,
            secureSessionReady: false,
            attachSurface: session.result.attachSurface
        ),
        session.initialHandshake,
        session.keyMaterial,
        session.recordChannel,
        closeReason: reason
    )
}

public func contractTls13DerivePskX25519SecretsForCipherSuite(
    psk: Array<Byte>,
    clientPrivateKey: Array<Byte>,
    serverPublicKey: Array<Byte>,
    transcriptHash: Array<Byte>,
    cipherSuite: Int64
): ContractTls13PskX25519DerivedSecrets {
    try {
        let binding = contractTls13ResolveCipherBinding(cipherSuite)
        let tlsSecrets = tls13DeriveSecretsFromPskAndX25519ForCipherSuite(
            psk,
            clientPrivateKey,
            serverPublicKey,
            transcriptHash,
            cipherSuite
        )
        contractFromTls13PskX25519DerivedSecrets(binding, tlsSecrets)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 PSK+X25519 secret derivation failed: ${e.message}"
        )
    }
}

public func contractTls13DerivePskX25519SecretsFromSessionTicketForCipherSuite(
    ticket: ContractTlsSessionTicket,
    clientPrivateKey: Array<Byte>,
    serverPublicKey: Array<Byte>,
    transcriptHash: Array<Byte>,
    cipherSuite: Int64
): ContractTls13PskX25519DerivedSecrets {
    contractTls13DerivePskX25519SecretsForCipherSuite(
        ticket.secret,
        clientPrivateKey,
        serverPublicKey,
        transcriptHash,
        cipherSuite
    )
}

public func contractTls13DerivePskX25519SecretsFromSessionTicketAndServerHello(
    ticket: ContractTlsSessionTicket,
    clientPrivateKey: Array<Byte>,
    serverPublicKey: Array<Byte>,
    transcriptHash: Array<Byte>,
    encodedServerHello: Array<Byte>
): ContractTls13PskX25519DerivedSecrets {
    let binding = contractTls13ResolveCipherBindingFromServerHello(encodedServerHello)
    contractTls13DerivePskX25519SecretsFromSessionTicketForCipherSuite(
        ticket,
        clientPrivateKey,
        serverPublicKey,
        transcriptHash,
        binding.cipherSuite
    )
}

public func contractTls13CreateClientRecordChannelFromPskX25519Secrets(
    secrets: ContractTls13PskX25519DerivedSecrets
): ContractTlsRecordChannel {
    contractTls13CreateClientRecordChannel(secrets.keyMaterial, algorithm: secrets.cipherBinding.algorithm)
}

public func contractTls13CreateServerRecordChannelFromPskX25519Secrets(
    secrets: ContractTls13PskX25519DerivedSecrets
): ContractTlsRecordChannel {
    contractTls13CreateServerRecordChannel(secrets.keyMaterial, algorithm: secrets.cipherBinding.algorithm)
}

public func contractTls13CreatePskX25519ChannelSetFromSecrets(
    secrets: ContractTls13PskX25519DerivedSecrets
): ContractTls13PskX25519ChannelSet {
    ContractTls13PskX25519ChannelSet(
        secrets,
        contractTls13CreateClientRecordChannelFromPskX25519Secrets(secrets),
        contractTls13CreateServerRecordChannelFromPskX25519Secrets(secrets)
    )
}

public func contractTls13CreatePskX25519ChannelSetFromSessionTicketAndServerHello(
    ticket: ContractTlsSessionTicket,
    clientPrivateKey: Array<Byte>,
    serverPublicKey: Array<Byte>,
    transcriptHash: Array<Byte>,
    encodedServerHello: Array<Byte>
): ContractTls13PskX25519ChannelSet {
    let secrets = contractTls13DerivePskX25519SecretsFromSessionTicketAndServerHello(
        ticket,
        clientPrivateKey,
        serverPublicKey,
        transcriptHash,
        encodedServerHello
    )
    contractTls13CreatePskX25519ChannelSetFromSecrets(secrets)
}

public func contractTls13RotatePskX25519ClientTraffic(
    channels: ContractTls13PskX25519ChannelSet,
    requestPeerUpdate!: Bool = false
): ContractTls13PskX25519TrafficUpdateResult {
    let encodedKeyUpdate = contractTls13BuildKeyUpdateHandshake(requestPeerUpdate: requestPeerUpdate)
    let rotatedSecrets = contractTls13RotatePskX25519ClientSecrets(channels.secrets)
    let rotatedChannels = contractTls13CreatePskX25519ChannelSetFromSecrets(rotatedSecrets)
    ContractTls13PskX25519TrafficUpdateResult(
        encodedKeyUpdate,
        requestPeerUpdate,
        rotatedChannels
    )
}

public func contractTls13RotatePskX25519ServerTraffic(
    channels: ContractTls13PskX25519ChannelSet,
    requestPeerUpdate!: Bool = false
): ContractTls13PskX25519TrafficUpdateResult {
    let encodedKeyUpdate = contractTls13BuildKeyUpdateHandshake(requestPeerUpdate: requestPeerUpdate)
    let rotatedSecrets = contractTls13RotatePskX25519ServerSecrets(channels.secrets)
    let rotatedChannels = contractTls13CreatePskX25519ChannelSetFromSecrets(rotatedSecrets)
    ContractTls13PskX25519TrafficUpdateResult(
        encodedKeyUpdate,
        requestPeerUpdate,
        rotatedChannels
    )
}

public func contractTls13ApplyPskX25519ClientTrafficUpdate(
    channels: ContractTls13PskX25519ChannelSet,
    encodedKeyUpdate: Array<Byte>
): ContractTls13PskX25519TrafficUpdateResult {
    let requestPeerUpdate = contractTls13DecodeKeyUpdateHandshake(encodedKeyUpdate)
    let rotatedSecrets = contractTls13RotatePskX25519ClientSecrets(channels.secrets)
    let rotatedChannels = contractTls13CreatePskX25519ChannelSetFromSecrets(rotatedSecrets)
    ContractTls13PskX25519TrafficUpdateResult(
        encodedKeyUpdate,
        requestPeerUpdate,
        rotatedChannels
    )
}

public func contractTls13ApplyPskX25519ServerTrafficUpdate(
    channels: ContractTls13PskX25519ChannelSet,
    encodedKeyUpdate: Array<Byte>
): ContractTls13PskX25519TrafficUpdateResult {
    let requestPeerUpdate = contractTls13DecodeKeyUpdateHandshake(encodedKeyUpdate)
    let rotatedSecrets = contractTls13RotatePskX25519ServerSecrets(channels.secrets)
    let rotatedChannels = contractTls13CreatePskX25519ChannelSetFromSecrets(rotatedSecrets)
    ContractTls13PskX25519TrafficUpdateResult(
        encodedKeyUpdate,
        requestPeerUpdate,
        rotatedChannels
    )
}

public func contractTls13ApplyPskX25519ClientTrafficUpdateAndMaybeRespond(
    channels: ContractTls13PskX25519ChannelSet,
    encodedKeyUpdate: Array<Byte>,
    forceResponse!: Bool = false
): ContractTls13PskX25519PeerUpdateOrchestrationResult {
    let applied = contractTls13ApplyPskX25519ClientTrafficUpdate(channels, encodedKeyUpdate)
    if (applied.requestPeerUpdate || forceResponse) {
        let response = contractTls13RotatePskX25519ServerTraffic(applied.channels)
        return ContractTls13PskX25519PeerUpdateOrchestrationResult(
            applied.requestPeerUpdate,
            true,
            response.encodedKeyUpdate,
            response.channels
        )
    }
    ContractTls13PskX25519PeerUpdateOrchestrationResult(
        applied.requestPeerUpdate,
        false,
        [],
        applied.channels
    )
}

public func contractTls13ApplyPskX25519ServerTrafficUpdateAndMaybeRespond(
    channels: ContractTls13PskX25519ChannelSet,
    encodedKeyUpdate: Array<Byte>,
    forceResponse!: Bool = false
): ContractTls13PskX25519PeerUpdateOrchestrationResult {
    let applied = contractTls13ApplyPskX25519ServerTrafficUpdate(channels, encodedKeyUpdate)
    if (applied.requestPeerUpdate || forceResponse) {
        let response = contractTls13RotatePskX25519ClientTraffic(applied.channels)
        return ContractTls13PskX25519PeerUpdateOrchestrationResult(
            applied.requestPeerUpdate,
            true,
            response.encodedKeyUpdate,
            response.channels
        )
    }
    ContractTls13PskX25519PeerUpdateOrchestrationResult(
        applied.requestPeerUpdate,
        false,
        [],
        applied.channels
    )
}

public func contractTls13RotatePskX25519LocalTraffic(
    channels: ContractTls13PskX25519ChannelSet,
    localEndpointRole: ContractTlsEndpointRole,
    requestPeerUpdate!: Bool = false
): ContractTls13PskX25519TrafficUpdateResult {
    match (localEndpointRole) {
        case ContractTlsEndpointRole.Client =>
            contractTls13RotatePskX25519ClientTraffic(channels, requestPeerUpdate: requestPeerUpdate)
        case ContractTlsEndpointRole.Server =>
            contractTls13RotatePskX25519ServerTraffic(channels, requestPeerUpdate: requestPeerUpdate)
    }
}

public func contractTls13ApplyPskX25519PeerTrafficUpdate(
    channels: ContractTls13PskX25519ChannelSet,
    encodedKeyUpdate: Array<Byte>,
    localEndpointRole: ContractTlsEndpointRole
): ContractTls13PskX25519TrafficUpdateResult {
    match (localEndpointRole) {
        case ContractTlsEndpointRole.Client =>
            contractTls13ApplyPskX25519ServerTrafficUpdate(channels, encodedKeyUpdate)
        case ContractTlsEndpointRole.Server =>
            contractTls13ApplyPskX25519ClientTrafficUpdate(channels, encodedKeyUpdate)
    }
}

public func contractTls13ApplyPskX25519PeerTrafficUpdateAndMaybeRespond(
    channels: ContractTls13PskX25519ChannelSet,
    encodedKeyUpdate: Array<Byte>,
    localEndpointRole: ContractTlsEndpointRole,
    forceResponse!: Bool = false
): ContractTls13PskX25519PeerUpdateOrchestrationResult {
    match (localEndpointRole) {
        case ContractTlsEndpointRole.Client =>
            contractTls13ApplyPskX25519ServerTrafficUpdateAndMaybeRespond(
                channels,
                encodedKeyUpdate,
                forceResponse: forceResponse
            )
        case ContractTlsEndpointRole.Server =>
            contractTls13ApplyPskX25519ClientTrafficUpdateAndMaybeRespond(
                channels,
                encodedKeyUpdate,
                forceResponse: forceResponse
            )
    }
}

public func contractTls13BuildKeyUpdateHandshake(
    requestPeerUpdate!: Bool = false
): Array<Byte> {
    try {
        tls13BuildKeyUpdateHandshake(requestPeerUpdate: requestPeerUpdate)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 KeyUpdate build failed: ${e.message}"
        )
    }
}

public func contractTls13DecodeKeyUpdateHandshake(encodedKeyUpdate: Array<Byte>): Bool {
    try {
        tls13DecodeKeyUpdateHandshake(encodedKeyUpdate)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 KeyUpdate decode failed: ${e.message}"
        )
    }
}

public func contractTls13PrepareKeyUpdate(
    currentTrafficSecret: Array<Byte>,
    requestPeerUpdate!: Bool = false,
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12
): ContractTls13KeyUpdatePlan {
    let encodedKeyUpdate = contractTls13BuildKeyUpdateHandshake(requestPeerUpdate: requestPeerUpdate)
    contractTls13BuildKeyUpdatePlan(
        currentTrafficSecret,
        encodedKeyUpdate,
        keyLen,
        ivLen
    )
}

public func contractTls13PrepareKeyUpdateRequest(
    request: ContractTls13KeyUpdateRequest
): ContractTls13KeyUpdatePlan {
    contractTls13PrepareKeyUpdate(
        request.currentTrafficSecret,
        requestPeerUpdate: request.requestPeerUpdate,
        keyLen: request.keyLen,
        ivLen: request.ivLen
    )
}

public func contractTls13ApplyPeerKeyUpdate(
    currentTrafficSecret: Array<Byte>,
    encodedKeyUpdate: Array<Byte>,
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12
): ContractTls13KeyUpdatePlan {
    contractTls13BuildKeyUpdatePlan(
        currentTrafficSecret,
        encodedKeyUpdate,
        keyLen,
        ivLen
    )
}

public func contractTls13ApplyPeerKeyUpdateRequest(
    request: ContractTls13PeerKeyUpdateRequest
): ContractTls13KeyUpdatePlan {
    contractTls13ApplyPeerKeyUpdate(
        request.currentTrafficSecret,
        request.encodedKeyUpdate,
        keyLen: request.keyLen,
        ivLen: request.ivLen
    )
}

public func contractTls13ResolveCipherBindingFromVerifiedSession(
    session: ContractTls13HttpClientVerifiedSession
): ContractTls13CipherBinding {
    match (session.result.cipherBinding) {
        case Some(binding) => binding
        case None =>
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 verified session does not carry cipher binding"
            )
    }
}

public func contractTls13CreateClientRecordChannelFromVerifiedSession(
    session: ContractTls13HttpClientVerifiedSession
): ContractTlsRecordChannel {
    let binding = contractTls13ResolveCipherBindingFromVerifiedSession(session)
    contractTls13CreateClientRecordChannel(
        session.result.keyMaterial,
        algorithm: binding.algorithm
    )
}

public func contractTls13CreateClientRecordChannelFromVerifiedSessionRequest(
    request: ContractTls13HttpVerifiedSessionRequest
): ContractTlsRecordChannel {
    contractTls13CreateClientRecordChannelFromVerifiedSession(request.session)
}

public func contractTls13CreateServerRecordChannelFromVerifiedSession(
    session: ContractTls13HttpClientVerifiedSession
): ContractTlsRecordChannel {
    let binding = contractTls13ResolveCipherBindingFromVerifiedSession(session)
    contractTls13CreateServerRecordChannel(
        session.result.keyMaterial,
        algorithm: binding.algorithm
    )
}

public func contractTls13CreateServerRecordChannelFromVerifiedSessionRequest(
    request: ContractTls13HttpVerifiedSessionRequest
): ContractTlsRecordChannel {
    contractTls13CreateServerRecordChannelFromVerifiedSession(request.session)
}

public func contractTls13CreateVerifiedSessionChannelSet(
    session: ContractTls13HttpClientVerifiedSession
): ContractTls13HttpVerifiedSessionChannelSet {
    ContractTls13HttpVerifiedSessionChannelSet(
        session,
        contractTls13CreateClientRecordChannelFromVerifiedSession(session),
        contractTls13CreateServerRecordChannelFromVerifiedSession(session)
    )
}

public func contractTls13CreateVerifiedSessionChannelSetRequest(
    request: ContractTls13HttpVerifiedSessionRequest
): ContractTls13HttpVerifiedSessionChannelSet {
    contractTls13CreateVerifiedSessionChannelSet(request.session)
}

public func contractTls13OpenHttpClientVerifiedSessionRuntime(
    session: ContractTls13HttpClientVerifiedSession
): ContractTls13HttpClientVerifiedSessionRuntime {
    ContractTls13HttpClientVerifiedSessionRuntime(
        ContractTls13HttpClientSessionStatus.Ready,
        contractTls13CreateVerifiedSessionChannelSet(session)
    )
}

public func contractTls13OpenHttpClientVerifiedSessionRuntimeRequest(
    request: ContractTls13HttpVerifiedSessionRequest
): ContractTls13HttpClientVerifiedSessionRuntime {
    contractTls13OpenHttpClientVerifiedSessionRuntime(request.session)
}

public func contractTls13CloseHttpClientVerifiedSessionRuntime(
    runtime: ContractTls13HttpClientVerifiedSessionRuntime,
    reason!: String = "close_notify"
): ContractTls13HttpClientVerifiedSessionRuntime {
    ContractTls13HttpClientVerifiedSessionRuntime(
        ContractTls13HttpClientSessionStatus.Closed,
        runtime.channelSet,
        closeReason: reason
    )
}

public func contractTls13DeriveExporterMasterSecretFromVerifiedSession(
    session: ContractTls13HttpClientVerifiedSession
): Array<Byte> {
    contractTls13DeriveExporterMasterSecret(
        session.masterSecret,
        session.transcriptHash
    )
}

public func contractTls13DeriveExporterMasterSecretFromVerifiedSessionRequest(
    request: ContractTls13HttpVerifiedSessionRequest
): Array<Byte> {
    contractTls13DeriveExporterMasterSecretFromVerifiedSession(request.session)
}

public func contractTls13ExportKeyingMaterialFromVerifiedSession(
    session: ContractTls13HttpClientVerifiedSession,
    exporterLabel: String,
    context!: Array<Byte> = [],
    outputLen!: Int64 = 32
): Array<Byte> {
    let exporterMasterSecret = contractTls13DeriveExporterMasterSecretFromVerifiedSession(session)
    contractTls13ExportKeyingMaterial(
        exporterMasterSecret,
        exporterLabel,
        context: context,
        outputLen: outputLen
    )
}

public func contractTls13ExportKeyingMaterialFromVerifiedSessionRequest(
    request: ContractTls13HttpVerifiedSessionExportRequest
): Array<Byte> {
    contractTls13ExportKeyingMaterialFromVerifiedSession(
        request.session,
        request.exporterLabel,
        context: request.context,
        outputLen: request.outputLen
    )
}

public func contractTls13PrepareKeyUpdateFromVerifiedSession(
    session: ContractTls13HttpClientVerifiedSession,
    requestPeerUpdate!: Bool = false
): ContractTls13KeyUpdatePlan {
    let binding = contractTls13ResolveCipherBindingFromVerifiedSession(session)
    contractTls13PrepareKeyUpdate(
        session.clientAppTrafficSecret,
        requestPeerUpdate: requestPeerUpdate,
        keyLen: binding.keyLen,
        ivLen: binding.ivLen
    )
}

public func contractTls13PrepareKeyUpdateFromVerifiedSessionRequest(
    request: ContractTls13HttpVerifiedSessionKeyUpdateRequest
): ContractTls13KeyUpdatePlan {
    contractTls13PrepareKeyUpdateFromVerifiedSession(
        request.session,
        requestPeerUpdate: request.requestPeerUpdate
    )
}

public func contractTls13ApplyPeerKeyUpdateFromVerifiedSession(
    session: ContractTls13HttpClientVerifiedSession,
    encodedKeyUpdate: Array<Byte>
): ContractTls13KeyUpdatePlan {
    let binding = contractTls13ResolveCipherBindingFromVerifiedSession(session)
    contractTls13ApplyPeerKeyUpdate(
        session.serverAppTrafficSecret,
        encodedKeyUpdate,
        keyLen: binding.keyLen,
        ivLen: binding.ivLen
    )
}

public func contractTls13ApplyPeerKeyUpdateFromVerifiedSessionRequest(
    request: ContractTls13HttpVerifiedSessionPeerKeyUpdateRequest
): ContractTls13KeyUpdatePlan {
    contractTls13ApplyPeerKeyUpdateFromVerifiedSession(
        request.session,
        request.encodedKeyUpdate
    )
}

public func contractTls13RotateClientTrafficInVerifiedSession(
    session: ContractTls13HttpClientVerifiedSession,
    requestPeerUpdate!: Bool = false
): ContractTls13HttpVerifiedSessionTrafficUpdateResult {
    let plan = contractTls13PrepareKeyUpdateFromVerifiedSession(
        session,
        requestPeerUpdate: requestPeerUpdate
    )
    let updatedSession = contractTls13RebuildVerifiedSession(
        session,
        session.result.keyMaterial.serverWriteKey,
        session.result.keyMaterial.serverWriteIv,
        plan.nextTrafficSecret,
        session.serverAppTrafficSecret,
        plan.nextWriteKey,
        plan.nextWriteIv
    )
    ContractTls13HttpVerifiedSessionTrafficUpdateResult(
        plan.encodedKeyUpdate,
        plan.requestPeerUpdate,
        contractTls13CreateVerifiedSessionChannelSet(updatedSession)
    )
}

public func contractTls13RotateClientTrafficInVerifiedSessionRequest(
    request: ContractTls13HttpVerifiedSessionKeyUpdateRequest
): ContractTls13HttpVerifiedSessionTrafficUpdateResult {
    contractTls13RotateClientTrafficInVerifiedSession(
        request.session,
        requestPeerUpdate: request.requestPeerUpdate
    )
}

public func contractTls13ApplyPeerTrafficUpdateToVerifiedSession(
    session: ContractTls13HttpClientVerifiedSession,
    encodedKeyUpdate: Array<Byte>
): ContractTls13HttpVerifiedSessionTrafficUpdateResult {
    let plan = contractTls13ApplyPeerKeyUpdateFromVerifiedSession(
        session,
        encodedKeyUpdate
    )
    let updatedSession = contractTls13RebuildVerifiedSession(
        session,
        plan.nextWriteKey,
        plan.nextWriteIv,
        session.clientAppTrafficSecret,
        plan.nextTrafficSecret,
        session.result.keyMaterial.clientWriteKey,
        session.result.keyMaterial.clientWriteIv
    )
    ContractTls13HttpVerifiedSessionTrafficUpdateResult(
        plan.encodedKeyUpdate,
        plan.requestPeerUpdate,
        contractTls13CreateVerifiedSessionChannelSet(updatedSession)
    )
}

public func contractTls13ApplyPeerTrafficUpdateToVerifiedSessionRequest(
    request: ContractTls13HttpVerifiedSessionPeerKeyUpdateRequest
): ContractTls13HttpVerifiedSessionTrafficUpdateResult {
    contractTls13ApplyPeerTrafficUpdateToVerifiedSession(
        request.session,
        request.encodedKeyUpdate
    )
}

public func contractTls13BuildNewSessionTicketFromSessionTicket(
    ticket: ContractTlsSessionTicket,
    ticketAgeAdd!: Int64 = 0
): Array<Byte> {
    try {
        let tlsTicket = contractToTlsSessionTicket(ticket)
        tls13BuildNewSessionTicketFromSessionTicket(tlsTicket, ticketAgeAdd: ticketAgeAdd)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 NewSessionTicket build from session ticket failed: ${e.message}"
        )
    }
}

public func contractTls13BuildNewSessionTicketFromSessionTicketRequest(
    request: ContractTls13NewSessionTicketRequest
): Array<Byte> {
    contractTls13BuildNewSessionTicketFromSessionTicket(
        request.ticket,
        ticketAgeAdd: request.ticketAgeAdd
    )
}

public func contractTls13DecodeSessionTicketFromNewSessionTicket(
    encodedNewSessionTicket: Array<Byte>
): ContractTlsSessionTicket {
    try {
        contractFromTlsSessionTicket(tls13DecodeSessionTicketFromNewSessionTicket(encodedNewSessionTicket))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 session ticket decode from NewSessionTicket failed: ${e.message}"
        )
    }
}

public func contractTls13StoreNewSessionTicketToCache(
    cache: ContractTlsSessionCache,
    encodedNewSessionTicket: Array<Byte>
): ContractTlsSessionTicket {
    let ticket = contractTls13DecodeSessionTicketFromNewSessionTicket(encodedNewSessionTicket)
    cache.store(ticket)
}

public func contractTls13StoreNewSessionTicketToCacheRequest(
    request: ContractTls13StoreNewSessionTicketRequest
): ContractTlsSessionTicket {
    contractTls13StoreNewSessionTicketToCache(
        request.cache,
        request.encodedNewSessionTicket
    )
}

public func contractTls13TryBuildHttpClientHelloPskFromSessionCache(
    cache: ContractTlsSessionCache,
    identity: ContractTlsSessionIdentity,
    nowUnixSeconds!: Int64 = 0,
    sessionId!: Array<Byte> = []
): ?ContractTls13PskClientHelloFromCacheResult {
    match (cache.load(identity, nowUnixSeconds: nowUnixSeconds)) {
        case Some(ticket) =>
            let encodedClientHello = contractTls13BuildHttpClientHelloPskFromSessionTicket(
                ticket,
                sessionId: sessionId
            )
            Some(ContractTls13PskClientHelloFromCacheResult(ticket, encodedClientHello))
        case None =>
            None
    }
}

public func contractTls13TryBuildHttpClientHelloPskFromSessionCacheRequest(
    request: ContractTls13PskClientHelloFromSessionCacheRequest
): ?ContractTls13PskClientHelloFromCacheResult {
    contractTls13TryBuildHttpClientHelloPskFromSessionCache(
        request.cache,
        request.identity,
        nowUnixSeconds: request.nowUnixSeconds,
        sessionId: request.sessionId
    )
}

public func contractTryBuildHttpClientHelloPskFromSessionCacheOutcome(
    cache: ContractTlsSessionCache,
    identity: ContractTlsSessionIdentity,
    nowUnixSeconds!: Int64 = 0,
    sessionId!: Array<Byte> = []
): ContractTls13PskClientHelloFromCacheOutcome {
    match (cache.load(identity, nowUnixSeconds: nowUnixSeconds)) {
        case Some(ticket) =>
            let encodedClientHello = contractTls13BuildHttpClientHelloPskFromSessionTicket(
                ticket,
                sessionId: sessionId
            )
            ContractTls13PskClientHelloFromCacheOutcome(
                true,
                "OK",
                result: Some(ContractTls13PskClientHelloFromCacheResult(ticket, encodedClientHello))
            )
        case None =>
            ContractTls13PskClientHelloFromCacheOutcome(
                false,
                "TLS1.3 PSK session ticket is not found in cache",
                code: Some(ContractErrorCode.KeyNotFound),
                igniteCode: Some(contractMapToIgniteCryptoErrorCode(ContractErrorCode.KeyNotFound))
            )
    }
}

public func contractTryBuildHttpClientHelloPskFromSessionCacheRequestOutcome(
    request: ContractTls13PskClientHelloFromSessionCacheRequest
): ContractTls13PskClientHelloFromCacheOutcome {
    contractTryBuildHttpClientHelloPskFromSessionCacheOutcome(
        request.cache,
        request.identity,
        nowUnixSeconds: request.nowUnixSeconds,
        sessionId: request.sessionId
    )
}

public func contractTls13EvaluateSessionTicketLifecycle(
    ticket: ContractTlsSessionTicket,
    policy!: ContractTls13SessionTicketPolicy = ContractTls13SessionTicketPolicy(),
    nowUnixSeconds!: Int64 = 0
): ContractTls13SessionTicketLifecycleResult {
    let now = if (nowUnixSeconds > 0) {
        nowUnixSeconds
    } else {
        ticket.issuedAtUnixSeconds
    }
    if (now <= 0) {
        throw ContractException(ContractErrorCode.BadInput, "TLS1.3 session ticket lifecycle nowUnixSeconds must be > 0")
    }

    if (ticket.identity.version != ContractTlsVersion.Tls13) {
        return ContractTls13SessionTicketLifecycleResult(
            false,
            false,
            "UNSUPPORTED_VERSION",
            now,
            ticket.expiresAtUnixSeconds - now
        )
    }
    if (now < ticket.issuedAtUnixSeconds) {
        return ContractTls13SessionTicketLifecycleResult(
            false,
            false,
            "NOT_YET_ACTIVE",
            now,
            ticket.expiresAtUnixSeconds - now
        )
    }
    if (
        policy.requiredServerName.size > 0 &&
        ticket.identity.serverName != policy.requiredServerName
    ) {
        return ContractTls13SessionTicketLifecycleResult(
            false,
            false,
            "SERVER_NAME_MISMATCH",
            now,
            ticket.expiresAtUnixSeconds - now
        )
    }
    if (
        policy.requiredAlpnProtocol.size > 0 &&
        ticket.identity.alpnProtocol != policy.requiredAlpnProtocol
    ) {
        return ContractTls13SessionTicketLifecycleResult(
            false,
            false,
            "ALPN_MISMATCH",
            now,
            ticket.expiresAtUnixSeconds - now
        )
    }

    let remaining = ticket.expiresAtUnixSeconds - now
    if (remaining <= 0) {
        return ContractTls13SessionTicketLifecycleResult(false, false, "EXPIRED", now, remaining)
    }
    if (remaining < policy.minRemainingTtlSeconds) {
        return ContractTls13SessionTicketLifecycleResult(
            false,
            false,
            "INSUFFICIENT_REMAINING_TTL",
            now,
            remaining
        )
    }

    let shouldRenew = if (policy.renewBeforeExpirySeconds > 0) {
        remaining <= policy.renewBeforeExpirySeconds
    } else {
        false
    }
    let reason = if (shouldRenew) {
        "OK_RENEW_RECOMMENDED"
    } else {
        "OK"
    }
    ContractTls13SessionTicketLifecycleResult(true, shouldRenew, reason, now, remaining)
}

public func contractTls13EvaluateSessionTicketLifecycleRequest(
    request: ContractTls13SessionTicketLifecycleRequest
): ContractTls13SessionTicketLifecycleResult {
    contractTls13EvaluateSessionTicketLifecycle(
        request.ticket,
        policy: request.policy,
        nowUnixSeconds: request.nowUnixSeconds
    )
}

public func contractTls13RequireUsableSessionTicket(
    ticket: ContractTlsSessionTicket,
    policy!: ContractTls13SessionTicketPolicy = ContractTls13SessionTicketPolicy(),
    nowUnixSeconds!: Int64 = 0
): ContractTls13SessionTicketLifecycleResult {
    let lifecycle = contractTls13EvaluateSessionTicketLifecycle(
        ticket,
        policy: policy,
        nowUnixSeconds: nowUnixSeconds
    )
    if (!lifecycle.usable) {
        throw ContractException(
            ContractErrorCode.VerifyFailed,
            "TLS1.3 session ticket lifecycle rejected: ${lifecycle.reason}"
        )
    }
    lifecycle
}

public func contractTls13RequireUsableSessionTicketRequest(
    request: ContractTls13SessionTicketLifecycleRequest
): ContractTls13SessionTicketLifecycleResult {
    contractTls13RequireUsableSessionTicket(
        request.ticket,
        policy: request.policy,
        nowUnixSeconds: request.nowUnixSeconds
    )
}

public func contractTls13TryBuildHttpClientHelloPskFromSessionCacheWithPolicy(
    cache: ContractTlsSessionCache,
    identity: ContractTlsSessionIdentity,
    policy!: ContractTls13SessionTicketPolicy = ContractTls13SessionTicketPolicy(),
    nowUnixSeconds!: Int64 = 0,
    sessionId!: Array<Byte> = []
): ?ContractTls13PskClientHelloFromCacheResult {
    match (cache.load(identity, nowUnixSeconds: nowUnixSeconds)) {
        case Some(ticket) =>
            let lifecycle = contractTls13EvaluateSessionTicketLifecycle(
                ticket,
                policy: policy,
                nowUnixSeconds: nowUnixSeconds
            )
            if (!lifecycle.usable) {
                return None
            }
            let encodedClientHello = contractTls13BuildHttpClientHelloPskFromSessionTicket(
                ticket,
                sessionId: sessionId
            )
            Some(ContractTls13PskClientHelloFromCacheResult(ticket, encodedClientHello))
        case None =>
            None
    }
}

public func contractTls13TryBuildHttpClientHelloPskFromSessionCacheWithPolicyRequest(
    request: ContractTls13PskClientHelloFromSessionCacheWithPolicyRequest
): ?ContractTls13PskClientHelloFromCacheResult {
    contractTls13TryBuildHttpClientHelloPskFromSessionCacheWithPolicy(
        request.cache,
        request.identity,
        policy: request.policy,
        nowUnixSeconds: request.nowUnixSeconds,
        sessionId: request.sessionId
    )
}

public func contractTryBuildHttpClientHelloPskFromSessionCacheWithPolicyOutcome(
    cache: ContractTlsSessionCache,
    identity: ContractTlsSessionIdentity,
    policy!: ContractTls13SessionTicketPolicy = ContractTls13SessionTicketPolicy(),
    nowUnixSeconds!: Int64 = 0,
    sessionId!: Array<Byte> = []
): ContractTls13PskClientHelloFromCacheOutcome {
    match (cache.load(identity, nowUnixSeconds: nowUnixSeconds)) {
        case Some(ticket) =>
            let lifecycle = contractTls13EvaluateSessionTicketLifecycle(
                ticket,
                policy: policy,
                nowUnixSeconds: nowUnixSeconds
            )
            if (!lifecycle.usable) {
                return ContractTls13PskClientHelloFromCacheOutcome(
                    false,
                    "TLS1.3 session ticket lifecycle rejected: ${lifecycle.reason}",
                    code: Some(ContractErrorCode.VerifyFailed),
                    igniteCode: Some(contractMapToIgniteCryptoErrorCode(ContractErrorCode.VerifyFailed)),
                    lifecycle: Some(lifecycle)
                )
            }
            let encodedClientHello = contractTls13BuildHttpClientHelloPskFromSessionTicket(
                ticket,
                sessionId: sessionId
            )
            ContractTls13PskClientHelloFromCacheOutcome(
                true,
                "OK",
                result: Some(ContractTls13PskClientHelloFromCacheResult(ticket, encodedClientHello)),
                lifecycle: Some(lifecycle)
            )
        case None =>
            ContractTls13PskClientHelloFromCacheOutcome(
                false,
                "TLS1.3 usable PSK session ticket is not found in cache",
                code: Some(ContractErrorCode.KeyNotFound),
                igniteCode: Some(contractMapToIgniteCryptoErrorCode(ContractErrorCode.KeyNotFound))
            )
    }
}

public func contractTryBuildHttpClientHelloPskFromSessionCacheWithPolicyRequestOutcome(
    request: ContractTls13PskClientHelloFromSessionCacheWithPolicyRequest
): ContractTls13PskClientHelloFromCacheOutcome {
    contractTryBuildHttpClientHelloPskFromSessionCacheWithPolicyOutcome(
        request.cache,
        request.identity,
        policy: request.policy,
        nowUnixSeconds: request.nowUnixSeconds,
        sessionId: request.sessionId
    )
}

public func contractTls13BuildHttpClientHelloPskFromSessionCacheWithPolicy(
    cache: ContractTlsSessionCache,
    identity: ContractTlsSessionIdentity,
    policy!: ContractTls13SessionTicketPolicy = ContractTls13SessionTicketPolicy(),
    nowUnixSeconds!: Int64 = 0,
    sessionId!: Array<Byte> = []
): ContractTls13PskClientHelloFromCacheResult {
    match (
        contractTls13TryBuildHttpClientHelloPskFromSessionCacheWithPolicy(
            cache,
            identity,
            policy: policy,
            nowUnixSeconds: nowUnixSeconds,
            sessionId: sessionId
        )
    ) {
        case Some(result) =>
            result
        case None =>
            throw ContractException(
                ContractErrorCode.KeyNotFound,
                "TLS1.3 usable PSK session ticket is not found in cache"
            )
    }
}

public func contractTls13BuildHttpClientHelloPskFromSessionCacheWithPolicyRequest(
    request: ContractTls13PskClientHelloFromSessionCacheWithPolicyRequest
): ContractTls13PskClientHelloFromCacheResult {
    contractTls13BuildHttpClientHelloPskFromSessionCacheWithPolicy(
        request.cache,
        request.identity,
        policy: request.policy,
        nowUnixSeconds: request.nowUnixSeconds,
        sessionId: request.sessionId
    )
}

public func contractTls13BuildHttpClientHelloPskFromSessionCache(
    cache: ContractTlsSessionCache,
    identity: ContractTlsSessionIdentity,
    nowUnixSeconds!: Int64 = 0,
    sessionId!: Array<Byte> = []
): ContractTls13PskClientHelloFromCacheResult {
    match (
        contractTls13TryBuildHttpClientHelloPskFromSessionCache(
            cache,
            identity,
            nowUnixSeconds: nowUnixSeconds,
            sessionId: sessionId
        )
    ) {
        case Some(result) =>
            result
        case None =>
            throw ContractException(
                ContractErrorCode.KeyNotFound,
                "TLS1.3 PSK session ticket is not found in cache"
            )
    }
}

public func contractTls13BuildHttpClientHelloPskFromSessionCacheRequest(
    request: ContractTls13PskClientHelloFromSessionCacheRequest
): ContractTls13PskClientHelloFromCacheResult {
    contractTls13BuildHttpClientHelloPskFromSessionCache(
        request.cache,
        request.identity,
        nowUnixSeconds: request.nowUnixSeconds,
        sessionId: request.sessionId
    )
}

public func contractTls13PreparePskEarlyDataFromSessionTicket(
    ticket: ContractTlsSessionTicket,
    sessionId!: Array<Byte> = [],
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12
): ContractTls13PskEarlyDataPlan {
    let encodedClientHello = contractTls13BuildHttpClientHelloPskFromSessionTicket(
        ticket,
        sessionId: sessionId
    )
    contractTls13BuildPskEarlyDataPlan(
        ticket,
        encodedClientHello,
        0,
        keyLen,
        ivLen
    )
}

public func contractTls13PreparePskEarlyDataFromSessionTicketRequest(
    request: ContractTls13PskEarlyDataFromSessionTicketRequest
): ContractTls13PskEarlyDataPlan {
    contractTls13PreparePskEarlyDataFromSessionTicket(
        request.ticket,
        sessionId: request.sessionId,
        keyLen: request.keyLen,
        ivLen: request.ivLen
    )
}

public func contractTls13PreparePskEarlyDataFromSessionCache(
    cache: ContractTlsSessionCache,
    identity: ContractTlsSessionIdentity,
    nowUnixSeconds!: Int64 = 0,
    sessionId!: Array<Byte> = [],
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12
): ContractTls13PskEarlyDataPlan {
    let fromCache = contractTls13BuildHttpClientHelloPskFromSessionCache(
        cache,
        identity,
        nowUnixSeconds: nowUnixSeconds,
        sessionId: sessionId
    )
    contractTls13BuildPskEarlyDataPlan(
        fromCache.ticket,
        fromCache.encodedClientHello,
        0,
        keyLen,
        ivLen
    )
}

public func contractTls13PreparePskEarlyDataFromSessionCacheRequest(
    request: ContractTls13PskEarlyDataFromSessionCacheRequest
): ContractTls13PskEarlyDataPlan {
    contractTls13PreparePskEarlyDataFromSessionCache(
        request.cache,
        request.identity,
        nowUnixSeconds: request.nowUnixSeconds,
        sessionId: request.sessionId,
        keyLen: request.keyLen,
        ivLen: request.ivLen
    )
}

public func contractTls13AcceptPskEarlyDataFromClientHello(
    encodedClientHello: Array<Byte>,
    nowUnixSeconds!: Int64 = 0,
    selectedIdentityIndex!: Int64 = -1,
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12
): ContractTls13PskEarlyDataPlan {
    let resolvedIdentityIndex = if (selectedIdentityIndex >= 0) {
        selectedIdentityIndex
    } else {
        contractTls13SelectPskIdentityFromSessionTickets(
            encodedClientHello,
            nowUnixSeconds: nowUnixSeconds
        )
    }
    if (resolvedIdentityIndex < 0 || resolvedIdentityIndex > 65535) {
        throw ContractException(ContractErrorCode.BadInput, "TLS1.3 selected identity index must be uint16")
    }

    let ticket = contractTls13ExtractClientPskSessionTicket(
        encodedClientHello,
        selectedIdentityIndex: resolvedIdentityIndex
    )
    if (nowUnixSeconds > 0 && contractTlsIsSessionTicketExpired(ticket, nowUnixSeconds: nowUnixSeconds)) {
        throw ContractException(ContractErrorCode.VerifyFailed, "TLS1.3 PSK session ticket is expired")
    }

    try {
        let binderOk = tls13VerifyClientPskBinder(
            encodedClientHello,
            ticket.secret,
            selectedIdentityIndex: resolvedIdentityIndex
        )
        if (!binderOk) {
            throw ContractException(ContractErrorCode.VerifyFailed, "TLS1.3 PSK binder verification failed")
        }
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 PSK binder verification failed: ${e.message}"
        )
    }

    contractTls13BuildPskEarlyDataPlan(
        ticket,
        encodedClientHello,
        resolvedIdentityIndex,
        keyLen,
        ivLen
    )
}

public func contractTls13AcceptPskEarlyDataFromClientHelloRequest(
    request: ContractTls13PskEarlyDataAcceptRequest
): ContractTls13PskEarlyDataPlan {
    contractTls13AcceptPskEarlyDataFromClientHello(
        request.encodedClientHello,
        nowUnixSeconds: request.nowUnixSeconds,
        selectedIdentityIndex: request.selectedIdentityIndex,
        keyLen: request.keyLen,
        ivLen: request.ivLen
    )
}

public func contractTls13BuildPskEarlyDataReplayKey(
    plan: ContractTls13PskEarlyDataPlan
): String {
    contractTls13BuildPskEarlyDataReplayKeyFromFields(
        plan.ticket.identity,
        plan.clientHelloHash
    )
}

public func contractTls13AcceptPskEarlyDataFromClientHelloWithReplayCache(
    encodedClientHello: Array<Byte>,
    replayCache: ContractTls13EarlyDataReplayCache,
    nowUnixSeconds!: Int64 = 0,
    selectedIdentityIndex!: Int64 = -1,
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12,
    replayTtlSeconds!: Int64 = 0
): ContractTls13PskEarlyDataPlan {
    let plan = contractTls13AcceptPskEarlyDataFromClientHello(
        encodedClientHello,
        nowUnixSeconds: nowUnixSeconds,
        selectedIdentityIndex: selectedIdentityIndex,
        keyLen: keyLen,
        ivLen: ivLen
    )
    contractTls13RememberEarlyDataReplayOrThrow(
        plan,
        replayCache,
        nowUnixSeconds,
        replayTtlSeconds
    )
    plan
}

public func contractTls13AcceptPskEarlyDataFromClientHelloWithReplayCacheRequest(
    request: ContractTls13PskEarlyDataAcceptWithReplayCacheRequest
): ContractTls13PskEarlyDataPlan {
    contractTls13AcceptPskEarlyDataFromClientHelloWithReplayCache(
        request.encodedClientHello,
        request.replayCache,
        nowUnixSeconds: request.nowUnixSeconds,
        selectedIdentityIndex: request.selectedIdentityIndex,
        keyLen: request.keyLen,
        ivLen: request.ivLen,
        replayTtlSeconds: request.replayTtlSeconds
    )
}

public func contractTls13AcceptPskEarlyDataForHttp(
    encodedClientHello: Array<Byte>,
    expectedServerName!: String = "",
    expectedAlpnProtocol!: String = "",
    nowUnixSeconds!: Int64 = 0,
    selectedIdentityIndex!: Int64 = -1,
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12
): ContractTls13PskEarlyDataPlan {
    let plan = contractTls13AcceptPskEarlyDataFromClientHello(
        encodedClientHello,
        nowUnixSeconds: nowUnixSeconds,
        selectedIdentityIndex: selectedIdentityIndex,
        keyLen: keyLen,
        ivLen: ivLen
    )
    contractTls13ValidatePskEarlyDataHttpBinding(
        plan.ticket.identity,
        expectedServerName,
        expectedAlpnProtocol
    )
    plan
}

public func contractTls13AcceptPskEarlyDataForHttpRequest(
    request: ContractTls13PskEarlyDataHttpAcceptRequest
): ContractTls13PskEarlyDataPlan {
    contractTls13AcceptPskEarlyDataForHttp(
        request.encodedClientHello,
        expectedServerName: request.expectedServerName,
        expectedAlpnProtocol: request.expectedAlpnProtocol,
        nowUnixSeconds: request.nowUnixSeconds,
        selectedIdentityIndex: request.selectedIdentityIndex,
        keyLen: request.keyLen,
        ivLen: request.ivLen
    )
}

public func contractTls13AcceptPskEarlyDataForHttpWithReplayCache(
    encodedClientHello: Array<Byte>,
    replayCache: ContractTls13EarlyDataReplayCache,
    expectedServerName!: String = "",
    expectedAlpnProtocol!: String = "",
    nowUnixSeconds!: Int64 = 0,
    selectedIdentityIndex!: Int64 = -1,
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12,
    replayTtlSeconds!: Int64 = 0
): ContractTls13PskEarlyDataPlan {
    let plan = contractTls13AcceptPskEarlyDataForHttp(
        encodedClientHello,
        expectedServerName: expectedServerName,
        expectedAlpnProtocol: expectedAlpnProtocol,
        nowUnixSeconds: nowUnixSeconds,
        selectedIdentityIndex: selectedIdentityIndex,
        keyLen: keyLen,
        ivLen: ivLen
    )
    contractTls13RememberEarlyDataReplayOrThrow(
        plan,
        replayCache,
        nowUnixSeconds,
        replayTtlSeconds
    )
    plan
}

public func contractTls13AcceptPskEarlyDataForHttpWithReplayCacheRequest(
    request: ContractTls13PskEarlyDataHttpAcceptWithReplayCacheRequest
): ContractTls13PskEarlyDataPlan {
    contractTls13AcceptPskEarlyDataForHttpWithReplayCache(
        request.encodedClientHello,
        request.replayCache,
        expectedServerName: request.expectedServerName,
        expectedAlpnProtocol: request.expectedAlpnProtocol,
        nowUnixSeconds: request.nowUnixSeconds,
        selectedIdentityIndex: request.selectedIdentityIndex,
        keyLen: request.keyLen,
        ivLen: request.ivLen,
        replayTtlSeconds: request.replayTtlSeconds
    )
}

private func contractTls13RememberEarlyDataReplayOrThrow(
    plan: ContractTls13PskEarlyDataPlan,
    replayCache: ContractTls13EarlyDataReplayCache,
    nowUnixSeconds: Int64,
    replayTtlSeconds: Int64
): Unit {
    let replayKey = contractTls13BuildPskEarlyDataReplayKey(plan)
    let replayNow = if (nowUnixSeconds > 0) {
        nowUnixSeconds
    } else {
        plan.ticket.issuedAtUnixSeconds
    }

    var effectiveReplayTtl = replayTtlSeconds
    if (effectiveReplayTtl <= 0) {
        let remainingLifetime = plan.ticket.expiresAtUnixSeconds - replayNow
        if (remainingLifetime > 0) {
            effectiveReplayTtl = remainingLifetime
        }
    }
    let accepted = replayCache.remember(
        replayKey,
        nowUnixSeconds: replayNow,
        ttlSeconds: effectiveReplayTtl
    )
    if (!accepted) {
        throw ContractException(ContractErrorCode.VerifyFailed, "TLS1.3 PSK early data replay detected")
    }
}

public func contractTls13BuildHttpClientHelloPskFromSessionTicket(
    ticket: ContractTlsSessionTicket,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    try {
        tls13BuildClientHelloPskFromSessionTicket(contractToTlsSessionTicket(ticket), sessionId: sessionId)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 PSK ClientHello build from session ticket failed: ${e.message}"
        )
    }
}

public func contractTls13BuildHttpClientHelloPskFromSessionTickets(
    tickets: Array<ContractTlsSessionTicket>,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    if (tickets.size == 0) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "TLS1.3 PSK ClientHello build from session ticket list requires at least one ticket"
        )
    }
    try {
        let tlsTickets = ArrayList<TlsSessionTicket>()
        for (ticket in tickets) {
            tlsTickets.add(contractToTlsSessionTicket(ticket))
        }
        tls13BuildClientHelloPskFromSessionTickets(tlsTickets.toArray(), sessionId: sessionId)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 PSK ClientHello build from session ticket list failed: ${e.message}"
        )
    }
}

public func contractTls13SelectPskIdentityFromSessionTickets(
    encodedClientHello: Array<Byte>,
    nowUnixSeconds!: Int64 = 0
): Int64 {
    try {
        tls13SelectPskIdentityFromSessionTickets(encodedClientHello, nowUnixSeconds: nowUnixSeconds)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 PSK session ticket identity selection failed: ${e.message}"
        )
    }
}

public func contractTls13BuildHttpServerHelloForPskFromSessionTicket(
    encodedClientHello: Array<Byte>,
    selectedIdentityIndex!: Int64 = 0,
    nowUnixSeconds!: Int64 = 0
): Array<Byte> {
    try {
        tls13BuildServerHelloForPskFromSessionTicket(
            encodedClientHello,
            selectedIdentityIndex: selectedIdentityIndex,
            nowUnixSeconds: nowUnixSeconds
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 PSK ServerHello build from session ticket failed: ${e.message}"
        )
    }
}

public func contractTls13BuildHttpServerHelloForPskBySessionTickets(
    encodedClientHello: Array<Byte>,
    nowUnixSeconds!: Int64 = 0
): Array<Byte> {
    try {
        tls13BuildServerHelloForPskBySessionTickets(encodedClientHello, nowUnixSeconds: nowUnixSeconds)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 PSK ServerHello build from session ticket list failed: ${e.message}"
        )
    }
}

public func contractTls13ExtractClientPskSessionTicket(
    encodedClientHello: Array<Byte>,
    selectedIdentityIndex!: Int64 = 0
): ContractTlsSessionTicket {
    try {
        let encodedTicket = tls13ExtractClientPskIdentity(
            encodedClientHello,
            selectedIdentityIndex: selectedIdentityIndex
        )
        contractFromTlsSessionTicket(tlsDecodeSessionTicket(encodedTicket))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 PSK session ticket extract failed: ${e.message}"
        )
    }
}

public func contractTls13ExtractServerSelectedPskIdentity(
    encodedServerHello: Array<Byte>
): Int64 {
    try {
        tls13ExtractServerSelectedPskIdentity(encodedServerHello)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 PSK selected identity extract failed: ${e.message}"
        )
    }
}

/** Proof-carrying HTTP client verification result. Construct through verifier helpers. */
public class ContractTls13HttpClientResult {
    public let selectedAlpn: String
    public let requestedServerName: String
    public let acknowledgedServerName: Bool
    public let chainLength: Int64
    public let leafSubjectCommonName: String
    public let trustAnchorCommonName: String
    public let leafDerSha256: Array<Byte>
    public let leafSpkiSha256: Array<Byte>
    public let keyMaterial: ContractTls13ApplicationKeyMaterial
    public let cipherBinding: ?ContractTls13CipherBinding

    internal init(
        selectedAlpn: String,
        requestedServerName: String,
        acknowledgedServerName: Bool,
        chainLength: Int64,
        leafSubjectCommonName: String,
        trustAnchorCommonName: String,
        leafDerSha256: Array<Byte>,
        leafSpkiSha256: Array<Byte>,
        keyMaterial: ContractTls13ApplicationKeyMaterial,
        cipherBinding!: ?ContractTls13CipherBinding = None
    ) {
        if (chainLength <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 verified chain length must be > 0")
        }
        requireSha256Pin(leafDerSha256, "leafDerSha256")
        requireSha256Pin(leafSpkiSha256, "leafSpkiSha256")
        this.selectedAlpn = selectedAlpn.trimAscii()
        this.requestedServerName = requestedServerName.trimAscii().toAsciiLower()
        this.acknowledgedServerName = acknowledgedServerName
        this.chainLength = chainLength
        this.leafSubjectCommonName = leafSubjectCommonName
        this.trustAnchorCommonName = trustAnchorCommonName
        this.leafDerSha256 = leafDerSha256.clone()
        this.leafSpkiSha256 = leafSpkiSha256.clone()
        this.keyMaterial = keyMaterial
        this.cipherBinding = cipherBinding
    }
}

/** Proof-carrying verified session. Construct through verifier helpers. */
public class ContractTls13HttpClientVerifiedSession {
    public let result: ContractTls13HttpClientResult
    public let clientAppTrafficSecret: Array<Byte>
    public let serverAppTrafficSecret: Array<Byte>
    public let masterSecret: Array<Byte>
    public let transcriptHash: Array<Byte>

    internal init(
        result: ContractTls13HttpClientResult,
        clientAppTrafficSecret: Array<Byte>,
        serverAppTrafficSecret: Array<Byte>,
        masterSecret: Array<Byte>,
        transcriptHash: Array<Byte>
    ) {
        if (
            clientAppTrafficSecret.size == 0 ||
            serverAppTrafficSecret.size == 0 ||
            masterSecret.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 verified session traffic/master secrets must not be empty"
            )
        }
        if (transcriptHash.size != 32) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 verified session transcript hash must be SHA-256 sized"
            )
        }
        this.result = result
        this.clientAppTrafficSecret = clientAppTrafficSecret.clone()
        this.serverAppTrafficSecret = serverAppTrafficSecret.clone()
        this.masterSecret = masterSecret.clone()
        this.transcriptHash = transcriptHash.clone()
    }
}

public class ContractTls13HttpClientVerifyOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractTls13HttpClientResult

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractTls13HttpClientResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 HTTP verify outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "TLS1.3 HTTP verify outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractTls13HttpClientVerifiedSessionOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractTls13HttpClientVerifiedSession

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractTls13HttpClientVerifiedSession = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 HTTP verified session outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "TLS1.3 HTTP verified session outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public class ContractTls13HttpVerifiedSessionRequest {
    public let session: ContractTls13HttpClientVerifiedSession

    public init(session: ContractTls13HttpClientVerifiedSession) {
        this.session = session
    }
}

public class ContractTls13HttpVerifiedSessionExportRequest {
    public let session: ContractTls13HttpClientVerifiedSession
    public let exporterLabel: String
    public let context: Array<Byte>
    public let outputLen: Int64

    public init(
        session: ContractTls13HttpClientVerifiedSession,
        exporterLabel: String,
        context!: Array<Byte> = [],
        outputLen!: Int64 = 32
    ) {
        if (exporterLabel.trimAscii().size == 0 || outputLen <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 verified session export request fields are invalid"
            )
        }
        this.session = session
        this.exporterLabel = exporterLabel.trimAscii()
        this.context = context.clone()
        this.outputLen = outputLen
    }
}

public class ContractTls13HttpVerifiedSessionKeyUpdateRequest {
    public let session: ContractTls13HttpClientVerifiedSession
    public let requestPeerUpdate: Bool

    public init(
        session: ContractTls13HttpClientVerifiedSession,
        requestPeerUpdate!: Bool = false
    ) {
        this.session = session
        this.requestPeerUpdate = requestPeerUpdate
    }
}

public class ContractTls13HttpVerifiedSessionPeerKeyUpdateRequest {
    public let session: ContractTls13HttpClientVerifiedSession
    public let encodedKeyUpdate: Array<Byte>

    public init(
        session: ContractTls13HttpClientVerifiedSession,
        encodedKeyUpdate: Array<Byte>
    ) {
        if (encodedKeyUpdate.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 verified session peer key update request must not be empty"
            )
        }
        this.session = session
        this.encodedKeyUpdate = encodedKeyUpdate.clone()
    }
}

/** Runtime channel set for a proof-carrying verified session. */
public class ContractTls13HttpVerifiedSessionChannelSet {
    public let session: ContractTls13HttpClientVerifiedSession
    public let clientChannel: ContractTlsRecordChannel
    public let serverChannel: ContractTlsRecordChannel

    internal init(
        session: ContractTls13HttpClientVerifiedSession,
        clientChannel: ContractTlsRecordChannel,
        serverChannel: ContractTlsRecordChannel
    ) {
        let binding = contractTls13ResolveCipherBindingFromVerifiedSession(session)
        if (clientChannel.version != ContractTlsVersion.Tls13 || serverChannel.version != ContractTlsVersion.Tls13) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 verified session channel set requires TLS1.3 record channels"
            )
        }
        if (clientChannel.algorithm != binding.algorithm || serverChannel.algorithm != binding.algorithm) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 verified session channel algorithms must match cipher binding"
            )
        }
        this.session = session
        this.clientChannel = clientChannel
        this.serverChannel = serverChannel
    }
}

public class ContractTls13HttpVerifiedSessionTrafficUpdateResult {
    public let encodedKeyUpdate: Array<Byte>
    public let requestPeerUpdate: Bool
    public let runtime: ContractTls13HttpVerifiedSessionChannelSet

    public init(
        encodedKeyUpdate: Array<Byte>,
        requestPeerUpdate: Bool,
        runtime: ContractTls13HttpVerifiedSessionChannelSet
    ) {
        if (encodedKeyUpdate.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 verified session traffic update handshake must not be empty"
            )
        }
        this.encodedKeyUpdate = encodedKeyUpdate.clone()
        this.requestPeerUpdate = requestPeerUpdate
        this.runtime = runtime
    }
}

public enum ContractTls13HttpClientSessionStatus <: Equatable<ContractTls13HttpClientSessionStatus> & ToString {
    | Ready
    | Blocked
    | Failed
    | Closed

    public operator func ==(right: ContractTls13HttpClientSessionStatus): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractTls13HttpClientSessionStatus): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Ready => 0
            case Blocked => 1
            case Failed => 2
            case Closed => 3
        }
    }

    public func toString(): String {
        match (this) {
            case Ready => "READY"
            case Blocked => "BLOCKED"
            case Failed => "FAILED"
            case Closed => "CLOSED"
        }
    }
}

/** Runtime carrier for a proof-carrying verified session. Construct through runtime helpers. */
public class ContractTls13HttpClientVerifiedSessionRuntime {
    public let status: ContractTls13HttpClientSessionStatus
    public let channelSet: ContractTls13HttpVerifiedSessionChannelSet
    public let closeReason: String

    internal init(
        status: ContractTls13HttpClientSessionStatus,
        channelSet: ContractTls13HttpVerifiedSessionChannelSet,
        closeReason!: String = ""
    ) {
        if (
            status == ContractTls13HttpClientSessionStatus.Ready &&
            channelSet.session.result.chainLength <= 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "ready TLS1.3 HTTP client session runtime requires verified chain metadata"
            )
        }
        this.status = status
        this.channelSet = channelSet
        this.closeReason = closeReason.trimAscii()
    }

    public prop secureSessionReady: Bool {
        get() {
            status == ContractTls13HttpClientSessionStatus.Ready
        }
    }

    public prop result: ContractTls13HttpClientResult {
        get() {
            channelSet.session.result
        }
    }
}

public class ContractTls13PskClientHelloFromCacheResult {
    public let ticket: ContractTlsSessionTicket
    public let encodedClientHello: Array<Byte>

    public init(ticket: ContractTlsSessionTicket, encodedClientHello: Array<Byte>) {
        if (encodedClientHello.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK ClientHello from cache must not be empty"
            )
        }
        this.ticket = ticket
        this.encodedClientHello = encodedClientHello.clone()
    }
}

public class ContractTls13PskClientHelloFromCacheOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractTls13PskClientHelloFromCacheResult
    public let lifecycle: ?ContractTls13SessionTicketLifecycleResult

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractTls13PskClientHelloFromCacheResult = None,
        lifecycle!: ?ContractTls13SessionTicketLifecycleResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 PSK cache outcome message must not be empty")
        }
        contractValidateOutcomeState(
            ok,
            code,
            igniteCode,
            result,
            "TLS1.3 PSK cache outcome result"
        )
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
        this.lifecycle = lifecycle
    }
}

public class ContractTls13PskEarlyDataPlan {
    public let selectedIdentityIndex: Int64
    public let ticket: ContractTlsSessionTicket
    public let encodedClientHello: Array<Byte>
    public let clientHelloHash: Array<Byte>
    public let clientEarlyTrafficSecret: Array<Byte>
    public let clientEarlyWriteKey: Array<Byte>
    public let clientEarlyWriteIv: Array<Byte>

    public init(
        selectedIdentityIndex: Int64,
        ticket: ContractTlsSessionTicket,
        encodedClientHello: Array<Byte>,
        clientHelloHash: Array<Byte>,
        clientEarlyTrafficSecret: Array<Byte>,
        clientEarlyWriteKey: Array<Byte>,
        clientEarlyWriteIv: Array<Byte>
    ) {
        if (selectedIdentityIndex < 0 || selectedIdentityIndex > 65535) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 selected identity index must be uint16")
        }
        if (encodedClientHello.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 PSK early data ClientHello must not be empty")
        }
        if (clientHelloHash.size != 32) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK early data ClientHello hash must be SHA-256 sized"
            )
        }
        if (
            clientEarlyTrafficSecret.size == 0 ||
            clientEarlyWriteKey.size == 0 ||
            clientEarlyWriteIv.size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK early data traffic secret and key material must not be empty"
            )
        }
        this.selectedIdentityIndex = selectedIdentityIndex
        this.ticket = ticket
        this.encodedClientHello = encodedClientHello.clone()
        this.clientHelloHash = clientHelloHash.clone()
        this.clientEarlyTrafficSecret = clientEarlyTrafficSecret.clone()
        this.clientEarlyWriteKey = clientEarlyWriteKey.clone()
        this.clientEarlyWriteIv = clientEarlyWriteIv.clone()
    }
}

public class ContractTls13PskEarlyDataFromSessionTicketRequest {
    public let ticket: ContractTlsSessionTicket
    public let sessionId: Array<Byte>
    public let keyLen: Int64
    public let ivLen: Int64

    public init(
        ticket: ContractTlsSessionTicket,
        sessionId!: Array<Byte> = [],
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12
    ) {
        if (keyLen <= 0 || ivLen <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK early data request key/iv lengths must be > 0"
            )
        }
        this.ticket = ticket
        this.sessionId = sessionId.clone()
        this.keyLen = keyLen
        this.ivLen = ivLen
    }
}

public class ContractTls13PskEarlyDataFromSessionCacheRequest {
    public let cache: ContractTlsSessionCache
    public let identity: ContractTlsSessionIdentity
    public let nowUnixSeconds: Int64
    public let sessionId: Array<Byte>
    public let keyLen: Int64
    public let ivLen: Int64

    public init(
        cache: ContractTlsSessionCache,
        identity: ContractTlsSessionIdentity,
        nowUnixSeconds!: Int64 = 0,
        sessionId!: Array<Byte> = [],
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12
    ) {
        if (keyLen <= 0 || ivLen <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK early data cache request key/iv lengths must be > 0"
            )
        }
        this.cache = cache
        this.identity = identity
        this.nowUnixSeconds = nowUnixSeconds
        this.sessionId = sessionId.clone()
        this.keyLen = keyLen
        this.ivLen = ivLen
    }
}

public class ContractTls13PskEarlyDataAcceptRequest {
    public let encodedClientHello: Array<Byte>
    public let nowUnixSeconds: Int64
    public let selectedIdentityIndex: Int64
    public let keyLen: Int64
    public let ivLen: Int64

    public init(
        encodedClientHello: Array<Byte>,
        nowUnixSeconds!: Int64 = 0,
        selectedIdentityIndex!: Int64 = -1,
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12
    ) {
        if (encodedClientHello.size == 0 || keyLen <= 0 || ivLen <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK early data accept request fields are invalid"
            )
        }
        this.encodedClientHello = encodedClientHello.clone()
        this.nowUnixSeconds = nowUnixSeconds
        this.selectedIdentityIndex = selectedIdentityIndex
        this.keyLen = keyLen
        this.ivLen = ivLen
    }
}

public class ContractTls13PskEarlyDataAcceptWithReplayCacheRequest {
    public let encodedClientHello: Array<Byte>
    public let replayCache: ContractTls13EarlyDataReplayCache
    public let nowUnixSeconds: Int64
    public let selectedIdentityIndex: Int64
    public let keyLen: Int64
    public let ivLen: Int64
    public let replayTtlSeconds: Int64

    public init(
        encodedClientHello: Array<Byte>,
        replayCache: ContractTls13EarlyDataReplayCache,
        nowUnixSeconds!: Int64 = 0,
        selectedIdentityIndex!: Int64 = -1,
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12,
        replayTtlSeconds!: Int64 = 0
    ) {
        if (encodedClientHello.size == 0 || keyLen <= 0 || ivLen <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 PSK early data replay-cache request fields are invalid"
            )
        }
        this.encodedClientHello = encodedClientHello.clone()
        this.replayCache = replayCache
        this.nowUnixSeconds = nowUnixSeconds
        this.selectedIdentityIndex = selectedIdentityIndex
        this.keyLen = keyLen
        this.ivLen = ivLen
        this.replayTtlSeconds = replayTtlSeconds
    }
}

public class ContractTls13PskEarlyDataHttpAcceptRequest {
    public let encodedClientHello: Array<Byte>
    public let expectedServerName: String
    public let expectedAlpnProtocol: String
    public let nowUnixSeconds: Int64
    public let selectedIdentityIndex: Int64
    public let keyLen: Int64
    public let ivLen: Int64

    public init(
        encodedClientHello: Array<Byte>,
        expectedServerName!: String = "",
        expectedAlpnProtocol!: String = "",
        nowUnixSeconds!: Int64 = 0,
        selectedIdentityIndex!: Int64 = -1,
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12
    ) {
        if (encodedClientHello.size == 0 || keyLen <= 0 || ivLen <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 HTTP early data accept request fields are invalid"
            )
        }
        this.encodedClientHello = encodedClientHello.clone()
        this.expectedServerName = expectedServerName.trimAscii().toAsciiLower()
        this.expectedAlpnProtocol = expectedAlpnProtocol.trimAscii().toAsciiLower()
        this.nowUnixSeconds = nowUnixSeconds
        this.selectedIdentityIndex = selectedIdentityIndex
        this.keyLen = keyLen
        this.ivLen = ivLen
    }
}

public class ContractTls13PskEarlyDataHttpAcceptWithReplayCacheRequest {
    public let encodedClientHello: Array<Byte>
    public let replayCache: ContractTls13EarlyDataReplayCache
    public let expectedServerName: String
    public let expectedAlpnProtocol: String
    public let nowUnixSeconds: Int64
    public let selectedIdentityIndex: Int64
    public let keyLen: Int64
    public let ivLen: Int64
    public let replayTtlSeconds: Int64

    public init(
        encodedClientHello: Array<Byte>,
        replayCache: ContractTls13EarlyDataReplayCache,
        expectedServerName!: String = "",
        expectedAlpnProtocol!: String = "",
        nowUnixSeconds!: Int64 = 0,
        selectedIdentityIndex!: Int64 = -1,
        keyLen!: Int64 = 16,
        ivLen!: Int64 = 12,
        replayTtlSeconds!: Int64 = 0
    ) {
        if (encodedClientHello.size == 0 || keyLen <= 0 || ivLen <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 HTTP early data replay-cache request fields are invalid"
            )
        }
        this.encodedClientHello = encodedClientHello.clone()
        this.replayCache = replayCache
        this.expectedServerName = expectedServerName.trimAscii().toAsciiLower()
        this.expectedAlpnProtocol = expectedAlpnProtocol.trimAscii().toAsciiLower()
        this.nowUnixSeconds = nowUnixSeconds
        this.selectedIdentityIndex = selectedIdentityIndex
        this.keyLen = keyLen
        this.ivLen = ivLen
        this.replayTtlSeconds = replayTtlSeconds
    }
}

public func contractMapCryptoErrorCode(code: CryptoErrorCode): ContractErrorCode {
    match (code) {
        case InvalidArgument => ContractErrorCode.BadInput
        case OutOfBounds => ContractErrorCode.BadInput
        case ParseError => ContractErrorCode.VerifyFailed
        case ComplianceRejected => ContractErrorCode.ComplianceRejected
        case Unsupported => ContractErrorCode.Unsupported
        case InternalError => ContractErrorCode.InternalError
        case _ => ContractErrorCode.InternalError
    }
}

public func contractMapToIgniteCryptoErrorCode(code: ContractErrorCode): ContractIgniteCryptoErrorCode {
    match (code) {
        case BadInput => ContractIgniteCryptoErrorCode.BadEnvelope
        case KeyNotFound => ContractIgniteCryptoErrorCode.KeyNotFound
        case VerifyFailed => ContractIgniteCryptoErrorCode.DecryptFailed
        case CryptoUnavailable => ContractIgniteCryptoErrorCode.CryptoUnavailable
        case ComplianceRejected => ContractIgniteCryptoErrorCode.CryptoUnavailable
        case Unsupported => ContractIgniteCryptoErrorCode.CryptoUnavailable
        case InternalError => ContractIgniteCryptoErrorCode.CryptoUnavailable
    }
}

public func contractMapExceptionToIgniteCryptoErrorCode(
    exception: ContractException
): ContractIgniteCryptoErrorCode {
    contractMapToIgniteCryptoErrorCode(exception.code)
}

public func contractMapCryptoExceptionToErrorCode(
    exception: CryptoException,
    operation!: String = ""
): ContractErrorCode {
    mapCryptoErrorForOperation(exception, operation)
}

public func contractMapCryptoExceptionToIgniteCryptoErrorCode(
    exception: CryptoException,
    operation!: String = ""
): ContractIgniteCryptoErrorCode {
    contractMapToIgniteCryptoErrorCode(contractMapCryptoExceptionToErrorCode(exception, operation: operation))
}

public func contractDescribeProviderErrorCode(
    code: ContractErrorCode,
    phase!: ContractProviderErrorPhase = ContractProviderErrorPhase.ProviderRuntime,
    detail!: String = ""
): ContractProviderErrorDescriptor {
    let family = contractMapProviderErrorFamily(code, phase)
    let normalizedDetail = if (detail.trimAscii().size == 0) {
        "provider error: ${family.toString()}"
    } else {
        detail.trimAscii()
    }
    ContractProviderErrorDescriptor(
        "jinguissl",
        family,
        phase,
        contractProviderErrorIsRetryable(family),
        contractProviderErrorSuggestsFallback(family),
        normalizedDetail,
        code: Some(code),
        igniteCode: Some(contractMapToIgniteCryptoErrorCode(code)),
    )
}

public func contractDescribeProviderContractException(
    exception: ContractException,
    phase!: ContractProviderErrorPhase = ContractProviderErrorPhase.ProviderRuntime
): ContractProviderErrorDescriptor {
    contractDescribeProviderErrorCode(
        exception.code,
        phase: phase,
        detail: exception.message
    )
}

public func contractDescribeProviderCryptoException(
    exception: CryptoException,
    phase!: ContractProviderErrorPhase = ContractProviderErrorPhase.ProviderRuntime,
    operation!: String = ""
): ContractProviderErrorDescriptor {
    let mapped = contractMapCryptoExceptionToErrorCode(exception, operation: operation)
    contractDescribeProviderErrorCode(
        mapped,
        phase: phase,
        detail: exception.message
    )
}

public func contractRecommendProviderFallback(
    error: ContractProviderErrorDescriptor
): ContractProviderFallbackDecision {
    let fallbackTarget = if (error.fallbackSuggested) {
        "stdx"
    } else {
        ""
    }
    let mustSurface = match (error.family) {
        case ContractProviderErrorFamily.BadInput => true
        case ContractProviderErrorFamily.VerifyFailed => true
        case ContractProviderErrorFamily.KeyNotFound => true
        case ContractProviderErrorFamily.ComplianceRejected => true
        case ContractProviderErrorFamily.TlsPrecheckError => true
        case ContractProviderErrorFamily.TlsVerifyError => true
        case _ => false
    }
    ContractProviderFallbackDecision(
        error.providerId,
        error.fallbackSuggested,
        fallbackTarget,
        error.retryable,
        mustSurface,
        contractProviderFallbackReason(error)
    )
}

public func contractRandomAvailable(): Bool {
    csprngIsAvailable()
}

public func contractRandomBytes(size: Int64): Array<Byte> {
    if (size <= 0) {
        throw ContractException(ContractErrorCode.BadInput, "random byte size must be > 0")
    }
    if (!csprngIsAvailable()) {
        throw ContractException(ContractErrorCode.CryptoUnavailable, "system CSPRNG is unavailable")
    }
    try {
        csprngBytes(size)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "random"),
            "random generation failed: ${e.message}"
        )
    }
}

public func contractRandomUInt8Bytes(size: Int64): Array<UInt8> {
    toUInt8Array(contractRandomBytes(size))
}

public func contractHkdfExtract(
    hash: ContractKdfHash,
    salt: Array<Byte>,
    ikm: Array<Byte>
): Array<Byte> {
    try {
        hkdfExtract(contractToHashAlgorithm(hash), salt, ikm)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "kdf"),
            "HKDF extract failed: ${e.message}"
        )
    }
}

public func contractHkdfExpand(
    hash: ContractKdfHash,
    prk: Array<Byte>,
    info: Array<Byte>,
    outputLen: Int64
): Array<Byte> {
    try {
        hkdfExpand(contractToHashAlgorithm(hash), prk, info, outputLen)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "kdf"),
            "HKDF expand failed: ${e.message}"
        )
    }
}

public func contractHkdf(
    hash: ContractKdfHash,
    ikm: Array<Byte>,
    info: Array<Byte>,
    outputLen: Int64,
    salt!: Array<Byte> = []
): Array<Byte> {
    try {
        hkdf(contractToHashAlgorithm(hash), ikm, info, outputLen, salt: salt)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "kdf"),
            "HKDF derive failed: ${e.message}"
        )
    }
}

public class ContractHkdfHttpSshKeySet {
    public let httpRequestKey: Array<Byte>
    public let httpResponseKey: Array<Byte>
    public let sshClientToServerKey: Array<Byte>
    public let sshServerToClientKey: Array<Byte>

    public init(
        httpRequestKey: Array<Byte>,
        httpResponseKey: Array<Byte>,
        sshClientToServerKey: Array<Byte>,
        sshServerToClientKey: Array<Byte>
    ) {
        if (
            httpRequestKey.size == 0 ||
            httpResponseKey.size == 0 ||
            sshClientToServerKey.size == 0 ||
            sshServerToClientKey.size == 0
        ) {
            throw ContractException(ContractErrorCode.BadInput, "HKDF key set entries must not be empty")
        }
        this.httpRequestKey = httpRequestKey.clone()
        this.httpResponseKey = httpResponseKey.clone()
        this.sshClientToServerKey = sshClientToServerKey.clone()
        this.sshServerToClientKey = sshServerToClientKey.clone()
    }
}

public func contractHkdfDeriveHttpSshKeySet(
    ikm: Array<Byte>,
    contextId!: String = "",
    outputLen!: Int64 = 32,
    salt!: Array<Byte> = []
): ContractHkdfHttpSshKeySet {
    let normalizedContextId = contextId.trimAscii().toAsciiLower()
    let suffix = if (normalizedContextId.size > 0) {
        "|${normalizedContextId}"
    } else {
        ""
    }
    ContractHkdfHttpSshKeySet(
        contractHkdf(ContractKdfHash.Sha256, ikm, "jinkui/http/request${suffix}".toArray(), outputLen, salt: salt),
        contractHkdf(ContractKdfHash.Sha256, ikm, "jinkui/http/response${suffix}".toArray(), outputLen, salt: salt),
        contractHkdf(ContractKdfHash.Sha256, ikm, "jinkui/ssh/c2s${suffix}".toArray(), outputLen, salt: salt),
        contractHkdf(ContractKdfHash.Sha256, ikm, "jinkui/ssh/s2c${suffix}".toArray(), outputLen, salt: salt)
    )
}

public func contractEncryptEnvelopeV1(
    algorithm: ContractAeadAlgorithm,
    kid: String,
    key: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = []
): ContractAeadEnvelopeV1 {
    let normalizedKid = kid.trimAscii()
    requireTokenAscii(normalizedKid, "kid")
    if (plaintext.size == 0) {
        throw ContractException(ContractErrorCode.BadInput, "plaintext must not be empty")
    }

    let nonce = contractRandomBytes(12)
    let (ciphertext, tag) = contractEncryptAead(algorithm, key, nonce, plaintext, aad)
    ContractAeadEnvelopeV1(
        1,
        algorithm.toString(),
        normalizedKid,
        base64UrlEncode(nonce),
        base64UrlEncode(aad),
        base64UrlEncode(ciphertext),
        base64UrlEncode(tag)
    )
}

public func contractEncryptEnvelopeJsonV1(
    algorithm: ContractAeadAlgorithm,
    kid: String,
    key: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = []
): String {
    contractEncryptEnvelopeV1(algorithm, kid, key, plaintext, aad: aad).toJsonString()
}

public func contractEncryptEnvelopeJsonLegacyV1(
    algorithm: ContractAeadAlgorithm,
    kid: String,
    key: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = []
): String {
    let envelope = contractEncryptEnvelopeV1(algorithm, kid, key, plaintext, aad: aad)
    contractEnvelopeToLegacyJsonV1(envelope)
}

public func contractDecryptEnvelopeV1(
    envelope: ContractAeadEnvelopeV1,
    keyRing: HashMap<String, Array<Byte>>,
    aadOverride!: ?Array<Byte> = None
): Array<Byte> {
    match (keyRing.get(envelope.kid)) {
        case Some(key) =>
            let nonce = decodeEnvelopeField(envelope.nonce, "nonce")
            let ciphertext = decodeEnvelopeField(envelope.ciphertext, "ciphertext")
            let tag = decodeEnvelopeField(envelope.tag, "tag")
            let aad = if (let Some(override) <- aadOverride) {
                override
            } else {
                decodeEnvelopeField(envelope.aad, "aad")
            }
            contractDecryptAead(envelope.algorithm(), key, nonce, ciphertext, tag, aad)
        case None =>
            throw ContractException(ContractErrorCode.KeyNotFound, "envelope key id is not found: ${envelope.kid}")
    }
}

public func contractDecryptEnvelopeJsonV1(
    envelopeJson: String,
    keyRing: HashMap<String, Array<Byte>>,
    aadOverride!: ?Array<Byte> = None
): Array<Byte> {
    let envelope = ContractAeadEnvelopeV1.parseJson(envelopeJson)
    contractDecryptEnvelopeV1(envelope, keyRing, aadOverride: aadOverride)
}

public func contractDecryptEnvelopeJsonCompatV1(
    envelopeJson: String,
    keyRing: HashMap<String, Array<Byte>>,
    aadOverride!: ?Array<Byte> = None
): Array<Byte> {
    let envelope = contractParseEnvelopeJsonCompatV1(envelopeJson)
    contractDecryptEnvelopeV1(envelope, keyRing, aadOverride: aadOverride)
}

public func contractTryDecryptEnvelopeV1(
    envelope: ContractAeadEnvelopeV1,
    keyRing: HashMap<String, Array<Byte>>,
    aadOverride!: ?Array<Byte> = None
): ContractEnvelopeOpenOutcome {
    try {
        let plaintext = contractDecryptEnvelopeV1(envelope, keyRing, aadOverride: aadOverride)
        ContractEnvelopeOpenOutcome(true, "OK", plaintext: Some(plaintext))
    } catch (e: ContractException) {
        ContractEnvelopeOpenOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryDecryptEnvelopeJsonV1(
    envelopeJson: String,
    keyRing: HashMap<String, Array<Byte>>,
    aadOverride!: ?Array<Byte> = None
): ContractEnvelopeOpenOutcome {
    try {
        let plaintext = contractDecryptEnvelopeJsonV1(envelopeJson, keyRing, aadOverride: aadOverride)
        ContractEnvelopeOpenOutcome(true, "OK", plaintext: Some(plaintext))
    } catch (e: ContractException) {
        ContractEnvelopeOpenOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryDecryptEnvelopeJsonCompatV1(
    envelopeJson: String,
    keyRing: HashMap<String, Array<Byte>>,
    aadOverride!: ?Array<Byte> = None
): ContractEnvelopeOpenOutcome {
    try {
        let plaintext = contractDecryptEnvelopeJsonCompatV1(envelopeJson, keyRing, aadOverride: aadOverride)
        ContractEnvelopeOpenOutcome(true, "OK", plaintext: Some(plaintext))
    } catch (e: ContractException) {
        ContractEnvelopeOpenOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractEncryptEnvelopeJsonV1UInt8(
    algorithm: ContractAeadAlgorithm,
    kid: String,
    key: Array<UInt8>,
    plaintext: Array<UInt8>,
    aad!: Array<UInt8> = []
): String {
    contractEncryptEnvelopeJsonV1(
        algorithm,
        kid,
        toByteArray(key),
        toByteArray(plaintext),
        aad: toByteArray(aad)
    )
}

public func contractDecryptEnvelopeJsonV1UInt8(
    envelopeJson: String,
    keyRing: HashMap<String, Array<UInt8>>,
    aadOverride!: ?Array<UInt8> = None
): Array<UInt8> {
    let byteKeyRing = HashMap<String, Array<Byte>>()
    for ((kid, key) in keyRing) {
        byteKeyRing.add(kid, toByteArray(key))
    }

    let byteAadOverride: ?Array<Byte> = if (let Some(value) <- aadOverride) {
        Some(toByteArray(value))
    } else {
        None
    }
    toUInt8Array(contractDecryptEnvelopeJsonV1(envelopeJson, byteKeyRing, aadOverride: byteAadOverride))
}

public func contractDecryptEnvelopeJsonCompatV1UInt8(
    envelopeJson: String,
    keyRing: HashMap<String, Array<UInt8>>,
    aadOverride!: ?Array<UInt8> = None
): Array<UInt8> {
    let byteKeyRing = HashMap<String, Array<Byte>>()
    for ((kid, key) in keyRing) {
        byteKeyRing.add(kid, toByteArray(key))
    }

    let byteAadOverride: ?Array<Byte> = if (let Some(value) <- aadOverride) {
        Some(toByteArray(value))
    } else {
        None
    }
    toUInt8Array(contractDecryptEnvelopeJsonCompatV1(envelopeJson, byteKeyRing, aadOverride: byteAadOverride))
}

public func contractComputeLeafPinsFromPem(leafPem: String): (Array<Byte>, Array<Byte>) {
    try {
        let leaf = x509ParsePem(leafPem)
        (sha256(leaf.der), sha256(leaf.subjectPublicKeyInfoDer))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "x509"),
            "failed to compute certificate pins: ${e.message}"
        )
    }
}

public func contractVerifyServerCertificatePem(
    leafPem: String,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy()
): ContractX509VerifyResult {
    try {
        let leaf = x509ParsePem(leafPem)
        let intermediates: Array<X509Certificate> = if (intermediatesPemBundle.trimAscii().size == 0) {
            []
        } else {
            x509ParsePemChain(intermediatesPemBundle)
        }
        contractVerifyServerCertificateParsed(
            leaf,
            trustAnchorsPemBundle,
            intermediates,
            hostname,
            validationTime,
            pinPolicy
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "x509"),
            "certificate verification failed: ${e.message}"
        )
    }
}

public func contractTryVerifyServerCertificatePem(
    leafPem: String,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy()
): ContractX509VerifyOutcome {
    try {
        let result = contractVerifyServerCertificatePem(
            leafPem,
            trustAnchorsPemBundle,
            intermediatesPemBundle: intermediatesPemBundle,
            hostname: hostname,
            validationTime: validationTime,
            pinPolicy: pinPolicy
        )
        ContractX509VerifyOutcome(
            true,
            ContractErrorCode.VerifyFailed,
            "OK",
            result: Some(result)
        )
    } catch (e: ContractException) {
        ContractX509VerifyOutcome(
            false,
            e.code,
            e.message,
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code)),
            result: None
        )
    }
}

public func contractVerifyServerCertificateChainPem(
    certificateChainPemBundle: String,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy()
): ContractX509VerifyResult {
    try {
        let chain = x509ParsePemChain(certificateChainPemBundle)
        if (chain.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "certificate chain PEM bundle must not be empty")
        }

        let leaf = chain[0]
        let mergedIntermediates = ArrayList<X509Certificate>()
        var index = 1
        while (index < chain.size) {
            mergedIntermediates.add(chain[index])
            index += 1
        }
        if (intermediatesPemBundle.trimAscii().size > 0) {
            let extraIntermediates = x509ParsePemChain(intermediatesPemBundle)
            for (certificate in extraIntermediates) {
                mergedIntermediates.add(certificate)
            }
        }

        contractVerifyServerCertificateParsed(
            leaf,
            trustAnchorsPemBundle,
            mergedIntermediates.toArray(),
            hostname,
            validationTime,
            pinPolicy
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "x509"),
            "certificate chain verification failed: ${e.message}"
        )
    }
}

public func contractTryVerifyServerCertificateChainPem(
    certificateChainPemBundle: String,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy()
): ContractX509VerifyOutcome {
    try {
        let result = contractVerifyServerCertificateChainPem(
            certificateChainPemBundle,
            trustAnchorsPemBundle,
            intermediatesPemBundle: intermediatesPemBundle,
            hostname: hostname,
            validationTime: validationTime,
            pinPolicy: pinPolicy
        )
        ContractX509VerifyOutcome(
            true,
            ContractErrorCode.VerifyFailed,
            "OK",
            result: Some(result)
        )
    } catch (e: ContractException) {
        ContractX509VerifyOutcome(
            false,
            e.code,
            e.message,
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code)),
            result: None
        )
    }
}

public func contractValidateHttpServerTlsConfigInput(
    certificateChainPem: String,
    privateKeyPem: String,
    alpnProtocols!: Array<String> = ["h2", "http/1.1"],
    requireHttp2Alpn!: Bool = true
): ContractHttpServerTlsConfigValidationResult {
    try {
        let certChain = x509ParsePemChain(certificateChainPem)
        if (certChain.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS certificate chain PEM must not be empty")
        }
        let normalizedAlpn = contractNormalizeAlpnProtocols(alpnProtocols)
        if (requireHttp2Alpn && !contractContainsString(normalizedAlpn, "h2")) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS ALPN protocols must include h2 when requireHttp2Alpn is true"
            )
        }
        let keyAlgorithm = contractValidateLeafCertificateAndPrivateKeyMatch(certChain[0], privateKeyPem)
        ContractHttpServerTlsConfigValidationResult(
            certChain.size,
            certChain[0].subject.commonName(),
            certChain[0].issuer.commonName(),
            keyAlgorithm,
            normalizedAlpn
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "x509"),
            "TLS server config input validation failed: ${e.message}"
        )
    }
}

public func contractValidateHttpServerTlsConfigRequest(
    request: ContractHttpServerTlsConfigRequest
): ContractHttpServerTlsConfigValidationResult {
    contractValidateHttpServerTlsConfigInput(
        request.certificateChainPem,
        request.privateKeyPem,
        alpnProtocols: request.alpnProtocols,
        requireHttp2Alpn: request.requireHttp2Alpn
    )
}

public func contractTryValidateHttpServerTlsConfigInput(
    certificateChainPem: String,
    privateKeyPem: String,
    alpnProtocols!: Array<String> = ["h2", "http/1.1"],
    requireHttp2Alpn!: Bool = true
): ContractHttpServerTlsConfigValidationOutcome {
    try {
        let result = contractValidateHttpServerTlsConfigInput(
            certificateChainPem,
            privateKeyPem,
            alpnProtocols: alpnProtocols,
            requireHttp2Alpn: requireHttp2Alpn
        )
        ContractHttpServerTlsConfigValidationOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpServerTlsConfigValidationOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryValidateHttpServerTlsConfigRequest(
    request: ContractHttpServerTlsConfigRequest
): ContractHttpServerTlsConfigValidationOutcome {
    try {
        let result = contractValidateHttpServerTlsConfigRequest(request)
        ContractHttpServerTlsConfigValidationOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpServerTlsConfigValidationOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareHttpServerTlsMaterial(
    certificateChainPem: String,
    privateKeyPem: String,
    alpnProtocols!: Array<String> = ["h2", "http/1.1"],
    requireHttp2Alpn!: Bool = true
): ContractHttpServerTlsMaterial {
    try {
        let validation = contractValidateHttpServerTlsConfigInput(
            certificateChainPem,
            privateKeyPem,
            alpnProtocols: alpnProtocols,
            requireHttp2Alpn: requireHttp2Alpn
        )
        let certChain = x509ParsePemChain(certificateChainPem)
        ContractHttpServerTlsMaterial(
            validation,
            contractCertificatesToPemBlocks(certChain),
            privateKeyPem
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "x509"),
            "TLS server material preparation failed: ${e.message}"
        )
    }
}

public func contractPrepareHttpServerTlsMaterialRequest(
    request: ContractHttpServerTlsConfigRequest
): ContractHttpServerTlsMaterial {
    contractPrepareHttpServerTlsMaterial(
        request.certificateChainPem,
        request.privateKeyPem,
        alpnProtocols: request.alpnProtocols,
        requireHttp2Alpn: request.requireHttp2Alpn
    )
}

public func contractTryPrepareHttpServerTlsMaterial(
    certificateChainPem: String,
    privateKeyPem: String,
    alpnProtocols!: Array<String> = ["h2", "http/1.1"],
    requireHttp2Alpn!: Bool = true
): ContractHttpServerTlsMaterialOutcome {
    try {
        let result = contractPrepareHttpServerTlsMaterial(
            certificateChainPem,
            privateKeyPem,
            alpnProtocols: alpnProtocols,
            requireHttp2Alpn: requireHttp2Alpn
        )
        ContractHttpServerTlsMaterialOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpServerTlsMaterialOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryPrepareHttpServerTlsMaterialRequest(
    request: ContractHttpServerTlsConfigRequest
): ContractHttpServerTlsMaterialOutcome {
    try {
        let result = contractPrepareHttpServerTlsMaterialRequest(request)
        ContractHttpServerTlsMaterialOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpServerTlsMaterialOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractValidateHttpClientTlsConfigInput(
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractHttpClientTlsConfigValidationResult {
    try {
        let anchors = x509ParsePemChain(trustAnchorsPemBundle)
        if (anchors.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS client trust anchors PEM bundle must not be empty")
        }
        let intermediates: Array<X509Certificate> = if (intermediatesPemBundle.trimAscii().size == 0) {
            []
        } else {
            x509ParsePemChain(intermediatesPemBundle)
        }
        let x509Policy = X509VerificationPolicy(
            anchors,
            intermediates: intermediates,
            requiredLeafDnsName: hostname,
            validationTime: validationTime
        )
        let validatedPolicy = contractValidateTlsHttpNegotiationPolicy(policy: policy)
        if (
            x509Policy.requiredLeafDnsName.size > 0 &&
            validatedPolicy.normalizedAllowedServerNames.size > 0 &&
            !contractContainsString(
                validatedPolicy.normalizedAllowedServerNames,
                x509Policy.requiredLeafDnsName
            )
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS client hostname must be included in allowed server names when both are configured"
            )
        }
        ContractHttpClientTlsConfigValidationResult(
            anchors.size,
            intermediates.size,
            x509Policy.requiredLeafDnsName,
            x509Policy.validationTime.size > 0,
            pinPolicy.allowedLeafDerSha256.size,
            pinPolicy.allowedLeafSpkiSha256.size,
            validatedPolicy
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS client config validation failed: ${e.message}"
        )
    }
}

public func contractValidateHttpClientTlsTrustRequest(
    request: ContractHttpClientTlsTrustRequest
): ContractHttpClientTlsConfigValidationResult {
    contractValidateHttpClientTlsConfigInput(
        request.trustAnchorsPemBundle,
        intermediatesPemBundle: request.intermediatesPemBundle,
        hostname: request.hostname,
        validationTime: request.validationTime,
        pinPolicy: request.pinPolicy,
        policy: request.policy
    )
}

public func contractPrepareHttpClientTlsTrustMaterial(
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractHttpClientTlsTrustMaterial {
    try {
        let validation = contractValidateHttpClientTlsConfigInput(
            trustAnchorsPemBundle,
            intermediatesPemBundle: intermediatesPemBundle,
            hostname: hostname,
            validationTime: validationTime,
            pinPolicy: pinPolicy,
            policy: policy
        )
        let anchors = x509ParsePemChain(trustAnchorsPemBundle)
        let intermediates: Array<X509Certificate> = if (intermediatesPemBundle.trimAscii().size == 0) {
            []
        } else {
            x509ParsePemChain(intermediatesPemBundle)
        }
        ContractHttpClientTlsTrustMaterial(
            validation,
            contractCertificatesToPemBlocks(anchors),
            intermediatePemBlocks: contractCertificatesToPemBlocks(intermediates),
            validationTime: validationTime,
            pinPolicy: pinPolicy
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "x509"),
            "TLS client trust material preparation failed: ${e.message}"
        )
    }
}

public func contractPrepareHttpClientTlsTrustMaterialRequest(
    request: ContractHttpClientTlsTrustRequest
): ContractHttpClientTlsTrustMaterial {
    contractPrepareHttpClientTlsTrustMaterial(
        request.trustAnchorsPemBundle,
        intermediatesPemBundle: request.intermediatesPemBundle,
        hostname: request.hostname,
        validationTime: request.validationTime,
        pinPolicy: request.pinPolicy,
        policy: request.policy
    )
}

public func contractTryPrepareHttpClientTlsTrustMaterial(
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractHttpClientTlsTrustMaterialOutcome {
    try {
        let result = contractPrepareHttpClientTlsTrustMaterial(
            trustAnchorsPemBundle,
            intermediatesPemBundle: intermediatesPemBundle,
            hostname: hostname,
            validationTime: validationTime,
            pinPolicy: pinPolicy,
            policy: policy
        )
        ContractHttpClientTlsTrustMaterialOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpClientTlsTrustMaterialOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryPrepareHttpClientTlsTrustMaterialRequest(
    request: ContractHttpClientTlsTrustRequest
): ContractHttpClientTlsTrustMaterialOutcome {
    try {
        let result = contractPrepareHttpClientTlsTrustMaterialRequest(request)
        ContractHttpClientTlsTrustMaterialOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpClientTlsTrustMaterialOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryValidateHttpClientTlsConfigInput(
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractHttpClientTlsConfigValidationOutcome {
    try {
        let result = contractValidateHttpClientTlsConfigInput(
            trustAnchorsPemBundle,
            intermediatesPemBundle: intermediatesPemBundle,
            hostname: hostname,
            validationTime: validationTime,
            pinPolicy: pinPolicy,
            policy: policy
        )
        ContractHttpClientTlsConfigValidationOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpClientTlsConfigValidationOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryValidateHttpClientTlsTrustRequest(
    request: ContractHttpClientTlsTrustRequest
): ContractHttpClientTlsConfigValidationOutcome {
    try {
        let result = contractValidateHttpClientTlsTrustRequest(request)
        ContractHttpClientTlsConfigValidationOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractHttpClientTlsConfigValidationOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractVerifyHttpClientPeerCertificatePem(
    leafPem: String,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractX509VerifyResult {
    let validated = contractValidateHttpClientTlsConfigInput(
        trustAnchorsPemBundle,
        intermediatesPemBundle: intermediatesPemBundle,
        hostname: hostname,
        validationTime: validationTime,
        pinPolicy: pinPolicy,
        policy: policy
    )
    contractVerifyServerCertificatePem(
        leafPem,
        trustAnchorsPemBundle,
        intermediatesPemBundle: intermediatesPemBundle,
        hostname: validated.normalizedHostname,
        validationTime: validationTime,
        pinPolicy: pinPolicy
    )
}

public func contractVerifyHttpClientPeerCertificatePemRequest(
    request: ContractHttpClientTlsPeerPemRequest
): ContractX509VerifyResult {
    contractVerifyHttpClientPeerCertificatePem(
        request.leafPem,
        request.trust.trustAnchorsPemBundle,
        intermediatesPemBundle: request.trust.intermediatesPemBundle,
        hostname: request.trust.hostname,
        validationTime: request.trust.validationTime,
        pinPolicy: request.trust.pinPolicy,
        policy: request.trust.policy
    )
}

public func contractTryVerifyHttpClientPeerCertificatePem(
    leafPem: String,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractX509VerifyOutcome {
    try {
        let result = contractVerifyHttpClientPeerCertificatePem(
            leafPem,
            trustAnchorsPemBundle,
            intermediatesPemBundle: intermediatesPemBundle,
            hostname: hostname,
            validationTime: validationTime,
            pinPolicy: pinPolicy,
            policy: policy
        )
        ContractX509VerifyOutcome(
            true,
            ContractErrorCode.VerifyFailed,
            "OK",
            result: Some(result)
        )
    } catch (e: ContractException) {
        ContractX509VerifyOutcome(
            false,
            e.code,
            e.message,
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code)),
            result: None
        )
    }
}

public func contractTryVerifyHttpClientPeerCertificatePemRequest(
    request: ContractHttpClientTlsPeerPemRequest
): ContractX509VerifyOutcome {
    try {
        let result = contractVerifyHttpClientPeerCertificatePemRequest(request)
        ContractX509VerifyOutcome(
            true,
            ContractErrorCode.VerifyFailed,
            "OK",
            result: Some(result)
        )
    } catch (e: ContractException) {
        ContractX509VerifyOutcome(
            false,
            e.code,
            e.message,
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code)),
            result: None
        )
    }
}

public func contractVerifyHttpClientPeerCertificateChainPem(
    certificateChainPemBundle: String,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractX509VerifyResult {
    let validated = contractValidateHttpClientTlsConfigInput(
        trustAnchorsPemBundle,
        intermediatesPemBundle: intermediatesPemBundle,
        hostname: hostname,
        validationTime: validationTime,
        pinPolicy: pinPolicy,
        policy: policy
    )
    contractVerifyServerCertificateChainPem(
        certificateChainPemBundle,
        trustAnchorsPemBundle,
        intermediatesPemBundle: intermediatesPemBundle,
        hostname: validated.normalizedHostname,
        validationTime: validationTime,
        pinPolicy: pinPolicy
    )
}

public func contractVerifyHttpClientPeerCertificateChainPemRequest(
    request: ContractHttpClientTlsPeerChainRequest
): ContractX509VerifyResult {
    contractVerifyHttpClientPeerCertificateChainPem(
        request.certificateChainPemBundle,
        request.trust.trustAnchorsPemBundle,
        intermediatesPemBundle: request.trust.intermediatesPemBundle,
        hostname: request.trust.hostname,
        validationTime: request.trust.validationTime,
        pinPolicy: request.trust.pinPolicy,
        policy: request.trust.policy
    )
}

public func contractTryVerifyHttpClientPeerCertificateChainPem(
    certificateChainPemBundle: String,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractX509VerifyOutcome {
    try {
        let result = contractVerifyHttpClientPeerCertificateChainPem(
            certificateChainPemBundle,
            trustAnchorsPemBundle,
            intermediatesPemBundle: intermediatesPemBundle,
            hostname: hostname,
            validationTime: validationTime,
            pinPolicy: pinPolicy,
            policy: policy
        )
        ContractX509VerifyOutcome(
            true,
            ContractErrorCode.VerifyFailed,
            "OK",
            result: Some(result)
        )
    } catch (e: ContractException) {
        ContractX509VerifyOutcome(
            false,
            e.code,
            e.message,
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code)),
            result: None
        )
    }
}

public func contractTryVerifyHttpClientPeerCertificateChainPemRequest(
    request: ContractHttpClientTlsPeerChainRequest
): ContractX509VerifyOutcome {
    try {
        let result = contractVerifyHttpClientPeerCertificateChainPemRequest(request)
        ContractX509VerifyOutcome(
            true,
            ContractErrorCode.VerifyFailed,
            "OK",
            result: Some(result)
        )
    } catch (e: ContractException) {
        ContractX509VerifyOutcome(
            false,
            e.code,
            e.message,
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code)),
            result: None
        )
    }
}

public func contractTls12BuildHttpClientHello(
    keyExchange: ContractTls12KeyExchange,
    sessionId!: Array<Byte> = [],
    serverName!: String = "",
    alpnProtocols!: Array<String> = [],
    requestOcspStapling!: Bool = false
): ContractTls12ClientHello {
    try {
        let encoded = tls12BuildClientHello(
            contractToTls12KeyExchange(keyExchange),
            sessionId: sessionId,
            serverName: serverName,
            alpnProtocols: alpnProtocols,
            requestOcspStapling: requestOcspStapling
        )
        let clientRandom = tls12ExtractClientRandom(encoded)
        ContractTls12ClientHello(encoded, clientRandom)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 HTTP ClientHello build failed: ${e.message}"
        )
    }
}

public func contractTls12BuildHttpClientHelloRequest(
    request: ContractTls12HttpClientHelloRequest
): ContractTls12ClientHello {
    contractTls12BuildHttpClientHello(
        request.keyExchange,
        sessionId: request.sessionId,
        serverName: request.serverName,
        alpnProtocols: request.alpnProtocols,
        requestOcspStapling: request.requestOcspStapling
    )
}

public func contractTls12BuildHttpServerHello(
    encodedClientHello: Array<Byte>,
    keyExchange: ContractTls12KeyExchange
): ContractTls12ServerHello {
    try {
        let encoded = tls12BuildServerHello(
            encodedClientHello,
            contractToTls12KeyExchange(keyExchange)
        )
        let serverRandom = tls12ExtractServerRandom(encoded)
        ContractTls12ServerHello(encoded, serverRandom)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 HTTP ServerHello build failed: ${e.message}"
        )
    }
}

public func contractTls12BuildHttpServerHelloRequest(
    request: ContractTls12HttpServerHelloRequest
): ContractTls12ServerHello {
    contractTls12BuildHttpServerHello(
        request.encodedClientHello,
        request.keyExchange
    )
}

public func contractTls12BuildCertificateHandshakeFromPemChain(
    certChainPemBundle: String
): Array<Byte> {
    try {
        let certChain = x509ParsePemChain(certChainPemBundle)
        if (certChain.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 certificate chain PEM bundle must not be empty")
        }
        let certChainDer = contractDerChainFromCertificates(certChain)
        tls12BuildCertificateHandshakeFromDerChain(certChainDer)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 certificate handshake build failed: ${e.message}"
        )
    }
}

public func contractTls12BuildCertificateHandshakeFromPemChainRequest(
    request: ContractTls12CertificateHandshakeFromPemChainRequest
): Array<Byte> {
    contractTls12BuildCertificateHandshakeFromPemChain(request.certChainPemBundle)
}

public func contractTls12VerifyCertificateHandshakeForHttp(
    encodedCertificateHandshake: Array<Byte>,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy()
): ContractX509VerifyResult {
    try {
        let anchors = x509ParsePemChain(trustAnchorsPemBundle)
        let intermediates: Array<X509Certificate> = if (intermediatesPemBundle.trimAscii().size == 0) {
            []
        } else {
            x509ParsePemChain(intermediatesPemBundle)
        }
        let policy = X509VerificationPolicy(
            anchors,
            intermediates: intermediates,
            requiredLeafDnsName: hostname,
            validationTime: validationTime
        )
        let verified = tls12VerifyCertificateChainFromHandshake(encodedCertificateHandshake, policy)
        let leaf = verified.chain[0]
        let leafDerSha = sha256(leaf.der)
        let leafSpkiSha = sha256(leaf.subjectPublicKeyInfoDer)
        contractRequirePinPolicy(pinPolicy, leafDerSha, leafSpkiSha)

        ContractX509VerifyResult(
            verified.chain.size,
            leaf.subject.commonName(),
            leaf.issuer.commonName(),
            verified.trustAnchor.subject.commonName(),
            leafDerSha,
            leafSpkiSha
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 certificate handshake verification failed: ${e.message}"
        )
    }
}

public func contractTls12VerifyCertificateHandshakeForHttpRequest(
    request: ContractTls12VerifyCertificateHandshakeForHttpRequest
): ContractX509VerifyResult {
    contractTls12VerifyCertificateHandshakeForHttp(
        request.encodedCertificateHandshake,
        request.trust.trustAnchorsPemBundle,
        intermediatesPemBundle: request.trust.intermediatesPemBundle,
        hostname: request.trust.hostname,
        validationTime: request.trust.validationTime,
        pinPolicy: request.trust.pinPolicy
    )
}

public func contractTls12BuildRsaClientKeyExchangeFromLeafPem(
    serverLeafPem: String
): ContractTls12RsaClientKeyExchange {
    try {
        let leaf = x509ParsePem(serverLeafPem)
        let rsaPublicKey = x509ExtractRsaPublicKey(leaf)
        let (encodedClientKeyExchange, preMasterSecret) = tls12BuildRsaClientKeyExchange(rsaPublicKey)
        ContractTls12RsaClientKeyExchange(encodedClientKeyExchange, preMasterSecret)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 RSA ClientKeyExchange build failed: ${e.message}"
        )
    }
}

public func contractTls12BuildRsaClientKeyExchangeFromLeafPemRequest(
    request: ContractTls12RsaClientKeyExchangeFromLeafPemRequest
): ContractTls12RsaClientKeyExchange {
    contractTls12BuildRsaClientKeyExchangeFromLeafPem(request.serverLeafPem)
}

public func contractTls12ProcessRsaClientKeyExchange(
    serverPrivateKeyPkcs8Pem: String,
    encodedClientKeyExchange: Array<Byte>
): Array<Byte> {
    try {
        let privateKey = x509ParseRsaPrivateKeyPkcs8Pem(serverPrivateKeyPkcs8Pem)
        tls12ProcessRsaClientKeyExchange(privateKey, encodedClientKeyExchange)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 RSA ClientKeyExchange process failed: ${e.message}"
        )
    }
}

public func contractTls12ProcessRsaClientKeyExchangeRequest(
    request: ContractTls12ProcessRsaClientKeyExchangeRequest
): Array<Byte> {
    contractTls12ProcessRsaClientKeyExchange(
        request.serverPrivateKeyPkcs8Pem,
        request.encodedClientKeyExchange
    )
}

public func contractTls12DeriveSecretsFromPreMaster(
    preMasterSecret: Array<Byte>,
    clientRandom: Array<Byte>,
    serverRandom: Array<Byte>,
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12
): ContractTls12HandshakeSecrets {
    try {
        let secrets = tls12DeriveSecretsFromPreMaster(
            preMasterSecret,
            clientRandom,
            serverRandom,
            keyLen: keyLen,
            ivLen: ivLen
        )
        contractFromTls12HandshakeSecrets(secrets)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 handshake secret derivation failed: ${e.message}"
        )
    }
}

public func contractTls12DeriveSecretsFromPreMasterRequest(
    request: ContractTls12DeriveSecretsFromPreMasterRequest
): ContractTls12HandshakeSecrets {
    contractTls12DeriveSecretsFromPreMaster(
        request.preMasterSecret,
        request.clientRandom,
        request.serverRandom,
        keyLen: request.keyLen,
        ivLen: request.ivLen
    )
}

public func contractTls12BuildEcdheServerKeyExchange(
    keyExchange: ContractTls12KeyExchange,
    serverPrivateScalar!: ?Array<Byte> = None
): ContractTls12EcdheServerKeyExchange {
    let (curve, fieldBytes) = contractTls12ResolveEcdheCurveSpec(keyExchange)
    try {
        let scalar = if (let Some(value) <- serverPrivateScalar) {
            value.clone()
        } else {
            contractRandomBytes(fieldBytes)
        }
        let privateKey = contractTls12EcPrivateKeyFromScalar(curve, scalar, fieldBytes, "server")
        let publicKey = ecPublicFromPrivateKey(privateKey)
        let encodedServerKeyExchange = tls12BuildEcdheServerKeyExchange(publicKey)
        ContractTls12EcdheServerKeyExchange(encodedServerKeyExchange, scalar)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 ECDHE ServerKeyExchange build failed: ${e.message}"
        )
    }
}

public func contractTls12BuildEcdheServerKeyExchangeRequest(
    request: ContractTls12EcdheServerKeyExchangeRequest
): ContractTls12EcdheServerKeyExchange {
    contractTls12BuildEcdheServerKeyExchange(
        request.keyExchange,
        serverPrivateScalar: request.serverPrivateScalar
    )
}

public func contractTls12BuildEcdheClientKeyExchange(
    keyExchange: ContractTls12KeyExchange,
    clientPrivateScalar!: ?Array<Byte> = None
): ContractTls12EcdheClientKeyExchange {
    let (curve, fieldBytes) = contractTls12ResolveEcdheCurveSpec(keyExchange)
    try {
        let scalar = if (let Some(value) <- clientPrivateScalar) {
            value.clone()
        } else {
            contractRandomBytes(fieldBytes)
        }
        let privateKey = contractTls12EcPrivateKeyFromScalar(curve, scalar, fieldBytes, "client")
        let publicKey = ecPublicFromPrivateKey(privateKey)
        let encodedClientKeyExchange = tls12BuildEcdheClientKeyExchange(publicKey)
        ContractTls12EcdheClientKeyExchange(encodedClientKeyExchange, scalar)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 ECDHE ClientKeyExchange build failed: ${e.message}"
        )
    }
}

public func contractTls12BuildEcdheClientKeyExchangeRequest(
    request: ContractTls12EcdheClientKeyExchangeRequest
): ContractTls12EcdheClientKeyExchange {
    contractTls12BuildEcdheClientKeyExchange(
        request.keyExchange,
        clientPrivateScalar: request.clientPrivateScalar
    )
}

public func contractTls12DeriveClientSecretsFromEcdhe(
    keyExchange: ContractTls12KeyExchange,
    clientPrivateScalar: Array<Byte>,
    encodedServerKeyExchange: Array<Byte>,
    clientRandom: Array<Byte>,
    serverRandom: Array<Byte>,
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12
): ContractTls12HandshakeSecrets {
    let (curve, fieldBytes) = contractTls12ResolveEcdheCurveSpec(keyExchange)
    try {
        let privateKey = contractTls12EcPrivateKeyFromScalar(curve, clientPrivateScalar, fieldBytes, "client")
        let serverPublicKey = tls12ParseEcdheServerKeyExchange(encodedServerKeyExchange)
        if (serverPublicKey.curve != curve) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 ECDHE server key exchange curve mismatch")
        }
        let secrets = tls12DeriveSecretsFromEcdhe(
            privateKey,
            serverPublicKey,
            clientRandom,
            serverRandom,
            keyLen: keyLen,
            ivLen: ivLen
        )
        contractFromTls12HandshakeSecrets(secrets)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 ECDHE client secret derivation failed: ${e.message}"
        )
    }
}

public func contractTls12DeriveClientSecretsFromEcdheRequest(
    request: ContractTls12DeriveClientSecretsFromEcdheRequest
): ContractTls12HandshakeSecrets {
    contractTls12DeriveClientSecretsFromEcdhe(
        request.keyExchange,
        request.clientPrivateScalar,
        request.encodedServerKeyExchange,
        request.clientRandom,
        request.serverRandom,
        keyLen: request.keyLen,
        ivLen: request.ivLen
    )
}

public func contractTls12DeriveServerSecretsFromEcdhe(
    keyExchange: ContractTls12KeyExchange,
    serverPrivateScalar: Array<Byte>,
    encodedClientKeyExchange: Array<Byte>,
    clientRandom: Array<Byte>,
    serverRandom: Array<Byte>,
    keyLen!: Int64 = 16,
    ivLen!: Int64 = 12
): ContractTls12HandshakeSecrets {
    let (curve, fieldBytes) = contractTls12ResolveEcdheCurveSpec(keyExchange)
    try {
        let privateKey = contractTls12EcPrivateKeyFromScalar(curve, serverPrivateScalar, fieldBytes, "server")
        let clientPublicKey = tls12ParseEcdheClientKeyExchange(encodedClientKeyExchange)
        if (clientPublicKey.curve != curve) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.2 ECDHE client key exchange curve mismatch")
        }
        let secrets = tls12DeriveSecretsFromEcdhe(
            privateKey,
            clientPublicKey,
            clientRandom,
            serverRandom,
            keyLen: keyLen,
            ivLen: ivLen
        )
        contractFromTls12HandshakeSecrets(secrets)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 ECDHE server secret derivation failed: ${e.message}"
        )
    }
}

public func contractTls12DeriveServerSecretsFromEcdheRequest(
    request: ContractTls12DeriveServerSecretsFromEcdheRequest
): ContractTls12HandshakeSecrets {
    contractTls12DeriveServerSecretsFromEcdhe(
        request.keyExchange,
        request.serverPrivateScalar,
        request.encodedClientKeyExchange,
        request.clientRandom,
        request.serverRandom,
        keyLen: request.keyLen,
        ivLen: request.ivLen
    )
}

public func contractTls12CreateClientRecordChannel(
    secrets: ContractTls12HandshakeSecrets,
    algorithm!: ContractAeadAlgorithm = ContractAeadAlgorithm.Aes256Gcm
): ContractTlsRecordChannel {
    try {
        let tlsSecrets = contractToTls12HandshakeSecrets(secrets)
        match (algorithm) {
            case ContractAeadAlgorithm.Aes256Gcm =>
                let layer = tls12CreateClientRecordLayer(tlsSecrets)
                return ContractTlsRecordChannel(
                    ContractTlsVersion.Tls12,
                    ContractAeadAlgorithm.Aes256Gcm,
                    aesLayer: Some(layer)
                )
            case ContractAeadAlgorithm.Chacha20Poly1305 =>
                let layer = tls12CreateClientRecordLayerChacha20Poly1305(tlsSecrets)
                return ContractTlsRecordChannel(
                    ContractTlsVersion.Tls12,
                    ContractAeadAlgorithm.Chacha20Poly1305,
                    chachaLayer: Some(layer)
                )
        }
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 client record channel creation failed: ${e.message}"
        )
    }
}

public func contractTls12CreateClientRecordChannelRequest(
    request: ContractTls12RecordChannelRequest
): ContractTlsRecordChannel {
    contractTls12CreateClientRecordChannel(
        request.secrets,
        algorithm: request.algorithm
    )
}

public func contractTls12CreateServerRecordChannel(
    secrets: ContractTls12HandshakeSecrets,
    algorithm!: ContractAeadAlgorithm = ContractAeadAlgorithm.Aes256Gcm
): ContractTlsRecordChannel {
    try {
        let tlsSecrets = contractToTls12HandshakeSecrets(secrets)
        match (algorithm) {
            case ContractAeadAlgorithm.Aes256Gcm =>
                let layer = tls12CreateServerRecordLayer(tlsSecrets)
                return ContractTlsRecordChannel(
                    ContractTlsVersion.Tls12,
                    ContractAeadAlgorithm.Aes256Gcm,
                    aesLayer: Some(layer)
                )
            case ContractAeadAlgorithm.Chacha20Poly1305 =>
                let layer = tls12CreateServerRecordLayerChacha20Poly1305(tlsSecrets)
                return ContractTlsRecordChannel(
                    ContractTlsVersion.Tls12,
                    ContractAeadAlgorithm.Chacha20Poly1305,
                    chachaLayer: Some(layer)
                )
        }
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.2 server record channel creation failed: ${e.message}"
        )
    }
}

public func contractTls12CreateServerRecordChannelRequest(
    request: ContractTls12RecordChannelRequest
): ContractTlsRecordChannel {
    contractTls12CreateServerRecordChannel(
        request.secrets,
        algorithm: request.algorithm
    )
}

public func contractTls13CreateClientRecordChannel(
    keyMaterial: ContractTls13ApplicationKeyMaterial,
    algorithm!: ContractAeadAlgorithm = ContractAeadAlgorithm.Aes256Gcm
): ContractTlsRecordChannel {
    try {
        match (algorithm) {
            case ContractAeadAlgorithm.Aes256Gcm =>
                let layer = TlsAeadRecordLayer(
                    keyMaterial.clientWriteKey,
                    keyMaterial.clientWriteIv,
                    readKey: keyMaterial.serverWriteKey,
                    readIv: keyMaterial.serverWriteIv,
                    version: TLS_VERSION_1_3
                )
                return ContractTlsRecordChannel(
                    ContractTlsVersion.Tls13,
                    ContractAeadAlgorithm.Aes256Gcm,
                    aesLayer: Some(layer)
                )
            case ContractAeadAlgorithm.Chacha20Poly1305 =>
                let layer = TlsChacha20Poly1305RecordLayer(
                    keyMaterial.clientWriteKey,
                    keyMaterial.clientWriteIv,
                    readKey: keyMaterial.serverWriteKey,
                    readIv: keyMaterial.serverWriteIv,
                    version: TLS_VERSION_1_3
                )
                return ContractTlsRecordChannel(
                    ContractTlsVersion.Tls13,
                    ContractAeadAlgorithm.Chacha20Poly1305,
                    chachaLayer: Some(layer)
                )
        }
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 client record channel creation failed: ${e.message}"
        )
    }
}

public func contractTls13CreateClientRecordChannelRequest(
    request: ContractTls13RecordChannelRequest
): ContractTlsRecordChannel {
    contractTls13CreateClientRecordChannel(
        request.keyMaterial,
        algorithm: request.algorithm
    )
}

public func contractTls13CreateServerRecordChannel(
    keyMaterial: ContractTls13ApplicationKeyMaterial,
    algorithm!: ContractAeadAlgorithm = ContractAeadAlgorithm.Aes256Gcm
): ContractTlsRecordChannel {
    try {
        match (algorithm) {
            case ContractAeadAlgorithm.Aes256Gcm =>
                let layer = TlsAeadRecordLayer(
                    keyMaterial.serverWriteKey,
                    keyMaterial.serverWriteIv,
                    readKey: keyMaterial.clientWriteKey,
                    readIv: keyMaterial.clientWriteIv,
                    version: TLS_VERSION_1_3
                )
                return ContractTlsRecordChannel(
                    ContractTlsVersion.Tls13,
                    ContractAeadAlgorithm.Aes256Gcm,
                    aesLayer: Some(layer)
                )
            case ContractAeadAlgorithm.Chacha20Poly1305 =>
                let layer = TlsChacha20Poly1305RecordLayer(
                    keyMaterial.serverWriteKey,
                    keyMaterial.serverWriteIv,
                    readKey: keyMaterial.clientWriteKey,
                    readIv: keyMaterial.clientWriteIv,
                    version: TLS_VERSION_1_3
                )
                return ContractTlsRecordChannel(
                    ContractTlsVersion.Tls13,
                    ContractAeadAlgorithm.Chacha20Poly1305,
                    chachaLayer: Some(layer)
                )
        }
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 server record channel creation failed: ${e.message}"
        )
    }
}

public func contractTls13CreateServerRecordChannelRequest(
    request: ContractTls13RecordChannelRequest
): ContractTlsRecordChannel {
    contractTls13CreateServerRecordChannel(
        request.keyMaterial,
        algorithm: request.algorithm
    )
}

public func contractTls13BuildHttpClientHelloX25519(
    serverName: String,
    alpnProtocols!: Array<String> = [],
    clientPrivateKey!: ?Array<Byte> = None
): ContractTls13HttpClientHelloX25519 {
    try {
        let privateKey = if (let Some(value) <- clientPrivateKey) {
            value.clone()
        } else {
            x25519GeneratePrivateKey()
        }
        let publicKey = x25519PublicFromPrivate(privateKey)
        let encodedClientHello = tls13BuildHttpClientHelloX25519(
            publicKey,
            serverName,
            alpnProtocols: alpnProtocols
        )
        ContractTls13HttpClientHelloX25519(encodedClientHello, privateKey, publicKey)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 HTTP ClientHello build failed: ${e.message}"
        )
    }
}

public func contractTls13BuildHttpClientHelloX25519Request(
    request: ContractTls13HttpClientHelloX25519Request
): ContractTls13HttpClientHelloX25519 {
    contractTls13BuildHttpClientHelloX25519(
        request.serverName,
        alpnProtocols: request.alpnProtocols,
        clientPrivateKey: request.clientPrivateKey
    )
}

public func contractTls13BuildHttpServerFlightX25519(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    certChainPemBundle: String,
    certificatePrivateKeyPkcs8Pem: String,
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractTls13HttpServerFlight {
    try {
        let certChain = x509ParsePemChain(certChainPemBundle)
        if (certChain.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 certificate chain PEM bundle must not be empty")
        }
        let certChainDer = contractDerChainFromCertificates(certChain)
        let certificatePrivateKeyRsa: ?RsaPrivateKey = contractTryParseRsaPrivateKeyPkcs8Pem(certificatePrivateKeyPkcs8Pem)
        let certificatePrivateKeyEcdsa: ?EcPrivateKey = if (let Some(_value) <- certificatePrivateKeyRsa) {
            None
        } else {
            contractTryParseEcPrivateKeyPkcs8Pem(certificatePrivateKeyPkcs8Pem)
        }
        if (
            !contractIsSomeRsaPrivateKey(certificatePrivateKeyRsa) &&
            !contractIsSomeEcPrivateKey(certificatePrivateKeyEcdsa)
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 certificate private key must be PKCS8 RSA or EC"
            )
        }
        let serverKeyShare = x25519PublicFromPrivate(serverKeyExchangePrivate)
        let context = tls13BuildHttpServerHandshakeContextX25519(
            encodedClientHello,
            serverKeyExchangePrivate,
            serverKeyShare,
            certChainDer,
            certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
            certificatePrivateKeyRsa: certificatePrivateKeyRsa,
            policy: contractToTlsHttpNegotiationPolicy(policy)
        )
        contractFromTls13ServerHandshakeFlight(context.flight)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 HTTP server flight build failed: ${e.message}"
        )
    }
}

public func contractTls13BuildHttpServerFlightX25519Request(
    request: ContractTls13HttpServerFlightX25519Request
): ContractTls13HttpServerFlight {
    contractTls13BuildHttpServerFlightX25519(
        request.encodedClientHello,
        request.serverKeyExchangePrivate,
        request.certChainPemBundle,
        request.certificatePrivateKeyPkcs8Pem,
        policy: request.policy
    )
}

public func contractTls13BuildHttpServerFlightX25519Rsa(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    certChainPemBundle: String,
    certificatePrivateKeyPkcs8Pem: String,
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractTls13HttpServerFlight {
    contractTls13BuildHttpServerFlightX25519(
        encodedClientHello,
        serverKeyExchangePrivate,
        certChainPemBundle,
        certificatePrivateKeyPkcs8Pem,
        policy: policy
    )
}

public func contractTls13VerifyHttpServerFlightX25519(
    clientHello: ContractTls13HttpClientHelloX25519,
    serverFlight: ContractTls13HttpServerFlight,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractTls13HttpClientResult {
    contractTls13VerifyHttpServerFlightX25519WithSession(
        clientHello,
        serverFlight,
        trustAnchorsPemBundle,
        intermediatesPemBundle: intermediatesPemBundle,
        hostname: hostname,
        validationTime: validationTime,
        pinPolicy: pinPolicy,
        policy: policy
    ).result
}

public func contractTls13VerifyHttpServerFlightX25519Request(
    request: ContractTls13HttpVerifyServerFlightX25519Request
): ContractTls13HttpClientResult {
    contractTls13VerifyHttpServerFlightX25519(
        request.clientHello,
        request.serverFlight,
        request.trust.trustAnchorsPemBundle,
        intermediatesPemBundle: request.trust.intermediatesPemBundle,
        hostname: request.trust.hostname,
        validationTime: request.trust.validationTime,
        pinPolicy: request.trust.pinPolicy,
        policy: request.trust.policy
    )
}

public func contractTls13VerifyHttpServerFlightX25519WithSession(
    clientHello: ContractTls13HttpClientHelloX25519,
    serverFlight: ContractTls13HttpServerFlight,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractTls13HttpClientVerifiedSession {
    try {
        let anchors = x509ParsePemChain(trustAnchorsPemBundle)
        let intermediates: Array<X509Certificate> = if (intermediatesPemBundle.trimAscii().size == 0) {
            []
        } else {
            x509ParsePemChain(intermediatesPemBundle)
        }
        let x509Policy = X509VerificationPolicy(
            anchors,
            intermediates: intermediates,
            requiredLeafDnsName: hostname,
            validationTime: validationTime
        )
        let flight = contractToTls13ServerHandshakeFlight(serverFlight)
        let result = tls13ProcessServerHandshakeFlightX25519(
            clientHello.encodedClientHello,
            clientHello.clientPrivateKey,
            flight,
            x509Policy
        )
        tls13ValidateHttpClientResult(result, policy: contractToTlsHttpNegotiationPolicy(policy))

        let leaf = result.verification.chain[0]
        let leafDerSha = sha256(leaf.der)
        let leafSpkiSha = sha256(leaf.subjectPublicKeyInfoDer)
        contractRequirePinPolicy(pinPolicy, leafDerSha, leafSpkiSha)
        let binding = contractTls13ResolveCipherBindingFromServerFlight(serverFlight)
        let clientResult = ContractTls13HttpClientResult(
            result.selectedAlpn,
            result.requestedServerName,
            result.acknowledgedServerName,
            result.verification.chain.size,
            leaf.subject.commonName(),
            result.verification.trustAnchor.subject.commonName(),
            leafDerSha,
            leafSpkiSha,
            ContractTls13ApplicationKeyMaterial(
                result.secrets.clientWriteKey,
                result.secrets.clientWriteIv,
                result.secrets.serverWriteKey,
                result.secrets.serverWriteIv
            ),
            cipherBinding: Some(binding)
        )
        ContractTls13HttpClientVerifiedSession(
            clientResult,
            result.secrets.clientAppTrafficSecret,
            result.secrets.serverAppTrafficSecret,
            result.secrets.masterSecret,
            serverFlight.transcriptHash
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 HTTP server flight verification with session failed: ${e.message}"
        )
    }
}

public func contractTls13VerifyHttpServerFlightX25519WithSessionRequest(
    request: ContractTls13HttpVerifyServerFlightX25519Request
): ContractTls13HttpClientVerifiedSession {
    contractTls13VerifyHttpServerFlightX25519WithSession(
        request.clientHello,
        request.serverFlight,
        request.trust.trustAnchorsPemBundle,
        intermediatesPemBundle: request.trust.intermediatesPemBundle,
        hostname: request.trust.hostname,
        validationTime: request.trust.validationTime,
        pinPolicy: request.trust.pinPolicy,
        policy: request.trust.policy
    )
}

public func contractTryTls13VerifyHttpServerFlightX25519(
    clientHello: ContractTls13HttpClientHelloX25519,
    serverFlight: ContractTls13HttpServerFlight,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractTls13HttpClientVerifyOutcome {
    try {
        let result = contractTls13VerifyHttpServerFlightX25519(
            clientHello,
            serverFlight,
            trustAnchorsPemBundle,
            intermediatesPemBundle: intermediatesPemBundle,
            hostname: hostname,
            validationTime: validationTime,
            pinPolicy: pinPolicy,
            policy: policy
        )
        ContractTls13HttpClientVerifyOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractTls13HttpClientVerifyOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryTls13VerifyHttpServerFlightX25519Request(
    request: ContractTls13HttpVerifyServerFlightX25519Request
): ContractTls13HttpClientVerifyOutcome {
    try {
        let result = contractTls13VerifyHttpServerFlightX25519Request(request)
        ContractTls13HttpClientVerifyOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractTls13HttpClientVerifyOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryTls13VerifyHttpServerFlightX25519WithSession(
    clientHello: ContractTls13HttpClientHelloX25519,
    serverFlight: ContractTls13HttpServerFlight,
    trustAnchorsPemBundle: String,
    intermediatesPemBundle!: String = "",
    hostname!: String = "",
    validationTime!: String = "",
    pinPolicy!: ContractX509PinPolicy = ContractX509PinPolicy(),
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractTls13HttpClientVerifiedSessionOutcome {
    try {
        let result = contractTls13VerifyHttpServerFlightX25519WithSession(
            clientHello,
            serverFlight,
            trustAnchorsPemBundle,
            intermediatesPemBundle: intermediatesPemBundle,
            hostname: hostname,
            validationTime: validationTime,
            pinPolicy: pinPolicy,
            policy: policy
        )
        ContractTls13HttpClientVerifiedSessionOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractTls13HttpClientVerifiedSessionOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryTls13VerifyHttpServerFlightX25519WithSessionRequest(
    request: ContractTls13HttpVerifyServerFlightX25519Request
): ContractTls13HttpClientVerifiedSessionOutcome {
    try {
        let result = contractTls13VerifyHttpServerFlightX25519WithSessionRequest(request)
        ContractTls13HttpClientVerifiedSessionOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractTls13HttpClientVerifiedSessionOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshComputeHostKeySha256(serverHostKey: Array<Byte>): Array<Byte> {
    try {
        sshComputeHostKeySha256(serverHostKey)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH host key fingerprint computation failed: ${e.message}"
        )
    }
}

public func contractSshEncodeRsaHostPublicKey(publicKey: RsaPublicKey): Array<Byte> {
    try {
        sshEncodeRsaHostPublicKey(publicKey)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH RSA host key encoding failed: ${e.message}"
        )
    }
}

public func contractSshSignExchangeHashRsa(
    privateKey: RsaPrivateKey,
    exchangeHash: Array<Byte>,
    signatureAlgorithm!: String = "rsa-sha2-256"
): Array<Byte> {
    try {
        sshSignExchangeHashRsa(privateKey, exchangeHash, signatureAlgorithm: signatureAlgorithm)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH RSA exchange-hash signing failed: ${e.message}"
        )
    }
}

public func contractSshEncodeEcdsaHostPublicKey(publicKey: EcPublicKey): Array<Byte> {
    try {
        sshEncodeEcdsaHostPublicKey(publicKey)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH ECDSA host key encoding failed: ${e.message}"
        )
    }
}

public func contractSshSignExchangeHashEcdsa(privateKey: EcPrivateKey, exchangeHash: Array<Byte>): Array<Byte> {
    try {
        sshSignExchangeHashEcdsa(privateKey, exchangeHash)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH ECDSA exchange-hash signing failed: ${e.message}"
        )
    }
}

public func contractSshBuildEd25519HostKeyBlobFromSeed(privateKeySeed: Array<Byte>): Array<Byte> {
    try {
        sshBuildEd25519HostKeyBlobFromSeed(privateKeySeed)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH Ed25519 host key encoding failed: ${e.message}"
        )
    }
}

public func contractPrepareSshHostSigningRsa(
    privateKey: RsaPrivateKey,
    exchangeHash: Array<Byte>,
    signatureAlgorithm!: String = "rsa-sha2-256"
): ContractSshHostSigningResult {
    let serverHostKey = contractSshEncodeRsaHostPublicKey(privateKey.publicKey)
    let hostSignature = contractSshSignExchangeHashRsa(
        privateKey,
        exchangeHash,
        signatureAlgorithm: signatureAlgorithm
    )
    contractBuildSshHostSigningResult(serverHostKey, hostSignature)
}

public func contractTryPrepareSshHostSigningRsa(
    privateKey: RsaPrivateKey,
    exchangeHash: Array<Byte>,
    signatureAlgorithm!: String = "rsa-sha2-256"
): ContractSshHostSigningOutcome {
    try {
        let result = contractPrepareSshHostSigningRsa(
            privateKey,
            exchangeHash,
            signatureAlgorithm: signatureAlgorithm
        )
        ContractSshHostSigningOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshHostSigningOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareSshHostSigningRsaPkcs8Request(
    request: ContractSshHostSigningRsaPkcs8Request
): ContractSshHostSigningResult {
    let privateKey = contractParseRsaPrivateKeyPkcs8PemForSshHostSigning(request.hostPrivateKeyPkcs8Pem)
    contractPrepareSshHostSigningRsa(
        privateKey,
        request.exchangeHash,
        signatureAlgorithm: request.signatureAlgorithm
    )
}

public func contractTryPrepareSshHostSigningRsaPkcs8Request(
    request: ContractSshHostSigningRsaPkcs8Request
): ContractSshHostSigningOutcome {
    try {
        let result = contractPrepareSshHostSigningRsaPkcs8Request(request)
        ContractSshHostSigningOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshHostSigningOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareSshHostSigningEcdsa(
    privateKey: EcPrivateKey,
    exchangeHash: Array<Byte>
): ContractSshHostSigningResult {
    let serverHostKey = contractSshEncodeEcdsaHostPublicKey(ecPublicFromPrivateKey(privateKey))
    let hostSignature = contractSshSignExchangeHashEcdsa(privateKey, exchangeHash)
    contractBuildSshHostSigningResult(serverHostKey, hostSignature)
}

public func contractTryPrepareSshHostSigningEcdsa(
    privateKey: EcPrivateKey,
    exchangeHash: Array<Byte>
): ContractSshHostSigningOutcome {
    try {
        let result = contractPrepareSshHostSigningEcdsa(privateKey, exchangeHash)
        ContractSshHostSigningOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshHostSigningOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareSshHostSigningEcdsaPkcs8Request(
    request: ContractSshHostSigningEcdsaPkcs8Request
): ContractSshHostSigningResult {
    let privateKey = contractParseEcPrivateKeyPkcs8PemForSshHostSigning(request.hostPrivateKeyPkcs8Pem)
    contractPrepareSshHostSigningEcdsa(privateKey, request.exchangeHash)
}

public func contractTryPrepareSshHostSigningEcdsaPkcs8Request(
    request: ContractSshHostSigningEcdsaPkcs8Request
): ContractSshHostSigningOutcome {
    try {
        let result = contractPrepareSshHostSigningEcdsaPkcs8Request(request)
        ContractSshHostSigningOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshHostSigningOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareSshHostSigningEd25519(
    privateKeySeed: Array<Byte>,
    exchangeHash: Array<Byte>
): ContractSshHostSigningResult {
    let serverHostKey = contractSshBuildEd25519HostKeyBlobFromSeed(privateKeySeed)
    let hostSignature = contractSshSignExchangeHashEd25519(privateKeySeed, exchangeHash)
    contractBuildSshHostSigningResult(serverHostKey, hostSignature)
}

public func contractTryPrepareSshHostSigningEd25519(
    privateKeySeed: Array<Byte>,
    exchangeHash: Array<Byte>
): ContractSshHostSigningOutcome {
    try {
        let result = contractPrepareSshHostSigningEd25519(privateKeySeed, exchangeHash)
        ContractSshHostSigningOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshHostSigningOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractPrepareSshHostSigningEd25519SeedRequest(
    request: ContractSshHostSigningEd25519SeedRequest
): ContractSshHostSigningResult {
    contractPrepareSshHostSigningEd25519(request.hostPrivateKeySeed, request.exchangeHash)
}

public func contractTryPrepareSshHostSigningEd25519SeedRequest(
    request: ContractSshHostSigningEd25519SeedRequest
): ContractSshHostSigningOutcome {
    try {
        let result = contractPrepareSshHostSigningEd25519SeedRequest(request)
        ContractSshHostSigningOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshHostSigningOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshSignExchangeHashEd25519(privateKeySeed: Array<Byte>, exchangeHash: Array<Byte>): Array<Byte> {
    try {
        sshSignExchangeHashEd25519(privateKeySeed, exchangeHash)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH Ed25519 exchange-hash signing failed: ${e.message}"
        )
    }
}

public func contractSshBuildVersionBanner(
    softwareVersion: String,
    comments!: String = ""
): ContractSshVersionBanner {
    try {
        contractFromSshVersionBanner(
            sshBuildVersionBanner(softwareVersion, comments: comments)
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH version banner build failed: ${e.message}"
        )
    }
}

public func contractSshBuildVersionBannerRequest(
    request: ContractSshBuildVersionBannerRequest
): ContractSshVersionBanner {
    contractSshBuildVersionBanner(request.softwareVersion, comments: request.comments)
}

public func contractSshEncodeVersionBanner(
    banner: ContractSshVersionBanner
): Array<Byte> {
    try {
        sshEncodeVersionBanner(contractToSshVersionBanner(banner))
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH version banner encode failed: ${e.message}"
        )
    }
}

public func contractSshEncodeVersionBannerRequest(
    request: ContractSshEncodeVersionBannerRequest
): Array<Byte> {
    contractSshEncodeVersionBanner(request.banner)
}

public func contractSshDecodeVersionBanner(
    encodedLine: Array<Byte>
): ContractSshVersionBanner {
    try {
        contractFromSshVersionBanner(sshDecodeVersionBanner(encodedLine))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH version banner decode failed: ${e.message}"
        )
    }
}

public func contractSshDecodeVersionBannerRequest(
    request: ContractSshDecodeVersionBannerRequest
): ContractSshVersionBanner {
    contractSshDecodeVersionBanner(request.encodedLine)
}

public func contractSshBuildDefaultKexInit(
    cookie!: Array<Byte> = []
): ContractSshKexInitMessage {
    try {
        contractFromSshKexInitMessage(sshBuildDefaultKexInit(cookie: cookie))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH default KEXINIT build failed: ${e.message}"
        )
    }
}

public func contractSshBuildDefaultKexInitRequest(
    request: ContractSshBuildDefaultKexInitRequest
): ContractSshKexInitMessage {
    contractSshBuildDefaultKexInit(cookie: request.cookie)
}

public func contractSshEncodeKexInit(
    message: ContractSshKexInitMessage
): Array<Byte> {
    try {
        sshEncodeKexInit(contractToSshKexInitMessage(message))
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEXINIT encode failed: ${e.message}"
        )
    }
}

public func contractSshEncodeKexInitRequest(
    request: ContractSshEncodeKexInitRequest
): Array<Byte> {
    contractSshEncodeKexInit(request.message)
}

public func contractSshDecodeKexInit(
    encoded: Array<Byte>
): ContractSshKexInitMessage {
    try {
        contractFromSshKexInitMessage(sshDecodeKexInit(encoded))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEXINIT decode failed: ${e.message}"
        )
    }
}

public func contractSshDecodeKexInitRequest(
    request: ContractSshDecodeKexInitRequest
): ContractSshKexInitMessage {
    contractSshDecodeKexInit(request.encoded)
}

public func contractSshNegotiateKexInit(
    client: ContractSshKexInitMessage,
    server: ContractSshKexInitMessage
): ContractSshNegotiatedAlgorithms {
    try {
        contractFromSshNegotiatedAlgorithms(
            sshNegotiateKexInit(
                contractToSshKexInitMessage(client),
                contractToSshKexInitMessage(server)
            )
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEXINIT negotiation failed: ${e.message}"
        )
    }
}

public func contractSshNegotiateKexInitRequest(
    request: ContractSshNegotiateKexInitRequest
): ContractSshNegotiatedAlgorithms {
    contractSshNegotiateKexInit(request.client, request.server)
}

public func contractSshBuildKexExchangeTranscript(
    clientBannerLine: Array<Byte>,
    serverBannerLine: Array<Byte>,
    clientKexInit: ContractSshKexInitMessage,
    serverKexInit: ContractSshKexInitMessage
): ContractSshKexExchangeTranscript {
    ContractSshKexExchangeTranscript(
        clientBannerLine,
        serverBannerLine,
        contractSshEncodeKexInit(clientKexInit),
        contractSshEncodeKexInit(serverKexInit)
    )
}

public func contractSshBuildKexExchangeTranscriptRequest(
    request: ContractSshBuildTranscriptFromKexInitRequest
): ContractSshKexExchangeTranscript {
    contractSshBuildKexExchangeTranscript(
        request.clientBannerLine,
        request.serverBannerLine,
        request.clientKexInit,
        request.serverKexInit
    )
}

public func contractSshBuildKexExchangeTranscriptFromPrelude(
    clientBanner: ContractSshVersionBanner,
    serverBanner: ContractSshVersionBanner,
    clientKexInit: ContractSshKexInitMessage,
    serverKexInit: ContractSshKexInitMessage
): ContractSshKexExchangeTranscript {
    ContractSshKexExchangeTranscript(
        contractSshEncodeVersionBanner(clientBanner),
        contractSshEncodeVersionBanner(serverBanner),
        contractSshEncodeKexInit(clientKexInit),
        contractSshEncodeKexInit(serverKexInit)
    )
}

public func contractSshBuildKexExchangeTranscriptFromPreludeRequest(
    request: ContractSshBuildTranscriptFromPreludeRequest
): ContractSshKexExchangeTranscript {
    contractSshBuildKexExchangeTranscriptFromPrelude(
        request.clientBanner,
        request.serverBanner,
        request.clientKexInit,
        request.serverKexInit
    )
}

public func contractSshEncodeKexEcdhInit(
    message: ContractSshKexEcdhInitMessage
): Array<Byte> {
    try {
        sshEncodeKexEcdhInit(contractToSshKexEcdhInitMessage(message))
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEX_ECDH_INIT encode failed: ${e.message}"
        )
    }
}

public func contractSshEncodeKexEcdhInitRequest(
    request: ContractSshEncodeKexEcdhInitRequest
): Array<Byte> {
    contractSshEncodeKexEcdhInit(request.message)
}

public func contractSshDecodeKexEcdhInit(
    encoded: Array<Byte>
): ContractSshKexEcdhInitMessage {
    try {
        contractFromSshKexEcdhInitMessage(sshDecodeKexEcdhInit(encoded))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEX_ECDH_INIT decode failed: ${e.message}"
        )
    }
}

public func contractSshDecodeKexEcdhInitRequest(
    request: ContractSshDecodeKexEcdhInitRequest
): ContractSshKexEcdhInitMessage {
    contractSshDecodeKexEcdhInit(request.encoded)
}

public func contractSshEncodeKexEcdhReply(
    message: ContractSshKexEcdhReplyMessage
): Array<Byte> {
    try {
        sshEncodeKexEcdhReply(contractToSshKexEcdhReplyMessage(message))
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEX_ECDH_REPLY encode failed: ${e.message}"
        )
    }
}

public func contractSshEncodeKexEcdhReplyRequest(
    request: ContractSshEncodeKexEcdhReplyRequest
): Array<Byte> {
    contractSshEncodeKexEcdhReply(request.message)
}

public func contractSshDecodeKexEcdhReply(
    encoded: Array<Byte>
): ContractSshKexEcdhReplyMessage {
    try {
        contractFromSshKexEcdhReplyMessage(sshDecodeKexEcdhReply(encoded))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEX_ECDH_REPLY decode failed: ${e.message}"
        )
    }
}

public func contractSshDecodeKexEcdhReplyRequest(
    request: ContractSshDecodeKexEcdhReplyRequest
): ContractSshKexEcdhReplyMessage {
    contractSshDecodeKexEcdhReply(request.encoded)
}

public func contractSshEncodeNewKeys(): Array<Byte> {
    try {
        sshEncodeNewKeys()
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH NEWKEYS encode failed: ${e.message}"
        )
    }
}

public func contractSshEncodeNewKeysRequest(
    request: ContractSshEncodeNewKeysRequest
): Array<Byte> {
    let _ = request
    contractSshEncodeNewKeys()
}

public func contractSshDecodeNewKeys(encoded: Array<Byte>): Unit {
    try {
        sshDecodeNewKeys(encoded)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH NEWKEYS decode failed: ${e.message}"
        )
    }
}

public func contractSshDecodeNewKeysRequest(
    request: ContractSshDecodeNewKeysRequest
): Unit {
    contractSshDecodeNewKeys(request.encoded)
}

public func contractSshBuildKexEcdhInitX25519(clientPrivateKey: Array<Byte>): ContractSshX25519InitResult {
    try {
        let (encodedInit, clientPublicKey) = sshBuildKexEcdhInitX25519(clientPrivateKey)
        ContractSshX25519InitResult(encodedInit, clientPublicKey)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH X25519 KEX init build failed: ${e.message}"
        )
    }
}

public func contractSshBuildKexEcdhInitX25519Request(
    request: ContractSshBuildKexEcdhInitX25519Request
): ContractSshX25519InitResult {
    contractSshBuildKexEcdhInitX25519(request.clientPrivateKey)
}

public func contractSshServerProcessKexEcdhInitX25519(
    transcript: ContractSshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    hostSigning: ContractSshHostSigningResult,
    serverPublicKey!: Array<Byte> = []
): ContractSshServerProcessKexEcdhInitX25519Result {
    try {
        let (encodedReply, kexResult) = sshServerProcessKexEcdhInitX25519(
            contractToSshKexExchangeTranscript(transcript),
            serverPrivateKey,
            encodedClientInit,
            hostSigning.serverHostKey,
            hostSigning.hostSignature,
            serverPublicKey: serverPublicKey
        )
        ContractSshServerProcessKexEcdhInitX25519Result(
            encodedReply,
            contractBuildSshSessionStateFromKexResult(kexResult, kexResult.sessionId)
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH server KEX process failed: ${e.message}"
        )
    }
}

public func contractSshServerProcessKexEcdhInitX25519Request(
    request: ContractSshServerProcessKexEcdhInitX25519Request
): ContractSshServerProcessKexEcdhInitX25519Result {
    contractSshServerProcessKexEcdhInitX25519(
        request.transcript,
        request.serverPrivateKey,
        request.encodedClientInit,
        request.hostSigning,
        serverPublicKey: request.serverPublicKey
    )
}

public func contractSshClientProcessKexEcdhReplyX25519(
    transcript: ContractSshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
): ContractSshSessionState {
    try {
        let kexResult = sshClientProcessKexEcdhReplyX25519(
            contractToSshKexExchangeTranscript(transcript),
            clientPrivateKey,
            encodedClientInit,
            encodedServerReply
        )
        let verification = contractSshVerifyHostIdentity(
            kexResult.exchangeHash,
            kexResult.serverHostKey,
            kexResult.hostSignature,
            policy: policy
        )
        contractBuildSshSessionStateFromKexResult(
            kexResult,
            kexResult.sessionId,
            hostVerification: verification
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH client KEX process failed: ${e.message}"
        )
    }
}

public func contractSshClientProcessKexEcdhReplyX25519Request(
    request: ContractSshClientProcessKexEcdhReplyX25519Request
): ContractSshSessionState {
    contractSshClientProcessKexEcdhReplyX25519(
        request.transcript,
        request.clientPrivateKey,
        request.encodedClientInit,
        request.encodedServerReply,
        policy: request.policy
    )
}

public func contractSshCompleteServerInitialHandshakeX25519Rsa(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    hostPrivateKey: RsaPrivateKey,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    signatureAlgorithm!: String = "rsa-sha2-256",
    serverPublicKey!: Array<Byte> = []
): ContractSshServerInitialHandshakeResult {
    try {
        contractFromSshServerInitialHandshakeResult(
            sshCompleteServerInitialHandshakeX25519Rsa(
                transcript,
                serverPrivateKey,
                encodedClientInit,
                hostPrivateKey,
                negotiated,
                encodedClientNewKeys,
                encodedServerNewKeys,
                signatureAlgorithm: signatureAlgorithm,
                serverPublicKey: serverPublicKey
            )
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH RSA server initial handshake failed: ${e.message}"
        )
    }
}

public func contractSshCompleteServerInitialHandshakeX25519RsaRequest(
    request: ContractSshServerInitialHandshakeX25519RsaRequest
): ContractSshServerInitialHandshakeResult {
    contractSshCompleteServerInitialHandshakeX25519Rsa(
        contractToSshKexExchangeTranscript(request.transcript),
        request.serverPrivateKey,
        request.encodedClientInit,
        request.hostPrivateKey,
        contractToSshNegotiatedAlgorithms(request.negotiated),
        request.encodedClientNewKeys,
        request.encodedServerNewKeys,
        signatureAlgorithm: request.signatureAlgorithm,
        serverPublicKey: request.serverPublicKey
    )
}

public func contractTrySshCompleteServerInitialHandshakeX25519Rsa(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    hostPrivateKey: RsaPrivateKey,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    signatureAlgorithm!: String = "rsa-sha2-256",
    serverPublicKey!: Array<Byte> = []
): ContractSshServerInitialHandshakeOutcome {
    try {
        let result = contractSshCompleteServerInitialHandshakeX25519Rsa(
            transcript,
            serverPrivateKey,
            encodedClientInit,
            hostPrivateKey,
            negotiated,
            encodedClientNewKeys,
            encodedServerNewKeys,
            signatureAlgorithm: signatureAlgorithm,
            serverPublicKey: serverPublicKey
        )
        ContractSshServerInitialHandshakeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerInitialHandshakeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTrySshCompleteServerInitialHandshakeX25519RsaRequest(
    request: ContractSshServerInitialHandshakeX25519RsaRequest
): ContractSshServerInitialHandshakeOutcome {
    try {
        let result = contractSshCompleteServerInitialHandshakeX25519RsaRequest(request)
        ContractSshServerInitialHandshakeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerInitialHandshakeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshCompleteServerInitialHandshakeX25519Ecdsa(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    hostPrivateKey: EcPrivateKey,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    serverPublicKey!: Array<Byte> = []
): ContractSshServerInitialHandshakeResult {
    try {
        contractFromSshServerInitialHandshakeResult(
            sshCompleteServerInitialHandshakeX25519Ecdsa(
                transcript,
                serverPrivateKey,
                encodedClientInit,
                hostPrivateKey,
                negotiated,
                encodedClientNewKeys,
                encodedServerNewKeys,
                serverPublicKey: serverPublicKey
            )
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH ECDSA server initial handshake failed: ${e.message}"
        )
    }
}

public func contractSshCompleteServerInitialHandshakeX25519EcdsaRequest(
    request: ContractSshServerInitialHandshakeX25519EcdsaRequest
): ContractSshServerInitialHandshakeResult {
    contractSshCompleteServerInitialHandshakeX25519Ecdsa(
        contractToSshKexExchangeTranscript(request.transcript),
        request.serverPrivateKey,
        request.encodedClientInit,
        request.hostPrivateKey,
        contractToSshNegotiatedAlgorithms(request.negotiated),
        request.encodedClientNewKeys,
        request.encodedServerNewKeys,
        serverPublicKey: request.serverPublicKey
    )
}

public func contractTrySshCompleteServerInitialHandshakeX25519Ecdsa(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    hostPrivateKey: EcPrivateKey,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    serverPublicKey!: Array<Byte> = []
): ContractSshServerInitialHandshakeOutcome {
    try {
        let result = contractSshCompleteServerInitialHandshakeX25519Ecdsa(
            transcript,
            serverPrivateKey,
            encodedClientInit,
            hostPrivateKey,
            negotiated,
            encodedClientNewKeys,
            encodedServerNewKeys,
            serverPublicKey: serverPublicKey
        )
        ContractSshServerInitialHandshakeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerInitialHandshakeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTrySshCompleteServerInitialHandshakeX25519EcdsaRequest(
    request: ContractSshServerInitialHandshakeX25519EcdsaRequest
): ContractSshServerInitialHandshakeOutcome {
    try {
        let result = contractSshCompleteServerInitialHandshakeX25519EcdsaRequest(request)
        ContractSshServerInitialHandshakeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerInitialHandshakeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshCompleteServerInitialHandshakeX25519Ed25519(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    hostPrivateKeySeed: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    serverPublicKey!: Array<Byte> = []
): ContractSshServerInitialHandshakeResult {
    try {
        contractFromSshServerInitialHandshakeResult(
            sshCompleteServerInitialHandshakeX25519Ed25519(
                transcript,
                serverPrivateKey,
                encodedClientInit,
                hostPrivateKeySeed,
                negotiated,
                encodedClientNewKeys,
                encodedServerNewKeys,
                serverPublicKey: serverPublicKey
            )
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH Ed25519 server initial handshake failed: ${e.message}"
        )
    }
}

public func contractSshCompleteServerInitialHandshakeX25519Ed25519Request(
    request: ContractSshServerInitialHandshakeX25519Ed25519Request
): ContractSshServerInitialHandshakeResult {
    contractSshCompleteServerInitialHandshakeX25519Ed25519(
        contractToSshKexExchangeTranscript(request.transcript),
        request.serverPrivateKey,
        request.encodedClientInit,
        request.hostPrivateKeySeed,
        contractToSshNegotiatedAlgorithms(request.negotiated),
        request.encodedClientNewKeys,
        request.encodedServerNewKeys,
        serverPublicKey: request.serverPublicKey
    )
}

public func contractTrySshCompleteServerInitialHandshakeX25519Ed25519(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    hostPrivateKeySeed: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    serverPublicKey!: Array<Byte> = []
): ContractSshServerInitialHandshakeOutcome {
    try {
        let result = contractSshCompleteServerInitialHandshakeX25519Ed25519(
            transcript,
            serverPrivateKey,
            encodedClientInit,
            hostPrivateKeySeed,
            negotiated,
            encodedClientNewKeys,
            encodedServerNewKeys,
            serverPublicKey: serverPublicKey
        )
        ContractSshServerInitialHandshakeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerInitialHandshakeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTrySshCompleteServerInitialHandshakeX25519Ed25519Request(
    request: ContractSshServerInitialHandshakeX25519Ed25519Request
): ContractSshServerInitialHandshakeOutcome {
    try {
        let result = contractSshCompleteServerInitialHandshakeX25519Ed25519Request(request)
        ContractSshServerInitialHandshakeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerInitialHandshakeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshCompleteClientInitialHandshakeX25519(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
): ContractSshClientInitialHandshakeResult {
    try {
        contractFromSshClientInitialHandshakeResult(
            sshCompleteClientInitialHandshakeX25519WithHostVerificationRequirement(
                transcript,
                clientPrivateKey,
                encodedClientInit,
                encodedServerReply,
                negotiated,
                encodedClientNewKeys,
                encodedServerNewKeys,
                policy: contractToSshHostVerificationPolicy(policy),
                requireVerifiedHost: policy.requireVerifiedHost
            )
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH client initial handshake failed: ${e.message}"
        )
    }
}

public func contractSshCompleteClientInitialHandshakeX25519Request(
    request: ContractSshClientInitialHandshakeX25519Request
): ContractSshClientInitialHandshakeResult {
    contractSshCompleteClientInitialHandshakeX25519(
        contractToSshKexExchangeTranscript(request.transcript),
        request.clientPrivateKey,
        request.encodedClientInit,
        request.encodedServerReply,
        contractToSshNegotiatedAlgorithms(request.negotiated),
        request.encodedClientNewKeys,
        request.encodedServerNewKeys,
        policy: request.policy
    )
}

public func contractTrySshCompleteClientInitialHandshakeX25519(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
): ContractSshClientInitialHandshakeOutcome {
    try {
        let result = contractSshCompleteClientInitialHandshakeX25519(
            transcript,
            clientPrivateKey,
            encodedClientInit,
            encodedServerReply,
            negotiated,
            encodedClientNewKeys,
            encodedServerNewKeys,
            policy: policy
        )
        ContractSshClientInitialHandshakeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshClientInitialHandshakeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTrySshCompleteClientInitialHandshakeX25519Request(
    request: ContractSshClientInitialHandshakeX25519Request
): ContractSshClientInitialHandshakeOutcome {
    try {
        let result = contractSshCompleteClientInitialHandshakeX25519Request(request)
        ContractSshClientInitialHandshakeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshClientInitialHandshakeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshCreateServerRuntime(
    result: ContractSshServerInitialHandshakeResult
): ContractSshServerRuntime {
    ContractSshServerRuntime(result)
}

public func contractSshCreateServerRuntimeRequest(
    request: ContractSshServerRuntimeRequest
): ContractSshServerRuntime {
    contractSshCreateServerRuntime(request.result)
}

public func contractPrepareSshServerRuntimeRequest(
    request: ContractSshServerRuntimeRequest
): ContractSshServerRuntimeBundle {
    let runtime = contractSshCreateServerRuntimeRequest(request)
    let session = runtime.currentSession()
    ContractSshServerRuntimeBundle(runtime, session, runtime.snapshot())
}

public func contractTryPrepareSshServerRuntimeRequest(
    request: ContractSshServerRuntimeRequest
): ContractSshServerRuntimeOutcome {
    try {
        let result = contractPrepareSshServerRuntimeRequest(request)
        ContractSshServerRuntimeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerRuntimeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshCreateClientRuntime(
    result: ContractSshClientInitialHandshakeResult
): ContractSshClientRuntime {
    ContractSshClientRuntime(result)
}

public func contractSshCreateClientRuntimeRequest(
    request: ContractSshClientRuntimeRequest
): ContractSshClientRuntime {
    contractSshCreateClientRuntime(request.result)
}

public func contractPrepareSshClientRuntimeRequest(
    request: ContractSshClientRuntimeRequest
): ContractSshClientRuntimeBundle {
    let runtime = contractSshCreateClientRuntimeRequest(request)
    let session = runtime.currentSession()
    ContractSshClientRuntimeBundle(runtime, session, runtime.snapshot())
}

public func contractTryPrepareSshClientRuntimeRequest(
    request: ContractSshClientRuntimeRequest
): ContractSshClientRuntimeOutcome {
    try {
        let result = contractPrepareSshClientRuntimeRequest(request)
        ContractSshClientRuntimeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshClientRuntimeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshRekeyServerRuntimeX25519(
    runtime: ContractSshServerRuntime,
    kexResult: SshX25519KexResult,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>
): ContractSshServerRuntimeRekeyResult {
    try {
        _ = runtime.transport()._coordinator.rekeyWithX25519(
            kexResult,
            encodedClientNewKeys,
            encodedServerNewKeys
        )
        let session = contractBuildSshSessionStateFromKexResult(
            kexResult,
            runtime.transport().sessionId()
        )
        let updatedRuntime = ContractSshServerRuntime(
            runtime.initialHandshake,
            currentSession: Some(session)
        )
        ContractSshServerRuntimeRekeyResult(updatedRuntime, session)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH server runtime rekey failed: ${e.message}"
        )
    }
}

public func contractSshRekeyServerRuntimeX25519Request(
    request: ContractSshServerRuntimeRekeyRequest
): ContractSshServerRuntimeRekeyResult {
    contractSshRekeyServerRuntimeX25519(
        request.runtime,
        request.kexResult,
        request.encodedClientNewKeys,
        request.encodedServerNewKeys
    )
}

public func contractPrepareSshServerRuntimeRekeyX25519Request(
    request: ContractSshServerRuntimeRekeyRequest
): ContractSshServerRuntimeBundle {
    let result = contractSshRekeyServerRuntimeX25519Request(request)
    ContractSshServerRuntimeBundle(result.runtime, result.session, result.runtime.snapshot())
}

public func contractTryPrepareSshServerRuntimeRekeyX25519Request(
    request: ContractSshServerRuntimeRekeyRequest
): ContractSshServerRuntimeOutcome {
    try {
        let result = contractPrepareSshServerRuntimeRekeyX25519Request(request)
        ContractSshServerRuntimeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerRuntimeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshRekeyClientRuntimeX25519(
    runtime: ContractSshClientRuntime,
    kexResult: SshX25519KexResult,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
): ContractSshClientRuntimeRekeyResult {
    try {
        let verification = if (policy.requireVerifiedHost) {
            _ = runtime.transport()._coordinator.rekeyWithX25519Verified(
                kexResult,
                encodedClientNewKeys,
                encodedServerNewKeys,
                policy: contractToSshHostVerificationPolicy(policy)
            )
            Some(
                contractSshVerifyHostIdentityRequired(
                    kexResult.exchangeHash,
                    kexResult.serverHostKey,
                    kexResult.hostSignature,
                    policy: policy
                )
            )
        } else {
            _ = runtime.transport()._coordinator.rekeyWithX25519(
                kexResult,
                encodedClientNewKeys,
                encodedServerNewKeys
            )
            contractSshVerifyHostIdentity(
                kexResult.exchangeHash,
                kexResult.serverHostKey,
                kexResult.hostSignature,
                policy: policy
            )
        }
        let session = contractBuildSshSessionStateFromKexResult(
            kexResult,
            runtime.transport().sessionId(),
            hostVerification: verification
        )
        let updatedRuntime = ContractSshClientRuntime(
            runtime.initialHandshake,
            currentSession: Some(session)
        )
        ContractSshClientRuntimeRekeyResult(updatedRuntime, session)
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH client runtime rekey failed: ${e.message}"
        )
    }
}

public func contractSshRekeyClientRuntimeX25519Request(
    request: ContractSshClientRuntimeRekeyRequest
): ContractSshClientRuntimeRekeyResult {
    contractSshRekeyClientRuntimeX25519(
        request.runtime,
        request.kexResult,
        request.encodedClientNewKeys,
        request.encodedServerNewKeys,
        policy: request.policy
    )
}

public func contractPrepareSshClientRuntimeRekeyX25519Request(
    request: ContractSshClientRuntimeRekeyRequest
): ContractSshClientRuntimeBundle {
    let result = contractSshRekeyClientRuntimeX25519Request(request)
    ContractSshClientRuntimeBundle(result.runtime, result.session, result.runtime.snapshot())
}

public func contractTryPrepareSshClientRuntimeRekeyX25519Request(
    request: ContractSshClientRuntimeRekeyRequest
): ContractSshClientRuntimeOutcome {
    try {
        let result = contractPrepareSshClientRuntimeRekeyX25519Request(request)
        ContractSshClientRuntimeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshClientRuntimeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshRekeyServerRuntimeFromSessionState(
    runtime: ContractSshServerRuntime,
    session: ContractSshSessionState,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>
): ContractSshServerRuntimeRekeyResult {
    contractSshRekeyServerRuntimeX25519(
        runtime,
        contractToSshX25519KexResult(session),
        encodedClientNewKeys,
        encodedServerNewKeys
    )
}

public func contractSshRekeyServerRuntimeFromSessionStateRequest(
    request: ContractSshServerRuntimeSessionRekeyRequest
): ContractSshServerRuntimeRekeyResult {
    contractSshRekeyServerRuntimeFromSessionState(
        request.runtime,
        request.session,
        request.encodedClientNewKeys,
        request.encodedServerNewKeys
    )
}

public func contractPrepareSshServerRuntimeRekeyFromSessionStateRequest(
    request: ContractSshServerRuntimeSessionRekeyRequest
): ContractSshServerRuntimeBundle {
    let result = contractSshRekeyServerRuntimeFromSessionStateRequest(request)
    ContractSshServerRuntimeBundle(result.runtime, result.session, result.runtime.snapshot())
}

public func contractTryPrepareSshServerRuntimeRekeyFromSessionStateRequest(
    request: ContractSshServerRuntimeSessionRekeyRequest
): ContractSshServerRuntimeOutcome {
    try {
        let result = contractPrepareSshServerRuntimeRekeyFromSessionStateRequest(request)
        ContractSshServerRuntimeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshServerRuntimeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshRekeyClientRuntimeFromSessionState(
    runtime: ContractSshClientRuntime,
    session: ContractSshSessionState,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
): ContractSshClientRuntimeRekeyResult {
    contractSshRekeyClientRuntimeX25519(
        runtime,
        contractToSshX25519KexResult(session),
        encodedClientNewKeys,
        encodedServerNewKeys,
        policy: policy
    )
}

public func contractSshRekeyClientRuntimeFromSessionStateRequest(
    request: ContractSshClientRuntimeSessionRekeyRequest
): ContractSshClientRuntimeRekeyResult {
    contractSshRekeyClientRuntimeFromSessionState(
        request.runtime,
        request.session,
        request.encodedClientNewKeys,
        request.encodedServerNewKeys,
        policy: request.policy
    )
}

public func contractPrepareSshClientRuntimeRekeyFromSessionStateRequest(
    request: ContractSshClientRuntimeSessionRekeyRequest
): ContractSshClientRuntimeBundle {
    let result = contractSshRekeyClientRuntimeFromSessionStateRequest(request)
    ContractSshClientRuntimeBundle(result.runtime, result.session, result.runtime.snapshot())
}

public func contractTryPrepareSshClientRuntimeRekeyFromSessionStateRequest(
    request: ContractSshClientRuntimeSessionRekeyRequest
): ContractSshClientRuntimeOutcome {
    try {
        let result = contractPrepareSshClientRuntimeRekeyFromSessionStateRequest(request)
        ContractSshClientRuntimeOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshClientRuntimeOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractSshVerifyHostIdentity(
    exchangeHash: Array<Byte>,
    serverHostKey: Array<Byte>,
    hostSignature: Array<Byte>,
    policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
): ?ContractSshHostVerificationResult {
    if (policy.requireVerifiedHost) {
        return Some(
            contractSshVerifyHostIdentityRequired(
                exchangeHash,
                serverHostKey,
                hostSignature,
                policy: policy
            )
        )
    }

    try {
        return Some(
            contractSshVerifyHostIdentityRequired(
                exchangeHash,
                serverHostKey,
                hostSignature,
                policy: policy
            )
        )
    } catch (e: ContractException) {
        if (e.code == ContractErrorCode.VerifyFailed || e.code == ContractErrorCode.Unsupported) {
            return None
        }
        throw e
    }
}

public func contractSshVerifyHostIdentityRequest(
    request: ContractSshVerifyHostIdentityRequest
): ?ContractSshHostVerificationResult {
    contractSshVerifyHostIdentity(
        request.exchangeHash,
        request.serverHostKey,
        request.hostSignature,
        policy: request.policy
    )
}

public func contractSshVerifyHostIdentityRequired(
    exchangeHash: Array<Byte>,
    serverHostKey: Array<Byte>,
    hostSignature: Array<Byte>,
    policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
): ContractSshHostVerificationResult {
    try {
        let hostKeyAlgorithm = sshExtractHostKeyAlgorithm(serverHostKey)
        let hostSignatureAlgorithm = sshExtractHostSignatureAlgorithm(hostSignature)
        let hostKeySha256 = sshComputeHostKeySha256(serverHostKey)

        if (policy.expectedHostKeySha256.size != 0) {
            if (!constantTimeEquals(policy.expectedHostKeySha256, hostKeySha256)) {
                if (policy.requireKnownHost) {
                    throw ContractException(ContractErrorCode.VerifyFailed, "SSH known-host fingerprint verification failed")
                }
            }
        }

        var signatureVerified = false
        if (policy.requireHostSignature) {
            signatureVerified = sshVerifyServerHostSignature(
                exchangeHash,
                serverHostKey,
                hostSignature,
                negotiatedHostKeyAlgorithm: policy.negotiatedHostKeyAlgorithm,
                allowLegacyRsaSha1: policy.allowLegacyRsaSha1
            )
            if (!signatureVerified) {
                throw ContractException(ContractErrorCode.VerifyFailed, "SSH server host signature verification failed")
            }
        }

        ContractSshHostVerificationResult(
            hostKeyAlgorithm,
            hostSignatureAlgorithm,
            hostKeySha256,
            signatureVerified
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH host verification failed: ${e.message}"
        )
    }
}

public func contractSshVerifyHostIdentityRequiredRequest(
    request: ContractSshVerifyHostIdentityRequest
): ContractSshHostVerificationResult {
    contractSshVerifyHostIdentityRequired(
        request.exchangeHash,
        request.serverHostKey,
        request.hostSignature,
        policy: request.policy
    )
}

public func contractSshEncodeTransportPacket(
    payload: Array<Byte>,
    blockSize!: Int64 = SSH_DEFAULT_PACKET_BLOCK_SIZE,
    randomPadding!: Array<Byte> = []
): Array<Byte> {
    try {
        sshEncodeTransportPacket(
            payload,
            blockSize: blockSize,
            randomPadding: randomPadding
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH transport packet encode failed: ${e.message}"
        )
    }
}

public func contractSshEncodeTransportPacketRequest(
    request: ContractSshEncodeTransportPacketRequest
): Array<Byte> {
    contractSshEncodeTransportPacket(
        request.payload,
        blockSize: request.blockSize,
        randomPadding: request.randomPadding
    )
}

public func contractSshDecodeTransportPacket(
    encodedPacket: Array<Byte>,
    blockSize!: Int64 = SSH_DEFAULT_PACKET_BLOCK_SIZE
): ContractSshTransportPacket {
    try {
        contractFromSshTransportPacket(
            sshDecodeTransportPacket(encodedPacket, blockSize: blockSize)
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH transport packet decode failed: ${e.message}"
        )
    }
}

public func contractSshDecodeTransportPacketRequest(
    request: ContractSshDecodeTransportPacketRequest
): ContractSshTransportPacket {
    contractSshDecodeTransportPacket(request.encodedPacket, blockSize: request.blockSize)
}

public func contractTrySshVerifyHostIdentityRequired(
    exchangeHash: Array<Byte>,
    serverHostKey: Array<Byte>,
    hostSignature: Array<Byte>,
    policy!: ContractSshHostVerificationPolicy = ContractSshHostVerificationPolicy()
): ContractSshHostVerificationOutcome {
    try {
        let result = contractSshVerifyHostIdentityRequired(
            exchangeHash,
            serverHostKey,
            hostSignature,
            policy: policy
        )
        ContractSshHostVerificationOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSshHostVerificationOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTrySshVerifyHostIdentityRequiredRequest(
    request: ContractSshVerifyHostIdentityRequest
): ContractSshHostVerificationOutcome {
    contractTrySshVerifyHostIdentityRequired(
        request.exchangeHash,
        request.serverHostKey,
        request.hostSignature,
        policy: request.policy
    )
}

private func contractTryHostVerificationSignatureVerified(
    verification: ?ContractSshHostVerificationResult
): ?Bool {
    match (verification) {
        case Some(value) => Some(value.hostSignatureVerified)
        case None => None
    }
}

private func contractFromSshServerInitialHandshakeResult(
    result: SshServerInitialHandshakeResult
): ContractSshServerInitialHandshakeResult {
    let kex = result.kexResult
    let hostKeyAlgorithm = sshExtractHostKeyAlgorithm(kex.serverHostKey)
    let hostSignatureAlgorithm = sshExtractHostSignatureAlgorithm(kex.hostSignature)
    let hostKeySha256 = sshComputeHostKeySha256(kex.serverHostKey)
    ContractSshServerInitialHandshakeResult(
        result.encodedReply,
        kex.sharedSecret,
        kex.exchangeHash,
        kex.sessionId,
        kex.clientEphemeralPublicKey,
        kex.serverEphemeralPublicKey,
        kex.serverHostKey,
        kex.hostSignature,
        hostKeyAlgorithm,
        hostSignatureAlgorithm,
        hostKeySha256,
        ContractSshTransportChannel(result.coordinator)
    )
}

private func contractResolveSshServerRuntimeSessionState(
    initialHandshake: ContractSshServerInitialHandshakeResult,
    currentSession: ?ContractSshSessionState
): ContractSshSessionState {
    match (currentSession) {
        case Some(value) => value
        case None => contractBuildSshSessionStateFromServerInitialHandshake(initialHandshake)
    }
}

private func contractResolveSshClientRuntimeSessionState(
    initialHandshake: ContractSshClientInitialHandshakeResult,
    currentSession: ?ContractSshSessionState
): ContractSshSessionState {
    match (currentSession) {
        case Some(value) => value
        case None => contractBuildSshSessionStateFromClientInitialHandshake(initialHandshake)
    }
}

private func contractBuildSshSessionStateFromServerInitialHandshake(
    result: ContractSshServerInitialHandshakeResult
): ContractSshSessionState {
    ContractSshSessionState(
        result.sharedSecret,
        result.exchangeHash,
        result.sessionId,
        result.clientEphemeralPublicKey,
        result.serverEphemeralPublicKey,
        result.serverHostKey,
        result.hostSignature,
        result.hostKeyAlgorithm,
        result.hostSignatureAlgorithm,
        result.hostKeySha256
    )
}

private func contractBuildSshSessionStateFromClientInitialHandshake(
    result: ContractSshClientInitialHandshakeResult
): ContractSshSessionState {
    ContractSshSessionState(
        result.sharedSecret,
        result.exchangeHash,
        result.sessionId,
        result.clientEphemeralPublicKey,
        result.serverEphemeralPublicKey,
        result.serverHostKey,
        result.hostSignature,
        result.hostKeyAlgorithm,
        result.hostSignatureAlgorithm,
        result.hostKeySha256,
        hostVerification: result.hostVerification
    )
}

private func contractBuildSshSessionStateFromKexResult(
    kexResult: SshX25519KexResult,
    sessionId: Array<Byte>,
    hostVerification!: ?ContractSshHostVerificationResult = None
): ContractSshSessionState {
    let hostKeyAlgorithm = sshExtractHostKeyAlgorithm(kexResult.serverHostKey)
    let hostSignatureAlgorithm = sshExtractHostSignatureAlgorithm(kexResult.hostSignature)
    let hostKeySha256 = sshComputeHostKeySha256(kexResult.serverHostKey)
    ContractSshSessionState(
        kexResult.sharedSecret,
        kexResult.exchangeHash,
        sessionId,
        kexResult.clientEphemeralPublicKey,
        kexResult.serverEphemeralPublicKey,
        kexResult.serverHostKey,
        kexResult.hostSignature,
        hostKeyAlgorithm,
        hostSignatureAlgorithm,
        hostKeySha256,
        hostVerification: hostVerification
    )
}

private func contractFromSshClientInitialHandshakeResult(
    result: SshClientInitialHandshakeResult
): ContractSshClientInitialHandshakeResult {
    let kex = result.kexResult
    let hostKeyAlgorithm = sshExtractHostKeyAlgorithm(kex.serverHostKey)
    let hostSignatureAlgorithm = sshExtractHostSignatureAlgorithm(kex.hostSignature)
    let hostKeySha256 = sshComputeHostKeySha256(kex.serverHostKey)
    ContractSshClientInitialHandshakeResult(
        kex.sharedSecret,
        kex.exchangeHash,
        kex.sessionId,
        kex.clientEphemeralPublicKey,
        kex.serverEphemeralPublicKey,
        kex.serverHostKey,
        kex.hostSignature,
        hostKeyAlgorithm,
        hostSignatureAlgorithm,
        hostKeySha256,
        ContractSshTransportChannel(result.coordinator),
        hostVerification: contractTryFromSshHostVerificationResult(result.hostVerification)
    )
}

private func contractFromSshTransportPacket(packet: SshTransportPacket): ContractSshTransportPacket {
    ContractSshTransportPacket(packet.packetLength, packet.payload, packet.padding)
}

private func contractFromSshKexEcdhInitMessage(
    message: SshKexEcdhInitMessage
): ContractSshKexEcdhInitMessage {
    ContractSshKexEcdhInitMessage(message.clientEphemeralPublicKey)
}

private func contractToSshKexEcdhInitMessage(
    message: ContractSshKexEcdhInitMessage
): SshKexEcdhInitMessage {
    try {
        SshKexEcdhInitMessage(message.clientEphemeralPublicKey)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEX_ECDH_INIT message is invalid: ${e.message}"
        )
    }
}

private func contractFromSshKexEcdhReplyMessage(
    message: SshKexEcdhReplyMessage
): ContractSshKexEcdhReplyMessage {
    ContractSshKexEcdhReplyMessage(
        message.serverHostKey,
        message.serverEphemeralPublicKey,
        message.signature
    )
}

private func contractToSshKexEcdhReplyMessage(
    message: ContractSshKexEcdhReplyMessage
): SshKexEcdhReplyMessage {
    try {
        SshKexEcdhReplyMessage(
            message.serverHostKey,
            message.serverEphemeralPublicKey,
            message.signature
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEX_ECDH_REPLY message is invalid: ${e.message}"
        )
    }
}

private func contractFromSshVersionBanner(banner: SshVersionBanner): ContractSshVersionBanner {
    ContractSshVersionBanner(
        banner.protocolVersion,
        banner.softwareVersion,
        comments: banner.comments
    )
}

private func contractToSshVersionBanner(banner: ContractSshVersionBanner): SshVersionBanner {
    try {
        SshVersionBanner(
            banner.protocolVersion,
            banner.softwareVersion,
            comments: banner.comments
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH version banner is invalid: ${e.message}"
        )
    }
}

private func contractTryFromSshHostVerificationResult(
    result: ?SshHostVerificationResult
): ?ContractSshHostVerificationResult {
    match (result) {
        case Some(value) => Some(contractFromSshHostVerificationResult(value))
        case None => None
    }
}

private func contractFromSshHostVerificationResult(
    result: SshHostVerificationResult
): ContractSshHostVerificationResult {
    ContractSshHostVerificationResult(
        result.hostKeyAlgorithm,
        result.hostSignatureAlgorithm,
        result.hostKeySha256,
        result.hostSignatureVerified
    )
}

private func contractFromSshKexInitMessage(
    message: SshKexInitMessage
): ContractSshKexInitMessage {
    ContractSshKexInitMessage(
        message.cookie,
        message.kexAlgorithms,
        message.serverHostKeyAlgorithms,
        message.encryptionAlgorithmsClientToServer,
        message.encryptionAlgorithmsServerToClient,
        message.macAlgorithmsClientToServer,
        message.macAlgorithmsServerToClient,
        message.compressionAlgorithmsClientToServer,
        message.compressionAlgorithmsServerToClient,
        languagesClientToServer: message.languagesClientToServer,
        languagesServerToClient: message.languagesServerToClient,
        firstKexPacketFollows: message.firstKexPacketFollows,
        reserved: message.reserved
    )
}

private func contractFromSshNegotiatedAlgorithms(
    negotiated: SshNegotiatedAlgorithms
): ContractSshNegotiatedAlgorithms {
    ContractSshNegotiatedAlgorithms(
        negotiated.kexAlgorithm,
        negotiated.serverHostKeyAlgorithm,
        negotiated.encryptionAlgorithmClientToServer,
        negotiated.encryptionAlgorithmServerToClient,
        negotiated.macAlgorithmClientToServer,
        negotiated.macAlgorithmServerToClient,
        compressionAlgorithmClientToServer: negotiated.compressionAlgorithmClientToServer,
        compressionAlgorithmServerToClient: negotiated.compressionAlgorithmServerToClient
    )
}

private func contractToSshNegotiatedAlgorithms(
    negotiated: ContractSshNegotiatedAlgorithms
): SshNegotiatedAlgorithms {
    SshNegotiatedAlgorithms(
        negotiated.kexAlgorithm,
        negotiated.serverHostKeyAlgorithm,
        negotiated.encryptionAlgorithmClientToServer,
        negotiated.encryptionAlgorithmServerToClient,
        negotiated.macAlgorithmClientToServer,
        negotiated.macAlgorithmServerToClient,
        negotiated.compressionAlgorithmClientToServer,
        negotiated.compressionAlgorithmServerToClient
    )
}

private func contractToSshKexInitMessage(
    message: ContractSshKexInitMessage
): SshKexInitMessage {
    contractToSshKexInitMessage(
        message.cookie,
        message.kexAlgorithms,
        message.serverHostKeyAlgorithms,
        message.encryptionAlgorithmsClientToServer,
        message.encryptionAlgorithmsServerToClient,
        message.macAlgorithmsClientToServer,
        message.macAlgorithmsServerToClient,
        message.compressionAlgorithmsClientToServer,
        message.compressionAlgorithmsServerToClient,
        languagesClientToServer: message.languagesClientToServer,
        languagesServerToClient: message.languagesServerToClient,
        firstKexPacketFollows: message.firstKexPacketFollows,
        reserved: message.reserved
    )
}

private func contractToSshKexInitMessage(
    cookie: Array<Byte>,
    kexAlgorithms: Array<String>,
    serverHostKeyAlgorithms: Array<String>,
    encryptionAlgorithmsClientToServer: Array<String>,
    encryptionAlgorithmsServerToClient: Array<String>,
    macAlgorithmsClientToServer: Array<String>,
    macAlgorithmsServerToClient: Array<String>,
    compressionAlgorithmsClientToServer: Array<String>,
    compressionAlgorithmsServerToClient: Array<String>,
    languagesClientToServer!: Array<String> = [],
    languagesServerToClient!: Array<String> = [],
    firstKexPacketFollows!: Bool = false,
    reserved!: Int64 = 0
): SshKexInitMessage {
    try {
        SshKexInitMessage(
            cookie,
            kexAlgorithms,
            serverHostKeyAlgorithms,
            encryptionAlgorithmsClientToServer,
            encryptionAlgorithmsServerToClient,
            macAlgorithmsClientToServer,
            macAlgorithmsServerToClient,
            compressionAlgorithmsClientToServer,
            compressionAlgorithmsServerToClient,
            languagesClientToServer: languagesClientToServer,
            languagesServerToClient: languagesServerToClient,
            firstKexPacketFollows: firstKexPacketFollows,
            reserved: reserved
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEXINIT message is invalid: ${e.message}"
        )
    }
}

private func contractToSshKexExchangeTranscript(
    transcript: ContractSshKexExchangeTranscript
): SshKexExchangeTranscript {
    contractToSshKexExchangeTranscript(
        transcript.clientBannerLine,
        transcript.serverBannerLine,
        transcript.clientKexInitPayload,
        transcript.serverKexInitPayload
    )
}

private func contractToSshKexExchangeTranscript(
    clientBannerLine: Array<Byte>,
    serverBannerLine: Array<Byte>,
    clientKexInitPayload: Array<Byte>,
    serverKexInitPayload: Array<Byte>
): SshKexExchangeTranscript {
    try {
        SshKexExchangeTranscript(
            clientBannerLine,
            serverBannerLine,
            clientKexInitPayload,
            serverKexInitPayload
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEX transcript is invalid: ${e.message}"
        )
    }
}

private func contractCloneStringArray(values: Array<String>): Array<String> {
    let out = ArrayList<String>()
    for (value in values) {
        out.add(value)
    }
    out.toArray()
}

private func contractToSshX25519KexResult(
    session: ContractSshSessionState
): SshX25519KexResult {
    SshX25519KexResult(
        session.sharedSecret,
        session.exchangeHash,
        session.sessionId,
        session.clientEphemeralPublicKey,
        session.serverEphemeralPublicKey,
        session.serverHostKey,
        session.hostSignature
    )
}

private func contractToSshHostVerificationPolicy(
    policy: ContractSshHostVerificationPolicy
): SshHostVerificationPolicy {
    SshHostVerificationPolicy(
        negotiatedHostKeyAlgorithm: policy.negotiatedHostKeyAlgorithm,
        expectedHostKeySha256: policy.expectedHostKeySha256,
        requireKnownHost: policy.requireKnownHost,
        requireHostSignature: policy.requireHostSignature,
        allowLegacyRsaSha1: policy.allowLegacyRsaSha1
    )
}

private func contractDerChainFromCertificates(certChain: Array<X509Certificate>): Array<Array<Byte>> {
    let out = ArrayList<Array<Byte>>()
    for (cert in certChain) {
        out.add(cert.der.clone())
    }
    out.toArray()
}

private func contractTryParseRsaPrivateKeyPkcs8Pem(pkcs8Pem: String): ?RsaPrivateKey {
    try {
        Some(x509ParseRsaPrivateKeyPkcs8Pem(pkcs8Pem))
    } catch (e: CryptoException) {
        if (e.code == ParseError) {
            return None
        }
        throw e
    }
}

private func contractTryParseEcPrivateKeyPkcs8Pem(pkcs8Pem: String): ?EcPrivateKey {
    try {
        Some(x509ParseEcPrivateKeyPkcs8Pem(pkcs8Pem))
    } catch (e: CryptoException) {
        if (e.code == ParseError) {
            return None
        }
        throw e
    }
}

private func contractParseRsaPrivateKeyPkcs8PemForSshHostSigning(pkcs8Pem: String): RsaPrivateKey {
    try {
        x509ParseRsaPrivateKeyPkcs8Pem(pkcs8Pem)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH RSA host signing request failed: ${e.message}"
        )
    }
}

private func contractParseEcPrivateKeyPkcs8PemForSshHostSigning(pkcs8Pem: String): EcPrivateKey {
    try {
        x509ParseEcPrivateKeyPkcs8Pem(pkcs8Pem)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH ECDSA host signing request failed: ${e.message}"
        )
    }
}

private func contractBuildSshHostSigningResult(
    serverHostKey: Array<Byte>,
    hostSignature: Array<Byte>
): ContractSshHostSigningResult {
    try {
        let hostKeyAlgorithm = sshExtractHostKeyAlgorithm(serverHostKey)
        let hostSignatureAlgorithm = sshExtractHostSignatureAlgorithm(hostSignature)
        let hostKeySha256 = contractSshComputeHostKeySha256(serverHostKey)
        ContractSshHostSigningResult(
            serverHostKey,
            hostSignature,
            hostKeyAlgorithm,
            hostSignatureAlgorithm,
            hostKeySha256
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH host signing result construction failed: ${e.message}"
        )
    }
}

private func contractIsSomeRsaPrivateKey(value: ?RsaPrivateKey): Bool {
    if (let Some(_inner) <- value) {
        return true
    }
    false
}

private func contractIsSomeEcPrivateKey(value: ?EcPrivateKey): Bool {
    if (let Some(_inner) <- value) {
        return true
    }
    false
}

private func contractToTls12KeyExchange(
    keyExchange: ContractTls12KeyExchange
): Tls12KeyExchange {
    match (keyExchange) {
        case ContractTls12KeyExchange.Rsa => Tls12KeyExchange.RSA
        case ContractTls12KeyExchange.EcdheP256 => Tls12KeyExchange.ECDHE_P256
        case ContractTls12KeyExchange.EcdheP384 => Tls12KeyExchange.ECDHE_P384
    }
}

private func contractFromTls12HandshakeSecrets(
    secrets: Tls12HandshakeSecrets
): ContractTls12HandshakeSecrets {
    ContractTls12HandshakeSecrets(
        secrets.masterSecret,
        secrets.clientWriteKey,
        secrets.clientWriteIv,
        secrets.serverWriteKey,
        secrets.serverWriteIv
    )
}

private func contractToTls12HandshakeSecrets(
    secrets: ContractTls12HandshakeSecrets
): Tls12HandshakeSecrets {
    Tls12HandshakeSecrets(
        secrets.masterSecret,
        secrets.clientWriteKey,
        secrets.serverWriteKey,
        secrets.clientWriteIv,
        secrets.serverWriteIv
    )
}

private func contractToTlsContentType(
    contentType: ContractTlsRecordContentType
): TlsContentType {
    match (contentType) {
        case ContractTlsRecordContentType.ChangeCipherSpec => TlsContentType.ChangeCipherSpec
        case ContractTlsRecordContentType.Alert => TlsContentType.Alert
        case ContractTlsRecordContentType.Handshake => TlsContentType.Handshake
        case ContractTlsRecordContentType.ApplicationData => TlsContentType.ApplicationData
    }
}

private func contractFromTlsContentType(
    contentType: TlsContentType
): ContractTlsRecordContentType {
    match (contentType) {
        case TlsContentType.ChangeCipherSpec => ContractTlsRecordContentType.ChangeCipherSpec
        case TlsContentType.Alert => ContractTlsRecordContentType.Alert
        case TlsContentType.Handshake => ContractTlsRecordContentType.Handshake
        case TlsContentType.ApplicationData => ContractTlsRecordContentType.ApplicationData
    }
}

private func contractFromTlsAeadAlgorithm(algorithm: TlsAeadAlgorithm): ContractAeadAlgorithm {
    match (algorithm) {
        case TlsAeadAlgorithm.AES_GCM => ContractAeadAlgorithm.Aes256Gcm
        case TlsAeadAlgorithm.CHACHA20_POLY1305 => ContractAeadAlgorithm.Chacha20Poly1305
    }
}

private func contractFromTlsVersion(version: TlsVersion): ContractTlsVersion {
    if (version == TLS_VERSION_1_2) {
        return ContractTlsVersion.Tls12
    }
    if (version == TLS_VERSION_1_3) {
        return ContractTlsVersion.Tls13
    }
    throw ContractException(
        ContractErrorCode.Unsupported,
        "unsupported TLS version in contract record channel: ${version.toString()}"
    )
}

private func contractToTlsVersion(version: ContractTlsVersion): TlsVersion {
    match (version) {
        case ContractTlsVersion.Tls12 => TLS_VERSION_1_2
        case ContractTlsVersion.Tls13 => TLS_VERSION_1_3
    }
}

private func contractToTlsAlertLevel(level: ContractTlsAlertLevel): TlsAlertLevel {
    match (level) {
        case ContractTlsAlertLevel.AlertWarning => TlsAlertLevel.Warning
        case ContractTlsAlertLevel.AlertFatal => TlsAlertLevel.Fatal
    }
}

private func contractFromTlsAlertLevel(level: TlsAlertLevel): ContractTlsAlertLevel {
    match (level) {
        case TlsAlertLevel.Warning => ContractTlsAlertLevel.AlertWarning
        case TlsAlertLevel.Fatal => ContractTlsAlertLevel.AlertFatal
    }
}

private func contractToTlsAlertDescription(
    description: ContractTlsAlertDescription
): TlsAlertDescription {
    match (description) {
        case ContractTlsAlertDescription.AlertCloseNotify => TlsAlertDescription.CloseNotify
        case ContractTlsAlertDescription.AlertUnexpectedMessage => TlsAlertDescription.UnexpectedMessage
        case ContractTlsAlertDescription.AlertBadRecordMac => TlsAlertDescription.BadRecordMac
        case ContractTlsAlertDescription.AlertDecryptionFailedReserved => TlsAlertDescription.DecryptionFailedReserved
        case ContractTlsAlertDescription.AlertRecordOverflow => TlsAlertDescription.RecordOverflow
        case ContractTlsAlertDescription.AlertHandshakeFailure => TlsAlertDescription.HandshakeFailure
        case ContractTlsAlertDescription.AlertBadCertificate => TlsAlertDescription.BadCertificate
        case ContractTlsAlertDescription.AlertUnsupportedCertificate => TlsAlertDescription.UnsupportedCertificate
        case ContractTlsAlertDescription.AlertCertificateRevoked => TlsAlertDescription.CertificateRevoked
        case ContractTlsAlertDescription.AlertCertificateExpired => TlsAlertDescription.CertificateExpired
        case ContractTlsAlertDescription.AlertCertificateUnknown => TlsAlertDescription.CertificateUnknown
        case ContractTlsAlertDescription.AlertIllegalParameter => TlsAlertDescription.IllegalParameter
        case ContractTlsAlertDescription.AlertUnknownCa => TlsAlertDescription.UnknownCa
        case ContractTlsAlertDescription.AlertAccessDenied => TlsAlertDescription.AccessDenied
        case ContractTlsAlertDescription.AlertDecodeError => TlsAlertDescription.DecodeError
        case ContractTlsAlertDescription.AlertDecryptError => TlsAlertDescription.DecryptError
        case ContractTlsAlertDescription.AlertProtocolVersion => TlsAlertDescription.ProtocolVersion
        case ContractTlsAlertDescription.AlertInsufficientSecurity => TlsAlertDescription.InsufficientSecurity
        case ContractTlsAlertDescription.AlertInternalError => TlsAlertDescription.InternalError
        case ContractTlsAlertDescription.AlertUserCanceled => TlsAlertDescription.UserCanceled
        case ContractTlsAlertDescription.AlertMissingExtension => TlsAlertDescription.MissingExtension
        case ContractTlsAlertDescription.AlertUnsupportedExtension => TlsAlertDescription.UnsupportedExtension
        case ContractTlsAlertDescription.AlertUnrecognizedName => TlsAlertDescription.UnrecognizedName
        case ContractTlsAlertDescription.AlertBadCertificateStatusResponse => TlsAlertDescription.BadCertificateStatusResponse
        case ContractTlsAlertDescription.AlertUnknownPskIdentity => TlsAlertDescription.UnknownPskIdentity
        case ContractTlsAlertDescription.AlertCertificateRequired => TlsAlertDescription.CertificateRequired
        case ContractTlsAlertDescription.AlertNoApplicationProtocol => TlsAlertDescription.NoApplicationProtocol
    }
}

private func contractFromTlsAlertDescription(
    description: TlsAlertDescription
): ContractTlsAlertDescription {
    match (description) {
        case TlsAlertDescription.CloseNotify => ContractTlsAlertDescription.AlertCloseNotify
        case TlsAlertDescription.UnexpectedMessage => ContractTlsAlertDescription.AlertUnexpectedMessage
        case TlsAlertDescription.BadRecordMac => ContractTlsAlertDescription.AlertBadRecordMac
        case TlsAlertDescription.DecryptionFailedReserved => ContractTlsAlertDescription.AlertDecryptionFailedReserved
        case TlsAlertDescription.RecordOverflow => ContractTlsAlertDescription.AlertRecordOverflow
        case TlsAlertDescription.HandshakeFailure => ContractTlsAlertDescription.AlertHandshakeFailure
        case TlsAlertDescription.BadCertificate => ContractTlsAlertDescription.AlertBadCertificate
        case TlsAlertDescription.UnsupportedCertificate => ContractTlsAlertDescription.AlertUnsupportedCertificate
        case TlsAlertDescription.CertificateRevoked => ContractTlsAlertDescription.AlertCertificateRevoked
        case TlsAlertDescription.CertificateExpired => ContractTlsAlertDescription.AlertCertificateExpired
        case TlsAlertDescription.CertificateUnknown => ContractTlsAlertDescription.AlertCertificateUnknown
        case TlsAlertDescription.IllegalParameter => ContractTlsAlertDescription.AlertIllegalParameter
        case TlsAlertDescription.UnknownCa => ContractTlsAlertDescription.AlertUnknownCa
        case TlsAlertDescription.AccessDenied => ContractTlsAlertDescription.AlertAccessDenied
        case TlsAlertDescription.DecodeError => ContractTlsAlertDescription.AlertDecodeError
        case TlsAlertDescription.DecryptError => ContractTlsAlertDescription.AlertDecryptError
        case TlsAlertDescription.ProtocolVersion => ContractTlsAlertDescription.AlertProtocolVersion
        case TlsAlertDescription.InsufficientSecurity => ContractTlsAlertDescription.AlertInsufficientSecurity
        case TlsAlertDescription.InternalError => ContractTlsAlertDescription.AlertInternalError
        case TlsAlertDescription.UserCanceled => ContractTlsAlertDescription.AlertUserCanceled
        case TlsAlertDescription.MissingExtension => ContractTlsAlertDescription.AlertMissingExtension
        case TlsAlertDescription.UnsupportedExtension => ContractTlsAlertDescription.AlertUnsupportedExtension
        case TlsAlertDescription.UnrecognizedName => ContractTlsAlertDescription.AlertUnrecognizedName
        case TlsAlertDescription.BadCertificateStatusResponse => ContractTlsAlertDescription.AlertBadCertificateStatusResponse
        case TlsAlertDescription.UnknownPskIdentity => ContractTlsAlertDescription.AlertUnknownPskIdentity
        case TlsAlertDescription.CertificateRequired => ContractTlsAlertDescription.AlertCertificateRequired
        case TlsAlertDescription.NoApplicationProtocol => ContractTlsAlertDescription.AlertNoApplicationProtocol
    }
}

private func contractFromTlsAlertMessage(alert: TlsAlertMessage): ContractTlsAlertMessage {
    ContractTlsAlertMessage(
        contractFromTlsAlertLevel(alert.level),
        contractFromTlsAlertDescription(alert.description)
    )
}

private func contractToTlsSessionIdentity(identity: ContractTlsSessionIdentity): TlsSessionIdentity {
    TlsSessionIdentity(
        contractToTlsVersion(identity.version),
        identity.resumptionId,
        serverName: identity.serverName,
        alpnProtocol: identity.alpnProtocol
    )
}

private func contractFromTlsSessionIdentity(identity: TlsSessionIdentity): ContractTlsSessionIdentity {
    ContractTlsSessionIdentity(
        contractFromTlsVersion(identity.version),
        identity.resumptionId,
        serverName: identity.serverName,
        alpnProtocol: identity.alpnProtocol
    )
}

private func contractToTlsSessionTicket(ticket: ContractTlsSessionTicket): TlsSessionTicket {
    TlsSessionTicket(
        contractToTlsSessionIdentity(ticket.identity),
        ticket.secret,
        ticket.nonce,
        ticket.issuedAtUnixSeconds,
        ticket.expiresAtUnixSeconds,
        version: ticket.version
    )
}

private func contractFromTlsSessionTicket(ticket: TlsSessionTicket): ContractTlsSessionTicket {
    ContractTlsSessionTicket(
        ticket.version,
        contractFromTlsSessionIdentity(ticket.identity),
        ticket.secret,
        ticket.nonce,
        ticket.issuedAtUnixSeconds,
        ticket.expiresAtUnixSeconds
    )
}

private func contractFromTlsSessionCacheStats(stats: TlsSessionCacheStats): ContractTlsSessionCacheStats {
    ContractTlsSessionCacheStats(
        stats.size,
        stats.hits,
        stats.misses,
        stats.evictions,
        stats.expiredRemovals
    )
}

private func contractFromAesHardwareMountPoint(
    mount: AesHardwareMountPoint
): ContractAesHardwareMountPointInfo {
    ContractAesHardwareMountPointInfo(
        mount.backend,
        mount.available,
        mount.accelerated,
        mount.detected,
        mount.detail
    )
}

private func contractFromAesHardwareProbe(
    probe: AesHardwareProbe
): ContractAesHardwareProbeInfo {
    ContractAesHardwareProbeInfo(
        probe.available,
        probe.backend,
        probe.accelerated,
        probe.detail
    )
}

private func contractFromAesHardwareRoadmapEntry(
    entry: AesHardwareRoadmapEntry
): ContractAesHardwareRoadmapEntry {
    ContractAesHardwareRoadmapEntry(
        entry.architecture,
        entry.backend,
        entry.status,
        entry.targetVersion,
        entry.detail
    )
}

private func contractFromAesEngineKind(kind: AesEngineKind): ContractAesEngineKind {
    match (kind) {
        case AUTO => ContractAesEngineKind.Auto
        case SOFTWARE => ContractAesEngineKind.Software
        case HARDWARE => ContractAesEngineKind.Hardware
    }
}

private func contractToAesEngineKind(kind: ContractAesEngineKind): AesEngineKind {
    match (kind) {
        case ContractAesEngineKind.Auto => AesEngineKind.AUTO
        case ContractAesEngineKind.Software => AesEngineKind.SOFTWARE
        case ContractAesEngineKind.Hardware => AesEngineKind.HARDWARE
    }
}

private func contractFromAesEngine(engine: AesEngine): ContractAesEngineInfo {
    ContractAesEngineInfo(
        contractFromAesEngineKind(engine.requested),
        contractFromAesEngineKind(engine.active),
        engine.backend,
        engine.accelerated,
        engine.detail
    )
}

private func contractToAesNativeBridgeSpec(spec: ContractAesNativeBridgeSpec): AesNativeBridgeSpec {
    AesNativeBridgeSpec(
        spec.backend,
        spec.libraryPath,
        symbolPrefix: spec.symbolPrefix,
        abiVersion: spec.abiVersion
    )
}

private func contractFromAesNativeBridgeContract(
    contract: AesNativeBridgeContract
): ContractAesNativeBridgeContractInfo {
    ContractAesNativeBridgeContractInfo(
        contract.backend,
        contract.abiVersion,
        contract.expandKeySymbol,
        contract.encryptBlocksSymbol,
        contract.decryptBlocksSymbol,
        contract.ghashMulSymbol,
        contract.detail
    )
}

private func contractFromAesNativeBridgeCallShape(
    shape: AesNativeBridgeCallShape
): ContractAesNativeBridgeCallShapeInfo {
    ContractAesNativeBridgeCallShapeInfo(
        shape.backend,
        shape.abiVersion,
        shape.keyBytes,
        shape.roundCount,
        shape.roundKeyWordCount,
        shape.expandedKeyBlobBytes,
        shape.blockBytes,
        shape.requiresBlockAlignedPayload
    )
}

private func contractFindAesMountPoint(
    mounts: Array<ContractAesHardwareMountPointInfo>,
    backend: String
): ?ContractAesHardwareMountPointInfo {
    for (mount in mounts) {
        if (mount.backend == backend) {
            return Some(mount)
        }
    }
    None
}

private func contractFindPrimaryAesRoadmapBackend(
    roadmap: Array<ContractAesHardwareRoadmapEntry>
): String {
    for (entry in roadmap) {
        if (entry.status == "PRIMARY_ACTIVE") {
            return entry.backend
        }
    }
    throw ContractException(
        ContractErrorCode.InternalError,
        "AES roadmap does not define a primary active backend"
    )
}

private func contractCollectAesRoadmapArchitectures(
    roadmap: Array<ContractAesHardwareRoadmapEntry>,
    status: String
): Array<String> {
    let values = ArrayList<String>()
    for (entry in roadmap) {
        if (entry.status == status) {
            values.add(entry.architecture)
        }
    }
    values.toArray()
}

private func contractCollectAesRoadmapBackendsByPrefix(
    roadmap: Array<ContractAesHardwareRoadmapEntry>,
    statusPrefix: String
): Array<String> {
    let values = ArrayList<String>()
    for (entry in roadmap) {
        if (entry.status.startsWith(statusPrefix)) {
            values.add(entry.backend)
        }
    }
    values.toArray()
}

private func contractHasAllFeatures(
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

private func contractRequireHttpTlsStartupProfile(
    template: ContractHttpSshStartupProfileTemplate,
    scenario: String
): Unit {
    if (!template.policy.requireHttpTls) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "HTTP startup profile ${template.profile.toString()} does not enable HTTP/TLS for ${scenario}"
        )
    }
    if (!template.policy.requireX509) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "HTTP startup profile ${template.profile.toString()} does not enable X.509 for ${scenario}"
        )
    }
}

private func contractRequireSshStartupProfile(
    template: ContractHttpSshStartupProfileTemplate,
    scenario: String
): Unit {
    if (!template.policy.requireSsh) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "SSH startup profile ${template.profile.toString()} does not enable SSH for ${scenario}"
        )
    }
}

private func contractJoinMessages(
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

private func contractTls12ResolveEcdheCurveSpec(
    keyExchange: ContractTls12KeyExchange
): (NamedCurve, Int64) {
    match (keyExchange) {
        case ContractTls12KeyExchange.EcdheP256 => (P256, 32)
        case ContractTls12KeyExchange.EcdheP384 => (P384, 48)
        case ContractTls12KeyExchange.Rsa =>
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.2 ECDHE contract API requires ECDHE_P256 or ECDHE_P384 key exchange"
            )
    }
}

private func contractTls12EcPrivateKeyFromScalar(
    curve: NamedCurve,
    scalar: Array<Byte>,
    fieldBytes: Int64,
    roleLabel: String
): EcPrivateKey {
    if (scalar.size != fieldBytes) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "TLS1.2 ECDHE ${roleLabel} private scalar must be ${fieldBytes} bytes"
        )
    }
    if (isZeroBytes(scalar)) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "TLS1.2 ECDHE ${roleLabel} private scalar must not be zero"
        )
    }
    EcPrivateKey(curve, BigNum.fromBytesBE(scalar))
}

private func contractToTlsHttpNegotiationPolicy(
    policy: ContractTlsHttpNegotiationPolicy
): TlsHttpNegotiationPolicy {
    TlsHttpNegotiationPolicy(
        requireServerName: policy.requireServerName,
        allowedServerNames: policy.allowedServerNames,
        alpnPreference: policy.alpnPreference
    )
}

private func contractTls13CipherSuiteName(cipherSuite: Int64): String {
    if (cipherSuite == TLS13_CIPHER_SUITE_AES_128_GCM_SHA256) {
        return "TLS_AES_128_GCM_SHA256"
    }
    if (cipherSuite == TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256) {
        return "TLS_CHACHA20_POLY1305_SHA256"
    }
    "TLS_UNKNOWN_${cipherSuite}"
}

private func contractToHashAlgorithm(hash: ContractKdfHash): HashAlgorithm {
    match (hash) {
        case ContractKdfHash.Sha1 => HashAlgorithm.SHA1
        case ContractKdfHash.Sha256 => HashAlgorithm.SHA256
        case ContractKdfHash.Sha384 => HashAlgorithm.SHA384
        case ContractKdfHash.Sha512 => HashAlgorithm.SHA512
    }
}

private func contractFromTls13PskX25519DerivedSecrets(
    binding: ContractTls13CipherBinding,
    tlsSecrets: Tls13HandshakeSecrets
): ContractTls13PskX25519DerivedSecrets {
    ContractTls13PskX25519DerivedSecrets(
        binding,
        ContractTls13ApplicationKeyMaterial(
            tlsSecrets.clientWriteKey,
            tlsSecrets.clientWriteIv,
            tlsSecrets.serverWriteKey,
            tlsSecrets.serverWriteIv
        ),
        tlsSecrets.clientAppTrafficSecret,
        tlsSecrets.serverAppTrafficSecret,
        tlsSecrets.masterSecret
    )
}

private func contractTls13BuildKeyUpdatePlan(
    currentTrafficSecret: Array<Byte>,
    encodedKeyUpdate: Array<Byte>,
    keyLen: Int64,
    ivLen: Int64
): ContractTls13KeyUpdatePlan {
    let requestPeerUpdate = contractTls13DecodeKeyUpdateHandshake(encodedKeyUpdate)
    let nextTrafficSecret = contractTls13DeriveNextApplicationTrafficSecret(currentTrafficSecret)
    let (nextWriteKey, nextWriteIv) = contractTls13DeriveApplicationTrafficKeyIv(
        nextTrafficSecret,
        keyLen: keyLen,
        ivLen: ivLen
    )
    ContractTls13KeyUpdatePlan(
        encodedKeyUpdate,
        requestPeerUpdate,
        nextTrafficSecret,
        nextWriteKey,
        nextWriteIv
    )
}

private func contractTls13BuildPskEarlyDataPlan(
    ticket: ContractTlsSessionTicket,
    encodedClientHello: Array<Byte>,
    selectedIdentityIndex: Int64,
    keyLen: Int64,
    ivLen: Int64
): ContractTls13PskEarlyDataPlan {
    let clientHelloHash = sha256(encodedClientHello)
    try {
        let earlyDataSecrets = tls13DeriveEarlyDataSecrets(
            ticket.secret,
            clientHelloHash,
            keyLen: keyLen,
            ivLen: ivLen
        )
        ContractTls13PskEarlyDataPlan(
            selectedIdentityIndex,
            ticket,
            encodedClientHello,
            clientHelloHash,
            earlyDataSecrets.clientEarlyTrafficSecret,
            earlyDataSecrets.clientEarlyWriteKey,
            earlyDataSecrets.clientEarlyWriteIv
        )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS1.3 PSK early data secret derivation failed: ${e.message}"
        )
    }
}

private func contractTls13BuildPskEarlyDataReplayKeyFromFields(
    identity: ContractTlsSessionIdentity,
    clientHelloHash: Array<Byte>
): String {
    if (clientHelloHash.size != 32) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "TLS1.3 PSK early data replay hash must be SHA-256 sized"
        )
    }
    let versionTag = identity.version.toString()
    let resumptionId = base64UrlEncode(identity.resumptionId)
    let hash = base64UrlEncode(clientHelloHash)
    "${versionTag}:${resumptionId}:${hash}"
}

private func contractTls13RebuildVerifiedSession(
    session: ContractTls13HttpClientVerifiedSession,
    serverWriteKey: Array<Byte>,
    serverWriteIv: Array<Byte>,
    clientAppTrafficSecret: Array<Byte>,
    serverAppTrafficSecret: Array<Byte>,
    clientWriteKey: Array<Byte>,
    clientWriteIv: Array<Byte>
): ContractTls13HttpClientVerifiedSession {
    let previous = session.result
    let keyMaterial = ContractTls13ApplicationKeyMaterial(
        clientWriteKey,
        clientWriteIv,
        serverWriteKey,
        serverWriteIv
    )
    let result = ContractTls13HttpClientResult(
        previous.selectedAlpn,
        previous.requestedServerName,
        previous.acknowledgedServerName,
        previous.chainLength,
        previous.leafSubjectCommonName,
        previous.trustAnchorCommonName,
        previous.leafDerSha256,
        previous.leafSpkiSha256,
        keyMaterial,
        cipherBinding: previous.cipherBinding
    )
    ContractTls13HttpClientVerifiedSession(
        result,
        clientAppTrafficSecret,
        serverAppTrafficSecret,
        session.masterSecret,
        session.transcriptHash
    )
}

private func contractTls13ValidatePskEarlyDataHttpBinding(
    identity: ContractTlsSessionIdentity,
    expectedServerName: String,
    expectedAlpnProtocol: String
): Unit {
    let normalizedServerName = expectedServerName.trimAscii().toAsciiLower()
    if (normalizedServerName.size > 0) {
        if (identity.serverName.size == 0 || identity.serverName != normalizedServerName) {
            throw ContractException(
                ContractErrorCode.VerifyFailed,
                "TLS1.3 PSK early data ticket server_name does not match expected endpoint"
            )
        }
    }

    let normalizedAlpn = expectedAlpnProtocol.trimAscii().toAsciiLower()
    if (normalizedAlpn.size > 0) {
        if (identity.alpnProtocol.size == 0 || identity.alpnProtocol != normalizedAlpn) {
            throw ContractException(
                ContractErrorCode.VerifyFailed,
                "TLS1.3 PSK early data ticket ALPN does not match expected endpoint"
            )
        }
    }
}

private func contractTls13RotatePskX25519ClientSecrets(
    secrets: ContractTls13PskX25519DerivedSecrets
): ContractTls13PskX25519DerivedSecrets {
    let nextClientAppTrafficSecret = contractTls13DeriveNextApplicationTrafficSecret(
        secrets.clientAppTrafficSecret
    )
    let (nextClientWriteKey, nextClientWriteIv) = contractTls13DeriveApplicationTrafficKeyIv(
        nextClientAppTrafficSecret,
        keyLen: secrets.cipherBinding.keyLen,
        ivLen: secrets.cipherBinding.ivLen
    )
    contractTls13BuildPskX25519DerivedSecrets(
        secrets,
        nextClientAppTrafficSecret,
        secrets.serverAppTrafficSecret,
        nextClientWriteKey,
        nextClientWriteIv,
        secrets.keyMaterial.serverWriteKey,
        secrets.keyMaterial.serverWriteIv
    )
}

private func contractTls13RotatePskX25519ServerSecrets(
    secrets: ContractTls13PskX25519DerivedSecrets
): ContractTls13PskX25519DerivedSecrets {
    let nextServerAppTrafficSecret = contractTls13DeriveNextApplicationTrafficSecret(
        secrets.serverAppTrafficSecret
    )
    let (nextServerWriteKey, nextServerWriteIv) = contractTls13DeriveApplicationTrafficKeyIv(
        nextServerAppTrafficSecret,
        keyLen: secrets.cipherBinding.keyLen,
        ivLen: secrets.cipherBinding.ivLen
    )
    contractTls13BuildPskX25519DerivedSecrets(
        secrets,
        secrets.clientAppTrafficSecret,
        nextServerAppTrafficSecret,
        secrets.keyMaterial.clientWriteKey,
        secrets.keyMaterial.clientWriteIv,
        nextServerWriteKey,
        nextServerWriteIv
    )
}

private func contractTls13BuildPskX25519DerivedSecrets(
    current: ContractTls13PskX25519DerivedSecrets,
    clientAppTrafficSecret: Array<Byte>,
    serverAppTrafficSecret: Array<Byte>,
    clientWriteKey: Array<Byte>,
    clientWriteIv: Array<Byte>,
    serverWriteKey: Array<Byte>,
    serverWriteIv: Array<Byte>
): ContractTls13PskX25519DerivedSecrets {
    ContractTls13PskX25519DerivedSecrets(
        current.cipherBinding,
        ContractTls13ApplicationKeyMaterial(
            clientWriteKey,
            clientWriteIv,
            serverWriteKey,
            serverWriteIv
        ),
        clientAppTrafficSecret,
        serverAppTrafficSecret,
        current.masterSecret
    )
}

private func contractFromTls13ServerHandshakeFlight(
    flight: Tls13ServerHandshakeFlight
): ContractTls13HttpServerFlight {
    ContractTls13HttpServerFlight(
        flight.serverHello,
        flight.encryptedExtensions,
        flight.authFlight.certificateHandshake,
        flight.authFlight.certificateVerifyHandshake,
        flight.authFlight.finishedHandshake,
        flight.transcriptHash,
        selectedAlpn: flight.selectedAlpn,
        requestedServerName: flight.requestedServerName,
        acknowledgedServerName: flight.acknowledgedServerName
    )
}

private func contractToTls13ServerHandshakeFlight(
    flight: ContractTls13HttpServerFlight
): Tls13ServerHandshakeFlight {
    let authFlight = Tls13AuthFlight(
        Tls13AuthFlightRole.SERVER,
        flight.certificateHandshake,
        flight.certificateVerifyHandshake,
        flight.finishedHandshake
    )
    Tls13ServerHandshakeFlight(
        flight.serverHello,
        flight.encryptedExtensions,
        authFlight,
        flight.transcriptHash,
        selectedAlpn: flight.selectedAlpn,
        requestedServerName: flight.requestedServerName,
        acknowledgedServerName: flight.acknowledgedServerName
    )
}

private func contractEncryptAead(
    algorithm: ContractAeadAlgorithm,
    key: Array<Byte>,
    nonce: Array<Byte>,
    plaintext: Array<Byte>,
    aad: Array<Byte>
): (Array<Byte>, Array<Byte>) {
    try {
        match (algorithm) {
            case ContractAeadAlgorithm.Aes256Gcm =>
                aesGcmEncryptWithContext(contractResolveAesGcmContext(key), nonce, plaintext, aad: aad, tagLen: 16)
            case ContractAeadAlgorithm.Chacha20Poly1305 =>
                chacha20Poly1305Encrypt(key, nonce, plaintext, aad: aad)
        }
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "encrypt"),
            "AEAD encryption failed: ${e.message}"
        )
    }
}

private func contractResolveAesGcmContext(key: Array<Byte>): AesGcmContext {
    var index = 0
    while (index < _contractAesGcmContextCache.size) {
        let entry = _contractAesGcmContextCache[index]
        if (constantTimeEquals(entry.key, key)) {
            return entry.context
        }
        index += 1
    }

    let context = aesNewGcmContext(key)
    let keyCopy = key.clone()

    if (_contractAesGcmContextCache.size >= CONTRACT_AES_GCM_CONTEXT_CACHE_MAX) {
        _contractAesGcmContextCache.remove(at: 0)
    }
    _contractAesGcmContextCache.add(ContractAesGcmContextCacheEntry(keyCopy, context))
    context
}

private func contractDecryptAead(
    algorithm: ContractAeadAlgorithm,
    key: Array<Byte>,
    nonce: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad: Array<Byte>
): Array<Byte> {
    try {
        match (algorithm) {
            case ContractAeadAlgorithm.Aes256Gcm =>
                aesGcmDecryptWithContext(contractResolveAesGcmContext(key), nonce, ciphertext, tag, aad: aad)
            case ContractAeadAlgorithm.Chacha20Poly1305 =>
                chacha20Poly1305Decrypt(key, nonce, ciphertext, tag, aad: aad)
        }
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "decrypt"),
            "AEAD decryption failed: ${e.message}"
        )
    }
}

private func contractRequirePinPolicy(
    pinPolicy: ContractX509PinPolicy,
    leafDerSha: Array<Byte>,
    leafSpkiSha: Array<Byte>
): Unit {
    if (pinPolicy.allowedLeafDerSha256.size > 0) {
        var found = false
        for (pin in pinPolicy.allowedLeafDerSha256) {
            if (constantTimeEquals(pin, leafDerSha)) {
                found = true
                break
            }
        }
        if (!found) {
            throw ContractException(ContractErrorCode.VerifyFailed, "leaf certificate DER pin mismatch")
        }
    }

    if (pinPolicy.allowedLeafSpkiSha256.size > 0) {
        var found = false
        for (pin in pinPolicy.allowedLeafSpkiSha256) {
            if (constantTimeEquals(pin, leafSpkiSha)) {
                found = true
                break
            }
        }
        if (!found) {
            throw ContractException(ContractErrorCode.VerifyFailed, "leaf certificate SPKI pin mismatch")
        }
    }
}

private func contractVerifyServerCertificateParsed(
    leaf: X509Certificate,
    trustAnchorsPemBundle: String,
    intermediates: Array<X509Certificate>,
    hostname: String,
    validationTime: String,
    pinPolicy: ContractX509PinPolicy
): ContractX509VerifyResult {
    let anchors = x509ParsePemChain(trustAnchorsPemBundle)
    let policy = X509VerificationPolicy(
        anchors,
        intermediates: intermediates,
        requiredLeafDnsName: hostname,
        validationTime: validationTime
    )
    let verified = x509VerifyCertificateChain(leaf, policy)
    let leafDerSha = sha256(leaf.der)
    let leafSpkiSha = sha256(leaf.subjectPublicKeyInfoDer)
    contractRequirePinPolicy(pinPolicy, leafDerSha, leafSpkiSha)

    ContractX509VerifyResult(
        verified.chain.size,
        leaf.subject.commonName(),
        leaf.issuer.commonName(),
        verified.trustAnchor.subject.commonName(),
        leafDerSha,
        leafSpkiSha
    )
}

private func contractNormalizeAlpnProtocols(alpnProtocols: Array<String>): Array<String> {
    let normalized = ArrayList<String>()
    for (protocol in alpnProtocols) {
        let value = protocol.trimAscii().toAsciiLower()
        if (value.size == 0) {
            continue
        }
        var exists = false
        for (item in normalized) {
            if (item == value) {
                exists = true
                break
            }
        }
        if (!exists) {
            normalized.add(value)
        }
    }
    if (normalized.size == 0) {
        throw ContractException(ContractErrorCode.BadInput, "TLS ALPN protocol list must not be empty")
    }
    normalized.toArray()
}

private func contractContainsString(values: Array<String>, expected: String): Bool {
    for (value in values) {
        if (value == expected) {
            return true
        }
    }
    false
}

private func contractValidateLeafCertificateAndPrivateKeyMatch(
    leaf: X509Certificate,
    privateKeyPem: String
): String {
    match (contractTryParseRsaPrivateKeyPem(privateKeyPem)) {
        case Some(rsaPrivateKey) =>
            let leafPublicKey = try {
                x509ExtractRsaPublicKey(leaf)
            } catch (_: CryptoException) {
                throw ContractException(
                    ContractErrorCode.VerifyFailed,
                    "TLS certificate public key is not RSA but private key is RSA"
                )
            }
            if (
                leafPublicKey.modulus.cmp(rsaPrivateKey.publicKey.modulus) != 0 ||
                leafPublicKey.exponent.cmp(rsaPrivateKey.publicKey.exponent) != 0
            ) {
                throw ContractException(
                    ContractErrorCode.VerifyFailed,
                    "TLS certificate public key does not match RSA private key"
                )
            }
            return "RSA"
        case None =>
            ()
    }

    match (contractTryParseEcPrivateKeyPem(privateKeyPem)) {
        case Some(ecPrivateKey) =>
            let leafPublicKey = try {
                x509ExtractEcPublicKey(leaf)
            } catch (_: CryptoException) {
                throw ContractException(
                    ContractErrorCode.VerifyFailed,
                    "TLS certificate public key is not EC but private key is EC"
                )
            }
            let derivedPublicKey = ecPublicFromPrivateKey(ecPrivateKey)
            if (
                leafPublicKey.curve != derivedPublicKey.curve ||
                leafPublicKey.x.cmp(derivedPublicKey.x) != 0 ||
                leafPublicKey.y.cmp(derivedPublicKey.y) != 0
            ) {
                throw ContractException(
                    ContractErrorCode.VerifyFailed,
                    "TLS certificate public key does not match EC private key"
                )
            }
            return "EC"
        case None =>
            ()
    }

    throw ContractException(
        ContractErrorCode.BadInput,
        "unsupported TLS private key PEM format (expected RSA PKCS#1/PKCS#8 or EC PKCS#8)"
    )
}

private func contractTryParseRsaPrivateKeyPem(privateKeyPem: String): ?RsaPrivateKey {
    try {
        return Some(x509ParseRsaPrivateKeyPkcs8Pem(privateKeyPem))
    } catch (_: CryptoException) {
        ()
    }
    try {
        return Some(x509ParseRsaPrivateKeyPkcs1Pem(privateKeyPem))
    } catch (_: CryptoException) {
        ()
    }
    None
}

private func contractTryParseEcPrivateKeyPem(privateKeyPem: String): ?EcPrivateKey {
    try {
        Some(x509ParseEcPrivateKeyPkcs8Pem(privateKeyPem))
    } catch (_: CryptoException) {
        None
    }
}

private func contractCertificatesToPemBlocks(certificates: Array<X509Certificate>): Array<String> {
    let blocks = ArrayList<String>()
    for (certificate in certificates) {
        blocks.add(certificate.toPem())
    }
    blocks.toArray()
}

private func contractCloneTrimmedPemBlocks(pemBlocks: Array<String>, fieldName: String): Array<String> {
    let normalized = ArrayList<String>()
    for (pemBlock in pemBlocks) {
        let trimmed = pemBlock.trimAscii()
        if (trimmed.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "${fieldName} block must not be empty")
        }
        normalized.add(trimmed)
    }
    normalized.toArray()
}

private func contractJoinPemBlocks(pemBlocks: Array<String>): String {
    if (pemBlocks.size == 0) {
        return ""
    }
    var out = ""
    var first = true
    for (pemBlock in pemBlocks) {
        let trimmed = pemBlock.trimAscii()
        if (trimmed.size == 0) {
            continue
        }
        if (!first) {
            out += "\n"
        }
        out += trimmed
        first = false
    }
    out
}

private func decodeEnvelopeField(text: String, fieldName: String): Array<Byte> {
    try {
        base64UrlDecode(text)
    } catch (e: ContractException) {
        throw ContractException(ContractErrorCode.BadInput, "invalid envelope ${fieldName}: ${e.message}")
    }
}

private func contractNormalizeAlgorithmToken(raw: String): String {
    let normalized = raw.trimAscii().toAsciiUpper()
    _ = contractParseAlgorithmToken(normalized)
    normalized
}

private func contractCloneOptionalBytes(bytes: ?Array<Byte>): ?Array<Byte> {
    match (bytes) {
        case Some(value) => Some(value.clone())
        case None => None
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractTlsHttpNegotiationPolicyValidationResult,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractHttpClientTlsConfigValidationResult,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractHttpServerTlsMaterial,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractHttpClientTlsTrustMaterial,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractHttpServerTlsConfigValidationResult,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractSshHostVerificationResult,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractSshHostSigningResult,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractSshServerInitialHandshakeResult,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractSshClientInitialHandshakeResult,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractTls13HttpClientResult,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractTls13PskClientHelloFromCacheResult,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractTls13HttpClientVerifiedSession,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractHttpServerLibraryStartupBundle,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractHttpClientLibraryStartupBundle,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractSshServerLibraryStartupBundle,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractSshServerRuntimeBundle,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractSshClientRuntimeBundle,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractValidateOutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractSshClientLibraryStartupBundle,
    resultLabel: String
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "${resultLabel} must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractParseAlgorithmToken(raw: String): ContractAeadAlgorithm {
    let normalized = raw.trimAscii().toAsciiUpper()
    if (normalized == "AES-256-GCM") {
        return ContractAeadAlgorithm.Aes256Gcm
    }
    if (normalized == "CHACHA20-POLY1305") {
        return ContractAeadAlgorithm.Chacha20Poly1305
    }
    throw ContractException(ContractErrorCode.Unsupported, "unsupported AEAD algorithm: ${raw}")
}

private func requireTokenAscii(value: String, fieldName: String, allowEmpty!: Bool = false): Unit {
    if (!allowEmpty && value.size == 0) {
        throw ContractException(ContractErrorCode.BadInput, "${fieldName} must not be empty")
    }
    for (ch in value.toArray()) {
        if (
            (ch >= b'a' && ch <= b'z') ||
            (ch >= b'A' && ch <= b'Z') ||
            (ch >= b'0' && ch <= b'9') ||
            ch == b'-' ||
            ch == b'_' ||
            ch == b'.'
        ) {
            continue
        }
        throw ContractException(ContractErrorCode.BadInput, "${fieldName} contains invalid token character")
    }
}

private func mapCryptoErrorForOperation(e: CryptoException, operation: String): ContractErrorCode {
    if (operation == "random" && e.code == CryptoErrorCode.Unsupported) {
        return ContractErrorCode.CryptoUnavailable
    }
    if (operation == "decrypt") {
        if (e.code == InvalidArgument || e.code == ParseError) {
            return ContractErrorCode.VerifyFailed
        }
    }
    if (operation == "x509" && e.code == ParseError) {
        return ContractErrorCode.VerifyFailed
    }
    if (operation == "tls") {
        if (e.code == ParseError) {
            return ContractErrorCode.VerifyFailed
        }
        if (e.code == CryptoErrorCode.Unsupported) {
            return ContractErrorCode.Unsupported
        }
    }
    if (operation == "ssh") {
        if (e.code == ParseError) {
            return ContractErrorCode.VerifyFailed
        }
        if (e.code == CryptoErrorCode.Unsupported) {
            return ContractErrorCode.Unsupported
        }
    }
    contractMapCryptoErrorCode(e.code)
}

private func contractMapProviderErrorFamily(
    code: ContractErrorCode,
    phase: ContractProviderErrorPhase
): ContractProviderErrorFamily {
    match (code) {
        case ContractErrorCode.BadInput => ContractProviderErrorFamily.BadInput
        case ContractErrorCode.KeyNotFound => ContractProviderErrorFamily.KeyNotFound
        case ContractErrorCode.CryptoUnavailable =>
            if (
                phase == ContractProviderErrorPhase.ProviderSelection ||
                phase == ContractProviderErrorPhase.ProviderRuntime
            ) {
                ContractProviderErrorFamily.ProviderUnavailable
            } else {
                ContractProviderErrorFamily.CryptoUnavailable
            }
        case ContractErrorCode.ComplianceRejected => ContractProviderErrorFamily.ComplianceRejected
        case ContractErrorCode.Unsupported => ContractProviderErrorFamily.Unsupported
        case ContractErrorCode.InternalError => ContractProviderErrorFamily.InternalError
        case ContractErrorCode.VerifyFailed =>
            match (phase) {
                case ContractProviderErrorPhase.TlsPrecheck => ContractProviderErrorFamily.TlsPrecheckError
                case ContractProviderErrorPhase.TlsHandshake => ContractProviderErrorFamily.TlsHandshakeError
                case ContractProviderErrorPhase.TlsVerify => ContractProviderErrorFamily.TlsVerifyError
                case _ => ContractProviderErrorFamily.VerifyFailed
            }
    }
}

private func contractProviderErrorIsRetryable(family: ContractProviderErrorFamily): Bool {
    match (family) {
        case ContractProviderErrorFamily.TlsHandshakeError => true
        case _ => false
    }
}

private func contractProviderErrorSuggestsFallback(family: ContractProviderErrorFamily): Bool {
    match (family) {
        case ContractProviderErrorFamily.CryptoUnavailable => true
        case ContractProviderErrorFamily.Unsupported => true
        case ContractProviderErrorFamily.InternalError => true
        case ContractProviderErrorFamily.TlsHandshakeError => true
        case ContractProviderErrorFamily.ProviderUnavailable => true
        case _ => false
    }
}

private func contractProviderFallbackReason(error: ContractProviderErrorDescriptor): String {
    if (!error.fallbackSuggested) {
        return "surface ${error.family.toString()} to the caller and do not auto-fallback"
    }
    match (error.family) {
        case ContractProviderErrorFamily.ProviderUnavailable =>
            "provider is unavailable in the current runtime; prefer stdx fallback via lisi"
        case ContractProviderErrorFamily.Unsupported =>
            "requested capability is unsupported in jinguissl; prefer stdx fallback via lisi"
        case ContractProviderErrorFamily.CryptoUnavailable =>
            "crypto backend is unavailable; prefer stdx fallback via lisi"
        case ContractProviderErrorFamily.InternalError =>
            "provider hit an internal error; quarantine this provider and prefer stdx fallback"
        case ContractProviderErrorFamily.TlsHandshakeError =>
            "TLS handshake failed inside provider flow; retry cautiously or fall back to stdx"
        case _ =>
            "fallback is suggested by provider policy"
    }
}

private func contractProviderSmokeExecutionModeForFixture(
    fixture: ContractProviderSmokeFixtureInfo
): ContractProviderSmokeExecutionMode {
    match (fixture.category) {
        case ContractProviderSmokeFixtureCategory.PrecheckFail =>
            ContractProviderSmokeExecutionMode.PrecheckPath
        case ContractProviderSmokeFixtureCategory.VerifyFail =>
            ContractProviderSmokeExecutionMode.VerifyPath
        case ContractProviderSmokeFixtureCategory.Success =>
            ContractProviderSmokeExecutionMode.VerifyPath
        case ContractProviderSmokeFixtureCategory.ProviderUnavailable =>
            ContractProviderSmokeExecutionMode.ProviderSelectionPath
        case ContractProviderSmokeFixtureCategory.HandshakeFail =>
            ContractProviderSmokeExecutionMode.MetadataOnly
    }
}

private func contractProviderSmokeExpectedCode(
    fixture: ContractProviderSmokeFixtureInfo
): ContractErrorCode {
    match (fixture.expectedCode) {
        case Some(value) => value
        case None =>
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke fixture ${fixture.fixtureId} does not define an expected code"
            )
    }
}

private func contractProviderSmokeExpectedPhase(
    fixture: ContractProviderSmokeFixtureInfo
): ContractProviderErrorPhase {
    match (fixture.expectedPhase) {
        case Some(value) => value
        case None =>
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke fixture ${fixture.fixtureId} does not define an expected phase"
            )
    }
}

private func contractProviderSmokeWarnings(
    fixture: ContractProviderSmokeFixtureInfo,
    executionMode: ContractProviderSmokeExecutionMode,
    capability: ContractProviderCapabilityRecord,
    attachBoundary: ContractProviderServerAttachBoundary
): Array<String> {
    let warnings = ArrayList<String>()
    if (!capability.defaultEligible) {
        warnings.add("provider is not default HTTPS eligible in the current public release line")
    }
    if (!attachBoundary.stableAttach) {
        warnings.add("stable server attach is unavailable; keep smoke exercises within precheck, verify, or provider-selection boundaries")
    }
    match (executionMode) {
        case ContractProviderSmokeExecutionMode.MetadataOnly =>
            warnings.add("this smoke baseline is modeled through provider error normalization metadata rather than a live network handshake")
        case ContractProviderSmokeExecutionMode.ProviderSelectionPath =>
            warnings.add("provider-unavailable is an expected selection-path baseline and should not be counted as a functional regression by itself")
        case ContractProviderSmokeExecutionMode.VerifyPath =>
            if (!capability.supportsX509Verify) {
                warnings.add("provider does not currently advertise X.509 verify support for verify-path smoke")
            }
        case ContractProviderSmokeExecutionMode.PrecheckPath =>
            let attach = contractProviderAttachContractInfo()
            if (!attach.supportsTlsPrecheck) {
                warnings.add("provider does not currently advertise TLS precheck support for precheck-path smoke")
            }
    }
    if (fixture.entrypoints.size == 1 && fixture.entrypoints[0].contains("contractDescribeProvider")) {
        warnings.add("this baseline is descriptor-driven and should be exercised through contract-level error normalization helpers")
    }
    warnings.toArray()
}

private func contractProviderSmokeSelfCheckRequirement(
    warnings: ArrayList<String>,
    policy: ContractProviderSmokeSelfCheckPolicy,
    capability: ContractProviderCapabilityRecord,
    attach: ContractProviderAttachContractInfo,
    suite: ContractProviderSmokeSuiteReport,
    hasSuccessBaseline: Bool,
    hasPrecheckCoverage: Bool,
    hasVerifyCoverage: Bool,
    hasProviderSelectionCoverage: Bool,
    hasHandshakeCoverage: Bool,
    hasLiveHandshakeCoverage: Bool,
    hasFallbackPlanCoverage: Bool
): Bool {
    var overallReady = true
    if (capability.experimental) {
        contractAppendUniqueString(
            warnings,
            "provider remains experimental in the current public release line"
        )
    }
    if (policy.requireClientTls && (!capability.supportsClientTls || !attach.supportsClientTls)) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires client TLS facade support, but the published capability/attach contract is incomplete"
        )
        overallReady = false
    }
    if (policy.requireX509Verify && (!capability.supportsX509Verify || !attach.supportsX509Verify)) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires X.509 verify support, but the published capability/attach contract is incomplete"
        )
        overallReady = false
    }
    if (policy.requireTlsPrecheck && !attach.supportsTlsPrecheck) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires TLS precheck support, but the public attach contract does not advertise it"
        )
        overallReady = false
    }
    if (policy.requireSuccessBaseline && !hasSuccessBaseline) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires at least one success baseline fixture"
        )
        overallReady = false
    }
    if (policy.requirePrecheckCoverage && !hasPrecheckCoverage) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires at least one precheck-path smoke baseline"
        )
        overallReady = false
    }
    if (policy.requireVerifyCoverage && !hasVerifyCoverage) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires at least one verify-path smoke baseline"
        )
        overallReady = false
    }
    if (policy.requireProviderSelectionCoverage && !hasProviderSelectionCoverage) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires at least one provider-selection-path smoke baseline"
        )
        overallReady = false
    }
    if (policy.requireHandshakeCoverage && !hasHandshakeCoverage) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires at least one handshake coverage baseline"
        )
        overallReady = false
    }
    if (hasHandshakeCoverage && !hasLiveHandshakeCoverage) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check handshake coverage is currently metadata-only; a stable live attach path is not published yet"
        )
    }
    if (policy.requireLiveHandshakeCoverage && !hasLiveHandshakeCoverage) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires live handshake coverage, but the current suite only exposes metadata-only handshake baselines"
        )
        overallReady = false
    }
    if (policy.requireFallbackPlan && !hasFallbackPlanCoverage) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires fallback decisions for every non-success smoke baseline"
        )
        overallReady = false
    }
    if (
        policy.requireStableServerAttach &&
        (!capability.supportsServerTlsAttach || !attach.supportsServerTlsAttach || !suite.attachBoundary.stableAttach)
    ) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires stable server attach coverage, but the public boundary remains precheck-only"
        )
        overallReady = false
    }
    if (policy.requireDefaultEligible && !capability.defaultEligible) {
        contractAppendUniqueString(
            warnings,
            "provider smoke self-check requires default HTTPS eligibility, but the current release line keeps jinguissl provider-candidate only"
        )
        overallReady = false
    }
    overallReady
}

private func contractProviderSmokeSelfCheckFailureDetail(
    report: ContractProviderSmokeSelfCheckReport
): String {
    for (warning in report.warnings) {
        if (warning.contains("stable server attach")) {
            return warning
        }
    }
    for (warning in report.warnings) {
        if (warning.contains("default HTTPS eligibility")) {
            return warning
        }
    }
    for (warning in report.warnings) {
        if (warning.contains("live handshake coverage")) {
            return warning
        }
    }
    for (warning in report.warnings) {
        if (warning.contains("provider smoke self-check requires")) {
            return warning
        }
    }
    if (report.warnings.size > 0) {
        return report.warnings[0]
    }
    "provider smoke self-check policy requirements are not satisfied"
}

private func contractProviderSmokeSuiteFixtureIds(
    request: ContractProviderSmokeSuiteRequest
): Array<String> {
    if (request.fixtureIds.size == 0) {
        let fixtureIds = ArrayList<String>()
        for (fixture in contractProviderSmokeFixtureCatalog()) {
            fixtureIds.add(fixture.fixtureId)
        }
        return fixtureIds.toArray()
    }
    request.fixtureIds.clone()
}

private func contractAppendUniqueString(
    values: ArrayList<String>,
    value: String
): Unit {
    for (existing in values) {
        if (existing == value) {
            return
        }
    }
    values.add(value)
}

private func clonePinList(pins: Array<Array<Byte>>, label: String): Array<Array<Byte>> {
    let out = ArrayList<Array<Byte>>()
    for (pin in pins) {
        requireSha256Pin(pin, "${label} pin")
        out.add(pin.clone())
    }
    out.toArray()
}

private func contractCloneRecordWire(records: Array<Array<Byte>>, label: String): Array<Array<Byte>> {
    let out = ArrayList<Array<Byte>>()
    for (record in records) {
        if (record.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "${label} must not be empty")
        }
        out.add(record.clone())
    }
    out.toArray()
}

private func contractCountRecordWireBytes(records: Array<Array<Byte>>): Int64 {
    var total: Int64 = 0
    for (record in records) {
        total += record.size
    }
    total
}

private func requireSha256Pin(pin: Array<Byte>, fieldName: String): Unit {
    if (pin.size != 32) {
        throw ContractException(ContractErrorCode.BadInput, "${fieldName} must be 32 bytes (SHA-256)")
    }
}

private func removeAsciiSpaces(text: String): String {
    var out = ""
    for (ch in text.toRuneArray()) {
        if (ch == r' ' || ch == r'\n' || ch == r'\r' || ch == r'\t') {
            continue
        }
        out += ch.toString()
    }
    out
}

private func extractStringField(json: String, key: String): String {
    let pattern = "\"${key}\":\""
    let start = indexOfString(json, pattern)
    if (start < 0) {
        throw ContractException(ContractErrorCode.BadInput, "missing envelope field: ${key}")
    }
    let valueStart = start + pattern.size
    let valueEnd = indexOfRuneFrom(json, r'\"', valueStart)
    if (valueEnd < 0) {
        throw ContractException(ContractErrorCode.BadInput, "invalid envelope string field: ${key}")
    }
    substringRange(json, valueStart, valueEnd)
}

private func extractOptionalStringField(json: String, key: String, defaultValue: String): String {
    let pattern = "\"${key}\":\""
    let start = indexOfString(json, pattern)
    if (start < 0) {
        return defaultValue
    }
    let valueStart = start + pattern.size
    let valueEnd = indexOfRuneFrom(json, r'\"', valueStart)
    if (valueEnd < 0) {
        throw ContractException(ContractErrorCode.BadInput, "invalid envelope string field: ${key}")
    }
    substringRange(json, valueStart, valueEnd)
}

private func extractIntField(json: String, key: String): Int64 {
    let pattern = "\"${key}\":"
    let start = indexOfString(json, pattern)
    if (start < 0) {
        throw ContractException(ContractErrorCode.BadInput, "missing envelope field: ${key}")
    }
    let runes = json.toRuneArray()
    var i = start + pattern.size
    var digits = ""
    while (i < runes.size) {
        let ch = runes[i]
        if (ch >= r'0' && ch <= r'9') {
            digits += ch.toString()
            i += 1
            continue
        }
        break
    }
    if (digits.size == 0) {
        throw ContractException(ContractErrorCode.BadInput, "invalid envelope integer field: ${key}")
    }
    parseInt64Ascii(digits)
}

private func parseInt64Ascii(text: String): Int64 {
    var out: Int64 = 0
    for (ch in text.toRuneArray()) {
        out = (out * 10) + digitOfRune(ch)
    }
    out
}

private func digitOfRune(ch: Rune): Int64 {
    match (ch) {
        case r'0' => 0
        case r'1' => 1
        case r'2' => 2
        case r'3' => 3
        case r'4' => 4
        case r'5' => 5
        case r'6' => 6
        case r'7' => 7
        case r'8' => 8
        case r'9' => 9
        case _ => throw ContractException(ContractErrorCode.BadInput, "invalid numeric field")
    }
}

private func indexOfString(text: String, needle: String): Int64 {
    let hay = text.toRuneArray()
    let target = needle.toRuneArray()
    if (target.size == 0) {
        return 0
    }
    if (hay.size < target.size) {
        return -1
    }

    var i = 0
    while (i <= hay.size - target.size) {
        var matched = true
        var j = 0
        while (j < target.size) {
            if (hay[i + j] != target[j]) {
                matched = false
                break
            }
            j += 1
        }
        if (matched) {
            return i
        }
        i += 1
    }
    -1
}

private func indexOfRuneFrom(text: String, target: Rune, start: Int64): Int64 {
    let chars = text.toRuneArray()
    var i = start
    while (i < chars.size) {
        if (chars[i] == target) {
            return i
        }
        i += 1
    }
    -1
}

private func substringRange(text: String, start: Int64, endExclusive: Int64): String {
    let chars = text.toRuneArray()
    if (start < 0 || endExclusive < start || endExclusive > chars.size) {
        throw ContractException(ContractErrorCode.BadInput, "invalid envelope string range")
    }
    var out = ""
    var i = start
    while (i < endExclusive) {
        out += chars[i].toString()
        i += 1
    }
    out
}

private func base64UrlEncode(input: Array<Byte>): String {
    let data = toUInt8Array(input)
    if (data.size == 0) {
        return ""
    }

    let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".toRuneArray()
    var out = ""
    var i = 0
    while (i < data.size) {
        let b0 = Int64(data[i])
        let b1 = if (i + 1 < data.size) { Int64(data[i + 1]) } else { -1 }
        let b2 = if (i + 2 < data.size) { Int64(data[i + 2]) } else { -1 }

        let x0 = b0 >> 2
        let x1 = ((b0 & 0x03) << 4) | (if (b1 >= 0) { (b1 >> 4) & 0x0f } else { 0 })
        out += table[x0].toString()
        out += table[x1].toString()

        if (b1 >= 0) {
            let x2 = ((b1 & 0x0f) << 2) | (if (b2 >= 0) { (b2 >> 6) & 0x03 } else { 0 })
            out += table[x2].toString()
        }
        if (b2 >= 0) {
            let x3 = b2 & 0x3f
            out += table[x3].toString()
        }
        i += 3
    }
    out
}

private func base64UrlDecode(input: String): Array<Byte> {
    let text = input.trimAscii()
    if (text.size == 0) {
        return []
    }

    let out = ArrayList<UInt8>()
    var buffer: Int64 = 0
    var bits: Int64 = 0
    for (ch in text.toRuneArray()) {
        let value = base64UrlIndex(ch)
        if (value < 0) {
            throw ContractException(ContractErrorCode.BadInput, "invalid base64url character")
        }
        buffer = (buffer << 6) | value
        bits += 6
        if (bits >= 8) {
            bits -= 8
            out.add(UInt8((buffer >> bits) & 0xFF))
        }
    }
    toByteArray(out.toArray())
}

private func base64UrlIndex(ch: Rune): Int64 {
    let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".toRuneArray()
    var i = 0
    while (i < table.size) {
        if (table[i] == ch) {
            return i
        }
        i += 1
    }
    -1
}

private func isZeroBytes(bytes: Array<Byte>): Bool {
    for (value in bytes) {
        if (UInt8(value) != UInt8(0)) {
            return false
        }
    }
    true
}

private func toUInt8Array(bytes: Array<Byte>): Array<UInt8> {
    let out = Array<UInt8>(bytes.size, repeat: 0)
    var i = 0
    while (i < bytes.size) {
        out[i] = UInt8(bytes[i])
        i += 1
    }
    out
}

private func toByteArray(bytes: Array<UInt8>): Array<Byte> {
    let out = Array<Byte>(bytes.size, repeat: 0)
    var i = 0
    while (i < bytes.size) {
        out[i] = UInt8(bytes[i])
        i += 1
    }
    out
}
