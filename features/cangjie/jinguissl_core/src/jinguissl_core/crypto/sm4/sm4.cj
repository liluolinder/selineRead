package jinguissl_core.crypto.sm4

/**
 * SM4 block cipher (GM/T 0002-2012) — ECB mode.
 *
 * Encrypts or decrypts data with a 128-bit key. Input data size must be a multiple of 16.
 */

/**
 * Encrypt data with SM4 in ECB mode.
 *
 * @param key 16-byte (128-bit) secret key.
 * @param data Plaintext bytes; size must be a multiple of 16.
 * @return Ciphertext bytes, same length as input.
 * @throws Exception If key or data size is invalid.
 */
public func sm4Encrypt(key: Array<Byte>, data: Array<Byte>): Array<Byte> {
    if (key.size != 16) {
        throw Exception("SM4 key must be 16 bytes")
    }
    if ((data.size == 0) || ((data.size % 16) != 0)) {
        throw Exception("SM4 data size must be a non-zero multiple of 16")
    }

    let rk = sm4KeySchedule(key)
    let blocks = data.size / 16
    var result = Array<Byte>(data.size, repeat: UInt8(0))

    var i = 0
    while (i < blocks) {
        let offset = i * 16
        var block = Array<Byte>(16, repeat: UInt8(0))
        var j = 0
        while (j < 16) {
            block[j] = data[offset + j]
            j += 1
        }
        let enc = sm4CryptBlock(block, rk, true)
        j = 0
        while (j < 16) {
            result[offset + j] = enc[j]
            j += 1
        }
        i += 1
    }
    result
}

/**
 * Decrypt data with SM4 in ECB mode.
 *
 * @param key 16-byte (128-bit) secret key.
 * @param data Ciphertext bytes; size must be a multiple of 16.
 * @return Plaintext bytes, same length as input.
 * @throws Exception If key or data size is invalid.
 */
public func sm4Decrypt(key: Array<Byte>, data: Array<Byte>): Array<Byte> {
    if (key.size != 16) {
        throw Exception("SM4 key must be 16 bytes")
    }
    if ((data.size == 0) || ((data.size % 16) != 0)) {
        throw Exception("SM4 data size must be a non-zero multiple of 16")
    }

    let rk = sm4KeySchedule(key)
    let blocks = data.size / 16
    var result = Array<Byte>(data.size, repeat: UInt8(0))

    var i = 0
    while (i < blocks) {
        let offset = i * 16
        var block = Array<Byte>(16, repeat: UInt8(0))
        var j = 0
        while (j < 16) {
            block[j] = data[offset + j]
            j += 1
        }
        let dec = sm4CryptBlock(block, rk, false)
        j = 0
        while (j < 16) {
            result[offset + j] = dec[j]
            j += 1
        }
        i += 1
    }
    result
}

/* ─── SM4 constants ─── */

/* System parameter FK (GM/T 0002-2012 §7.3) */
private let FK: Array<UInt32> = [
    UInt32(0xA3B1BAC6), UInt32(0x56AA3350), UInt32(0x677D9197), UInt32(0xB27022DC)
]

/* Fixed parameter CK (GM/T 0002-2012 §7.3) */
private let CK: Array<UInt32> = [
    UInt32(0x00070E15), UInt32(0x1C232A31), UInt32(0x383F464D), UInt32(0x545B6269),
    UInt32(0x70777E85), UInt32(0x8C939AA1), UInt32(0xA8AFB6BD), UInt32(0xC4CBD2D9),
    UInt32(0xE0E7EEF5), UInt32(0xFC030A11), UInt32(0x181F262D), UInt32(0x343B4249),
    UInt32(0x50575E65), UInt32(0x6C737A81), UInt32(0x888F969D), UInt32(0xA4ABB2B9),
    UInt32(0xC0C7CED5), UInt32(0xDCE3EAF1), UInt32(0xF8FF060D), UInt32(0x141B2229),
    UInt32(0x30373E45), UInt32(0x4C535A61), UInt32(0x686F767D), UInt32(0x848B9299),
    UInt32(0xA0A7AEB5), UInt32(0xBCC3CAD1), UInt32(0xD8DFE6ED), UInt32(0xF4FB0209),
    UInt32(0x10171E25), UInt32(0x2C333A41), UInt32(0x484F565D), UInt32(0x646B7279)
]

