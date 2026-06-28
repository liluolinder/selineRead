package jinguissl_core.crypto.chacha20

import std.math.numeric.{BigInt}
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.utils.constantTimeEquals

public let CHACHA20_KEY_LEN: Int64 = 32
public let CHACHA20_NONCE_LEN: Int64 = 12
public let CHACHA20_BLOCK_LEN: Int64 = 64
public let POLY1305_KEY_LEN: Int64 = 32
public let POLY1305_TAG_LEN: Int64 = 16
public let CHACHA20_POLY1305_TAG_LEN: Int64 = POLY1305_TAG_LEN

private let CHACHA20_CONST_0: UInt32 = UInt32(0x6170_7865)
private let CHACHA20_CONST_1: UInt32 = UInt32(0x3320_646e)
private let CHACHA20_CONST_2: UInt32 = UInt32(0x7962_2d32)
private let CHACHA20_CONST_3: UInt32 = UInt32(0x6b20_6574)
private let CHACHA20_COUNTER_MAX: Int64 = 0xffff_ffff

public class Chacha20Poly1305Context {
    let _keyWords: Array<UInt32>

    public init(key: Array<Byte>) {
        this._keyWords = decodeKeyWords(key)
    }
}

public func chacha20Poly1305AlgorithmName(): String {
    "CHACHA20-POLY1305"
}

public func requireChacha20Poly1305Allowed(profile: FipsProfile): Unit {
    profile.requireAllowed(chacha20Poly1305AlgorithmName())
}

public func chacha20Poly1305NewContext(key: Array<Byte>): Chacha20Poly1305Context {
    Chacha20Poly1305Context(key)
}

public func chacha20Block(key: Array<Byte>, counter: Int64, nonce: Array<Byte>): Array<Byte> {
    let context = chacha20Poly1305NewContext(key)
    chacha20BlockWithContext(context, counter, nonce)
}

public func chacha20BlockWithContext(
    context: Chacha20Poly1305Context,
    counter: Int64,
    nonce: Array<Byte>
): Array<Byte> {
    requireNonce(nonce)
    let counterWord = parseCounter(counter)
    chacha20BlockWithKeyWords(context._keyWords, counterWord, nonce)
}

public func chacha20Xor(
    key: Array<Byte>,
    nonce: Array<Byte>,
    input: Array<Byte>,
    initialCounter!: Int64 = 0
): Array<Byte> {
    let context = chacha20Poly1305NewContext(key)
    chacha20XorWithContext(context, nonce, input, initialCounter: initialCounter)
}

