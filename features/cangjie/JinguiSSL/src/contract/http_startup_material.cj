package jinguissl.contract

import std.collection.ArrayList
import jinguissl_core.crypto.digest.sha256
import jinguissl_core.crypto.ecc.{EcPrivateKey, ecPublicFromPrivateKey}
import jinguissl_core.crypto.error.{CryptoErrorCode, CryptoException}
import jinguissl_core.crypto.rsa.RsaPrivateKey
import jinguissl_core.crypto.tls.TlsHttpNegotiationPolicy
import jinguissl_core.crypto.utils.constantTimeEquals
import jinguissl_core.crypto.x509.{
    X509Certificate,
    X509VerificationPolicy,
    x509ExtractEcPublicKey,
    x509ExtractRsaPublicKey,
    x509ParseEcPrivateKeyPkcs8Pem,
    x509ParsePem,
    x509ParsePemChain,
    x509ParseRsaPrivateKeyPkcs1Pem,
    x509ParseRsaPrivateKeyPkcs8Pem,
    x509VerifyCertificateChain
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
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "x509 verify outcome result must exist when ok is true"
                    )
            }
        } else {
            match (igniteCode) {
                case Some(_) => ()
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
        contractValidateHttpServerTlsConfigValidationOutcomeState(ok, code, igniteCode, result, "TLS config validation outcome result")
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
        contractValidateHttpServerTlsMaterialOutcomeState(ok, code, igniteCode, result, "TLS server material outcome result")
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
        contractValidateHttpClientTlsTrustMaterialOutcomeState(ok, code, igniteCode, result, "TLS client material outcome result")
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
        contractValidateHttpClientTlsConfigValidationOutcomeState(ok, code, igniteCode, result, "TLS client config validation outcome result")
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
        contractValidateHttpServerLibraryStartupOutcomeState(ok, code, igniteCode, result, "HTTP server startup outcome result")
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
        contractValidateHttpClientLibraryStartupOutcomeState(ok, code, igniteCode, result, "HTTP client startup outcome result")
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
        contractValidateTlsHttpNegotiationPolicyValidationOutcomeState(
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

private func contractValidateTlsHttpNegotiationPolicyValidationOutcomeState(
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

private func contractValidateHttpClientTlsConfigValidationOutcomeState(
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

private func contractValidateHttpServerTlsConfigValidationOutcomeState(
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

private func contractValidateHttpServerTlsMaterialOutcomeState(
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

private func contractValidateHttpClientTlsTrustMaterialOutcomeState(
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

private func contractValidateHttpServerLibraryStartupOutcomeState(
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

private func contractValidateHttpClientLibraryStartupOutcomeState(
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

private func contractToTlsHttpNegotiationPolicy(
    policy: ContractTlsHttpNegotiationPolicy
): TlsHttpNegotiationPolicy {
    TlsHttpNegotiationPolicy(
        requireServerName: policy.requireServerName,
        allowedServerNames: policy.allowedServerNames,
        alpnPreference: policy.alpnPreference
    )
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

private func clonePinList(pins: Array<Array<Byte>>, label: String): Array<Array<Byte>> {
    let out = ArrayList<Array<Byte>>()
    for (pin in pins) {
        requireSha256Pin(pin, "${label} pin")
        out.add(pin.clone())
    }
    out.toArray()
}

private func requireSha256Pin(pin: Array<Byte>, fieldName: String): Unit {
    if (pin.size != 32) {
        throw ContractException(ContractErrorCode.BadInput, "${fieldName} must be 32 bytes (SHA-256)")
    }
}

private func mapCryptoErrorForOperation(e: CryptoException, operation: String): ContractErrorCode {
    if (operation == "random" && e.code == CryptoErrorCode.Unsupported) {
        return ContractErrorCode.CryptoUnavailable
    }
    if (operation == "decrypt") {
        if (e.code == CryptoErrorCode.InvalidArgument || e.code == CryptoErrorCode.ParseError) {
            return ContractErrorCode.VerifyFailed
        }
    }
    if (operation == "x509" && e.code == CryptoErrorCode.ParseError) {
        return ContractErrorCode.VerifyFailed
    }
    if (operation == "tls") {
        if (e.code == CryptoErrorCode.ParseError) {
            return ContractErrorCode.VerifyFailed
        }
        if (e.code == CryptoErrorCode.Unsupported) {
            return ContractErrorCode.Unsupported
        }
    }
    contractMapCryptoErrorCode(e.code)
}

private func contractMapCryptoErrorCode(code: CryptoErrorCode): ContractErrorCode {
    match (code) {
        case CryptoErrorCode.InvalidArgument => ContractErrorCode.BadInput
        case CryptoErrorCode.OutOfBounds => ContractErrorCode.BadInput
        case CryptoErrorCode.ParseError => ContractErrorCode.VerifyFailed
        case CryptoErrorCode.ComplianceRejected => ContractErrorCode.ComplianceRejected
        case CryptoErrorCode.Unsupported => ContractErrorCode.Unsupported
        case CryptoErrorCode.InternalError => ContractErrorCode.InternalError
        case _ => ContractErrorCode.InternalError
    }
}
