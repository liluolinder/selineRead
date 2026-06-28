package jinguissl_core.crypto.tls

import std.collection.ArrayList
import jinguissl_core.crypto.aes.{AesEngine, AesEngineKind, AesGcmContext, aesGcmDecryptIntoWithContext, aesGcmEncryptIntoWithContext}
import jinguissl_core.crypto.chacha20.{CHACHA20_POLY1305_TAG_LEN, Chacha20Poly1305Context, chacha20Poly1305DecryptWithContext, chacha20Poly1305EncryptWithContext, chacha20Poly1305NewContext}
import jinguissl_core.crypto.compliance.{FipsProfile, TlsVersion}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.utils.secureCopyInto

public let TLS_RECORD_HEADER_LEN: Int64 = 5
public let TLS_MAX_PLAINTEXT_LEN: Int64 = 16384
public let TLS_AEAD_TAG_LEN: Int64 = 16
public let TLS_MAX_CIPHERTEXT_LEN: Int64 = TLS_MAX_PLAINTEXT_LEN + TLS_AEAD_TAG_LEN

public enum TlsAeadAlgorithm <: Equatable<TlsAeadAlgorithm> & ToString {
    | AES_GCM
    | CHACHA20_POLY1305

    public operator func ==(right: TlsAeadAlgorithm): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: TlsAeadAlgorithm): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case AES_GCM => 0
            case CHACHA20_POLY1305 => 1
        }
    }

    public func toString(): String {
        match (this) {
            case AES_GCM => "AES-GCM"
            case CHACHA20_POLY1305 => "CHACHA20-POLY1305"
        }
    }
}

public enum TlsContentType <: Equatable<TlsContentType> & ToString {
    | ChangeCipherSpec
    | Alert
    | Handshake
    | ApplicationData

    public operator func ==(right: TlsContentType): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: TlsContentType): Bool {
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

public enum TlsAlertLevel <: Equatable<TlsAlertLevel> & ToString {
    | Warning
    | Fatal

    public operator func ==(right: TlsAlertLevel): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: TlsAlertLevel): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Warning => 0
            case Fatal => 1
        }
    }

    public func toString(): String {
        match (this) {
            case Warning => "WARNING"
            case Fatal => "FATAL"
        }
    }
}

public enum TlsAlertDescription <: Equatable<TlsAlertDescription> & ToString {
    | CloseNotify
    | UnexpectedMessage
    | BadRecordMac
    | DecryptionFailedReserved
    | RecordOverflow
    | HandshakeFailure
    | BadCertificate
    | UnsupportedCertificate
    | CertificateRevoked
    | CertificateExpired
    | CertificateUnknown
    | IllegalParameter
    | UnknownCa
    | AccessDenied
    | DecodeError
    | DecryptError
    | ProtocolVersion
    | InsufficientSecurity
    | InternalError
    | UserCanceled
    | MissingExtension
    | UnsupportedExtension
    | UnrecognizedName
    | BadCertificateStatusResponse
    | UnknownPskIdentity
    | CertificateRequired
    | NoApplicationProtocol

    public operator func ==(right: TlsAlertDescription): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: TlsAlertDescription): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case CloseNotify => 0
            case UnexpectedMessage => 1
            case BadRecordMac => 2
            case DecryptionFailedReserved => 3
            case RecordOverflow => 4
            case HandshakeFailure => 5
            case BadCertificate => 6
            case UnsupportedCertificate => 7
            case CertificateRevoked => 8
            case CertificateExpired => 9
            case CertificateUnknown => 10
            case IllegalParameter => 11
            case UnknownCa => 12
            case AccessDenied => 13
            case DecodeError => 14
            case DecryptError => 15
            case ProtocolVersion => 16
            case InsufficientSecurity => 17
            case InternalError => 18
            case UserCanceled => 19
            case MissingExtension => 20
            case UnsupportedExtension => 21
            case UnrecognizedName => 22
            case BadCertificateStatusResponse => 23
            case UnknownPskIdentity => 24
            case CertificateRequired => 25
            case NoApplicationProtocol => 26
        }
    }

    public func toString(): String {
        match (this) {
            case CloseNotify => "CLOSE_NOTIFY"
            case UnexpectedMessage => "UNEXPECTED_MESSAGE"
            case BadRecordMac => "BAD_RECORD_MAC"
            case DecryptionFailedReserved => "DECRYPTION_FAILED_RESERVED"
            case RecordOverflow => "RECORD_OVERFLOW"
            case HandshakeFailure => "HANDSHAKE_FAILURE"
            case BadCertificate => "BAD_CERTIFICATE"
            case UnsupportedCertificate => "UNSUPPORTED_CERTIFICATE"
            case CertificateRevoked => "CERTIFICATE_REVOKED"
            case CertificateExpired => "CERTIFICATE_EXPIRED"
            case CertificateUnknown => "CERTIFICATE_UNKNOWN"
            case IllegalParameter => "ILLEGAL_PARAMETER"
            case UnknownCa => "UNKNOWN_CA"
            case AccessDenied => "ACCESS_DENIED"
            case DecodeError => "DECODE_ERROR"
            case DecryptError => "DECRYPT_ERROR"
            case ProtocolVersion => "PROTOCOL_VERSION"
            case InsufficientSecurity => "INSUFFICIENT_SECURITY"
            case InternalError => "INTERNAL_ERROR"
            case UserCanceled => "USER_CANCELED"
            case MissingExtension => "MISSING_EXTENSION"
            case UnsupportedExtension => "UNSUPPORTED_EXTENSION"
            case UnrecognizedName => "UNRECOGNIZED_NAME"
            case BadCertificateStatusResponse => "BAD_CERTIFICATE_STATUS_RESPONSE"
            case UnknownPskIdentity => "UNKNOWN_PSK_IDENTITY"
            case CertificateRequired => "CERTIFICATE_REQUIRED"
            case NoApplicationProtocol => "NO_APPLICATION_PROTOCOL"
        }
    }
}