/**
 * chacha20XorWithContext.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func chacha20XorWithContext(
    context: Chacha20Poly1305Context,
    nonce: Array<Byte>,
    input: Array<Byte>,
    initialCounter!: Int64 = 0
): Array<Byte> {
    requireNonce(nonce)
    var counter = initialCounter
    if (counter < 0 || counter > CHACHA20_COUNTER_MAX) {
        throw CryptoException(OutOfBounds, "ChaCha20 counter is out of uint32 range")
    }

    if (input.size == 0) {
        return []
    }

    let output = Array<Byte>(input.size, repeat: 0)
    var offset = 0
    while (offset < input.size) {
        let streamBlock = chacha20BlockWithKeyWords(context._keyWords, UInt32(counter), nonce)
        let take = minInt64(CHACHA20_BLOCK_LEN, input.size - offset)

        var i = 0
        while (i < take) {
            output[offset + i] = UInt8(input[offset + i]) ^ UInt8(streamBlock[i])
            i += 1
        }

        offset += take
        if (offset < input.size) {
            if (counter == CHACHA20_COUNTER_MAX) {
                throw CryptoException(OutOfBounds, "ChaCha20 counter overflow")
            }
            counter += 1
        }
    }

    output
}

public func poly1305Mac(key: Array<Byte>, message: Array<Byte>): Array<Byte> {
    requirePoly1305Key(key)

    let rBytes = key[..16].clone()
    clampPoly1305R(rBytes)
    let sBytes = key[16..32]

    let r = bigIntFromLittleEndian(rBytes)
    let s = bigIntFromLittleEndian(sBytes)
    let p = poly1305Prime()
    var acc = BigInt(0)

    var offset = 0
    while (offset < message.size) {
        let take = minInt64(16, message.size - offset)
        let block = Array<Byte>(take + 1, repeat: 0)

        var i = 0
        while (i < take) {
            block[i] = message[offset + i]
            i += 1
        }
        block[take] = UInt8(0x01)

        let n = bigIntFromLittleEndian(block)
        acc = ((acc + n) * r) % p
        offset += take
    }

    let tagValue = (acc + s) % poly1305TagModulus()
    bigIntToLittleEndian(tagValue, POLY1305_TAG_LEN)
}

public func chacha20Poly1305Encrypt(
    key: Array<Byte>,
    nonce: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = []
): (Array<Byte>, Array<Byte>) {
    let context = chacha20Poly1305NewContext(key)
    chacha20Poly1305EncryptWithContext(context, nonce, plaintext, aad: aad)
}

public func chacha20Poly1305EncryptWithContext(
    context: Chacha20Poly1305Context,
    nonce: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = []
): (Array<Byte>, Array<Byte>) {
    requireNonce(nonce)

    let oneTimeKey = chacha20BlockWithKeyWords(context._keyWords, UInt32(0), nonce)[..POLY1305_KEY_LEN]
    let ciphertext = chacha20XorWithContext(context, nonce, plaintext, initialCounter: 1)
    let macInput = buildAeadMacInput(aad, ciphertext)
    let tag = poly1305Mac(oneTimeKey, macInput)
    (ciphertext, tag)
}

public func chacha20Poly1305EncryptChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    nonce: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = []
): (Array<Byte>, Array<Byte>) {
    requireChacha20Poly1305Allowed(profile)
    chacha20Poly1305Encrypt(key, nonce, plaintext, aad: aad)
}

public func chacha20Poly1305EncryptWithContextChecked(
    profile: FipsProfile,
    context: Chacha20Poly1305Context,
    nonce: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = []
): (Array<Byte>, Array<Byte>) {
    requireChacha20Poly1305Allowed(profile)
    chacha20Poly1305EncryptWithContext(context, nonce, plaintext, aad: aad)
}

public func chacha20Poly1305Decrypt(
    key: Array<Byte>,
    nonce: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad!: Array<Byte> = []
): Array<Byte> {
    let context = chacha20Poly1305NewContext(key)
    chacha20Poly1305DecryptWithContext(context, nonce, ciphertext, tag, aad: aad)
}

/**
 * chacha20Poly1305DecryptWithContext.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func chacha20Poly1305DecryptWithContext(
    context: Chacha20Poly1305Context,
    nonce: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad!: Array<Byte> = []
): Array<Byte> {
    requireNonce(nonce)
    if (tag.size != CHACHA20_POLY1305_TAG_LEN) {
        throw CryptoException(InvalidArgument, "ChaCha20-Poly1305 tag must be 16 bytes")
    }

    let oneTimeKey = chacha20BlockWithKeyWords(context._keyWords, UInt32(0), nonce)[..POLY1305_KEY_LEN]
    let macInput = buildAeadMacInput(aad, ciphertext)
    let expectedTag = poly1305Mac(oneTimeKey, macInput)
    if (!constantTimeEquals(expectedTag, tag)) {
        throw CryptoException(InvalidArgument, "ChaCha20-Poly1305 tag mismatch")
    }

    chacha20XorWithContext(context, nonce, ciphertext, initialCounter: 1)
}

public func chacha20Poly1305DecryptChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    nonce: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad!: Array<Byte> = []
): Array<Byte> {
    requireChacha20Poly1305Allowed(profile)
    chacha20Poly1305Decrypt(key, nonce, ciphertext, tag, aad: aad)
}

public func chacha20Poly1305DecryptWithContextChecked(
    profile: FipsProfile,
    context: Chacha20Poly1305Context,
    nonce: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad!: Array<Byte> = []
): Array<Byte> {
    requireChacha20Poly1305Allowed(profile)
    chacha20Poly1305DecryptWithContext(context, nonce, ciphertext, tag, aad: aad)
}

private func decodeKeyWords(key: Array<Byte>): Array<UInt32> {
    if (key.size != CHACHA20_KEY_LEN) {
        throw CryptoException(InvalidArgument, "ChaCha20 key must be 32 bytes")
    }

    let words = Array<UInt32>(8, repeat: UInt32(0))
    var i = 0
    while (i < 8) {
        words[i] = decodeUInt32LE(key, i * 4)
        i += 1
    }
    words
}

private func requireNonce(nonce: Array<Byte>): Unit {
    if (nonce.size != CHACHA20_NONCE_LEN) {
        throw CryptoException(InvalidArgument, "ChaCha20 nonce must be 12 bytes")
    }
}

private func requirePoly1305Key(key: Array<Byte>): Unit {
    if (key.size != POLY1305_KEY_LEN) {
        throw CryptoException(InvalidArgument, "Poly1305 key must be 32 bytes")
    }
}

private func parseCounter(counter: Int64): UInt32 {
    if (counter < 0 || counter > CHACHA20_COUNTER_MAX) {
        throw CryptoException(OutOfBounds, "ChaCha20 counter is out of uint32 range")
    }
    UInt32(counter)
}

@OverflowWrapping
private func chacha20BlockWithKeyWords(
    keyWords: Array<UInt32>,
    counter: UInt32,
    nonce: Array<Byte>
): Array<Byte> {
    let state = Array<UInt32>(16, repeat: UInt32(0))
    state[0] = CHACHA20_CONST_0
    state[1] = CHACHA20_CONST_1
    state[2] = CHACHA20_CONST_2
    state[3] = CHACHA20_CONST_3

    var i = 0
    while (i < 8) {
        state[4 + i] = keyWords[i]
        i += 1
    }

    state[12] = counter
    state[13] = decodeUInt32LE(nonce, 0)
    state[14] = decodeUInt32LE(nonce, 4)
    state[15] = decodeUInt32LE(nonce, 8)

    let working = state.clone()
    var round = 0
    while (round < 10) {
        chachaQuarterRound(working, 0, 4, 8, 12)
        chachaQuarterRound(working, 1, 5, 9, 13)
        chachaQuarterRound(working, 2, 6, 10, 14)
        chachaQuarterRound(working, 3, 7, 11, 15)

        chachaQuarterRound(working, 0, 5, 10, 15)
        chachaQuarterRound(working, 1, 6, 11, 12)
        chachaQuarterRound(working, 2, 7, 8, 13)
        chachaQuarterRound(working, 3, 4, 9, 14)
        round += 1
    }

    let out = Array<Byte>(CHACHA20_BLOCK_LEN, repeat: 0)
    i = 0
    while (i < 16) {
        encodeUInt32LE(out, i * 4, working[i] + state[i])
        i += 1
    }
    out
}

@OverflowWrapping
private func chachaQuarterRound(state: Array<UInt32>, a: Int64, b: Int64, c: Int64, d: Int64): Unit {
    state[a] = state[a] + state[b]
    state[d] = rotl32(state[d] ^ state[a], 16)

    state[c] = state[c] + state[d]
    state[b] = rotl32(state[b] ^ state[c], 12)

    state[a] = state[a] + state[b]
    state[d] = rotl32(state[d] ^ state[a], 8)

    state[c] = state[c] + state[d]
    state[b] = rotl32(state[b] ^ state[c], 7)
}

private func rotl32(value: UInt32, bits: Int64): UInt32 {
    let n = bits & 31
    if (n == 0) {
        return value
    }
    (value << n) | (value >> (32 - n))
}

private func decodeUInt32LE(bytes: Array<Byte>, offset: Int64): UInt32 {
    if (offset < 0 || offset + 4 > bytes.size) {
        throw CryptoException(OutOfBounds, "uint32 decode is out of bounds")
    }

    UInt32(UInt8(bytes[offset])) |
        (UInt32(UInt8(bytes[offset + 1])) << 8) |
        (UInt32(UInt8(bytes[offset + 2])) << 16) |
        (UInt32(UInt8(bytes[offset + 3])) << 24)
}

private func encodeUInt32LE(out: Array<Byte>, offset: Int64, value: UInt32): Unit {
    if (offset < 0 || offset + 4 > out.size) {
        throw CryptoException(OutOfBounds, "uint32 encode is out of bounds")
    }

    out[offset] = UInt8(value & UInt32(0xff))
    out[offset + 1] = UInt8((value >> 8) & UInt32(0xff))
    out[offset + 2] = UInt8((value >> 16) & UInt32(0xff))
    out[offset + 3] = UInt8((value >> 24) & UInt32(0xff))
}

private func buildAeadMacInput(aad: Array<Byte>, ciphertext: Array<Byte>): Array<Byte> {
    let aadPadded = roundUp16(aad.size)
    let ctPadded = roundUp16(ciphertext.size)
    let total = aadPadded + ctPadded + 16

    let out = Array<Byte>(total, repeat: 0)
    var offset = 0

    if (aad.size > 0) {
        copyInto(aad, out, offset)
    }
    offset += aadPadded

    if (ciphertext.size > 0) {
        copyInto(ciphertext, out, offset)
    }
    offset += ctPadded

    encodeUInt64LE(out, offset, UInt64(aad.size))
    encodeUInt64LE(out, offset + 8, UInt64(ciphertext.size))
    out
}

private func roundUp16(length: Int64): Int64 {
    if (length < 0) {
        throw CryptoException(OutOfBounds, "negative length is invalid")
    }
    let remain = length % 16
    if (remain == 0) {
        return length
    }
    length + (16 - remain)
}

private func encodeUInt64LE(out: Array<Byte>, offset: Int64, value: UInt64): Unit {
    if (offset < 0 || offset + 8 > out.size) {
        throw CryptoException(OutOfBounds, "uint64 encode is out of bounds")
    }

    out[offset] = UInt8(value & UInt64(0xff))
    out[offset + 1] = UInt8((value >> 8) & UInt64(0xff))
    out[offset + 2] = UInt8((value >> 16) & UInt64(0xff))
    out[offset + 3] = UInt8((value >> 24) & UInt64(0xff))
    out[offset + 4] = UInt8((value >> 32) & UInt64(0xff))
    out[offset + 5] = UInt8((value >> 40) & UInt64(0xff))
    out[offset + 6] = UInt8((value >> 48) & UInt64(0xff))
    out[offset + 7] = UInt8((value >> 56) & UInt64(0xff))
}

private func copyInto(source: Array<Byte>, destination: Array<Byte>, offset: Int64): Unit {
    if (offset < 0 || offset + source.size > destination.size) {
        throw CryptoException(OutOfBounds, "byte copy is out of bounds")
    }

    var i = 0
    while (i < source.size) {
        destination[offset + i] = source[i]
        i += 1
    }
}

private func clampPoly1305R(r: Array<Byte>): Unit {
    r[3] = UInt8(r[3]) & UInt8(0x0f)
    r[7] = UInt8(r[7]) & UInt8(0x0f)
    r[11] = UInt8(r[11]) & UInt8(0x0f)
    r[15] = UInt8(r[15]) & UInt8(0x0f)
    r[4] = UInt8(r[4]) & UInt8(0xfc)
    r[8] = UInt8(r[8]) & UInt8(0xfc)
    r[12] = UInt8(r[12]) & UInt8(0xfc)
}

private func poly1305Prime(): BigInt {
    (BigInt(1) << 130) - BigInt(5)
}

private func poly1305TagModulus(): BigInt {
    BigInt(1) << 128
}

private func bigIntFromLittleEndian(bytes: Array<Byte>): BigInt {
    if (bytes.size == 0) {
        return BigInt(0)
    }

    var value = BigInt(0)
    var i = bytes.size
    while (i > 0) {
        i -= 1
        value = (value << 8) + BigInt(Int64(UInt8(bytes[i])))
    }
    value
}

private func bigIntToLittleEndian(value: BigInt, size: Int64): Array<Byte> {
    if (size < 0) {
        throw CryptoException(OutOfBounds, "little-endian output length must be non-negative")
    }

    let out = Array<Byte>(size, repeat: 0)
    var v = value
    var i = 0
    while (i < size) {
        out[i] = UInt8((v % BigInt(256)).toInt64())
        v = v >> 8
        i += 1
    }
    out
}

private func minInt64(left: Int64, right: Int64): Int64 {
    if (left < right) {
        return left
    }
    right
}
