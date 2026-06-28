package jinguissl_core.crypto.sm3

/**
 * SM3 cryptographic hash function (GM/T 0004-2012).
 *
 * Computes a 256-bit (32-byte) hash of the input data.
 *
 * @param data Input bytes.
 * @return 32-byte SM3 digest.
 */
public func sm3(data: Array<Byte>): Array<Byte> {
    /* SM3 initial hash value (GM/T 0004-2012 §4.1) */
    let iv: Array<UInt32> = [
        UInt32(0x7380166F), UInt32(0x4914B2B9), UInt32(0x172442D7), UInt32(0xDA8A0600),
        UInt32(0xA96F30BC), UInt32(0x163138AA), UInt32(0xE38DEE4D), UInt32(0xB0FB0E4E)
    ]

    let blockSize: Int64 = 64

    /* Padding (same as SHA-256 style): append 0x80, then zeros, then 64-bit length in bits */
    let originalSizeBits = UInt64(data.size) * 8

    var paddedSize = data.size + 1  /* at least one byte for 0x80 */
    while ((paddedSize % blockSize) != 56) {
        paddedSize += 1
    }
    paddedSize += 8  /* 8 bytes for length */

    var padded = Array<Byte>(paddedSize, repeat: UInt8(0))
    /* Copy original data */
    var i = 0
    while (i < data.size) {
        padded[i] = data[i]
        i += 1
    }
    /* Append 0x80 */
    padded[i] = UInt8(0x80)
    /* Zeros already in place from initialization */

    /* Append 64-bit big-endian length */
    padded[paddedSize - 8] = UInt8((originalSizeBits >> 56) & 0xFF)
    padded[paddedSize - 7] = UInt8((originalSizeBits >> 48) & 0xFF)
    padded[paddedSize - 6] = UInt8((originalSizeBits >> 40) & 0xFF)
    padded[paddedSize - 5] = UInt8((originalSizeBits >> 32) & 0xFF)
    padded[paddedSize - 4] = UInt8((originalSizeBits >> 24) & 0xFF)
    padded[paddedSize - 3] = UInt8((originalSizeBits >> 16) & 0xFF)
    padded[paddedSize - 2] = UInt8((originalSizeBits >> 8) & 0xFF)
    padded[paddedSize - 1] = UInt8(originalSizeBits & 0xFF)

    /* Process blocks */
    var state = iv.clone()
    let blocks = paddedSize / blockSize
    var offset: Int64 = 0
    i = 0
    while (i < blocks) {
        /* Extract one 64-byte block */
        var block = Array<Byte>(64, repeat: UInt8(0))
        var j = 0
        while (j < 64) {
            block[j] = padded[offset + j]
            j += 1
        }
        sm3Compress(state, block)
        offset += blockSize
        i += 1
    }

    /* Output: 8 x uint32 in big-endian */
    var result = Array<Byte>(32, repeat: UInt8(0))
    i = 0
    while (i < 8) {
        result[i * 4]     = UInt8((state[i] >> 24) & 0xFF)
        result[i * 4 + 1] = UInt8((state[i] >> 16) & 0xFF)
        result[i * 4 + 2] = UInt8((state[i] >> 8) & 0xFF)
        result[i * 4 + 3] = UInt8(state[i] & 0xFF)
        i += 1
    }
    result
}

/* ─── SM3 compression helpers (private) ─── */

private func rotl32(v: UInt32, bits: Int64): UInt32 {
    let n = bits & 31
    (v << UInt32(n)) | (v >> UInt32((32 - n) & 31))
}

private func P0(x: UInt32): UInt32 {
    x ^ rotl32(x, 9) ^ rotl32(x, 17)
}

private func P1(x: UInt32): UInt32 {
    x ^ rotl32(x, 15) ^ rotl32(x, 23)
}

private func FF0(x: UInt32, y: UInt32, z: UInt32): UInt32 {
    x ^ y ^ z
}

private func FF1(x: UInt32, y: UInt32, z: UInt32): UInt32 {
    (x & y) | (x & z) | (y & z)
}

private func GG0(x: UInt32, y: UInt32, z: UInt32): UInt32 {
    x ^ y ^ z
}

private func GG1(x: UInt32, y: UInt32, z: UInt32): UInt32 {
    (x & y) | ((UInt32(0xFFFFFFFF) ^ x) & z)
}

/* Wrapping 32-bit addition (mod 2^32, matching SM3 spec) */
private func add32(a: UInt32, b: UInt32): UInt32 {
    UInt32((UInt64(a) + UInt64(b)) & UInt64(0xFFFF_FFFF))
}

private func add32(a: UInt32, b: UInt32, c: UInt32): UInt32 {
    UInt32((UInt64(a) + UInt64(b) + UInt64(c)) & UInt64(0xFFFF_FFFF))
}
private func sm3Compress(state: Array<UInt32>, block: Array<Byte>): Unit {
    /* Message expansion: W[0..15] from block, W[16..67] derived */
    var w = Array<UInt32>(68, repeat: UInt32(0))

    var i = 0
    while (i < 16) {
        w[i] = (UInt32(block[i * 4]) << 24) |
               (UInt32(block[i * 4 + 1]) << 16) |
               (UInt32(block[i * 4 + 2]) << 8) |
               UInt32(block[i * 4 + 3])
        i += 1
    }

    i = 16
    while (i < 68) {
        w[i] = P1(w[i - 16] ^ w[i - 9] ^ rotl32(w[i - 3], 15)) ^
               rotl32(w[i - 13], 7) ^
               w[i - 6]
        i += 1
    }

    /* Working variables */
    var a = state[0]
    var b = state[1]
    var c = state[2]
    var d = state[3]
    var e = state[4]
    var f = state[5]
    var g = state[6]
    var h = state[7]

    /* 64 rounds */
    i = 0
    while (i < 64) {
        /* Round constant: Tj rotated left by j */
        let Tj = if (i < 16) { UInt32(0x79CC4519) } else { UInt32(0x7A879D8A) }
        let Kj = rotl32(Tj, i)

        let a12 = rotl32(a, 12)
        let SS1 = rotl32(add32(add32(a12, e), Kj), 7)
        let SS2 = SS1 ^ a12

        let Wj = w[i]
        let Wi = w[i] ^ w[i + 4]

        let (FF, GG) = if (i < 16) { (FF0, GG0) } else { (FF1, GG1) }

        let TT1 = add32(add32(add32(FF(a, b, c), d), SS2), Wi)
        let TT2 = add32(add32(add32(GG(e, f, g), h), SS1), Wj)

        d = c
        c = rotl32(b, 9)
        b = a
        a = TT1

        h = g
        g = rotl32(f, 19)
        f = e
        e = P0(TT2)

        i += 1
    }

    /* Update state */
    state[0] ^= a
    state[1] ^= b
    state[2] ^= c
    state[3] ^= d
    state[4] ^= e
    state[5] ^= f
    state[6] ^= g
    state[7] ^= h
}
