package jinguissl.contract

import jinguissl_core.crypto.chacha20.{
    CHACHA20_KEY_LEN as Core_CHACHA20_KEY_LEN,
    CHACHA20_NONCE_LEN as Core_CHACHA20_NONCE_LEN,
    CHACHA20_BLOCK_LEN as Core_CHACHA20_BLOCK_LEN,
    POLY1305_KEY_LEN as Core_POLY1305_KEY_LEN,
    POLY1305_TAG_LEN as Core_POLY1305_TAG_LEN,
    CHACHA20_POLY1305_TAG_LEN as Core_CHACHA20_POLY1305_TAG_LEN,
    chacha20Poly1305AlgorithmName,
    chacha20Block,
    chacha20Xor,
    poly1305Mac,
    chacha20Poly1305Encrypt,
    chacha20Poly1305Decrypt
}

/**
 * CHACHA20_KEY_LEN — ChaCha20 key length in bytes (32).
 */
public let CHACHA20_KEY_LEN: Int64 = Core_CHACHA20_KEY_LEN

/**
 * CHACHA20_NONCE_LEN — ChaCha20 nonce length in bytes (12).
 */
public let CHACHA20_NONCE_LEN: Int64 = Core_CHACHA20_NONCE_LEN

/**
 * CHACHA20_BLOCK_LEN — ChaCha20 block output length in bytes (64).
 */
public let CHACHA20_BLOCK_LEN: Int64 = Core_CHACHA20_BLOCK_LEN

/**
 * POLY1305_KEY_LEN — Poly1305 key length in bytes (32).
 */
public let POLY1305_KEY_LEN: Int64 = Core_POLY1305_KEY_LEN

/**
 * POLY1305_TAG_LEN — Poly1305 tag length in bytes (16).
 */
public let POLY1305_TAG_LEN: Int64 = Core_POLY1305_TAG_LEN

/**
 * CHACHA20_POLY1305_TAG_LEN — ChaCha20-Poly1305 authentication tag length in bytes (16).
 */
public let CHACHA20_POLY1305_TAG_LEN: Int64 = Core_CHACHA20_POLY1305_TAG_LEN

/**
 * contractChacha20Poly1305AlgorithmName — returns the algorithm name string "CHACHA20-POLY1305".
 */
public func contractChacha20Poly1305AlgorithmName(): String {
    chacha20Poly1305AlgorithmName()
}

/**
 * contractChacha20Block — generate a single ChaCha20 block.
 *
 * @param key 32-byte key
 * @param counter block counter (starting value)
 * @param nonce 12-byte nonce
 * @returns 64-byte keystream block
 */
public func contractChacha20Block(key: Array<Byte>, counter: Int64, nonce: Array<Byte>): Array<Byte> {
    chacha20Block(key, counter, nonce)
}

/**
 * contractChacha20Xor — XOR input with ChaCha20 keystream (stream cipher).
 *
 * @param key 32-byte key
 * @param nonce 12-byte nonce
 * @param input plaintext or ciphertext bytes
 * @param initialCounter initial counter value (default 0)
 * @returns XORed output (same length as input)
 */
public func contractChacha20Xor(
    key: Array<Byte>,
    nonce: Array<Byte>,
    input: Array<Byte>,
    initialCounter!: Int64 = 0
): Array<Byte> {
    chacha20Xor(key, nonce, input, initialCounter: initialCounter)
}

/**
 * contractPoly1305Mac — compute a Poly1305 message authentication code.
 *
 * @param key 32-byte one-time key
 * @param message input message
 * @returns 16-byte tag
 */
public func contractPoly1305Mac(key: Array<Byte>, message: Array<Byte>): Array<Byte> {
    poly1305Mac(key, message)
}

/**
 * contractChacha20Poly1305Encrypt — ChaCha20-Poly1305 AEAD encryption.
 *
 * @param key 32-byte key
 * @param nonce 12-byte nonce
 * @param plaintext plaintext to encrypt
 * @param aad additional authenticated data (default empty)
 * @returns (ciphertext, tag) tuple
 */
public func contractChacha20Poly1305Encrypt(
    key: Array<Byte>,
    nonce: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = []
): (Array<Byte>, Array<Byte>) {
    chacha20Poly1305Encrypt(key, nonce, plaintext, aad: aad)
}

/**
 * contractChacha20Poly1305Decrypt — ChaCha20-Poly1305 AEAD decryption.
 *
 * @param key 32-byte key
 * @param nonce 12-byte nonce
 * @param ciphertext ciphertext to decrypt
 * @param tag 16-byte authentication tag
 * @param aad additional authenticated data (default empty)
 * @returns plaintext
 * @throws CryptoException if tag verification fails
 */
public func contractChacha20Poly1305Decrypt(
    key: Array<Byte>,
    nonce: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad!: Array<Byte> = []
): Array<Byte> {
    chacha20Poly1305Decrypt(key, nonce, ciphertext, tag, aad: aad)
}
