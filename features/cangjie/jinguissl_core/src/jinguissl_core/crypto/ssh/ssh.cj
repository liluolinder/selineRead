package jinguissl_core.crypto.ssh

import std.collection.ArrayList
import jinguissl_core.crypto.aes.{
    AesGcmContext,
    aesCtrCrypt,
    aesGcmDecryptIntoWithContext,
    aesGcmEncryptIntoWithContext
}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.chacha20.{
    CHACHA20_POLY1305_TAG_LEN,
    Chacha20Poly1305Context,
    chacha20Poly1305DecryptWithContext,
    chacha20Poly1305EncryptWithContext,
    chacha20Poly1305NewContext
}
import jinguissl_core.crypto.digest.{hmac, sha1, sha256, sha384, sha512, HashAlgorithm}
import jinguissl_core.crypto.ed25519.{ed25519PublicKeyFromSeed, ed25519Sign, ed25519Verify, ED25519_PUBLIC_KEY_LEN, ED25519_SIGNATURE_LEN}
import jinguissl_core.crypto.ecc.{NamedCurve, EcPublicKey, EcPrivateKey, ecdsaSign, ecdsaVerify, ecPublicFromPrivateKey}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.rsa.{RsaHashAlgorithm, RsaPrivateKey, RsaPublicKey, rsaSignPkcs1v15WithHash, rsaVerifyPkcs1v15WithHash}
import jinguissl_core.crypto.utils.{constantTimeEquals, randomSeed, secureCopyInto}
import jinguissl_core.crypto.x25519.{X25519_KEY_LEN, X25519_SHARED_SECRET_LEN, x25519ValidatePublicKey, x25519PublicFromPrivate, x25519DeriveSharedSecret}

public let SSH_VERSION_PREFIX: String = "SSH-"
public let SSH_PROTOCOL_VERSION_2_0: String = "2.0"
public let SSH_MAX_IDENTIFICATION_LEN: Int64 = 255
public let SSH_MSG_KEXINIT: Int64 = 20
public let SSH_MSG_NEWKEYS: Int64 = 21
public let SSH_MSG_KEX_ECDH_INIT: Int64 = 30
public let SSH_MSG_KEX_ECDH_REPLY: Int64 = 31
public let SSH_DEFAULT_PACKET_BLOCK_SIZE: Int64 = 8
public let SSH_MIN_PACKET_PADDING_LEN: Int64 = 4
public let SSH_MAX_SEQUENCE_NUMBER: Int64 = 0xffff_ffff
public let SSH_HOST_KEY_ALGORITHM_RSA: String = "ssh-rsa"
public let SSH_HOST_KEY_ALGORITHM_RSA_SHA256: String = "rsa-sha2-256"
public let SSH_HOST_KEY_ALGORITHM_RSA_SHA512: String = "rsa-sha2-512"
public let SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256: String = "ecdsa-sha2-nistp256"
public let SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384: String = "ecdsa-sha2-nistp384"
public let SSH_HOST_KEY_ALGORITHM_ED25519: String = "ssh-ed25519"
public let SSH_KEX_ALGORITHM_SNTRUP761X25519_SHA512_OPENSSH: String = "sntrup761x25519-sha512@" + "openssh.com"
public let SSH_CIPHER_CHACHA20_POLY1305_OPENSSH: String = "chacha20-poly1305@" + "openssh.com"
public let SSH_CIPHER_AES128_GCM_OPENSSH: String = "aes128-gcm@" + "openssh.com"
public let SSH_CIPHER_AES256_GCM_OPENSSH: String = "aes256-gcm@" + "openssh.com"
public let SSH_MAC_ALGORITHM_UMAC64_OPENSSH: String = "umac-64@" + "openssh.com"
public let SSH_COMPRESSION_ZLIB_OPENSSH: String = "zlib@" + "openssh.com"
public let SSH_HOST_KEY_SHA256_LEN: Int64 = 32
private let SSH_AES_BLOCK_SIZE: Int64 = 16
private let SSH_P256_FIELD_LEN: Int64 = 32
private let SSH_P384_FIELD_LEN: Int64 = 48

public class SshVersionBanner {
    public let protocolVersion: String
    public let softwareVersion: String
    public let comments: String

    public init(protocolVersion: String, softwareVersion: String, comments!: String = "") {
        let normalizedProtocolVersion = protocolVersion.trimAscii()
        let normalizedSoftwareVersion = softwareVersion.trimAscii()
        let normalizedComments = comments.trimAscii()

        if (normalizedProtocolVersion != SSH_PROTOCOL_VERSION_2_0) {
            throw CryptoException(Unsupported, "SSH protocol version is unsupported: ${normalizedProtocolVersion}")
        }
        if (normalizedSoftwareVersion.size == 0) {
            throw CryptoException(InvalidArgument, "SSH software version must not be empty")
        }
        if (normalizedSoftwareVersion.contains(" ")) {
            throw CryptoException(InvalidArgument, "SSH software version must not contain spaces")
        }
        if (normalizedSoftwareVersion.contains("\r") || normalizedSoftwareVersion.contains("\n")) {
            throw CryptoException(InvalidArgument, "SSH software version must be single line")
        }
        if (normalizedComments.contains("\r") || normalizedComments.contains("\n")) {
            throw CryptoException(InvalidArgument, "SSH comments must be single line")
        }

        this.protocolVersion = normalizedProtocolVersion
        this.softwareVersion = normalizedSoftwareVersion
        this.comments = normalizedComments
    }

    public func lineText(): String {
        if (comments.size == 0) {
            return "${SSH_VERSION_PREFIX}${protocolVersion}-${softwareVersion}\r\n"
        }
        "${SSH_VERSION_PREFIX}${protocolVersion}-${softwareVersion} ${comments}\r\n"
    }
}

public class SshKexInitMessage {
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
        if (cookie.size != 16) {
            throw CryptoException(InvalidArgument, "SSH KEXINIT cookie must be 16 bytes")
        }
        if (reserved < 0 || reserved > 0xffff_ffff) {
            throw CryptoException(InvalidArgument, "SSH KEXINIT reserved must be uint32")
        }

        this.cookie = cookie.clone()
        this.kexAlgorithms = sshNormalizeNameList(kexAlgorithms, "kex_algorithms", false)
        this.serverHostKeyAlgorithms = sshNormalizeNameList(serverHostKeyAlgorithms, "server_host_key_algorithms", false)
        this.encryptionAlgorithmsClientToServer = sshNormalizeNameList(
            encryptionAlgorithmsClientToServer,
            "encryption_algorithms_client_to_server",
            false
        )
        this.encryptionAlgorithmsServerToClient = sshNormalizeNameList(
            encryptionAlgorithmsServerToClient,
            "encryption_algorithms_server_to_client",
            false
        )
        this.macAlgorithmsClientToServer = sshNormalizeNameList(
            macAlgorithmsClientToServer,
            "mac_algorithms_client_to_server",
            false
        )
        this.macAlgorithmsServerToClient = sshNormalizeNameList(
            macAlgorithmsServerToClient,
            "mac_algorithms_server_to_client",
            false
        )
        this.compressionAlgorithmsClientToServer = sshNormalizeNameList(
            compressionAlgorithmsClientToServer,
            "compression_algorithms_client_to_server",
            false
        )
        this.compressionAlgorithmsServerToClient = sshNormalizeNameList(
            compressionAlgorithmsServerToClient,
            "compression_algorithms_server_to_client",
            false
        )
        this.languagesClientToServer = sshNormalizeNameList(
            languagesClientToServer,
            "languages_client_to_server",
            true
        )
        this.languagesServerToClient = sshNormalizeNameList(
            languagesServerToClient,
            "languages_server_to_client",
            true
        )
        this.firstKexPacketFollows = firstKexPacketFollows
        this.reserved = reserved
    }
}

public class SshNegotiatedAlgorithms {
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
        compressionAlgorithmClientToServer: String,
        compressionAlgorithmServerToClient: String
    ) {
        this.kexAlgorithm = kexAlgorithm
        this.serverHostKeyAlgorithm = serverHostKeyAlgorithm
        this.encryptionAlgorithmClientToServer = encryptionAlgorithmClientToServer
        this.encryptionAlgorithmServerToClient = encryptionAlgorithmServerToClient
        this.macAlgorithmClientToServer = macAlgorithmClientToServer
        this.macAlgorithmServerToClient = macAlgorithmServerToClient
        this.compressionAlgorithmClientToServer = compressionAlgorithmClientToServer
        this.compressionAlgorithmServerToClient = compressionAlgorithmServerToClient
    }
}

public class SshTransportPacket {
    public let packetLength: Int64
    public let payload: Array<Byte>
    public let padding: Array<Byte>

    public init(payload: Array<Byte>, padding: Array<Byte>, packetLength: Int64) {
        if (packetLength < 1 + SSH_MIN_PACKET_PADDING_LEN) {
            throw CryptoException(InvalidArgument, "SSH packet length is too small")
        }
        if (padding.size < SSH_MIN_PACKET_PADDING_LEN) {
            throw CryptoException(InvalidArgument, "SSH packet padding is too short")
        }
        if (packetLength != 1 + payload.size + padding.size) {
            throw CryptoException(InvalidArgument, "SSH packet length does not match payload + padding")
        }
        this.packetLength = packetLength
        this.payload = payload.clone()
        this.padding = padding.clone()
    }
}

public class SshKexExchangeTranscript {
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
        if (clientKexInitPayload.size == 0 || serverKexInitPayload.size == 0) {
            throw CryptoException(InvalidArgument, "SSH KEX transcript requires both KEXINIT payloads")
        }
        if (Int64(UInt8(clientKexInitPayload[0])) != SSH_MSG_KEXINIT) {
            throw CryptoException(InvalidArgument, "SSH client KEXINIT payload type must be SSH_MSG_KEXINIT")
        }
        if (Int64(UInt8(serverKexInitPayload[0])) != SSH_MSG_KEXINIT) {
            throw CryptoException(InvalidArgument, "SSH server KEXINIT payload type must be SSH_MSG_KEXINIT")
        }

        _ = sshDecodeVersionBanner(clientBannerLine)
        _ = sshDecodeVersionBanner(serverBannerLine)

        this.clientBannerLine = clientBannerLine.clone()
        this.serverBannerLine = serverBannerLine.clone()
        this.clientKexInitPayload = clientKexInitPayload.clone()
        this.serverKexInitPayload = serverKexInitPayload.clone()
    }
}

public class SshKexEcdhInitMessage {
    public let clientEphemeralPublicKey: Array<Byte>

    public init(clientEphemeralPublicKey: Array<Byte>) {
        x25519ValidatePublicKey(clientEphemeralPublicKey)
        this.clientEphemeralPublicKey = clientEphemeralPublicKey.clone()
    }
}

public class SshKexEcdhReplyMessage {
    public let serverHostKey: Array<Byte>
    public let serverEphemeralPublicKey: Array<Byte>
    public let signature: Array<Byte>

    public init(
        serverHostKey: Array<Byte>,
        serverEphemeralPublicKey: Array<Byte>,
        signature: Array<Byte>
    ) {
        if (serverHostKey.size == 0) {
            throw CryptoException(InvalidArgument, "SSH server host key blob must not be empty")
        }
        x25519ValidatePublicKey(serverEphemeralPublicKey)
        if (signature.size == 0) {
            throw CryptoException(InvalidArgument, "SSH server host signature blob must not be empty")
        }
        this.serverHostKey = serverHostKey.clone()
        this.serverEphemeralPublicKey = serverEphemeralPublicKey.clone()
        this.signature = signature.clone()
    }
}

public class SshX25519KexResult {
    public let sharedSecret: Array<Byte>
    public let exchangeHash: Array<Byte>
    public let sessionId: Array<Byte>
    public let clientEphemeralPublicKey: Array<Byte>
    public let serverEphemeralPublicKey: Array<Byte>
    public let serverHostKey: Array<Byte>
    public let hostSignature: Array<Byte>

    public init(
        sharedSecret: Array<Byte>,
        exchangeHash: Array<Byte>,
        sessionId: Array<Byte>,
        clientEphemeralPublicKey: Array<Byte>,
        serverEphemeralPublicKey: Array<Byte>,
        serverHostKey: Array<Byte>,
        hostSignature: Array<Byte>
    ) {
        if (sharedSecret.size != X25519_SHARED_SECRET_LEN) {
            throw CryptoException(InvalidArgument, "SSH X25519 shared secret length is invalid")
        }
        if (exchangeHash.size != 32 || sessionId.size != 32) {
            throw CryptoException(InvalidArgument, "SSH exchange hash/session id must be SHA-256 sized")
        }
        x25519ValidatePublicKey(clientEphemeralPublicKey)
        x25519ValidatePublicKey(serverEphemeralPublicKey)
        if (serverHostKey.size == 0) {
            throw CryptoException(InvalidArgument, "SSH server host key blob must not be empty")
        }
        if (hostSignature.size == 0) {
            throw CryptoException(InvalidArgument, "SSH server host signature blob must not be empty")
        }

        this.sharedSecret = sharedSecret.clone()
        this.exchangeHash = exchangeHash.clone()
        this.sessionId = sessionId.clone()
        this.clientEphemeralPublicKey = clientEphemeralPublicKey.clone()
        this.serverEphemeralPublicKey = serverEphemeralPublicKey.clone()
        this.serverHostKey = serverHostKey.clone()
        this.hostSignature = hostSignature.clone()
    }
}

public class SshHostVerificationPolicy {
    public let negotiatedHostKeyAlgorithm: String
    public let expectedHostKeySha256: Array<Byte>
    public let requireKnownHost: Bool
    public let requireHostSignature: Bool
    public let allowLegacyRsaSha1: Bool

    public init(
        negotiatedHostKeyAlgorithm!: String = "",
        expectedHostKeySha256!: Array<Byte> = [],
        requireKnownHost!: Bool = false,
        requireHostSignature!: Bool = true,
        allowLegacyRsaSha1!: Bool = false
    ) {
        let normalizedNegotiated = negotiatedHostKeyAlgorithm.trimAscii().toAsciiLower()
        if (
            expectedHostKeySha256.size != 0 &&
            expectedHostKeySha256.size != SSH_HOST_KEY_SHA256_LEN
        ) {
            throw CryptoException(InvalidArgument, "SSH expected host key fingerprint must be SHA-256 sized")
        }
        if (requireKnownHost && expectedHostKeySha256.size == 0) {
            throw CryptoException(InvalidArgument, "SSH known-host verification requires expected host key fingerprint")
        }

        this.negotiatedHostKeyAlgorithm = normalizedNegotiated
        this.expectedHostKeySha256 = expectedHostKeySha256.clone()
        this.requireKnownHost = requireKnownHost
        this.requireHostSignature = requireHostSignature
        this.allowLegacyRsaSha1 = allowLegacyRsaSha1
    }
}

public class SshHostVerificationConfig {
    public let policy: SshHostVerificationPolicy
    public let requireVerifiedHost: Bool

    public init(
        policy!: SshHostVerificationPolicy = SshHostVerificationPolicy(),
        requireVerifiedHost!: Bool = true
    ) {
        this.policy = policy
        this.requireVerifiedHost = requireVerifiedHost
    }
}