public class TlsAlertMessage {
    public let level: TlsAlertLevel
    public let description: TlsAlertDescription

    public init(level: TlsAlertLevel, description: TlsAlertDescription) {
        this.level = level
        this.description = description
    }
}

public class TlsRecordHeader {
    public let contentType: TlsContentType
    public let version: TlsVersion
    public let length: Int64

    public init(contentType: TlsContentType, version: TlsVersion, length: Int64) {
        if (length < 0 || length > TLS_MAX_CIPHERTEXT_LEN) {
            throw CryptoException(OutOfBounds, "TLS record payload length is out of range")
        }
        this.contentType = contentType
        this.version = version
        this.length = length
    }
}

public class TlsCipherRecord {
    public let header: TlsRecordHeader
    public let fragment: Array<Byte>

    public init(header: TlsRecordHeader, fragment: Array<Byte>) {
        if (fragment.size != header.length) {
            throw CryptoException(InvalidArgument, "TLS record fragment length mismatch")
        }
        this.header = header
        this.fragment = fragment.clone()
    }
}

public class TlsPlainRecord {
    public let contentType: TlsContentType
    public let version: TlsVersion
    public let fragment: Array<Byte>

    public init(contentType: TlsContentType, version: TlsVersion, fragment: Array<Byte>) {
        this.contentType = contentType
        this.version = version
        this.fragment = fragment.clone()
    }
}

public class TlsAeadRecordLayer {
    public let version: TlsVersion
    public let engine: AesEngine

    let _writeContext: AesGcmContext
    let _readContext: AesGcmContext
    let _writeIv: Array<Byte>
    let _readIv: Array<Byte>
    var _writeCipherScratch: Array<Byte> = []
    var _writeTagScratch: Array<Byte> = Array<Byte>(TLS_AEAD_TAG_LEN, repeat: 0)
    var _writeNonceScratch: Array<Byte> = Array<Byte>(12, repeat: 0)
    var _writeAadScratch: Array<Byte> = Array<Byte>(13, repeat: 0)
    var _readCipherScratch: Array<Byte> = []
    var _readPlainScratch: Array<Byte> = []
    var _readTagScratch: Array<Byte> = Array<Byte>(TLS_AEAD_TAG_LEN, repeat: 0)
    var _readNonceScratch: Array<Byte> = Array<Byte>(12, repeat: 0)
    var _readAadScratch: Array<Byte> = Array<Byte>(13, repeat: 0)

    var _writeSequence: Int64 = 0
    var _readSequence: Int64 = 0

    public init(
        writeKey: Array<Byte>,
        writeIv: Array<Byte>,
        readKey!: Array<Byte> = [],
        readIv!: Array<Byte> = [],
        version!: TlsVersion = TLS1_2,
        requestedEngine!: AesEngineKind = AUTO
    ) {
        requireFixedIv(writeIv, "write IV")
        let inboundIv = if (readIv.size == 0) {
            writeIv
        } else {
            readIv
        }
        requireFixedIv(inboundIv, "read IV")

        let inboundKey = if (readKey.size == 0) {
            writeKey
        } else {
            readKey
        }

        let writeContext = AesGcmContext(writeKey, requestedEngine: requestedEngine)
        let readContext = AesGcmContext(inboundKey, requestedEngine: requestedEngine)
        this.version = version
        this.engine = writeContext.engine
        this._writeContext = writeContext
        this._readContext = readContext
        this._writeIv = writeIv.clone()
        this._readIv = inboundIv.clone()
    }

    public prop writeSequence: Int64 {
        get() {
            _writeSequence
        }
    }

    public prop readSequence: Int64 {
        get() {
            _readSequence
        }
    }

    public func resetSequences(): Unit {
        _writeSequence = 0
        _readSequence = 0
    }

