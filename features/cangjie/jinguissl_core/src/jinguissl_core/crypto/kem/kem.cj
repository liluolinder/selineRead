package jinguissl_core.crypto.kem

import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.digest.{hmac, HashAlgorithm}
import jinguissl_core.crypto.ecc.{NamedCurve, EcPrivateKey, EcPublicKey, ecdhDeriveSharedSecret}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.rsa.{RsaPrivateKey, RsaPublicKey}
import jinguissl_core.crypto.utils.{randomSeed, secureCopyInto}

public func rsaKemRequireAllowed(profile: FipsProfile): Unit {
    if (profile.isAllowed("RSA-KEM")) {
        return
    }
    profile.requireAllowed("RSA")
}

public func ecdhKemRequireAllowed(profile: FipsProfile): Unit {
    if (profile.isAllowed("ECDH-KEM")) {
        return
    }
    profile.requireAllowed("ECDH")
}

public func rsaKemEncapsulate(
    publicKey: RsaPublicKey,
    sharedSecretLen!: Int64 = 32,
    info!: Array<Byte> = []
): (Array<Byte>, Array<Byte>) {
    validateSharedSecretLen(sharedSecretLen)
    let k = modulusByteLength(publicKey.modulus)
    let z = randomRsaRepresentative(publicKey.modulus, k)
    let ciphertext = z.modExp(publicKey.exponent, publicKey.modulus).toBytesBE(paddedLen: k)
    let ikm = z.toBytesBE(paddedLen: k)
    let sharedSecret = hkdfSha256(ikm, appendContext("RSA-KEM", info), sharedSecretLen)
    (ciphertext, sharedSecret)
}