public class SshHostVerificationResult {
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
            throw CryptoException(InvalidArgument, "SSH host verification algorithms must not be empty")
        }
        if (hostKeySha256.size != SSH_HOST_KEY_SHA256_LEN) {
            throw CryptoException(InvalidArgument, "SSH host key fingerprint must be SHA-256 sized")
        }
        this.hostKeyAlgorithm = hostKeyAlgorithm
        this.hostSignatureAlgorithm = hostSignatureAlgorithm
        this.hostKeySha256 = hostKeySha256.clone()
        this.hostSignatureVerified = hostSignatureVerified
    }
}

public class SshClientInitialHandshakeResult {
    public let coordinator: SshHandshakeCoordinator
    public let kexResult: SshX25519KexResult
    public let hostVerification: ?SshHostVerificationResult

    public init(
        coordinator: SshHandshakeCoordinator,
        kexResult: SshX25519KexResult,
        hostVerification!: ?SshHostVerificationResult = None
    ) {
        if (coordinator.role != SshPeerRole.Client) {
            throw CryptoException(InvalidArgument, "SSH client handshake result requires client coordinator")
        }
        if (!coordinator.isActive) {
            throw CryptoException(ParseError, "SSH client handshake coordinator is not active")
        }
        this.coordinator = coordinator
        this.kexResult = kexResult
        this.hostVerification = hostVerification
    }

