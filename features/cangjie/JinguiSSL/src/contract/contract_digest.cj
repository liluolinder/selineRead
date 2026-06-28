package jinguissl.contract

import jinguissl_core.crypto.digest.{hash, md5, sha1, sha256, sha384, sha512, bytesToHexLower, hmac, hkdfExtract, hkdfExpand, hkdf}
import jinguissl_core.crypto.digest.HashAlgorithm as CoreHashAlgorithm

/**
 * HashAlgorithm — contract-side type alias for core's digest.HashAlgorithm.
 *
 * This type is structurally identical to the core enum. Consumers may pass
 * values via contractHashAlgorithm constants without importing core.
 */
public type HashAlgorithm = CoreHashAlgorithm

/**
 * contractHash — generic hash dispatcher.
 * Delegates to core's hash().
 */
public func contractHash(algorithm: HashAlgorithm, data: Array<Byte>): Array<Byte> {
    hash(algorithm, data)
}

/**
 * contractMd5 — MD5 hash.
 * @deprecated MD5 is cryptographically broken. Only for legacy compatibility.
 */
public func contractMd5(data: Array<Byte>): Array<Byte> {
    md5(data)
}

/**
 * contractSha1 — SHA-1 hash.
 * @deprecated SHA-1 is cryptographically broken. Use SHA-256 or higher.
 */
public func contractSha1(data: Array<Byte>): Array<Byte> {
    sha1(data)
}

/**
 * contractSha256 — SHA-256 hash.
 */
public func contractSha256(data: Array<Byte>): Array<Byte> {
    sha256(data)
}

/**
 * contractSha384 — SHA-384 hash.
 */
public func contractSha384(data: Array<Byte>): Array<Byte> {
    sha384(data)
}

/**
 * contractSha512 — SHA-512 hash.
 */
public func contractSha512(data: Array<Byte>): Array<Byte> {
    sha512(data)
}

/**
 * contractBytesToHexLower — byte array to lowercase hex string.
 */
public func contractBytesToHexLower(bytes: Array<Byte>): String {
    bytesToHexLower(bytes)
}

/**
 * contractHmac — HMAC with given hash algorithm.
 */
public func contractHmac(algorithm: HashAlgorithm, key: Array<Byte>, data: Array<Byte>): Array<Byte> {
    hmac(algorithm, key, data)
}

/**
 * contractHkdfExtract — HKDF extract step.
 */
public func contractHkdfExtract(
    algorithm: HashAlgorithm,
    salt: Array<Byte>,
    ikm: Array<Byte>
): Array<Byte> {
    hkdfExtract(algorithm, salt, ikm)
}

/**
 * contractHkdfExpand — HKDF expand step.
 */
public func contractHkdfExpand(
    algorithm: HashAlgorithm,
    prk: Array<Byte>,
    info: Array<Byte>,
    outputLen: Int64
): Array<Byte> {
    hkdfExpand(algorithm, prk, info, outputLen)
}

/**
 * contractHkdf — full HKDF (extract then expand).
 */
public func contractHkdf(
    algorithm: HashAlgorithm,
    ikm: Array<Byte>,
    info: Array<Byte>,
    outputLen: Int64,
    salt!: Array<Byte> = []
): Array<Byte> {
    hkdf(algorithm, ikm, info, outputLen, salt: salt)
}
