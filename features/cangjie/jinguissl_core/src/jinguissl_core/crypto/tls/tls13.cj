package jinguissl_core.crypto.tls

import std.collection.ArrayList
import jinguissl_core.crypto.aes.{AesEngineKind}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.{FipsProfile, TLS_VERSION_1_2, TlsVersion}
import jinguissl_core.crypto.digest.{hmac, sha256, sha384, HashAlgorithm}
import jinguissl_core.crypto.ecc.{EcPrivateKey, EcPublicKey, NamedCurve, ecdhDeriveSharedSecret, ecdsaSign, ecdsaVerify, requireFipsCurve}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.rsa.{RsaHashAlgorithm, RsaPrivateKey, rsaSignPssWithHash, rsaVerifyPssWithHash}
import jinguissl_core.crypto.utils.{constantTimeEquals, randomSeed, secureCopyInto}
import jinguissl_core.crypto.x25519.{X25519_KEY_LEN, x25519DeriveSharedSecret, x25519ValidatePublicKey}
import jinguissl_core.crypto.x509.{X509Certificate, X509VerificationPolicy, X509VerificationResult, x509ExtractEcPublicKey, x509ExtractRsaPublicKey, x509ParseDer, x509VerifyCertificateChain, x509VerifyCertificateChainWithProfile}

public enum Tls13HandshakeMode <: Equatable<Tls13HandshakeMode> & ToString {
    | ECDHE_1RTT
    | PSK_1RTT
    | PSK_0RTT_PLACEHOLDER

    public operator func ==(right: Tls13HandshakeMode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: Tls13HandshakeMode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ECDHE_1RTT => 0
            case PSK_1RTT => 1
            case PSK_0RTT_PLACEHOLDER => 2
        }
    }

    public func toString(): String {
        match (this) {
            case ECDHE_1RTT => "TLS13-ECDHE-1RTT"
            case PSK_1RTT => "TLS13-PSK-1RTT"
            case PSK_0RTT_PLACEHOLDER => "TLS13-PSK-0RTT-PLACEHOLDER"
        }
    }
}

public class Tls13HandshakeSecrets {
    public let earlySecret: Array<Byte>
    public let handshakeSecret: Array<Byte>
    public let masterSecret: Array<Byte>

    public let clientHsTrafficSecret: Array<Byte>
    public let serverHsTrafficSecret: Array<Byte>
    public let clientAppTrafficSecret: Array<Byte>
    public let serverAppTrafficSecret: Array<Byte>

    public let clientWriteKey: Array<Byte>
    public let serverWriteKey: Array<Byte>
    public let clientWriteIv: Array<Byte>
    public let serverWriteIv: Array<Byte>

    public init(
        earlySecret: Array<Byte>,
        handshakeSecret: Array<Byte>,
        masterSecret: Array<Byte>,
        clientHsTrafficSecret: Array<Byte>,
        serverHsTrafficSecret: Array<Byte>,
        clientAppTrafficSecret: Array<Byte>,
        serverAppTrafficSecret: Array<Byte>,
        clientWriteKey: Array<Byte>,
        serverWriteKey: Array<Byte>,
        clientWriteIv: Array<Byte>,
        serverWriteIv: Array<Byte>
    ) {
        this.earlySecret = earlySecret.clone()
        this.handshakeSecret = handshakeSecret.clone()
        this.masterSecret = masterSecret.clone()
        this.clientHsTrafficSecret = clientHsTrafficSecret.clone()
        this.serverHsTrafficSecret = serverHsTrafficSecret.clone()
        this.clientAppTrafficSecret = clientAppTrafficSecret.clone()
        this.serverAppTrafficSecret = serverAppTrafficSecret.clone()
        this.clientWriteKey = clientWriteKey.clone()
        this.serverWriteKey = serverWriteKey.clone()
        this.clientWriteIv = clientWriteIv.clone()
        this.serverWriteIv = serverWriteIv.clone()
    }
}

public class Tls13EarlyDataSecrets {
    public let clientEarlyTrafficSecret: Array<Byte>
    public let clientEarlyWriteKey: Array<Byte>
    public let clientEarlyWriteIv: Array<Byte>

    public init(clientEarlyTrafficSecret: Array<Byte>, clientEarlyWriteKey: Array<Byte>, clientEarlyWriteIv: Array<Byte>) {
        this.clientEarlyTrafficSecret = clientEarlyTrafficSecret.clone()
        this.clientEarlyWriteKey = clientEarlyWriteKey.clone()
        this.clientEarlyWriteIv = clientEarlyWriteIv.clone()
    }
}

public class Tls13NewSessionTicketMessage {
    public let ticketLifetimeSeconds: Int64
    public let ticketAgeAdd: Int64
    public let ticketNonce: Array<Byte>
    public let ticket: Array<Byte>
    public let extensions: Array<TlsExtension>

    public init(
        ticketLifetimeSeconds: Int64,
        ticketAgeAdd: Int64,
        ticketNonce: Array<Byte>,
        ticket: Array<Byte>,
        extensions!: Array<TlsExtension> = []
    ) {
        if (ticketLifetimeSeconds < 0 || ticketLifetimeSeconds > 0xffff_ffff) {
            throw CryptoException(InvalidArgument, "TLS1.3 ticket_lifetime must fit uint32")
        }
        if (ticketAgeAdd < 0 || ticketAgeAdd > 0xffff_ffff) {
            throw CryptoException(InvalidArgument, "TLS1.3 ticket_age_add must fit uint32")
        }
        if (ticketNonce.size > 255) {
            throw CryptoException(OutOfBounds, "TLS1.3 ticket_nonce exceeds uint8 length")
        }
        if (ticket.size == 0 || ticket.size > 65535) {
            throw CryptoException(InvalidArgument, "TLS1.3 ticket length is invalid")
        }
        this.ticketLifetimeSeconds = ticketLifetimeSeconds
        this.ticketAgeAdd = ticketAgeAdd
        this.ticketNonce = ticketNonce.clone()
        this.ticket = ticket.clone()
        this.extensions = extensions.clone()
    }
}

public class Tls13PskIdentityEntry {
    public let identity: Array<Byte>
    public let obfuscatedTicketAge: Int64
    public let binder: Array<Byte>

    public init(identity: Array<Byte>, obfuscatedTicketAge: Int64, binder: Array<Byte>) {
        if (identity.size == 0 || identity.size > 65535) {
            throw CryptoException(InvalidArgument, "TLS1.3 PSK identity length is invalid")
        }
        if (obfuscatedTicketAge < 0 || obfuscatedTicketAge > 0xffff_ffff) {
            throw CryptoException(InvalidArgument, "TLS1.3 PSK obfuscated_ticket_age must fit uint32")
        }
        if (binder.size == 0 || binder.size > 255) {
            throw CryptoException(InvalidArgument, "TLS1.3 PSK binder length is invalid")
        }
        this.identity = identity.clone()
        this.obfuscatedTicketAge = obfuscatedTicketAge
        this.binder = binder.clone()
    }
}

public enum Tls13RecordChannelState <: Equatable<Tls13RecordChannelState> & ToString {
    | Active
    | CloseNotifySent
    | CloseNotifyReceived
    | Closed

    public operator func ==(right: Tls13RecordChannelState): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: Tls13RecordChannelState): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Active => 0
            case CloseNotifySent => 1
            case CloseNotifyReceived => 2
            case Closed => 3
        }
    }

    public func toString(): String {
        match (this) {
            case Active => "ACTIVE"
            case CloseNotifySent => "CLOSE_NOTIFY_SENT"
            case CloseNotifyReceived => "CLOSE_NOTIFY_RECEIVED"
            case Closed => "CLOSED"
        }
    }
}

public class Tls13RecordChannelInbound {
    public let contentType: TlsContentType
    public let fragment: Array<Byte>
    public let alert: ?TlsAlertMessage
    public let stateAfter: Tls13RecordChannelState

    public init(
        contentType: TlsContentType,
        fragment: Array<Byte>,
        stateAfter: Tls13RecordChannelState,
        alert!: ?TlsAlertMessage = None
    ) {
        if (contentType == Alert) {
            if (let Some(_alert) <- alert) {
                ()
            } else {
                throw CryptoException(InvalidArgument, "TLS1.3 alert inbound event must carry decoded alert")
            }
        }
        this.contentType = contentType
        this.fragment = fragment.clone()
        this.alert = alert
        this.stateAfter = stateAfter
    }
}

public class Tls13RecordLayerHandle {
    public let algorithm: TlsAeadAlgorithm
    let _aesLayer: ?TlsAeadRecordLayer
    let _chachaLayer: ?TlsChacha20Poly1305RecordLayer

    public init(
        algorithm: TlsAeadAlgorithm,
        aesLayer!: ?TlsAeadRecordLayer = None,
        chachaLayer!: ?TlsChacha20Poly1305RecordLayer = None
    ) {
        match (algorithm) {
            case AES_GCM =>
                if (let Some(_layer) <- aesLayer) {
                    if (let Some(_unexpected) <- chachaLayer) {
                        throw CryptoException(InvalidArgument, "TLS1.3 AES record handle must not carry ChaCha layer")
                    }
                } else {
                    throw CryptoException(InvalidArgument, "TLS1.3 AES record handle requires AES layer")
                }
            case CHACHA20_POLY1305 =>
                if (let Some(_layer) <- chachaLayer) {
                    if (let Some(_unexpected) <- aesLayer) {
                        throw CryptoException(InvalidArgument, "TLS1.3 ChaCha record handle must not carry AES layer")
                    }
                } else {
                    throw CryptoException(InvalidArgument, "TLS1.3 ChaCha record handle requires ChaCha layer")
                }
        }
        this.algorithm = algorithm
        this._aesLayer = aesLayer
        this._chachaLayer = chachaLayer
    }

