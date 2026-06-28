package jinguissl_core.crypto.ecc

import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.digest.sha256
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}

private let ES256_P256_COORDINATE_BYTES: Int64 = 32
private let ES256_P256_DIGEST_BYTES: Int64 = 32
private let DER_TAG_INTEGER: Int64 = 0x02
private let DER_TAG_SEQUENCE: Int64 = 0x30

public class Es256P256StructuredVerifyRequest {
    public let x: Array<Byte>
    public let y: Array<Byte>
    public let signedBytes: Array<Byte>
    public let derSignature: Array<Byte>

    public init(
        x: Array<Byte>,
        y: Array<Byte>,
        signedBytes: Array<Byte>,
        derSignature: Array<Byte>
    ) {
        if (x.size != ES256_P256_COORDINATE_BYTES || y.size != ES256_P256_COORDINATE_BYTES) {
            throw CryptoException(
                InvalidArgument,
                "ES256/P-256 structured verify coordinates must be 32 bytes"
            )
        }
        if (derSignature.size == 0) {
            throw CryptoException(
                InvalidArgument,
                "ES256/P-256 structured verify DER signature must not be empty"
            )
        }
        this.x = x.clone()
        this.y = y.clone()
        this.signedBytes = signedBytes.clone()
        this.derSignature = derSignature.clone()
    }
}

public class Es256P256StructuredVerifyResult {
    public let signatureVerified: Bool
    public let digestSha256: Array<Byte>

    public init(signatureVerified: Bool, digestSha256: Array<Byte>) {
        if (digestSha256.size != ES256_P256_DIGEST_BYTES) {
            throw CryptoException(
                InvalidArgument,
                "ES256/P-256 structured verify digest must be 32 bytes"
            )
        }
        this.signatureVerified = signatureVerified
        this.digestSha256 = digestSha256.clone()
    }
}

public class Es256P256StructuredVerifyOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?CryptoErrorCode
    public let result: ?Es256P256StructuredVerifyResult

    public init(
        ok: Bool,
        message: String,
        code!: ?CryptoErrorCode = None,
        result!: ?Es256P256StructuredVerifyResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw CryptoException(
                InvalidArgument,
                "ES256/P-256 structured verify outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw CryptoException(
                        InvalidArgument,
                        "successful ES256/P-256 structured verify outcome must not carry an error code"
                    )
                case None => ()
            }
            match (result) {
                case Some(_value) => ()
                case None =>
                    throw CryptoException(
                        InvalidArgument,
                        "successful ES256/P-256 structured verify outcome must carry a result"
                    )
            }
        } else {
            match (code) {
                case Some(_value) => ()
                case None =>
                    throw CryptoException(
                        InvalidArgument,
                        "failed ES256/P-256 structured verify outcome must carry an error code"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw CryptoException(
                        InvalidArgument,
                        "failed ES256/P-256 structured verify outcome must not carry a result"
                    )
                case None => ()
            }
        }
        this.ok = ok
        this.message = message
        this.code = code
        this.result = result
    }
}

public func es256P256VerifyStructuredRequest(
    request: Es256P256StructuredVerifyRequest
): Es256P256StructuredVerifyResult {
    let publicKey = EcPublicKey(
        P256,
        BigNum.fromBytesBE(request.x),
        BigNum.fromBytesBE(request.y)
    )
    let digest = sha256(request.signedBytes)
    let (r, s) = decodeEs256P256DerSignature(request.derSignature)
    let signatureVerified = ecdsaVerify(publicKey, digest, r, s)
    Es256P256StructuredVerifyResult(signatureVerified, digest)
}

public func tryEs256P256VerifyStructuredRequest(
    request: Es256P256StructuredVerifyRequest
): Es256P256StructuredVerifyOutcome {
    try {
        let result = es256P256VerifyStructuredRequest(request)
        let message = if (result.signatureVerified) {
            "ES256/P-256 signature verified"
        } else {
            "ES256/P-256 signature did not verify"
        }
        Es256P256StructuredVerifyOutcome(true, message, result: Some(result))
    } catch (e: CryptoException) {
        Es256P256StructuredVerifyOutcome(false, e.message, code: Some(e.code))
    }
}

private class StructuredVerifyDerElement {
    let tag: Int64
    let value: Array<Byte>
    let nextOffset: Int64

    init(tag: Int64, value: Array<Byte>, nextOffset: Int64) {
        this.tag = tag
        this.value = value.clone()
        this.nextOffset = nextOffset
    }
}

