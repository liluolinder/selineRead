package jinguissl.contract

import std.collection.ArrayList
import jinguissl.live as livecontract
import jinguissl_core.crypto.error.{CryptoErrorCode, CryptoException}
import jinguissl_core.crypto.x509.{x509ParseEcPrivateKeyPkcs8Pem, x509ParseRsaPrivateKeyPkcs8Pem}

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
        _ = contractToLiveSshKexExchangeTranscript(
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
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH expected host key fingerprint must be SHA-256 sized"
            )
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

// Transitional truth: startup facade is target-local, but handshake/runtime result
// objects still ride on the old live-source contract package in this packet.
public class ContractSshServerLibraryStartupBundle {
    public let template: ContractHttpSshStartupProfileTemplate
    public let readiness: ContractHttpSshStartupReadinessReport
    public let handshake: livecontract.ContractSshServerInitialHandshakeResult
    public let runtime: livecontract.ContractSshServerRuntime

    public init(
        template: ContractHttpSshStartupProfileTemplate,
        readiness: ContractHttpSshStartupReadinessReport,
        handshake: livecontract.ContractSshServerInitialHandshakeResult,
        runtime: livecontract.ContractSshServerRuntime
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
    public let handshake: livecontract.ContractSshClientInitialHandshakeResult
    public let runtime: livecontract.ContractSshClientRuntime

    public init(
        template: ContractHttpSshStartupProfileTemplate,
        readiness: ContractHttpSshStartupReadinessReport,
        handshake: livecontract.ContractSshClientInitialHandshakeResult,
        runtime: livecontract.ContractSshClientRuntime
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
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH server startup outcome message must not be empty"
            )
        }
        contractValidateSshServerLibraryStartupOutcomeState(
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
            throw ContractException(
                ContractErrorCode.BadInput,
                "SSH client startup outcome message must not be empty"
            )
        }
        contractValidateSshClientLibraryStartupOutcomeState(
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
        let handshake = livecontract.contractSshCompleteServerInitialHandshakeX25519RsaRequest(
            livecontract.ContractSshServerInitialHandshakeX25519RsaRequest(
                contractToLiveSshKexExchangeTranscript(request.transcript),
                request.serverPrivateKey,
                request.encodedClientInit,
                hostPrivateKey,
                contractToLiveSshNegotiatedAlgorithms(request.negotiated),
                request.encodedClientNewKeys,
                request.encodedServerNewKeys,
                signatureAlgorithm: request.signatureAlgorithm,
                serverPublicKey: request.serverPublicKey
            )
        )
        let runtime = livecontract.contractSshCreateServerRuntimeRequest(
            livecontract.ContractSshServerRuntimeRequest(handshake)
        )
        ContractSshServerLibraryStartupBundle(template, readiness, handshake, runtime)
    } catch (e: ContractException) {
        throw e
    } catch (e: livecontract.ContractException) {
        throw ContractException(contractMapLiveContractErrorCode(e.code), e.message)
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
        let handshake = livecontract.contractSshCompleteServerInitialHandshakeX25519EcdsaRequest(
            livecontract.ContractSshServerInitialHandshakeX25519EcdsaRequest(
                contractToLiveSshKexExchangeTranscript(request.transcript),
                request.serverPrivateKey,
                request.encodedClientInit,
                hostPrivateKey,
                contractToLiveSshNegotiatedAlgorithms(request.negotiated),
                request.encodedClientNewKeys,
                request.encodedServerNewKeys,
                serverPublicKey: request.serverPublicKey
            )
        )
        let runtime = livecontract.contractSshCreateServerRuntimeRequest(
            livecontract.ContractSshServerRuntimeRequest(handshake)
        )
        ContractSshServerLibraryStartupBundle(template, readiness, handshake, runtime)
    } catch (e: ContractException) {
        throw e
    } catch (e: livecontract.ContractException) {
        throw ContractException(contractMapLiveContractErrorCode(e.code), e.message)
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
        let handshake = livecontract.contractSshCompleteServerInitialHandshakeX25519Ed25519Request(
            livecontract.ContractSshServerInitialHandshakeX25519Ed25519Request(
                contractToLiveSshKexExchangeTranscript(request.transcript),
                request.serverPrivateKey,
                request.encodedClientInit,
                request.hostPrivateKeySeed,
                contractToLiveSshNegotiatedAlgorithms(request.negotiated),
                request.encodedClientNewKeys,
                request.encodedServerNewKeys,
                serverPublicKey: request.serverPublicKey
            )
        )
        let runtime = livecontract.contractSshCreateServerRuntimeRequest(
            livecontract.ContractSshServerRuntimeRequest(handshake)
        )
        ContractSshServerLibraryStartupBundle(template, readiness, handshake, runtime)
    } catch (e: ContractException) {
        throw e
    } catch (e: livecontract.ContractException) {
        throw ContractException(contractMapLiveContractErrorCode(e.code), e.message)
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
        let handshake = livecontract.contractSshCompleteClientInitialHandshakeX25519Request(
            contractToLiveSshClientInitialHandshakeX25519Request(request.handshake)
        )
        let runtime = livecontract.contractSshCreateClientRuntimeRequest(
            livecontract.ContractSshClientRuntimeRequest(handshake)
        )
        ContractSshClientLibraryStartupBundle(template, readiness, handshake, runtime)
    } catch (e: ContractException) {
        throw e
    } catch (e: livecontract.ContractException) {
        throw ContractException(contractMapLiveContractErrorCode(e.code), e.message)
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

private func contractToLiveSshNegotiatedAlgorithms(
    negotiated: ContractSshNegotiatedAlgorithms
): livecontract.ContractSshNegotiatedAlgorithms {
    livecontract.ContractSshNegotiatedAlgorithms(
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

private func contractToLiveSshKexExchangeTranscript(
    transcript: ContractSshKexExchangeTranscript
): livecontract.ContractSshKexExchangeTranscript {
    contractToLiveSshKexExchangeTranscript(
        transcript.clientBannerLine,
        transcript.serverBannerLine,
        transcript.clientKexInitPayload,
        transcript.serverKexInitPayload
    )
}

private func contractToLiveSshKexExchangeTranscript(
    clientBannerLine: Array<Byte>,
    serverBannerLine: Array<Byte>,
    clientKexInitPayload: Array<Byte>,
    serverKexInitPayload: Array<Byte>
): livecontract.ContractSshKexExchangeTranscript {
    try {
        livecontract.ContractSshKexExchangeTranscript(
            clientBannerLine,
            serverBannerLine,
            clientKexInitPayload,
            serverKexInitPayload
        )
    } catch (e: livecontract.ContractException) {
        throw ContractException(contractMapLiveContractErrorCode(e.code), e.message)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "ssh"),
            "SSH KEX transcript is invalid: ${e.message}"
        )
    }
}

private func contractToLiveSshHostVerificationPolicy(
    policy: ContractSshHostVerificationPolicy
): livecontract.ContractSshHostVerificationPolicy {
    livecontract.ContractSshHostVerificationPolicy(
        negotiatedHostKeyAlgorithm: policy.negotiatedHostKeyAlgorithm,
        expectedHostKeySha256: policy.expectedHostKeySha256,
        requireKnownHost: policy.requireKnownHost,
        requireHostSignature: policy.requireHostSignature,
        allowLegacyRsaSha1: policy.allowLegacyRsaSha1,
        requireVerifiedHost: policy.requireVerifiedHost
    )
}

private func contractToLiveSshClientInitialHandshakeX25519Request(
    request: ContractSshClientInitialHandshakeX25519Request
): livecontract.ContractSshClientInitialHandshakeX25519Request {
    try {
        livecontract.ContractSshClientInitialHandshakeX25519Request(
            contractToLiveSshKexExchangeTranscript(request.transcript),
            request.clientPrivateKey,
            request.encodedClientInit,
            request.encodedServerReply,
            contractToLiveSshNegotiatedAlgorithms(request.negotiated),
            request.encodedClientNewKeys,
            request.encodedServerNewKeys,
            policy: contractToLiveSshHostVerificationPolicy(request.policy)
        )
    } catch (e: livecontract.ContractException) {
        throw ContractException(contractMapLiveContractErrorCode(e.code), e.message)
    }
}

private func contractValidateSshServerLibraryStartupOutcomeState(
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

private func contractValidateSshClientLibraryStartupOutcomeState(
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

private func contractMapLiveContractErrorCode(
    code: livecontract.ContractErrorCode
): ContractErrorCode {
    match (code.toString()) {
        case "BAD_INPUT" => ContractErrorCode.BadInput
        case "KEY_NOT_FOUND" => ContractErrorCode.KeyNotFound
        case "VERIFY_FAILED" => ContractErrorCode.VerifyFailed
        case "CRYPTO_UNAVAILABLE" => ContractErrorCode.CryptoUnavailable
        case "COMPLIANCE_REJECTED" => ContractErrorCode.ComplianceRejected
        case "UNSUPPORTED" => ContractErrorCode.Unsupported
        case _ => ContractErrorCode.InternalError
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
    if (operation == "tls" || operation == "ssh") {
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

private func contractCloneStringArray(values: Array<String>): Array<String> {
    let out = ArrayList<String>()
    for (value in values) {
        out.add(value)
    }
    out.toArray()
}
