package jinguissl_core.crypto.digest

import std.collection.ArrayList
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.utils.{bytesToUInt32BE, bytesToUInt32LE, secureCopyInto, uInt32ToBytesBE, uInt32ToBytesLE}

public enum HashAlgorithm <: Equatable<HashAlgorithm> & ToString {
    /** @deprecated MD5 is cryptographically broken. Only for legacy compatibility. */
    | MD5
    /** @deprecated SHA-1 is cryptographically broken. Use SHA-256 or higher. */
    | SHA1
    | SHA256
    | SHA384
    | SHA512

    public operator func ==(right: HashAlgorithm): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: HashAlgorithm): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case MD5 => 0
            case SHA1 => 1
            case SHA256 => 2
            case SHA384 => 3
            case SHA512 => 4
        }
    }

    public func toString(): String {
        match (this) {
            case MD5 => "MD5"
            case SHA1 => "SHA-1"
            case SHA256 => "SHA-256"
            case SHA384 => "SHA-384"
            case SHA512 => "SHA-512"
        }
    }
}

public func hash(algorithm: HashAlgorithm, data: Array<Byte>): Array<Byte> {
    match (algorithm) {
        case MD5 => md5(data)
        case SHA1 => sha1(data)
        case SHA256 => sha256(data)
        case SHA384 => sha384(data)
        case SHA512 => sha512(data)
    }
}

/** @deprecated MD5 is cryptographically broken. Only for legacy compatibility. */
@OverflowWrapping
public func md5(data: Array<Byte>): Array<Byte> {
    let message = padForMd5(data)

    var a0 = UInt32(0x67452301)
    var b0 = UInt32(0xefcdab89)
    var c0 = UInt32(0x98badcfe)
    var d0 = UInt32(0x10325476)

    var offset = 0
    while (offset < message.size) {
        let m = Array<UInt32>(16, repeat: UInt32(0))
        var i = 0
        while (i < 16) {
            m[i] = bytesToUInt32LE(message, offset: offset + i * 4)
            i += 1
        }

        var a = a0
        var b = b0
        var c = c0
        var d = d0

        i = 0
        while (i < 64) {
            let f: UInt32
            let g: Int64
            if (i < 16) {
                f = (b & c) | (not32(b) & d)
                g = i
            } else if (i < 32) {
                f = (d & b) | (not32(d) & c)
                g = (5 * i + 1) % 16
            } else if (i < 48) {
                f = b ^ c ^ d
                g = (3 * i + 5) % 16
            } else {
                f = c ^ (b | not32(d))
                g = (7 * i) % 16
            }

            let sum = a + f + MD5_K[i] + m[g]
            let rotated = rotl32(sum, MD5_S[i])

            let nextD = c
            c = b
            b = b + rotated
            a = d
            d = nextD

            i += 1
        }

        a0 = a0 + a
        b0 = b0 + b
        c0 = c0 + c
        d0 = d0 + d

        offset += 64
    }

    let out = ArrayList<Byte>()
    appendBytes(out, uInt32ToBytesLE(a0))
    appendBytes(out, uInt32ToBytesLE(b0))
    appendBytes(out, uInt32ToBytesLE(c0))
    appendBytes(out, uInt32ToBytesLE(d0))
    out.toArray()
}

