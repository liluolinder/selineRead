package jinguissl_core.tests

import std.collection.ArrayList
import jinguissl_core.crypto.chacha20.{CHACHA20_BLOCK_LEN, CHACHA20_KEY_LEN, CHACHA20_NONCE_LEN, CHACHA20_POLY1305_TAG_LEN, POLY1305_KEY_LEN, POLY1305_TAG_LEN, chacha20Block, chacha20Poly1305Decrypt, chacha20Poly1305DecryptWithContext, chacha20Poly1305DecryptWithContextChecked, chacha20Poly1305Encrypt, chacha20Poly1305EncryptChecked, chacha20Poly1305EncryptWithContext, chacha20Poly1305EncryptWithContextChecked, chacha20Poly1305NewContext, chacha20Xor, poly1305Mac}
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.digest.bytesToHexLower
import jinguissl_core.crypto.error.CryptoException

@Test
public class CoreChacha20TestSuite {
    @TestCase
    public func testChacha20BlockRfc8439Vector(): Unit {
        let key = hexToBytes("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
        let nonce = hexToBytes("000000090000004a00000000")
        let expected = "10f1e7e4d13b5915500fdd1fa32071c4" +
            "c7d1f4c733c068030422aa9ac3d46c4e" +
            "d2826446079faa0914c2d705d98b02a2" +
            "b5129cd1de164eb9cbd083e8a2503c4e"

        let block = chacha20Block(key, 1, nonce)
        @Assert(bytesToHexLower(block), expected)
    }

    @TestCase
    public func testChacha20StreamRfc8439Vector(): Unit {
        let key = hexToBytes("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
        let nonce = hexToBytes("000000000000004a00000000")
        let plaintext = (
            "Ladies and Gentlemen of the class of '99: " +
            "If I could offer you only one tip for the future, sunscreen would be it."
        ).toArray()
        let expectedCipher = "6e2e359a2568f98041ba0728dd0d6981" +
            "e97e7aec1d4360c20a27afccfd9fae0b" +
            "f91b65c5524733ab8f593dabcd62b357" +
            "1639d624e65152ab8f530c359f0861d8" +
            "07ca0dbf500d6a6156a38e088a22b65e" +
            "52bc514d16ccf806818ce91ab7793736" +
            "5af90bbf74a35be6b40b8eedf2785e42" +
            "874d"

        let ciphertext = chacha20Xor(key, nonce, plaintext, initialCounter: 1)
        @Assert(bytesToHexLower(ciphertext), expectedCipher)
        @Assert(chacha20Xor(key, nonce, ciphertext, initialCounter: 1), plaintext)
    }

    @TestCase
    public func testPoly1305RfcVector(): Unit {
        let key = hexToBytes("85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b")
        let input = "Cryptographic Forum Research Group".toArray()
        let tag = poly1305Mac(key, input)
        @Assert(bytesToHexLower(tag), "a8061dc1305136c6c22b8baf0c0127a9")
    }

    @TestCase
    public func testChacha20Poly1305AeadRfc8439Vector(): Unit {
        // RFC 8439 Section 2.8.2 test vector
        let key = hexToBytes("808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f")
        let nonce = hexToBytes("070000004041424344454647")
        let plaintext: Array<Byte> = (
            "Ladies and Gentlemen of the class of '99: " +
            "If I could offer you only one tip for the future, sunscreen would be it."
        ).toArray()
        let aad = hexToBytes("50515253c0c1c2c3c4c5c6c7")

        let expectedCipher = "d31a8d34648e60db7b86afbc53ef7ec2" +
            "a4aded51296e08fea9e2b5a736ee62d6" +
            "3dbea45e8ca9671282fafb69da92728b" +
            "1a71de0a9e060b2905d6a5b67ecd3b36" +
            "92ddbd7f2d778b8c9803aee328091b58" +
            "fab324e4fad675945585808b4831d7bc" +
            "3ff4def08e4b7a9de576d26586cec64b" +
            "6116"
        let expectedTag = "1ae10b594f09e26a7e902ecbd0600691"

        let (ciphertext, tag) = chacha20Poly1305Encrypt(key, nonce, plaintext, aad: aad)
        @Assert(bytesToHexLower(ciphertext), expectedCipher)
        @Assert(bytesToHexLower(tag), expectedTag)

        let opened = chacha20Poly1305Decrypt(key, nonce, ciphertext, tag, aad: aad)
        @Assert(opened, plaintext)
    }

    @TestCase
    public func testChacha20Poly1305DecryptTagMismatch(): Unit {
        let key = hexToBytes("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
        let nonce = hexToBytes("000000000000004a00000000")
        let plain = "hello-chacha20-poly1305".toArray()
        let aad: Array<Byte> = []

        let (ciphertext, tag) = chacha20Poly1305Encrypt(key, nonce, plain, aad: aad)

        let badTag = tag.clone()
        badTag[0] = UInt8(badTag[0]) ^ UInt8(0x01)
        try {
            _ = chacha20Poly1305Decrypt(key, nonce, ciphertext, badTag, aad: aad)
            @Fail("tag mismatch should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testChacha20Poly1305EncryptDecryptRoundtrip(): Unit {
        let key = hexToBytes("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
        let nonce = hexToBytes("000000000000004a00000000")
        let plain = "hello-chacha20-poly1305".toArray()
        let aad = "tls-record-aad".toArray()

        let context = chacha20Poly1305NewContext(key)
        let (ciphertext, tag) = chacha20Poly1305EncryptWithContext(context, nonce, plain, aad: aad)
        let opened = chacha20Poly1305DecryptWithContext(context, nonce, ciphertext, tag, aad: aad)
        @Assert(opened, plain)
        @Assert(ciphertext != plain, true)
    }

    @TestCase
    public func testChacha20Poly1305ComplianceGate(): Unit {
        let key = hexToBytes("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
        let nonce = hexToBytes("000000000000004a00000000")
        let plain = "hello-chacha20-poly1305".toArray()
        let aad = "tls-record-aad".toArray()

        let blocked = FipsProfile.phase1Default()
        try {
            _ = chacha20Poly1305EncryptChecked(blocked, key, nonce, plain, aad: aad)
            @Fail("default phase profile should block CHACHA20-POLY1305")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }

        let allowed = FipsProfile.fromText("TLS1.2\nCHACHA20-POLY1305")
        let context = chacha20Poly1305NewContext(key)
        let (ciphertext, tag) = chacha20Poly1305EncryptWithContextChecked(allowed, context, nonce, plain, aad: aad)
        let opened = chacha20Poly1305DecryptWithContextChecked(allowed, context, nonce, ciphertext, tag, aad: aad)
        @Assert(opened, plain)
    }

    @TestCase
    public func testConstantsShape(): Unit {
        @Assert(CHACHA20_KEY_LEN, 32)
        @Assert(CHACHA20_NONCE_LEN, 12)
        @Assert(CHACHA20_BLOCK_LEN, 64)
        @Assert(POLY1305_KEY_LEN, 32)
        @Assert(POLY1305_TAG_LEN, 16)
        @Assert(CHACHA20_POLY1305_TAG_LEN, 16)
    }
}

private func hexToBytes(hex: String): Array<Byte> {
    let clean = hex.trimAscii().replace(" ", "").replace("\n", "").replace("\t", "")
    if ((clean.size % 2) != 0) {
        throw Exception("invalid hex length")
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

    throw Exception("invalid hex char")
}
