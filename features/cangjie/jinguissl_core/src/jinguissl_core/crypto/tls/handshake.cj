package jinguissl_core.crypto.tls

import std.collection.ArrayList
import jinguissl_core.crypto.compliance.{TlsVersion}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.utils.secureCopyInto

public let TLS_HANDSHAKE_HEADER_LEN: Int64 = 4
public let TLS_HANDSHAKE_MAX_BODY_LEN: Int64 = 0x00ff_ffff
public let TLS_HELLO_RANDOM_LEN: Int64 = 32
public let TLS_SESSION_ID_MAX_LEN: Int64 = 32
public let TLS_EXT_SERVER_NAME: Int64 = 0x0000
public let TLS_EXT_STATUS_REQUEST: Int64 = 0x0005
public let TLS_EXT_ALPN: Int64 = 0x0010
public let TLS_SNI_NAME_TYPE_HOST_NAME: Int64 = 0
public let TLS_STATUS_REQUEST_TYPE_OCSP: Int64 = 1

public enum TlsHandshakeType <: Equatable<TlsHandshakeType> & ToString {
    | ClientHello
    | ServerHello
    | NewSessionTicket
    | EncryptedExtensions
    | CertificateRequest
    | Certificate
    | CertificateVerify
    | ServerKeyExchange
    | ClientKeyExchange
    | Finished
    | KeyUpdate

    public operator func ==(right: TlsHandshakeType): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: TlsHandshakeType): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ClientHello => 0
            case ServerHello => 1
            case NewSessionTicket => 2
            case EncryptedExtensions => 3
            case CertificateRequest => 4
            case Certificate => 5
            case CertificateVerify => 6
            case ServerKeyExchange => 7
            case ClientKeyExchange => 8
            case Finished => 9
            case KeyUpdate => 10
        }
    }

    public func toString(): String {
        match (this) {
            case ClientHello => "CLIENT_HELLO"
            case ServerHello => "SERVER_HELLO"
            case NewSessionTicket => "NEW_SESSION_TICKET"
            case EncryptedExtensions => "ENCRYPTED_EXTENSIONS"
            case CertificateRequest => "CERTIFICATE_REQUEST"
            case Certificate => "CERTIFICATE"
            case CertificateVerify => "CERTIFICATE_VERIFY"
            case ServerKeyExchange => "SERVER_KEY_EXCHANGE"
            case ClientKeyExchange => "CLIENT_KEY_EXCHANGE"
            case Finished => "FINISHED"
            case KeyUpdate => "KEY_UPDATE"
        }
    }
}

public class TlsHandshakeFrame {
    public let msgType: TlsHandshakeType
    public let body: Array<Byte>

    public init(msgType: TlsHandshakeType, body: Array<Byte>) {
        if (body.size > TLS_HANDSHAKE_MAX_BODY_LEN) {
            throw CryptoException(OutOfBounds, "TLS handshake body is too large")
        }
        this.msgType = msgType
        this.body = body.clone()
    }
}

public class TlsExtension {
    public let extType: Int64
    public let data: Array<Byte>

    public init(extType: Int64, data: Array<Byte>) {
        if (extType < 0 || extType > 65535) {
            throw CryptoException(InvalidArgument, "TLS extension type must be uint16")
        }
        if (data.size > 65535) {
            throw CryptoException(OutOfBounds, "TLS extension payload is too large")
        }
        this.extType = extType
        this.data = data.clone()
    }
}

public class TlsOcspStatusRequest {
    public let statusType: Int64
    public let responderIds: Array<Array<Byte>>
    public let requestExtensions: Array<Byte>

    public init(
        statusType!: Int64 = TLS_STATUS_REQUEST_TYPE_OCSP,
        responderIds!: Array<Array<Byte>> = [],
        requestExtensions!: Array<Byte> = []
    ) {
        if (statusType < 0 || statusType > 255) {
            throw CryptoException(InvalidArgument, "TLS OCSP status_request status_type must be uint8")
        }
        if (requestExtensions.size > 65535) {
            throw CryptoException(OutOfBounds, "TLS OCSP status_request request_extensions exceeds uint16 length")
        }

        var i = 0
        while (i < responderIds.size) {
            let responderId = responderIds[i]
            if (responderId.size == 0) {
                throw CryptoException(InvalidArgument, "TLS OCSP status_request responder_id must not be empty")
            }
            if (responderId.size > 65535) {
                throw CryptoException(OutOfBounds, "TLS OCSP status_request responder_id exceeds uint16 length")
            }
            i += 1
        }

        this.statusType = statusType
        this.responderIds = cloneByteArrayList(responderIds)
        this.requestExtensions = requestExtensions.clone()
    }
}

public class TlsClientHello {
    public let legacyVersion: TlsVersion
    public let random: Array<Byte>
    public let sessionId: Array<Byte>
    public let cipherSuites: Array<Int64>
    public let compressionMethods: Array<Byte>
    public let extensions: Array<TlsExtension>

    public init(
        random: Array<Byte>,
        cipherSuites: Array<Int64>,
        sessionId!: Array<Byte> = [],
        compressionMethods!: Array<Byte> = [0],
        extensions!: Array<TlsExtension> = [],
        legacyVersion!: TlsVersion = TLS1_2
    ) {
        requireRandom(random)
        requireSessionId(sessionId)
        requireCipherSuites(cipherSuites)
        requireCompressionMethods(compressionMethods)

        this.legacyVersion = legacyVersion
        this.random = random.clone()
        this.sessionId = sessionId.clone()
        this.cipherSuites = cipherSuites.clone()
        this.compressionMethods = compressionMethods.clone()
        this.extensions = extensions.clone()
    }
}

public class TlsServerHello {
    public let legacyVersion: TlsVersion
    public let random: Array<Byte>
    public let sessionId: Array<Byte>
    public let cipherSuite: Int64
    public let compressionMethod: Byte
    public let extensions: Array<TlsExtension>