@OverflowWrapping
/** @deprecated SHA-1 is cryptographically broken. Use SHA-256 or higher. */
public func sha1(data: Array<Byte>): Array<Byte> {
    let message = padForSha(data, 64)

    var h0 = UInt32(0x67452301)
    var h1 = UInt32(0xefcdab89)
    var h2 = UInt32(0x98badcfe)
    var h3 = UInt32(0x10325476)
    var h4 = UInt32(0xc3d2e1f0)

    var offset = 0
    while (offset < message.size) {
        let w = Array<UInt32>(80, repeat: UInt32(0))
        var i = 0
        while (i < 16) {
            w[i] = bytesToUInt32BE(message, offset: offset + i * 4)
            i += 1
        }

        while (i < 80) {
            w[i] = rotl32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1)
            i += 1
        }

        var a = h0
        var b = h1
        var c = h2
        var d = h3
        var e = h4

        i = 0
        while (i < 80) {
            let f: UInt32
            let k: UInt32
            if (i < 20) {
                f = (b & c) | (not32(b) & d)
                k = UInt32(0x5a827999)
            } else if (i < 40) {
                f = b ^ c ^ d
                k = UInt32(0x6ed9eba1)
            } else if (i < 60) {
                f = (b & c) | (b & d) | (c & d)
                k = UInt32(0x8f1bbcdc)
            } else {
                f = b ^ c ^ d
                k = UInt32(0xca62c1d6)
            }

            let temp = rotl32(a, 5) + f + e + k + w[i]
            e = d
            d = c
            c = rotl32(b, 30)
            b = a
            a = temp
            i += 1
        }

        h0 = h0 + a
        h1 = h1 + b
        h2 = h2 + c
        h3 = h3 + d
        h4 = h4 + e

        offset += 64
    }

    let out = ArrayList<Byte>()
    appendBytes(out, uInt32ToBytesBE(h0))
    appendBytes(out, uInt32ToBytesBE(h1))
    appendBytes(out, uInt32ToBytesBE(h2))
    appendBytes(out, uInt32ToBytesBE(h3))
    appendBytes(out, uInt32ToBytesBE(h4))
    out.toArray()
}