    /**
 * seal.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func seal(contentType: TlsContentType, plaintext: Array<Byte>): Array<Byte> {
        match (algorithm) {
            case AES_GCM =>
                if (let Some(layer) <- _aesLayer) {
                    return layer.seal(contentType, plaintext)
                }
                throw CryptoException(InvalidArgument, "TLS1.3 AES record layer is unavailable")
            case CHACHA20_POLY1305 =>
                if (let Some(layer) <- _chachaLayer) {
                    return layer.seal(contentType, plaintext)
                }
                throw CryptoException(InvalidArgument, "TLS1.3 ChaCha record layer is unavailable")
        }
    }

    /**
 * open.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func open(encodedRecord: Array<Byte>): TlsPlainRecord {
        match (algorithm) {
            case AES_GCM =>
                if (let Some(layer) <- _aesLayer) {
                    return layer.open(encodedRecord)
                }
                throw CryptoException(InvalidArgument, "TLS1.3 AES record layer is unavailable")
            case CHACHA20_POLY1305 =>
                if (let Some(layer) <- _chachaLayer) {
                    return layer.open(encodedRecord)
                }
                throw CryptoException(InvalidArgument, "TLS1.3 ChaCha record layer is unavailable")
        }
    }

    /**
 * resetSequences.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func resetSequences(): Unit {
        match (algorithm) {
            case AES_GCM =>
                if (let Some(layer) <- _aesLayer) {
                    layer.resetSequences()
                    return
                }
                throw CryptoException(InvalidArgument, "TLS1.3 AES record layer is unavailable")
            case CHACHA20_POLY1305 =>
                if (let Some(layer) <- _chachaLayer) {
                    layer.resetSequences()
                    return
                }
                throw CryptoException(InvalidArgument, "TLS1.3 ChaCha record layer is unavailable")
        }
    }
}

public class Tls13RecordChannel {
    public let handle: Tls13RecordLayerHandle
    var _state: Tls13RecordChannelState

    public init(
        handle: Tls13RecordLayerHandle,
        state!: Tls13RecordChannelState = Active
    ) {
        this.handle = handle
        this._state = state
    }

    public prop state: Tls13RecordChannelState {
        get() {
            _state
        }
    }

    public prop isActive: Bool {
        get() {
            _state == Active
        }
    }

    /**
 * sealApplicationData.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sealApplicationData(plaintext: Array<Byte>): Array<Byte> {
        if (_state != Active) {
            throw CryptoException(ParseError, "TLS1.3 record channel is not active for application data")
        }
        handle.seal(ApplicationData, plaintext)
    }

    /**
 * sendCloseNotify.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sendCloseNotify(): Array<Byte> {
        if (_state == Closed) {
            throw CryptoException(ParseError, "TLS1.3 record channel is already closed")
        }
        if (_state == CloseNotifySent) {
            throw CryptoException(ParseError, "TLS1.3 close_notify has already been sent")
        }
        if (_state == CloseNotifyReceived) {
            _state = Closed
        } else {
            _state = CloseNotifySent
        }
        handle.seal(Alert, tlsEncodeAlert(Warning, CloseNotify))
    }

    /**
 * sendFatalAlert.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func sendFatalAlert(description: TlsAlertDescription): Array<Byte> {
        if (_state == Closed) {
            throw CryptoException(ParseError, "TLS1.3 record channel is already closed")
        }
        _state = Closed
        handle.seal(Alert, tlsEncodeAlert(Fatal, description))
    }

    /**
 * openRecord.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func openRecord(encodedRecord: Array<Byte>): Tls13RecordChannelInbound {
        if (_state == Closed) {
            throw CryptoException(ParseError, "TLS1.3 record channel is already closed")
        }
        let plain = handle.open(encodedRecord)
        if (plain.contentType == Alert) {
            let alert = tlsDecodeAlert(plain.fragment)
            _state = tls13AdvanceRecordChannelStateFromAlert(_state, alert)
            return Tls13RecordChannelInbound(
                Alert,
                [],
                _state,
                alert: Some(alert)
            )
        }
        if (_state != Active) {
            throw CryptoException(ParseError, "TLS1.3 non-alert record received after close_notify")
        }
        Tls13RecordChannelInbound(
            plain.contentType,
            plain.fragment,
            _state
        )
    }

    public func forceClose(): Unit {
        _state = Closed
    }
}

public enum Tls13AuthFlightRole <: Equatable<Tls13AuthFlightRole> & ToString {
    | SERVER
    | CLIENT

    public operator func ==(right: Tls13AuthFlightRole): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: Tls13AuthFlightRole): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case SERVER => 0
            case CLIENT => 1
        }
    }

    public func toString(): String {
        match (this) {
            case SERVER => "SERVER"
            case CLIENT => "CLIENT"
        }
    }
}

public class Tls13AuthFlight {
    public let role: Tls13AuthFlightRole
    public let certificateHandshake: Array<Byte>
    public let certificateVerifyHandshake: Array<Byte>
    public let finishedHandshake: Array<Byte>

    public init(
        role: Tls13AuthFlightRole,
        certificateHandshake: Array<Byte>,
        certificateVerifyHandshake: Array<Byte>,
        finishedHandshake: Array<Byte>
    ) {
        if (certificateHandshake.size == 0) {
            throw CryptoException(InvalidArgument, "TLS1.3 auth flight certificate handshake must not be empty")
        }
        if (certificateVerifyHandshake.size == 0) {
            throw CryptoException(InvalidArgument, "TLS1.3 auth flight certificate_verify handshake must not be empty")
        }
        if (finishedHandshake.size == 0) {
            throw CryptoException(InvalidArgument, "TLS1.3 auth flight finished handshake must not be empty")
        }
        this.role = role
        this.certificateHandshake = certificateHandshake.clone()
        this.certificateVerifyHandshake = certificateVerifyHandshake.clone()
        this.finishedHandshake = finishedHandshake.clone()
    }
}

public class Tls13ServerHandshakeFlight {
    public let serverHello: Array<Byte>
    public let encryptedExtensions: Array<Byte>
    public let authFlight: Tls13AuthFlight
    public let transcriptHash: Array<Byte>
    public let selectedAlpn: String
    public let requestedServerName: String
    public let acknowledgedServerName: Bool

    public init(
        serverHello: Array<Byte>,
        encryptedExtensions: Array<Byte>,
        authFlight: Tls13AuthFlight,
        transcriptHash: Array<Byte>,
        selectedAlpn!: String = "",
        requestedServerName!: String = "",
        acknowledgedServerName!: Bool = false
    ) {
        if (serverHello.size == 0 || encryptedExtensions.size == 0) {
            throw CryptoException(InvalidArgument, "TLS1.3 server handshake flight messages must not be empty")
        }
        if (transcriptHash.size != 32) {
            throw CryptoException(InvalidArgument, "TLS1.3 transcript hash must be SHA-256 sized")
        }
        let normalizedAlpn = selectedAlpn.trimAscii()
        let normalizedSni = requestedServerName.trimAscii().toAsciiLower()
        this.serverHello = serverHello.clone()
        this.encryptedExtensions = encryptedExtensions.clone()
        this.authFlight = authFlight
        this.transcriptHash = transcriptHash.clone()
        this.selectedAlpn = normalizedAlpn
        this.requestedServerName = normalizedSni
        this.acknowledgedServerName = acknowledgedServerName
    }
}

public class Tls13ServerHandshakeContext {
    public let flight: Tls13ServerHandshakeFlight
    public let secrets: Tls13HandshakeSecrets

    public init(flight: Tls13ServerHandshakeFlight, secrets: Tls13HandshakeSecrets) {
        this.flight = flight
        this.secrets = secrets
    }
}

public class Tls13ServerClientAuthContext {
    public let serverContext: Tls13ServerHandshakeContext
    public let encodedCertificateRequest: Array<Byte>
    public let request: Tls13CertificateRequestParameters

    public init(
        serverContext: Tls13ServerHandshakeContext,
        encodedCertificateRequest: Array<Byte>,
        request: Tls13CertificateRequestParameters
    ) {
        if (encodedCertificateRequest.size == 0) {
            throw CryptoException(InvalidArgument, "TLS1.3 CertificateRequest handshake must not be empty")
        }
        this.serverContext = serverContext
        this.encodedCertificateRequest = encodedCertificateRequest.clone()
        this.request = request
    }
}

public class Tls13ClientHandshakeResult {
    public let secrets: Tls13HandshakeSecrets
    public let selectedAlpn: String
    public let requestedServerName: String
    public let acknowledgedServerName: Bool
    public let verification: X509VerificationResult

    public init(
        secrets: Tls13HandshakeSecrets,
        verification: X509VerificationResult,
        selectedAlpn!: String = "",
        requestedServerName!: String = "",
        acknowledgedServerName!: Bool = false
    ) {
        this.secrets = secrets
        this.verification = verification
        this.selectedAlpn = selectedAlpn.trimAscii()
        this.requestedServerName = requestedServerName.trimAscii().toAsciiLower()
        this.acknowledgedServerName = acknowledgedServerName
    }
}

public class Tls13CertificateRequestParameters {
    public let requestContext: Array<Byte>
    public let signatureSchemes: Array<Int64>
    public let certificateAuthorities: Array<Array<Byte>>
    public let extensions: Array<TlsExtension>

    public init(
        requestContext: Array<Byte>,
        signatureSchemes: Array<Int64>,
        certificateAuthorities!: Array<Array<Byte>> = [],
        extensions!: Array<TlsExtension> = []
    ) {
        if (requestContext.size > 255) {
            throw CryptoException(OutOfBounds, "TLS1.3 CertificateRequest.request_context exceeds uint8 length")
        }
        if (signatureSchemes.size == 0) {
            throw CryptoException(InvalidArgument, "TLS1.3 CertificateRequest signature_schemes must not be empty")
        }
        for (scheme in signatureSchemes) {
            if (scheme < 0 || scheme > 65535) {
                throw CryptoException(InvalidArgument, "TLS1.3 signature scheme must fit uint16")
            }
        }
        for (authority in certificateAuthorities) {
            if (authority.size == 0) {
                throw CryptoException(InvalidArgument, "TLS1.3 certificate authority name must not be empty")
            }
            if (authority.size > 65535) {
                throw CryptoException(OutOfBounds, "TLS1.3 certificate authority name exceeds uint16 length")
            }
        }
        this.requestContext = requestContext.clone()
        this.signatureSchemes = signatureSchemes.clone()
        this.certificateAuthorities = tls13CloneByteArrayArray(certificateAuthorities)
        this.extensions = extensions.clone()
    }
}

public let TLS13_DEFAULT_AEAD_KEY_LEN: Int64 = 16
public let TLS13_DEFAULT_AEAD_IV_LEN: Int64 = 12
public let TLS13_HASH_LEN: Int64 = 32
public let TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256: Int64 = 0x0403
public let TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384: Int64 = 0x0503
public let TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256: Int64 = 0x0804
public let TLS13_EXT_SIGNATURE_ALGORITHMS: Int64 = 0x000d
public let TLS13_EXT_CERTIFICATE_AUTHORITIES: Int64 = 0x002f
public let TLS13_KEY_UPDATE_NOT_REQUESTED: Int64 = 0
public let TLS13_KEY_UPDATE_REQUESTED: Int64 = 1
public let TLS13_MAX_TICKET_LIFETIME_SECONDS: Int64 = 0xffff_ffff
public let TLS13_CIPHER_SUITE_AES_128_GCM_SHA256: Int64 = 0x1301
public let TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256: Int64 = 0x1303

private let TLS13_VERSION: Int64 = 0x0304
private let TLS13_EXT_SUPPORTED_GROUPS: Int64 = 0x000a
private let TLS13_EXT_SUPPORTED_VERSIONS: Int64 = 0x002b
private let TLS13_EXT_KEY_SHARE: Int64 = 0x0033
private let TLS13_EXT_PSK_KEY_EXCHANGE_MODES: Int64 = 0x002d
private let TLS13_EXT_PRE_SHARED_KEY: Int64 = 0x0029
private let TLS13_GROUP_SECP256R1: Int64 = 0x0017
private let TLS13_GROUP_SECP384R1: Int64 = 0x0018
private let TLS13_GROUP_X25519: Int64 = 0x001d
private let TLS13_PSK_MODE_DHE_KE: Int64 = 0x01
private let TLS13_ECC_POINT_UNCOMPRESSED: Int64 = 0x04
private let TLS13_P256_FIELD_BYTES: Int64 = 32
private let TLS13_P384_FIELD_BYTES: Int64 = 48
private let TLS13_CIPHER_TLS_AES_128_GCM_SHA256: Int64 = TLS13_CIPHER_SUITE_AES_128_GCM_SHA256
private let TLS13_CIPHER_TLS_CHACHA20_POLY1305_SHA256: Int64 = TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256
private let TLS13_CERT_VERIFY_PREFIX_LEN: Int64 = 64
private let TLS13_CERT_VERIFY_CONTEXT_SERVER: String = "TLS 1.3, server CertificateVerify"
private let TLS13_CERT_VERIFY_CONTEXT_CLIENT: String = "TLS 1.3, client CertificateVerify"

public class Tls13ClientHelloInteropSummary {
    public let legacyVersion: TlsVersion
    public let cipherSuites: Array<Int64>
    public let extensionTypes: Array<Int64>
    public let serverNames: Array<String>
    public let alpnProtocols: Array<String>
    public let supportedVersions: Array<Int64>
    public let supportedGroups: Array<Int64>
    public let keyShareGroups: Array<Int64>
    public let signatureSchemes: Array<Int64>

    public init(
        legacyVersion: TlsVersion,
        cipherSuites: Array<Int64>,
        extensionTypes: Array<Int64>,
        serverNames: Array<String>,
        alpnProtocols: Array<String>,
        supportedVersions: Array<Int64>,
        supportedGroups: Array<Int64>,
        keyShareGroups: Array<Int64>,
        signatureSchemes: Array<Int64>
    ) {
        this.legacyVersion = legacyVersion
        this.cipherSuites = cipherSuites.clone()
        this.extensionTypes = extensionTypes.clone()
        this.serverNames = serverNames.clone()
        this.alpnProtocols = alpnProtocols.clone()
        this.supportedVersions = supportedVersions.clone()
        this.supportedGroups = supportedGroups.clone()
        this.keyShareGroups = keyShareGroups.clone()
        this.signatureSchemes = signatureSchemes.clone()
    }
}

public class Tls13ClientHelloInteropProfile {
    public let serverName: String
    public let alpnProtocols: Array<String>
    public let cipherSuites: Array<Int64>
    public let supportedVersions: Array<Int64>
    public let supportedGroups: Array<Int64>
    public let keyShareGroups: Array<Int64>
    public let signatureSchemes: Array<Int64>

    public init(
        serverName!: String = "",
        alpnProtocols!: Array<String> = [],
        cipherSuites!: Array<Int64> = [],
        supportedVersions!: Array<Int64> = [TLS13_VERSION],
        supportedGroups!: Array<Int64> = [],
        keyShareGroups!: Array<Int64> = [],
        signatureSchemes!: Array<Int64> = []
    ) {
        this.serverName = serverName
        this.alpnProtocols = alpnProtocols.clone()
        this.cipherSuites = cipherSuites.clone()
        this.supportedVersions = supportedVersions.clone()
        this.supportedGroups = supportedGroups.clone()
        this.keyShareGroups = keyShareGroups.clone()
        this.signatureSchemes = signatureSchemes.clone()
    }
}

public class Tls13ClientHelloInteropPrecheckReport {
    public let ready: Bool
    public let missing: Array<String>
    public let warnings: Array<String>

    public init(ready: Bool, missing: Array<String>, warnings: Array<String>) {
        this.ready = ready
        this.missing = missing.clone()
        this.warnings = warnings.clone()
    }
}

/**
 * tls13SummarizeClientHello.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13SummarizeClientHello(encodedClientHello: Array<Byte>): Tls13ClientHelloInteropSummary {
    tls13SummarizeDecodedClientHello(tlsDecodeClientHelloHandshake(encodedClientHello))
}

/**
 * tls13SummarizeDecodedClientHello.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13SummarizeDecodedClientHello(clientHello: TlsClientHello): Tls13ClientHelloInteropSummary {
    let extensionTypes = ArrayList<Int64>()
    for (ext in clientHello.extensions) {
        extensionTypes.add(ext.extType)
    }

    Tls13ClientHelloInteropSummary(
        clientHello.legacyVersion,
        clientHello.cipherSuites,
        extensionTypes.toArray(),
        tls13SummarizeServerNames(clientHello.extensions),
        tls13SummarizeAlpnProtocols(clientHello.extensions),
        tls13SummarizeSupportedVersions(clientHello.extensions),
        tls13SummarizeSupportedGroups(clientHello.extensions),
        tls13SummarizeKeyShareGroups(clientHello.extensions),
        tls13SummarizeSignatureSchemes(clientHello.extensions)
    )
}

/**
 * tls13PrecheckEncodedClientHelloInterop.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13PrecheckEncodedClientHelloInterop(
    encodedClientHello: Array<Byte>,
    profile: Tls13ClientHelloInteropProfile
): Tls13ClientHelloInteropPrecheckReport {
    tls13PrecheckClientHelloInterop(tls13SummarizeClientHello(encodedClientHello), profile)
}

/**
 * tls13PrecheckClientHelloInterop.
 */
public func tls13PrecheckClientHelloInterop(
    summary: Tls13ClientHelloInteropSummary,
    profile: Tls13ClientHelloInteropProfile
): Tls13ClientHelloInteropPrecheckReport {
    let missing = ArrayList<String>()
    let warnings = ArrayList<String>()

    if (summary.legacyVersion != TLS_VERSION_1_2) {
        warnings.add("legacy_version expected TLS1.2 compatibility value, got ${summary.legacyVersion.toString()}")
    }
    if (profile.serverName.size > 0 && !tls13ContainsString(summary.serverNames, profile.serverName)) {
        missing.add("missing SNI ${profile.serverName}")
    }

    tls13RequireAllStrings(missing, summary.alpnProtocols, profile.alpnProtocols, "ALPN")
    tls13RequireAllInt64(missing, summary.cipherSuites, profile.cipherSuites, "cipher_suite")
    tls13RequireAllInt64(missing, summary.supportedVersions, profile.supportedVersions, "supported_version")
    tls13RequireAllInt64(missing, summary.supportedGroups, profile.supportedGroups, "supported_group")
    tls13RequireAllInt64(missing, summary.keyShareGroups, profile.keyShareGroups, "key_share_group")
    tls13RequireAllInt64(missing, summary.signatureSchemes, profile.signatureSchemes, "signature_scheme")

    Tls13ClientHelloInteropPrecheckReport(missing.size == 0, missing.toArray(), warnings.toArray())
}

public func tls13HandshakeRequireAllowed(
    profile: FipsProfile,
    mode: Tls13HandshakeMode,
    algorithm!: TlsAeadAlgorithm = AES_GCM,
    ecdheCurve!: NamedCurve = P256
): Unit {
    profile.requireAllowed("TLS1.3")
    profile.requireAllowed(algorithm.toString())
    match (mode) {
        case ECDHE_1RTT =>
            profile.requireAllowed("ECDH")
            tls13RequireSupportedEcdheCurve(ecdheCurve)
            requireFipsCurve(ecdheCurve)
        case PSK_1RTT | PSK_0RTT_PLACEHOLDER =>
            ()
    }
}

/**
 * tls13CipherSuiteAeadAlgorithm.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13CipherSuiteAeadAlgorithm(cipherSuite: Int64): TlsAeadAlgorithm {
    if (cipherSuite == TLS13_CIPHER_SUITE_AES_128_GCM_SHA256) {
        return AES_GCM
    }
    if (cipherSuite == TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256) {
        return CHACHA20_POLY1305
    }
    throw CryptoException(Unsupported, "TLS1.3 cipher suite is unsupported: ${cipherSuite}")
}

/**
 * tls13CipherSuiteKeyLen.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13CipherSuiteKeyLen(cipherSuite: Int64): Int64 {
    if (cipherSuite == TLS13_CIPHER_SUITE_AES_128_GCM_SHA256) {
        return 16
    }
    if (cipherSuite == TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256) {
        return 32
    }
    throw CryptoException(Unsupported, "TLS1.3 cipher suite key length is unsupported: ${cipherSuite}")
}

public func tls13CipherSuiteIvLen(cipherSuite: Int64): Int64 {
    _ = tls13CipherSuiteAeadAlgorithm(cipherSuite)
    TLS13_DEFAULT_AEAD_IV_LEN
}

private func tls13DefaultClientSignatureSchemes(): Array<Int64> {
    [
        TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
        TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    ]
}

public func tls13BuildClientHelloEcdhe(
    clientKeyShare: EcPublicKey,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    tls13BuildClientHelloEcdheWithCipherSuites(
        clientKeyShare,
        [TLS13_CIPHER_SUITE_AES_128_GCM_SHA256],
        sessionId: sessionId
    )
}

public func tls13BuildClientHelloEcdheWithCipherSuites(
    clientKeyShare: EcPublicKey,
    cipherSuites: Array<Int64>,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    let (supportedGroup, _) = tls13ResolveEcdheCurveSpecFromPublicKey(clientKeyShare)
    tls13ValidateOfferedCipherSuites(cipherSuites)

    let hello = TlsClientHello(
        randomSeed(size: TLS_HELLO_RANDOM_LEN),
        cipherSuites,
        sessionId: sessionId,
        compressionMethods: [UInt8(0x00)],
        extensions: [
            TlsExtension(TLS13_EXT_SUPPORTED_VERSIONS, tls13EncodeClientSupportedVersions()),
            tls13EncodeSupportedGroupsExtension([supportedGroup]),
            tls13EncodeSignatureAlgorithmsExtension(tls13DefaultClientSignatureSchemes()),
            TlsExtension(TLS13_EXT_KEY_SHARE, tls13EncodeClientKeyShare(clientKeyShare))
        ],
        legacyVersion: TLS1_2
    )
    tlsEncodeClientHelloHandshake(hello)
}

public func tls13BuildClientHelloX25519(
    clientKeyShare: Array<Byte>,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    tls13BuildClientHelloX25519WithCipherSuites(
        clientKeyShare,
        [TLS13_CIPHER_SUITE_AES_128_GCM_SHA256],
        sessionId: sessionId
    )
}

public func tls13BuildClientHelloX25519WithCipherSuites(
    clientKeyShare: Array<Byte>,
    cipherSuites: Array<Int64>,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    x25519ValidatePublicKey(clientKeyShare)
    tls13ValidateOfferedCipherSuites(cipherSuites)

    let hello = TlsClientHello(
        randomSeed(size: TLS_HELLO_RANDOM_LEN),
        cipherSuites,
        sessionId: sessionId,
        compressionMethods: [UInt8(0x00)],
        extensions: [
            TlsExtension(TLS13_EXT_SUPPORTED_VERSIONS, tls13EncodeClientSupportedVersions()),
            tls13EncodeSupportedGroupsExtension([TLS13_GROUP_X25519]),
            tls13EncodeSignatureAlgorithmsExtension(tls13DefaultClientSignatureSchemes()),
            TlsExtension(TLS13_EXT_KEY_SHARE, tls13EncodeClientX25519KeyShare(clientKeyShare))
        ],
        legacyVersion: TLS1_2
    )
    tlsEncodeClientHelloHandshake(hello)
}

public func tls13BuildClientHelloPsk(
    pskIdentity: Array<Byte>,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    tls13BuildClientHelloPskWithOptionalBinder(pskIdentity, None, sessionId)
}

/**
 * tls13BuildClientHelloPskWithBinder.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildClientHelloPskWithBinder(
    pskIdentity: Array<Byte>,
    psk: Array<Byte>,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    if (psk.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK must not be empty")
    }
    tls13BuildClientHelloPskWithBinders([pskIdentity], [psk], sessionId: sessionId)
}

/**
 * tls13BuildClientHelloPskWithBinders.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildClientHelloPskWithBinders(
    pskIdentities: Array<Array<Byte>>,
    psks: Array<Array<Byte>>,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    if (pskIdentities.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK identity list must not be empty")
    }
    if (pskIdentities.size != psks.size) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK identity and secret list size mismatch")
    }

    let obfuscatedTicketAges = Array<Int64>(pskIdentities.size, repeat: 0)
    let identitiesRaw = tls13EncodeClientPskIdentities(pskIdentities, obfuscatedTicketAges)
    let clientRandom = randomSeed(size: TLS_HELLO_RANDOM_LEN)
    let transcriptHash = tls13ComputePskBinderTranscriptHash(clientRandom, identitiesRaw, sessionId)

    let binders = ArrayList<Array<Byte>>()
    var i = 0
    while (i < psks.size) {
        let psk = psks[i]
        if (psk.size == 0) {
            throw CryptoException(InvalidArgument, "TLS1.3 PSK must not be empty")
        }
        binders.add(tls13ComputePskBinder(psk, transcriptHash))
        i += 1
    }

    let pskExt = concat(identitiesRaw, tls13EncodeClientPskBinders(binders.toArray()))
    let hello = TlsClientHello(
        clientRandom,
        [TLS13_CIPHER_TLS_AES_128_GCM_SHA256],
        sessionId: sessionId,
        compressionMethods: [UInt8(0x00)],
        extensions: [
            TlsExtension(TLS13_EXT_SUPPORTED_VERSIONS, tls13EncodeClientSupportedVersions()),
            TlsExtension(TLS13_EXT_PSK_KEY_EXCHANGE_MODES, tls13EncodePskKeyExchangeModes()),
            TlsExtension(TLS13_EXT_PRE_SHARED_KEY, pskExt)
        ],
        legacyVersion: TLS1_2
    )
    tlsEncodeClientHelloHandshake(hello)
}

public func tls13BuildClientHelloPskFromSessionTicket(
    ticket: TlsSessionTicket,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    let identity = tlsEncodeSessionTicket(ticket)
    tls13BuildClientHelloPskWithBinder(identity, ticket.secret, sessionId: sessionId)
}

/**
 * tls13BuildClientHelloPskFromSessionTickets.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildClientHelloPskFromSessionTickets(
    tickets: Array<TlsSessionTicket>,
    sessionId!: Array<Byte> = []
): Array<Byte> {
    if (tickets.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 session ticket list must not be empty")
    }
    let identities = ArrayList<Array<Byte>>()
    let psks = ArrayList<Array<Byte>>()
    for (ticket in tickets) {
        identities.add(tlsEncodeSessionTicket(ticket))
        psks.add(ticket.secret.clone())
    }
    tls13BuildClientHelloPskWithBinders(identities.toArray(), psks.toArray(), sessionId: sessionId)
}

private func tls13BuildClientHelloPskWithOptionalBinder(
    pskIdentity: Array<Byte>,
    psk: ?Array<Byte>,
    sessionId: Array<Byte>
): Array<Byte> {
    if (pskIdentity.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK identity must not be empty")
    }

    let clientRandom = randomSeed(size: TLS_HELLO_RANDOM_LEN)
    let binders = ArrayList<Array<Byte>>()
    let identitiesRaw = tls13EncodeClientPskIdentities([pskIdentity], [0])
    if (let Some(value) <- psk) {
        let transcriptHash = tls13ComputePskBinderTranscriptHash(clientRandom, identitiesRaw, sessionId)
        binders.add(tls13ComputePskBinder(value, transcriptHash))
    } else {
        binders.add(Array<Byte>(TLS13_HASH_LEN, repeat: 0))
    }
    let pskExt = concat(identitiesRaw, tls13EncodeClientPskBinders(binders.toArray()))

    let hello = TlsClientHello(
        clientRandom,
        [TLS13_CIPHER_TLS_AES_128_GCM_SHA256],
        sessionId: sessionId,
        compressionMethods: [UInt8(0x00)],
        extensions: [
            TlsExtension(TLS13_EXT_SUPPORTED_VERSIONS, tls13EncodeClientSupportedVersions()),
            TlsExtension(TLS13_EXT_PSK_KEY_EXCHANGE_MODES, tls13EncodePskKeyExchangeModes()),
            TlsExtension(TLS13_EXT_PRE_SHARED_KEY, pskExt)
        ],
        legacyVersion: TLS1_2
    )
    tlsEncodeClientHelloHandshake(hello)
}

/**
 * tls13BuildServerHelloForEcdhe.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildServerHelloForEcdhe(
    encodedClientHello: Array<Byte>,
    serverKeyShare: EcPublicKey
): Array<Byte> {
    _ = tls13ResolveEcdheCurveSpecFromPublicKey(serverKeyShare)

    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    tls13RequireClientVersion(clientHello)
    let selectedCipher = tls13SelectCipherSuite(clientHello.cipherSuites)
    let clientKeyShare = tls13ExtractClientKeyShareFromHello(clientHello)
    if (clientKeyShare.curve != serverKeyShare.curve) {
        throw CryptoException(ParseError, "TLS1.3 server key_share curve does not match client offer")
    }

    let hello = TlsServerHello(
        randomSeed(size: TLS_HELLO_RANDOM_LEN),
        selectedCipher,
        sessionId: clientHello.sessionId,
        compressionMethod: UInt8(0x00),
        extensions: [
            TlsExtension(TLS13_EXT_SUPPORTED_VERSIONS, tls13EncodeServerSupportedVersion()),
            TlsExtension(TLS13_EXT_KEY_SHARE, tls13EncodeServerKeyShare(serverKeyShare))
        ],
        legacyVersion: TLS1_2
    )
    tlsEncodeServerHelloHandshake(hello)
}

public func tls13BuildServerHelloForX25519(
    encodedClientHello: Array<Byte>,
    serverKeyShare: Array<Byte>
): Array<Byte> {
    x25519ValidatePublicKey(serverKeyShare)

    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    tls13RequireClientVersion(clientHello)
    let selectedCipher = tls13SelectCipherSuite(clientHello.cipherSuites)
    _ = tls13ExtractClientX25519KeyShareFromHello(clientHello)

    let hello = TlsServerHello(
        randomSeed(size: TLS_HELLO_RANDOM_LEN),
        selectedCipher,
        sessionId: clientHello.sessionId,
        compressionMethod: UInt8(0x00),
        extensions: [
            TlsExtension(TLS13_EXT_SUPPORTED_VERSIONS, tls13EncodeServerSupportedVersion()),
            TlsExtension(TLS13_EXT_KEY_SHARE, tls13EncodeServerX25519KeyShare(serverKeyShare))
        ],
        legacyVersion: TLS1_2
    )
    tlsEncodeServerHelloHandshake(hello)
}

/**
 * tls13BuildServerHelloForPsk.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildServerHelloForPsk(
    encodedClientHello: Array<Byte>,
    selectedIdentityIndex!: Int64 = 0
): Array<Byte> {
    if (selectedIdentityIndex < 0 || selectedIdentityIndex > 65535) {
        throw CryptoException(InvalidArgument, "TLS1.3 selected identity index must be uint16")
    }

    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    tls13RequireClientVersion(clientHello)
    let selectedCipher = tls13SelectCipherSuite(clientHello.cipherSuites)

    let pskExt = tls13RequireExtension(clientHello.extensions, TLS13_EXT_PRE_SHARED_KEY, "TLS1.3 client pre_shared_key")
    let identityCount = tls13CountClientPskIdentities(pskExt.data)
    if (identityCount == 0 || selectedIdentityIndex >= identityCount) {
        throw CryptoException(ParseError, "TLS1.3 selected PSK identity index is out of range")
    }
    _ = tls13RequireExtension(clientHello.extensions, TLS13_EXT_PSK_KEY_EXCHANGE_MODES, "TLS1.3 psk_key_exchange_modes")

    let hello = TlsServerHello(
        randomSeed(size: TLS_HELLO_RANDOM_LEN),
        selectedCipher,
        sessionId: clientHello.sessionId,
        compressionMethod: UInt8(0x00),
        extensions: [
            TlsExtension(TLS13_EXT_SUPPORTED_VERSIONS, tls13EncodeServerSupportedVersion()),
            TlsExtension(TLS13_EXT_PRE_SHARED_KEY, tls13EncodeSelectedIdentity(selectedIdentityIndex))
        ],
        legacyVersion: TLS1_2
    )
    tlsEncodeServerHelloHandshake(hello)
}

/**
 * tls13VerifyClientPskBinder.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13VerifyClientPskBinder(
    encodedClientHello: Array<Byte>,
    psk: Array<Byte>,
    selectedIdentityIndex!: Int64 = 0
): Bool {
    if (psk.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK must not be empty")
    }
    if (selectedIdentityIndex < 0 || selectedIdentityIndex > 65535) {
        throw CryptoException(InvalidArgument, "TLS1.3 selected identity index must be uint16")
    }

    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    let pskExt = tls13RequireExtension(clientHello.extensions, TLS13_EXT_PRE_SHARED_KEY, "TLS1.3 client pre_shared_key")
    let parsed = tls13ParseClientPreSharedKey(pskExt.data)
    if (selectedIdentityIndex >= parsed.identities.size || selectedIdentityIndex >= parsed.binders.size) {
        throw CryptoException(ParseError, "TLS1.3 selected PSK identity index is out of range")
    }

    let transcriptHash = tls13ComputePskBinderTranscriptHashFromHello(clientHello, parsed.identitiesRaw)
    let expectedBinder = tls13ComputePskBinder(psk, transcriptHash)
    let providedBinder = parsed.binders[selectedIdentityIndex]
    if (providedBinder.size != expectedBinder.size) {
        return false
    }
    constantTimeEquals(providedBinder, expectedBinder)
}

/**
 * tls13BuildServerHelloForPskWithBinder.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildServerHelloForPskWithBinder(
    encodedClientHello: Array<Byte>,
    psk: Array<Byte>,
    selectedIdentityIndex!: Int64 = 0
): Array<Byte> {
    let binderOk = tls13VerifyClientPskBinder(
        encodedClientHello,
        psk,
        selectedIdentityIndex: selectedIdentityIndex
    )
    if (!binderOk) {
        throw CryptoException(ParseError, "TLS1.3 PSK binder verification failed")
    }
    tls13BuildServerHelloForPsk(encodedClientHello, selectedIdentityIndex: selectedIdentityIndex)
}

/**
 * tls13BuildServerHelloForPskFromSessionTicket.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildServerHelloForPskFromSessionTicket(
    encodedClientHello: Array<Byte>,
    selectedIdentityIndex!: Int64 = 0,
    nowUnixSeconds!: Int64 = 0
): Array<Byte> {
    let identity = tls13ExtractClientPskIdentity(encodedClientHello, selectedIdentityIndex: selectedIdentityIndex)
    let ticket = tlsDecodeSessionTicket(identity)
    let now = if (nowUnixSeconds > 0) {
        nowUnixSeconds
    } else {
        1
    }
    if (ticket.isExpired(now)) {
        throw CryptoException(ParseError, "TLS1.3 PSK session ticket is expired")
    }
    tls13BuildServerHelloForPskWithBinder(
        encodedClientHello,
        ticket.secret,
        selectedIdentityIndex: selectedIdentityIndex
    )
}

public func tls13BuildServerHelloForPskBySessionTickets(
    encodedClientHello: Array<Byte>,
    nowUnixSeconds!: Int64 = 0
): Array<Byte> {
    let selectedIdentityIndex = tls13SelectPskIdentityFromSessionTickets(
        encodedClientHello,
        nowUnixSeconds: nowUnixSeconds
    )
    tls13BuildServerHelloForPskFromSessionTicket(
        encodedClientHello,
        selectedIdentityIndex: selectedIdentityIndex,
        nowUnixSeconds: nowUnixSeconds
    )
}

/**
 * tls13ExtractClientPskIdentity.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13ExtractClientPskIdentity(
    encodedClientHello: Array<Byte>,
    selectedIdentityIndex!: Int64 = 0
): Array<Byte> {
    if (selectedIdentityIndex < 0 || selectedIdentityIndex > 65535) {
        throw CryptoException(InvalidArgument, "TLS1.3 selected identity index must be uint16")
    }
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    let pskExt = tls13RequireExtension(clientHello.extensions, TLS13_EXT_PRE_SHARED_KEY, "TLS1.3 client pre_shared_key")
    let parsed = tls13ParseClientPreSharedKey(pskExt.data)
    if (selectedIdentityIndex >= parsed.identities.size) {
        throw CryptoException(ParseError, "TLS1.3 selected PSK identity index is out of range")
    }
    parsed.identities[selectedIdentityIndex]
}

public func tls13ExtractClientPskIdentities(encodedClientHello: Array<Byte>): Array<Tls13PskIdentityEntry> {
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    let pskExt = tls13RequireExtension(clientHello.extensions, TLS13_EXT_PRE_SHARED_KEY, "TLS1.3 client pre_shared_key")
    let parsed = tls13ParseClientPreSharedKey(pskExt.data)

    let entries = ArrayList<Tls13PskIdentityEntry>()
    var i = 0
    while (i < parsed.identities.size) {
        entries.add(
            Tls13PskIdentityEntry(
                parsed.identities[i],
                parsed.obfuscatedTicketAges[i],
                parsed.binders[i]
            )
        )
        i += 1
    }
    entries.toArray()
}

/**
 * tls13SelectPskIdentityFromSessionTickets.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13SelectPskIdentityFromSessionTickets(
    encodedClientHello: Array<Byte>,
    nowUnixSeconds!: Int64 = 0
): Int64 {
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    let pskExt = tls13RequireExtension(clientHello.extensions, TLS13_EXT_PRE_SHARED_KEY, "TLS1.3 client pre_shared_key")
    let parsed = tls13ParseClientPreSharedKey(pskExt.data)
    let transcriptHash = tls13ComputePskBinderTranscriptHashFromHello(clientHello, parsed.identitiesRaw)
    let now = if (nowUnixSeconds > 0) {
        nowUnixSeconds
    } else {
        1
    }

    var i = 0
    while (i < parsed.identities.size) {
        let ticketOpt = tls13TryDecodeSessionTicket(parsed.identities[i])
        if (let Some(ticket) <- ticketOpt) {
            if (!ticket.isExpired(now)) {
                let expectedBinder = tls13ComputePskBinder(ticket.secret, transcriptHash)
                let providedBinder = parsed.binders[i]
                let binderSizesMatch = providedBinder.size == expectedBinder.size
                let binderBytesMatch = constantTimeEquals(providedBinder, expectedBinder)
                if (binderSizesMatch && binderBytesMatch) {
                    return i
                }
            }
        }
        i += 1
    }
    throw CryptoException(ParseError, "TLS1.3 client did not offer a valid session ticket binder")
}

/**
 * tls13ExtractServerSelectedPskIdentity.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13ExtractServerSelectedPskIdentity(encodedServerHello: Array<Byte>): Int64 {
    let serverHello = tlsDecodeServerHelloHandshake(encodedServerHello)
    let ext = tls13RequireExtension(serverHello.extensions, TLS13_EXT_PRE_SHARED_KEY, "TLS1.3 server pre_shared_key")
    if (ext.data.size != 2) {
        throw CryptoException(ParseError, "TLS1.3 server selected_identity length is invalid")
    }
    tls13DecodeUInt16(ext.data, 0)
}

public func tls13ExtractClientKeyShare(encodedClientHello: Array<Byte>): EcPublicKey {
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    tls13ExtractClientKeyShareFromHello(clientHello)
}

public func tls13ExtractClientX25519KeyShare(encodedClientHello: Array<Byte>): Array<Byte> {
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    tls13ExtractClientX25519KeyShareFromHello(clientHello)
}

public func tls13ExtractServerKeyShare(encodedServerHello: Array<Byte>): EcPublicKey {
    let serverHello = tlsDecodeServerHelloHandshake(encodedServerHello)
    let ext = tls13RequireExtension(serverHello.extensions, TLS13_EXT_KEY_SHARE, "TLS1.3 server key_share")
    tls13DecodeServerKeyShare(ext.data)
}

public func tls13ExtractServerX25519KeyShare(encodedServerHello: Array<Byte>): Array<Byte> {
    let serverHello = tlsDecodeServerHelloHandshake(encodedServerHello)
    let ext = tls13RequireExtension(serverHello.extensions, TLS13_EXT_KEY_SHARE, "TLS1.3 server key_share")
    tls13DecodeServerX25519KeyShare(ext.data)
}

public func tls13BuildCertificateHandshakeFromDerChain(
    certChainDer: Array<Array<Byte>>,
    requestContext!: Array<Byte> = []
): Array<Byte> {
    let entries = ArrayList<TlsCertificateEntry>()
    for (der in certChainDer) {
        entries.add(TlsCertificateEntry(der))
    }
    tlsEncodeCertificateHandshakeTls13(Tls13CertificateMessage(requestContext: requestContext, entries: entries.toArray()))
}

/**
 * tls13ParseCertificateChainFromHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13ParseCertificateChainFromHandshake(encodedCertificate: Array<Byte>): Array<X509Certificate> {
    let message = tlsDecodeCertificateHandshakeTls13(encodedCertificate)
    if (message.entries.size == 0) {
        throw CryptoException(ParseError, "TLS13 certificate chain must not be empty")
    }
    let chain = ArrayList<X509Certificate>()
    for (entry in message.entries) {
        chain.add(x509ParseDer(entry.certData))
    }
    chain.toArray()
}

public func tls13VerifyCertificateChainFromHandshake(
    encodedCertificate: Array<Byte>,
    policy: X509VerificationPolicy
): X509VerificationResult {
    let chain = tls13ParseCertificateChainFromHandshake(encodedCertificate)
    let leaf = chain[0]
    let embeddedIntermediates: Array<X509Certificate> = if (chain.size > 1) {
        chain[1..]
    } else {
        []
    }
    let mergedPolicy = tls13MergePolicyIntermediates(policy, embeddedIntermediates)
    x509VerifyCertificateChain(leaf, mergedPolicy)
}

public func tls13VerifyCertificateChainFromHandshakeWithProfile(
    encodedCertificate: Array<Byte>,
    policy: X509VerificationPolicy,
    profile: FipsProfile
): X509VerificationResult {
    let chain = tls13ParseCertificateChainFromHandshake(encodedCertificate)
    let leaf = chain[0]
    let embeddedIntermediates: Array<X509Certificate> = if (chain.size > 1) {
        chain[1..]
    } else {
        []
    }
    let mergedPolicy = tls13MergePolicyIntermediates(policy, embeddedIntermediates)
    x509VerifyCertificateChainWithProfile(leaf, mergedPolicy, profile)
}

public func tls13BuildCertificateRequestHandshake(
    requestContext!: Array<Byte> = [],
    signatureSchemes!: Array<Int64> = [
        TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
        TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    ],
    certificateAuthorities!: Array<Array<Byte>> = []
): Array<Byte> {
    let normalizedSchemes = tls13NormalizeSignatureSchemes(signatureSchemes)
    let extensions = ArrayList<TlsExtension>()
    extensions.add(tls13EncodeSignatureAlgorithmsExtension(normalizedSchemes))
    if (certificateAuthorities.size > 0) {
        extensions.add(tls13EncodeCertificateAuthoritiesExtension(certificateAuthorities))
    }
    tlsEncodeCertificateRequestHandshakeTls13(
        Tls13CertificateRequestMessage(requestContext: requestContext, extensions: extensions.toArray())
    )
}

public func tls13DecodeCertificateRequestHandshake(
    encodedCertificateRequest: Array<Byte>
): Tls13CertificateRequestParameters {
    let message = tlsDecodeCertificateRequestHandshakeTls13(encodedCertificateRequest)
    let sigExt = tls13RequireExtension(
        message.extensions,
        TLS13_EXT_SIGNATURE_ALGORITHMS,
        "TLS1.3 CertificateRequest signature_algorithms"
    )
    let signatureSchemes = tls13ParseSignatureAlgorithmsExtension(sigExt)
    var certificateAuthorities: Array<Array<Byte>> = []
    if (let Some(authorityExt) <- tlsFindExtension(message.extensions, TLS13_EXT_CERTIFICATE_AUTHORITIES)) {
        certificateAuthorities = tls13ParseCertificateAuthoritiesExtension(authorityExt)
    }
    Tls13CertificateRequestParameters(
        message.requestContext,
        signatureSchemes,
        certificateAuthorities: certificateAuthorities,
        extensions: message.extensions
    )
}

public func tls13BuildClientAuthRequestForServerContext(
    context: Tls13ServerHandshakeContext,
    requestContext!: Array<Byte> = [],
    signatureSchemes!: Array<Int64> = [
        TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
        TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    ],
    certificateAuthorities!: Array<Array<Byte>> = []
): Tls13ServerClientAuthContext {
    let encodedCertificateRequest = tls13BuildCertificateRequestHandshake(
        requestContext: requestContext,
        signatureSchemes: signatureSchemes,
        certificateAuthorities: certificateAuthorities
    )
    let request = tls13DecodeCertificateRequestHandshake(encodedCertificateRequest)
    Tls13ServerClientAuthContext(
        context,
        encodedCertificateRequest,
        request
    )
}

public func tls13ProcessClientAuthFlightForServerContext(
    context: Tls13ServerClientAuthContext,
    clientAuthFlight: Tls13AuthFlight,
    policy: X509VerificationPolicy,
    profile!: ?FipsProfile = None
): X509VerificationResult {
    let transcriptHash = context.serverContext.flight.transcriptHash
    let clientHsTrafficSecret = context.serverContext.secrets.clientHsTrafficSecret
    if (let Some(activeProfile) <- profile) {
        return tls13VerifyClientAuthFlightForCertificateRequestWithProfile(
            clientAuthFlight,
            context.encodedCertificateRequest,
            policy,
            transcriptHash,
            clientHsTrafficSecret,
            activeProfile
        )
    }
    tls13VerifyClientAuthFlightForCertificateRequest(
        clientAuthFlight,
        context.encodedCertificateRequest,
        policy,
        transcriptHash,
        clientHsTrafficSecret
    )
}

/**
 * tls13ProcessClientAuthFlightForServerContextWithRequirement.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13ProcessClientAuthFlightForServerContextWithRequirement(
    context: Tls13ServerClientAuthContext,
    policy: X509VerificationPolicy,
    clientAuthFlight!: ?Tls13AuthFlight = None,
    requireClientCertificate!: Bool = true,
    profile!: ?FipsProfile = None
): ?X509VerificationResult {
    if (let Some(flight) <- clientAuthFlight) {
        return Some(
            tls13ProcessClientAuthFlightForServerContext(
                context,
                flight,
                policy,
                profile: profile
            )
        )
    }
    if (requireClientCertificate) {
        throw CryptoException(ParseError, "TLS1.3 server context requires client authentication flight")
    }
    None
}

public func tls13BuildEncryptedExtensions(
    selectedAlpn!: String = "",
    acknowledgeServerName!: Bool = false
): Array<Byte> {
    let extensions = ArrayList<TlsExtension>()
    let normalizedAlpn = selectedAlpn.trimAscii()
    if (normalizedAlpn.size > 0) {
        extensions.add(tlsBuildAlpnExtension([normalizedAlpn]))
    }
    if (acknowledgeServerName) {
        extensions.add(TlsExtension(TLS_EXT_SERVER_NAME, []))
    }
    tlsEncodeEncryptedExtensionsHandshake(TlsEncryptedExtensionsMessage(extensions: extensions.toArray()))
}

/**
 * tls13DecodeEncryptedExtensionsSummary.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13DecodeEncryptedExtensionsSummary(encodedEncryptedExtensions: Array<Byte>): (String, Bool) {
    let message = tlsDecodeEncryptedExtensionsHandshake(encodedEncryptedExtensions)
    var selectedAlpn = ""
    var acknowledgedServerName = false

    for (ext in message.extensions) {
        if (ext.extType == TLS_EXT_ALPN) {
            let protocols = tlsParseAlpnExtension(ext)
            if (protocols.size == 0) {
                throw CryptoException(ParseError, "TLS1.3 ALPN extension must carry one selected protocol")
            }
            selectedAlpn = protocols[0]
            continue
        }
        if (ext.extType == TLS_EXT_SERVER_NAME) {
            if (ext.data.size != 0) {
                throw CryptoException(ParseError, "TLS1.3 server_name EncryptedExtensions payload must be empty")
            }
            acknowledgedServerName = true
        }
    }
    (selectedAlpn, acknowledgedServerName)
}

public func tls13SelectAlpnFromClientHello(encodedClientHello: Array<Byte>, serverPreference: Array<String>): String {
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    tls13SelectAlpnFromHello(clientHello, serverPreference)
}

public func tls13ExtractClientServerName(encodedClientHello: Array<Byte>): String {
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    if (let Some(ext) <- tlsFindExtension(clientHello.extensions, TLS_EXT_SERVER_NAME)) {
        let names = tlsParseServerNameExtension(ext)
        if (names.size > 0) {
            return names[0]
        }
    }
    ""
}

/**
 * tls13BuildServerHandshakeContextEcdheP256.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildServerHandshakeContextEcdheP256(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: EcPrivateKey,
    serverKeyShare: EcPublicKey,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    alpnPreference!: Array<String> = [],
    acknowledgeServerName!: Bool = true
): Tls13ServerHandshakeContext {
    if (serverKeyExchangePrivate.curve != P256 || serverKeyShare.curve != P256) {
        throw CryptoException(InvalidArgument, "TLS1.3 ECDHE-P256 context requires P-256 key exchange keys")
    }
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    let selectedAlpn = tls13SelectAlpnFromHello(clientHello, alpnPreference)
    let requestedServerName = tls13ExtractServerNameFromHello(clientHello)
    let shouldAckServerName = acknowledgeServerName && requestedServerName.size > 0

    let serverHello = tls13BuildServerHelloForEcdhe(encodedClientHello, serverKeyShare)
    let serverHelloMessage = tlsDecodeServerHelloHandshake(serverHello)
    let (keyLen, ivLen) = tls13KeyIvLensFromCipherSuite(serverHelloMessage.cipherSuite)
    let encryptedExtensions = tls13BuildEncryptedExtensions(
        selectedAlpn: selectedAlpn,
        acknowledgeServerName: shouldAckServerName
    )
    let transcriptHash = sha256(concat(concat(encodedClientHello, serverHello), encryptedExtensions))
    let clientPublicKey = tls13ExtractClientKeyShare(encodedClientHello)
    let firstSecrets = tls13DeriveSecretsFromEcdhe(
        serverKeyExchangePrivate,
        clientPublicKey,
        transcriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )
    let authFlight = tls13BuildServerAuthFlightBySigner(
        certChainDer,
        transcriptHash,
        firstSecrets.serverHsTrafficSecret,
        certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa
    )

    // RFC 8446 §7.1: application traffic keys use Transcript-Hash(Hello…Finished)
    let fullTranscriptHash = sha256(concat(concat(concat(concat(concat(
        encodedClientHello, serverHello), encryptedExtensions),
        authFlight.certificateHandshake), authFlight.certificateVerifyHandshake),
        authFlight.finishedHandshake))
    let secrets = tls13DeriveSecretsFromEcdhe(
        serverKeyExchangePrivate,
        clientPublicKey,
        transcriptHash,
        appTranscriptHash: fullTranscriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )

    let flight = Tls13ServerHandshakeFlight(
        serverHello,
        encryptedExtensions,
        authFlight,
        transcriptHash,
        selectedAlpn: selectedAlpn,
        requestedServerName: requestedServerName,
        acknowledgedServerName: shouldAckServerName
    )
    Tls13ServerHandshakeContext(flight, secrets)
}

/**
 * tls13BuildServerHandshakeContextEcdheP384.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildServerHandshakeContextEcdheP384(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: EcPrivateKey,
    serverKeyShare: EcPublicKey,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    alpnPreference!: Array<String> = [],
    acknowledgeServerName!: Bool = true
): Tls13ServerHandshakeContext {
    if (serverKeyExchangePrivate.curve != P384 || serverKeyShare.curve != P384) {
        throw CryptoException(InvalidArgument, "TLS1.3 ECDHE-P384 context requires P-384 key exchange keys")
    }
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    let selectedAlpn = tls13SelectAlpnFromHello(clientHello, alpnPreference)
    let requestedServerName = tls13ExtractServerNameFromHello(clientHello)
    let shouldAckServerName = acknowledgeServerName && requestedServerName.size > 0

    let serverHello = tls13BuildServerHelloForEcdhe(encodedClientHello, serverKeyShare)
    let serverHelloMessage = tlsDecodeServerHelloHandshake(serverHello)
    let (keyLen, ivLen) = tls13KeyIvLensFromCipherSuite(serverHelloMessage.cipherSuite)
    let encryptedExtensions = tls13BuildEncryptedExtensions(
        selectedAlpn: selectedAlpn,
        acknowledgeServerName: shouldAckServerName
    )
    let transcriptHash = sha256(concat(concat(encodedClientHello, serverHello), encryptedExtensions))
    let clientPublicKey = tls13ExtractClientKeyShare(encodedClientHello)
    let firstSecrets = tls13DeriveSecretsFromEcdhe(
        serverKeyExchangePrivate,
        clientPublicKey,
        transcriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )
    let authFlight = tls13BuildServerAuthFlightBySigner(
        certChainDer,
        transcriptHash,
        firstSecrets.serverHsTrafficSecret,
        certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa
    )

    // RFC 8446 §7.1: application traffic keys use Transcript-Hash(Hello…Finished)
    let fullTranscriptHash = sha256(concat(concat(concat(concat(concat(
        encodedClientHello, serverHello), encryptedExtensions),
        authFlight.certificateHandshake), authFlight.certificateVerifyHandshake),
        authFlight.finishedHandshake))
    let secrets = tls13DeriveSecretsFromEcdhe(
        serverKeyExchangePrivate,
        clientPublicKey,
        transcriptHash,
        appTranscriptHash: fullTranscriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )

    let flight = Tls13ServerHandshakeFlight(
        serverHello,
        encryptedExtensions,
        authFlight,
        transcriptHash,
        selectedAlpn: selectedAlpn,
        requestedServerName: requestedServerName,
        acknowledgedServerName: shouldAckServerName
    )
    Tls13ServerHandshakeContext(flight, secrets)
}

public func tls13BuildServerHandshakeContextX25519(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    serverKeyShare: Array<Byte>,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    alpnPreference!: Array<String> = [],
    acknowledgeServerName!: Bool = true
): Tls13ServerHandshakeContext {
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    let selectedAlpn = tls13SelectAlpnFromHello(clientHello, alpnPreference)
    let requestedServerName = tls13ExtractServerNameFromHello(clientHello)
    let shouldAckServerName = acknowledgeServerName && requestedServerName.size > 0

    let serverHello = tls13BuildServerHelloForX25519(encodedClientHello, serverKeyShare)
    let serverHelloMessage = tlsDecodeServerHelloHandshake(serverHello)
    let (keyLen, ivLen) = tls13KeyIvLensFromCipherSuite(serverHelloMessage.cipherSuite)
    let encryptedExtensions = tls13BuildEncryptedExtensions(
        selectedAlpn: selectedAlpn,
        acknowledgeServerName: shouldAckServerName
    )
    let transcriptHash = sha256(concat(concat(encodedClientHello, serverHello), encryptedExtensions))
    let clientPublicKey = tls13ExtractClientX25519KeyShare(encodedClientHello)
    let firstSecrets = tls13DeriveSecretsFromX25519(
        serverKeyExchangePrivate,
        clientPublicKey,
        transcriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )
    let authFlight = tls13BuildServerAuthFlightBySigner(
        certChainDer,
        transcriptHash,
        firstSecrets.serverHsTrafficSecret,
        certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa
    )

    // RFC 8446 §7.1: application traffic keys use Transcript-Hash(Hello…Finished)
    let fullTranscriptHash = sha256(concat(concat(concat(concat(concat(
        encodedClientHello, serverHello), encryptedExtensions),
        authFlight.certificateHandshake), authFlight.certificateVerifyHandshake),
        authFlight.finishedHandshake))
    let secrets = tls13DeriveSecretsFromX25519(
        serverKeyExchangePrivate,
        clientPublicKey,
        transcriptHash,
        appTranscriptHash: fullTranscriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )

    let flight = Tls13ServerHandshakeFlight(
        serverHello,
        encryptedExtensions,
        authFlight,
        transcriptHash,
        selectedAlpn: selectedAlpn,
        requestedServerName: requestedServerName,
        acknowledgedServerName: shouldAckServerName
    )
    Tls13ServerHandshakeContext(flight, secrets)
}

public func tls13BuildServerClientAuthContextEcdheP256(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: EcPrivateKey,
    serverKeyShare: EcPublicKey,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    alpnPreference!: Array<String> = [],
    acknowledgeServerName!: Bool = true,
    requestContext!: Array<Byte> = [],
    signatureSchemes!: Array<Int64> = [
        TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
        TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    ],
    certificateAuthorities!: Array<Array<Byte>> = []
): Tls13ServerClientAuthContext {
    let context = tls13BuildServerHandshakeContextEcdheP256(
        encodedClientHello,
        serverKeyExchangePrivate,
        serverKeyShare,
        certChainDer,
        certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa: certificatePrivateKeyRsa,
        alpnPreference: alpnPreference,
        acknowledgeServerName: acknowledgeServerName
    )
    tls13BuildClientAuthRequestForServerContext(
        context,
        requestContext: requestContext,
        signatureSchemes: signatureSchemes,
        certificateAuthorities: certificateAuthorities
    )
}

public func tls13BuildServerClientAuthContextEcdheP384(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: EcPrivateKey,
    serverKeyShare: EcPublicKey,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    alpnPreference!: Array<String> = [],
    acknowledgeServerName!: Bool = true,
    requestContext!: Array<Byte> = [],
    signatureSchemes!: Array<Int64> = [
        TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
        TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    ],
    certificateAuthorities!: Array<Array<Byte>> = []
): Tls13ServerClientAuthContext {
    let context = tls13BuildServerHandshakeContextEcdheP384(
        encodedClientHello,
        serverKeyExchangePrivate,
        serverKeyShare,
        certChainDer,
        certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa: certificatePrivateKeyRsa,
        alpnPreference: alpnPreference,
        acknowledgeServerName: acknowledgeServerName
    )
    tls13BuildClientAuthRequestForServerContext(
        context,
        requestContext: requestContext,
        signatureSchemes: signatureSchemes,
        certificateAuthorities: certificateAuthorities
    )
}

public func tls13BuildServerClientAuthContextX25519(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    serverKeyShare: Array<Byte>,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    alpnPreference!: Array<String> = [],
    acknowledgeServerName!: Bool = true,
    requestContext!: Array<Byte> = [],
    signatureSchemes!: Array<Int64> = [
        TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
        TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    ],
    certificateAuthorities!: Array<Array<Byte>> = []
): Tls13ServerClientAuthContext {
    let context = tls13BuildServerHandshakeContextX25519(
        encodedClientHello,
        serverKeyExchangePrivate,
        serverKeyShare,
        certChainDer,
        certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa: certificatePrivateKeyRsa,
        alpnPreference: alpnPreference,
        acknowledgeServerName: acknowledgeServerName
    )
    tls13BuildClientAuthRequestForServerContext(
        context,
        requestContext: requestContext,
        signatureSchemes: signatureSchemes,
        certificateAuthorities: certificateAuthorities
    )
}

/**
 * tls13ProcessServerHandshakeFlightEcdheP256.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13ProcessServerHandshakeFlightEcdheP256(
    encodedClientHello: Array<Byte>,
    clientKeyExchangePrivate: EcPrivateKey,
    flight: Tls13ServerHandshakeFlight,
    policy: X509VerificationPolicy,
    profile!: ?FipsProfile = None
): Tls13ClientHandshakeResult {
    if (clientKeyExchangePrivate.curve != P256) {
        throw CryptoException(InvalidArgument, "TLS1.3 ECDHE-P256 client context requires P-256 private key")
    }
    let transcriptHash = sha256(concat(concat(encodedClientHello, flight.serverHello), flight.encryptedExtensions))
    if (!constantTimeEquals(transcriptHash, flight.transcriptHash)) {
        throw CryptoException(ParseError, "TLS1.3 transcript hash mismatch in server handshake flight")
    }

    // RFC 8446 §7.1: application traffic keys use Transcript-Hash(Hello…Finished)
    let fullTranscriptHash = sha256(concat(concat(concat(concat(concat(
        encodedClientHello, flight.serverHello), flight.encryptedExtensions),
        flight.authFlight.certificateHandshake), flight.authFlight.certificateVerifyHandshake),
        flight.authFlight.finishedHandshake))

    let serverHello = tlsDecodeServerHelloHandshake(flight.serverHello)
    let (keyLen, ivLen) = tls13KeyIvLensFromCipherSuite(serverHello.cipherSuite)
    let serverPublicKey = tls13ExtractServerKeyShare(flight.serverHello)
    let secrets = tls13DeriveSecretsFromEcdhe(
        clientKeyExchangePrivate,
        serverPublicKey,
        transcriptHash,
        appTranscriptHash: fullTranscriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )
    let verification = tls13VerifyServerAuthFlightWithOptionalProfile(
        flight.authFlight,
        policy,
        transcriptHash,
        secrets.serverHsTrafficSecret,
        profile
    )
    let (selectedAlpn, acknowledgedServerName) = tls13DecodeEncryptedExtensionsSummary(flight.encryptedExtensions)
    Tls13ClientHandshakeResult(
        secrets,
        verification,
        selectedAlpn: selectedAlpn,
        requestedServerName: flight.requestedServerName,
        acknowledgedServerName: acknowledgedServerName
    )
}

/**
 * tls13ProcessServerHandshakeFlightEcdheP384.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13ProcessServerHandshakeFlightEcdheP384(
    encodedClientHello: Array<Byte>,
    clientKeyExchangePrivate: EcPrivateKey,
    flight: Tls13ServerHandshakeFlight,
    policy: X509VerificationPolicy,
    profile!: ?FipsProfile = None
): Tls13ClientHandshakeResult {
    if (clientKeyExchangePrivate.curve != P384) {
        throw CryptoException(InvalidArgument, "TLS1.3 ECDHE-P384 client context requires P-384 private key")
    }
    let transcriptHash = sha256(concat(concat(encodedClientHello, flight.serverHello), flight.encryptedExtensions))
    if (!constantTimeEquals(transcriptHash, flight.transcriptHash)) {
        throw CryptoException(ParseError, "TLS1.3 transcript hash mismatch in server handshake flight")
    }

    // RFC 8446 §7.1: application traffic keys use Transcript-Hash(Hello…Finished)
    let fullTranscriptHash = sha256(concat(concat(concat(concat(concat(
        encodedClientHello, flight.serverHello), flight.encryptedExtensions),
        flight.authFlight.certificateHandshake), flight.authFlight.certificateVerifyHandshake),
        flight.authFlight.finishedHandshake))

    let serverHello = tlsDecodeServerHelloHandshake(flight.serverHello)
    let (keyLen, ivLen) = tls13KeyIvLensFromCipherSuite(serverHello.cipherSuite)
    let serverPublicKey = tls13ExtractServerKeyShare(flight.serverHello)
    let secrets = tls13DeriveSecretsFromEcdhe(
        clientKeyExchangePrivate,
        serverPublicKey,
        transcriptHash,
        appTranscriptHash: fullTranscriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )
    let verification = tls13VerifyServerAuthFlightWithOptionalProfile(
        flight.authFlight,
        policy,
        transcriptHash,
        secrets.serverHsTrafficSecret,
        profile
    )
    let (selectedAlpn, acknowledgedServerName) = tls13DecodeEncryptedExtensionsSummary(flight.encryptedExtensions)
    Tls13ClientHandshakeResult(
        secrets,
        verification,
        selectedAlpn: selectedAlpn,
        requestedServerName: flight.requestedServerName,
        acknowledgedServerName: acknowledgedServerName
    )
}

/**
 * tls13ProcessServerHandshakeFlightX25519.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13ProcessServerHandshakeFlightX25519(
    encodedClientHello: Array<Byte>,
    clientKeyExchangePrivate: Array<Byte>,
    flight: Tls13ServerHandshakeFlight,
    policy: X509VerificationPolicy,
    profile!: ?FipsProfile = None
): Tls13ClientHandshakeResult {
    let transcriptHash = sha256(concat(concat(encodedClientHello, flight.serverHello), flight.encryptedExtensions))
    if (!constantTimeEquals(transcriptHash, flight.transcriptHash)) {
        throw CryptoException(ParseError, "TLS1.3 transcript hash mismatch in server handshake flight")
    }

    // RFC 8446 §7.1: application traffic keys use Transcript-Hash(Hello…Finished)
    let fullTranscriptHash = sha256(concat(concat(concat(concat(concat(
        encodedClientHello, flight.serverHello), flight.encryptedExtensions),
        flight.authFlight.certificateHandshake), flight.authFlight.certificateVerifyHandshake),
        flight.authFlight.finishedHandshake))

    let serverHello = tlsDecodeServerHelloHandshake(flight.serverHello)
    let (keyLen, ivLen) = tls13KeyIvLensFromCipherSuite(serverHello.cipherSuite)
    let serverPublicKey = tls13ExtractServerX25519KeyShare(flight.serverHello)
    let secrets = tls13DeriveSecretsFromX25519(
        clientKeyExchangePrivate,
        serverPublicKey,
        transcriptHash,
        appTranscriptHash: fullTranscriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )
    let verification = tls13VerifyServerAuthFlightWithOptionalProfile(
        flight.authFlight,
        policy,
        transcriptHash,
        secrets.serverHsTrafficSecret,
        profile
    )
    let (selectedAlpn, acknowledgedServerName) = tls13DecodeEncryptedExtensionsSummary(flight.encryptedExtensions)
    Tls13ClientHandshakeResult(
        secrets,
        verification,
        selectedAlpn: selectedAlpn,
        requestedServerName: flight.requestedServerName,
        acknowledgedServerName: acknowledgedServerName
    )
}

public func tls13BuildServerAuthFlightEcdsa(
    certChainDer: Array<Array<Byte>>,
    privateKey: EcPrivateKey,
    transcriptHash: Array<Byte>,
    serverHsTrafficSecret: Array<Byte>,
    requestContext!: Array<Byte> = []
): Tls13AuthFlight {
    let certificate = tls13BuildCertificateHandshakeFromDerChain(certChainDer, requestContext: requestContext)
    let certificateVerify = tls13BuildServerCertificateVerifyEcdsa(privateKey, transcriptHash)
    let finished = tlsEncodeFinishedHandshake(tls13ComputeFinishedVerifyData(serverHsTrafficSecret, transcriptHash))
    Tls13AuthFlight(Tls13AuthFlightRole.SERVER, certificate, certificateVerify, finished)
}

public func tls13BuildServerAuthFlightRsaPss(
    certChainDer: Array<Array<Byte>>,
    privateKey: RsaPrivateKey,
    transcriptHash: Array<Byte>,
    serverHsTrafficSecret: Array<Byte>,
    requestContext!: Array<Byte> = []
): Tls13AuthFlight {
    let certificate = tls13BuildCertificateHandshakeFromDerChain(certChainDer, requestContext: requestContext)
    let certificateVerify = tls13BuildServerCertificateVerifyRsaPss(privateKey, transcriptHash)
    let finished = tlsEncodeFinishedHandshake(tls13ComputeFinishedVerifyData(serverHsTrafficSecret, transcriptHash))
    Tls13AuthFlight(Tls13AuthFlightRole.SERVER, certificate, certificateVerify, finished)
}

public func tls13BuildClientAuthFlightEcdsa(
    certChainDer: Array<Array<Byte>>,
    privateKey: EcPrivateKey,
    transcriptHash: Array<Byte>,
    clientHsTrafficSecret: Array<Byte>,
    requestContext!: Array<Byte> = []
): Tls13AuthFlight {
    let certificate = tls13BuildCertificateHandshakeFromDerChain(certChainDer, requestContext: requestContext)
    let certificateVerify = tls13BuildClientCertificateVerifyEcdsa(privateKey, transcriptHash)
    let finished = tlsEncodeFinishedHandshake(tls13ComputeFinishedVerifyData(clientHsTrafficSecret, transcriptHash))
    Tls13AuthFlight(Tls13AuthFlightRole.CLIENT, certificate, certificateVerify, finished)
}

public func tls13BuildClientAuthFlightRsaPss(
    certChainDer: Array<Array<Byte>>,
    privateKey: RsaPrivateKey,
    transcriptHash: Array<Byte>,
    clientHsTrafficSecret: Array<Byte>,
    requestContext!: Array<Byte> = []
): Tls13AuthFlight {
    let certificate = tls13BuildCertificateHandshakeFromDerChain(certChainDer, requestContext: requestContext)
    let certificateVerify = tls13BuildClientCertificateVerifyRsaPss(privateKey, transcriptHash)
    let finished = tlsEncodeFinishedHandshake(tls13ComputeFinishedVerifyData(clientHsTrafficSecret, transcriptHash))
    Tls13AuthFlight(Tls13AuthFlightRole.CLIENT, certificate, certificateVerify, finished)
}

/**
 * tls13BuildClientAuthFlightForCertificateRequest.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildClientAuthFlightForCertificateRequest(
    certChainDer: Array<Array<Byte>>,
    encodedCertificateRequest: Array<Byte>,
    transcriptHash: Array<Byte>,
    clientHsTrafficSecret: Array<Byte>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None
): Tls13AuthFlight {
    if (certChainDer.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 client auth flight requires non-empty certificate chain")
    }
    let request = tls13DecodeCertificateRequestHandshake(encodedCertificateRequest)
    let leaf = x509ParseDer(certChainDer[0])
    if (
        request.certificateAuthorities.size > 0 &&
        !tls13ContainsDistinguishedName(request.certificateAuthorities, leaf.issuer.der)
    ) {
        throw CryptoException(ParseError, "TLS1.3 CertificateRequest certificate_authorities rejected client leaf issuer")
    }

    var leafEcCurve: ?NamedCurve = None
    try {
        let ecPublicKey = x509ExtractEcPublicKey(leaf)
        leafEcCurve = Some(ecPublicKey.curve)
    } catch (_: CryptoException) {
        ()
    }

    var supportsRsaLeaf = false
    try {
        _ = x509ExtractRsaPublicKey(leaf)
        supportsRsaLeaf = true
    } catch (_: CryptoException) {
        ()
    }

    for (scheme in request.signatureSchemes) {
        if (scheme == TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256) {
            if (let Some(leafCurve) <- leafEcCurve) {
                if (leafCurve == P256) {
                    if (let Some(privateKey) <- certificatePrivateKeyEcdsa) {
                        if (privateKey.curve == P256) {
                            return tls13BuildClientAuthFlightEcdsa(
                                certChainDer,
                                privateKey,
                                transcriptHash,
                                clientHsTrafficSecret,
                                requestContext: request.requestContext
                            )
                        }
                    }
                }
            }
        }

        if (scheme == TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384) {
            if (let Some(leafCurve) <- leafEcCurve) {
                if (leafCurve == P384) {
                    if (let Some(privateKey) <- certificatePrivateKeyEcdsa) {
                        if (privateKey.curve == P384) {
                            return tls13BuildClientAuthFlightEcdsa(
                                certChainDer,
                                privateKey,
                                transcriptHash,
                                clientHsTrafficSecret,
                                requestContext: request.requestContext
                            )
                        }
                    }
                }
            }
        }

        if (scheme == TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256 && supportsRsaLeaf) {
            if (let Some(privateKey) <- certificatePrivateKeyRsa) {
                return tls13BuildClientAuthFlightRsaPss(
                    certChainDer,
                    privateKey,
                    transcriptHash,
                    clientHsTrafficSecret,
                    requestContext: request.requestContext
                )
            }
        }
    }

    throw CryptoException(
        Unsupported,
        "TLS1.3 CertificateRequest has no signature scheme/private key match for client authentication"
    )
}

/**
 * tls13VerifyServerAuthFlight.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13VerifyServerAuthFlight(
    flight: Tls13AuthFlight,
    policy: X509VerificationPolicy,
    transcriptHash: Array<Byte>,
    serverHsTrafficSecret: Array<Byte>
): X509VerificationResult {
    if (flight.role != Tls13AuthFlightRole.SERVER) {
        throw CryptoException(InvalidArgument, "TLS1.3 auth flight role mismatch: expected SERVER")
    }
    let verification = tls13VerifyCertificateChainFromHandshake(flight.certificateHandshake, policy)
    tls13VerifyAuthFlightIntegrity(
        flight,
        verification.chain[0],
        transcriptHash,
        serverHsTrafficSecret
    )
    verification
}

/**
 * tls13VerifyServerAuthFlightWithProfile.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13VerifyServerAuthFlightWithProfile(
    flight: Tls13AuthFlight,
    policy: X509VerificationPolicy,
    transcriptHash: Array<Byte>,
    serverHsTrafficSecret: Array<Byte>,
    profile: FipsProfile
): X509VerificationResult {
    if (flight.role != Tls13AuthFlightRole.SERVER) {
        throw CryptoException(InvalidArgument, "TLS1.3 auth flight role mismatch: expected SERVER")
    }
    let verification = tls13VerifyCertificateChainFromHandshakeWithProfile(flight.certificateHandshake, policy, profile)
    tls13VerifyAuthFlightIntegrity(
        flight,
        verification.chain[0],
        transcriptHash,
        serverHsTrafficSecret
    )
    verification
}

/**
 * tls13VerifyClientAuthFlight.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13VerifyClientAuthFlight(
    flight: Tls13AuthFlight,
    policy: X509VerificationPolicy,
    transcriptHash: Array<Byte>,
    clientHsTrafficSecret: Array<Byte>
): X509VerificationResult {
    if (flight.role != Tls13AuthFlightRole.CLIENT) {
        throw CryptoException(InvalidArgument, "TLS1.3 auth flight role mismatch: expected CLIENT")
    }
    let verification = tls13VerifyCertificateChainFromHandshake(flight.certificateHandshake, policy)
    tls13VerifyAuthFlightIntegrity(
        flight,
        verification.chain[0],
        transcriptHash,
        clientHsTrafficSecret
    )
    verification
}

/**
 * tls13VerifyClientAuthFlightWithProfile.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13VerifyClientAuthFlightWithProfile(
    flight: Tls13AuthFlight,
    policy: X509VerificationPolicy,
    transcriptHash: Array<Byte>,
    clientHsTrafficSecret: Array<Byte>,
    profile: FipsProfile
): X509VerificationResult {
    if (flight.role != Tls13AuthFlightRole.CLIENT) {
        throw CryptoException(InvalidArgument, "TLS1.3 auth flight role mismatch: expected CLIENT")
    }
    let verification = tls13VerifyCertificateChainFromHandshakeWithProfile(flight.certificateHandshake, policy, profile)
    tls13VerifyAuthFlightIntegrity(
        flight,
        verification.chain[0],
        transcriptHash,
        clientHsTrafficSecret
    )
    verification
}

public func tls13VerifyClientAuthFlightForCertificateRequest(
    flight: Tls13AuthFlight,
    encodedCertificateRequest: Array<Byte>,
    policy: X509VerificationPolicy,
    transcriptHash: Array<Byte>,
    clientHsTrafficSecret: Array<Byte>
): X509VerificationResult {
    let request = tls13DecodeCertificateRequestHandshake(encodedCertificateRequest)
    tls13RequireClientAuthFlightMatchesCertificateRequest(flight, request)
    tls13VerifyClientAuthFlight(flight, policy, transcriptHash, clientHsTrafficSecret)
}

public func tls13VerifyClientAuthFlightForCertificateRequestWithProfile(
    flight: Tls13AuthFlight,
    encodedCertificateRequest: Array<Byte>,
    policy: X509VerificationPolicy,
    transcriptHash: Array<Byte>,
    clientHsTrafficSecret: Array<Byte>,
    profile: FipsProfile
): X509VerificationResult {
    let request = tls13DecodeCertificateRequestHandshake(encodedCertificateRequest)
    tls13RequireClientAuthFlightMatchesCertificateRequest(flight, request)
    tls13VerifyClientAuthFlightWithProfile(
        flight,
        policy,
        transcriptHash,
        clientHsTrafficSecret,
        profile
    )
}

public func tls13BuildServerCertificateVerifyEcdsa(
    privateKey: EcPrivateKey,
    transcriptHash: Array<Byte>
): Array<Byte> {
    tls13BuildCertificateVerifyEcdsa(privateKey, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_SERVER)
}

public func tls13BuildClientCertificateVerifyEcdsa(
    privateKey: EcPrivateKey,
    transcriptHash: Array<Byte>
): Array<Byte> {
    tls13BuildCertificateVerifyEcdsa(privateKey, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_CLIENT)
}

public func tls13BuildServerCertificateVerifyRsaPss(
    privateKey: RsaPrivateKey,
    transcriptHash: Array<Byte>
): Array<Byte> {
    tls13BuildCertificateVerifyRsaPss(privateKey, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_SERVER)
}

public func tls13BuildClientCertificateVerifyRsaPss(
    privateKey: RsaPrivateKey,
    transcriptHash: Array<Byte>
): Array<Byte> {
    tls13BuildCertificateVerifyRsaPss(privateKey, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_CLIENT)
}

public func tls13VerifyServerCertificateVerify(
    encodedCertificateVerify: Array<Byte>,
    certificate: X509Certificate,
    transcriptHash: Array<Byte>
): Bool {
    tls13VerifyCertificateVerify(encodedCertificateVerify, certificate, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_SERVER)
}

public func tls13VerifyClientCertificateVerify(
    encodedCertificateVerify: Array<Byte>,
    certificate: X509Certificate,
    transcriptHash: Array<Byte>
): Bool {
    tls13VerifyCertificateVerify(encodedCertificateVerify, certificate, transcriptHash, TLS13_CERT_VERIFY_CONTEXT_CLIENT)
}

/**
 * tls13DeriveSecretsFromEcdhe.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13DeriveSecretsFromEcdhe(
    privateKey: EcPrivateKey,
    peerPublicKey: EcPublicKey,
    transcriptHash: Array<Byte>,
    keyLen!: Int64 = TLS13_DEFAULT_AEAD_KEY_LEN,
    ivLen!: Int64 = TLS13_DEFAULT_AEAD_IV_LEN,
    appTranscriptHash!: Array<Byte> = []   // RFC 8446 §7.1: override for app traffic keys
): Tls13HandshakeSecrets {
    if (privateKey.curve != peerPublicKey.curve) {
        throw CryptoException(InvalidArgument, "TLS1.3 ECDHE key curve mismatch")
    }
    tls13RequireSupportedEcdheCurve(privateKey.curve)
    tls13RequireHashAndLengths(transcriptHash, keyLen, ivLen)

    let sharedSecret = ecdhDeriveSharedSecret(privateKey, peerPublicKey)
    let zeros = Array<Byte>(TLS13_HASH_LEN, repeat: 0)
    let emptyHash = sha256([])

    let earlySecret = tls13HkdfExtract(zeros, zeros)
    let derivedEarly = tls13DeriveSecret(earlySecret, "derived", emptyHash)
    let handshakeSecret = tls13HkdfExtract(derivedEarly, sharedSecret)
    tls13BuildSecretsFromStages(earlySecret, handshakeSecret, transcriptHash, keyLen, ivLen, appTranscriptHash: appTranscriptHash)
}

public func tls13DeriveSecretsFromEcdheForCipherSuite(
    privateKey: EcPrivateKey,
    peerPublicKey: EcPublicKey,
    transcriptHash: Array<Byte>,
    cipherSuite: Int64,
    appTranscriptHash!: Array<Byte> = []
): Tls13HandshakeSecrets {
    let (keyLen, ivLen) = tls13KeyIvLensFromCipherSuite(cipherSuite)
    tls13DeriveSecretsFromEcdhe(
        privateKey,
        peerPublicKey,
        transcriptHash,
        appTranscriptHash: appTranscriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )
}

public func tls13DeriveSecretsFromX25519(
    privateKey: Array<Byte>,
    peerPublicKey: Array<Byte>,
    transcriptHash: Array<Byte>,
    keyLen!: Int64 = TLS13_DEFAULT_AEAD_KEY_LEN,
    ivLen!: Int64 = TLS13_DEFAULT_AEAD_IV_LEN,
    appTranscriptHash!: Array<Byte> = []   // RFC 8446 §7.1: override for app traffic keys
): Tls13HandshakeSecrets {
    tls13RequireHashAndLengths(transcriptHash, keyLen, ivLen)

    let sharedSecret = x25519DeriveSharedSecret(privateKey, peerPublicKey)
    let zeros = Array<Byte>(TLS13_HASH_LEN, repeat: 0)
    let emptyHash = sha256([])

    let earlySecret = tls13HkdfExtract(zeros, zeros)
    let derivedEarly = tls13DeriveSecret(earlySecret, "derived", emptyHash)
    let handshakeSecret = tls13HkdfExtract(derivedEarly, sharedSecret)
    tls13BuildSecretsFromStages(earlySecret, handshakeSecret, transcriptHash, keyLen, ivLen, appTranscriptHash: appTranscriptHash)
}

public func tls13DeriveSecretsFromX25519ForCipherSuite(
    privateKey: Array<Byte>,
    peerPublicKey: Array<Byte>,
    transcriptHash: Array<Byte>,
    cipherSuite: Int64,
    appTranscriptHash!: Array<Byte> = []
): Tls13HandshakeSecrets {
    let (keyLen, ivLen) = tls13KeyIvLensFromCipherSuite(cipherSuite)
    tls13DeriveSecretsFromX25519(
        privateKey,
        peerPublicKey,
        transcriptHash,
        appTranscriptHash: appTranscriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )
}

/**
 * tls13DeriveSecretsFromPsk.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13DeriveSecretsFromPsk(
    psk: Array<Byte>,
    transcriptHash: Array<Byte>,
    appTranscriptHash!: Array<Byte> = [],
    keyLen!: Int64 = TLS13_DEFAULT_AEAD_KEY_LEN,
    ivLen!: Int64 = TLS13_DEFAULT_AEAD_IV_LEN
): Tls13HandshakeSecrets {
    if (psk.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK must not be empty")
    }
    tls13RequireHashAndLengths(transcriptHash, keyLen, ivLen)

    let zeros = Array<Byte>(TLS13_HASH_LEN, repeat: 0)
    let emptyHash = sha256([])
    let earlySecret = tls13HkdfExtract(zeros, psk)
    let derivedEarly = tls13DeriveSecret(earlySecret, "derived", emptyHash)
    let handshakeSecret = tls13HkdfExtract(derivedEarly, zeros)
    tls13BuildSecretsFromStages(earlySecret, handshakeSecret, transcriptHash, keyLen, ivLen, appTranscriptHash: appTranscriptHash)
}

public func tls13DeriveSecretsFromPskForCipherSuite(
    psk: Array<Byte>,
    transcriptHash: Array<Byte>,
    cipherSuite: Int64,
    appTranscriptHash!: Array<Byte> = []
): Tls13HandshakeSecrets {
    let (keyLen, ivLen) = tls13KeyIvLensFromCipherSuite(cipherSuite)
    tls13DeriveSecretsFromPsk(
        psk,
        transcriptHash,
        appTranscriptHash: appTranscriptHash,
        keyLen: keyLen,
        ivLen: ivLen
    )
}

/**
 * tls13DeriveSecretsFromPskAndX25519ForCipherSuite.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13DeriveSecretsFromPskAndX25519ForCipherSuite(
    psk: Array<Byte>,
    privateKey: Array<Byte>,
    peerPublicKey: Array<Byte>,
    transcriptHash: Array<Byte>,
    cipherSuite: Int64,
    appTranscriptHash!: Array<Byte> = []
): Tls13HandshakeSecrets {
    if (psk.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK must not be empty")
    }
    let (keyLen, ivLen) = tls13KeyIvLensFromCipherSuite(cipherSuite)
    tls13RequireHashAndLengths(transcriptHash, keyLen, ivLen)

    let sharedSecret = x25519DeriveSharedSecret(privateKey, peerPublicKey)
    let zeros = Array<Byte>(TLS13_HASH_LEN, repeat: 0)
    let emptyHash = sha256([])
    let earlySecret = tls13HkdfExtract(zeros, psk)
    let derivedEarly = tls13DeriveSecret(earlySecret, "derived", emptyHash)
    let handshakeSecret = tls13HkdfExtract(derivedEarly, sharedSecret)
    tls13BuildSecretsFromStages(earlySecret, handshakeSecret, transcriptHash, keyLen, ivLen, appTranscriptHash: appTranscriptHash)
}

/**
 * tls13DeriveEarlyDataSecrets.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13DeriveEarlyDataSecrets(
    psk: Array<Byte>,
    clientHelloHash: Array<Byte>,
    keyLen!: Int64 = TLS13_DEFAULT_AEAD_KEY_LEN,
    ivLen!: Int64 = TLS13_DEFAULT_AEAD_IV_LEN
): Tls13EarlyDataSecrets {
    if (psk.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK must not be empty")
    }
    tls13RequireHashAndLengths(clientHelloHash, keyLen, ivLen)

    let zeros = Array<Byte>(TLS13_HASH_LEN, repeat: 0)
    let earlySecret = tls13HkdfExtract(zeros, psk)
    let clientEarlyTraffic = tls13DeriveSecret(earlySecret, "c e traffic", clientHelloHash)
    let clientEarlyWriteKey = tls13HkdfExpandLabel(clientEarlyTraffic, "key", [], keyLen)
    let clientEarlyWriteIv = tls13HkdfExpandLabel(clientEarlyTraffic, "iv", [], ivLen)
    Tls13EarlyDataSecrets(clientEarlyTraffic, clientEarlyWriteKey, clientEarlyWriteIv)
}

/**
 * tls13ComputeFinishedVerifyData.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13ComputeFinishedVerifyData(baseTrafficSecret: Array<Byte>, transcriptHash: Array<Byte>): Array<Byte> {
    if (baseTrafficSecret.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 finished base secret must not be empty")
    }
    if (transcriptHash.size != TLS13_HASH_LEN) {
        throw CryptoException(InvalidArgument, "TLS1.3 transcript hash must be SHA-256 sized")
    }
    let finishedKey = tls13HkdfExpandLabel(baseTrafficSecret, "finished", [], TLS13_HASH_LEN)
    hmac(HashAlgorithm.SHA256, finishedKey, transcriptHash)
}

public func tls13BuildKeyUpdateHandshake(requestPeerUpdate!: Bool = false): Array<Byte> {
    let requestValue = if (requestPeerUpdate) {
        TLS13_KEY_UPDATE_REQUESTED
    } else {
        TLS13_KEY_UPDATE_NOT_REQUESTED
    }
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(KeyUpdate, [UInt8(requestValue)]))
}

/**
 * tls13DecodeKeyUpdateHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13DecodeKeyUpdateHandshake(encodedKeyUpdate: Array<Byte>): Bool {
    let frame = tlsDecodeHandshakeFrame(encodedKeyUpdate)
    if (frame.msgType != KeyUpdate) {
        throw CryptoException(ParseError, "TLS1.3 handshake type is not KeyUpdate")
    }
    if (frame.body.size != 1) {
        throw CryptoException(ParseError, "TLS1.3 KeyUpdate body length must be 1")
    }
    let requestValue = Int64(UInt8(frame.body[0]))
    if (requestValue != TLS13_KEY_UPDATE_NOT_REQUESTED && requestValue != TLS13_KEY_UPDATE_REQUESTED) {
        throw CryptoException(ParseError, "TLS1.3 KeyUpdate request_update is invalid")
    }
    requestValue == TLS13_KEY_UPDATE_REQUESTED
}

public func tls13DeriveNextApplicationTrafficSecret(currentTrafficSecret: Array<Byte>): Array<Byte> {
    tls13RequireTrafficSecret(currentTrafficSecret, "TLS1.3 application traffic secret")
    tls13HkdfExpandLabel(currentTrafficSecret, "traffic upd", [], TLS13_HASH_LEN)
}

public func tls13DeriveApplicationTrafficKeyIv(
    applicationTrafficSecret: Array<Byte>,
    keyLen!: Int64 = TLS13_DEFAULT_AEAD_KEY_LEN,
    ivLen!: Int64 = TLS13_DEFAULT_AEAD_IV_LEN
): (Array<Byte>, Array<Byte>) {
    tls13RequireTrafficSecret(applicationTrafficSecret, "TLS1.3 application traffic secret")
    tls13RequireKeyIvLengths(keyLen, ivLen)

    let writeKey = tls13HkdfExpandLabel(applicationTrafficSecret, "key", [], keyLen)
    let writeIv = tls13HkdfExpandLabel(applicationTrafficSecret, "iv", [], ivLen)
    (writeKey, writeIv)
}

/**
 * tls13RotateClientApplicationTrafficSecrets.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13RotateClientApplicationTrafficSecrets(secrets: Tls13HandshakeSecrets): Tls13HandshakeSecrets {
    let keyLen = secrets.clientWriteKey.size
    let ivLen = secrets.clientWriteIv.size
    if (secrets.serverWriteKey.size != keyLen || secrets.serverWriteIv.size != ivLen) {
        throw CryptoException(InvalidArgument, "TLS1.3 client/server key material lengths must match")
    }
    let nextClientTraffic = tls13DeriveNextApplicationTrafficSecret(secrets.clientAppTrafficSecret)
    tls13CloneWithTrafficSecrets(
        secrets,
        nextClientTraffic,
        secrets.serverAppTrafficSecret,
        keyLen,
        ivLen
    )
}

/**
 * tls13RotateServerApplicationTrafficSecrets.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13RotateServerApplicationTrafficSecrets(secrets: Tls13HandshakeSecrets): Tls13HandshakeSecrets {
    let keyLen = secrets.serverWriteKey.size
    let ivLen = secrets.serverWriteIv.size
    if (secrets.clientWriteKey.size != keyLen || secrets.clientWriteIv.size != ivLen) {
        throw CryptoException(InvalidArgument, "TLS1.3 client/server key material lengths must match")
    }
    let nextServerTraffic = tls13DeriveNextApplicationTrafficSecret(secrets.serverAppTrafficSecret)
    tls13CloneWithTrafficSecrets(
        secrets,
        secrets.clientAppTrafficSecret,
        nextServerTraffic,
        keyLen,
        ivLen
    )
}

/**
 * tls13DeriveExporterMasterSecret.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13DeriveExporterMasterSecret(masterSecret: Array<Byte>, transcriptHash: Array<Byte>): Array<Byte> {
    if (masterSecret.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 master secret must not be empty")
    }
    if (transcriptHash.size != TLS13_HASH_LEN) {
        throw CryptoException(InvalidArgument, "TLS1.3 transcript hash must be SHA-256 sized")
    }
    tls13DeriveSecret(masterSecret, "exp master", transcriptHash)
}

/**
 * tls13ExportKeyingMaterial.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13ExportKeyingMaterial(
    exporterMasterSecret: Array<Byte>,
    exporterLabel: String,
    context!: Array<Byte> = [],
    outputLen!: Int64 = TLS13_HASH_LEN
): Array<Byte> {
    tls13RequireTrafficSecret(exporterMasterSecret, "TLS1.3 exporter master secret")
    if (outputLen < 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 exporter output length must be >= 0")
    }

    let normalizedLabel = exporterLabel.trimAscii()
    if (normalizedLabel.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 exporter label must not be empty")
    }

    let emptyHash = sha256([])
    let contextHash = sha256(context)
    let exporterSecret = tls13DeriveSecret(exporterMasterSecret, normalizedLabel, emptyHash)
    tls13HkdfExpandLabel(exporterSecret, "exporter", contextHash, outputLen)
}

public func tls13EncodeNewSessionTicketHandshake(message: Tls13NewSessionTicketMessage): Array<Byte> {
    let encodedExtensions = tls13EncodeExtensionList(message.extensions)
    let body = Array<Byte>(
        4 + 4 + 1 + message.ticketNonce.size + 2 + message.ticket.size + 2 + encodedExtensions.size,
        repeat: 0
    )
    tls13EncodeUInt32Into(message.ticketLifetimeSeconds, body, 0)
    tls13EncodeUInt32Into(message.ticketAgeAdd, body, 4)
    body[8] = UInt8(message.ticketNonce.size)
    if (message.ticketNonce.size > 0) {
        secureCopyInto(message.ticketNonce, body, dstOffset: 9)
    }
    let ticketLenOffset = 9 + message.ticketNonce.size
    let ticketLen = tls13EncodeUInt16(message.ticket.size)
    body[ticketLenOffset] = ticketLen[0]
    body[ticketLenOffset + 1] = ticketLen[1]
    secureCopyInto(message.ticket, body, dstOffset: ticketLenOffset + 2)
    let extensionsLenOffset = ticketLenOffset + 2 + message.ticket.size
    let extensionsLen = tls13EncodeUInt16(encodedExtensions.size)
    body[extensionsLenOffset] = extensionsLen[0]
    body[extensionsLenOffset + 1] = extensionsLen[1]
    if (encodedExtensions.size > 0) {
        secureCopyInto(encodedExtensions, body, dstOffset: extensionsLenOffset + 2)
    }
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(NewSessionTicket, body))
}

/**
 * tls13DecodeNewSessionTicketHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13DecodeNewSessionTicketHandshake(encodedNewSessionTicket: Array<Byte>): Tls13NewSessionTicketMessage {
    let frame = tlsDecodeHandshakeFrame(encodedNewSessionTicket)
    if (frame.msgType != NewSessionTicket) {
        throw CryptoException(ParseError, "TLS1.3 handshake type is not NewSessionTicket")
    }
    let body = frame.body
    if (body.size < 13) {
        throw CryptoException(ParseError, "TLS1.3 NewSessionTicket body is too short")
    }

    let ticketLifetimeSeconds = tls13DecodeUInt32(body, 0)
    let ticketAgeAdd = tls13DecodeUInt32(body, 4)
    let nonceLen = Int64(UInt8(body[8]))
    var offset = 9
    if (offset + nonceLen > body.size) {
        throw CryptoException(ParseError, "TLS1.3 NewSessionTicket ticket_nonce is truncated")
    }
    let ticketNonce = body[offset..(offset + nonceLen)]
    offset += nonceLen

    if (offset + 2 > body.size) {
        throw CryptoException(ParseError, "TLS1.3 NewSessionTicket ticket length is truncated")
    }
    let ticketLen = tls13DecodeUInt16(body, offset)
    offset += 2
    if (ticketLen == 0 || offset + ticketLen > body.size) {
        throw CryptoException(ParseError, "TLS1.3 NewSessionTicket ticket length is invalid")
    }
    let ticket = body[offset..(offset + ticketLen)]
    offset += ticketLen

    if (offset + 2 > body.size) {
        throw CryptoException(ParseError, "TLS1.3 NewSessionTicket extensions length is truncated")
    }
    let extensionsLen = tls13DecodeUInt16(body, offset)
    offset += 2
    if (offset + extensionsLen != body.size) {
        throw CryptoException(ParseError, "TLS1.3 NewSessionTicket extensions length is invalid")
    }
    let extensionsBytes = body[offset..]
    let extensions = tls13DecodeExtensionList(extensionsBytes)

    Tls13NewSessionTicketMessage(
        ticketLifetimeSeconds,
        ticketAgeAdd,
        ticketNonce,
        ticket,
        extensions: extensions
    )
}

/**
 * tls13BuildNewSessionTicketFromSessionTicket.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildNewSessionTicketFromSessionTicket(
    ticket: TlsSessionTicket,
    ticketAgeAdd!: Int64 = 0
): Array<Byte> {
    let ticketLifetime = ticket.expiresAtUnixSeconds - ticket.issuedAtUnixSeconds
    if (ticketLifetime <= 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 session ticket lifetime must be positive")
    }
    let encodedTicket = tlsEncodeSessionTicket(ticket)
    let message = Tls13NewSessionTicketMessage(
        ticketLifetime,
        ticketAgeAdd,
        ticket.nonce,
        encodedTicket
    )
    tls13EncodeNewSessionTicketHandshake(message)
}

public func tls13DecodeSessionTicketFromNewSessionTicket(
    encodedNewSessionTicket: Array<Byte>
): TlsSessionTicket {
    let message = tls13DecodeNewSessionTicketHandshake(encodedNewSessionTicket)
    tlsDecodeSessionTicket(message.ticket)
}

public func tls13CreateClientRecordLayer(
    secrets: Tls13HandshakeSecrets,
    requestedEngine!: AesEngineKind = AUTO
): TlsAeadRecordLayer {
    TlsAeadRecordLayer(
        secrets.clientWriteKey,
        secrets.clientWriteIv,
        readKey: secrets.serverWriteKey,
        readIv: secrets.serverWriteIv,
        version: TLS1_3,
        requestedEngine: requestedEngine
    )
}

public func tls13CreateServerRecordLayer(
    secrets: Tls13HandshakeSecrets,
    requestedEngine!: AesEngineKind = AUTO
): TlsAeadRecordLayer {
    TlsAeadRecordLayer(
        secrets.serverWriteKey,
        secrets.serverWriteIv,
        readKey: secrets.clientWriteKey,
        readIv: secrets.clientWriteIv,
        version: TLS1_3,
        requestedEngine: requestedEngine
    )
}

public func tls13CreateClientRecordLayerHandle(
    secrets: Tls13HandshakeSecrets,
    cipherSuite: Int64,
    requestedEngine!: AesEngineKind = AUTO
): Tls13RecordLayerHandle {
    let algorithm = tls13CipherSuiteAeadAlgorithm(cipherSuite)
    match (algorithm) {
        case AES_GCM =>
            return Tls13RecordLayerHandle(
                AES_GCM,
                aesLayer: Some(tls13CreateClientRecordLayer(secrets, requestedEngine: requestedEngine))
            )
        case CHACHA20_POLY1305 =>
            return Tls13RecordLayerHandle(
                CHACHA20_POLY1305,
                chachaLayer: Some(tls13CreateClientRecordLayerChacha20Poly1305(secrets))
            )
    }
}

public func tls13CreateServerRecordLayerHandle(
    secrets: Tls13HandshakeSecrets,
    cipherSuite: Int64,
    requestedEngine!: AesEngineKind = AUTO
): Tls13RecordLayerHandle {
    let algorithm = tls13CipherSuiteAeadAlgorithm(cipherSuite)
    match (algorithm) {
        case AES_GCM =>
            return Tls13RecordLayerHandle(
                AES_GCM,
                aesLayer: Some(tls13CreateServerRecordLayer(secrets, requestedEngine: requestedEngine))
            )
        case CHACHA20_POLY1305 =>
            return Tls13RecordLayerHandle(
                CHACHA20_POLY1305,
                chachaLayer: Some(tls13CreateServerRecordLayerChacha20Poly1305(secrets))
            )
    }
}

public func tls13CreateClientRecordChannel(
    secrets: Tls13HandshakeSecrets,
    cipherSuite: Int64,
    requestedEngine!: AesEngineKind = AUTO
): Tls13RecordChannel {
    Tls13RecordChannel(
        tls13CreateClientRecordLayerHandle(
            secrets,
            cipherSuite,
            requestedEngine: requestedEngine
        )
    )
}

public func tls13CreateServerRecordChannel(
    secrets: Tls13HandshakeSecrets,
    cipherSuite: Int64,
    requestedEngine!: AesEngineKind = AUTO
): Tls13RecordChannel {
    Tls13RecordChannel(
        tls13CreateServerRecordLayerHandle(
            secrets,
            cipherSuite,
            requestedEngine: requestedEngine
        )
    )
}

public func tls13RotateClientRecordLayer(
    secrets: Tls13HandshakeSecrets,
    requestedEngine!: AesEngineKind = AUTO
): (Tls13HandshakeSecrets, TlsAeadRecordLayer) {
    let rotated = tls13RotateClientApplicationTrafficSecrets(secrets)
    (rotated, tls13CreateClientRecordLayer(rotated, requestedEngine: requestedEngine))
}

public func tls13RotateServerRecordLayer(
    secrets: Tls13HandshakeSecrets,
    requestedEngine!: AesEngineKind = AUTO
): (Tls13HandshakeSecrets, TlsAeadRecordLayer) {
    let rotated = tls13RotateServerApplicationTrafficSecrets(secrets)
    (rotated, tls13CreateServerRecordLayer(rotated, requestedEngine: requestedEngine))
}

public func tls13CreateClientRecordLayerChacha20Poly1305(
    secrets: Tls13HandshakeSecrets
): TlsChacha20Poly1305RecordLayer {
    TlsChacha20Poly1305RecordLayer(
        secrets.clientWriteKey,
        secrets.clientWriteIv,
        readKey: secrets.serverWriteKey,
        readIv: secrets.serverWriteIv,
        version: TLS1_3
    )
}

public func tls13CreateServerRecordLayerChacha20Poly1305(
    secrets: Tls13HandshakeSecrets
): TlsChacha20Poly1305RecordLayer {
    TlsChacha20Poly1305RecordLayer(
        secrets.serverWriteKey,
        secrets.serverWriteIv,
        readKey: secrets.clientWriteKey,
        readIv: secrets.clientWriteIv,
        version: TLS1_3
    )
}

public func tls13RotateClientRecordLayerChacha20Poly1305(
    secrets: Tls13HandshakeSecrets
): (Tls13HandshakeSecrets, TlsChacha20Poly1305RecordLayer) {
    let rotated = tls13RotateClientApplicationTrafficSecrets(secrets)
    (rotated, tls13CreateClientRecordLayerChacha20Poly1305(rotated))
}

public func tls13RotateServerRecordLayerChacha20Poly1305(
    secrets: Tls13HandshakeSecrets
): (Tls13HandshakeSecrets, TlsChacha20Poly1305RecordLayer) {
    let rotated = tls13RotateServerApplicationTrafficSecrets(secrets)
    (rotated, tls13CreateServerRecordLayerChacha20Poly1305(rotated))
}

public func tls13RotateClientRecordLayerHandle(
    secrets: Tls13HandshakeSecrets,
    cipherSuite: Int64,
    requestedEngine!: AesEngineKind = AUTO
): (Tls13HandshakeSecrets, Tls13RecordLayerHandle) {
    let algorithm = tls13CipherSuiteAeadAlgorithm(cipherSuite)
    match (algorithm) {
        case AES_GCM =>
            let (rotated, layer) = tls13RotateClientRecordLayer(secrets, requestedEngine: requestedEngine)
            return (rotated, Tls13RecordLayerHandle(AES_GCM, aesLayer: Some(layer)))
        case CHACHA20_POLY1305 =>
            let (rotated, layer) = tls13RotateClientRecordLayerChacha20Poly1305(secrets)
            return (rotated, Tls13RecordLayerHandle(CHACHA20_POLY1305, chachaLayer: Some(layer)))
    }
}

public func tls13RotateServerRecordLayerHandle(
    secrets: Tls13HandshakeSecrets,
    cipherSuite: Int64,
    requestedEngine!: AesEngineKind = AUTO
): (Tls13HandshakeSecrets, Tls13RecordLayerHandle) {
    let algorithm = tls13CipherSuiteAeadAlgorithm(cipherSuite)
    match (algorithm) {
        case AES_GCM =>
            let (rotated, layer) = tls13RotateServerRecordLayer(secrets, requestedEngine: requestedEngine)
            return (rotated, Tls13RecordLayerHandle(AES_GCM, aesLayer: Some(layer)))
        case CHACHA20_POLY1305 =>
            let (rotated, layer) = tls13RotateServerRecordLayerChacha20Poly1305(secrets)
            return (rotated, Tls13RecordLayerHandle(CHACHA20_POLY1305, chachaLayer: Some(layer)))
    }
}

private func tls13AdvanceRecordChannelStateFromAlert(
    state: Tls13RecordChannelState,
    alert: TlsAlertMessage
): Tls13RecordChannelState {
    if (alert.level == Fatal) {
        return Closed
    }
    if (alert.description == CloseNotify) {
        if (state == CloseNotifySent) {
            return Closed
        }
        if (state == Closed) {
            return Closed
        }
        return CloseNotifyReceived
    }
    state
}

private func tls13SelectAlpnFromHello(clientHello: TlsClientHello, serverPreference: Array<String>): String {
    if (serverPreference.size == 0) {
        return ""
    }
    let ext = tlsFindExtension(clientHello.extensions, TLS_EXT_ALPN)
    if (let Some(value) <- ext) {
        let clientProtocols = tlsParseAlpnExtension(value)
        for (serverProtocol in serverPreference) {
            let normalized = serverProtocol.trimAscii()
            if (normalized.size == 0) {
                continue
            }
            if (tls13ContainsString(clientProtocols, normalized)) {
                return normalized
            }
        }
    }
    ""
}

private func tls13ExtractServerNameFromHello(clientHello: TlsClientHello): String {
    let ext = tlsFindExtension(clientHello.extensions, TLS_EXT_SERVER_NAME)
    if (let Some(value) <- ext) {
        let names = tlsParseServerNameExtension(value)
        if (names.size > 0) {
            return names[0]
        }
    }
    ""
}

private func tls13BuildServerAuthFlightBySigner(
    certChainDer: Array<Array<Byte>>,
    transcriptHash: Array<Byte>,
    serverHsTrafficSecret: Array<Byte>,
    certificatePrivateKeyEcdsa: ?EcPrivateKey,
    certificatePrivateKeyRsa: ?RsaPrivateKey
): Tls13AuthFlight {
    if (let Some(ecdsaKey) <- certificatePrivateKeyEcdsa) {
        if (let Some(_rsaKey) <- certificatePrivateKeyRsa) {
            throw CryptoException(InvalidArgument, "TLS1.3 server auth flight signer must use exactly one private key")
        }
        return tls13BuildServerAuthFlightEcdsa(
            certChainDer,
            ecdsaKey,
            transcriptHash,
            serverHsTrafficSecret
        )
    }
    if (let Some(rsaKey) <- certificatePrivateKeyRsa) {
        return tls13BuildServerAuthFlightRsaPss(
            certChainDer,
            rsaKey,
            transcriptHash,
            serverHsTrafficSecret
        )
    }
    throw CryptoException(InvalidArgument, "TLS1.3 server auth flight signer private key is missing")
}

private func tls13VerifyServerAuthFlightWithOptionalProfile(
    authFlight: Tls13AuthFlight,
    policy: X509VerificationPolicy,
    transcriptHash: Array<Byte>,
    serverHsTrafficSecret: Array<Byte>,
    profile: ?FipsProfile
): X509VerificationResult {
    if (let Some(value) <- profile) {
        return tls13VerifyServerAuthFlightWithProfile(
            authFlight,
            policy,
            transcriptHash,
            serverHsTrafficSecret,
            value
        )
    }
    tls13VerifyServerAuthFlight(
        authFlight,
        policy,
        transcriptHash,
        serverHsTrafficSecret
    )
}

private func tls13BuildSecretsFromStages(
    earlySecret: Array<Byte>,
    handshakeSecret: Array<Byte>,
    transcriptHash: Array<Byte>,
    keyLen: Int64,
    ivLen: Int64,
    appTranscriptHash!: Array<Byte> = []   // RFC 8446 §7.1: app traffic keys use Hello…Finished transcript; empty = use transcriptHash
): Tls13HandshakeSecrets {
    // Use appTranscriptHash if provided (non-empty), otherwise fall back to transcriptHash
    let appHash = if (appTranscriptHash.size > 0) { appTranscriptHash } else { transcriptHash }
    let emptyHash = sha256([])
    let zeros = Array<Byte>(TLS13_HASH_LEN, repeat: 0)

    let clientHsTrafficSecret = tls13DeriveSecret(handshakeSecret, "c hs traffic", transcriptHash)
    let serverHsTrafficSecret = tls13DeriveSecret(handshakeSecret, "s hs traffic", transcriptHash)

    let derivedHandshake = tls13DeriveSecret(handshakeSecret, "derived", emptyHash)
    let masterSecret = tls13HkdfExtract(derivedHandshake, zeros)

    let clientAppTrafficSecret = tls13DeriveSecret(masterSecret, "c ap traffic", appHash)
    let serverAppTrafficSecret = tls13DeriveSecret(masterSecret, "s ap traffic", appHash)

    let clientWriteKey = tls13HkdfExpandLabel(clientAppTrafficSecret, "key", [], keyLen)
    let serverWriteKey = tls13HkdfExpandLabel(serverAppTrafficSecret, "key", [], keyLen)
    let clientWriteIv = tls13HkdfExpandLabel(clientAppTrafficSecret, "iv", [], ivLen)
    let serverWriteIv = tls13HkdfExpandLabel(serverAppTrafficSecret, "iv", [], ivLen)

    Tls13HandshakeSecrets(
        earlySecret,
        handshakeSecret,
        masterSecret,
        clientHsTrafficSecret,
        serverHsTrafficSecret,
        clientAppTrafficSecret,
        serverAppTrafficSecret,
        clientWriteKey,
        serverWriteKey,
        clientWriteIv,
        serverWriteIv
    )
}

private func tls13CloneWithTrafficSecrets(
    base: Tls13HandshakeSecrets,
    clientAppTrafficSecret: Array<Byte>,
    serverAppTrafficSecret: Array<Byte>,
    keyLen: Int64,
    ivLen: Int64
): Tls13HandshakeSecrets {
    tls13RequireTrafficSecret(clientAppTrafficSecret, "TLS1.3 client application traffic secret")
    tls13RequireTrafficSecret(serverAppTrafficSecret, "TLS1.3 server application traffic secret")
    tls13RequireKeyIvLengths(keyLen, ivLen)

    let clientWriteKey = tls13HkdfExpandLabel(clientAppTrafficSecret, "key", [], keyLen)
    let serverWriteKey = tls13HkdfExpandLabel(serverAppTrafficSecret, "key", [], keyLen)
    let clientWriteIv = tls13HkdfExpandLabel(clientAppTrafficSecret, "iv", [], ivLen)
    let serverWriteIv = tls13HkdfExpandLabel(serverAppTrafficSecret, "iv", [], ivLen)

    Tls13HandshakeSecrets(
        base.earlySecret,
        base.handshakeSecret,
        base.masterSecret,
        base.clientHsTrafficSecret,
        base.serverHsTrafficSecret,
        clientAppTrafficSecret,
        serverAppTrafficSecret,
        clientWriteKey,
        serverWriteKey,
        clientWriteIv,
        serverWriteIv
    )
}

private func tls13VerifyAuthFlightIntegrity(
    flight: Tls13AuthFlight,
    leafCertificate: X509Certificate,
    transcriptHash: Array<Byte>,
    finishedBaseSecret: Array<Byte>
): Unit {
    let certVerifyOk = match (flight.role) {
        case Tls13AuthFlightRole.SERVER => tls13VerifyServerCertificateVerify(flight.certificateVerifyHandshake, leafCertificate, transcriptHash)
        case Tls13AuthFlightRole.CLIENT => tls13VerifyClientCertificateVerify(flight.certificateVerifyHandshake, leafCertificate, transcriptHash)
    }
    if (!certVerifyOk) {
        throw CryptoException(ParseError, "TLS1.3 CertificateVerify validation failed")
    }

    let finishedVerifyData = tlsDecodeFinishedHandshake(flight.finishedHandshake)
    let expectedFinished = tls13ComputeFinishedVerifyData(finishedBaseSecret, transcriptHash)
    if (!constantTimeEquals(finishedVerifyData, expectedFinished)) {
        throw CryptoException(ParseError, "TLS1.3 Finished verify_data mismatch")
    }
}

private func tls13BuildCertificateVerifyEcdsa(
    privateKey: EcPrivateKey,
    transcriptHash: Array<Byte>,
    contextLabel: String
): Array<Byte> {
    let signatureScheme = tls13ResolveEcdsaCertificateVerifyScheme(privateKey.curve)
    let digest = tls13ComputeCertificateVerifyDigestForScheme(contextLabel, transcriptHash, signatureScheme)
    let (r, s) = ecdsaSign(privateKey, digest)
    let signature = tls13EncodeEcdsaSignatureDer(r, s)
    tlsEncodeCertificateVerifyHandshake(
        TlsCertificateVerifyMessage(signatureScheme, signature)
    )
}

private func tls13BuildCertificateVerifyRsaPss(
    privateKey: RsaPrivateKey,
    transcriptHash: Array<Byte>,
    contextLabel: String
): Array<Byte> {
    let digest = tls13ComputeCertificateVerifyDigestForScheme(
        contextLabel,
        transcriptHash,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    )
    let signature = rsaSignPssWithHash(
        privateKey,
        digest,
        RsaHashAlgorithm.SHA256,
        saltLen: TLS13_HASH_LEN
    )
    tlsEncodeCertificateVerifyHandshake(
        TlsCertificateVerifyMessage(TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256, signature)
    )
}

private func tls13VerifyCertificateVerify(
    encodedCertificateVerify: Array<Byte>,
    certificate: X509Certificate,
    transcriptHash: Array<Byte>,
    contextLabel: String
): Bool {
    let message = try {
        tlsDecodeCertificateVerifyHandshake(encodedCertificateVerify)
    } catch (_: CryptoException) {
        return false
    }
    if (
        message.signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256 ||
        message.signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384
    ) {
        let publicKey = try {
            x509ExtractEcPublicKey(certificate)
        } catch (_: CryptoException) {
            return false
        }
        if (!tls13IsCertificateCurveAllowedForScheme(publicKey.curve, message.signatureScheme)) {
            return false
        }
        let digest = try {
            tls13ComputeCertificateVerifyDigestForScheme(contextLabel, transcriptHash, message.signatureScheme)
        } catch (_: CryptoException) {
            return false
        }
        let (r, s) = try {
            tls13DecodeEcdsaSignatureDer(message.signature)
        } catch (_: CryptoException) {
            return false
        }
        return ecdsaVerify(publicKey, digest, r, s)
    }

    if (message.signatureScheme == TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256) {
        let publicKey = try {
            x509ExtractRsaPublicKey(certificate)
        } catch (_: CryptoException) {
            return false
        }
        let digest = try {
            tls13ComputeCertificateVerifyDigestForScheme(contextLabel, transcriptHash, message.signatureScheme)
        } catch (_: CryptoException) {
            return false
        }
        return rsaVerifyPssWithHash(
            publicKey,
            digest,
            message.signature,
            RsaHashAlgorithm.SHA256,
            saltLen: TLS13_HASH_LEN
        )
    }

    false
}

private func tls13ComputeCertificateVerifyDigestForScheme(
    contextLabel: String,
    transcriptHash: Array<Byte>,
    signatureScheme: Int64
): Array<Byte> {
    if (transcriptHash.size != TLS13_HASH_LEN) {
        throw CryptoException(InvalidArgument, "TLS1.3 transcript hash must be SHA-256 sized")
    }
    let contextBytes = contextLabel.toArray()
    let input = Array<Byte>(TLS13_CERT_VERIFY_PREFIX_LEN + contextBytes.size + 1 + transcriptHash.size, repeat: UInt8(0x20))
    secureCopyInto(contextBytes, input, dstOffset: TLS13_CERT_VERIFY_PREFIX_LEN)
    input[TLS13_CERT_VERIFY_PREFIX_LEN + contextBytes.size] = UInt8(0x00)
    secureCopyInto(transcriptHash, input, dstOffset: TLS13_CERT_VERIFY_PREFIX_LEN + contextBytes.size + 1)
    if (signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256 || signatureScheme == TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256) {
        return sha256(input)
    }
    if (signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384) {
        return sha384(input)
    }
    throw CryptoException(Unsupported, "TLS1.3 CertificateVerify signature scheme is unsupported: ${signatureScheme}")
}

private func tls13ResolveEcdsaCertificateVerifyScheme(curve: NamedCurve): Int64 {
    if (curve == P256) {
        return TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256
    }
    if (curve == P384) {
        return TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384
    }
    throw CryptoException(Unsupported, "TLS1.3 ECDSA CertificateVerify curve is unsupported: ${curve.toString()}")
}

private func tls13IsCertificateCurveAllowedForScheme(curve: NamedCurve, signatureScheme: Int64): Bool {
    if (signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256) {
        return curve == P256
    }
    if (signatureScheme == TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384) {
        return curve == P384
    }
    false
}

private func tls13RequireHashAndLengths(transcriptHash: Array<Byte>, keyLen: Int64, ivLen: Int64): Unit {
    if (transcriptHash.size != TLS13_HASH_LEN) {
        throw CryptoException(InvalidArgument, "TLS1.3 transcript hash must be SHA-256 sized")
    }
    tls13RequireKeyIvLengths(keyLen, ivLen)
}

private func tls13KeyIvLensFromCipherSuite(cipherSuite: Int64): (Int64, Int64) {
    let keyLen = tls13CipherSuiteKeyLen(cipherSuite)
    let ivLen = tls13CipherSuiteIvLen(cipherSuite)
    (keyLen, ivLen)
}

private func tls13RequireKeyIvLengths(keyLen: Int64, ivLen: Int64): Unit {
    if (keyLen <= 0 || ivLen <= 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 key/iv lengths must be > 0")
    }
}

private func tls13RequireTrafficSecret(secret: Array<Byte>, label: String): Unit {
    if (secret.size != TLS13_HASH_LEN) {
        throw CryptoException(InvalidArgument, "${label} must be SHA-256 sized")
    }
}

private func tls13RequireClientVersion(clientHello: TlsClientHello): Unit {
    let ext = tls13RequireExtension(clientHello.extensions, TLS13_EXT_SUPPORTED_VERSIONS, "TLS1.3 supported_versions")
    let versions = ext.data
    if (versions.size < 3) {
        throw CryptoException(ParseError, "TLS1.3 supported_versions extension is too short")
    }
    let vectorLen = Int64(UInt8(versions[0]))
    if (vectorLen <= 0 || vectorLen != versions.size - 1 || (vectorLen % 2) != 0) {
        throw CryptoException(ParseError, "TLS1.3 supported_versions vector length is invalid")
    }

    var found = false
    var offset = 1
    while (offset < versions.size) {
        let version = tls13DecodeUInt16(versions, offset)
        if (version == TLS13_VERSION) {
            found = true
            break
        }
        offset += 2
    }
    if (!found) {
        throw CryptoException(ParseError, "TLS1.3 is not offered in supported_versions")
    }
}

private func tls13ValidateOfferedCipherSuites(cipherSuites: Array<Int64>): Unit {
    if (cipherSuites.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 offered cipher suite list must not be empty")
    }
    for (cipherSuite in cipherSuites) {
        _ = tls13CipherSuiteAeadAlgorithm(cipherSuite)
    }
}

private func tls13SelectCipherSuite(offered: Array<Int64>): Int64 {
    var i = 0
    while (i < offered.size) {
        let suite = offered[i]
        if (suite == TLS13_CIPHER_TLS_CHACHA20_POLY1305_SHA256) {
            return TLS13_CIPHER_TLS_CHACHA20_POLY1305_SHA256
        }
        if (suite == TLS13_CIPHER_TLS_AES_128_GCM_SHA256) {
            return TLS13_CIPHER_TLS_AES_128_GCM_SHA256
        }
        i += 1
    }
    throw CryptoException(ParseError, "TLS1.3 client did not offer supported cipher suite")
}

private func tls13ExtractClientKeyShareFromHello(clientHello: TlsClientHello): EcPublicKey {
    let ext = tls13RequireExtension(clientHello.extensions, TLS13_EXT_KEY_SHARE, "TLS1.3 client key_share")
    tls13DecodeClientKeyShare(ext.data)
}

private func tls13ExtractClientX25519KeyShareFromHello(clientHello: TlsClientHello): Array<Byte> {
    let ext = tls13RequireExtension(clientHello.extensions, TLS13_EXT_KEY_SHARE, "TLS1.3 client key_share")
    tls13DecodeClientX25519KeyShare(ext.data)
}

private func tls13FindOptionalExtension(extensions: Array<TlsExtension>, extType: Int64): ?TlsExtension {
    for (ext in extensions) {
        if (ext.extType == extType) {
            return Some(ext)
        }
    }
    None
}

private func tls13SummarizeServerNames(extensions: Array<TlsExtension>): Array<String> {
    if (let Some(ext) <- tls13FindOptionalExtension(extensions, TLS_EXT_SERVER_NAME)) {
        return tlsParseServerNameExtension(ext)
    }
    []
}

private func tls13SummarizeAlpnProtocols(extensions: Array<TlsExtension>): Array<String> {
    if (let Some(ext) <- tls13FindOptionalExtension(extensions, TLS_EXT_ALPN)) {
        return tlsParseAlpnExtension(ext)
    }
    []
}

private func tls13SummarizeSupportedVersions(extensions: Array<TlsExtension>): Array<Int64> {
    if (let Some(ext) <- tls13FindOptionalExtension(extensions, TLS13_EXT_SUPPORTED_VERSIONS)) {
        return tls13ParseClientSupportedVersionsExtension(ext)
    }
    []
}

private func tls13SummarizeSupportedGroups(extensions: Array<TlsExtension>): Array<Int64> {
    if (let Some(ext) <- tls13FindOptionalExtension(extensions, TLS13_EXT_SUPPORTED_GROUPS)) {
        return tls13ParseSupportedGroupsExtension(ext)
    }
    []
}

private func tls13SummarizeKeyShareGroups(extensions: Array<TlsExtension>): Array<Int64> {
    if (let Some(ext) <- tls13FindOptionalExtension(extensions, TLS13_EXT_KEY_SHARE)) {
        return tls13ParseClientKeyShareGroupIds(ext)
    }
    []
}

private func tls13SummarizeSignatureSchemes(extensions: Array<TlsExtension>): Array<Int64> {
    if (let Some(ext) <- tls13FindOptionalExtension(extensions, TLS13_EXT_SIGNATURE_ALGORITHMS)) {
        return tls13ParseSignatureAlgorithmsExtension(ext)
    }
    []
}

private func tls13RequireExtension(extensions: Array<TlsExtension>, extType: Int64, label: String): TlsExtension {
    for (ext in extensions) {
        if (ext.extType == extType) {
            return ext
        }
    }
    throw CryptoException(ParseError, "${label} extension is missing")
}

private func tls13NormalizeSupportedGroups(groups: Array<Int64>): Array<Int64> {
    if (groups.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 supported group list must not be empty")
    }

    let out = ArrayList<Int64>()
    for (group in groups) {
        if (group < 0 || group > 65535) {
            throw CryptoException(InvalidArgument, "TLS1.3 supported group must fit uint16")
        }
        var duplicate = false
        for (current in out.toArray()) {
            if (current == group) {
                duplicate = true
                break
            }
        }
        if (!duplicate) {
            out.add(group)
        }
    }
    if (out.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 supported group list must not be empty")
    }
    out.toArray()
}

private func tls13EncodeSupportedGroupsExtension(groups: Array<Int64>): TlsExtension {
    let normalizedGroups = tls13NormalizeSupportedGroups(groups)
    let encoded = Array<Byte>(normalizedGroups.size * 2, repeat: 0)
    var i = 0
    while (i < normalizedGroups.size) {
        let group = tls13EncodeUInt16(normalizedGroups[i])
        encoded[i * 2] = group[0]
        encoded[i * 2 + 1] = group[1]
        i += 1
    }
    TlsExtension(TLS13_EXT_SUPPORTED_GROUPS, tls13EncodeVector16(encoded))
}

private func tls13NormalizeSignatureSchemes(signatureSchemes: Array<Int64>): Array<Int64> {
    if (signatureSchemes.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 signature scheme list must not be empty")
    }

    let out = ArrayList<Int64>()
    for (scheme in signatureSchemes) {
        if (scheme < 0 || scheme > 65535) {
            throw CryptoException(InvalidArgument, "TLS1.3 signature scheme must fit uint16")
        }
        var duplicate = false
        for (current in out.toArray()) {
            if (current == scheme) {
                duplicate = true
                break
            }
        }
        if (!duplicate) {
            out.add(scheme)
        }
    }
    if (out.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 signature scheme list must not be empty")
    }
    out.toArray()
}

private func tls13EncodeSignatureAlgorithmsExtension(signatureSchemes: Array<Int64>): TlsExtension {
    let normalizedSchemes = tls13NormalizeSignatureSchemes(signatureSchemes)
    let encoded = Array<Byte>(normalizedSchemes.size * 2, repeat: 0)
    var i = 0
    while (i < normalizedSchemes.size) {
        let scheme = tls13EncodeUInt16(normalizedSchemes[i])
        encoded[i * 2] = scheme[0]
        encoded[i * 2 + 1] = scheme[1]
        i += 1
    }
    TlsExtension(TLS13_EXT_SIGNATURE_ALGORITHMS, tls13EncodeVector16(encoded))
}

private func tls13ParseClientSupportedVersionsExtension(extension: TlsExtension): Array<Int64> {
    if (extension.extType != TLS13_EXT_SUPPORTED_VERSIONS) {
        throw CryptoException(InvalidArgument, "TLS1.3 extension is not supported_versions")
    }
    if (extension.data.size < 3) {
        throw CryptoException(ParseError, "TLS1.3 supported_versions extension is too short")
    }
    let vectorLen = Int64(UInt8(extension.data[0]))
    if (vectorLen == 0 || (vectorLen % 2) != 0 || vectorLen != extension.data.size - 1) {
        throw CryptoException(ParseError, "TLS1.3 supported_versions vector length is invalid")
    }

    let versions = ArrayList<Int64>()
    var offset = 1
    while (offset < extension.data.size) {
        versions.add(tls13DecodeUInt16(extension.data, offset))
        offset += 2
    }
    versions.toArray()
}

private func tls13ParseSupportedGroupsExtension(extension: TlsExtension): Array<Int64> {
    if (extension.extType != TLS13_EXT_SUPPORTED_GROUPS) {
        throw CryptoException(InvalidArgument, "TLS1.3 extension is not supported_groups")
    }
    tls13DecodeUInt16ListVector16(extension.data, "TLS1.3 supported_groups")
}

private func tls13ParseClientKeyShareGroupIds(extension: TlsExtension): Array<Int64> {
    if (extension.extType != TLS13_EXT_KEY_SHARE) {
        throw CryptoException(InvalidArgument, "TLS1.3 extension is not key_share")
    }
    let entries = tls13DecodeVector16(extension.data, "TLS1.3 client key_share list")
    let groups = ArrayList<Int64>()
    var offset = 0
    while (offset < entries.size) {
        if (offset + 4 > entries.size) {
            throw CryptoException(ParseError, "TLS1.3 client key_share entry is truncated")
        }
        let group = tls13DecodeUInt16(entries, offset)
        offset += 2
        let keyLen = tls13DecodeUInt16(entries, offset)
        offset += 2
        if (keyLen == 0 || offset + keyLen > entries.size) {
            throw CryptoException(ParseError, "TLS1.3 client key_share entry length is invalid")
        }
        groups.add(group)
        offset += keyLen
    }
    if (groups.size == 0) {
        throw CryptoException(ParseError, "TLS1.3 client key_share list is empty")
    }
    groups.toArray()
}

private func tls13DecodeUInt16ListVector16(data: Array<Byte>, label: String): Array<Int64> {
    let vector = tls13DecodeVector16(data, label)
    if (vector.size == 0 || (vector.size % 2) != 0) {
        throw CryptoException(ParseError, "${label} vector length is invalid")
    }

    let values = ArrayList<Int64>()
    var offset = 0
    while (offset < vector.size) {
        values.add(tls13DecodeUInt16(vector, offset))
        offset += 2
    }
    values.toArray()
}

private func tls13ParseSignatureAlgorithmsExtension(extension: TlsExtension): Array<Int64> {
    if (extension.extType != TLS13_EXT_SIGNATURE_ALGORITHMS) {
        throw CryptoException(InvalidArgument, "TLS1.3 extension is not signature_algorithms")
    }
    let vector = tls13DecodeVector16(extension.data, "TLS1.3 signature_algorithms")
    if (vector.size == 0 || (vector.size % 2) != 0) {
        throw CryptoException(ParseError, "TLS1.3 signature_algorithms vector length is invalid")
    }

    let schemes = ArrayList<Int64>()
    var offset = 0
    while (offset < vector.size) {
        schemes.add(tls13DecodeUInt16(vector, offset))
        offset += 2
    }
    schemes.toArray()
}

private func tls13EncodeCertificateAuthoritiesExtension(authorities: Array<Array<Byte>>): TlsExtension {
    if (authorities.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 certificate_authorities must not be empty")
    }

    let payload = ArrayList<Byte>()
    for (authority in authorities) {
        if (authority.size == 0) {
            throw CryptoException(InvalidArgument, "TLS1.3 certificate authority name must not be empty")
        }
        if (authority.size > 65535) {
            throw CryptoException(OutOfBounds, "TLS1.3 certificate authority name exceeds uint16 length")
        }
        let encodedLen = tls13EncodeUInt16(authority.size)
        payload.add(encodedLen[0])
        payload.add(encodedLen[1])
        for (b in authority) {
            payload.add(b)
        }
    }

    TlsExtension(TLS13_EXT_CERTIFICATE_AUTHORITIES, tls13EncodeVector16(payload.toArray()))
}

private func tls13ParseCertificateAuthoritiesExtension(extension: TlsExtension): Array<Array<Byte>> {
    if (extension.extType != TLS13_EXT_CERTIFICATE_AUTHORITIES) {
        throw CryptoException(InvalidArgument, "TLS1.3 extension is not certificate_authorities")
    }
    let vector = tls13DecodeVector16(extension.data, "TLS1.3 certificate_authorities")
    if (vector.size == 0) {
        throw CryptoException(ParseError, "TLS1.3 certificate_authorities vector must not be empty")
    }

    let authorities = ArrayList<Array<Byte>>()
    var offset = 0
    while (offset < vector.size) {
        if (offset + 2 > vector.size) {
            throw CryptoException(ParseError, "TLS1.3 certificate_authorities entry length is truncated")
        }
        let nameLen = tls13DecodeUInt16(vector, offset)
        offset += 2
        if (nameLen == 0 || offset + nameLen > vector.size) {
            throw CryptoException(ParseError, "TLS1.3 certificate_authorities entry length is invalid")
        }
        authorities.add(vector[offset..(offset + nameLen)])
        offset += nameLen
    }
    if (offset != vector.size) {
        throw CryptoException(ParseError, "TLS1.3 certificate_authorities vector has trailing bytes")
    }
    authorities.toArray()
}

private func tls13RequireClientAuthFlightMatchesCertificateRequest(
    flight: Tls13AuthFlight,
    request: Tls13CertificateRequestParameters
): Unit {
    if (flight.role != Tls13AuthFlightRole.CLIENT) {
        throw CryptoException(InvalidArgument, "TLS1.3 auth flight role mismatch: expected CLIENT")
    }

    let certificateMessage = tlsDecodeCertificateHandshakeTls13(flight.certificateHandshake)
    if (!tls13BytesEqual(certificateMessage.requestContext, request.requestContext)) {
        throw CryptoException(ParseError, "TLS1.3 client Certificate.request_context mismatches CertificateRequest")
    }
    if (certificateMessage.entries.size == 0) {
        throw CryptoException(ParseError, "TLS1.3 client certificate chain must not be empty")
    }

    let certificateVerify = tlsDecodeCertificateVerifyHandshake(flight.certificateVerifyHandshake)
    if (!tls13ContainsInt64(request.signatureSchemes, certificateVerify.signatureScheme)) {
        throw CryptoException(ParseError, "TLS1.3 client CertificateVerify signature scheme is not allowed")
    }

    if (request.certificateAuthorities.size > 0) {
        let leaf = x509ParseDer(certificateMessage.entries[0].certData)
        if (!tls13ContainsDistinguishedName(request.certificateAuthorities, leaf.issuer.der)) {
            throw CryptoException(ParseError, "TLS1.3 client certificate issuer is not accepted by certificate_authorities")
        }
    }
}

private func tls13ContainsInt64(values: Array<Int64>, target: Int64): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    false
}

private func tls13RequireAllInt64(
    missing: ArrayList<String>,
    actual: Array<Int64>,
    expected: Array<Int64>,
    label: String
): Unit {
    for (value in expected) {
        if (!tls13ContainsInt64(actual, value)) {
            missing.add("missing ${label} ${value}")
        }
    }
}

private func tls13RequireAllStrings(
    missing: ArrayList<String>,
    actual: Array<String>,
    expected: Array<String>,
    label: String
): Unit {
    for (value in expected) {
        if (!tls13ContainsString(actual, value)) {
            missing.add("missing ${label} ${value}")
        }
    }
}

private func tls13ContainsDistinguishedName(values: Array<Array<Byte>>, target: Array<Byte>): Bool {
    for (candidate in values) {
        if (tls13BytesEqual(candidate, target)) {
            return true
        }
    }
    false
}

private func tls13BytesEqual(left: Array<Byte>, right: Array<Byte>): Bool {
    if (left.size != right.size) {
        return false
    }
    if (left.size == 0) {
        return true
    }
    constantTimeEquals(left, right)
}

private func tls13EncodeClientSupportedVersions(): Array<Byte> {
    [UInt8(0x02), UInt8(0x03), UInt8(0x04)]
}

private func tls13EncodeServerSupportedVersion(): Array<Byte> {
    [UInt8(0x03), UInt8(0x04)]
}

private func tls13EncodeClientKeyShare(publicKey: EcPublicKey): Array<Byte> {
    let (groupId, fieldBytes) = tls13ResolveEcdheCurveSpecFromPublicKey(publicKey)
    let point = tls13EncodeEcPoint(publicKey, fieldBytes)
    let entry = Array<Byte>(4 + point.size, repeat: 0)
    let group = tls13EncodeUInt16(groupId)
    let pointLen = tls13EncodeUInt16(point.size)
    entry[0] = group[0]
    entry[1] = group[1]
    entry[2] = pointLen[0]
    entry[3] = pointLen[1]
    secureCopyInto(point, entry, dstOffset: 4)
    tls13EncodeVector16(entry)
}

private func tls13EncodeClientX25519KeyShare(publicKey: Array<Byte>): Array<Byte> {
    x25519ValidatePublicKey(publicKey)
    let entry = Array<Byte>(4 + publicKey.size, repeat: 0)
    let group = tls13EncodeUInt16(TLS13_GROUP_X25519)
    let keyLen = tls13EncodeUInt16(publicKey.size)
    entry[0] = group[0]
    entry[1] = group[1]
    entry[2] = keyLen[0]
    entry[3] = keyLen[1]
    secureCopyInto(publicKey, entry, dstOffset: 4)
    tls13EncodeVector16(entry)
}

private func tls13DecodeClientKeyShare(data: Array<Byte>): EcPublicKey {
    let entries = tls13DecodeVector16(data, "TLS1.3 client key_share list")
    if (entries.size < 5) {
        throw CryptoException(ParseError, "TLS1.3 client key_share list is empty")
    }

    var offset = 0
    while (offset < entries.size) {
        if (offset + 4 > entries.size) {
            throw CryptoException(ParseError, "TLS1.3 client key_share entry is truncated")
        }
        let group = tls13DecodeUInt16(entries, offset)
        offset += 2
        let keyLen = tls13DecodeUInt16(entries, offset)
        offset += 2
        if (keyLen == 0 || offset + keyLen > entries.size) {
            throw CryptoException(ParseError, "TLS1.3 client key_share entry length is invalid")
        }

        let keyBytes = entries[offset..(offset + keyLen)]
        offset += keyLen
        if (group == TLS13_GROUP_SECP256R1 || group == TLS13_GROUP_SECP384R1) {
            let (curve, fieldBytes) = tls13ResolveEcdheCurveSpecFromNamedGroup(group)
            return tls13DecodeEcPoint(keyBytes, curve, fieldBytes)
        }
    }

    throw CryptoException(ParseError, "TLS1.3 client key_share does not include supported group")
}

private func tls13DecodeClientX25519KeyShare(data: Array<Byte>): Array<Byte> {
    let entries = tls13DecodeVector16(data, "TLS1.3 client key_share list")
    if (entries.size < 4 + X25519_KEY_LEN) {
        throw CryptoException(ParseError, "TLS1.3 client key_share list is empty")
    }

    var offset = 0
    while (offset < entries.size) {
        if (offset + 4 > entries.size) {
            throw CryptoException(ParseError, "TLS1.3 client key_share entry is truncated")
        }
        let group = tls13DecodeUInt16(entries, offset)
        offset += 2
        let keyLen = tls13DecodeUInt16(entries, offset)
        offset += 2
        if (keyLen == 0 || offset + keyLen > entries.size) {
            throw CryptoException(ParseError, "TLS1.3 client key_share entry length is invalid")
        }

        let keyBytes = entries[offset..(offset + keyLen)]
        offset += keyLen
        if (group == TLS13_GROUP_X25519) {
            x25519ValidatePublicKey(keyBytes)
            return keyBytes
        }
    }

    throw CryptoException(ParseError, "TLS1.3 client key_share does not include X25519 group")
}

private func tls13EncodeServerKeyShare(publicKey: EcPublicKey): Array<Byte> {
    let (groupId, fieldBytes) = tls13ResolveEcdheCurveSpecFromPublicKey(publicKey)
    let point = tls13EncodeEcPoint(publicKey, fieldBytes)
    let out = Array<Byte>(4 + point.size, repeat: 0)
    let group = tls13EncodeUInt16(groupId)
    let pointLen = tls13EncodeUInt16(point.size)
    out[0] = group[0]
    out[1] = group[1]
    out[2] = pointLen[0]
    out[3] = pointLen[1]
    secureCopyInto(point, out, dstOffset: 4)
    out
}

private func tls13EncodeServerX25519KeyShare(publicKey: Array<Byte>): Array<Byte> {
    x25519ValidatePublicKey(publicKey)
    let out = Array<Byte>(4 + publicKey.size, repeat: 0)
    let group = tls13EncodeUInt16(TLS13_GROUP_X25519)
    let keyLen = tls13EncodeUInt16(publicKey.size)
    out[0] = group[0]
    out[1] = group[1]
    out[2] = keyLen[0]
    out[3] = keyLen[1]
    secureCopyInto(publicKey, out, dstOffset: 4)
    out
}

private func tls13DecodeServerKeyShare(data: Array<Byte>): EcPublicKey {
    if (data.size < 5) {
        throw CryptoException(ParseError, "TLS1.3 server key_share is too short")
    }
    let group = tls13DecodeUInt16(data, 0)
    if (group != TLS13_GROUP_SECP256R1 && group != TLS13_GROUP_SECP384R1) {
        throw CryptoException(Unsupported, "TLS1.3 server key_share group is unsupported")
    }
    let keyLen = tls13DecodeUInt16(data, 2)
    if (keyLen == 0 || data.size != 4 + keyLen) {
        throw CryptoException(ParseError, "TLS1.3 server key_share length is invalid")
    }
    let (curve, fieldBytes) = tls13ResolveEcdheCurveSpecFromNamedGroup(group)
    tls13DecodeEcPoint(data[4..], curve, fieldBytes)
}

private func tls13DecodeServerX25519KeyShare(data: Array<Byte>): Array<Byte> {
    if (data.size < 4 + X25519_KEY_LEN) {
        throw CryptoException(ParseError, "TLS1.3 server key_share is too short")
    }
    let group = tls13DecodeUInt16(data, 0)
    if (group != TLS13_GROUP_X25519) {
        throw CryptoException(Unsupported, "TLS1.3 server key_share group is unsupported")
    }
    let keyLen = tls13DecodeUInt16(data, 2)
    if (keyLen != X25519_KEY_LEN || data.size != 4 + keyLen) {
        throw CryptoException(ParseError, "TLS1.3 server X25519 key_share length is invalid")
    }
    let key = data[4..]
    x25519ValidatePublicKey(key)
    key
}

private func tls13EncodePskKeyExchangeModes(): Array<Byte> {
    [UInt8(0x01), UInt8(TLS13_PSK_MODE_DHE_KE)]
}

private class Tls13ParsedClientPreSharedKey {
    public let identitiesRaw: Array<Byte>
    public let identities: Array<Array<Byte>>
    public let obfuscatedTicketAges: Array<Int64>
    public let binders: Array<Array<Byte>>

    public init(
        identitiesRaw: Array<Byte>,
        identities: Array<Array<Byte>>,
        obfuscatedTicketAges: Array<Int64>,
        binders: Array<Array<Byte>>
    ) {
        this.identitiesRaw = identitiesRaw.clone()
        this.identities = tls13CloneByteArrayArray(identities)
        this.obfuscatedTicketAges = obfuscatedTicketAges.clone()
        this.binders = tls13CloneByteArrayArray(binders)
    }
}

private func tls13EncodeClientPskIdentities(
    identities: Array<Array<Byte>>,
    obfuscatedTicketAges: Array<Int64>
): Array<Byte> {
    if (identities.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK identities must not be empty")
    }
    if (obfuscatedTicketAges.size != identities.size) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK ticket_age list size mismatch")
    }
    let payload = ArrayList<Byte>()
    var i = 0
    while (i < identities.size) {
        let identity = identities[i]
        let age = obfuscatedTicketAges[i]
        if (identity.size == 0 || identity.size > 65535) {
            throw CryptoException(InvalidArgument, "TLS1.3 PSK identity length is invalid")
        }
        if (age < 0 || age > 0xffff_ffff) {
            throw CryptoException(InvalidArgument, "TLS1.3 PSK obfuscated_ticket_age must fit uint32")
        }
        let idLen = tls13EncodeUInt16(identity.size)
        payload.add(idLen[0])
        payload.add(idLen[1])
        for (b in identity) {
            payload.add(b)
        }
        let encodedAge = tls13EncodeUInt32(age)
        payload.add(encodedAge[0])
        payload.add(encodedAge[1])
        payload.add(encodedAge[2])
        payload.add(encodedAge[3])
        i += 1
    }
    tls13EncodeVector16(payload.toArray())
}

private func tls13EncodeClientPskBinders(binders: Array<Array<Byte>>): Array<Byte> {
    if (binders.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK binders must not be empty")
    }
    let payload = ArrayList<Byte>()
    for (binder in binders) {
        if (binder.size == 0 || binder.size > 255) {
            throw CryptoException(InvalidArgument, "TLS1.3 PSK binder length is invalid")
        }
        payload.add(UInt8(binder.size))
        for (b in binder) {
            payload.add(b)
        }
    }
    tls13EncodeVector16(payload.toArray())
}

private func tls13ParseClientPreSharedKey(data: Array<Byte>): Tls13ParsedClientPreSharedKey {
    if (data.size < 4) {
        throw CryptoException(ParseError, "TLS1.3 pre_shared_key extension is too short")
    }
    let identitiesLen = tls13DecodeUInt16(data, 0)
    if (identitiesLen <= 0 || identitiesLen + 4 > data.size) {
        throw CryptoException(ParseError, "TLS1.3 identities vector length is invalid")
    }

    let identitiesRawEnd = 2 + identitiesLen
    let identitiesRaw = data[0..identitiesRawEnd]
    let identities = ArrayList<Array<Byte>>()
    let obfuscatedTicketAges = ArrayList<Int64>()
    var offset = 2
    while (offset < identitiesRawEnd) {
        if (offset + 2 > identitiesRawEnd) {
            throw CryptoException(ParseError, "TLS1.3 PSK identity length field is truncated")
        }
        let idLen = tls13DecodeUInt16(data, offset)
        offset += 2
        if (idLen == 0 || offset + idLen + 4 > identitiesRawEnd) {
            throw CryptoException(ParseError, "TLS1.3 PSK identity entry is malformed")
        }
        let identity = data[offset..(offset + idLen)]
        offset += idLen
        let obfuscatedTicketAge = tls13DecodeUInt32(data, offset)
        offset += 4
        identities.add(identity)
        obfuscatedTicketAges.add(obfuscatedTicketAge)
    }
    if (offset != identitiesRawEnd) {
        throw CryptoException(ParseError, "TLS1.3 PSK identities block has trailing bytes")
    }

    let bindersLen = tls13DecodeUInt16(data, identitiesRawEnd)
    if (bindersLen <= 0 || identitiesRawEnd + 2 + bindersLen != data.size) {
        throw CryptoException(ParseError, "TLS1.3 PSK binders length is invalid")
    }
    let bindersEnd = identitiesRawEnd + 2 + bindersLen
    let binders = ArrayList<Array<Byte>>()
    offset = identitiesRawEnd + 2
    while (offset < bindersEnd) {
        let binderLen = Int64(UInt8(data[offset]))
        offset += 1
        if (binderLen == 0 || offset + binderLen > bindersEnd) {
            throw CryptoException(ParseError, "TLS1.3 PSK binder entry is malformed")
        }
        binders.add(data[offset..(offset + binderLen)])
        offset += binderLen
    }
    if (offset != bindersEnd) {
        throw CryptoException(ParseError, "TLS1.3 PSK binders block has trailing bytes")
    }
    if (identities.size != binders.size) {
        throw CryptoException(ParseError, "TLS1.3 PSK identities/binders count mismatch")
    }

    Tls13ParsedClientPreSharedKey(
        identitiesRaw,
        identities.toArray(),
        obfuscatedTicketAges.toArray(),
        binders.toArray()
    )
}

private func tls13CountClientPskIdentities(data: Array<Byte>): Int64 {
    tls13ParseClientPreSharedKey(data).identities.size
}

private func tls13EncodeSelectedIdentity(index: Int64): Array<Byte> {
    tls13EncodeUInt16(index)
}

private func tls13ComputePskBinderTranscriptHash(
    clientRandom: Array<Byte>,
    pskIdentitiesRaw: Array<Byte>,
    sessionId: Array<Byte>
): Array<Byte> {
    let hello = TlsClientHello(
        clientRandom,
        [TLS13_CIPHER_TLS_AES_128_GCM_SHA256],
        sessionId: sessionId,
        compressionMethods: [UInt8(0x00)],
        extensions: [
            TlsExtension(TLS13_EXT_SUPPORTED_VERSIONS, tls13EncodeClientSupportedVersions()),
            TlsExtension(TLS13_EXT_PSK_KEY_EXCHANGE_MODES, tls13EncodePskKeyExchangeModes()),
            TlsExtension(TLS13_EXT_PRE_SHARED_KEY, pskIdentitiesRaw)
        ],
        legacyVersion: TLS1_2
    )
    sha256(tlsEncodeClientHelloHandshake(hello))
}

private func tls13ComputePskBinderTranscriptHashFromHello(
    clientHello: TlsClientHello,
    pskIdentitiesRaw: Array<Byte>
): Array<Byte> {
    let extensions = ArrayList<TlsExtension>()
    for (ext in clientHello.extensions) {
        if (ext.extType == TLS13_EXT_PRE_SHARED_KEY) {
            extensions.add(TlsExtension(TLS13_EXT_PRE_SHARED_KEY, pskIdentitiesRaw))
        } else {
            extensions.add(ext)
        }
    }
    let partial = TlsClientHello(
        clientHello.random,
        clientHello.cipherSuites,
        sessionId: clientHello.sessionId,
        compressionMethods: clientHello.compressionMethods,
        extensions: extensions.toArray(),
        legacyVersion: clientHello.legacyVersion
    )
    sha256(tlsEncodeClientHelloHandshake(partial))
}

private func tls13ComputePskBinder(psk: Array<Byte>, transcriptHash: Array<Byte>): Array<Byte> {
    if (psk.size == 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 PSK must not be empty")
    }
    if (transcriptHash.size != TLS13_HASH_LEN) {
        throw CryptoException(InvalidArgument, "TLS1.3 transcript hash must be SHA-256 sized")
    }
    let zeros = Array<Byte>(TLS13_HASH_LEN, repeat: 0)
    let emptyHash = sha256([])
    let earlySecret = tls13HkdfExtract(zeros, psk)
    let binderKey = tls13DeriveSecret(earlySecret, "res binder", emptyHash)
    let finishedKey = tls13HkdfExpandLabel(binderKey, "finished", [], TLS13_HASH_LEN)
    hmac(HashAlgorithm.SHA256, finishedKey, transcriptHash)
}

private func tls13TryDecodeSessionTicket(encodedTicket: Array<Byte>): ?TlsSessionTicket {
    try {
        Some(tlsDecodeSessionTicket(encodedTicket))
    } catch (_: CryptoException) {
        None
    }
}

private func tls13HkdfExtract(salt: Array<Byte>, ikm: Array<Byte>): Array<Byte> {
    let normalizedSalt = if (salt.size == 0) {
        Array<Byte>(TLS13_HASH_LEN, repeat: 0)
    } else {
        salt
    }
    hmac(HashAlgorithm.SHA256, normalizedSalt, ikm)
}

private func tls13HkdfExpand(prk: Array<Byte>, info: Array<Byte>, outputLen: Int64): Array<Byte> {
    if (outputLen < 0) {
        throw CryptoException(InvalidArgument, "TLS1.3 HKDF output length must be >= 0")
    }
    if (outputLen == 0) {
        return []
    }

    let out = Array<Byte>(outputLen, repeat: 0)
    var t = Array<Byte>(0, repeat: 0)
    var offset: Int64 = 0
    var counter: Int64 = 1
    while (offset < outputLen) {
        if (counter > 255) {
            throw CryptoException(OutOfBounds, "TLS1.3 HKDF expand output is too large")
        }
        let input = Array<Byte>(t.size + info.size + 1, repeat: 0)
        if (t.size > 0) {
            secureCopyInto(t, input)
        }
        if (info.size > 0) {
            secureCopyInto(info, input, dstOffset: t.size)
        }
        input[input.size - 1] = UInt8(counter)

        t = hmac(HashAlgorithm.SHA256, prk, input)
        let remain = outputLen - offset
        let take = if (remain < t.size) {
            remain
        } else {
            t.size
        }
        var i = 0
        while (i < take) {
            out[offset + i] = t[i]
            i += 1
        }
        offset += take
        counter += 1
    }
    out
}

private func tls13HkdfExpandLabel(secret: Array<Byte>, label: String, context: Array<Byte>, outputLen: Int64): Array<Byte> {
    let fullLabel = "tls13 ${label}".toArray()
    if (fullLabel.size > 255 || context.size > 255) {
        throw CryptoException(OutOfBounds, "TLS1.3 HKDF label/context is too long")
    }
    let hkdfLabel = Array<Byte>(2 + 1 + fullLabel.size + 1 + context.size, repeat: 0)
    let len = tls13EncodeUInt16(outputLen)
    hkdfLabel[0] = len[0]
    hkdfLabel[1] = len[1]
    hkdfLabel[2] = UInt8(fullLabel.size)
    secureCopyInto(fullLabel, hkdfLabel, dstOffset: 3)
    hkdfLabel[3 + fullLabel.size] = UInt8(context.size)
    if (context.size > 0) {
        secureCopyInto(context, hkdfLabel, dstOffset: 4 + fullLabel.size)
    }
    tls13HkdfExpand(secret, hkdfLabel, outputLen)
}

private func tls13DeriveSecret(secret: Array<Byte>, label: String, transcriptHash: Array<Byte>): Array<Byte> {
    tls13HkdfExpandLabel(secret, label, transcriptHash, TLS13_HASH_LEN)
}

private func tls13RequireSupportedEcdheCurve(curve: NamedCurve): Unit {
    if (curve != P256 && curve != P384) {
        throw CryptoException(Unsupported, "TLS1.3 key_share curve is unsupported: ${curve.toString()}")
    }
}

private func tls13ResolveEcdheCurveSpecFromPublicKey(publicKey: EcPublicKey): (Int64, Int64) {
    if (publicKey.curve == P256) {
        return (TLS13_GROUP_SECP256R1, TLS13_P256_FIELD_BYTES)
    }
    if (publicKey.curve == P384) {
        return (TLS13_GROUP_SECP384R1, TLS13_P384_FIELD_BYTES)
    }
    throw CryptoException(Unsupported, "TLS1.3 key_share curve is unsupported: ${publicKey.curve.toString()}")
}

private func tls13ResolveEcdheCurveSpecFromNamedGroup(group: Int64): (NamedCurve, Int64) {
    if (group == TLS13_GROUP_SECP256R1) {
        return (P256, TLS13_P256_FIELD_BYTES)
    }
    if (group == TLS13_GROUP_SECP384R1) {
        return (P384, TLS13_P384_FIELD_BYTES)
    }
    throw CryptoException(Unsupported, "TLS1.3 key_share group is unsupported: ${group}")
}

private func tls13EncodeEcPoint(publicKey: EcPublicKey, fieldBytes: Int64): Array<Byte> {
    let out = Array<Byte>(1 + fieldBytes * 2, repeat: 0)
    out[0] = UInt8(TLS13_ECC_POINT_UNCOMPRESSED)
    let x = publicKey.x.toBytesBE(paddedLen: fieldBytes)
    let y = publicKey.y.toBytesBE(paddedLen: fieldBytes)
    secureCopyInto(x, out, dstOffset: 1)
    secureCopyInto(y, out, dstOffset: 1 + fieldBytes)
    out
}

private func tls13DecodeEcPoint(encoded: Array<Byte>, curve: NamedCurve, fieldBytes: Int64): EcPublicKey {
    if (encoded.size != 1 + fieldBytes * 2) {
        throw CryptoException(ParseError, "TLS1.3 key_share point length is invalid for curve ${curve.toString()}")
    }
    if (Int64(UInt8(encoded[0])) != TLS13_ECC_POINT_UNCOMPRESSED) {
        throw CryptoException(ParseError, "TLS1.3 key_share point must be uncompressed")
    }

    let x = BigNum.fromBytesBE(encoded[1..(1 + fieldBytes)])
    let y = BigNum.fromBytesBE(encoded[(1 + fieldBytes)..])
    EcPublicKey(curve, x, y)
}

private func tls13EncodeVector16(payload: Array<Byte>): Array<Byte> {
    if (payload.size > 65535) {
        throw CryptoException(OutOfBounds, "vector16 payload is too large")
    }
    let out = Array<Byte>(2 + payload.size, repeat: 0)
    let len = tls13EncodeUInt16(payload.size)
    out[0] = len[0]
    out[1] = len[1]
    secureCopyInto(payload, out, dstOffset: 2)
    out
}

private func tls13DecodeVector16(data: Array<Byte>, label: String): Array<Byte> {
    if (data.size < 2) {
        throw CryptoException(ParseError, "${label} is too short")
    }
    let len = tls13DecodeUInt16(data, 0)
    if (len != data.size - 2) {
        throw CryptoException(ParseError, "${label} length mismatch")
    }
    data[2..]
}

@OverflowWrapping
private func tls13EncodeUInt16(value: Int64): Array<Byte> {
    if (value < 0 || value > 65535) {
        throw CryptoException(OutOfBounds, "value does not fit into uint16")
    }
    let v = UInt16(value)
    [UInt8((v >> 8) & UInt16(0xff)), UInt8(v & UInt16(0xff))]
}

@OverflowWrapping
private func tls13DecodeUInt16(bytes: Array<Byte>, offset: Int64): Int64 {
    if (offset < 0 || offset + 2 > bytes.size) {
        throw CryptoException(ParseError, "uint16 decode out of bounds")
    }
    (Int64(UInt8(bytes[offset])) << 8) | Int64(UInt8(bytes[offset + 1]))
}

@OverflowWrapping
private func tls13EncodeUInt32(value: Int64): Array<Byte> {
    if (value < 0 || value > 0xffff_ffff) {
        throw CryptoException(OutOfBounds, "value does not fit into uint32")
    }
    let v = UInt64(value)
    [
        UInt8((v >> 24) & UInt64(0xff)),
        UInt8((v >> 16) & UInt64(0xff)),
        UInt8((v >> 8) & UInt64(0xff)),
        UInt8(v & UInt64(0xff))
    ]
}

private func tls13EncodeUInt32Into(value: Int64, out: Array<Byte>, offset: Int64): Unit {
    if (offset < 0 || offset + 4 > out.size) {
        throw CryptoException(OutOfBounds, "uint32 encode out of bounds")
    }
    let encoded = tls13EncodeUInt32(value)
    out[offset] = encoded[0]
    out[offset + 1] = encoded[1]
    out[offset + 2] = encoded[2]
    out[offset + 3] = encoded[3]
}

@OverflowWrapping
private func tls13DecodeUInt32(bytes: Array<Byte>, offset: Int64): Int64 {
    if (offset < 0 || offset + 4 > bytes.size) {
        throw CryptoException(ParseError, "uint32 decode out of bounds")
    }
    (Int64(UInt8(bytes[offset])) << 24) |
        (Int64(UInt8(bytes[offset + 1])) << 16) |
        (Int64(UInt8(bytes[offset + 2])) << 8) |
        Int64(UInt8(bytes[offset + 3]))
}

private func tls13EncodeExtensionList(extensions: Array<TlsExtension>): Array<Byte> {
    if (extensions.size == 0) {
        return []
    }
    let out = ArrayList<Byte>()
    for (ext in extensions) {
        let extType = tls13EncodeUInt16(ext.extType)
        let extLen = tls13EncodeUInt16(ext.data.size)
        out.add(extType[0])
        out.add(extType[1])
        out.add(extLen[0])
        out.add(extLen[1])
        for (b in ext.data) {
            out.add(b)
        }
    }
    out.toArray()
}

private func tls13DecodeExtensionList(encoded: Array<Byte>): Array<TlsExtension> {
    if (encoded.size == 0) {
        return []
    }
    let list = ArrayList<TlsExtension>()
    var offset = 0
    while (offset < encoded.size) {
        if (offset + 4 > encoded.size) {
            throw CryptoException(ParseError, "TLS1.3 extension list is truncated")
        }
        let extType = tls13DecodeUInt16(encoded, offset)
        offset += 2
        let extLen = tls13DecodeUInt16(encoded, offset)
        offset += 2
        if (offset + extLen > encoded.size) {
            throw CryptoException(ParseError, "TLS1.3 extension payload exceeds envelope length")
        }
        let data = encoded[offset..(offset + extLen)]
        list.add(TlsExtension(extType, data))
        offset += extLen
    }
    list.toArray()
}

private func tls13CloneByteArrayArray(values: Array<Array<Byte>>): Array<Array<Byte>> {
    if (values.size == 0) {
        return []
    }
    let out = Array<Array<Byte>>(values.size, repeat: values[0].clone())
    var i = 0
    while (i < values.size) {
        out[i] = values[i].clone()
        i += 1
    }
    out
}

private func concat(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    secureCopyInto(left, out)
    secureCopyInto(right, out, dstOffset: left.size)
    out
}

private func tls13ContainsString(values: Array<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    false
}

private func tls13MergePolicyIntermediates(
    base: X509VerificationPolicy,
    embeddedIntermediates: Array<X509Certificate>
): X509VerificationPolicy {
    let mergedIntermediates = tls13ConcatCertArray(base.intermediates, embeddedIntermediates)
    X509VerificationPolicy(
        base.trustAnchors,
        intermediates: mergedIntermediates,
        crls: base.crls,
        requireCrlForAllIssuers: base.requireCrlForAllIssuers,
        requireCrlIfDistributionPointsPresent: base.requireCrlIfDistributionPointsPresent,
        requireCrlAuthorityKeyIdentifierMatch: base.requireCrlAuthorityKeyIdentifierMatch,
        requireAuthorityKeyIdentifierMatch: base.requireAuthorityKeyIdentifierMatch,
        requiredLeafKeyUsageMask: base.requiredLeafKeyUsageMask,
        requiredLeafExtendedKeyUsages: base.requiredLeafExtendedKeyUsages,
        requiredLeafCertificatePolicies: base.requiredLeafCertificatePolicies,
        requiredLeafDnsName: base.requiredLeafDnsName,
        validationTime: base.validationTime,
        revokedSerialHexLower: base.revokedSerialHexLower
    )
}

private func tls13ConcatCertArray(left: Array<X509Certificate>, right: Array<X509Certificate>): Array<X509Certificate> {
    if (left.size == 0) {
        return right.clone()
    }
    if (right.size == 0) {
        return left.clone()
    }
    let out = Array<X509Certificate>(left.size + right.size, repeat: left[0])
    var i = 0
    while (i < left.size) {
        out[i] = left[i]
        i += 1
    }
    i = 0
    while (i < right.size) {
        out[left.size + i] = right[i]
        i += 1
    }
    out
}

private func tls13EncodeEcdsaSignatureDer(r: BigNum, s: BigNum): Array<Byte> {
    let encodedR = tls13DerEncodeUnsignedInteger(r, "TLS1.3 ECDSA signature.r")
    let encodedS = tls13DerEncodeUnsignedInteger(s, "TLS1.3 ECDSA signature.s")
    let payload = concat(encodedR, encodedS)
    tls13DerWrap(0x30, payload)
}

private func tls13DecodeEcdsaSignatureDer(signatureDer: Array<Byte>): (BigNum, BigNum) {
    let (tag, sequenceValue, consumed) = tls13DerReadElement(signatureDer, 0, "TLS1.3 ECDSA signature")
    if (tag != 0x30) {
        throw CryptoException(ParseError, "TLS1.3 ECDSA signature must be DER SEQUENCE")
    }
    if (consumed != signatureDer.size) {
        throw CryptoException(ParseError, "TLS1.3 ECDSA signature has trailing bytes")
    }

    let (rTag, rValue, rConsumed) = tls13DerReadElement(sequenceValue, 0, "TLS1.3 ECDSA signature.r")
    if (rTag != 0x02) {
        throw CryptoException(ParseError, "TLS1.3 ECDSA signature.r must be DER INTEGER")
    }
    let (sTag, sValue, sConsumed) = tls13DerReadElement(sequenceValue, rConsumed, "TLS1.3 ECDSA signature.s")
    if (sTag != 0x02) {
        throw CryptoException(ParseError, "TLS1.3 ECDSA signature.s must be DER INTEGER")
    }
    if (rConsumed + sConsumed != sequenceValue.size) {
        throw CryptoException(ParseError, "TLS1.3 ECDSA signature sequence has trailing bytes")
    }

    let rBytes = tls13ParsePositiveDerInteger(rValue, "TLS1.3 ECDSA signature.r")
    let sBytes = tls13ParsePositiveDerInteger(sValue, "TLS1.3 ECDSA signature.s")
    (BigNum.fromBytesBE(rBytes), BigNum.fromBytesBE(sBytes))
}

private func tls13DerEncodeUnsignedInteger(value: BigNum, label: String): Array<Byte> {
    if (value.isNegative() || value.isZero()) {
        throw CryptoException(InvalidArgument, "${label} must be positive")
    }
    let magnitude = value.toBytesBE()
    if (magnitude.size == 0) {
        throw CryptoException(InvalidArgument, "${label} must not be empty")
    }
    let highBitSet = (Int64(UInt8(magnitude[0])) & 0x80) != 0
    if (!highBitSet) {
        return tls13DerWrap(0x02, magnitude)
    }
    let withPad = Array<Byte>(magnitude.size + 1, repeat: 0)
    secureCopyInto(magnitude, withPad, dstOffset: 1)
    tls13DerWrap(0x02, withPad)
}

private func tls13ParsePositiveDerInteger(value: Array<Byte>, label: String): Array<Byte> {
    if (value.size == 0) {
        throw CryptoException(ParseError, "${label} must not be empty")
    }
    if ((Int64(UInt8(value[0])) & 0x80) != 0) {
        throw CryptoException(ParseError, "${label} must be non-negative")
    }
    if (value.size > 1 && UInt8(value[0]) == UInt8(0x00) && (Int64(UInt8(value[1])) & 0x80) == 0) {
        throw CryptoException(ParseError, "${label} uses non-minimal encoding")
    }
    if (value.size > 1 && UInt8(value[0]) == UInt8(0x00)) {
        return value[1..]
    }
    value
}

private func tls13DerWrap(tag: Int64, value: Array<Byte>): Array<Byte> {
    if (tag < 0 || tag > 255) {
        throw CryptoException(InvalidArgument, "DER tag must be uint8")
    }
    let length = tls13DerEncodeLength(value.size)
    let out = Array<Byte>(1 + length.size + value.size, repeat: 0)
    out[0] = UInt8(tag)
    secureCopyInto(length, out, dstOffset: 1)
    secureCopyInto(value, out, dstOffset: 1 + length.size)
    out
}

private func tls13DerEncodeLength(length: Int64): Array<Byte> {
    if (length < 0) {
        throw CryptoException(OutOfBounds, "DER length must be non-negative")
    }
    if (length < 128) {
        return [UInt8(length)]
    }

    let width = if (length <= 0xff) {
        1
    } else if (length <= 0xffff) {
        2
    } else if (length <= 0xffffff) {
        3
    } else if (length <= 0xffffffff) {
        4
    } else {
        throw CryptoException(OutOfBounds, "DER length exceeds 4-byte support limit")
    }

    let out = Array<Byte>(1 + width, repeat: 0)
    out[0] = UInt8(0x80 | width)
    var i = 0
    while (i < width) {
        let shift = (width - 1 - i) * 8
        out[1 + i] = UInt8((length >> shift) & 0xff)
        i += 1
    }
    out
}

private func tls13DerReadElement(der: Array<Byte>, offset: Int64, label: String): (Int64, Array<Byte>, Int64) {
    if (offset < 0 || offset >= der.size) {
        throw CryptoException(ParseError, "${label} is truncated")
    }
    let tag = Int64(UInt8(der[offset]))
    let (length, lengthBytes) = tls13DerDecodeLength(der, offset + 1, label)
    let valueOffset = offset + 1 + lengthBytes
    if (valueOffset + length > der.size) {
        throw CryptoException(ParseError, "${label} value is truncated")
    }
    let value = der[valueOffset..(valueOffset + length)]
    let consumed = 1 + lengthBytes + length
    (tag, value, consumed)
}

private func tls13DerDecodeLength(der: Array<Byte>, offset: Int64, label: String): (Int64, Int64) {
    if (offset < 0 || offset >= der.size) {
        throw CryptoException(ParseError, "${label} DER length is truncated")
    }
    let first = Int64(UInt8(der[offset]))
    if ((first & 0x80) == 0) {
        return (first, 1)
    }

    let width = first & 0x7f
    if (width == 0) {
        throw CryptoException(ParseError, "${label} DER length uses indefinite form")
    }
    if (width > 4) {
        throw CryptoException(ParseError, "${label} DER length width is too large")
    }
    if (offset + 1 + width > der.size) {
        throw CryptoException(ParseError, "${label} DER length is truncated")
    }

    var length: Int64 = 0
    var i = 0
    while (i < width) {
        length = (length << 8) | Int64(UInt8(der[offset + 1 + i]))
        i += 1
    }
    if (length < 128) {
        throw CryptoException(ParseError, "${label} DER length uses non-minimal long form")
    }
    (length, 1 + width)
}