/* SM4 S-box (GM/T 0002-2012 §6.2) */
private let SBOX: Array<UInt8> = [
    UInt8(0xD6), UInt8(0x90), UInt8(0xE9), UInt8(0xFE), UInt8(0xCC), UInt8(0xE1), UInt8(0x3D), UInt8(0xB7),
    UInt8(0x16), UInt8(0xB6), UInt8(0x14), UInt8(0xC2), UInt8(0x28), UInt8(0xFB), UInt8(0x2C), UInt8(0x05),
    UInt8(0x2B), UInt8(0x67), UInt8(0x9A), UInt8(0x76), UInt8(0x2A), UInt8(0xBE), UInt8(0x04), UInt8(0xC3),
    UInt8(0xAA), UInt8(0x44), UInt8(0x13), UInt8(0x26), UInt8(0x49), UInt8(0x86), UInt8(0x06), UInt8(0x99),
    UInt8(0x9C), UInt8(0x42), UInt8(0x50), UInt8(0xF4), UInt8(0x91), UInt8(0xEF), UInt8(0x98), UInt8(0x7A),
    UInt8(0x33), UInt8(0x54), UInt8(0x0B), UInt8(0x43), UInt8(0xED), UInt8(0xCF), UInt8(0xAC), UInt8(0x62),
    UInt8(0xE4), UInt8(0xB3), UInt8(0x1C), UInt8(0xA9), UInt8(0xC9), UInt8(0x08), UInt8(0xE8), UInt8(0x95),
    UInt8(0x80), UInt8(0xDF), UInt8(0x94), UInt8(0xFA), UInt8(0x75), UInt8(0x8F), UInt8(0x3F), UInt8(0xA6),
    UInt8(0x47), UInt8(0x07), UInt8(0xA7), UInt8(0xFC), UInt8(0xF3), UInt8(0x73), UInt8(0x17), UInt8(0xBA),
    UInt8(0x83), UInt8(0x59), UInt8(0x3C), UInt8(0x19), UInt8(0xE6), UInt8(0x85), UInt8(0x4F), UInt8(0xA8),
    UInt8(0x68), UInt8(0x6B), UInt8(0x81), UInt8(0xB2), UInt8(0x71), UInt8(0x64), UInt8(0xDA), UInt8(0x8B),
    UInt8(0xF8), UInt8(0xEB), UInt8(0x0F), UInt8(0x4B), UInt8(0x70), UInt8(0x56), UInt8(0x9D), UInt8(0x35),
    UInt8(0x1E), UInt8(0x24), UInt8(0x0E), UInt8(0x5E), UInt8(0x63), UInt8(0x58), UInt8(0xD1), UInt8(0xA2),
    UInt8(0x25), UInt8(0x22), UInt8(0x7C), UInt8(0x3B), UInt8(0x01), UInt8(0x21), UInt8(0x78), UInt8(0x87),
    UInt8(0xD4), UInt8(0x00), UInt8(0x46), UInt8(0x57), UInt8(0x9F), UInt8(0xD3), UInt8(0x27), UInt8(0x52),
    UInt8(0x4C), UInt8(0x36), UInt8(0x02), UInt8(0xE7), UInt8(0xA0), UInt8(0xC4), UInt8(0xC8), UInt8(0x9E),
    UInt8(0xEA), UInt8(0xBF), UInt8(0x8A), UInt8(0xD2), UInt8(0x40), UInt8(0xC7), UInt8(0x38), UInt8(0xB5),
    UInt8(0xA3), UInt8(0xF7), UInt8(0xF2), UInt8(0xCE), UInt8(0xF9), UInt8(0x61), UInt8(0x15), UInt8(0xA1),
    UInt8(0xE0), UInt8(0xAE), UInt8(0x5D), UInt8(0xA4), UInt8(0x9B), UInt8(0x34), UInt8(0x1A), UInt8(0x55),
    UInt8(0xAD), UInt8(0x93), UInt8(0x32), UInt8(0x30), UInt8(0xF5), UInt8(0x8C), UInt8(0xB1), UInt8(0xE3),
    UInt8(0x1D), UInt8(0xF6), UInt8(0xE2), UInt8(0x2E), UInt8(0x82), UInt8(0x66), UInt8(0xCA), UInt8(0x60),
    UInt8(0xC0), UInt8(0x29), UInt8(0x23), UInt8(0xAB), UInt8(0x0D), UInt8(0x53), UInt8(0x4E), UInt8(0x6F),
    UInt8(0xD5), UInt8(0xDB), UInt8(0x37), UInt8(0x45), UInt8(0xDE), UInt8(0xFD), UInt8(0x8E), UInt8(0x2F),
    UInt8(0x03), UInt8(0xFF), UInt8(0x6A), UInt8(0x72), UInt8(0x6D), UInt8(0x6C), UInt8(0x5B), UInt8(0x51),
    UInt8(0x8D), UInt8(0x1B), UInt8(0xAF), UInt8(0x92), UInt8(0xBB), UInt8(0xDD), UInt8(0xBC), UInt8(0x7F),
    UInt8(0x11), UInt8(0xD9), UInt8(0x5C), UInt8(0x41), UInt8(0x1F), UInt8(0x10), UInt8(0x5A), UInt8(0xD8),
    UInt8(0x0A), UInt8(0xC1), UInt8(0x31), UInt8(0x88), UInt8(0xA5), UInt8(0xCD), UInt8(0x7B), UInt8(0xBD),
    UInt8(0x2D), UInt8(0x74), UInt8(0xD0), UInt8(0x12), UInt8(0xB8), UInt8(0xE5), UInt8(0xB4), UInt8(0xB0),
    UInt8(0x89), UInt8(0x69), UInt8(0x97), UInt8(0x4A), UInt8(0x0C), UInt8(0x96), UInt8(0x77), UInt8(0x7E),
    UInt8(0x65), UInt8(0xB9), UInt8(0xF1), UInt8(0x09), UInt8(0xC5), UInt8(0x6E), UInt8(0xC6), UInt8(0x84),
    UInt8(0x18), UInt8(0xF0), UInt8(0x7D), UInt8(0xEC), UInt8(0x3A), UInt8(0xDC), UInt8(0x4D), UInt8(0x20),
    UInt8(0x79), UInt8(0xEE), UInt8(0x5F), UInt8(0x3E), UInt8(0xD7), UInt8(0xCB), UInt8(0x39), UInt8(0x48)
]