/**
 * rsaKemDecapsulate.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func rsaKemDecapsulate(
    privateKey: RsaPrivateKey,
    ciphertext: Array<Byte>,
    sharedSecretLen!: Int64 = 32,
    info!: Array<Byte> = []
): Array<Byte> {
    validateSharedSecretLen(sharedSecretLen)
    let modulus = privateKey.publicKey.modulus
    let k = modulusByteLength(modulus)
    if (ciphertext.size != k) {
        throw CryptoException(InvalidArgument, "RSA-KEM ciphertext length mismatch")
    }

    let c = BigNum.fromBytesBE(ciphertext)
    if (c.cmp(modulus) >= 0) {
        throw CryptoException(InvalidArgument, "RSA-KEM ciphertext representative out of range")
    }

    let ikm = c.modExp(privateKey.privateExponent, modulus).toBytesBE(paddedLen: k)
    hkdfSha256(ikm, appendContext("RSA-KEM", info), sharedSecretLen)
}

/**
 * ecdhKemEncapsulate.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func ecdhKemEncapsulate(
    peerPublicKey: EcPublicKey,
    sharedSecretLen!: Int64 = 32,
    info!: Array<Byte> = []
): (Array<Byte>, Array<Byte>) {
    validateSharedSecretLen(sharedSecretLen)
    if (peerPublicKey.curve != P256) {
        throw CryptoException(Unsupported, "ECDH-KEM currently supports only P-256")
    }

    let scalar = randomP256Scalar()
    let ephemeralPrivate = EcPrivateKey(P256, scalar)
    let sharedX = ecdhDeriveSharedSecret(ephemeralPrivate, peerPublicKey)
    let ephemeralPublic = p256PublicFromScalarXOnly(scalar)
    let encapsulatedKey = encodeUncompressedP256(ephemeralPublic)
    let sharedSecret = hkdfSha256(sharedX, appendContext("ECDH-KEM", info), sharedSecretLen)
    (encapsulatedKey, sharedSecret)
}

/**
 * ecdhKemDecapsulate.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func ecdhKemDecapsulate(
    privateKey: EcPrivateKey,
    encapsulatedKey: Array<Byte>,
    sharedSecretLen!: Int64 = 32,
    info!: Array<Byte> = []
): Array<Byte> {
    validateSharedSecretLen(sharedSecretLen)
    if (privateKey.curve != P256) {
        throw CryptoException(Unsupported, "ECDH-KEM currently supports only P-256")
    }

    let ephemeralPublic = decodeUncompressedP256(encapsulatedKey)
    let sharedX = ecdhDeriveSharedSecret(privateKey, ephemeralPublic)
    hkdfSha256(sharedX, appendContext("ECDH-KEM", info), sharedSecretLen)
}

private let HKDF_SHA256_LEN: Int64 = 32
private let HKDF_MAX_BLOCKS: Int64 = 255
private let P256_FIELD_BYTES: Int64 = 32
private let P256_ORDER: BigNum = BigNum.fromHex("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551")
private let P256_PRIME: BigNum = BigNum.fromHex("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF")
private let P256_A: BigNum = BigNum.fromHex("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC")
private let P256_B: BigNum = BigNum.fromHex("5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B")
private let P256_GX: BigNum = BigNum.fromHex("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296")
private let P256_GY: BigNum = BigNum.fromHex("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5")

private func validateSharedSecretLen(sharedSecretLen: Int64): Unit {
    if (sharedSecretLen <= 0) {
        throw CryptoException(InvalidArgument, "shared secret length must be > 0")
    }
    if (sharedSecretLen > (HKDF_MAX_BLOCKS * HKDF_SHA256_LEN)) {
        throw CryptoException(OutOfBounds, "shared secret length is too large")
    }
}

private func modulusByteLength(modulus: BigNum): Int64 {
    let raw = modulus.toBytesBE()
    if (raw.size == 1 && UInt8(raw[0]) == UInt8(0)) {
        throw CryptoException(InvalidArgument, "RSA modulus must be positive")
    }
    raw.size
}

private func randomRsaRepresentative(modulus: BigNum, byteLen: Int64): BigNum {
    var attempt = 0
    while (attempt < 256) {
        let candidate = BigNum.fromBytesBE(randomSeed(size: byteLen))
        if (!candidate.isZero() && candidate.cmp(modulus) < 0) {
            return candidate
        }
        attempt += 1
    }
    throw CryptoException(InternalError, "failed to generate RSA-KEM random representative")
}

private func randomP256Scalar(): BigNum {
    var attempt = 0
    while (attempt < 256) {
        let candidate = BigNum.fromBytesBE(randomSeed(size: P256_FIELD_BYTES)).mod(P256_ORDER)
        if (!candidate.isZero()) {
            return candidate
        }
        attempt += 1
    }
    throw CryptoException(InternalError, "failed to generate ECDH-KEM ephemeral scalar")
}

private func p256PublicFromScalarXOnly(scalar: BigNum): EcPublicKey {
    let base = EcPublicKey(P256, P256_GX, P256_GY)
    let privateKey = EcPrivateKey(P256, scalar)
    let xBytes = ecdhDeriveSharedSecret(privateKey, base)
    let x = BigNum.fromBytesBE(xBytes)
    let y = recoverP256YFromX(x)
    EcPublicKey(P256, x, y)
}

private func recoverP256YFromX(x: BigNum): BigNum {
    let xNorm = x.mod(P256_PRIME)
    let rhs = xNorm.mul(xNorm).mul(xNorm).add(P256_A.mul(xNorm)).add(P256_B).mod(P256_PRIME)
    BigNum.modSqrt(rhs, P256_PRIME)
}

private func encodeUncompressedP256(publicKey: EcPublicKey): Array<Byte> {
    if (publicKey.curve != P256) {
        throw CryptoException(InvalidArgument, "only P-256 public keys can be encoded")
    }

    let out = Array<Byte>(1 + P256_FIELD_BYTES + P256_FIELD_BYTES, repeat: 0)
    out[0] = UInt8(0x04)
    let x = publicKey.x.toBytesBE(paddedLen: P256_FIELD_BYTES)
    let y = publicKey.y.toBytesBE(paddedLen: P256_FIELD_BYTES)
    secureCopyInto(x, out, dstOffset: 1)
    secureCopyInto(y, out, dstOffset: 1 + P256_FIELD_BYTES)
    out
}

private func decodeUncompressedP256(encoded: Array<Byte>): EcPublicKey {
    if (encoded.size != 1 + P256_FIELD_BYTES + P256_FIELD_BYTES) {
        throw CryptoException(ParseError, "invalid P-256 uncompressed point length")
    }
    if (UInt8(encoded[0]) != UInt8(0x04)) {
        throw CryptoException(ParseError, "invalid P-256 uncompressed point prefix")
    }

    let x = BigNum.fromBytesBE(encoded[1..(1 + P256_FIELD_BYTES)])
    let y = BigNum.fromBytesBE(encoded[(1 + P256_FIELD_BYTES)..])
    EcPublicKey(P256, x, y)
}

private func appendContext(label: String, info: Array<Byte>): Array<Byte> {
    let labelBytes = label.toArray()
    let out = Array<Byte>(labelBytes.size + info.size, repeat: 0)
    secureCopyInto(labelBytes, out)
    if (info.size > 0) {
        secureCopyInto(info, out, dstOffset: labelBytes.size)
    }
    out
}

private func hkdfSha256(ikm: Array<Byte>, info: Array<Byte>, outputLen: Int64): Array<Byte> {
    let zeroSalt = Array<Byte>(HKDF_SHA256_LEN, repeat: 0)
    let prk = hmac(HashAlgorithm.SHA256, zeroSalt, ikm)

    let blocks = (outputLen + HKDF_SHA256_LEN - 1) / HKDF_SHA256_LEN
    if (blocks > HKDF_MAX_BLOCKS) {
        throw CryptoException(OutOfBounds, "HKDF output is too large")
    }

    let out = Array<Byte>(outputLen, repeat: 0)
    var t = Array<Byte>(0, repeat: 0)
    var offset: Int64 = 0
    var counter: Int64 = 1
    while (counter <= blocks) {
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
        let take = if (remain < HKDF_SHA256_LEN) {
            remain
        } else {
            HKDF_SHA256_LEN
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