private func decodeEs256P256DerSignature(signatureDer: Array<Byte>): (BigNum, BigNum) {
    let sequence = readStructuredVerifyDerElement(signatureDer, 0, "ECDSA signature")
    if (sequence.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "ECDSA signature must be DER SEQUENCE")
    }
    if (sequence.nextOffset != signatureDer.size) {
        throw CryptoException(ParseError, "ECDSA signature has trailing bytes")
    }

    let rElement = readStructuredVerifyDerElement(sequence.value, 0, "ECDSA signature.r")
    if (rElement.tag != DER_TAG_INTEGER) {
        throw CryptoException(ParseError, "ECDSA signature.r must be DER INTEGER")
    }

    let sElement = readStructuredVerifyDerElement(sequence.value, rElement.nextOffset, "ECDSA signature.s")
    if (sElement.tag != DER_TAG_INTEGER) {
        throw CryptoException(ParseError, "ECDSA signature.s must be DER INTEGER")
    }
    if (sElement.nextOffset != sequence.value.size) {
        throw CryptoException(ParseError, "ECDSA signature has trailing bytes")
    }

    let r = BigNum.fromBytesBE(parseStructuredVerifyPositiveInteger(rElement.value, "ECDSA signature.r"))
    let s = BigNum.fromBytesBE(parseStructuredVerifyPositiveInteger(sElement.value, "ECDSA signature.s"))
    (r, s)
}

private func readStructuredVerifyDerElement(
    bytes: Array<Byte>,
    offset: Int64,
    label: String
): StructuredVerifyDerElement {
    if (offset >= bytes.size) {
        throw CryptoException(ParseError, "${label} is truncated")
    }

    let tagByte = UInt8(bytes[offset])
    if ((tagByte & UInt8(0x1f)) == UInt8(0x1f)) {
        throw CryptoException(ParseError, "${label} uses unsupported high-tag-number form")
    }

    let lengthOffset = offset + 1
    let (valueLength, lengthBytes) = decodeStructuredVerifyDerLength(bytes, lengthOffset, label)
    let valueOffset = lengthOffset + lengthBytes
    if (valueLength < 0 || valueOffset + valueLength > bytes.size) {
        throw CryptoException(ParseError, "${label} length exceeds input bounds")
    }

    let nextOffset = valueOffset + valueLength
    StructuredVerifyDerElement(
        Int64(tagByte),
        bytes[valueOffset..nextOffset],
        nextOffset
    )
}

private func decodeStructuredVerifyDerLength(
    bytes: Array<Byte>,
    offset: Int64,
    label: String
): (Int64, Int64) {
    if (offset >= bytes.size) {
        throw CryptoException(ParseError, "${label} DER length is truncated")
    }

    let first = UInt8(bytes[offset])
    if ((first & UInt8(0x80)) == UInt8(0)) {
        return (Int64(first), 1)
    }

    let width = Int64(first & UInt8(0x7f))
    if (width == 0) {
        throw CryptoException(ParseError, "${label} DER length uses indefinite form")
    }
    if (width > 4) {
        throw CryptoException(ParseError, "${label} DER length width is too large")
    }
    if (offset + 1 + width > bytes.size) {
        throw CryptoException(ParseError, "${label} DER length is truncated")
    }

    var length: Int64 = 0
    var i = 0
    while (i < width) {
        length = (length << 8) | Int64(UInt8(bytes[offset + 1 + i]))
        i += 1
    }
    if (length < 0) {
        throw CryptoException(ParseError, "${label} DER length is negative")
    }
    if (length < 128) {
        throw CryptoException(ParseError, "${label} DER length uses non-minimal long form")
    }
    (length, 1 + width)
}

private func parseStructuredVerifyPositiveInteger(
    encoded: Array<Byte>,
    label: String
): Array<Byte> {
    if (encoded.size == 0) {
        throw CryptoException(ParseError, "${label} INTEGER is empty")
    }
    if ((UInt8(encoded[0]) & UInt8(0x80)) != UInt8(0)) {
        throw CryptoException(ParseError, "${label} INTEGER must be non-negative")
    }

    let trimmed = trimStructuredVerifyLeadingZeros(encoded)
    if (trimmed.size == 0) {
        return [UInt8(0)]
    }
    trimmed
}

private func trimStructuredVerifyLeadingZeros(bytes: Array<Byte>): Array<Byte> {
    var offset = 0
    while (offset < bytes.size && UInt8(bytes[offset]) == UInt8(0)) {
        offset += 1
    }
    if (offset == 0) {
        return bytes.clone()
    }
    if (offset >= bytes.size) {
        return []
    }
    bytes[offset..]
}