@OverflowWrapping
public func sha256(data: Array<Byte>): Array<Byte> {
    let message = padForSha(data, 64)

    let h = SHA256_IV.clone()

    var offset = 0
    while (offset < message.size) {
        let w = Array<UInt32>(64, repeat: UInt32(0))

        var i = 0
        while (i < 16) {
            w[i] = bytesToUInt32BE(message, offset: offset + i * 4)
            i += 1
        }

        while (i < 64) {
            let s0 = rotr32(w[i - 15], 7) ^ rotr32(w[i - 15], 18) ^ (w[i - 15] >> 3)
            let s1 = rotr32(w[i - 2], 17) ^ rotr32(w[i - 2], 19) ^ (w[i - 2] >> 10)
            w[i] = w[i - 16] + s0 + w[i - 7] + s1
            i += 1
        }

        var a = h[0]
        var b = h[1]
        var c = h[2]
        var d = h[3]
        var e = h[4]
        var f = h[5]
        var g = h[6]
        var x = h[7]

        i = 0
        while (i < 64) {
            let s1 = rotr32(e, 6) ^ rotr32(e, 11) ^ rotr32(e, 25)
            let ch = (e & f) ^ (not32(e) & g)
            let temp1 = x + s1 + ch + SHA256_K[i] + w[i]
            let s0 = rotr32(a, 2) ^ rotr32(a, 13) ^ rotr32(a, 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = s0 + maj

            x = g
            g = f
            f = e
            e = d + temp1
            d = c
            c = b
            b = a
            a = temp1 + temp2
            i += 1
        }

        h[0] = h[0] + a
        h[1] = h[1] + b
        h[2] = h[2] + c
        h[3] = h[3] + d
        h[4] = h[4] + e
        h[5] = h[5] + f
        h[6] = h[6] + g
        h[7] = h[7] + x

        offset += 64
    }

    let out = ArrayList<Byte>()
    for (v in h) {
        appendBytes(out, uInt32ToBytesBE(v))
    }
    out.toArray()
}

public func sha384(data: Array<Byte>): Array<Byte> {
    let full = sha512WithIV(data, SHA384_IV)
    full[..48]
}

public func sha512(data: Array<Byte>): Array<Byte> {
    sha512WithIV(data, SHA512_IV)
}

public func bytesToHexLower(bytes: Array<Byte>): String {
    let digits: Array<String> = [
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9", "a", "b", "c", "d", "e", "f"
    ]

    var out = ""
    for (b in bytes) {
        let ub = UInt8(b)
        out += digits[Int64((ub >> 4) & UInt8(0x0f))]
        out += digits[Int64(ub & UInt8(0x0f))]
    }
    out
}

@OverflowWrapping
private func sha512WithIV(data: Array<Byte>, initial: Array<UInt64>): Array<Byte> {
    let message = padForSha(data, 128)

    let h = initial.clone()

    var offset = 0
    while (offset < message.size) {
        let w = Array<UInt64>(80, repeat: UInt64(0))

        var i = 0
        while (i < 16) {
            w[i] = bytesToUInt64BE(message, offset: offset + i * 8)
            i += 1
        }

        while (i < 80) {
            let s0 = rotr64(w[i - 15], 1) ^ rotr64(w[i - 15], 8) ^ (w[i - 15] >> 7)
            let s1 = rotr64(w[i - 2], 19) ^ rotr64(w[i - 2], 61) ^ (w[i - 2] >> 6)
            w[i] = w[i - 16] + s0 + w[i - 7] + s1
            i += 1
        }

        var a = h[0]
        var b = h[1]
        var c = h[2]
        var d = h[3]
        var e = h[4]
        var f = h[5]
        var g = h[6]
        var x = h[7]

        i = 0
        while (i < 80) {
            let s1 = rotr64(e, 14) ^ rotr64(e, 18) ^ rotr64(e, 41)
            let ch = (e & f) ^ (not64(e) & g)
            let temp1 = x + s1 + ch + SHA512_K[i] + w[i]
            let s0 = rotr64(a, 28) ^ rotr64(a, 34) ^ rotr64(a, 39)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = s0 + maj

            x = g
            g = f
            f = e
            e = d + temp1
            d = c
            c = b
            b = a
            a = temp1 + temp2
            i += 1
        }

        h[0] = h[0] + a
        h[1] = h[1] + b
        h[2] = h[2] + c
        h[3] = h[3] + d
        h[4] = h[4] + e
        h[5] = h[5] + f
        h[6] = h[6] + g
        h[7] = h[7] + x

        offset += 128
    }

    let out = ArrayList<Byte>()
    for (v in h) {
        appendBytes(out, uInt64ToBytesBE(v))
    }
    out.toArray()
}

private func concat(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    secureCopyInto(left, out)
    secureCopyInto(right, out, dstOffset: left.size)
    out
}

private func appendBytes(list: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    for (b in bytes) {
        list.add(b)
    }
}

private func digestLength(algorithm: HashAlgorithm): Int64 {
    match (algorithm) {
        case MD5 => 16
        case SHA1 => 20
        case SHA256 => 32
        case SHA384 => 48
        case SHA512 => 64
    }
}

private func padForMd5(data: Array<Byte>): Array<Byte> {
    let list = ArrayList<Byte>()
    appendBytes(list, data)
    list.add(UInt8(0x80))

    while ((list.size + 8) % 64 != 0) {
        list.add(0)
    }

    let bitLen = UInt64(data.size) * UInt64(8)
    var i = 0
    while (i < 8) {
        list.add(UInt8((bitLen >> (i * 8)) & UInt64(0xff)))
        i += 1
    }

    list.toArray()
}

private func padForSha(data: Array<Byte>, blockSize: Int64): Array<Byte> {
    let list = ArrayList<Byte>()
    appendBytes(list, data)
    list.add(UInt8(0x80))

    while ((list.size + 16) % blockSize != 0) {
        list.add(0)
    }

    // Stage-2 baseline: up to 2^64-1 bits input length.
    let bitLenHigh = UInt64(0)
    let bitLenLow = UInt64(data.size) * UInt64(8)

    appendBytes(list, uInt64ToBytesBE(bitLenHigh))
    appendBytes(list, uInt64ToBytesBE(bitLenLow))

    list.toArray()
}

private func bytesToUInt64BE(bytes: Array<Byte>, offset!: Int64 = 0): UInt64 {
    if (offset < 0 || offset + 8 > bytes.size) {
        throw CryptoException(OutOfBounds, "bytesToUInt64BE out of bounds")
    }

    var v = UInt64(0)
    var i = 0
    while (i < 8) {
        v = (v << 8) | UInt64(UInt8(bytes[offset + i]))
        i += 1
    }
    v
}

private func uInt64ToBytesBE(value: UInt64): Array<Byte> {
    [
        UInt8((value >> 56) & UInt64(0xff)),
        UInt8((value >> 48) & UInt64(0xff)),
        UInt8((value >> 40) & UInt64(0xff)),
        UInt8((value >> 32) & UInt64(0xff)),
        UInt8((value >> 24) & UInt64(0xff)),
        UInt8((value >> 16) & UInt64(0xff)),
        UInt8((value >> 8) & UInt64(0xff)),
        UInt8(value & UInt64(0xff))
    ]
}

private func rotl32(v: UInt32, bits: Int64): UInt32 {
    let n = bits & 31
    if (n == 0) {
        return v
    }
    (v << n) | (v >> (32 - n))
}

private func rotr32(v: UInt32, bits: Int64): UInt32 {
    let n = bits & 31
    if (n == 0) {
        return v
    }
    (v >> n) | (v << (32 - n))
}

private func rotr64(v: UInt64, bits: Int64): UInt64 {
    let n = bits & 63
    if (n == 0) {
        return v
    }
    (v >> n) | (v << (64 - n))
}

private func not32(v: UInt32): UInt32 {
    v ^ UInt32(0xffff_ffff)
}

private func not64(v: UInt64): UInt64 {
    v ^ u64Word(UInt32(0xffff_ffff), UInt32(0xffff_ffff))
}

private func u64Word(hi: UInt32, lo: UInt32): UInt64 {
    (UInt64(hi) << 32) | UInt64(lo)
}

public func hmac(algorithm: HashAlgorithm, key: Array<Byte>, data: Array<Byte>): Array<Byte> {
    let blockSize = match (algorithm) {
        case MD5 | SHA1 | SHA256 => 64
        case SHA384 | SHA512 => 128
    }

    var normalizedKey = if (key.size > blockSize) {
        hash(algorithm, key)
    } else {
        key.clone()
    }

    if (normalizedKey.size < blockSize) {
        let padded = Array<Byte>(blockSize, repeat: 0)
        secureCopyInto(normalizedKey, padded)
        normalizedKey = padded
    }

    let iPad = Array<Byte>(blockSize, repeat: 0)
    let oPad = Array<Byte>(blockSize, repeat: 0)

    var i = 0
    while (i < blockSize) {
        let b = UInt8(normalizedKey[i])
        iPad[i] = b ^ UInt8(0x36)
        oPad[i] = b ^ UInt8(0x5c)
        i += 1
    }

    let inner = hash(algorithm, concat(iPad, data))
    hash(algorithm, concat(oPad, inner))
}

public func hkdfExtract(
    algorithm: HashAlgorithm,
    salt: Array<Byte>,
    ikm: Array<Byte>
): Array<Byte> {
    let digestLen = digestLength(algorithm)
    let effectiveSalt = if (salt.size == 0) {
        Array<Byte>(digestLen, repeat: 0)
    } else {
        salt
    }
    hmac(algorithm, effectiveSalt, ikm)
}

/**
 * hkdfExpand.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func hkdfExpand(
    algorithm: HashAlgorithm,
    prk: Array<Byte>,
    info: Array<Byte>,
    outputLen: Int64
): Array<Byte> {
    if (outputLen < 0) {
        throw CryptoException(InvalidArgument, "HKDF output length must be >= 0")
    }
    if (outputLen == 0) {
        return []
    }
    if (prk.size == 0) {
        throw CryptoException(InvalidArgument, "HKDF PRK must not be empty")
    }

    let digestLen = digestLength(algorithm)
    let maxLen = digestLen * 255
    if (outputLen > maxLen) {
        throw CryptoException(OutOfBounds, "HKDF output length is too large")
    }

    let okm = ArrayList<Byte>()
    var previous = Array<Byte>(0, repeat: 0)
    var blockIndex: Int64 = 1

    while (okm.size < outputLen) {
        let indexByte = Array<Byte>(1, repeat: UInt8(blockIndex))
        let input = concat(concat(previous, info), indexByte)
        previous = hmac(algorithm, prk, input)

        let remaining = outputLen - okm.size
        let take = if (remaining < digestLen) {
            remaining
        } else {
            digestLen
        }
        var i: Int64 = 0
        while (i < take) {
            okm.add(previous[i])
            i += 1
        }
        blockIndex += 1
    }

    okm.toArray()
}

public func hkdf(
    algorithm: HashAlgorithm,
    ikm: Array<Byte>,
    info: Array<Byte>,
    outputLen: Int64,
    salt!: Array<Byte> = []
): Array<Byte> {
    let prk = hkdfExtract(algorithm, salt, ikm)
    hkdfExpand(algorithm, prk, info, outputLen)
}