    public init(
        random: Array<Byte>,
        cipherSuite: Int64,
        sessionId!: Array<Byte> = [],
        compressionMethod!: Byte = 0,
        extensions!: Array<TlsExtension> = [],
        legacyVersion!: TlsVersion = TLS1_2
    ) {
        requireRandom(random)
        requireSessionId(sessionId)
        requireCipherSuite(cipherSuite)

        this.legacyVersion = legacyVersion
        this.random = random.clone()
        this.sessionId = sessionId.clone()
        this.cipherSuite = cipherSuite
        this.compressionMethod = compressionMethod
        this.extensions = extensions.clone()
    }
}

public class TlsKeyExchangeMessage {
    public let exchangeData: Array<Byte>

    public init(exchangeData: Array<Byte>) {
        if (exchangeData.size == 0) {
            throw CryptoException(InvalidArgument, "TLS key exchange payload must not be empty")
        }
        if (exchangeData.size > TLS_HANDSHAKE_MAX_BODY_LEN) {
            throw CryptoException(OutOfBounds, "TLS key exchange payload is too large")
        }
        this.exchangeData = exchangeData.clone()
    }
}

public class TlsCertificateEntry {
    public let certData: Array<Byte>
    public let extensions: Array<TlsExtension>

    public init(certData: Array<Byte>, extensions!: Array<TlsExtension> = []) {
        if (certData.size == 0) {
            throw CryptoException(InvalidArgument, "TLS certificate entry cert_data must not be empty")
        }
        if (certData.size > TLS_HANDSHAKE_MAX_BODY_LEN) {
            throw CryptoException(OutOfBounds, "TLS certificate entry cert_data is too large")
        }
        this.certData = certData.clone()
        this.extensions = extensions.clone()
    }
}

public class Tls13CertificateMessage {
    public let requestContext: Array<Byte>
    public let entries: Array<TlsCertificateEntry>

    public init(requestContext!: Array<Byte> = [], entries!: Array<TlsCertificateEntry> = []) {
        if (requestContext.size > 255) {
            throw CryptoException(OutOfBounds, "TLS1.3 certificate request context exceeds uint8 length")
        }
        this.requestContext = requestContext.clone()
        this.entries = entries.clone()
    }
}

public class TlsEncryptedExtensionsMessage {
    public let extensions: Array<TlsExtension>

    public init(extensions!: Array<TlsExtension> = []) {
        this.extensions = extensions.clone()
    }
}

public class Tls13CertificateRequestMessage {
    public let requestContext: Array<Byte>
    public let extensions: Array<TlsExtension>

    public init(requestContext!: Array<Byte> = [], extensions!: Array<TlsExtension> = []) {
        if (requestContext.size > 255) {
            throw CryptoException(OutOfBounds, "TLS1.3 CertificateRequest.request_context exceeds uint8 length")
        }
        this.requestContext = requestContext.clone()
        this.extensions = extensions.clone()
    }
}

public class TlsCertificateVerifyMessage {
    public let signatureScheme: Int64
    public let signature: Array<Byte>

    public init(signatureScheme: Int64, signature: Array<Byte>) {
        if (signatureScheme < 0 || signatureScheme > 65535) {
            throw CryptoException(InvalidArgument, "TLS CertificateVerify signature_scheme must be uint16")
        }
        if (signature.size == 0) {
            throw CryptoException(InvalidArgument, "TLS CertificateVerify signature must not be empty")
        }
        if (signature.size > 65535) {
            throw CryptoException(OutOfBounds, "TLS CertificateVerify signature exceeds uint16 length")
        }
        this.signatureScheme = signatureScheme
        this.signature = signature.clone()
    }
}

public func tlsEncodeHandshakeFrame(frame: TlsHandshakeFrame): Array<Byte> {
    let out = Array<Byte>(TLS_HANDSHAKE_HEADER_LEN + frame.body.size, repeat: 0)
    out[0] = handshakeTypeToWire(frame.msgType)
    let len = hsEncodeUInt24(frame.body.size)
    out[1] = len[0]
    out[2] = len[1]
    out[3] = len[2]
    secureCopyInto(frame.body, out, dstOffset: TLS_HANDSHAKE_HEADER_LEN)
    out
}

