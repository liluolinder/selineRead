package jinguissl_core.crypto.rsa

import std.math.numeric.{BigInt, abs}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.digest.{sha1, sha256, sha384, sha512}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.utils.{constantTimeEquals, csprngBytes, randomSeed, secureCopyInto}

private let RSA_KEYGEN_OUTER_MAX_ATTEMPTS: Int64 = 32
private let RSA_PRIME_SEARCH_MAX_ATTEMPTS: Int64 = 1_000_000
private let RSA_PRIMALITY_ROUNDS: Int64 = 12
private let RSA_BLINDING_MAX_ATTEMPTS: Int64 = 64
private let RSA_SMALL_PRIMES: Array<Int64> = [
    3, 5, 7, 11, 13, 17, 19, 23, 29, 31,
    37, 41, 43, 47, 53, 59, 61, 67, 71, 73,
    79, 83, 89, 97, 101, 103, 107, 109, 113, 127,
    131, 137, 139, 149, 151, 157, 163, 167, 173, 179,
    181, 191, 193, 197, 199, 211, 223, 227, 229, 233,
    239, 241, 251, 257, 263, 269, 271, 277, 281, 283,
    293, 307, 311, 313, 317, 331, 337, 347, 349, 353,
    359, 367, 373, 379, 383, 389, 397, 401, 409, 419,
    421, 431, 433, 439, 443, 449, 457, 461, 463, 467,
    479, 487, 491, 499, 503, 509, 521, 523, 541
]

public enum RsaSignatureScheme <: Equatable<RsaSignatureScheme> & ToString {
    /** @deprecated RSA-PKCS1v1.5 is vulnerable to Bleichenbacher attacks. Use RSA-PSS instead. */
    | PKCS1v15
    | PSS

    public operator func ==(right: RsaSignatureScheme): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: RsaSignatureScheme): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case PKCS1v15 => 0
            case PSS => 1
        }
    }

    public func toString(): String {
        match (this) {
            case PKCS1v15 => "RSA-PKCS1V1.5"
            case PSS => "RSA-PSS"
        }
    }
}

public enum RsaHashAlgorithm <: Equatable<RsaHashAlgorithm> & ToString {
    | SHA1
    | SHA256
    | SHA384
    | SHA512

    public operator func ==(right: RsaHashAlgorithm): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: RsaHashAlgorithm): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case SHA1 => 0
            case SHA256 => 1
            case SHA384 => 2
            case SHA512 => 3
        }
    }

    public func toString(): String {
        match (this) {
            case SHA1 => "SHA-1"
            case SHA256 => "SHA-256"
            case SHA384 => "SHA-384"
            case SHA512 => "SHA-512"
        }
    }
}

public class RsaPublicKey {
    public let modulus: BigNum
    public let exponent: BigNum

    public init(modulus: BigNum, exponent: BigNum) {
        validateModulus(modulus)
        validatePublicExponent(exponent)
        this.modulus = modulus
        this.exponent = exponent
    }

    public func bits(): Int64 {
        bitLength(modulus)
    }
}

public class RsaPrivateKey {
    public let publicKey: RsaPublicKey
    public let privateExponent: BigNum

    public init(modulus: BigNum, exponent: BigNum, privateExponent: BigNum) {
        this.publicKey = RsaPublicKey(modulus, exponent)
        if (privateExponent.isZero() || privateExponent.isNegative()) {
            throw CryptoException(InvalidArgument, "RSA private exponent must be positive")
        }
        this.privateExponent = privateExponent
    }
}

public func rsaPublicKeyFromHex(modulusHex: String, exponentHex: String): RsaPublicKey {
    RsaPublicKey(BigNum.fromHex(modulusHex), BigNum.fromHex(exponentHex))
}

