package jinguissl_core.tests

import jinguissl_core.crypto.sm4.*

@Test
public class CoreSm4TestSuite {
    /* SM4 known test vectors from GM/T 0002-2012 */

    @TestCase
    public func testSm4EncryptDecryptSingleBlock(): Unit {
        /* Test vector from GB/T 32907-2016 / GM/T 0002-2012 */
        let key: Array<Byte> = [
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10
        ]
        let plaintext: Array<Byte> = [
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10
        ]
        let expectedCiphertext: Array<Byte> = [
            0x68, 0x1E, 0xDF, 0x34, 0xD2, 0x06, 0x96, 0x5E,
            0x86, 0xB3, 0xE9, 0x4F, 0x53, 0x6E, 0x42, 0x46
        ]
        let ciphertext = sm4Encrypt(key, plaintext)
        @Assert(arrToHex(ciphertext), arrToHex(expectedCiphertext))

        let decrypted = sm4Decrypt(key, ciphertext)
        @Assert(arrToHex(decrypted), arrToHex(plaintext))
    }

    @TestCase
    public func testSm4EncryptDecryptMultiBlock(): Unit {
        let key: Array<Byte> = [
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10
        ]
        /* Two blocks (32 bytes) */
        var plaintext = Array<Byte>(32, repeat: UInt8(0))
        var i = 0
        while (i < 16) {
            plaintext[i] = UInt8(i)
            plaintext[i + 16] = UInt8(16 + i)
            i += 1
        }
        let ciphertext = sm4Encrypt(key, plaintext)
        @Assert(ciphertext.size, 32)

        let decrypted = sm4Decrypt(key, ciphertext)
        @Assert(arrToHex(decrypted), arrToHex(plaintext))
    }

    @TestCase
    public func testSm4DecryptSingleBlock(): Unit {
        /* Decrypt the known ciphertext back to plaintext */
        let key: Array<Byte> = [
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10
        ]
        let ciphertext: Array<Byte> = [
            0x68, 0x1E, 0xDF, 0x34, 0xD2, 0x06, 0x96, 0x5E,
            0x86, 0xB3, 0xE9, 0x4F, 0x53, 0x6E, 0x42, 0x46
        ]
        let expectedPlaintext: Array<Byte> = [
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10
        ]
        let decrypted = sm4Decrypt(key, ciphertext)
        @Assert(arrToHex(decrypted), arrToHex(expectedPlaintext))
    }

    @TestCase
    public func testSm4RoundTripZeroKey(): Unit {
        /* All-zero key and all-zero plaintext */
        var key = Array<Byte>(16, repeat: UInt8(0))
        var plaintext = Array<Byte>(16, repeat: UInt8(0))
        let ciphertext = sm4Encrypt(key, plaintext)
        @Assert(ciphertext.size, 16)
        let decrypted = sm4Decrypt(key, ciphertext)
        @Assert(arrToHex(decrypted), arrToHex(plaintext))
    }

    @TestCase
    public func testSm4Deterministic(): Unit {
        let key: Array<Byte> = [
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10
        ]
        let plaintext: Array<Byte> = [
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10
        ]
        let r1 = sm4Encrypt(key, plaintext)
        let r2 = sm4Encrypt(key, plaintext)
        @Assert(arrToHex(r1), arrToHex(r2))
    }

    @TestCase
    public func testSm4InvalidKeySize(): Unit {
        let key = Array<Byte>(15, repeat: UInt8(0xAB))
        let data = Array<Byte>(16, repeat: UInt8(0))
        try {
            sm4Encrypt(key, data)
            @Assert(false, true)  /* Should not reach here */
        } catch (e: Exception) {
            @Assert(true, true)  /* Expected exception */
        }
    }

    @TestCase
    public func testSm4InvalidDataSize(): Unit {
        let key = Array<Byte>(16, repeat: UInt8(0xAB))
        let data = Array<Byte>(15, repeat: UInt8(0))
        try {
            sm4Encrypt(key, data)
            @Assert(false, true)  /* Should not reach here */
        } catch (e: Exception) {
            @Assert(true, true)  /* Expected exception */
        }
    }

    private func arrToHex(bytes: Array<Byte>): String {
        let hexChars: Array<String> = [
            "0", "1", "2", "3", "4", "5", "6", "7",
            "8", "9", "a", "b", "c", "d", "e", "f"
        ]
        var result = ""
        var i = 0
        while (i < bytes.size) {
            let b = Int64(bytes[i])
            result = result + hexChars[(b >> 4) & 0xF] + hexChars[b & 0xF]
            i += 1
        }
        result
    }
}