/* ─── Private helpers ─── */

private func rotl32(v: UInt32, bits: Int64): UInt32 {
    let n = bits & 31
    (v << UInt32(n)) | (v >> UInt32((32 - n) & 31))
}

/**
 * S-box substitution on a 32-bit word.
 * Each byte is replaced via the SM4 S-box.
 */
private func sm4SubWord(x: UInt32): UInt32 {
    let b0 = UInt32(SBOX[Int64((x >> 24) & 0xFF)])
    let b1 = UInt32(SBOX[Int64((x >> 16) & 0xFF)])
    let b2 = UInt32(SBOX[Int64((x >> 8) & 0xFF)])
    let b3 = UInt32(SBOX[Int64(x & 0xFF)])
    (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

/**
 * Linear transform L for encryption rounds.
 * L(B) = B ^ (B <<< 2) ^ (B <<< 10) ^ (B <<< 18) ^ (B <<< 24)
 */
private func sm4L(x: UInt32): UInt32 {
    x ^ rotl32(x, 2) ^ rotl32(x, 10) ^ rotl32(x, 18) ^ rotl32(x, 24)
}

/**
 * Linear transform L' for key schedule.
 * L'(B) = B ^ (B <<< 13) ^ (B <<< 23)
 */
private func sm4LPrime(x: UInt32): UInt32 {
    x ^ rotl32(x, 13) ^ rotl32(x, 23)
}

/**
 * SM4 key schedule: generates 32 round keys from a 128-bit key.
 */
private func sm4KeySchedule(key: Array<Byte>): Array<UInt32> {
    var rk = Array<UInt32>(32, repeat: UInt32(0))

    /* MK XOR FK */
    let k0 = GET_UINT32_BE(key, 0) ^ FK[0]
    let k1 = GET_UINT32_BE(key, 4) ^ FK[1]
    let k2 = GET_UINT32_BE(key, 8) ^ FK[2]
    let k3 = GET_UINT32_BE(key, 12) ^ FK[3]

    var K = Array<UInt32>(36, repeat: UInt32(0))
    K[0] = k0
    K[1] = k1
    K[2] = k2
    K[3] = k3

    var i = 0
    while (i < 32) {
        let t = K[i + 1] ^ K[i + 2] ^ K[i + 3] ^ CK[i]
        K[i + 4] = K[i] ^ sm4LPrime(sm4SubWord(t))
        rk[i] = K[i + 4]
        i += 1
    }
    rk
}

/**
 * SM4 round transformation.
 * T(x) = L(S-box_substitution(x))
 */
private func sm4T(x: UInt32): UInt32 {
    sm4L(sm4SubWord(x))
}

/**
 * Encrypt or decrypt one 16-byte block.
 */
private func sm4CryptBlock(block: Array<Byte>, rk: Array<UInt32>, enc: Bool): Array<Byte> {
    var x0 = GET_UINT32_BE(block, 0)
    var x1 = GET_UINT32_BE(block, 4)
    var x2 = GET_UINT32_BE(block, 8)
    var x3 = GET_UINT32_BE(block, 12)

    if (enc) {
        /* Encryption: rk[0..31] */
        var i = 0
        while (i < 32) {
            let t = x1 ^ x2 ^ x3 ^ rk[i]
            let xi = x0 ^ sm4T(t)
            x0 = x1
            x1 = x2
            x2 = x3
            x3 = xi
            i += 1
        }
    } else {
        /* Decryption: rk[31..0] (reverse order) */
        var i = 0
        while (i < 32) {
            let t = x1 ^ x2 ^ x3 ^ rk[31 - i]
            let xi = x0 ^ sm4T(t)
            x0 = x1
            x1 = x2
            x2 = x3
            x3 = xi
            i += 1
        }
    }

    /* Reverse order for output: (X35, X34, X33, X32) */
    var result = Array<Byte>(16, repeat: UInt8(0))
    PUT_UINT32_BE(x3, result, 0)
    PUT_UINT32_BE(x2, result, 4)
    PUT_UINT32_BE(x1, result, 8)
    PUT_UINT32_BE(x0, result, 12)
    result
}

/* ─── Byte-level big-endian helpers ─── */

private func GET_UINT32_BE(bytes: Array<Byte>, offset: Int64): UInt32 {
    (UInt32(bytes[offset]) << 24) |
    (UInt32(bytes[offset + 1]) << 16) |
    (UInt32(bytes[offset + 2]) << 8) |
    UInt32(bytes[offset + 3])
}

private func PUT_UINT32_BE(value: UInt32, bytes: Array<Byte>, offset: Int64): Unit {
    bytes[offset]     = UInt8((value >> 24) & 0xFF)
    bytes[offset + 1] = UInt8((value >> 16) & 0xFF)
    bytes[offset + 2] = UInt8((value >> 8) & 0xFF)
    bytes[offset + 3] = UInt8(value & 0xFF)
}