/**
 * tlsDecodeHandshakeFrame.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeHandshakeFrame(encoded: Array<Byte>): TlsHandshakeFrame {
    if (encoded.size < TLS_HANDSHAKE_HEADER_LEN) {
        throw CryptoException(ParseError, "TLS handshake is shorter than header")
    }

    let msgType = handshakeTypeFromWire(UInt8(encoded[0]))
    let bodyLen = hsDecodeUInt24(encoded, 1)
    if (bodyLen > TLS_HANDSHAKE_MAX_BODY_LEN) {
        throw CryptoException(ParseError, "TLS handshake length exceeds uint24 max")
    }
    if (encoded.size != TLS_HANDSHAKE_HEADER_LEN + bodyLen) {
        throw CryptoException(ParseError, "TLS handshake length field mismatch")
    }

    TlsHandshakeFrame(msgType, encoded[TLS_HANDSHAKE_HEADER_LEN..])
}

public func tlsEncodeClientHelloBody(clientHello: TlsClientHello): Array<Byte> {
    let list = ArrayList<Byte>()
    appendBytes(list, hsVersionToWire(clientHello.legacyVersion))
    appendBytes(list, clientHello.random)
    appendVariableVector8(list, clientHello.sessionId, "TLS ClientHello.session_id")

    let suites = encodeCipherSuites(clientHello.cipherSuites)
    appendVariableVector16(list, suites, "TLS ClientHello.cipher_suites")

    appendVariableVector8(list, clientHello.compressionMethods, "TLS ClientHello.compression_methods")

    let extBytes = encodeExtensions(clientHello.extensions)
    appendVariableVector16(list, extBytes, "TLS ClientHello.extensions")
    list.toArray()
}

/**
 * tlsDecodeClientHelloBody.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeClientHelloBody(body: Array<Byte>): TlsClientHello {
    var offset = 0
    let version = hsVersionFromWire(body, offset)
    offset += 2

    let random = readRange(body, offset, TLS_HELLO_RANDOM_LEN, "TLS ClientHello random")
    offset += TLS_HELLO_RANDOM_LEN

    let sessionIdLen = readUInt8(body, offset, "TLS ClientHello session_id length")
    offset += 1
    let sessionId = readRange(body, offset, sessionIdLen, "TLS ClientHello session_id")
    offset += sessionIdLen

    let suitesLen = hsDecodeUInt16(body, offset)
    offset += 2
    if (suitesLen == 0 || (suitesLen % 2) != 0) {
        throw CryptoException(ParseError, "TLS ClientHello cipher_suites length is invalid")
    }
    let suitesBytes = readRange(body, offset, suitesLen, "TLS ClientHello cipher_suites")
    offset += suitesLen
    let cipherSuites = decodeCipherSuites(suitesBytes)

    let compLen = readUInt8(body, offset, "TLS ClientHello compression_methods length")
    offset += 1
    if (compLen == 0) {
        throw CryptoException(ParseError, "TLS ClientHello compression_methods must not be empty")
    }
    let compressionMethods = readRange(body, offset, compLen, "TLS ClientHello compression_methods")
    offset += compLen

    let extLen = hsDecodeUInt16(body, offset)
    offset += 2
    let extBytes = readRange(body, offset, extLen, "TLS ClientHello extensions")
    offset += extLen

    if (offset != body.size) {
        throw CryptoException(ParseError, "TLS ClientHello contains trailing bytes")
    }

    let extensions = decodeExtensions(extBytes)
    TlsClientHello(
        random,
        cipherSuites,
        sessionId: sessionId,
        compressionMethods: compressionMethods,
        extensions: extensions,
        legacyVersion: version
    )
}

public func tlsEncodeClientHelloHandshake(clientHello: TlsClientHello): Array<Byte> {
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(ClientHello, tlsEncodeClientHelloBody(clientHello)))
}

/**
 * tlsDecodeClientHelloHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeClientHelloHandshake(encoded: Array<Byte>): TlsClientHello {
    let frame = tlsDecodeHandshakeFrame(encoded)
    if (frame.msgType != ClientHello) {
        throw CryptoException(ParseError, "handshake type is not ClientHello")
    }
    tlsDecodeClientHelloBody(frame.body)
}

public func tlsEncodeServerHelloBody(serverHello: TlsServerHello): Array<Byte> {
    let list = ArrayList<Byte>()
    appendBytes(list, hsVersionToWire(serverHello.legacyVersion))
    appendBytes(list, serverHello.random)
    appendVariableVector8(list, serverHello.sessionId, "TLS ServerHello.session_id")
    appendBytes(list, hsEncodeUInt16(serverHello.cipherSuite))
    list.add(serverHello.compressionMethod)

    let extBytes = encodeExtensions(serverHello.extensions)
    appendVariableVector16(list, extBytes, "TLS ServerHello.extensions")
    list.toArray()
}

/**
 * tlsDecodeServerHelloBody.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeServerHelloBody(body: Array<Byte>): TlsServerHello {
    var offset = 0
    let version = hsVersionFromWire(body, offset)
    offset += 2

    let random = readRange(body, offset, TLS_HELLO_RANDOM_LEN, "TLS ServerHello random")
    offset += TLS_HELLO_RANDOM_LEN

    let sessionIdLen = readUInt8(body, offset, "TLS ServerHello session_id length")
    offset += 1
    let sessionId = readRange(body, offset, sessionIdLen, "TLS ServerHello session_id")
    offset += sessionIdLen

    let cipherSuite = hsDecodeUInt16(body, offset)
    offset += 2
    let compressionMethod = readByte(body, offset, "TLS ServerHello compression_method")
    offset += 1

    let extLen = hsDecodeUInt16(body, offset)
    offset += 2
    let extBytes = readRange(body, offset, extLen, "TLS ServerHello extensions")
    offset += extLen

    if (offset != body.size) {
        throw CryptoException(ParseError, "TLS ServerHello contains trailing bytes")
    }

    let extensions = decodeExtensions(extBytes)
    TlsServerHello(
        random,
        cipherSuite,
        sessionId: sessionId,
        compressionMethod: compressionMethod,
        extensions: extensions,
        legacyVersion: version
    )
}

public func tlsEncodeServerHelloHandshake(serverHello: TlsServerHello): Array<Byte> {
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(ServerHello, tlsEncodeServerHelloBody(serverHello)))
}

/**
 * tlsDecodeServerHelloHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeServerHelloHandshake(encoded: Array<Byte>): TlsServerHello {
    let frame = tlsDecodeHandshakeFrame(encoded)
    if (frame.msgType != ServerHello) {
        throw CryptoException(ParseError, "handshake type is not ServerHello")
    }
    tlsDecodeServerHelloBody(frame.body)
}

public func tlsEncodeEncryptedExtensionsHandshake(message: TlsEncryptedExtensionsMessage): Array<Byte> {
    let extBytes = encodeExtensions(message.extensions)
    let body = ArrayList<Byte>()
    appendVariableVector16(body, extBytes, "TLS EncryptedExtensions.extensions")
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(EncryptedExtensions, body.toArray()))
}

/**
 * tlsDecodeEncryptedExtensionsHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeEncryptedExtensionsHandshake(encoded: Array<Byte>): TlsEncryptedExtensionsMessage {
    let frame = tlsDecodeHandshakeFrame(encoded)
    if (frame.msgType != EncryptedExtensions) {
        throw CryptoException(ParseError, "handshake type is not EncryptedExtensions")
    }
    if (frame.body.size < 2) {
        throw CryptoException(ParseError, "TLS EncryptedExtensions body is too short")
    }
    let extLen = hsDecodeUInt16(frame.body, 0)
    if (extLen != frame.body.size - 2) {
        throw CryptoException(ParseError, "TLS EncryptedExtensions.extensions length mismatch")
    }
    let extBytes = readRange(frame.body, 2, extLen, "TLS EncryptedExtensions.extensions")
    TlsEncryptedExtensionsMessage(extensions: decodeExtensions(extBytes))
}

public func tlsEncodeCertificateRequestHandshakeTls13(message: Tls13CertificateRequestMessage): Array<Byte> {
    let body = ArrayList<Byte>()
    appendVariableVector8(body, message.requestContext, "TLS13 CertificateRequest.request_context")
    let extBytes = encodeExtensions(message.extensions)
    appendVariableVector16(body, extBytes, "TLS13 CertificateRequest.extensions")
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(CertificateRequest, body.toArray()))
}

/**
 * tlsDecodeCertificateRequestHandshakeTls13.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeCertificateRequestHandshakeTls13(encoded: Array<Byte>): Tls13CertificateRequestMessage {
    let frame = tlsDecodeHandshakeFrame(encoded)
    if (frame.msgType != CertificateRequest) {
        throw CryptoException(ParseError, "handshake type is not CertificateRequest")
    }
    if (frame.body.size < 3) {
        throw CryptoException(ParseError, "TLS13 CertificateRequest body is too short")
    }

    var offset = 0
    let contextLen = readUInt8(frame.body, offset, "TLS13 CertificateRequest.request_context length")
    offset += 1
    let requestContext = readRange(frame.body, offset, contextLen, "TLS13 CertificateRequest.request_context")
    offset += contextLen

    if (offset + 2 > frame.body.size) {
        throw CryptoException(ParseError, "TLS13 CertificateRequest.extensions length is truncated")
    }
    let extLen = hsDecodeUInt16(frame.body, offset)
    offset += 2
    if (offset + extLen != frame.body.size) {
        throw CryptoException(ParseError, "TLS13 CertificateRequest.extensions length mismatch")
    }
    let extBytes = readRange(frame.body, offset, extLen, "TLS13 CertificateRequest.extensions")
    Tls13CertificateRequestMessage(requestContext: requestContext, extensions: decodeExtensions(extBytes))
}

public func tlsEncodeServerKeyExchangeHandshake(message: TlsKeyExchangeMessage): Array<Byte> {
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(ServerKeyExchange, message.exchangeData))
}

/**
 * tlsDecodeServerKeyExchangeHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeServerKeyExchangeHandshake(encoded: Array<Byte>): TlsKeyExchangeMessage {
    let frame = tlsDecodeHandshakeFrame(encoded)
    if (frame.msgType != ServerKeyExchange) {
        throw CryptoException(ParseError, "handshake type is not ServerKeyExchange")
    }
    TlsKeyExchangeMessage(frame.body)
}

public func tlsEncodeClientKeyExchangeHandshake(message: TlsKeyExchangeMessage): Array<Byte> {
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(ClientKeyExchange, message.exchangeData))
}

/**
 * tlsDecodeClientKeyExchangeHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeClientKeyExchangeHandshake(encoded: Array<Byte>): TlsKeyExchangeMessage {
    let frame = tlsDecodeHandshakeFrame(encoded)
    if (frame.msgType != ClientKeyExchange) {
        throw CryptoException(ParseError, "handshake type is not ClientKeyExchange")
    }
    TlsKeyExchangeMessage(frame.body)
}

public func tlsEncodeCertificateHandshakeTls12(certificates: Array<Array<Byte>>): Array<Byte> {
    let body = tlsEncodeCertificateBodyTls12(certificates)
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(Certificate, body))
}

/**
 * tlsDecodeCertificateHandshakeTls12.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeCertificateHandshakeTls12(encoded: Array<Byte>): Array<Array<Byte>> {
    let frame = tlsDecodeHandshakeFrame(encoded)
    if (frame.msgType != Certificate) {
        throw CryptoException(ParseError, "handshake type is not Certificate")
    }
    tlsDecodeCertificateBodyTls12(frame.body)
}

public func tlsEncodeCertificateHandshakeTls13(message: Tls13CertificateMessage): Array<Byte> {
    let body = tlsEncodeCertificateBodyTls13(message)
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(Certificate, body))
}

/**
 * tlsDecodeCertificateHandshakeTls13.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeCertificateHandshakeTls13(encoded: Array<Byte>): Tls13CertificateMessage {
    let frame = tlsDecodeHandshakeFrame(encoded)
    if (frame.msgType != Certificate) {
        throw CryptoException(ParseError, "handshake type is not Certificate")
    }
    tlsDecodeCertificateBodyTls13(frame.body)
}

public func tlsEncodeCertificateVerifyHandshake(message: TlsCertificateVerifyMessage): Array<Byte> {
    let body = Array<Byte>(4 + message.signature.size, repeat: 0)
    let scheme = hsEncodeUInt16(message.signatureScheme)
    body[0] = scheme[0]
    body[1] = scheme[1]
    let sigLen = hsEncodeUInt16(message.signature.size)
    body[2] = sigLen[0]
    body[3] = sigLen[1]
    secureCopyInto(message.signature, body, dstOffset: 4)
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(CertificateVerify, body))
}

/**
 * tlsDecodeCertificateVerifyHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeCertificateVerifyHandshake(encoded: Array<Byte>): TlsCertificateVerifyMessage {
    let frame = tlsDecodeHandshakeFrame(encoded)
    if (frame.msgType != CertificateVerify) {
        throw CryptoException(ParseError, "handshake type is not CertificateVerify")
    }
    if (frame.body.size < 4) {
        throw CryptoException(ParseError, "TLS CertificateVerify body is too short")
    }

    let signatureScheme = hsDecodeUInt16(frame.body, 0)
    let signatureLen = hsDecodeUInt16(frame.body, 2)
    if (signatureLen == 0 || signatureLen != frame.body.size - 4) {
        throw CryptoException(ParseError, "TLS CertificateVerify signature length is invalid")
    }
    let signature = readRange(frame.body, 4, signatureLen, "TLS CertificateVerify signature")
    TlsCertificateVerifyMessage(signatureScheme, signature)
}

/**
 * tlsEncodeFinishedHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsEncodeFinishedHandshake(verifyData: Array<Byte>): Array<Byte> {
    if (verifyData.size == 0) {
        throw CryptoException(InvalidArgument, "TLS Finished verify_data must not be empty")
    }
    tlsEncodeHandshakeFrame(TlsHandshakeFrame(Finished, verifyData))
}

/**
 * tlsDecodeFinishedHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeFinishedHandshake(encoded: Array<Byte>): Array<Byte> {
    let frame = tlsDecodeHandshakeFrame(encoded)
    if (frame.msgType != Finished) {
        throw CryptoException(ParseError, "handshake type is not Finished")
    }
    if (frame.body.size == 0) {
        throw CryptoException(ParseError, "TLS Finished verify_data must not be empty")
    }
    frame.body
}

public func tlsFindExtension(extensions: Array<TlsExtension>, extType: Int64): ?TlsExtension {
    for (ext in extensions) {
        if (ext.extType == extType) {
            return Some(ext)
        }
    }
    None
}

public func tlsBuildServerNameExtension(hostName: String): TlsExtension {
    let normalizedHostName = normalizeHostName(hostName, "TLS SNI host_name")
    let hostBytes = normalizedHostName.toArray()
    let hostEntry = ArrayList<Byte>()
    hostEntry.add(UInt8(TLS_SNI_NAME_TYPE_HOST_NAME))
    appendBytes(hostEntry, hsEncodeUInt16(hostBytes.size))
    appendBytes(hostEntry, hostBytes)

    let listBytes = hostEntry.toArray()
    let payload = ArrayList<Byte>()
    appendBytes(payload, hsEncodeUInt16(listBytes.size))
    appendBytes(payload, listBytes)
    TlsExtension(TLS_EXT_SERVER_NAME, payload.toArray())
}

/**
 * tlsParseServerNameExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsParseServerNameExtension(extension: TlsExtension): Array<String> {
    if (extension.extType != TLS_EXT_SERVER_NAME) {
        throw CryptoException(InvalidArgument, "extension is not server_name")
    }
    if (extension.data.size < 2) {
        throw CryptoException(ParseError, "TLS server_name extension is too short")
    }

    let listLen = hsDecodeUInt16(extension.data, 0)
    if (listLen == 0) {
        throw CryptoException(ParseError, "TLS server_name extension list must not be empty")
    }
    if (listLen != extension.data.size - 2) {
        throw CryptoException(ParseError, "TLS server_name extension list length mismatch")
    }

    var offset = 2
    let hostNames = ArrayList<String>()
    while (offset < extension.data.size) {
        let nameType = readUInt8(extension.data, offset, "TLS server_name name_type")
        offset += 1
        let nameLen = hsDecodeUInt16(extension.data, offset)
        offset += 2
        if (nameLen == 0) {
            throw CryptoException(ParseError, "TLS server_name host_name must not be empty")
        }
        let nameBytes = readRange(extension.data, offset, nameLen, "TLS server_name host_name")
        offset += nameLen

        if (nameType == TLS_SNI_NAME_TYPE_HOST_NAME) {
            let rawName = decodeAsciiText(nameBytes, "TLS server_name host_name")
            hostNames.add(normalizeHostName(rawName, "TLS server_name host_name"))
        }
    }
    hostNames.toArray()
}

/**
 * tlsBuildAlpnExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsBuildAlpnExtension(protocols: Array<String>): TlsExtension {
    if (protocols.size == 0) {
        throw CryptoException(InvalidArgument, "TLS ALPN protocol list must not be empty")
    }

    let protocolList = ArrayList<Byte>()
    for (protocol in protocols) {
        let bytes = protocol.toArray()
        if (bytes.size == 0) {
            throw CryptoException(InvalidArgument, "TLS ALPN protocol id must not be empty")
        }
        if (bytes.size > 255) {
            throw CryptoException(OutOfBounds, "TLS ALPN protocol id exceeds uint8 length")
        }
        requireAlpnProtocolAscii(bytes)
        protocolList.add(UInt8(bytes.size))
        appendBytes(protocolList, bytes)
    }

    let protocolListBytes = protocolList.toArray()
    let payload = ArrayList<Byte>()
    appendBytes(payload, hsEncodeUInt16(protocolListBytes.size))
    appendBytes(payload, protocolListBytes)
    TlsExtension(TLS_EXT_ALPN, payload.toArray())
}

/**
 * tlsParseAlpnExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsParseAlpnExtension(extension: TlsExtension): Array<String> {
    if (extension.extType != TLS_EXT_ALPN) {
        throw CryptoException(InvalidArgument, "extension is not ALPN")
    }
    if (extension.data.size < 2) {
        throw CryptoException(ParseError, "TLS ALPN extension is too short")
    }

    let listLen = hsDecodeUInt16(extension.data, 0)
    if (listLen == 0) {
        throw CryptoException(ParseError, "TLS ALPN protocol list must not be empty")
    }
    if (listLen != extension.data.size - 2) {
        throw CryptoException(ParseError, "TLS ALPN protocol list length mismatch")
    }

    var offset = 2
    let out = ArrayList<String>()
    while (offset < extension.data.size) {
        let protoLen = readUInt8(extension.data, offset, "TLS ALPN protocol id length")
        offset += 1
        if (protoLen == 0) {
            throw CryptoException(ParseError, "TLS ALPN protocol id must not be empty")
        }
        let protoBytes = readRange(extension.data, offset, protoLen, "TLS ALPN protocol id")
        offset += protoLen
        requireAlpnProtocolAscii(protoBytes)
        out.add(decodeAsciiText(protoBytes, "TLS ALPN protocol id"))
    }
    out.toArray()
}

public func tlsBuildOcspStatusRequestExtension(
    request!: TlsOcspStatusRequest = TlsOcspStatusRequest()
): TlsExtension {
    let responderList = ArrayList<Byte>()
    for (responderId in request.responderIds) {
        appendBytes(responderList, hsEncodeUInt16(responderId.size))
        appendBytes(responderList, responderId)
    }
    let responderListBytes = responderList.toArray()

    let payload = ArrayList<Byte>()
    payload.add(UInt8(request.statusType))
    appendBytes(payload, hsEncodeUInt16(responderListBytes.size))
    appendBytes(payload, responderListBytes)
    appendBytes(payload, hsEncodeUInt16(request.requestExtensions.size))
    appendBytes(payload, request.requestExtensions)
    TlsExtension(TLS_EXT_STATUS_REQUEST, payload.toArray())
}

/**
 * tlsParseOcspStatusRequestExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsParseOcspStatusRequestExtension(extension: TlsExtension): TlsOcspStatusRequest {
    if (extension.extType != TLS_EXT_STATUS_REQUEST) {
        throw CryptoException(InvalidArgument, "extension is not status_request")
    }
    if (extension.data.size < 5) {
        throw CryptoException(ParseError, "TLS status_request extension is too short")
    }

    let statusType = readUInt8(extension.data, 0, "TLS status_request status_type")
    var offset = 1
    let responderListLen = hsDecodeUInt16(extension.data, offset)
    offset += 2
    let responderListEnd = offset + responderListLen
    if (responderListEnd > extension.data.size) {
        throw CryptoException(ParseError, "TLS status_request responder_id_list exceeds extension length")
    }

    let responderIds = ArrayList<Array<Byte>>()
    while (offset < responderListEnd) {
        let responderIdLen = hsDecodeUInt16(extension.data, offset)
        offset += 2
        if (responderIdLen == 0) {
            throw CryptoException(ParseError, "TLS status_request responder_id must not be empty")
        }
        let responderId = readRange(extension.data, offset, responderIdLen, "TLS status_request responder_id")
        offset += responderIdLen
        responderIds.add(responderId)
    }
    if (offset != responderListEnd) {
        throw CryptoException(ParseError, "TLS status_request responder_id_list parse did not consume full list")
    }

    let requestExtensionsLen = hsDecodeUInt16(extension.data, offset)
    offset += 2
    let requestExtensions = readRange(extension.data, offset, requestExtensionsLen, "TLS status_request request_extensions")
    offset += requestExtensionsLen

    if (offset != extension.data.size) {
        throw CryptoException(ParseError, "TLS status_request extension contains trailing bytes")
    }

    TlsOcspStatusRequest(
        statusType: statusType,
        responderIds: responderIds.toArray(),
        requestExtensions: requestExtensions
    )
}

public func tlsBuildOcspStatusRequestAckExtension(): TlsExtension {
    TlsExtension(TLS_EXT_STATUS_REQUEST, [])
}

public func tlsIsOcspStatusRequestAckExtension(extension: TlsExtension): Bool {
    extension.extType == TLS_EXT_STATUS_REQUEST && extension.data.size == 0
}

private func cloneByteArrayList(input: Array<Array<Byte>>): Array<Array<Byte>> {
    if (input.size == 0) {
        return []
    }
    let out = Array<Array<Byte>>(input.size, repeat: [])
    var i = 0
    while (i < input.size) {
        out[i] = input[i].clone()
        i += 1
    }
    out
}

private func decodeAsciiText(value: Array<Byte>, label: String): String {
    for (ch in value) {
        if (UInt8(ch) > UInt8(0x7f)) {
            throw CryptoException(ParseError, "${label} must be ASCII")
        }
    }
    try {
        String.fromUtf8(value)
    } catch (_: Exception) {
        throw CryptoException(ParseError, "${label} is not valid text")
    }
}

private func normalizeHostName(hostName: String, label: String): String {
    let normalized = hostName.trimAscii().toAsciiLower()
    if (normalized.size == 0) {
        throw CryptoException(InvalidArgument, "${label} must not be empty")
    }
    if (normalized.startsWith(".") || normalized.endsWith(".")) {
        throw CryptoException(InvalidArgument, "${label} must not start or end with '.'")
    }

    var i = 0
    var lastDot = false
    for (ch in normalized.toArray()) {
        if ((ch >= b'a' && ch <= b'z') || (ch >= b'0' && ch <= b'9') || ch == b'-') {
            lastDot = false
            i += 1
            continue
        }
        if (ch == b'.') {
            if (i == 0 || lastDot) {
                throw CryptoException(InvalidArgument, "${label} has invalid dot placement")
            }
            lastDot = true
            i += 1
            continue
        }
        throw CryptoException(InvalidArgument, "${label} contains invalid character")
    }
    if (lastDot) {
        throw CryptoException(InvalidArgument, "${label} has invalid trailing dot")
    }
    normalized
}

private func requireAlpnProtocolAscii(protocol: Array<Byte>): Unit {
    for (ch in protocol) {
        let value = UInt8(ch)
        if (value < UInt8(0x21) || value > UInt8(0x7e)) {
            throw CryptoException(InvalidArgument, "TLS ALPN protocol id must be visible ASCII")
        }
    }
}

private func appendBytes(list: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    for (b in bytes) {
        list.add(b)
    }
}

private func appendVariableVector8(list: ArrayList<Byte>, value: Array<Byte>, label: String): Unit {
    if (value.size > 255) {
        throw CryptoException(OutOfBounds, "${label} exceeds uint8 length")
    }
    list.add(UInt8(value.size))
    appendBytes(list, value)
}

private func appendVariableVector16(list: ArrayList<Byte>, value: Array<Byte>, label: String): Unit {
    if (value.size > 65535) {
        throw CryptoException(OutOfBounds, "${label} exceeds uint16 length")
    }
    appendBytes(list, hsEncodeUInt16(value.size))
    appendBytes(list, value)
}

private func appendVariableVector24(list: ArrayList<Byte>, value: Array<Byte>, label: String): Unit {
    if (value.size > TLS_HANDSHAKE_MAX_BODY_LEN) {
        throw CryptoException(OutOfBounds, "${label} exceeds uint24 length")
    }
    appendBytes(list, hsEncodeUInt24(value.size))
    appendBytes(list, value)
}

private func tlsEncodeCertificateBodyTls12(certificates: Array<Array<Byte>>): Array<Byte> {
    let entries = ArrayList<Byte>()
    for (cert in certificates) {
        if (cert.size == 0) {
            throw CryptoException(InvalidArgument, "TLS12 certificate entry must not be empty")
        }
        appendVariableVector24(entries, cert, "TLS12 certificate entry")
    }
    let body = ArrayList<Byte>()
    appendVariableVector24(body, entries.toArray(), "TLS12 Certificate.certificate_list")
    body.toArray()
}

private func tlsDecodeCertificateBodyTls12(body: Array<Byte>): Array<Array<Byte>> {
    if (body.size < 3) {
        throw CryptoException(ParseError, "TLS12 Certificate body is too short")
    }
    let listLen = hsDecodeUInt24(body, 0)
    if (listLen != body.size - 3) {
        throw CryptoException(ParseError, "TLS12 Certificate.certificate_list length mismatch")
    }

    let certificates = ArrayList<Array<Byte>>()
    var offset = 3
    while (offset < body.size) {
        if (offset + 3 > body.size) {
            throw CryptoException(ParseError, "TLS12 certificate entry length is truncated")
        }
        let certLen = hsDecodeUInt24(body, offset)
        offset += 3
        if (certLen == 0 || offset + certLen > body.size) {
            throw CryptoException(ParseError, "TLS12 certificate entry length is invalid")
        }
        certificates.add(readRange(body, offset, certLen, "TLS12 certificate entry"))
        offset += certLen
    }
    if (offset != body.size) {
        throw CryptoException(ParseError, "TLS12 Certificate body has trailing bytes")
    }
    certificates.toArray()
}

private func tlsEncodeCertificateBodyTls13(message: Tls13CertificateMessage): Array<Byte> {
    let body = ArrayList<Byte>()
    appendVariableVector8(body, message.requestContext, "TLS13 Certificate.request_context")

    let entries = ArrayList<Byte>()
    for (entry in message.entries) {
        appendVariableVector24(entries, entry.certData, "TLS13 CertificateEntry.cert_data")
        let extBytes = encodeExtensions(entry.extensions)
        appendVariableVector16(entries, extBytes, "TLS13 CertificateEntry.extensions")
    }
    appendVariableVector24(body, entries.toArray(), "TLS13 Certificate.certificate_list")
    body.toArray()
}

private func tlsDecodeCertificateBodyTls13(body: Array<Byte>): Tls13CertificateMessage {
    if (body.size < 4) {
        throw CryptoException(ParseError, "TLS13 Certificate body is too short")
    }

    var offset = 0
    let contextLen = readUInt8(body, offset, "TLS13 Certificate.request_context length")
    offset += 1
    let requestContext = readRange(body, offset, contextLen, "TLS13 Certificate.request_context")
    offset += contextLen

    if (offset + 3 > body.size) {
        throw CryptoException(ParseError, "TLS13 Certificate.certificate_list length is truncated")
    }
    let listLen = hsDecodeUInt24(body, offset)
    offset += 3
    if (offset + listLen != body.size) {
        throw CryptoException(ParseError, "TLS13 Certificate.certificate_list length mismatch")
    }

    let listEnd = offset + listLen
    let entries = ArrayList<TlsCertificateEntry>()
    while (offset < listEnd) {
        if (offset + 3 > listEnd) {
            throw CryptoException(ParseError, "TLS13 CertificateEntry.cert_data length is truncated")
        }
        let certLen = hsDecodeUInt24(body, offset)
        offset += 3
        if (certLen == 0 || offset + certLen > listEnd) {
            throw CryptoException(ParseError, "TLS13 CertificateEntry.cert_data length is invalid")
        }
        let certData = readRange(body, offset, certLen, "TLS13 CertificateEntry.cert_data")
        offset += certLen

        if (offset + 2 > listEnd) {
            throw CryptoException(ParseError, "TLS13 CertificateEntry.extensions length is truncated")
        }
        let extLen = hsDecodeUInt16(body, offset)
        offset += 2
        if (offset + extLen > listEnd) {
            throw CryptoException(ParseError, "TLS13 CertificateEntry.extensions length is invalid")
        }
        let extBytes = readRange(body, offset, extLen, "TLS13 CertificateEntry.extensions")
        offset += extLen
        entries.add(TlsCertificateEntry(certData, extensions: decodeExtensions(extBytes)))
    }
    if (offset != listEnd) {
        throw CryptoException(ParseError, "TLS13 Certificate body has trailing bytes")
    }

    Tls13CertificateMessage(requestContext: requestContext, entries: entries.toArray())
}

private func encodeCipherSuites(cipherSuites: Array<Int64>): Array<Byte> {
    requireCipherSuites(cipherSuites)
    let out = Array<Byte>(cipherSuites.size * 2, repeat: 0)
    var i = 0
    while (i < cipherSuites.size) {
        let encoded = hsEncodeUInt16(cipherSuites[i])
        out[i * 2] = encoded[0]
        out[i * 2 + 1] = encoded[1]
        i += 1
    }
    out
}

private func decodeCipherSuites(bytes: Array<Byte>): Array<Int64> {
    if (bytes.size == 0 || (bytes.size % 2) != 0) {
        throw CryptoException(ParseError, "TLS cipher_suites bytes length is invalid")
    }
    let out = Array<Int64>(bytes.size / 2, repeat: 0)
    var i = 0
    while (i < bytes.size) {
        out[i / 2] = hsDecodeUInt16(bytes, i)
        i += 2
    }
    out
}

private func encodeExtensions(extensions: Array<TlsExtension>): Array<Byte> {
    if (extensions.size == 0) {
        return []
    }

    let list = ArrayList<Byte>()
    for (ext in extensions) {
        appendBytes(list, hsEncodeUInt16(ext.extType))
        appendVariableVector16(list, ext.data, "TLS extension payload")
    }
    list.toArray()
}

private func decodeExtensions(encoded: Array<Byte>): Array<TlsExtension> {
    if (encoded.size == 0) {
        return []
    }

    let list = ArrayList<TlsExtension>()
    var offset = 0
    while (offset < encoded.size) {
        if (offset + 4 > encoded.size) {
            throw CryptoException(ParseError, "TLS extensions block is truncated")
        }
        let extType = hsDecodeUInt16(encoded, offset)
        offset += 2
        let extLen = hsDecodeUInt16(encoded, offset)
        offset += 2
        if (offset + extLen > encoded.size) {
            throw CryptoException(ParseError, "TLS extension payload exceeds envelope length")
        }
        let data = encoded[offset..(offset + extLen)]
        list.add(TlsExtension(extType, data))
        offset += extLen
    }
    list.toArray()
}

private func requireRandom(random: Array<Byte>): Unit {
    if (random.size != TLS_HELLO_RANDOM_LEN) {
        throw CryptoException(InvalidArgument, "TLS hello random must be 32 bytes")
    }
}

private func requireSessionId(sessionId: Array<Byte>): Unit {
    if (sessionId.size > TLS_SESSION_ID_MAX_LEN) {
        throw CryptoException(InvalidArgument, "TLS session_id must be <= 32 bytes")
    }
}

private func requireCipherSuites(cipherSuites: Array<Int64>): Unit {
    if (cipherSuites.size == 0) {
        throw CryptoException(InvalidArgument, "TLS cipher_suites must not be empty")
    }
    for (suite in cipherSuites) {
        requireCipherSuite(suite)
    }
}

private func requireCipherSuite(cipherSuite: Int64): Unit {
    if (cipherSuite < 0 || cipherSuite > 65535) {
        throw CryptoException(InvalidArgument, "TLS cipher_suite must be uint16")
    }
}

private func requireCompressionMethods(compressionMethods: Array<Byte>): Unit {
    if (compressionMethods.size == 0) {
        throw CryptoException(InvalidArgument, "TLS compression_methods must not be empty")
    }
    if (compressionMethods.size > 255) {
        throw CryptoException(OutOfBounds, "TLS compression_methods exceeds uint8 length")
    }
}

private func hsVersionToWire(version: TlsVersion): Array<Byte> {
    match (version) {
        case TLS1_2 => [UInt8(0x03), UInt8(0x03)]
        case TLS1_3 => [UInt8(0x03), UInt8(0x04)]
    }
}

private func hsVersionFromWire(bytes: Array<Byte>, offset: Int64): TlsVersion {
    let major = readUInt8(bytes, offset, "TLS version major")
    let minor = readUInt8(bytes, offset + 1, "TLS version minor")
    if (major == 0x03 && minor == 0x03) {
        return TLS1_2
    }
    if (major == 0x03 && minor == 0x04) {
        return TLS1_3
    }
    throw CryptoException(Unsupported, "unsupported TLS protocol version")
}

private func handshakeTypeToWire(msgType: TlsHandshakeType): Byte {
    match (msgType) {
        case ClientHello => UInt8(0x01)
        case ServerHello => UInt8(0x02)
        case NewSessionTicket => UInt8(0x04)
        case EncryptedExtensions => UInt8(0x08)
        case CertificateRequest => UInt8(0x0d)
        case Certificate => UInt8(0x0b)
        case CertificateVerify => UInt8(0x0f)
        case ServerKeyExchange => UInt8(0x0c)
        case ClientKeyExchange => UInt8(0x10)
        case Finished => UInt8(0x14)
        case KeyUpdate => UInt8(0x18)
    }
}

private func handshakeTypeFromWire(value: UInt8): TlsHandshakeType {
    if (value == UInt8(0x01)) {
        return ClientHello
    }
    if (value == UInt8(0x02)) {
        return ServerHello
    }
    if (value == UInt8(0x04)) {
        return NewSessionTicket
    }
    if (value == UInt8(0x08)) {
        return EncryptedExtensions
    }
    if (value == UInt8(0x0d)) {
        return CertificateRequest
    }
    if (value == UInt8(0x0b)) {
        return Certificate
    }
    if (value == UInt8(0x0f)) {
        return CertificateVerify
    }
    if (value == UInt8(0x0c)) {
        return ServerKeyExchange
    }
    if (value == UInt8(0x10)) {
        return ClientKeyExchange
    }
    if (value == UInt8(0x14)) {
        return Finished
    }
    if (value == UInt8(0x18)) {
        return KeyUpdate
    }
    throw CryptoException(Unsupported, "unsupported TLS handshake type")
}

private func readRange(bytes: Array<Byte>, offset: Int64, length: Int64, label: String): Array<Byte> {
    if (length < 0 || offset < 0 || offset + length > bytes.size) {
        throw CryptoException(ParseError, "${label} is out of bounds")
    }
    bytes[offset..(offset + length)]
}

private func readUInt8(bytes: Array<Byte>, offset: Int64, label: String): Int64 {
    if (offset < 0 || offset >= bytes.size) {
        throw CryptoException(ParseError, "${label} is out of bounds")
    }
    Int64(UInt8(bytes[offset]))
}

private func readByte(bytes: Array<Byte>, offset: Int64, label: String): Byte {
    if (offset < 0 || offset >= bytes.size) {
        throw CryptoException(ParseError, "${label} is out of bounds")
    }
    bytes[offset]
}

@OverflowWrapping
private func hsEncodeUInt16(value: Int64): Array<Byte> {
    if (value < 0 || value > 65535) {
        throw CryptoException(OutOfBounds, "value does not fit into uint16")
    }
    let v = UInt16(value)
    [UInt8((v >> 8) & UInt16(0xff)), UInt8(v & UInt16(0xff))]
}

@OverflowWrapping
private func hsDecodeUInt16(bytes: Array<Byte>, offset: Int64): Int64 {
    if (offset < 0 || offset + 2 > bytes.size) {
        throw CryptoException(ParseError, "uint16 decode out of bounds")
    }
    (Int64(UInt8(bytes[offset])) << 8) | Int64(UInt8(bytes[offset + 1]))
}

@OverflowWrapping
private func hsEncodeUInt24(value: Int64): Array<Byte> {
    if (value < 0 || value > TLS_HANDSHAKE_MAX_BODY_LEN) {
        throw CryptoException(OutOfBounds, "value does not fit into uint24")
    }
    let v = UInt32(value)
    [
        UInt8((v >> 16) & UInt32(0xff)),
        UInt8((v >> 8) & UInt32(0xff)),
        UInt8(v & UInt32(0xff))
    ]
}

@OverflowWrapping
private func hsDecodeUInt24(bytes: Array<Byte>, offset: Int64): Int64 {
    if (offset < 0 || offset + 3 > bytes.size) {
        throw CryptoException(ParseError, "uint24 decode out of bounds")
    }
    (Int64(UInt8(bytes[offset])) << 16) |
    (Int64(UInt8(bytes[offset + 1])) << 8) |
    Int64(UInt8(bytes[offset + 2]))
}