public func rsaPrivateKeyFromHex(modulusHex: String, exponentHex: String, privateExponentHex: String): RsaPrivateKey {
    RsaPrivateKey(BigNum.fromHex(modulusHex), BigNum.fromHex(exponentHex), BigNum.fromHex(privateExponentHex))
}

public func rsaRequireAllowed(profile: FipsProfile): Unit {
    profile.requireAllowed("RSA")
}

/**
 * rsaValidateKeyParameters.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func rsaValidateKeyParameters(bits: Int64, publicExponent: BigNum): Unit {
    if (bits != 2048 && bits != 4096) {
        throw CryptoException(ComplianceRejected, "RSA key size must be 2048 or 4096 bits in stage3 profile")
    }
    validatePublicExponent(publicExponent)
}

/**
 * rsaGenerateKey.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func rsaGenerateKey(
    bits: Int64,
    publicExponent!: BigNum = BigNum.fromHex("010001")
): RsaPrivateKey {
    rsaValidateKeyParameters(bits, publicExponent)
    let e = publicExponent.toBigInt()
    let one = BigInt(1)
    let pBits = bits / 2
    let qBits = bits - pBits

    var attempt = 0
    while (attempt < RSA_KEYGEN_OUTER_MAX_ATTEMPTS) {
        let p = rsaGeneratePrimeForKeygen(pBits, e)
        var q = rsaGeneratePrimeForKeygen(qBits, e)
        while (p == q) {
            q = rsaGeneratePrimeForKeygen(qBits, e)
        }

        let n = p * q
        if (bitLength(BigNum(n)) != bits) {
            attempt += 1
            continue
        }

        let phi = (p - one) * (q - one)
        if (rsaBigIntGcd(phi, e) != one) {
            attempt += 1
            continue
        }

        let d = try {
            e.modInverse(phi)
        } catch (_: Exception) {
            attempt += 1
            continue
        }

        return RsaPrivateKey(BigNum(n), publicExponent, BigNum(d))
    }

    throw CryptoException(InternalError, "RSA key generation exceeded attempt budget")
}

public func rsaSignPkcs1v15(privateKey: RsaPrivateKey, digest: Array<Byte>): Array<Byte> {
    rsaSignPkcs1v15WithHash(privateKey, digest, SHA256)
}

public func rsaVerifyPkcs1v15(publicKey: RsaPublicKey, digest: Array<Byte>, signature: Array<Byte>): Bool {
    rsaVerifyPkcs1v15WithHash(publicKey, digest, signature, SHA256)
}

public func rsaSignPkcs1v15WithHash(
    privateKey: RsaPrivateKey,
    digest: Array<Byte>,
    hashAlgorithm: RsaHashAlgorithm
): Array<Byte> {
    let k = modulusByteLength(privateKey.publicKey.modulus)
    let encoded = emsaPkcs1v15EncodeDigest(hashAlgorithm, digest, k)
    rsaPrivateTransform(privateKey, encoded)
}

public func rsaVerifyPkcs1v15WithHash(
    publicKey: RsaPublicKey,
    digest: Array<Byte>,
    signature: Array<Byte>,
    hashAlgorithm: RsaHashAlgorithm
): Bool {
    let k = modulusByteLength(publicKey.modulus)
    if (signature.size != k) {
        return false
    }

    try {
        let recovered = rsaPublicTransform(publicKey, signature)
        let expected = emsaPkcs1v15EncodeDigest(hashAlgorithm, digest, k)
        return constantTimeEquals(recovered, expected)
    } catch (_: CryptoException) {
        return false
    }
}

public func rsaSignPss(privateKey: RsaPrivateKey, digest: Array<Byte>, saltLen!: Int64 = -1): Array<Byte> {
    rsaSignPssWithHash(privateKey, digest, SHA256, saltLen: saltLen)
}

public func rsaVerifyPss(publicKey: RsaPublicKey, digest: Array<Byte>, signature: Array<Byte>, saltLen!: Int64 = -1): Bool {
    rsaVerifyPssWithHash(publicKey, digest, signature, SHA256, saltLen: saltLen)
}

public func rsaSignPssWithHash(
    privateKey: RsaPrivateKey,
    digest: Array<Byte>,
    hashAlgorithm: RsaHashAlgorithm,
    saltLen!: Int64 = -1
): Array<Byte> {
    let nBits = bitLength(privateKey.publicKey.modulus)
    let emBits = nBits - 1
    let em = emsaPssEncodeDigest(hashAlgorithm, digest, emBits, saltLen)
    rsaPrivateTransform(privateKey, em)
}

public func rsaVerifyPssWithHash(
    publicKey: RsaPublicKey,
    digest: Array<Byte>,
    signature: Array<Byte>,
    hashAlgorithm: RsaHashAlgorithm,
    saltLen!: Int64 = -1
): Bool {
    let k = modulusByteLength(publicKey.modulus)
    if (k == 0 || signature.size != k) {
        return false
    }

    try {
        let em = rsaPublicTransform(publicKey, signature)
        let emBits = bitLength(publicKey.modulus) - 1
        return emsaPssVerifyDigest(hashAlgorithm, digest, em, emBits, saltLen)
    } catch (_: CryptoException) {
        return false
    }
}

private func validateModulus(modulus: BigNum): Unit {
    if (modulus.isZero() || modulus.isNegative()) {
        throw CryptoException(InvalidArgument, "RSA modulus must be positive")
    }
}

private func validatePublicExponent(exponent: BigNum): Unit {
    if (exponent.isZero() || exponent.isNegative()) {
        throw CryptoException(InvalidArgument, "RSA public exponent must be positive")
    }

    let e = exponent.toBigInt()
    if (e < BigInt(3)) {
        throw CryptoException(InvalidArgument, "RSA public exponent must be >= 3")
    }
    if ((e % BigInt(2)) == BigInt(0)) {
        throw CryptoException(InvalidArgument, "RSA public exponent must be odd")
    }
}

private func rsaGeneratePrimeForKeygen(bits: Int64, publicExponent: BigInt): BigInt {
    if (bits < 2) {
        throw CryptoException(InvalidArgument, "RSA prime bits must be >= 2")
    }

    let one = BigInt(1)
    let upperExclusive = one << bits
    var candidate = rsaRandomOddCandidate(bits)
    var attempt = 0

    while (attempt < RSA_PRIME_SEARCH_MAX_ATTEMPTS) {
        if (candidate >= upperExclusive) {
            candidate = rsaRandomOddCandidate(bits)
            attempt += 1
            continue
        }

        let exponentIsCoprime = rsaBigIntGcd(candidate - one, publicExponent) == one
        let candidateIsProbablePrime = rsaIsProbablePrime(candidate)
        if (exponentIsCoprime && candidateIsProbablePrime) {
            return candidate
        }

        candidate += BigInt(2)
        attempt += 1
    }

    throw CryptoException(InternalError, "RSA prime generation exceeded attempt budget")
}

@OverflowWrapping
private func rsaRandomOddCandidate(bits: Int64): BigInt {
    let byteLen = (bits + 7) / 8
    let bytes = csprngBytes(byteLen)
    let extraBits = byteLen * 8 - bits
    if (extraBits > 0) {
        let topMask = UInt8(UInt32(0xff) >> UInt32(extraBits))
        bytes[0] = UInt8(bytes[0]) & topMask
        let highestBit = UInt8(UInt32(1) << UInt32(7 - extraBits))
        bytes[0] = UInt8(bytes[0]) | highestBit
    } else {
        bytes[0] = UInt8(bytes[0]) | UInt8(0x80)
    }
    bytes[byteLen - 1] = UInt8(bytes[byteLen - 1]) | UInt8(0x01)
    BigNum.fromBytesBE(bytes).toBigInt()
}

private func rsaIsProbablePrime(candidate: BigInt): Bool {
    let zero = BigInt(0)
    let one = BigInt(1)
    let two = BigInt(2)
    let three = BigInt(3)
    if (candidate < two) {
        return false
    }
    if (candidate == two || candidate == three) {
        return true
    }
    if ((candidate % two) == zero) {
        return false
    }

    for (prime in RSA_SMALL_PRIMES) {
        let p = BigInt(prime)
        if (candidate == p) {
            return true
        }
        if ((candidate % p) == zero) {
            return false
        }
    }

    let nMinusOne = candidate - one
    var d = nMinusOne
    var s: Int64 = 0
    while ((d % two) == zero) {
        d = d / two
        s += 1
    }

    var round = 0
    while (round < RSA_PRIMALITY_ROUNDS) {
        let a = rsaRandomMillerRabinBase(candidate)
        var x = a.modPow(d, m: candidate)
        if (x == one || x == nMinusOne) {
            round += 1
            continue
        }

        var witnessPass = false
        var r: Int64 = 1
        while (r < s) {
            x = (x * x) % candidate
            if (x == nMinusOne) {
                witnessPass = true
                break
            }
            r += 1
        }

        if (!witnessPass) {
            return false
        }
        round += 1
    }
    true
}

private func rsaRandomMillerRabinBase(candidate: BigInt): BigInt {
    let two = BigInt(2)
    let upper = candidate - two
    if (upper <= two) {
        return two
    }
    let span = (upper - two) + BigInt(1)
    two + rsaRandomBigIntBelow(span)
}

private func rsaRandomBigIntBelow(limitExclusive: BigInt): BigInt {
    if (limitExclusive <= BigInt(1)) {
        return BigInt(0)
    }
    let maxValue = limitExclusive - BigInt(1)
    let byteLen = BigNum(maxValue).toBytesBE().size
    while (true) {
        let sample = BigNum.fromBytesBE(csprngBytes(byteLen)).toBigInt()
        if (sample < limitExclusive) {
            return sample
        }
    }
    BigInt(0)
}

private func rsaBigIntGcd(left: BigInt, right: BigInt): BigInt {
    var a = abs(left)
    var b = abs(right)
    let zero = BigInt(0)
    while (b != zero) {
        let t = a % b
        a = b
        b = t
    }
    a
}

private func rsaPrivateTransform(key: RsaPrivateKey, input: Array<Byte>): Array<Byte> {
    let modulus = key.publicKey.modulus
    let k = modulusByteLength(modulus)
    if (input.size != k) {
        throw CryptoException(InvalidArgument, "RSA input length mismatch")
    }
    let m = BigNum.fromBytesBE(input)
    if (m.cmp(modulus) >= 0) {
        throw CryptoException(InvalidArgument, "RSA input representative out of range")
    }
    let (blinded, blindInverse) = rsaBlindInput(m, key.publicKey, k)
    let blindedResult = blinded.modExp(key.privateExponent, modulus)
    blindedResult.mul(blindInverse).mod(modulus).toBytesBE(paddedLen: k)
}

private func rsaBlindInput(message: BigNum, publicKey: RsaPublicKey, byteLen: Int64): (BigNum, BigNum) {
    let modulus = publicKey.modulus
    let one = BigNum.one()
    var attempt = 0

    while (attempt < RSA_BLINDING_MAX_ATTEMPTS) {
        let r = BigNum.fromBytesBE(csprngBytes(byteLen)).mod(modulus)
        if (r.cmp(one) <= 0 || BigNum.gcd(r, modulus).cmp(one) != 0) {
            attempt += 1
            continue
        }

        let rInverse = try {
            r.modInverse(modulus)
        } catch (_: CryptoException) {
            attempt += 1
            continue
        }
        let rToPublicExponent = r.modExp(publicKey.exponent, modulus)
        return (message.mul(rToPublicExponent).mod(modulus), rInverse)
    }

    throw CryptoException(InternalError, "RSA blinding factor generation exceeded attempt budget")
}

private func rsaPublicTransform(key: RsaPublicKey, input: Array<Byte>): Array<Byte> {
    let k = modulusByteLength(key.modulus)
    if (input.size != k) {
        throw CryptoException(InvalidArgument, "RSA input length mismatch")
    }
    let c = BigNum.fromBytesBE(input)
    if (c.cmp(key.modulus) >= 0) {
        throw CryptoException(InvalidArgument, "RSA input representative out of range")
    }
    c.modExp(key.exponent, key.modulus).toBytesBE(paddedLen: k)
}

private func emsaPkcs1v15EncodeDigest(
    hashAlgorithm: RsaHashAlgorithm,
    digest: Array<Byte>,
    emLen: Int64
): Array<Byte> {
    let prefix = digestInfoPrefix(hashAlgorithm)
    let expectedDigestLen = hashDigestLength(hashAlgorithm)
    if (digest.size != expectedDigestLen) {
        throw CryptoException(InvalidArgument, "digest length mismatch for ${hashAlgorithm.toString()}")
    }

    let tLen = prefix.size + digest.size
    if (emLen < tLen + 11) {
        throw CryptoException(OutOfBounds, "RSA modulus is too short for PKCS1v1.5 encoding")
    }

    let out = Array<Byte>(emLen, repeat: 0)
    out[0] = UInt8(0x00)
    out[1] = UInt8(0x01)

    let psLen = emLen - tLen - 3
    var i = 0
    while (i < psLen) {
        out[2 + i] = UInt8(0xff)
        i += 1
    }
    out[2 + psLen] = UInt8(0x00)

    var offset = 3 + psLen
    i = 0
    while (i < prefix.size) {
        out[offset + i] = prefix[i]
        i += 1
    }
    offset += prefix.size
    i = 0
    while (i < digest.size) {
        out[offset + i] = digest[i]
        i += 1
    }

    out
}

private func emsaPssEncodeDigest(
    hashAlgorithm: RsaHashAlgorithm,
    digest: Array<Byte>,
    emBits: Int64,
    saltLen: Int64
): Array<Byte> {
    let hLen = hashDigestLength(hashAlgorithm)
    if (digest.size != hLen) {
        throw CryptoException(InvalidArgument, "digest length mismatch for ${hashAlgorithm.toString()}")
    }
    if (emBits <= 0) {
        throw CryptoException(InvalidArgument, "invalid RSA emBits")
    }

    let sLen = normalizePssSaltLen(hashAlgorithm, saltLen)
    let emLen = (emBits + 7) / 8
    if (emLen < (hLen + sLen + 2)) {
        throw CryptoException(OutOfBounds, "RSA modulus is too short for PSS encoding")
    }

    let salt = if (sLen == 0) {
        Array<Byte>(0, repeat: 0)
    } else {
        randomSeed(size: sLen)
    }

    let mPrime = Array<Byte>(8 + hLen + sLen, repeat: 0)
    secureCopyInto(digest, mPrime, dstOffset: 8)
    if (sLen > 0) {
        secureCopyInto(salt, mPrime, dstOffset: 8 + hLen)
    }

    let h = hashWithAlgorithm(hashAlgorithm, mPrime)
    let dbLen = emLen - hLen - 1
    let db = Array<Byte>(dbLen, repeat: 0)
    let psLen = emLen - hLen - sLen - 2
    db[psLen] = UInt8(0x01)
    if (sLen > 0) {
        secureCopyInto(salt, db, dstOffset: dbLen - sLen)
    }

    let dbMask = mgf1(h, dbLen, hashAlgorithm)
    let maskedDb = Array<Byte>(dbLen, repeat: 0)
    var i = 0
    while (i < dbLen) {
        maskedDb[i] = UInt8(db[i]) ^ UInt8(dbMask[i])
        i += 1
    }

    let unusedBits = emLen * 8 - emBits
    if (unusedBits > 0) {
        maskedDb[0] = UInt8(maskedDb[0]) & UInt8(UInt32(0xff) >> UInt32(unusedBits))
    }

    let em = Array<Byte>(emLen, repeat: 0)
    secureCopyInto(maskedDb, em)
    secureCopyInto(h, em, dstOffset: dbLen)
    em[emLen - 1] = UInt8(0xbc)
    em
}

private func emsaPssVerifyDigest(
    hashAlgorithm: RsaHashAlgorithm,
    digest: Array<Byte>,
    em: Array<Byte>,
    emBits: Int64,
    saltLen: Int64
): Bool {
    let hLen = hashDigestLength(hashAlgorithm)
    if (digest.size != hLen || emBits <= 0) {
        return false
    }
    if (saltLen < -1) {
        return false
    }

    let sLen = if (saltLen == -1) {
        hLen
    } else {
        saltLen
    }

    let emLen = (emBits + 7) / 8
    if (em.size != emLen) {
        return false
    }
    if (emLen < (hLen + sLen + 2)) {
        return false
    }
    if (UInt8(em[emLen - 1]) != UInt8(0xbc)) {
        return false
    }

    let dbLen = emLen - hLen - 1
    let maskedDb = em[..dbLen]
    let h = em[dbLen..(dbLen + hLen)]

    let unusedBits = emLen * 8 - emBits
    if (unusedBits > 0) {
        let topMask = UInt8(UInt32(0xff) ^ (UInt32(0xff) >> UInt32(unusedBits)))
        if ((UInt8(maskedDb[0]) & topMask) != UInt8(0)) {
            return false
        }
    }

    let dbMask = mgf1(h, dbLen, hashAlgorithm)
    let db = Array<Byte>(dbLen, repeat: 0)
    var i = 0
    while (i < dbLen) {
        db[i] = UInt8(maskedDb[i]) ^ UInt8(dbMask[i])
        i += 1
    }

    if (unusedBits > 0) {
        db[0] = UInt8(db[0]) & UInt8(UInt32(0xff) >> UInt32(unusedBits))
    }

    let psLen = emLen - hLen - sLen - 2
    i = 0
    while (i < psLen) {
        if (UInt8(db[i]) != UInt8(0)) {
            return false
        }
        i += 1
    }
    if (UInt8(db[psLen]) != UInt8(0x01)) {
        return false
    }

    let salt = Array<Byte>(sLen, repeat: 0)
    if (sLen > 0) {
        i = 0
        while (i < sLen) {
            salt[i] = db[(dbLen - sLen) + i]
            i += 1
        }
    }

    let mPrime = Array<Byte>(8 + hLen + sLen, repeat: 0)
    secureCopyInto(digest, mPrime, dstOffset: 8)
    if (sLen > 0) {
        secureCopyInto(salt, mPrime, dstOffset: 8 + hLen)
    }

    let hPrime = hashWithAlgorithm(hashAlgorithm, mPrime)
    constantTimeEquals(hPrime, h)
}

private func normalizePssSaltLen(hashAlgorithm: RsaHashAlgorithm, saltLen: Int64): Int64 {
    if (saltLen < -1) {
        throw CryptoException(InvalidArgument, "RSA PSS salt length must be >= -1")
    }
    if (saltLen == -1) {
        return hashDigestLength(hashAlgorithm)
    }
    saltLen
}

private func hashWithAlgorithm(hashAlgorithm: RsaHashAlgorithm, data: Array<Byte>): Array<Byte> {
    match (hashAlgorithm) {
        case SHA1 => sha1(data)
        case SHA256 => sha256(data)
        case SHA384 => sha384(data)
        case SHA512 => sha512(data)
    }
}

@OverflowWrapping
private func i2osp32(value: Int64): Array<Byte> {
    if (value < 0 || value > Int64(UInt32.Max)) {
        throw CryptoException(OutOfBounds, "MGF1 counter overflow")
    }
    let v = UInt32(value)
    [
        UInt8((v >> 24) & UInt32(0xff)),
        UInt8((v >> 16) & UInt32(0xff)),
        UInt8((v >> 8) & UInt32(0xff)),
        UInt8(v & UInt32(0xff))
    ]
}

private func mgf1(seed: Array<Byte>, maskLen: Int64, hashAlgorithm: RsaHashAlgorithm): Array<Byte> {
    if (maskLen < 0) {
        throw CryptoException(InvalidArgument, "MGF1 mask length must be >= 0")
    }
    if (maskLen == 0) {
        return []
    }

    let out = Array<Byte>(maskLen, repeat: 0)
    var counter: Int64 = 0
    var offset: Int64 = 0
    while (offset < maskLen) {
        let c = i2osp32(counter)
        let input = Array<Byte>(seed.size + 4, repeat: 0)
        secureCopyInto(seed, input)
        secureCopyInto(c, input, dstOffset: seed.size)

        let digest = hashWithAlgorithm(hashAlgorithm, input)
        let remain = maskLen - offset
        let take = if (remain < digest.size) {
            remain
        } else {
            digest.size
        }

        var i = 0
        while (i < take) {
            out[offset + i] = digest[i]
            i += 1
        }

        offset += take
        counter += 1
    }
    out
}

private func digestInfoPrefix(hashAlgorithm: RsaHashAlgorithm): Array<Byte> {
    match (hashAlgorithm) {
        case SHA1 => hexToBytes("3021" + "3009" + "0605" + "2b0e03021a05000414")
        case SHA256 => hexToBytes("3031300d060960864801650304020105000420")
        case SHA384 => hexToBytes("3041300d060960864801650304020205000430")
        case SHA512 => hexToBytes("3051300d060960864801650304020305000440")
    }
}

private func hashDigestLength(hashAlgorithm: RsaHashAlgorithm): Int64 {
    match (hashAlgorithm) {
        case SHA1 => 20
        case SHA256 => 32
        case SHA384 => 48
        case SHA512 => 64
    }
}

private func bitLength(value: BigNum): Int64 {
    let bytes = value.toBytesBE()
    if (bytes.size == 0 || (bytes.size == 1 && UInt8(bytes[0]) == UInt8(0))) {
        return 0
    }

    var top = UInt8(bytes[0])
    var topBits: Int64 = 0
    while (top != UInt8(0)) {
        top = top >> 1
        topBits += 1
    }

    (bytes.size - 1) * 8 + topBits
}

private func modulusByteLength(modulus: BigNum): Int64 {
    let bits = bitLength(modulus)
    if (bits == 0) {
        return 0
    }
    (bits + 7) / 8
}

private func hexToBytes(hex: String): Array<Byte> {
    let clean = hex.trimAscii().replace(" ", "").replace("\n", "").replace("\t", "")
    if ((clean.size % 2) != 0) {
        throw CryptoException(ParseError, "invalid hex length")
    }

    let out = Array<Byte>(clean.size / 2, repeat: 0)
    var i = 0
    while (i < clean.size) {
        let hi = hexNibble(clean[i])
        let lo = hexNibble(clean[i + 1])
        out[i / 2] = UInt8((hi << 4) | lo)
        i += 2
    }
    out
}

private func hexNibble(ch: Byte): UInt8 {
    if (ch >= b'0' && ch <= b'9') {
        return UInt8(ch - b'0')
    }

    let lower = if (ch >= b'A' && ch <= b'F') {
        ch + 32
    } else {
        ch
    }

    if (lower >= b'a' && lower <= b'f') {
        return UInt8(lower - b'a' + 10)
    }
    throw CryptoException(ParseError, "invalid hex character")
}