    /**
 * requireHostVerification.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func requireHostVerification(): SshHostVerificationResult {
        match (hostVerification) {
            case Some(value) => value
            case None =>
                throw CryptoException(ParseError, "SSH host identity verification is unavailable")
        }
    }
}

public class SshServerInitialHandshakeResult {
    public let encodedReply: Array<Byte>
    public let coordinator: SshHandshakeCoordinator
    public let kexResult: SshX25519KexResult

    public init(
        encodedReply: Array<Byte>,
        coordinator: SshHandshakeCoordinator,
        kexResult: SshX25519KexResult
    ) {
        if (encodedReply.size == 0) {
            throw CryptoException(InvalidArgument, "SSH encoded KEX_ECDH_REPLY must not be empty")
        }
        if (coordinator.role != SshPeerRole.Server) {
            throw CryptoException(InvalidArgument, "SSH server handshake result requires server coordinator")
        }
        if (!coordinator.isActive) {
            throw CryptoException(ParseError, "SSH server handshake coordinator is not active")
        }
        this.encodedReply = encodedReply.clone()
        this.coordinator = coordinator
        this.kexResult = kexResult
    }
}

public class SshDirectionKeyMaterial {
    public let cipherName: String
    public let macName: String
    public let iv: Array<Byte>
    public let encryptionKey: Array<Byte>
    public let integrityKey: Array<Byte>

    public init(
        cipherName: String,
        macName: String,
        iv: Array<Byte>,
        encryptionKey: Array<Byte>,
        integrityKey: Array<Byte>
    ) {
        let normalizedCipher = cipherName.trimAscii().toAsciiLower()
        let normalizedMac = macName.trimAscii().toAsciiLower()
        let (ivLen, keyLen) = sshCipherMaterialLengths(normalizedCipher)
        let macLen = sshMacKeyLength(normalizedMac)
        if (ivLen != iv.size) {
            throw CryptoException(InvalidArgument, "SSH key material IV length mismatch for cipher ${normalizedCipher}")
        }
        if (keyLen != encryptionKey.size) {
            throw CryptoException(
                InvalidArgument,
                "SSH key material encryption key length mismatch for cipher ${normalizedCipher}"
            )
        }
        if (macLen != integrityKey.size) {
            throw CryptoException(InvalidArgument, "SSH key material MAC key length mismatch for MAC ${normalizedMac}")
        }

        this.cipherName = normalizedCipher
        this.macName = normalizedMac
        this.iv = iv.clone()
        this.encryptionKey = encryptionKey.clone()
        this.integrityKey = integrityKey.clone()
    }
}

public class SshDerivedSessionKeys {
    public let sessionId: Array<Byte>
    public let clientToServer: SshDirectionKeyMaterial
    public let serverToClient: SshDirectionKeyMaterial

    public init(
        sessionId: Array<Byte>,
        clientToServer: SshDirectionKeyMaterial,
        serverToClient: SshDirectionKeyMaterial
    ) {
        if (sessionId.size != 32) {
            throw CryptoException(InvalidArgument, "SSH session_id must be SHA-256 sized")
        }
        this.sessionId = sessionId.clone()
        this.clientToServer = clientToServer
        this.serverToClient = serverToClient
    }
}

public enum SshPeerRole <: Equatable<SshPeerRole> & ToString {
    | Client
    | Server

    public operator func ==(right: SshPeerRole): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SshPeerRole): Bool {
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

public enum SshHandshakePhase <: Equatable<SshHandshakePhase> & ToString {
    | Identification
    | KexInit
    | KexEcdh
    | NewKeys
    | Active

    public operator func ==(right: SshHandshakePhase): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SshHandshakePhase): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Identification => 0
            case KexInit => 1
            case KexEcdh => 2
            case NewKeys => 3
            case Active => 4
        }
    }

    public func toString(): String {
        match (this) {
            case Identification => "IDENTIFICATION"
            case KexInit => "KEXINIT"
            case KexEcdh => "KEX_ECDH"
            case NewKeys => "NEWKEYS"
            case Active => "ACTIVE"
        }
    }
}

public class SshHandshakeStateMachine {
    var _phase: SshHandshakePhase

    public init(phase!: SshHandshakePhase = SshHandshakePhase.Identification) {
        this._phase = phase
    }

    public prop phase: SshHandshakePhase {
        get() {
            _phase
        }
    }

    public func markVersionExchangeDone(): Unit {
        requireHandshakePhase(_phase, SshHandshakePhase.Identification, "version exchange")
        _phase = SshHandshakePhase.KexInit
    }

    public func markKexInitDone(): Unit {
        requireHandshakePhase(_phase, SshHandshakePhase.KexInit, "KEXINIT exchange")
        _phase = SshHandshakePhase.KexEcdh
    }

    public func markKexEcdhDone(): Unit {
        requireHandshakePhase(_phase, SshHandshakePhase.KexEcdh, "KEX_ECDH exchange")
        _phase = SshHandshakePhase.NewKeys
    }

    public func markNewKeysDone(): Unit {
        requireHandshakePhase(_phase, SshHandshakePhase.NewKeys, "NEWKEYS exchange")
        _phase = SshHandshakePhase.Active
    }

    public func beginRekey(): Unit {
        requireHandshakePhase(_phase, SshHandshakePhase.Active, "rekey")
        _phase = SshHandshakePhase.KexInit
    }

    /**
 * ensureActive.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func ensureActive(): Unit {
        if (_phase != SshHandshakePhase.Active) {
            throw CryptoException(ParseError, "SSH transport is not active yet")
        }
    }
}

public class SshPacketProtectionLayer {
    private let _writeState: SshPacketCipherState
    private let _readState: SshPacketCipherState

    public init(writeMaterial: SshDirectionKeyMaterial, readMaterial: SshDirectionKeyMaterial) {
        this._writeState = SshPacketCipherState(writeMaterial)
        this._readState = SshPacketCipherState(readMaterial)
    }

    public prop writeSequence: Int64 {
        get() {
            _writeState.sequence
        }
    }

    public prop readSequence: Int64 {
        get() {
            _readState.sequence
        }
    }

    public func reset(): Unit {
        _writeState.reset()
        _readState.reset()
    }

    public func seal(payload: Array<Byte>, randomPadding!: Array<Byte> = []): Array<Byte> {
        _writeState.seal(payload, randomPadding: randomPadding)
    }

    public func open(encodedPacket: Array<Byte>): SshTransportPacket {
        _readState.open(encodedPacket)
    }
}

public class SshHandshakeCoordinator {
    public let role: SshPeerRole
    public let negotiated: SshNegotiatedAlgorithms
    public let stateMachine: SshHandshakeStateMachine

    var _kexResult: ?SshX25519KexResult = None
    var _resolvedSessionId: Array<Byte> = Array<Byte>(0, repeat: 0)
    var _clientNewKeysAccepted: Bool = false
    var _serverNewKeysAccepted: Bool = false
    var _derivedKeys: ?SshDerivedSessionKeys = None
    var _packetLayer: ?SshPacketProtectionLayer = None
    var _hostVerification: ?SshHostVerificationResult = None

    public init(
        role: SshPeerRole,
        negotiated: SshNegotiatedAlgorithms,
        stateMachine!: SshHandshakeStateMachine = SshHandshakeStateMachine()
    ) {
        this.role = role
        this.negotiated = negotiated
        this.stateMachine = stateMachine
    }

    public prop phase: SshHandshakePhase {
        get() {
            stateMachine.phase
        }
    }

    public prop isActive: Bool {
        get() {
            stateMachine.phase == SshHandshakePhase.Active
        }
    }

    public prop writeSequence: Int64 {
        get() {
            requirePacketProtectionLayer().writeSequence
        }
    }

    public prop readSequence: Int64 {
        get() {
            requirePacketProtectionLayer().readSequence
        }
    }

    public func markVersionExchangeDone(): Unit {
        stateMachine.markVersionExchangeDone()
    }

    public func markKexInitDone(): Unit {
        stateMachine.markKexInitDone()
    }

    public func markKexEcdhDone(kexResult: SshX25519KexResult, existingSessionId!: Array<Byte> = []): Unit {
        stateMachine.markKexEcdhDone()
        _kexResult = Some(kexResult)
        let seedSessionId = if (existingSessionId.size != 0) {
            existingSessionId
        } else if (_resolvedSessionId.size != 0) {
            _resolvedSessionId
        } else {
            Array<Byte>(0, repeat: 0)
        }
        _resolvedSessionId = sshResolveSessionId(kexResult.exchangeHash, existingSessionId: seedSessionId)
        _clientNewKeysAccepted = false
        _serverNewKeysAccepted = false
        _derivedKeys = None
        _packetLayer = None
        _hostVerification = None
    }

    public func markKexEcdhDoneVerified(
        kexResult: SshX25519KexResult,
        policy!: SshHostVerificationPolicy = SshHostVerificationPolicy(),
        existingSessionId!: Array<Byte> = []
    ): SshHostVerificationResult {
        let verification = sshRequireVerifiedHostIdentity(kexResult, policy: policy)
        markKexEcdhDone(kexResult, existingSessionId: existingSessionId)
        _hostVerification = Some(verification)
        verification
    }

    public func markKexEcdhDoneWithHostVerificationRequirement(
        kexResult: SshX25519KexResult,
        policy!: SshHostVerificationPolicy = SshHostVerificationPolicy(),
        requireVerifiedHost!: Bool = true,
        existingSessionId!: Array<Byte> = []
    ): ?SshHostVerificationResult {
        let verification = sshVerifyHostIdentityWithRequirement(
            kexResult,
            policy: policy,
            requireVerifiedHost: requireVerifiedHost
        )
        markKexEcdhDone(kexResult, existingSessionId: existingSessionId)
        if (let Some(value) <- verification) {
            _hostVerification = Some(value)
            return Some(value)
        }
        None
    }

    public func markKexEcdhDoneWithHostVerificationConfig(
        kexResult: SshX25519KexResult,
        config!: SshHostVerificationConfig = SshHostVerificationConfig(),
        existingSessionId!: Array<Byte> = []
    ): ?SshHostVerificationResult {
        markKexEcdhDoneWithHostVerificationRequirement(
            kexResult,
            policy: config.policy,
            requireVerifiedHost: config.requireVerifiedHost,
            existingSessionId: existingSessionId
        )
    }

    /**
 * acceptNewKeys.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func acceptNewKeys(from: SshPeerRole, encodedNewKeys: Array<Byte>): Bool {
        requireHandshakePhase(stateMachine.phase, SshHandshakePhase.NewKeys, "accept NEWKEYS")
        sshDecodeNewKeys(encodedNewKeys)
        if (from == SshPeerRole.Client) {
            if (_clientNewKeysAccepted) {
                throw CryptoException(ParseError, "SSH client NEWKEYS replay detected")
            }
            _clientNewKeysAccepted = true
        } else {
            if (_serverNewKeysAccepted) {
                throw CryptoException(ParseError, "SSH server NEWKEYS replay detected")
            }
            _serverNewKeysAccepted = true
        }

        if (!_clientNewKeysAccepted || !_serverNewKeysAccepted) {
            return false
        }
        let kex = requireKexResult()
        let derived = sshDeriveSessionKeysSha256(
            kex.sharedSecret,
            kex.exchangeHash,
            _resolvedSessionId,
            negotiated
        )
        let packetLayer = sshBuildPacketProtectionLayer(derived, role: role)
        _derivedKeys = Some(derived)
        _packetLayer = Some(packetLayer)
        stateMachine.markNewKeysDone()
        true
    }

    /**
 * sessionId.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sessionId(): Array<Byte> {
        if (_resolvedSessionId.size == 0) {
            throw CryptoException(ParseError, "SSH session_id is not resolved yet")
        }
        _resolvedSessionId.clone()
    }

    /**
 * derivedKeys.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func derivedKeys(): SshDerivedSessionKeys {
        match (_derivedKeys) {
            case Some(value) => value
            case None =>
                throw CryptoException(ParseError, "SSH session keys are not active yet")
        }
    }

    /**
 * hostVerification.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func hostVerification(): SshHostVerificationResult {
        match (_hostVerification) {
            case Some(value) => value
            case None =>
                throw CryptoException(ParseError, "SSH host identity is not verified yet")
        }
    }

    public func resetTransportCounters(): Unit {
        requirePacketProtectionLayer().reset()
    }

    public func seal(payload: Array<Byte>, randomPadding!: Array<Byte> = []): Array<Byte> {
        stateMachine.ensureActive()
        requirePacketProtectionLayer().seal(payload, randomPadding: randomPadding)
    }

    public func open(encodedPacket: Array<Byte>): SshTransportPacket {
        stateMachine.ensureActive()
        requirePacketProtectionLayer().open(encodedPacket)
    }

    public func rekeyWithX25519(
        kexResult: SshX25519KexResult,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>
    ): SshDerivedSessionKeys {
        stateMachine.beginRekey()
        stateMachine.markKexInitDone()
        markKexEcdhDone(kexResult)
        _ = acceptNewKeys(SshPeerRole.Client, encodedClientNewKeys)
        _ = acceptNewKeys(SshPeerRole.Server, encodedServerNewKeys)
        derivedKeys()
    }

    public func rekeyWithX25519Verified(
        kexResult: SshX25519KexResult,
        encodedClientNewKeys: Array<Byte>,
        encodedServerNewKeys: Array<Byte>,
        policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
    ): SshDerivedSessionKeys {
        stateMachine.beginRekey()
        stateMachine.markKexInitDone()
        _ = markKexEcdhDoneVerified(kexResult, policy: policy)
        _ = acceptNewKeys(SshPeerRole.Client, encodedClientNewKeys)
        _ = acceptNewKeys(SshPeerRole.Server, encodedServerNewKeys)
        derivedKeys()
    }

    private func requireKexResult(): SshX25519KexResult {
        match (_kexResult) {
            case Some(value) => value
            case None =>
                throw CryptoException(ParseError, "SSH key exchange result is not set")
        }
    }

    private func requirePacketProtectionLayer(): SshPacketProtectionLayer {
        match (_packetLayer) {
            case Some(value) => value
            case None =>
                throw CryptoException(ParseError, "SSH packet protection layer is not active yet")
        }
    }
}

private class SshPacketCipherState {
    public let material: SshDirectionKeyMaterial
    let _blockSize: Int64
    let _aeadTagLen: Int64
    let _aesGcmContext: ?AesGcmContext
    let _chacha20Context: ?Chacha20Poly1305Context
    var _aeadNonceScratch: Array<Byte> = []
    var _aeadAadScratch: Array<Byte> = Array<Byte>(4, repeat: 0)
    var _aeadCipherScratch: Array<Byte> = []
    var _aeadPlainScratch: Array<Byte> = []
    var _aeadTagScratch: Array<Byte> = Array<Byte>(CHACHA20_POLY1305_TAG_LEN, repeat: 0)
    var _sequence: Int64 = 0
    var _counter: Array<Byte>

    public init(material: SshDirectionKeyMaterial) {
        this.material = material
        this._blockSize = sshCipherPacketBlockSize(material.cipherName)
        this._aeadTagLen = sshCipherTagLength(material.cipherName)
        this._counter = material.iv.clone()
        if (material.cipherName == SSH_CIPHER_AES128_GCM_OPENSSH || material.cipherName == SSH_CIPHER_AES256_GCM_OPENSSH) {
            this._aesGcmContext = Some(AesGcmContext(material.encryptionKey))
            this._chacha20Context = None
        } else if (material.cipherName == SSH_CIPHER_CHACHA20_POLY1305_OPENSSH) {
            this._aesGcmContext = None
            this._chacha20Context = Some(chacha20Poly1305NewContext(material.encryptionKey))
        } else {
            this._aesGcmContext = None
            this._chacha20Context = None
        }
    }

    public prop sequence: Int64 {
        get() {
            _sequence
        }
    }

    public func reset(): Unit {
        _sequence = 0
        _counter = material.iv.clone()
    }

    /**
 * seal.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func seal(payload: Array<Byte>, randomPadding!: Array<Byte> = []): Array<Byte> {
        let packet = sshEncodeTransportPacket(payload, blockSize: _blockSize, randomPadding: randomPadding)
        if (_aeadTagLen != 0) {
            _aeadNonceScratch = sshEnsureScratchSize(_aeadNonceScratch, _counter.size)
            sshCopyBytesRange(_counter, 0, _aeadNonceScratch, _counter.size)
            sshWritePacketAeadAad(_aeadAadScratch, _sequence)
            if (material.cipherName == SSH_CIPHER_AES128_GCM_OPENSSH || material.cipherName == SSH_CIPHER_AES256_GCM_OPENSSH) {
                let context = match (_aesGcmContext) {
                    case Some(value) => value
                    case None =>
                        throw CryptoException(InternalError, "SSH AES-GCM packet state is not initialized")
                }
                _aeadCipherScratch = sshEnsureScratchSize(_aeadCipherScratch, packet.size)
                aesGcmEncryptIntoWithContext(
                    context,
                    _aeadNonceScratch,
                    packet,
                    _aeadCipherScratch,
                    _aeadTagScratch,
                    aad: _aeadAadScratch,
                    tagLen: _aeadTagLen
                )
                let sealedPacket = sshConcatCipherAndTag(_aeadCipherScratch, _aeadTagScratch, _aeadTagLen)
                sshAdvanceCounterForPacket(material.cipherName, _counter, packet.size)
                _sequence = sshNextSequence(_sequence)
                return sealedPacket
            }
            let sealedPacket = sshSealPacketAead(
                material.cipherName,
                _aeadNonceScratch,
                packet,
                _aeadAadScratch,
                _aesGcmContext,
                _chacha20Context
            )
            sshAdvanceCounterForPacket(material.cipherName, _counter, packet.size)
            _sequence = sshNextSequence(_sequence)
            return sealedPacket
        }

        let mac = sshComputePacketMac(material.macName, material.integrityKey, _sequence, packet)
        let encryptedPacket = sshCipherPacket(material.cipherName, material.encryptionKey, _counter, packet)
        sshAdvanceCounterForPacket(material.cipherName, _counter, encryptedPacket.size)
        _sequence = sshNextSequence(_sequence)
        concatBytes(encryptedPacket, mac)
    }

    /**
 * open.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func open(encodedPacket: Array<Byte>): SshTransportPacket {
        if (_aeadTagLen != 0) {
            if (encodedPacket.size < 4 + 1 + SSH_MIN_PACKET_PADDING_LEN + _aeadTagLen) {
                throw CryptoException(ParseError, "SSH protected packet is too short")
            }
            let cipherPacketLen = encodedPacket.size - _aeadTagLen
            _aeadNonceScratch = sshEnsureScratchSize(_aeadNonceScratch, _counter.size)
            sshCopyBytesRange(_counter, 0, _aeadNonceScratch, _counter.size)
            sshWritePacketAeadAad(_aeadAadScratch, _sequence)
            let packet = if (material.cipherName == SSH_CIPHER_AES128_GCM_OPENSSH || material.cipherName == SSH_CIPHER_AES256_GCM_OPENSSH) {
                let context = match (_aesGcmContext) {
                    case Some(value) => value
                    case None =>
                        throw CryptoException(InternalError, "SSH AES-GCM packet state is not initialized")
                }
                _aeadCipherScratch = sshEnsureScratchSize(_aeadCipherScratch, cipherPacketLen)
                _aeadPlainScratch = sshEnsureScratchSize(_aeadPlainScratch, cipherPacketLen)
                sshCopyBytesRange(encodedPacket, 0, _aeadCipherScratch, cipherPacketLen)
                sshCopyBytesRange(encodedPacket, cipherPacketLen, _aeadTagScratch, _aeadTagLen)
                try {
                    aesGcmDecryptIntoWithContext(
                        context,
                        _aeadNonceScratch,
                        _aeadCipherScratch,
                        _aeadTagScratch,
                        _aeadPlainScratch,
                        aad: _aeadAadScratch
                    )
                    _aeadPlainScratch
                } catch (_: CryptoException) {
                    throw CryptoException(ParseError, "SSH packet AEAD verification failed")
                }
            } else {
                _aeadCipherScratch = sshEnsureScratchSize(_aeadCipherScratch, cipherPacketLen)
                sshCopyBytesRange(encodedPacket, 0, _aeadCipherScratch, cipherPacketLen)
                sshCopyBytesRange(encodedPacket, cipherPacketLen, _aeadTagScratch, _aeadTagLen)
                sshOpenPacketAead(
                    material.cipherName,
                    _aeadNonceScratch,
                    _aeadCipherScratch,
                    _aeadTagScratch,
                    _aeadAadScratch,
                    _aesGcmContext,
                    _chacha20Context
                )
            }
            let decoded = sshDecodeTransportPacket(packet, blockSize: _blockSize)
            sshAdvanceCounterForPacket(material.cipherName, _counter, packet.size)
            _sequence = sshNextSequence(_sequence)
            return decoded
        }

        let macLen = sshMacDigestLength(material.macName)
        if (encodedPacket.size < 4 + 1 + SSH_MIN_PACKET_PADDING_LEN + macLen) {
            throw CryptoException(ParseError, "SSH protected packet is too short")
        }
        let cipherPacketLen = encodedPacket.size - macLen
        let encryptedPacket = encodedPacket[0..cipherPacketLen]
        let receivedMac = if (macLen == 0) {
            Array<Byte>(0, repeat: 0)
        } else {
            encodedPacket[cipherPacketLen..]
        }

        let packet = sshCipherPacket(material.cipherName, material.encryptionKey, _counter, encryptedPacket)
        let expectedMac = sshComputePacketMac(material.macName, material.integrityKey, _sequence, packet)
        if (!constantTimeEquals(receivedMac, expectedMac)) {
            throw CryptoException(ParseError, "SSH packet MAC verification failed")
        }

        let decoded = sshDecodeTransportPacket(packet, blockSize: _blockSize)
        sshAdvanceCounterForPacket(material.cipherName, _counter, encryptedPacket.size)
        _sequence = sshNextSequence(_sequence)
        decoded
    }
}

public func sshBuildVersionBanner(softwareVersion: String, comments!: String = ""): SshVersionBanner {
    SshVersionBanner(SSH_PROTOCOL_VERSION_2_0, softwareVersion, comments: comments)
}

/**
 * sshEncodeVersionBanner.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshEncodeVersionBanner(banner: SshVersionBanner): Array<Byte> {
    let line = banner.lineText()
    if (line.size > SSH_MAX_IDENTIFICATION_LEN) {
        throw CryptoException(OutOfBounds, "SSH version identification line exceeds max length")
    }
    line.toArray()
}

/**
 * sshDecodeVersionBanner.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshDecodeVersionBanner(encodedLine: Array<Byte>): SshVersionBanner {
    if (encodedLine.size == 0 || encodedLine.size > SSH_MAX_IDENTIFICATION_LEN) {
        throw CryptoException(ParseError, "SSH version identification line length is invalid")
    }
    if (encodedLine.size < 8) {
        throw CryptoException(ParseError, "SSH version identification line is too short")
    }
    if (
        UInt8(encodedLine[encodedLine.size - 2]) != UInt8(b'\r') ||
        UInt8(encodedLine[encodedLine.size - 1]) != UInt8(b'\n')
    ) {
        throw CryptoException(ParseError, "SSH version identification line must end with CRLF")
    }

    let line = encodedLine[0..(encodedLine.size - 2)]
    if (
        UInt8(line[0]) != UInt8(b'S') ||
        UInt8(line[1]) != UInt8(b'S') ||
        UInt8(line[2]) != UInt8(b'H') ||
        UInt8(line[3]) != UInt8(b'-')
    ) {
        throw CryptoException(ParseError, "SSH version identification line prefix is invalid")
    }

    var dashIndex = -1
    var i = 4
    while (i < line.size) {
        if (UInt8(line[i]) == UInt8(b'-')) {
            dashIndex = i
            break
        }
        i += 1
    }
    if (dashIndex < 0) {
        throw CryptoException(ParseError, "SSH version identification line missing protocol/software separator")
    }
    if (dashIndex + 1 >= line.size) {
        throw CryptoException(ParseError, "SSH version identification line missing software version")
    }

    let protocolVersion = String.fromUtf8(line[4..dashIndex])
    let trailing = line[(dashIndex + 1)..]
    var spaceIndex = -1
    i = 0
    while (i < trailing.size) {
        if (UInt8(trailing[i]) == UInt8(b' ')) {
            spaceIndex = i
            break
        }
        i += 1
    }

    let softwareVersionBytes = if (spaceIndex >= 0) {
        trailing[0..spaceIndex]
    } else {
        trailing
    }
    if (softwareVersionBytes.size == 0) {
        throw CryptoException(ParseError, "SSH version identification line missing software version")
    }
    let commentsBytes = if (spaceIndex >= 0 && spaceIndex + 1 < trailing.size) {
        trailing[(spaceIndex + 1)..]
    } else {
        Array<Byte>(0, repeat: 0)
    }

    SshVersionBanner(
        protocolVersion,
        String.fromUtf8(softwareVersionBytes),
        comments: String.fromUtf8(commentsBytes)
    )
}

public func sshBuildDefaultKexInit(cookie!: Array<Byte> = []): SshKexInitMessage {
    let effectiveCookie = if (cookie.size == 0) {
        randomSeed(size: 16)
    } else {
        cookie
    }
    SshKexInitMessage(
        effectiveCookie,
        ["curve25519-sha256", "ecdh-sha2-nistp256", "diffie-hellman-group14-sha256"],
        [
            "ssh-ed25519",
            "rsa-sha2-512",
            "rsa-sha2-256",
            "ecdsa-sha2-nistp256",
            "ecdsa-sha2-nistp384"
        ],
        [
            SSH_CIPHER_CHACHA20_POLY1305_OPENSSH,
            SSH_CIPHER_AES128_GCM_OPENSSH,
            SSH_CIPHER_AES256_GCM_OPENSSH,
            "aes128-ctr",
            "aes256-ctr"
        ],
        [
            SSH_CIPHER_CHACHA20_POLY1305_OPENSSH,
            SSH_CIPHER_AES128_GCM_OPENSSH,
            SSH_CIPHER_AES256_GCM_OPENSSH,
            "aes128-ctr",
            "aes256-ctr"
        ],
        ["hmac-sha2-256", "hmac-sha2-512"],
        ["hmac-sha2-256", "hmac-sha2-512"],
        ["none", SSH_COMPRESSION_ZLIB_OPENSSH],
        ["none", SSH_COMPRESSION_ZLIB_OPENSSH],
        languagesClientToServer: [],
        languagesServerToClient: [],
        firstKexPacketFollows: false,
        reserved: 0
    )
}

public func sshEncodeKexEcdhInit(message: SshKexEcdhInitMessage): Array<Byte> {
    let out = ArrayList<Byte>()
    out.add(UInt8(SSH_MSG_KEX_ECDH_INIT))
    appendString(out, message.clientEphemeralPublicKey)
    out.toArray()
}

/**
 * sshDecodeKexEcdhInit.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshDecodeKexEcdhInit(encoded: Array<Byte>): SshKexEcdhInitMessage {
    if (encoded.size < 1 + 4 + X25519_KEY_LEN) {
        throw CryptoException(ParseError, "SSH_MSG_KEX_ECDH_INIT payload is too short")
    }
    if (Int64(UInt8(encoded[0])) != SSH_MSG_KEX_ECDH_INIT) {
        throw CryptoException(ParseError, "SSH packet is not SSH_MSG_KEX_ECDH_INIT")
    }
    let (clientPublicKey, offset) = decodeString(encoded, 1, "SSH_MSG_KEX_ECDH_INIT Q_C")
    if (offset != encoded.size) {
        throw CryptoException(ParseError, "SSH_MSG_KEX_ECDH_INIT has trailing bytes")
    }
    SshKexEcdhInitMessage(clientPublicKey)
}

public func sshEncodeKexEcdhReply(message: SshKexEcdhReplyMessage): Array<Byte> {
    let out = ArrayList<Byte>()
    out.add(UInt8(SSH_MSG_KEX_ECDH_REPLY))
    appendString(out, message.serverHostKey)
    appendString(out, message.serverEphemeralPublicKey)
    appendString(out, message.signature)
    out.toArray()
}

/**
 * sshDecodeKexEcdhReply.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshDecodeKexEcdhReply(encoded: Array<Byte>): SshKexEcdhReplyMessage {
    if (encoded.size < 1 + 12) {
        throw CryptoException(ParseError, "SSH_MSG_KEX_ECDH_REPLY payload is too short")
    }
    if (Int64(UInt8(encoded[0])) != SSH_MSG_KEX_ECDH_REPLY) {
        throw CryptoException(ParseError, "SSH packet is not SSH_MSG_KEX_ECDH_REPLY")
    }
    let (serverHostKey, hostOffset) = decodeString(encoded, 1, "SSH_MSG_KEX_ECDH_REPLY K_S")
    let (serverEphemeralPublicKey, keyOffset) = decodeString(
        encoded,
        hostOffset,
        "SSH_MSG_KEX_ECDH_REPLY Q_S"
    )
    let (signature, offset) = decodeString(encoded, keyOffset, "SSH_MSG_KEX_ECDH_REPLY signature")
    if (offset != encoded.size) {
        throw CryptoException(ParseError, "SSH_MSG_KEX_ECDH_REPLY has trailing bytes")
    }
    SshKexEcdhReplyMessage(serverHostKey, serverEphemeralPublicKey, signature)
}

public func sshEncodeNewKeys(): Array<Byte> {
    [UInt8(SSH_MSG_NEWKEYS)]
}

/**
 * sshDecodeNewKeys.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshDecodeNewKeys(encoded: Array<Byte>): Unit {
    if (encoded.size != 1) {
        throw CryptoException(ParseError, "SSH_MSG_NEWKEYS payload length is invalid")
    }
    if (Int64(UInt8(encoded[0])) != SSH_MSG_NEWKEYS) {
        throw CryptoException(ParseError, "SSH packet is not SSH_MSG_NEWKEYS")
    }
}

public func sshIsCipherSupported(cipherName: String): Bool {
    let normalizedCipher = cipherName.trimAscii().toAsciiLower()
    try {
        _ = sshCipherMaterialLengths(normalizedCipher)
        true
    } catch (_: CryptoException) {
        false
    }
}

public func sshIsMacSupported(macName: String): Bool {
    let normalizedMac = macName.trimAscii().toAsciiLower()
    try {
        _ = sshMacKeyLength(normalizedMac)
        true
    } catch (_: CryptoException) {
        false
    }
}

/**
 * sshResolveSessionId.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshResolveSessionId(
    exchangeHash: Array<Byte>,
    existingSessionId!: Array<Byte> = []
): Array<Byte> {
    if (exchangeHash.size != 32) {
        throw CryptoException(InvalidArgument, "SSH exchange hash must be SHA-256 sized")
    }
    if (existingSessionId.size == 0) {
        return exchangeHash.clone()
    }
    if (existingSessionId.size != 32) {
        throw CryptoException(InvalidArgument, "SSH existing session_id must be SHA-256 sized")
    }
    existingSessionId.clone()
}

/**
 * sshDeriveSessionKeysSha256.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshDeriveSessionKeysSha256(
    sharedSecret: Array<Byte>,
    exchangeHash: Array<Byte>,
    sessionId: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms
): SshDerivedSessionKeys {
    if (sharedSecret.size != X25519_SHARED_SECRET_LEN) {
        throw CryptoException(InvalidArgument, "SSH KDF shared secret length is invalid")
    }
    if (exchangeHash.size != 32) {
        throw CryptoException(InvalidArgument, "SSH KDF exchange hash must be SHA-256 sized")
    }
    if (sessionId.size != 32) {
        throw CryptoException(InvalidArgument, "SSH KDF session_id must be SHA-256 sized")
    }

    let cipherC2s = negotiated.encryptionAlgorithmClientToServer.trimAscii().toAsciiLower()
    let cipherS2c = negotiated.encryptionAlgorithmServerToClient.trimAscii().toAsciiLower()
    let macC2s = negotiated.macAlgorithmClientToServer.trimAscii().toAsciiLower()
    let macS2c = negotiated.macAlgorithmServerToClient.trimAscii().toAsciiLower()

    let (ivLenC2s, keyLenC2s) = sshCipherMaterialLengths(cipherC2s)
    let (ivLenS2c, keyLenS2c) = sshCipherMaterialLengths(cipherS2c)
    let macLenC2s = sshMacKeyLength(macC2s)
    let macLenS2c = sshMacKeyLength(macS2c)

    let ivC2s = sshDeriveKeyMaterialSha256(sharedSecret, exchangeHash, UInt8(b'A'), sessionId, ivLenC2s)
    let ivS2c = sshDeriveKeyMaterialSha256(sharedSecret, exchangeHash, UInt8(b'B'), sessionId, ivLenS2c)
    let keyC2s = sshDeriveKeyMaterialSha256(sharedSecret, exchangeHash, UInt8(b'C'), sessionId, keyLenC2s)
    let keyS2c = sshDeriveKeyMaterialSha256(sharedSecret, exchangeHash, UInt8(b'D'), sessionId, keyLenS2c)
    let macKeyC2s = sshDeriveKeyMaterialSha256(sharedSecret, exchangeHash, UInt8(b'E'), sessionId, macLenC2s)
    let macKeyS2c = sshDeriveKeyMaterialSha256(sharedSecret, exchangeHash, UInt8(b'F'), sessionId, macLenS2c)

    let c2s = SshDirectionKeyMaterial(
        cipherC2s,
        macC2s,
        ivC2s,
        keyC2s,
        macKeyC2s
    )
    let s2c = SshDirectionKeyMaterial(
        cipherS2c,
        macS2c,
        ivS2c,
        keyS2c,
        macKeyS2c
    )
    SshDerivedSessionKeys(sessionId, c2s, s2c)
}

public func sshDeriveSessionKeysFromX25519Result(
    kexResult: SshX25519KexResult,
    negotiated: SshNegotiatedAlgorithms,
    existingSessionId!: Array<Byte> = []
): SshDerivedSessionKeys {
    let sessionId = sshResolveSessionId(kexResult.exchangeHash, existingSessionId: existingSessionId)
    sshDeriveSessionKeysSha256(kexResult.sharedSecret, kexResult.exchangeHash, sessionId, negotiated)
}

public func sshCompleteInitialKeyExchangeX25519(
    kexResult: SshX25519KexResult,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>
): SshDerivedSessionKeys {
    sshDecodeNewKeys(encodedClientNewKeys)
    sshDecodeNewKeys(encodedServerNewKeys)
    sshDeriveSessionKeysFromX25519Result(kexResult, negotiated)
}

public func sshBuildPacketProtectionLayer(
    derivedKeys: SshDerivedSessionKeys,
    role!: SshPeerRole = SshPeerRole.Client
): SshPacketProtectionLayer {
    match (role) {
        case SshPeerRole.Client =>
            SshPacketProtectionLayer(derivedKeys.clientToServer, derivedKeys.serverToClient)
        case SshPeerRole.Server =>
            SshPacketProtectionLayer(derivedKeys.serverToClient, derivedKeys.clientToServer)
    }
}

public func sshCompleteInitialHandshakeCoordinatorX25519(
    role: SshPeerRole,
    kexResult: SshX25519KexResult,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>
): SshHandshakeCoordinator {
    let coordinator = SshHandshakeCoordinator(role, negotiated)
    coordinator.markVersionExchangeDone()
    coordinator.markKexInitDone()
    coordinator.markKexEcdhDone(kexResult)
    _ = coordinator.acceptNewKeys(SshPeerRole.Client, encodedClientNewKeys)
    _ = coordinator.acceptNewKeys(SshPeerRole.Server, encodedServerNewKeys)
    coordinator
}

public func sshCompleteInitialHandshakeCoordinatorX25519Verified(
    role: SshPeerRole,
    kexResult: SshX25519KexResult,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
): SshHandshakeCoordinator {
    let coordinator = SshHandshakeCoordinator(role, negotiated)
    coordinator.markVersionExchangeDone()
    coordinator.markKexInitDone()
    _ = coordinator.markKexEcdhDoneVerified(kexResult, policy: policy)
    _ = coordinator.acceptNewKeys(SshPeerRole.Client, encodedClientNewKeys)
    _ = coordinator.acceptNewKeys(SshPeerRole.Server, encodedServerNewKeys)
    coordinator
}

public func sshCompleteInitialHandshakeCoordinatorX25519WithHostVerificationRequirement(
    role: SshPeerRole,
    kexResult: SshX25519KexResult,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy(),
    requireVerifiedHost!: Bool = true
): SshHandshakeCoordinator {
    let coordinator = SshHandshakeCoordinator(role, negotiated)
    coordinator.markVersionExchangeDone()
    coordinator.markKexInitDone()
    _ = coordinator.markKexEcdhDoneWithHostVerificationRequirement(
        kexResult,
        policy: policy,
        requireVerifiedHost: requireVerifiedHost
    )
    _ = coordinator.acceptNewKeys(SshPeerRole.Client, encodedClientNewKeys)
    _ = coordinator.acceptNewKeys(SshPeerRole.Server, encodedServerNewKeys)
    coordinator
}

public func sshCompleteInitialHandshakeCoordinatorX25519WithHostVerificationConfig(
    role: SshPeerRole,
    kexResult: SshX25519KexResult,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    config!: SshHostVerificationConfig = SshHostVerificationConfig()
): SshHandshakeCoordinator {
    let coordinator = SshHandshakeCoordinator(role, negotiated)
    coordinator.markVersionExchangeDone()
    coordinator.markKexInitDone()
    _ = coordinator.markKexEcdhDoneWithHostVerificationConfig(kexResult, config: config)
    _ = coordinator.acceptNewKeys(SshPeerRole.Client, encodedClientNewKeys)
    _ = coordinator.acceptNewKeys(SshPeerRole.Server, encodedServerNewKeys)
    coordinator
}

public func sshCompleteServerInitialHandshakeX25519(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    serverHostKey: Array<Byte>,
    hostSignature: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    serverPublicKey!: Array<Byte> = []
): SshServerInitialHandshakeResult {
    let (encodedReply, serverResult) = sshServerProcessKexEcdhInitX25519(
        transcript,
        serverPrivateKey,
        encodedClientInit,
        serverHostKey,
        hostSignature,
        serverPublicKey: serverPublicKey
    )
    let coordinator = sshCompleteInitialHandshakeCoordinatorX25519(
        SshPeerRole.Server,
        serverResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys
    )
    SshServerInitialHandshakeResult(encodedReply, coordinator, serverResult)
}

public func sshCompleteServerInitialHandshakeX25519Rsa(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    hostPrivateKey: RsaPrivateKey,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    signatureAlgorithm!: String = SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
    serverPublicKey!: Array<Byte> = []
): SshServerInitialHandshakeResult {
    let signingArtifacts = sshPrepareServerSigningArtifactsX25519(
        serverPrivateKey,
        encodedClientInit,
        serverPublicKey: serverPublicKey
    )
    let serverHostKey = sshEncodeRsaHostPublicKey(hostPrivateKey.publicKey)
    let exchangeHash = sshComputeExchangeHashSha256(
        transcript,
        serverHostKey,
        signingArtifacts.clientEphemeralPublicKey,
        signingArtifacts.serverEphemeralPublicKey,
        signingArtifacts.sharedSecret
    )
    let hostSignature = sshSignExchangeHashRsa(
        hostPrivateKey,
        exchangeHash,
        signatureAlgorithm: signatureAlgorithm
    )
    let (encodedReply, serverResult) = sshBuildServerProcessKexEcdhInitResultX25519(
        transcript,
        signingArtifacts.clientEphemeralPublicKey,
        signingArtifacts.serverEphemeralPublicKey,
        signingArtifacts.sharedSecret,
        serverHostKey,
        hostSignature
    )
    let coordinator = sshCompleteInitialHandshakeCoordinatorX25519(
        SshPeerRole.Server,
        serverResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys
    )
    SshServerInitialHandshakeResult(encodedReply, coordinator, serverResult)
}

public func sshCompleteServerInitialHandshakeX25519Ecdsa(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    hostPrivateKey: EcPrivateKey,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    serverPublicKey!: Array<Byte> = []
): SshServerInitialHandshakeResult {
    let signingArtifacts = sshPrepareServerSigningArtifactsX25519(
        serverPrivateKey,
        encodedClientInit,
        serverPublicKey: serverPublicKey
    )
    let serverHostKey = sshEncodeEcdsaHostPublicKey(ecPublicFromPrivateKey(hostPrivateKey))
    let exchangeHash = sshComputeExchangeHashSha256(
        transcript,
        serverHostKey,
        signingArtifacts.clientEphemeralPublicKey,
        signingArtifacts.serverEphemeralPublicKey,
        signingArtifacts.sharedSecret
    )
    let hostSignature = sshSignExchangeHashEcdsa(hostPrivateKey, exchangeHash)
    let (encodedReply, serverResult) = sshBuildServerProcessKexEcdhInitResultX25519(
        transcript,
        signingArtifacts.clientEphemeralPublicKey,
        signingArtifacts.serverEphemeralPublicKey,
        signingArtifacts.sharedSecret,
        serverHostKey,
        hostSignature
    )
    let coordinator = sshCompleteInitialHandshakeCoordinatorX25519(
        SshPeerRole.Server,
        serverResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys
    )
    SshServerInitialHandshakeResult(encodedReply, coordinator, serverResult)
}

public func sshCompleteServerInitialHandshakeX25519Ed25519(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    hostPrivateKeySeed: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    serverPublicKey!: Array<Byte> = []
): SshServerInitialHandshakeResult {
    let signingArtifacts = sshPrepareServerSigningArtifactsX25519(
        serverPrivateKey,
        encodedClientInit,
        serverPublicKey: serverPublicKey
    )
    let serverHostKey = sshBuildEd25519HostKeyBlobFromSeed(hostPrivateKeySeed)
    let exchangeHash = sshComputeExchangeHashSha256(
        transcript,
        serverHostKey,
        signingArtifacts.clientEphemeralPublicKey,
        signingArtifacts.serverEphemeralPublicKey,
        signingArtifacts.sharedSecret
    )
    let hostSignature = sshSignExchangeHashEd25519(hostPrivateKeySeed, exchangeHash)
    let (encodedReply, serverResult) = sshBuildServerProcessKexEcdhInitResultX25519(
        transcript,
        signingArtifacts.clientEphemeralPublicKey,
        signingArtifacts.serverEphemeralPublicKey,
        signingArtifacts.sharedSecret,
        serverHostKey,
        hostSignature
    )
    let coordinator = sshCompleteInitialHandshakeCoordinatorX25519(
        SshPeerRole.Server,
        serverResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys
    )
    SshServerInitialHandshakeResult(encodedReply, coordinator, serverResult)
}

public func sshCompleteServerInitialHandshakeCoordinatorX25519(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    serverHostKey: Array<Byte>,
    hostSignature: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    serverPublicKey!: Array<Byte> = []
): (Array<Byte>, SshHandshakeCoordinator) {
    let completed = sshCompleteServerInitialHandshakeX25519(
        transcript,
        serverPrivateKey,
        encodedClientInit,
        serverHostKey,
        hostSignature,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys,
        serverPublicKey: serverPublicKey
    )
    (completed.encodedReply, completed.coordinator)
}

public func sshCompleteClientInitialHandshakeX25519(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>
): SshClientInitialHandshakeResult {
    let clientResult = sshClientProcessKexEcdhReplyX25519(
        transcript,
        clientPrivateKey,
        encodedClientInit,
        encodedServerReply
    )
    let coordinator = sshCompleteInitialHandshakeCoordinatorX25519(
        SshPeerRole.Client,
        clientResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys
    )
    SshClientInitialHandshakeResult(coordinator, clientResult)
}

public func sshCompleteClientInitialHandshakeX25519Verified(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
): SshClientInitialHandshakeResult {
    let clientResult = sshClientProcessKexEcdhReplyX25519(
        transcript,
        clientPrivateKey,
        encodedClientInit,
        encodedServerReply
    )
    let coordinator = sshCompleteInitialHandshakeCoordinatorX25519Verified(
        SshPeerRole.Client,
        clientResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys,
        policy: policy
    )
    SshClientInitialHandshakeResult(coordinator, clientResult, hostVerification: Some(coordinator.hostVerification()))
}

public func sshCompleteClientInitialHandshakeX25519WithHostVerificationRequirement(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy(),
    requireVerifiedHost!: Bool = true
): SshClientInitialHandshakeResult {
    let clientResult = sshClientProcessKexEcdhReplyX25519(
        transcript,
        clientPrivateKey,
        encodedClientInit,
        encodedServerReply
    )
    let coordinator = sshCompleteInitialHandshakeCoordinatorX25519WithHostVerificationRequirement(
        SshPeerRole.Client,
        clientResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys,
        policy: policy,
        requireVerifiedHost: requireVerifiedHost
    )
    SshClientInitialHandshakeResult(
        coordinator,
        clientResult,
        hostVerification: sshTryReadHostVerification(coordinator)
    )
}

public func sshCompleteClientInitialHandshakeX25519WithHostVerificationConfig(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    config!: SshHostVerificationConfig = SshHostVerificationConfig()
): SshClientInitialHandshakeResult {
    let clientResult = sshClientProcessKexEcdhReplyX25519(
        transcript,
        clientPrivateKey,
        encodedClientInit,
        encodedServerReply
    )
    let coordinator = sshCompleteInitialHandshakeCoordinatorX25519WithHostVerificationConfig(
        SshPeerRole.Client,
        clientResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys,
        config: config
    )
    SshClientInitialHandshakeResult(
        coordinator,
        clientResult,
        hostVerification: sshTryReadHostVerification(coordinator)
    )
}

public func sshCompleteClientInitialHandshakeCoordinatorX25519(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>
): SshHandshakeCoordinator {
    let clientResult = sshClientProcessKexEcdhReplyX25519(
        transcript,
        clientPrivateKey,
        encodedClientInit,
        encodedServerReply
    )
    sshCompleteInitialHandshakeCoordinatorX25519(
        SshPeerRole.Client,
        clientResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys
    )
}

public func sshCompleteClientInitialHandshakeCoordinatorX25519Verified(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
): SshHandshakeCoordinator {
    let clientResult = sshClientProcessKexEcdhReplyX25519(
        transcript,
        clientPrivateKey,
        encodedClientInit,
        encodedServerReply
    )
    sshCompleteInitialHandshakeCoordinatorX25519Verified(
        SshPeerRole.Client,
        clientResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys,
        policy: policy
    )
}

public func sshCompleteClientInitialHandshakeCoordinatorX25519WithHostVerificationRequirement(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy(),
    requireVerifiedHost!: Bool = true
): SshHandshakeCoordinator {
    let clientResult = sshClientProcessKexEcdhReplyX25519(
        transcript,
        clientPrivateKey,
        encodedClientInit,
        encodedServerReply
    )
    sshCompleteInitialHandshakeCoordinatorX25519WithHostVerificationRequirement(
        SshPeerRole.Client,
        clientResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys,
        policy: policy,
        requireVerifiedHost: requireVerifiedHost
    )
}

public func sshCompleteClientInitialHandshakeCoordinatorX25519WithHostVerificationConfig(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    negotiated: SshNegotiatedAlgorithms,
    encodedClientNewKeys: Array<Byte>,
    encodedServerNewKeys: Array<Byte>,
    config!: SshHostVerificationConfig = SshHostVerificationConfig()
): SshHandshakeCoordinator {
    let clientResult = sshClientProcessKexEcdhReplyX25519(
        transcript,
        clientPrivateKey,
        encodedClientInit,
        encodedServerReply
    )
    sshCompleteInitialHandshakeCoordinatorX25519WithHostVerificationConfig(
        SshPeerRole.Client,
        clientResult,
        negotiated,
        encodedClientNewKeys,
        encodedServerNewKeys,
        config: config
    )
}

private func sshTryReadHostVerification(
    coordinator: SshHandshakeCoordinator
): ?SshHostVerificationResult {
    try {
        return Some(coordinator.hostVerification())
    } catch (e: CryptoException) {
        if (e.code == ParseError) {
            return None
        }
        throw e
    }
}

private class SshServerSigningArtifactsX25519 {
    let clientEphemeralPublicKey: Array<Byte>
    let serverEphemeralPublicKey: Array<Byte>
    let sharedSecret: Array<Byte>

    init(
        clientEphemeralPublicKey: Array<Byte>,
        serverEphemeralPublicKey: Array<Byte>,
        sharedSecret: Array<Byte>
    ) {
        this.clientEphemeralPublicKey = clientEphemeralPublicKey.clone()
        this.serverEphemeralPublicKey = serverEphemeralPublicKey.clone()
        this.sharedSecret = sharedSecret.clone()
    }
}

private func sshPrepareServerSigningArtifactsX25519(
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    serverPublicKey!: Array<Byte> = []
): SshServerSigningArtifactsX25519 {
    let initMessage = sshDecodeKexEcdhInit(encodedClientInit)
    let effectiveServerPublicKey = if (serverPublicKey.size == 0) {
        x25519PublicFromPrivate(serverPrivateKey)
    } else {
        x25519ValidatePublicKey(serverPublicKey)
        serverPublicKey.clone()
    }
    let sharedSecret = x25519DeriveSharedSecret(serverPrivateKey, initMessage.clientEphemeralPublicKey)
    SshServerSigningArtifactsX25519(
        initMessage.clientEphemeralPublicKey,
        effectiveServerPublicKey,
        sharedSecret
    )
}

private func sshBuildServerProcessKexEcdhInitResultX25519(
    transcript: SshKexExchangeTranscript,
    clientEphemeralPublicKey: Array<Byte>,
    serverEphemeralPublicKey: Array<Byte>,
    sharedSecret: Array<Byte>,
    serverHostKey: Array<Byte>,
    hostSignature: Array<Byte>
): (Array<Byte>, SshX25519KexResult) {
    let exchangeHash = sshComputeExchangeHashSha256(
        transcript,
        serverHostKey,
        clientEphemeralPublicKey,
        serverEphemeralPublicKey,
        sharedSecret
    )
    let reply = sshEncodeKexEcdhReply(
        SshKexEcdhReplyMessage(serverHostKey, serverEphemeralPublicKey, hostSignature)
    )
    let result = SshX25519KexResult(
        sharedSecret,
        exchangeHash,
        exchangeHash,
        clientEphemeralPublicKey,
        serverEphemeralPublicKey,
        serverHostKey,
        hostSignature
    )
    (reply, result)
}

public func sshBuildKexEcdhInitX25519(clientPrivateKey: Array<Byte>): (Array<Byte>, Array<Byte>) {
    let clientPublicKey = x25519PublicFromPrivate(clientPrivateKey)
    let encodedInit = sshEncodeKexEcdhInit(SshKexEcdhInitMessage(clientPublicKey))
    (encodedInit, clientPublicKey)
}

public func sshServerProcessKexEcdhInitX25519(
    transcript: SshKexExchangeTranscript,
    serverPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    serverHostKey: Array<Byte>,
    hostSignature: Array<Byte>,
    serverPublicKey!: Array<Byte> = []
): (Array<Byte>, SshX25519KexResult) {
    let signingArtifacts = sshPrepareServerSigningArtifactsX25519(
        serverPrivateKey,
        encodedClientInit,
        serverPublicKey: serverPublicKey
    )
    sshBuildServerProcessKexEcdhInitResultX25519(
        transcript,
        signingArtifacts.clientEphemeralPublicKey,
        signingArtifacts.serverEphemeralPublicKey,
        signingArtifacts.sharedSecret,
        serverHostKey,
        hostSignature
    )
}

/**
 * sshClientProcessKexEcdhReplyX25519.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshClientProcessKexEcdhReplyX25519(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>
): SshX25519KexResult {
    let initMessage = sshDecodeKexEcdhInit(encodedClientInit)
    let expectedClientPublicKey = x25519PublicFromPrivate(clientPrivateKey)
    if (!constantTimeEquals(initMessage.clientEphemeralPublicKey, expectedClientPublicKey)) {
        throw CryptoException(InvalidArgument, "SSH client private key does not match encoded SSH_MSG_KEX_ECDH_INIT")
    }

    let replyMessage = sshDecodeKexEcdhReply(encodedServerReply)
    let sharedSecret = x25519DeriveSharedSecret(clientPrivateKey, replyMessage.serverEphemeralPublicKey)
    let exchangeHash = sshComputeExchangeHashSha256(
        transcript,
        replyMessage.serverHostKey,
        initMessage.clientEphemeralPublicKey,
        replyMessage.serverEphemeralPublicKey,
        sharedSecret
    )
    SshX25519KexResult(
        sharedSecret,
        exchangeHash,
        exchangeHash,
        initMessage.clientEphemeralPublicKey,
        replyMessage.serverEphemeralPublicKey,
        replyMessage.serverHostKey,
        replyMessage.signature
    )
}

public func sshClientProcessKexEcdhReplyX25519Verified(
    transcript: SshKexExchangeTranscript,
    clientPrivateKey: Array<Byte>,
    encodedClientInit: Array<Byte>,
    encodedServerReply: Array<Byte>,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
): SshX25519KexResult {
    let result = sshClientProcessKexEcdhReplyX25519(
        transcript,
        clientPrivateKey,
        encodedClientInit,
        encodedServerReply
    )
    _ = sshRequireVerifiedHostIdentity(result, policy: policy)
    result
}

/**
 * sshComputeHostKeySha256.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshComputeHostKeySha256(serverHostKey: Array<Byte>): Array<Byte> {
    if (serverHostKey.size == 0) {
        throw CryptoException(InvalidArgument, "SSH host key blob must not be empty")
    }
    sha256(serverHostKey)
}

/**
 * sshRequireVerifiedHostIdentity.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshRequireVerifiedHostIdentity(
    kexResult: SshX25519KexResult,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
): SshHostVerificationResult {
    let hostKeyAlgorithm = sshExtractHostKeyAlgorithm(kexResult.serverHostKey)
    let hostSignatureAlgorithm = sshExtractHostSignatureAlgorithm(kexResult.hostSignature)
    let hostKeySha256 = sshComputeHostKeySha256(kexResult.serverHostKey)

    if (policy.expectedHostKeySha256.size != 0) {
        if (!constantTimeEquals(policy.expectedHostKeySha256, hostKeySha256)) {
            if (policy.requireKnownHost) {
                throw CryptoException(ParseError, "SSH known-host fingerprint verification failed")
            }
        }
    }

    var signatureVerified = false
    if (policy.requireHostSignature) {
        signatureVerified = sshVerifyServerHostSignatureFromKexResult(
            kexResult,
            negotiatedHostKeyAlgorithm: policy.negotiatedHostKeyAlgorithm,
            allowLegacyRsaSha1: policy.allowLegacyRsaSha1
        )
        if (!signatureVerified) {
            throw CryptoException(ParseError, "SSH server host signature verification failed")
        }
    }

    SshHostVerificationResult(
        hostKeyAlgorithm,
        hostSignatureAlgorithm,
        hostKeySha256,
        signatureVerified
    )
}

/**
 * sshVerifyHostIdentityWithRequirement.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshVerifyHostIdentityWithRequirement(
    kexResult: SshX25519KexResult,
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy(),
    requireVerifiedHost!: Bool = true
): ?SshHostVerificationResult {
    if (requireVerifiedHost) {
        return Some(sshRequireVerifiedHostIdentity(kexResult, policy: policy))
    }

    try {
        return Some(sshRequireVerifiedHostIdentity(kexResult, policy: policy))
    } catch (e: CryptoException) {
        if (e.code == ParseError || e.code == Unsupported) {
            return None
        }
        throw e
    }
}

public func sshVerifyHostIdentityWithConfig(
    kexResult: SshX25519KexResult,
    config!: SshHostVerificationConfig = SshHostVerificationConfig()
): ?SshHostVerificationResult {
    sshVerifyHostIdentityWithRequirement(
        kexResult,
        policy: config.policy,
        requireVerifiedHost: config.requireVerifiedHost
    )
}

public func sshHostVerificationConfigRequired(
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
): SshHostVerificationConfig {
    SshHostVerificationConfig(policy: policy, requireVerifiedHost: true)
}

public func sshHostVerificationConfigOptional(
    policy!: SshHostVerificationPolicy = SshHostVerificationPolicy()
): SshHostVerificationConfig {
    SshHostVerificationConfig(policy: policy, requireVerifiedHost: false)
}

public func sshVerifyServerHostSignatureFromKexResult(
    kexResult: SshX25519KexResult,
    negotiatedHostKeyAlgorithm!: String = "",
    allowLegacyRsaSha1!: Bool = false
): Bool {
    sshVerifyServerHostSignature(
        kexResult.exchangeHash,
        kexResult.serverHostKey,
        kexResult.hostSignature,
        negotiatedHostKeyAlgorithm: negotiatedHostKeyAlgorithm,
        allowLegacyRsaSha1: allowLegacyRsaSha1
    )
}

public func sshExtractHostKeyAlgorithm(serverHostKey: Array<Byte>): String {
    sshDecodeHostKeyAlgorithm(serverHostKey)
}

public func sshExtractHostSignatureAlgorithm(hostSignature: Array<Byte>): String {
    let (algorithm, _) = sshDecodeHostSignature(hostSignature)
    algorithm
}

public func sshEncodeRsaHostPublicKey(publicKey: RsaPublicKey): Array<Byte> {
    let out = ArrayList<Byte>()
    appendString(out, SSH_HOST_KEY_ALGORITHM_RSA.toArray())
    appendString(out, sshEncodePositiveMpint(publicKey.exponent.toBytesBE()))
    appendString(out, sshEncodePositiveMpint(publicKey.modulus.toBytesBE()))
    out.toArray()
}

/**
 * sshEncodeRsaHostSignature.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshEncodeRsaHostSignature(signatureAlgorithm: String, signature: Array<Byte>): Array<Byte> {
    let normalized = sshNormalizeRsaHostSignatureAlgorithm(signatureAlgorithm)
    if (signature.size == 0) {
        throw CryptoException(InvalidArgument, "SSH RSA host signature must not be empty")
    }

    let out = ArrayList<Byte>()
    appendString(out, normalized.toArray())
    appendString(out, signature)
    out.toArray()
}

/**
 * sshSignExchangeHashRsa.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshSignExchangeHashRsa(
    privateKey: RsaPrivateKey,
    exchangeHash: Array<Byte>,
    signatureAlgorithm!: String = SSH_HOST_KEY_ALGORITHM_RSA_SHA256
): Array<Byte> {
    if (exchangeHash.size == 0) {
        throw CryptoException(InvalidArgument, "SSH exchange hash must not be empty")
    }

    let normalized = sshNormalizeRsaHostSignatureAlgorithm(signatureAlgorithm)
    let digest = if (normalized == SSH_HOST_KEY_ALGORITHM_RSA) {
        sha1(exchangeHash)
    } else if (normalized == SSH_HOST_KEY_ALGORITHM_RSA_SHA256) {
        sha256(exchangeHash)
    } else {
        sha512(exchangeHash)
    }
    let hashAlgorithm = if (normalized == SSH_HOST_KEY_ALGORITHM_RSA) {
        RsaHashAlgorithm.SHA1
    } else if (normalized == SSH_HOST_KEY_ALGORITHM_RSA_SHA256) {
        RsaHashAlgorithm.SHA256
    } else {
        RsaHashAlgorithm.SHA512
    }
    sshEncodeRsaHostSignature(normalized, rsaSignPkcs1v15WithHash(privateKey, digest, hashAlgorithm))
}

public func sshEncodeEcdsaHostPublicKey(publicKey: EcPublicKey): Array<Byte> {
    let (algorithm, curveName, fieldLen) = sshEcdsaCurveEncoding(publicKey.curve)
    let encodedPoint = sshEncodeEcdsaUncompressedPoint(publicKey, fieldLen)
    let out = ArrayList<Byte>()
    appendString(out, algorithm.toArray())
    appendString(out, curveName.toArray())
    appendString(out, encodedPoint)
    out.toArray()
}

public func sshEncodeEcdsaHostSignature(curve: NamedCurve, r: BigNum, s: BigNum): Array<Byte> {
    let (algorithm, _curveName, _fieldLen) = sshEcdsaCurveEncoding(curve)
    let signaturePair = ArrayList<Byte>()
    appendString(signaturePair, sshEncodePositiveMpint(r.toBytesBE()))
    appendString(signaturePair, sshEncodePositiveMpint(s.toBytesBE()))

    let out = ArrayList<Byte>()
    appendString(out, algorithm.toArray())
    appendString(out, signaturePair.toArray())
    out.toArray()
}

/**
 * sshSignExchangeHashEcdsa.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshSignExchangeHashEcdsa(privateKey: EcPrivateKey, exchangeHash: Array<Byte>): Array<Byte> {
    if (exchangeHash.size == 0) {
        throw CryptoException(InvalidArgument, "SSH exchange hash must not be empty")
    }

    let digest = match (privateKey.curve) {
        case NamedCurve.P256 => sha256(exchangeHash)
        case NamedCurve.P384 => sha384(exchangeHash)
        case _ =>
            throw CryptoException(Unsupported, "SSH ECDSA host signature curve is unsupported: ${privateKey.curve.toString()}")
    }
    let (r, s) = ecdsaSign(privateKey, digest)
    sshEncodeEcdsaHostSignature(privateKey.curve, r, s)
}

/**
 * sshEncodeEd25519HostPublicKey.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshEncodeEd25519HostPublicKey(publicKey: Array<Byte>): Array<Byte> {
    if (publicKey.size != ED25519_PUBLIC_KEY_LEN) {
        throw CryptoException(InvalidArgument, "SSH ed25519 host public key must be 32 bytes")
    }

    let out = ArrayList<Byte>()
    appendString(out, SSH_HOST_KEY_ALGORITHM_ED25519.toArray())
    appendString(out, publicKey)
    out.toArray()
}

public func sshBuildEd25519HostKeyBlobFromSeed(privateKeySeed: Array<Byte>): Array<Byte> {
    sshEncodeEd25519HostPublicKey(ed25519PublicKeyFromSeed(privateKeySeed))
}

/**
 * sshEncodeEd25519HostSignature.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshEncodeEd25519HostSignature(signature: Array<Byte>): Array<Byte> {
    if (signature.size != ED25519_SIGNATURE_LEN) {
        throw CryptoException(InvalidArgument, "SSH ed25519 host signature must be 64 bytes")
    }

    let out = ArrayList<Byte>()
    appendString(out, SSH_HOST_KEY_ALGORITHM_ED25519.toArray())
    appendString(out, signature)
    out.toArray()
}

/**
 * sshSignExchangeHashEd25519.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshSignExchangeHashEd25519(privateKeySeed: Array<Byte>, exchangeHash: Array<Byte>): Array<Byte> {
    if (exchangeHash.size == 0) {
        throw CryptoException(InvalidArgument, "SSH exchange hash must not be empty")
    }
    sshEncodeEd25519HostSignature(ed25519Sign(privateKeySeed, exchangeHash))
}

/**
 * sshVerifyServerHostSignature.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshVerifyServerHostSignature(
    exchangeHash: Array<Byte>,
    serverHostKey: Array<Byte>,
    hostSignature: Array<Byte>,
    negotiatedHostKeyAlgorithm!: String = "",
    allowLegacyRsaSha1!: Bool = false
): Bool {
    if (exchangeHash.size == 0) {
        throw CryptoException(InvalidArgument, "SSH exchange hash must not be empty")
    }

    let hostAlgorithm = sshDecodeHostKeyAlgorithm(serverHostKey)
    let (signatureAlgorithm, signatureData) = sshDecodeHostSignature(hostSignature)
    let negotiated = negotiatedHostKeyAlgorithm.trimAscii().toAsciiLower()
    if (
        negotiated.size != 0 &&
        !sshSignatureMatchesNegotiatedHostKey(negotiated, hostAlgorithm, signatureAlgorithm)
    ) {
        return false
    }

    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA256) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_RSA) {
            return false
        }
        let publicKey = sshDecodeRsaHostPublicKey(serverHostKey)
        let digest = sha256(exchangeHash)
        return rsaVerifyPkcs1v15WithHash(publicKey, digest, signatureData, RsaHashAlgorithm.SHA256)
    }
    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA512) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_RSA) {
            return false
        }
        let publicKey = sshDecodeRsaHostPublicKey(serverHostKey)
        let digest = sha512(exchangeHash)
        return rsaVerifyPkcs1v15WithHash(publicKey, digest, signatureData, RsaHashAlgorithm.SHA512)
    }
    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256) {
            return false
        }
        let publicKey = sshDecodeEcdsaP256HostPublicKey(serverHostKey)
        let (r, s) = sshDecodeEcdsaSignature(signatureData)
        let digest = sha256(exchangeHash)
        return ecdsaVerify(publicKey, digest, r, s)
    }
    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384) {
            return false
        }
        let publicKey = sshDecodeEcdsaP384HostPublicKey(serverHostKey)
        let (r, s) = sshDecodeEcdsaSignature(signatureData)
        let digest = sha384(exchangeHash)
        return ecdsaVerify(publicKey, digest, r, s)
    }
    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ED25519) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_ED25519) {
            return false
        }
        let publicKey = sshDecodeEd25519HostPublicKey(serverHostKey)
        let signature = sshDecodeEd25519HostSignature(signatureData)
        return ed25519Verify(publicKey, exchangeHash, signature)
    }
    if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA) {
        if (hostAlgorithm != SSH_HOST_KEY_ALGORITHM_RSA) {
            return false
        }
        if (!allowLegacyRsaSha1) {
            throw CryptoException(Unsupported, "SSH rsa-sha1 host signature verify is blocked")
        }
        let publicKey = sshDecodeRsaHostPublicKey(serverHostKey)
        let digest = sha1(exchangeHash)
        return rsaVerifyPkcs1v15WithHash(publicKey, digest, signatureData, RsaHashAlgorithm.SHA1)
    }
    throw CryptoException(Unsupported, "SSH host signature algorithm is unsupported: ${signatureAlgorithm}")
}

/**
 * sshComputeExchangeHashSha256.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshComputeExchangeHashSha256(
    transcript: SshKexExchangeTranscript,
    serverHostKey: Array<Byte>,
    clientEphemeralPublicKey: Array<Byte>,
    serverEphemeralPublicKey: Array<Byte>,
    sharedSecret: Array<Byte>
): Array<Byte> {
    if (serverHostKey.size == 0) {
        throw CryptoException(InvalidArgument, "SSH exchange hash requires non-empty server host key blob")
    }
    x25519ValidatePublicKey(clientEphemeralPublicKey)
    x25519ValidatePublicKey(serverEphemeralPublicKey)
    if (sharedSecret.size != X25519_SHARED_SECRET_LEN) {
        throw CryptoException(InvalidArgument, "SSH exchange hash shared secret length is invalid")
    }

    let clientBanner = normalizeBannerForHash(transcript.clientBannerLine, "client")
    let serverBanner = normalizeBannerForHash(transcript.serverBannerLine, "server")
    let payload = ArrayList<Byte>()
    appendString(payload, clientBanner)
    appendString(payload, serverBanner)
    appendString(payload, transcript.clientKexInitPayload)
    appendString(payload, transcript.serverKexInitPayload)
    appendString(payload, serverHostKey)
    appendString(payload, clientEphemeralPublicKey)
    appendString(payload, serverEphemeralPublicKey)
    appendString(payload, sharedSecret)
    sha256(payload.toArray())
}

public func sshEncodeKexInit(message: SshKexInitMessage): Array<Byte> {
    let out = ArrayList<Byte>()
    out.add(UInt8(SSH_MSG_KEXINIT))
    appendBytes(out, message.cookie)
    appendNameList(out, message.kexAlgorithms)
    appendNameList(out, message.serverHostKeyAlgorithms)
    appendNameList(out, message.encryptionAlgorithmsClientToServer)
    appendNameList(out, message.encryptionAlgorithmsServerToClient)
    appendNameList(out, message.macAlgorithmsClientToServer)
    appendNameList(out, message.macAlgorithmsServerToClient)
    appendNameList(out, message.compressionAlgorithmsClientToServer)
    appendNameList(out, message.compressionAlgorithmsServerToClient)
    appendNameList(out, message.languagesClientToServer)
    appendNameList(out, message.languagesServerToClient)
    out.add(if (message.firstKexPacketFollows) { UInt8(0x01) } else { UInt8(0x00) })
    appendUInt32(out, message.reserved)
    out.toArray()
}

/**
 * sshDecodeKexInit.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshDecodeKexInit(encoded: Array<Byte>): SshKexInitMessage {
    if (encoded.size < 62) {
        throw CryptoException(ParseError, "SSH KEXINIT payload is too short")
    }
    if (Int64(UInt8(encoded[0])) != SSH_MSG_KEXINIT) {
        throw CryptoException(ParseError, "SSH packet is not KEXINIT")
    }

    var offset = 1
    let cookie = encoded[offset..(offset + 16)]
    offset += 16

    let (kexAlgorithms, kexOffset) = decodeNameList(encoded, offset, "kex_algorithms")
    offset = kexOffset
    let (serverHostKeyAlgorithms, hostOffset) = decodeNameList(encoded, offset, "server_host_key_algorithms")
    offset = hostOffset
    let (encC2s, encC2sOffset) = decodeNameList(encoded, offset, "encryption_algorithms_client_to_server")
    offset = encC2sOffset
    let (encS2c, encS2cOffset) = decodeNameList(encoded, offset, "encryption_algorithms_server_to_client")
    offset = encS2cOffset
    let (macC2s, macC2sOffset) = decodeNameList(encoded, offset, "mac_algorithms_client_to_server")
    offset = macC2sOffset
    let (macS2c, macS2cOffset) = decodeNameList(encoded, offset, "mac_algorithms_server_to_client")
    offset = macS2cOffset
    let (compC2s, compC2sOffset) = decodeNameList(encoded, offset, "compression_algorithms_client_to_server")
    offset = compC2sOffset
    let (compS2c, compS2cOffset) = decodeNameList(encoded, offset, "compression_algorithms_server_to_client")
    offset = compS2cOffset
    let (langC2s, langC2sOffset) = decodeNameList(encoded, offset, "languages_client_to_server")
    offset = langC2sOffset
    let (langS2c, langS2cOffset) = decodeNameList(encoded, offset, "languages_server_to_client")
    offset = langS2cOffset

    if (offset + 5 != encoded.size) {
        throw CryptoException(ParseError, "SSH KEXINIT trailing bytes are invalid")
    }
    let firstKexPacketFollows = UInt8(encoded[offset]) == UInt8(0x01)
    offset += 1
    let reserved = decodeUInt32(encoded, offset, "reserved")
    offset += 4

    if (offset != encoded.size) {
        throw CryptoException(ParseError, "SSH KEXINIT parse did not consume payload")
    }

    SshKexInitMessage(
        cookie,
        kexAlgorithms,
        serverHostKeyAlgorithms,
        encC2s,
        encS2c,
        macC2s,
        macS2c,
        compC2s,
        compS2c,
        languagesClientToServer: langC2s,
        languagesServerToClient: langS2c,
        firstKexPacketFollows: firstKexPacketFollows,
        reserved: reserved
    )
}

public func sshNegotiateKexInit(client: SshKexInitMessage, server: SshKexInitMessage): SshNegotiatedAlgorithms {
    let kexAlgorithm = selectAlgorithm(server.kexAlgorithms, client.kexAlgorithms, "kex")
    let hostKeyAlgorithm = selectAlgorithm(
        server.serverHostKeyAlgorithms,
        client.serverHostKeyAlgorithms,
        "host key"
    )
    let encC2s = selectAlgorithm(
        server.encryptionAlgorithmsClientToServer,
        client.encryptionAlgorithmsClientToServer,
        "client_to_server cipher"
    )
    let encS2c = selectAlgorithm(
        server.encryptionAlgorithmsServerToClient,
        client.encryptionAlgorithmsServerToClient,
        "server_to_client cipher"
    )
    let macC2s = selectAlgorithm(
        server.macAlgorithmsClientToServer,
        client.macAlgorithmsClientToServer,
        "client_to_server MAC"
    )
    let macS2c = selectAlgorithm(
        server.macAlgorithmsServerToClient,
        client.macAlgorithmsServerToClient,
        "server_to_client MAC"
    )
    let compC2s = selectAlgorithm(
        server.compressionAlgorithmsClientToServer,
        client.compressionAlgorithmsClientToServer,
        "client_to_server compression"
    )
    let compS2c = selectAlgorithm(
        server.compressionAlgorithmsServerToClient,
        client.compressionAlgorithmsServerToClient,
        "server_to_client compression"
    )
    SshNegotiatedAlgorithms(kexAlgorithm, hostKeyAlgorithm, encC2s, encS2c, macC2s, macS2c, compC2s, compS2c)
}

/**
 * sshEncodeTransportPacket.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshEncodeTransportPacket(
    payload: Array<Byte>,
    blockSize!: Int64 = SSH_DEFAULT_PACKET_BLOCK_SIZE,
    randomPadding!: Array<Byte> = []
): Array<Byte> {
    validatePacketBlockSize(blockSize)
    if (payload.size > 0xffff_ffff - 256) {
        throw CryptoException(OutOfBounds, "SSH payload is too large")
    }

    var paddingLen = SSH_MIN_PACKET_PADDING_LEN
    while (((payload.size + 1 + paddingLen) % blockSize) != 0) {
        paddingLen += 1
    }
    if (paddingLen > 255) {
        throw CryptoException(OutOfBounds, "SSH packet padding exceeds uint8 length")
    }

    let packetLength = payload.size + 1 + paddingLen
    if (packetLength > 0xffff_ffff) {
        throw CryptoException(OutOfBounds, "SSH packet length exceeds uint32")
    }

    let encoded = Array<Byte>(4 + packetLength, repeat: 0)
    encodeUInt32(encoded, 0, packetLength)
    encoded[4] = UInt8(paddingLen)
    secureCopyInto(payload, encoded, dstOffset: 5)

    let padding = if (randomPadding.size == 0) {
        randomSeed(size: paddingLen)
    } else {
        if (randomPadding.size < paddingLen) {
            throw CryptoException(InvalidArgument, "SSH random padding is shorter than required padding length")
        }
        randomPadding[0..paddingLen]
    }
    secureCopyInto(padding, encoded, dstOffset: 5 + payload.size)
    encoded
}

/**
 * sshDecodeTransportPacket.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sshDecodeTransportPacket(
    encoded: Array<Byte>,
    blockSize!: Int64 = SSH_DEFAULT_PACKET_BLOCK_SIZE
): SshTransportPacket {
    validatePacketBlockSize(blockSize)
    if (encoded.size < 5) {
        throw CryptoException(ParseError, "SSH packet is too short")
    }
    let packetLength = decodeUInt32(encoded, 0, "packet_length")
    if (packetLength < 1 + SSH_MIN_PACKET_PADDING_LEN) {
        throw CryptoException(ParseError, "SSH packet_length is too short")
    }
    if (encoded.size != 4 + packetLength) {
        throw CryptoException(ParseError, "SSH packet_length does not match encoded size")
    }
    if ((packetLength % blockSize) != 0) {
        throw CryptoException(ParseError, "SSH packet_length is not block aligned")
    }

    let paddingLen = Int64(UInt8(encoded[4]))
    if (paddingLen < SSH_MIN_PACKET_PADDING_LEN || paddingLen >= packetLength) {
        throw CryptoException(ParseError, "SSH packet padding length is invalid")
    }
    let payloadLen = packetLength - 1 - paddingLen
    let payload = encoded[5..(5 + payloadLen)]
    let padding = encoded[(5 + payloadLen)..]
    SshTransportPacket(payload, padding, packetLength)
}

private func sshDecodeHostKeyAlgorithm(serverHostKey: Array<Byte>): String {
    let (algorithmBytes, _) = decodeString(serverHostKey, 0, "host key algorithm")
    sshDecodeAlgorithmToken(algorithmBytes, "host key algorithm")
}

private func sshDecodeHostSignature(hostSignature: Array<Byte>): (String, Array<Byte>) {
    let (algorithmBytes, offset) = decodeString(hostSignature, 0, "host signature algorithm")
    let algorithm = sshDecodeAlgorithmToken(algorithmBytes, "host signature algorithm")
    let (signatureData, nextOffset) = decodeString(hostSignature, offset, "host signature data")
    if (nextOffset != hostSignature.size) {
        throw CryptoException(ParseError, "SSH host signature blob has trailing bytes")
    }
    (algorithm, signatureData)
}

private func sshDecodeRsaHostPublicKey(serverHostKey: Array<Byte>): RsaPublicKey {
    let (algorithmBytes, offset) = decodeString(serverHostKey, 0, "host key algorithm")
    let algorithm = sshDecodeAlgorithmToken(algorithmBytes, "host key algorithm")
    if (algorithm != SSH_HOST_KEY_ALGORITHM_RSA) {
        throw CryptoException(ParseError, "SSH RSA host key blob algorithm mismatch: ${algorithm}")
    }

    let (exponentBytes, exponentOffset) = sshDecodePositiveMpint(serverHostKey, offset, "host key exponent")
    let (modulusBytes, nextOffset) = sshDecodePositiveMpint(serverHostKey, exponentOffset, "host key modulus")
    if (nextOffset != serverHostKey.size) {
        throw CryptoException(ParseError, "SSH RSA host key blob has trailing bytes")
    }
    if (exponentBytes.size == 0 || modulusBytes.size == 0) {
        throw CryptoException(ParseError, "SSH RSA host key requires non-zero modulus/exponent")
    }

    let exponent = sshUnsignedBigNumFromBytes(exponentBytes)
    let modulus = sshUnsignedBigNumFromBytes(modulusBytes)
    RsaPublicKey(modulus, exponent)
}

private func sshDecodeEcdsaP256HostPublicKey(serverHostKey: Array<Byte>): EcPublicKey {
    sshDecodeEcdsaHostPublicKey(
        serverHostKey,
        SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256,
        "nistp256",
        P256,
        SSH_P256_FIELD_LEN
    )
}

private func sshDecodeEcdsaP384HostPublicKey(serverHostKey: Array<Byte>): EcPublicKey {
    sshDecodeEcdsaHostPublicKey(
        serverHostKey,
        SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384,
        "nistp384",
        P384,
        SSH_P384_FIELD_LEN
    )
}

private func sshDecodeEcdsaHostPublicKey(
    serverHostKey: Array<Byte>,
    expectedAlgorithm: String,
    expectedCurveName: String,
    curve: NamedCurve,
    fieldLen: Int64
): EcPublicKey {
    let (algorithmBytes, offset) = decodeString(serverHostKey, 0, "host key algorithm")
    let algorithm = sshDecodeAlgorithmToken(algorithmBytes, "host key algorithm")
    if (algorithm != expectedAlgorithm) {
        throw CryptoException(ParseError, "SSH ECDSA host key blob algorithm mismatch: ${algorithm}")
    }

    let (curveNameBytes, curveOffset) = decodeString(serverHostKey, offset, "host key curve name")
    let curveName = sshDecodeAlgorithmToken(curveNameBytes, "host key curve name")
    if (curveName != expectedCurveName) {
        throw CryptoException(Unsupported, "SSH ECDSA host key curve is unsupported: ${curveName}")
    }

    let (encodedPoint, nextOffset) = decodeString(serverHostKey, curveOffset, "host key EC point")
    if (nextOffset != serverHostKey.size) {
        throw CryptoException(ParseError, "SSH ECDSA host key blob has trailing bytes")
    }
    if (encodedPoint.size != 1 + fieldLen * 2 || UInt8(encodedPoint[0]) != UInt8(0x04)) {
        throw CryptoException(ParseError, "SSH ECDSA host key point must be uncompressed")
    }

    let x = BigNum.fromBytesBE(encodedPoint[1..(1 + fieldLen)])
    let y = BigNum.fromBytesBE(encodedPoint[(1 + fieldLen)..])
    EcPublicKey(curve, x, y)
}

private func sshDecodeEd25519HostPublicKey(serverHostKey: Array<Byte>): Array<Byte> {
    let (algorithmBytes, offset) = decodeString(serverHostKey, 0, "host key algorithm")
    let algorithm = sshDecodeAlgorithmToken(algorithmBytes, "host key algorithm")
    if (algorithm != SSH_HOST_KEY_ALGORITHM_ED25519) {
        throw CryptoException(ParseError, "SSH ed25519 host key blob algorithm mismatch: ${algorithm}")
    }
    let (publicKey, nextOffset) = decodeString(serverHostKey, offset, "host key ed25519 public key")
    if (nextOffset != serverHostKey.size) {
        throw CryptoException(ParseError, "SSH ed25519 host key blob has trailing bytes")
    }
    if (publicKey.size != 32) {
        throw CryptoException(ParseError, "SSH ed25519 host key public key must be 32 bytes")
    }
    publicKey
}

private func sshDecodeEd25519HostSignature(signatureData: Array<Byte>): Array<Byte> {
    if (signatureData.size != 64) {
        throw CryptoException(ParseError, "SSH ed25519 host signature must be 64 bytes")
    }
    signatureData
}

private func sshDecodeEcdsaSignature(signatureData: Array<Byte>): (BigNum, BigNum) {
    let (rBytes, offset) = sshDecodePositiveMpint(signatureData, 0, "host signature r")
    let (sBytes, nextOffset) = sshDecodePositiveMpint(signatureData, offset, "host signature s")
    if (nextOffset != signatureData.size) {
        throw CryptoException(ParseError, "SSH ECDSA signature has trailing bytes")
    }
    (sshUnsignedBigNumFromBytes(rBytes), sshUnsignedBigNumFromBytes(sBytes))
}

private func sshDecodePositiveMpint(encoded: Array<Byte>, offset: Int64, label: String): (Array<Byte>, Int64) {
    let (rawValue, nextOffset) = decodeString(encoded, offset, label)
    if (rawValue.size == 0) {
        return ([], nextOffset)
    }
    if ((UInt8(rawValue[0]) & UInt8(0x80)) != UInt8(0x00)) {
        throw CryptoException(ParseError, "SSH ${label} must be non-negative mpint")
    }

    var start = 0
    while (
        start + 1 < rawValue.size &&
        UInt8(rawValue[start]) == UInt8(0x00) &&
        (UInt8(rawValue[start + 1]) & UInt8(0x80)) == UInt8(0x00)
    ) {
        start += 1
    }
    (rawValue[start..], nextOffset)
}

private func sshUnsignedBigNumFromBytes(data: Array<Byte>): BigNum {
    if (data.size == 0) {
        return BigNum.zero()
    }
    BigNum.fromBytesBE(data)
}

private func sshEncodePositiveMpint(unsigned: Array<Byte>): Array<Byte> {
    if (unsigned.size == 0) {
        return []
    }

    var start = 0
    while (start + 1 < unsigned.size && UInt8(unsigned[start]) == UInt8(0x00)) {
        start += 1
    }
    let trimmed = unsigned[start..]
    if (trimmed.size == 0) {
        return []
    }
    if ((UInt8(trimmed[0]) & UInt8(0x80)) != UInt8(0x00)) {
        let out = Array<Byte>(trimmed.size + 1, repeat: 0)
        var i = 0
        while (i < trimmed.size) {
            out[i + 1] = trimmed[i]
            i += 1
        }
        return out
    }
    trimmed
}

private func sshDecodeAlgorithmToken(raw: Array<Byte>, label: String): String {
    let token = String.fromUtf8(raw).trimAscii().toAsciiLower()
    if (token.size == 0) {
        throw CryptoException(ParseError, "SSH ${label} must not be empty")
    }
    if (token.contains(" ") || token.contains("\r") || token.contains("\n") || token.contains("\t")) {
        throw CryptoException(ParseError, "SSH ${label} contains invalid whitespace")
    }
    token
}

private func sshSignatureMatchesNegotiatedHostKey(
    negotiatedHostKeyAlgorithm: String,
    hostAlgorithm: String,
    signatureAlgorithm: String
): Bool {
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA256) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA256
    }
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA512) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA512
    }
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA
    }
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256 &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256
    }
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384 &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384
    }
    if (negotiatedHostKeyAlgorithm == SSH_HOST_KEY_ALGORITHM_ED25519) {
        return hostAlgorithm == SSH_HOST_KEY_ALGORITHM_ED25519 &&
            signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_ED25519
    }
    hostAlgorithm == negotiatedHostKeyAlgorithm &&
        signatureAlgorithm == negotiatedHostKeyAlgorithm
}

private func sshNormalizeRsaHostSignatureAlgorithm(signatureAlgorithm: String): String {
    let normalized = signatureAlgorithm.trimAscii().toAsciiLower()
    if (
        normalized != SSH_HOST_KEY_ALGORITHM_RSA &&
        normalized != SSH_HOST_KEY_ALGORITHM_RSA_SHA256 &&
        normalized != SSH_HOST_KEY_ALGORITHM_RSA_SHA512
    ) {
        throw CryptoException(Unsupported, "SSH RSA host signature algorithm is unsupported: ${signatureAlgorithm}")
    }
    normalized
}

private func sshEcdsaCurveEncoding(curve: NamedCurve): (String, String, Int64) {
    match (curve) {
        case NamedCurve.P256 => (SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256, "nistp256", SSH_P256_FIELD_LEN)
        case NamedCurve.P384 => (SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384, "nistp384", SSH_P384_FIELD_LEN)
        case _ =>
            throw CryptoException(Unsupported, "SSH ECDSA host key curve is unsupported: ${curve.toString()}")
    }
}

private func sshEncodeEcdsaUncompressedPoint(publicKey: EcPublicKey, fieldLen: Int64): Array<Byte> {
    let encodedPoint = Array<Byte>(1 + (fieldLen * 2), repeat: 0)
    encodedPoint[0] = UInt8(0x04)
    let x = publicKey.x.toBytesBE(paddedLen: fieldLen)
    let y = publicKey.y.toBytesBE(paddedLen: fieldLen)
    var i = 0
    while (i < fieldLen) {
        encodedPoint[1 + i] = x[i]
        encodedPoint[1 + fieldLen + i] = y[i]
        i += 1
    }
    encodedPoint
}

private func sshNormalizeNameList(
    names: Array<String>,
    fieldName: String,
    allowEmpty: Bool
): Array<String> {
    if (!allowEmpty && names.size == 0) {
        throw CryptoException(InvalidArgument, "SSH ${fieldName} must not be empty")
    }

    let normalized = ArrayList<String>()
    for (name in names) {
        let value = name.trimAscii()
        if (value.size == 0) {
            throw CryptoException(InvalidArgument, "SSH ${fieldName} contains an empty name")
        }
        if (value.contains(",") || value.contains(" ")) {
            throw CryptoException(InvalidArgument, "SSH ${fieldName} name is invalid: ${value}")
        }
        if (value.contains("\r") || value.contains("\n") || value.contains("\t")) {
            throw CryptoException(InvalidArgument, "SSH ${fieldName} name must be single token")
        }
        if (value.size > 255) {
            throw CryptoException(OutOfBounds, "SSH ${fieldName} name exceeds 255 bytes")
        }
        normalized.add(value)
    }
    if (!allowEmpty && normalized.size == 0) {
        throw CryptoException(InvalidArgument, "SSH ${fieldName} must not be empty")
    }
    normalized.toArray()
}

private func appendNameList(out: ArrayList<Byte>, names: Array<String>): Unit {
    if (names.size == 0) {
        appendUInt32(out, 0)
        return
    }
    let serialized = ArrayList<Byte>()
    var i = 0
    while (i < names.size) {
        if (i > 0) {
            serialized.add(UInt8(b','))
        }
        appendBytes(serialized, names[i].toArray())
        i += 1
    }
    appendUInt32(out, serialized.size)
    appendBytes(out, serialized.toArray())
}

private func decodeNameList(
    encoded: Array<Byte>,
    offset: Int64,
    fieldName: String
): (Array<String>, Int64) {
    let nameListLen = decodeUInt32(encoded, offset, fieldName)
    let cursor = offset + 4
    if (cursor + nameListLen > encoded.size) {
        throw CryptoException(ParseError, "SSH ${fieldName} exceeds packet bounds")
    }
    if (nameListLen == 0) {
        return ([], cursor)
    }

    let text = String.fromUtf8(encoded[cursor..(cursor + nameListLen)])
    let parts = text.split(',')
    let names = ArrayList<String>()
    for (part in parts) {
        let value = part.trimAscii()
        if (value.size == 0) {
            throw CryptoException(ParseError, "SSH ${fieldName} contains an empty algorithm name")
        }
        if (value.contains(" ") || value.contains("\r") || value.contains("\n") || value.contains("\t")) {
            throw CryptoException(ParseError, "SSH ${fieldName} contains invalid whitespace")
        }
        names.add(value)
    }
    (names.toArray(), cursor + nameListLen)
}

private func appendString(out: ArrayList<Byte>, data: Array<Byte>): Unit {
    appendUInt32(out, data.size)
    appendBytes(out, data)
}

private func decodeString(
    encoded: Array<Byte>,
    offset: Int64,
    label: String
): (Array<Byte>, Int64) {
    let stringLen = decodeUInt32(encoded, offset, label)
    let cursor = offset + 4
    if (cursor + stringLen > encoded.size) {
        throw CryptoException(ParseError, "SSH ${label} exceeds packet bounds")
    }
    (encoded[cursor..(cursor + stringLen)], cursor + stringLen)
}

private func normalizeBannerForHash(encodedLine: Array<Byte>, role: String): Array<Byte> {
    if (encodedLine.size < 2) {
        throw CryptoException(InvalidArgument, "SSH ${role} banner line is too short")
    }
    _ = sshDecodeVersionBanner(encodedLine)
    encodedLine[0..(encodedLine.size - 2)]
}

private func sshDeriveKeyMaterialSha256(
    sharedSecret: Array<Byte>,
    exchangeHash: Array<Byte>,
    letter: Byte,
    sessionId: Array<Byte>,
    length: Int64
): Array<Byte> {
    if (length < 0) {
        throw CryptoException(InvalidArgument, "SSH KDF output length must be non-negative")
    }
    if (length == 0) {
        return []
    }

    let seed = ArrayList<Byte>()
    appendString(seed, sharedSecret)
    appendString(seed, exchangeHash)
    seed.add(letter)
    appendString(seed, sessionId)

    var material = sha256(seed.toArray())
    let prefix = ArrayList<Byte>()
    appendString(prefix, sharedSecret)
    appendString(prefix, exchangeHash)

    while (material.size < length) {
        let nextInput = ArrayList<Byte>()
        appendBytes(nextInput, prefix.toArray())
        appendString(nextInput, material)
        material = concatBytes(material, sha256(nextInput.toArray()))
    }
    material[0..length]
}

private func sshCipherMaterialLengths(cipherName: String): (Int64, Int64) {
    if (cipherName == "aes128-ctr") {
        return (16, 16)
    }
    if (cipherName == "aes256-ctr") {
        return (16, 32)
    }
    if (cipherName == SSH_CIPHER_CHACHA20_POLY1305_OPENSSH) {
        return (12, 32)
    }
    if (cipherName == SSH_CIPHER_AES128_GCM_OPENSSH) {
        return (12, 16)
    }
    if (cipherName == SSH_CIPHER_AES256_GCM_OPENSSH) {
        return (12, 32)
    }
    if (cipherName == "none") {
        return (0, 0)
    }
    throw CryptoException(Unsupported, "SSH cipher is unsupported: ${cipherName}")
}

private func sshMacKeyLength(macName: String): Int64 {
    match (macName) {
        case "hmac-sha2-256" => 32
        case "hmac-sha2-512" => 64
        case "none" => 0
        case _ =>
            throw CryptoException(Unsupported, "SSH MAC is unsupported: ${macName}")
    }
}

private func sshCipherPacketBlockSize(cipherName: String): Int64 {
    if (cipherName == "aes128-ctr" || cipherName == "aes256-ctr") {
        return SSH_AES_BLOCK_SIZE
    }
    if (
        cipherName == SSH_CIPHER_CHACHA20_POLY1305_OPENSSH ||
        cipherName == SSH_CIPHER_AES128_GCM_OPENSSH ||
        cipherName == SSH_CIPHER_AES256_GCM_OPENSSH ||
        cipherName == "none"
    ) {
        return SSH_DEFAULT_PACKET_BLOCK_SIZE
    }
    throw CryptoException(Unsupported, "SSH cipher packet framing is unsupported: ${cipherName}")
}

private func sshCipherTagLength(cipherName: String): Int64 {
    if (cipherName == SSH_CIPHER_CHACHA20_POLY1305_OPENSSH) {
        return CHACHA20_POLY1305_TAG_LEN
    }
    if (cipherName == SSH_CIPHER_AES128_GCM_OPENSSH || cipherName == SSH_CIPHER_AES256_GCM_OPENSSH) {
        return 16
    }
    0
}

private func sshEnsureScratchSize(buffer: Array<Byte>, size: Int64): Array<Byte> {
    if (size < 0) {
        throw CryptoException(InvalidArgument, "SSH scratch buffer size must be non-negative")
    }
    if (buffer.size == size) {
        return buffer
    }
    Array<Byte>(size, repeat: 0)
}

private func sshCopyBytesRange(src: Array<Byte>, srcOffset: Int64, dst: Array<Byte>, count: Int64): Unit {
    if (srcOffset < 0 || count < 0) {
        throw CryptoException(OutOfBounds, "SSH byte-range copy offsets must be non-negative")
    }
    if ((srcOffset + count) > src.size || count > dst.size) {
        throw CryptoException(OutOfBounds, "SSH byte-range copy is out of bounds")
    }
    var i = 0
    while (i < count) {
        dst[i] = src[srcOffset + i]
        i += 1
    }
}

private func sshConcatCipherAndTag(ciphertext: Array<Byte>, tag: Array<Byte>, tagLen: Int64): Array<Byte> {
    if (tagLen <= 0 || tagLen > tag.size) {
        throw CryptoException(InvalidArgument, "SSH AEAD tag length is invalid")
    }
    let out = Array<Byte>(ciphertext.size + tagLen, repeat: 0)
    var i = 0
    while (i < ciphertext.size) {
        out[i] = ciphertext[i]
        i += 1
    }
    var j = 0
    while (j < tagLen) {
        out[ciphertext.size + j] = tag[j]
        j += 1
    }
    out
}

private func sshWritePacketAeadAad(aad: Array<Byte>, sequenceNumber: Int64): Unit {
    if (aad.size != 4) {
        throw CryptoException(InvalidArgument, "SSH packet AEAD additional data must be 4 bytes")
    }
    encodeUInt32(aad, 0, sequenceNumber)
}

private func sshSealPacketAead(
    cipherName: String,
    nonce: Array<Byte>,
    packet: Array<Byte>,
    aad: Array<Byte>,
    aesGcmContext: ?AesGcmContext,
    chacha20Context: ?Chacha20Poly1305Context
): Array<Byte> {
    let _ = aesGcmContext
    if (cipherName == SSH_CIPHER_CHACHA20_POLY1305_OPENSSH) {
        let context = match (chacha20Context) {
            case Some(value) => value
            case None =>
                throw CryptoException(InternalError, "SSH ChaCha20-Poly1305 packet state is not initialized")
        }
        let (ciphertext, tag) = chacha20Poly1305EncryptWithContext(context, nonce, packet, aad: aad)
        return concatBytes(ciphertext, tag)
    }
    throw CryptoException(Unsupported, "SSH AEAD packet cipher is unsupported: ${cipherName}")
}

private func sshOpenPacketAead(
    cipherName: String,
    nonce: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad: Array<Byte>,
    aesGcmContext: ?AesGcmContext,
    chacha20Context: ?Chacha20Poly1305Context
): Array<Byte> {
    let _ = aesGcmContext
    if (cipherName == SSH_CIPHER_CHACHA20_POLY1305_OPENSSH) {
        let context = match (chacha20Context) {
            case Some(value) => value
            case None =>
                throw CryptoException(InternalError, "SSH ChaCha20-Poly1305 packet state is not initialized")
        }
        try {
            return chacha20Poly1305DecryptWithContext(context, nonce, ciphertext, tag, aad: aad)
        } catch (_: CryptoException) {
            throw CryptoException(ParseError, "SSH packet AEAD verification failed")
        }
    }
    throw CryptoException(Unsupported, "SSH AEAD packet cipher is unsupported: ${cipherName}")
}

private func sshMacDigestLength(macName: String): Int64 {
    match (macName) {
        case "hmac-sha2-256" => 32
        case "hmac-sha2-512" => 64
        case "none" => 0
        case _ =>
            throw CryptoException(Unsupported, "SSH packet MAC is unsupported: ${macName}")
    }
}

private func sshMacHashAlgorithm(macName: String): HashAlgorithm {
    match (macName) {
        case "hmac-sha2-256" => HashAlgorithm.SHA256
        case "hmac-sha2-512" => HashAlgorithm.SHA512
        case _ =>
            throw CryptoException(Unsupported, "SSH packet MAC hash is unsupported: ${macName}")
    }
}

private func sshComputePacketMac(
    macName: String,
    integrityKey: Array<Byte>,
    sequenceNumber: Int64,
    packet: Array<Byte>
): Array<Byte> {
    if (sequenceNumber < 0 || sequenceNumber > SSH_MAX_SEQUENCE_NUMBER) {
        throw CryptoException(OutOfBounds, "SSH packet sequence number exceeds uint32")
    }
    if (macName == "none") {
        return []
    }
    let algorithm = sshMacHashAlgorithm(macName)
    let macInput = ArrayList<Byte>()
    appendUInt32(macInput, sequenceNumber)
    appendBytes(macInput, packet)
    hmac(algorithm, integrityKey, macInput.toArray())
}

private func sshCipherPacket(
    cipherName: String,
    encryptionKey: Array<Byte>,
    counter: Array<Byte>,
    packet: Array<Byte>
): Array<Byte> {
    if (cipherName == "none") {
        return packet.clone()
    }
    if (cipherName == "aes128-ctr" || cipherName == "aes256-ctr") {
        if (counter.size != SSH_AES_BLOCK_SIZE) {
            throw CryptoException(InvalidArgument, "SSH CTR counter must be 16 bytes")
        }
        return aesCtrCrypt(encryptionKey, counter, packet)
    }
    throw CryptoException(Unsupported, "SSH packet cipher is unsupported: ${cipherName}")
}

private func sshAdvanceCounterForPacket(cipherName: String, counter: Array<Byte>, packetLen: Int64): Unit {
    if (packetLen < 0) {
        throw CryptoException(InvalidArgument, "SSH packet length must be non-negative")
    }
    if (packetLen == 0 || cipherName == "none") {
        return
    }
    if (sshCipherTagLength(cipherName) != 0) {
        if (counter.size != 12) {
            throw CryptoException(InvalidArgument, "SSH AEAD invocation counter must be 12 bytes")
        }
        sshIncrementInvocationCounter96Unchecked(counter)
        return
    }
    if (counter.size != SSH_AES_BLOCK_SIZE) {
        throw CryptoException(InvalidArgument, "SSH CTR counter must be 16 bytes")
    }
    let blocks = (packetLen + SSH_AES_BLOCK_SIZE - 1) / SSH_AES_BLOCK_SIZE
    var i = 0
    while (i < blocks) {
        sshIncrementCounter128Unchecked(counter)
        i += 1
    }
}

private func sshIncrementInvocationCounter96Unchecked(counter: Array<Byte>): Unit {
    var i = counter.size - 1
    let suffixStart = counter.size - 8
    while (i >= suffixStart) {
        let next = Int64(UInt8(counter[i])) + 1
        counter[i] = UInt8(next & 0xff)
        if (next <= 0xff) {
            return
        }
        i -= 1
    }
}

private func sshIncrementCounter128Unchecked(counter: Array<Byte>): Unit {
    var i = counter.size - 1
    while (i >= 0) {
        let next = Int64(UInt8(counter[i])) + 1
        counter[i] = UInt8(next & 0xff)
        if (next <= 0xff) {
            return
        }
        i -= 1
    }
}

private func sshNextSequence(sequenceNumber: Int64): Int64 {
    if (sequenceNumber < 0 || sequenceNumber >= SSH_MAX_SEQUENCE_NUMBER) {
        throw CryptoException(OutOfBounds, "SSH packet sequence number exhausted")
    }
    sequenceNumber + 1
}

private func requireHandshakePhase(
    currentPhase: SshHandshakePhase,
    expectedPhase: SshHandshakePhase,
    label: String
): Unit {
    if (currentPhase != expectedPhase) {
        throw CryptoException(
            ParseError,
            "SSH handshake transition '${label}' requires ${expectedPhase.toString()}, current ${currentPhase.toString()}"
        )
    }
}

private func concatBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    secureCopyInto(left, out, dstOffset: 0)
    secureCopyInto(right, out, dstOffset: left.size)
    out
}

private func selectAlgorithm(serverPreferred: Array<String>, peerSupported: Array<String>, fieldName: String): String {
    for (candidate in serverPreferred) {
        if (containsString(peerSupported, candidate)) {
            return candidate
        }
    }
    throw CryptoException(ParseError, "SSH algorithm negotiation failed for ${fieldName}")
}

private func containsString(values: Array<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    false
}

private func appendBytes(out: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    var i = 0
    while (i < bytes.size) {
        out.add(bytes[i])
        i += 1
    }
}

private func appendUInt32(out: ArrayList<Byte>, value: Int64): Unit {
    if (value < 0 || value > 0xffff_ffff) {
        throw CryptoException(OutOfBounds, "SSH uint32 value is out of range")
    }
    out.add(UInt8((value >> 24) & 0xff))
    out.add(UInt8((value >> 16) & 0xff))
    out.add(UInt8((value >> 8) & 0xff))
    out.add(UInt8(value & 0xff))
}

private func decodeUInt32(encoded: Array<Byte>, offset: Int64, label: String): Int64 {
    if (offset < 0 || offset + 4 > encoded.size) {
        throw CryptoException(ParseError, "SSH ${label} uint32 read out of bounds")
    }
    (Int64(UInt8(encoded[offset])) << 24) |
    (Int64(UInt8(encoded[offset + 1])) << 16) |
    (Int64(UInt8(encoded[offset + 2])) << 8) |
    Int64(UInt8(encoded[offset + 3]))
}

private func encodeUInt32(encoded: Array<Byte>, offset: Int64, value: Int64): Unit {
    if (offset < 0 || offset + 4 > encoded.size) {
        throw CryptoException(OutOfBounds, "SSH uint32 write out of bounds")
    }
    if (value < 0 || value > 0xffff_ffff) {
        throw CryptoException(OutOfBounds, "SSH uint32 value is out of range")
    }
    encoded[offset] = UInt8((value >> 24) & 0xff)
    encoded[offset + 1] = UInt8((value >> 16) & 0xff)
    encoded[offset + 2] = UInt8((value >> 8) & 0xff)
    encoded[offset + 3] = UInt8(value & 0xff)
}

private func validatePacketBlockSize(blockSize: Int64): Unit {
    if (blockSize < SSH_DEFAULT_PACKET_BLOCK_SIZE || blockSize > 255) {
        throw CryptoException(InvalidArgument, "SSH packet block size must be in [8, 255]")
    }
}