    /**
 * seal.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func seal(contentType: TlsContentType, plaintext: Array<Byte>): Array<Byte> {
        if (plaintext.size > TLS_MAX_PLAINTEXT_LEN) {
            throw CryptoException(OutOfBounds, "TLS plaintext exceeds max fragment size")
        }

        if (version == TLS1_3) {
            // RFC 8446 §5.2: TLS 1.3 protected records use TLSInnerPlaintext
            // where the actual content type is appended as the last byte,
            // the wire content type is always ApplicationData (23),
            // and the wire version is legacy 0x0303.
            let seq = nextWriteSequence()
            let innerPlainLen = plaintext.size + 1
            let innerPlaintext = Array<Byte>(innerPlainLen, repeat: 0)
            secureCopyInto(plaintext, innerPlaintext)
            innerPlaintext[plaintext.size] = contentTypeToWire(contentType)
            buildNonceInto(_writeIv, seq, _writeNonceScratch)
            buildTls13AadInto(innerPlainLen, _writeAadScratch)
            _writeCipherScratch = ensureTlsScratchSize(_writeCipherScratch, innerPlainLen)
            aesGcmEncryptIntoWithContext(
                _writeContext,
                _writeNonceScratch,
                innerPlaintext,
                _writeCipherScratch,
                _writeTagScratch,
                aad: _writeAadScratch,
                tagLen: TLS_AEAD_TAG_LEN
            )
            // Encode with opaque_type=ApplicationData and legacy record_version=0x0303
            tlsEncodeRecordFromCipherAndTag(
                ApplicationData,
                TLS1_2,
                _writeCipherScratch,
                _writeTagScratch,
                TLS_AEAD_TAG_LEN
            )
        } else {
            let seq = nextWriteSequence()
            buildNonceInto(_writeIv, seq, _writeNonceScratch)
            buildAadInto(seq, contentType, version, plaintext.size, _writeAadScratch)
            _writeCipherScratch = ensureTlsScratchSize(_writeCipherScratch, plaintext.size)
            aesGcmEncryptIntoWithContext(
                _writeContext,
                _writeNonceScratch,
                plaintext,
                _writeCipherScratch,
                _writeTagScratch,
                aad: _writeAadScratch,
                tagLen: TLS_AEAD_TAG_LEN
            )
            tlsEncodeRecordFromCipherAndTag(
                contentType,
                version,
                _writeCipherScratch,
                _writeTagScratch,
                TLS_AEAD_TAG_LEN
            )
        }
    }

    /**
 * open.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func open(encodedRecord: Array<Byte>): TlsPlainRecord {
        let record = tlsDecodeRecord(encodedRecord)
        // RFC 8446 §5.1: legacy_record_version MUST be ignored for TLS 1.3
        if (version != TLS1_3 && record.header.version != version) {
            throw CryptoException(ParseError, "TLS record version mismatch")
        }
        if (record.fragment.size < TLS_AEAD_TAG_LEN) {
            throw CryptoException(ParseError, "TLS AEAD record is too short")
        }

        let seq = nextReadSequence()
        let cipherLen = record.fragment.size - TLS_AEAD_TAG_LEN
        _readCipherScratch = ensureTlsScratchSize(_readCipherScratch, cipherLen)
        _readPlainScratch = ensureTlsScratchSize(_readPlainScratch, cipherLen)
        copyTlsBytesRange(record.fragment, 0, _readCipherScratch, cipherLen)
        copyTlsBytesRange(record.fragment, cipherLen, _readTagScratch, TLS_AEAD_TAG_LEN)
        buildNonceInto(_readIv, seq, _readNonceScratch)

        if (version == TLS1_3) {
            // TLS 1.3 AAD: opaque_type || legacy_record_version (0x0303) || length
            buildTls13AadInto(cipherLen, _readAadScratch)
        } else {
            buildAadInto(seq, record.header.contentType, record.header.version, cipherLen, _readAadScratch)
        }

        aesGcmDecryptIntoWithContext(
            _readContext,
            _readNonceScratch,
            _readCipherScratch,
            _readTagScratch,
            _readPlainScratch,
            aad: _readAadScratch
        )

        if (version == TLS1_3) {
            // TLS 1.3 inner plaintext: last byte is the actual content type
            let actualContentType = contentTypeFromWire(_readPlainScratch[_readPlainScratch.size - 1])
            let plainLen = _readPlainScratch.size - 1
            TlsPlainRecord(actualContentType, TLS1_3, _readPlainScratch[..plainLen])
        } else {
            TlsPlainRecord(record.header.contentType, record.header.version, _readPlainScratch)
        }
    }

    public func sealFragments(
        contentType: TlsContentType,
        plaintext: Array<Byte>,
        maxFragmentLen!: Int64 = TLS_MAX_PLAINTEXT_LEN
    ): Array<Array<Byte>> {
        let fragments = tlsRecordFragment(plaintext, maxFragmentLen: maxFragmentLen)
        let records = ArrayList<Array<Byte>>()
        for (fragment in fragments) {
            records.add(seal(contentType, fragment))
        }
        records.toArray()
    }

    /**
 * openAndReassemble.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func openAndReassemble(
        encodedRecords: Array<Array<Byte>>,
        expectedContentType!: TlsContentType = ApplicationData
    ): Array<Byte> {
        if (encodedRecords.size == 0) {
            return []
        }

        let fragments = ArrayList<Array<Byte>>()
        for (encoded in encodedRecords) {
            let plain = open(encoded)
            if (plain.contentType != expectedContentType) {
                throw CryptoException(ParseError, "TLS content type mismatch while reassembling records")
            }
            fragments.add(plain.fragment)
        }
        tlsRecordReassemble(fragments.toArray())
    }

    private func nextWriteSequence(): Int64 {
        if (_writeSequence == Int64.Max) {
            throw CryptoException(OutOfBounds, "TLS write sequence overflow")
        }
        let seq = _writeSequence
        _writeSequence += 1
        seq
    }

    private func nextReadSequence(): Int64 {
        if (_readSequence == Int64.Max) {
            throw CryptoException(OutOfBounds, "TLS read sequence overflow")
        }
        let seq = _readSequence
        _readSequence += 1
        seq
    }
}

public class TlsChacha20Poly1305RecordLayer {
    public let version: TlsVersion

    let _writeContext: Chacha20Poly1305Context
    let _readContext: Chacha20Poly1305Context
    let _writeIv: Array<Byte>
    let _readIv: Array<Byte>
    var _writeNonceScratch: Array<Byte> = Array<Byte>(12, repeat: 0)
    var _writeAadScratch: Array<Byte> = Array<Byte>(13, repeat: 0)
    var _readNonceScratch: Array<Byte> = Array<Byte>(12, repeat: 0)
    var _readAadScratch: Array<Byte> = Array<Byte>(13, repeat: 0)

    var _writeSequence: Int64 = 0
    var _readSequence: Int64 = 0

    public init(
        writeKey: Array<Byte>,
        writeIv: Array<Byte>,
        readKey!: Array<Byte> = [],
        readIv!: Array<Byte> = [],
        version!: TlsVersion = TLS1_2
    ) {
        requireFixedIv(writeIv, "write IV")
        let inboundIv = if (readIv.size == 0) {
            writeIv
        } else {
            readIv
        }
        requireFixedIv(inboundIv, "read IV")

        let inboundKey = if (readKey.size == 0) {
            writeKey
        } else {
            readKey
        }

        this.version = version
        this._writeContext = chacha20Poly1305NewContext(writeKey)
        this._readContext = chacha20Poly1305NewContext(inboundKey)
        this._writeIv = writeIv.clone()
        this._readIv = inboundIv.clone()
    }

    public prop writeSequence: Int64 {
        get() {
            _writeSequence
        }
    }

    public prop readSequence: Int64 {
        get() {
            _readSequence
        }
    }

    public func resetSequences(): Unit {
        _writeSequence = 0
        _readSequence = 0
    }

    /**
 * seal.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func seal(contentType: TlsContentType, plaintext: Array<Byte>): Array<Byte> {
        if (plaintext.size > TLS_MAX_PLAINTEXT_LEN) {
            throw CryptoException(OutOfBounds, "TLS plaintext exceeds max fragment size")
        }

        if (version == TLS1_3) {
            // RFC 8446 §5.2: TLS 1.3 inner plaintext
            let seq = nextWriteSequence()
            let innerPlainLen = plaintext.size + 1
            let innerPlaintext = Array<Byte>(innerPlainLen, repeat: 0)
            secureCopyInto(plaintext, innerPlaintext)
            innerPlaintext[plaintext.size] = contentTypeToWire(contentType)
            buildNonceInto(_writeIv, seq, _writeNonceScratch)
            buildTls13AadInto(innerPlainLen, _writeAadScratch)
            let (ciphertext, tag) = chacha20Poly1305EncryptWithContext(
                _writeContext,
                _writeNonceScratch,
                innerPlaintext,
                aad: _writeAadScratch
            )
            let payload = Array<Byte>(ciphertext.size + tag.size, repeat: 0)
            secureCopyInto(ciphertext, payload)
            secureCopyInto(tag, payload, dstOffset: ciphertext.size)
            // Encode with opaque_type=ApplicationData and legacy record_version=0x0303
            tlsEncodeRecord(ApplicationData, TLS1_2, payload)
        } else {
            let seq = nextWriteSequence()
            buildNonceInto(_writeIv, seq, _writeNonceScratch)
            buildAadInto(seq, contentType, version, plaintext.size, _writeAadScratch)
            let (ciphertext, tag) = chacha20Poly1305EncryptWithContext(
                _writeContext,
                _writeNonceScratch,
                plaintext,
                aad: _writeAadScratch
            )
            let payload = Array<Byte>(ciphertext.size + tag.size, repeat: 0)
            secureCopyInto(ciphertext, payload)
            secureCopyInto(tag, payload, dstOffset: ciphertext.size)
            tlsEncodeRecord(contentType, version, payload)
        }
    }

    /**
 * open.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func open(encodedRecord: Array<Byte>): TlsPlainRecord {
        let record = tlsDecodeRecord(encodedRecord)
        // RFC 8446 §5.1: legacy_record_version MUST be ignored for TLS 1.3
        if (version != TLS1_3 && record.header.version != version) {
            throw CryptoException(ParseError, "TLS record version mismatch")
        }
        if (record.fragment.size < CHACHA20_POLY1305_TAG_LEN) {
            throw CryptoException(ParseError, "TLS AEAD record is too short")
        }

        let seq = nextReadSequence()
        let cipherLen = record.fragment.size - CHACHA20_POLY1305_TAG_LEN
        let ciphertext = record.fragment[..cipherLen]
        let tag = record.fragment[cipherLen..]
        buildNonceInto(_readIv, seq, _readNonceScratch)

        if (version == TLS1_3) {
            buildTls13AadInto(cipherLen, _readAadScratch)
        } else {
            buildAadInto(seq, record.header.contentType, record.header.version, cipherLen, _readAadScratch)
        }

        let plaintext = chacha20Poly1305DecryptWithContext(
            _readContext,
            _readNonceScratch,
            ciphertext,
            tag,
            aad: _readAadScratch
        )

        if (version == TLS1_3) {
            // TLS 1.3 inner plaintext: last byte is the actual content type
            let actualContentType = contentTypeFromWire(plaintext[plaintext.size - 1])
            TlsPlainRecord(actualContentType, TLS1_3, plaintext[..plaintext.size - 1])
        } else {
            TlsPlainRecord(record.header.contentType, record.header.version, plaintext)
        }
    }

    public func sealFragments(
        contentType: TlsContentType,
        plaintext: Array<Byte>,
        maxFragmentLen!: Int64 = TLS_MAX_PLAINTEXT_LEN
    ): Array<Array<Byte>> {
        let fragments = tlsRecordFragment(plaintext, maxFragmentLen: maxFragmentLen)
        let records = ArrayList<Array<Byte>>()
        for (fragment in fragments) {
            records.add(seal(contentType, fragment))
        }
        records.toArray()
    }

    /**
 * openAndReassemble.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func openAndReassemble(
        encodedRecords: Array<Array<Byte>>,
        expectedContentType!: TlsContentType = ApplicationData
    ): Array<Byte> {
        if (encodedRecords.size == 0) {
            return []
        }

        let fragments = ArrayList<Array<Byte>>()
        for (encoded in encodedRecords) {
            let plain = open(encoded)
            if (plain.contentType != expectedContentType) {
                throw CryptoException(ParseError, "TLS content type mismatch while reassembling records")
            }
            fragments.add(plain.fragment)
        }
        tlsRecordReassemble(fragments.toArray())
    }

    private func nextWriteSequence(): Int64 {
        if (_writeSequence == Int64.Max) {
            throw CryptoException(OutOfBounds, "TLS write sequence overflow")
        }
        let seq = _writeSequence
        _writeSequence += 1
        seq
    }

    private func nextReadSequence(): Int64 {
        if (_readSequence == Int64.Max) {
            throw CryptoException(OutOfBounds, "TLS read sequence overflow")
        }
        let seq = _readSequence
        _readSequence += 1
        seq
    }
}

public func tlsRecordRequireAllowed(
    profile: FipsProfile,
    version: TlsVersion,
    algorithm!: TlsAeadAlgorithm = AES_GCM
): Unit {
    profile.requireAllowed(version.toString())
    profile.requireAllowed(algorithm.toString())
}

public func tlsEncodeRecord(contentType: TlsContentType, version: TlsVersion, payload: Array<Byte>): Array<Byte> {
    let header = TlsRecordHeader(contentType, version, payload.size)
    let out = Array<Byte>(TLS_RECORD_HEADER_LEN + payload.size, repeat: 0)
    out[0] = contentTypeToWire(contentType)
    let ver = tlsVersionToWire(version)
    out[1] = ver[0]
    out[2] = ver[1]
    let len = encodeUInt16BE(header.length)
    out[3] = len[0]
    out[4] = len[1]
    secureCopyInto(payload, out, dstOffset: TLS_RECORD_HEADER_LEN)
    out
}

private func tlsEncodeRecordFromCipherAndTag(
    contentType: TlsContentType,
    version: TlsVersion,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    tagLen: Int64
): Array<Byte> {
    if (tagLen <= 0 || tagLen > tag.size) {
        throw CryptoException(InvalidArgument, "TLS AEAD tag length is invalid")
    }
    let payloadLen = ciphertext.size + tagLen
    let header = TlsRecordHeader(contentType, version, payloadLen)
    let out = Array<Byte>(TLS_RECORD_HEADER_LEN + payloadLen, repeat: 0)
    out[0] = contentTypeToWire(contentType)
    let ver = tlsVersionToWire(version)
    out[1] = ver[0]
    out[2] = ver[1]
    let len = encodeUInt16BE(header.length)
    out[3] = len[0]
    out[4] = len[1]
    secureCopyInto(ciphertext, out, dstOffset: TLS_RECORD_HEADER_LEN)
    copyTlsBytesRange(tag, 0, out, tagLen, dstOffset: TLS_RECORD_HEADER_LEN + ciphertext.size)
    out
}

private func ensureTlsScratchSize(buffer: Array<Byte>, size: Int64): Array<Byte> {
    if (size < 0) {
        throw CryptoException(InvalidArgument, "TLS scratch buffer size must be non-negative")
    }
    if (buffer.size == size) {
        return buffer
    }
    Array<Byte>(size, repeat: 0)
}

private func copyTlsBytesRange(
    src: Array<Byte>,
    srcOffset: Int64,
    dst: Array<Byte>,
    count: Int64,
    dstOffset!: Int64 = 0
): Unit {
    if (srcOffset < 0 || count < 0 || dstOffset < 0) {
        throw CryptoException(OutOfBounds, "TLS byte-range copy offsets must be non-negative")
    }
    if ((srcOffset + count) > src.size) {
        throw CryptoException(OutOfBounds, "TLS byte-range copy source is out of bounds")
    }
    if ((dstOffset + count) > dst.size) {
        throw CryptoException(OutOfBounds, "TLS byte-range copy destination is out of bounds")
    }
    var i = 0
    while (i < count) {
        dst[dstOffset + i] = src[srcOffset + i]
        i += 1
    }
}

/**
 * tlsDecodeRecord.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeRecord(encodedRecord: Array<Byte>): TlsCipherRecord {
    if (encodedRecord.size < TLS_RECORD_HEADER_LEN) {
        throw CryptoException(ParseError, "TLS record is shorter than header")
    }

    let contentType = contentTypeFromWire(UInt8(encodedRecord[0]))
    let version = tlsVersionFromWire(UInt8(encodedRecord[1]), UInt8(encodedRecord[2]))
    let length = decodeUInt16BE(encodedRecord, 3)
    if (length > TLS_MAX_CIPHERTEXT_LEN) {
        throw CryptoException(ParseError, "TLS record payload length is too large")
    }
    if (encodedRecord.size != TLS_RECORD_HEADER_LEN + length) {
        throw CryptoException(ParseError, "TLS record length field mismatch")
    }

    let payload = encodedRecord[TLS_RECORD_HEADER_LEN..]
    let header = TlsRecordHeader(contentType, version, length)
    TlsCipherRecord(header, payload)
}

public func tlsEncodeAlert(level: TlsAlertLevel, description: TlsAlertDescription): Array<Byte> {
    [alertLevelToWire(level), alertDescriptionToWire(description)]
}

/**
 * tlsDecodeAlert.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeAlert(encodedAlert: Array<Byte>): TlsAlertMessage {
    if (encodedAlert.size != 2) {
        throw CryptoException(ParseError, "TLS alert payload must be exactly 2 bytes")
    }
    let level = alertLevelFromWire(UInt8(encodedAlert[0]))
    let description = alertDescriptionFromWire(UInt8(encodedAlert[1]))
    TlsAlertMessage(level, description)
}

public func tlsEncodeAlertRecord(
    version: TlsVersion,
    level: TlsAlertLevel,
    description: TlsAlertDescription
): Array<Byte> {
    tlsEncodeRecord(Alert, version, tlsEncodeAlert(level, description))
}

/**
 * tlsDecodeAlertRecord.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeAlertRecord(encodedRecord: Array<Byte>): TlsAlertMessage {
    let record = tlsDecodeRecord(encodedRecord)
    if (record.header.contentType != Alert) {
        throw CryptoException(ParseError, "TLS record content type is not ALERT")
    }
    tlsDecodeAlert(record.fragment)
}

public func tlsIsCloseNotifyAlert(alert: TlsAlertMessage): Bool {
    alert.description == CloseNotify
}

/**
 * tlsRecordFragment.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsRecordFragment(plaintext: Array<Byte>, maxFragmentLen!: Int64 = TLS_MAX_PLAINTEXT_LEN): Array<Array<Byte>> {
    if (maxFragmentLen <= 0 || maxFragmentLen > TLS_MAX_PLAINTEXT_LEN) {
        throw CryptoException(InvalidArgument, "TLS max fragment length must be in [1, 16384]")
    }
    if (plaintext.size == 0) {
        return [[]]
    }

    let fragments = ArrayList<Array<Byte>>()
    var offset = 0
    while (offset < plaintext.size) {
        let remain = plaintext.size - offset
        let take = if (remain < maxFragmentLen) {
            remain
        } else {
            maxFragmentLen
        }
        fragments.add(plaintext[offset..(offset + take)])
        offset += take
    }
    fragments.toArray()
}

public func tlsRecordReassemble(fragments: Array<Array<Byte>>): Array<Byte> {
    if (fragments.size == 0) {
        return []
    }

    var total: Int64 = 0
    for (fragment in fragments) {
        total += fragment.size
    }

    let out = Array<Byte>(total, repeat: 0)
    var offset = 0
    for (fragment in fragments) {
        secureCopyInto(fragment, out, dstOffset: offset)
        offset += fragment.size
    }
    out
}

private func requireFixedIv(iv: Array<Byte>, label: String): Unit {
    if (iv.size != 12) {
        throw CryptoException(InvalidArgument, "TLS record ${label} must be 12 bytes")
    }
}

private func buildNonce(staticIv: Array<Byte>, sequence: Int64): Array<Byte> {
    let nonce = Array<Byte>(staticIv.size, repeat: 0)
    buildNonceInto(staticIv, sequence, nonce)
    nonce
}

@OverflowWrapping
private func buildNonceInto(staticIv: Array<Byte>, sequence: Int64, outNonce: Array<Byte>): Unit {
    if (sequence < 0) {
        throw CryptoException(InvalidArgument, "negative sequence cannot be encoded into TLS nonce")
    }
    if (outNonce.size != staticIv.size) {
        throw CryptoException(InvalidArgument, "TLS nonce output length mismatch")
    }
    requireFixedIv(staticIv, "static IV")
    secureCopyInto(staticIv, outNonce)

    let seq = UInt64(sequence)
    var i = 0
    while (i < 8) {
        let shift = UInt64((7 - i) * 8)
        let seqByte = UInt8((seq >> shift) & UInt64(0xff))
        outNonce[4 + i] = UInt8(outNonce[4 + i]) ^ seqByte
        i += 1
    }
}

private func buildAad(
    sequence: Int64,
    contentType: TlsContentType,
    version: TlsVersion,
    plainLen: Int64
): Array<Byte> {
    let aad = Array<Byte>(13, repeat: 0)
    buildAadInto(sequence, contentType, version, plainLen, aad)
    aad
}

@OverflowWrapping
private func buildAadInto(
    sequence: Int64,
    contentType: TlsContentType,
    version: TlsVersion,
    plainLen: Int64,
    outAad: Array<Byte>
): Unit {
    if (outAad.size != 13) {
        throw CryptoException(InvalidArgument, "TLS AEAD additional data must be 13 bytes")
    }
    if (sequence < 0) {
        throw CryptoException(InvalidArgument, "negative sequence cannot be encoded into TLS additional data")
    }
    if (plainLen < 0 || plainLen > TLS_MAX_PLAINTEXT_LEN) {
        throw CryptoException(OutOfBounds, "TLS AEAD plaintext length out of range")
    }

    let seq = UInt64(sequence)
    var i = 0
    while (i < 8) {
        let shift = UInt64((7 - i) * 8)
        outAad[i] = UInt8((seq >> shift) & UInt64(0xff))
        i += 1
    }
    outAad[8] = contentTypeToWire(contentType)
    if (version == TLS1_2) {
        outAad[9] = UInt8(0x03)
        outAad[10] = UInt8(0x03)
    } else {
        outAad[9] = UInt8(0x03)
        outAad[10] = UInt8(0x04)
    }
    outAad[11] = UInt8((plainLen >> 8) & 0xff)
    outAad[12] = UInt8(plainLen & 0xff)
}

/**
 * Build TLS 1.3 AEAD additional authenticated data (5 bytes).
 *
 * RFC 8446 §5.2: additional_data = TLSCiphertext.opaque_type ||
 *                  TLSCiphertext.legacy_record_version || TLSCiphertext.length
 * where opaque_type is always ApplicationData (23) for protected records,
 * legacy_record_version is 0x0303, and length is the ciphertext length
 * (inner plaintext length, excluding the tag).
 */
private func buildTls13AadInto(
    innerPlainLen: Int64,
    outAad: Array<Byte>
): Unit {
    if (outAad.size < 5) {
        throw CryptoException(InvalidArgument, "TLS1.3 AEAD additional data buffer must be at least 5 bytes")
    }
    if (innerPlainLen < 0 || innerPlainLen > TLS_MAX_PLAINTEXT_LEN + 1) {
        throw CryptoException(OutOfBounds, "TLS1.3 AEAD inner plaintext length out of range")
    }
    // opaque_type = ApplicationData (23)
    outAad[0] = UInt8(0x17)
    // legacy_record_version = 0x0303
    outAad[1] = UInt8(0x03)
    outAad[2] = UInt8(0x03)
    // length (inner plaintext length)
    outAad[3] = UInt8((innerPlainLen >> 8) & 0xff)
    outAad[4] = UInt8(innerPlainLen & 0xff)
}

private func contentTypeToWire(contentType: TlsContentType): Byte {
    match (contentType) {
        case ChangeCipherSpec => UInt8(0x14)
        case Alert => UInt8(0x15)
        case Handshake => UInt8(0x16)
        case ApplicationData => UInt8(0x17)
    }
}

private func contentTypeFromWire(value: UInt8): TlsContentType {
    if (value == UInt8(0x14)) {
        return ChangeCipherSpec
    }
    if (value == UInt8(0x15)) {
        return Alert
    }
    if (value == UInt8(0x16)) {
        return Handshake
    }
    if (value == UInt8(0x17)) {
        return ApplicationData
    }
    throw CryptoException(Unsupported, "unsupported TLS content type")
}

private func alertLevelToWire(level: TlsAlertLevel): Byte {
    match (level) {
        case Warning => UInt8(0x01)
        case Fatal => UInt8(0x02)
    }
}

private func alertLevelFromWire(value: UInt8): TlsAlertLevel {
    if (value == UInt8(0x01)) {
        return Warning
    }
    if (value == UInt8(0x02)) {
        return Fatal
    }
    throw CryptoException(Unsupported, "unsupported TLS alert level")
}

private func alertDescriptionToWire(description: TlsAlertDescription): Byte {
    match (description) {
        case CloseNotify => UInt8(0x00)
        case UnexpectedMessage => UInt8(0x0a)
        case BadRecordMac => UInt8(0x14)
        case DecryptionFailedReserved => UInt8(0x15)
        case RecordOverflow => UInt8(0x16)
        case HandshakeFailure => UInt8(0x28)
        case BadCertificate => UInt8(0x2a)
        case UnsupportedCertificate => UInt8(0x2b)
        case CertificateRevoked => UInt8(0x2c)
        case CertificateExpired => UInt8(0x2d)
        case CertificateUnknown => UInt8(0x2e)
        case IllegalParameter => UInt8(0x2f)
        case UnknownCa => UInt8(0x30)
        case AccessDenied => UInt8(0x31)
        case DecodeError => UInt8(0x32)
        case DecryptError => UInt8(0x33)
        case ProtocolVersion => UInt8(0x46)
        case InsufficientSecurity => UInt8(0x47)
        case InternalError => UInt8(0x50)
        case UserCanceled => UInt8(0x5a)
        case MissingExtension => UInt8(0x6d)
        case UnsupportedExtension => UInt8(0x6e)
        case UnrecognizedName => UInt8(0x70)
        case BadCertificateStatusResponse => UInt8(0x71)
        case UnknownPskIdentity => UInt8(0x73)
        case CertificateRequired => UInt8(0x74)
        case NoApplicationProtocol => UInt8(0x78)
    }
}

private func alertDescriptionFromWire(value: UInt8): TlsAlertDescription {
    if (value == UInt8(0x00)) {
        return CloseNotify
    }
    if (value == UInt8(0x0a)) {
        return UnexpectedMessage
    }
    if (value == UInt8(0x14)) {
        return BadRecordMac
    }
    if (value == UInt8(0x15)) {
        return DecryptionFailedReserved
    }
    if (value == UInt8(0x16)) {
        return RecordOverflow
    }
    if (value == UInt8(0x28)) {
        return HandshakeFailure
    }
    if (value == UInt8(0x2a)) {
        return BadCertificate
    }
    if (value == UInt8(0x2b)) {
        return UnsupportedCertificate
    }
    if (value == UInt8(0x2c)) {
        return CertificateRevoked
    }
    if (value == UInt8(0x2d)) {
        return CertificateExpired
    }
    if (value == UInt8(0x2e)) {
        return CertificateUnknown
    }
    if (value == UInt8(0x2f)) {
        return IllegalParameter
    }
    if (value == UInt8(0x30)) {
        return UnknownCa
    }
    if (value == UInt8(0x31)) {
        return AccessDenied
    }
    if (value == UInt8(0x32)) {
        return DecodeError
    }
    if (value == UInt8(0x33)) {
        return DecryptError
    }
    if (value == UInt8(0x46)) {
        return ProtocolVersion
    }
    if (value == UInt8(0x47)) {
        return InsufficientSecurity
    }
    if (value == UInt8(0x50)) {
        return InternalError
    }
    if (value == UInt8(0x5a)) {
        return UserCanceled
    }
    if (value == UInt8(0x6d)) {
        return MissingExtension
    }
    if (value == UInt8(0x6e)) {
        return UnsupportedExtension
    }
    if (value == UInt8(0x70)) {
        return UnrecognizedName
    }
    if (value == UInt8(0x71)) {
        return BadCertificateStatusResponse
    }
    if (value == UInt8(0x73)) {
        return UnknownPskIdentity
    }
    if (value == UInt8(0x74)) {
        return CertificateRequired
    }
    if (value == UInt8(0x78)) {
        return NoApplicationProtocol
    }
    throw CryptoException(Unsupported, "unsupported TLS alert description")
}

private func tlsVersionToWire(version: TlsVersion): Array<Byte> {
    match (version) {
        case TLS1_2 => [UInt8(0x03), UInt8(0x03)]
        case TLS1_3 => [UInt8(0x03), UInt8(0x04)]
    }
}

private func tlsVersionFromWire(major: UInt8, minor: UInt8): TlsVersion {
    if (major == UInt8(0x03) && minor == UInt8(0x03)) {
        return TLS1_2
    }
    if (major == UInt8(0x03) && minor == UInt8(0x04)) {
        return TLS1_3
    }
    throw CryptoException(Unsupported, "unsupported TLS protocol version")
}

@OverflowWrapping
private func encodeUInt16BE(value: Int64): Array<Byte> {
    if (value < 0 || value > 65535) {
        throw CryptoException(OutOfBounds, "value does not fit into uint16")
    }
    let v = UInt16(value)
    [UInt8((v >> 8) & UInt16(0xff)), UInt8(v & UInt16(0xff))]
}

@OverflowWrapping
private func decodeUInt16BE(bytes: Array<Byte>, offset: Int64): Int64 {
    if (offset < 0 || offset + 2 > bytes.size) {
        throw CryptoException(OutOfBounds, "uint16 decode out of bounds")
    }
    let hi = Int64(UInt8(bytes[offset]))
    let lo = Int64(UInt8(bytes[offset + 1]))
    (hi << 8) | lo
}

@OverflowWrapping
private func encodeUInt64BE(value: Int64): Array<Byte> {
    if (value < 0) {
        throw CryptoException(InvalidArgument, "negative value cannot be encoded as uint64")
    }
    let v = UInt64(value)
    [
        UInt8((v >> 56) & UInt64(0xff)),
        UInt8((v >> 48) & UInt64(0xff)),
        UInt8((v >> 40) & UInt64(0xff)),
        UInt8((v >> 32) & UInt64(0xff)),
        UInt8((v >> 24) & UInt64(0xff)),
        UInt8((v >> 16) & UInt64(0xff)),
        UInt8((v >> 8) & UInt64(0xff)),
        UInt8(v & UInt64(0xff))
    ]
}
