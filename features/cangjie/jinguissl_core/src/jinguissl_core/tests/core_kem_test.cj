package jinguissl_core.tests

import std.fs.*
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.ecc.*
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.kem.*
import jinguissl_core.crypto.rsa.*

private let P256_GX: BigNum = BigNum.fromHex("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296")
private let P256_GY: BigNum = BigNum.fromHex("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5")

@Test
public class KemTestSuite {
    @TestCase
    public func testRsaKemRoundTrip(): Unit {
        let privateKey = loadRsa2048PrivateKey()
        let info = "stage3-rsa-kem".toArray()
        let (ciphertext, secretEnc) = rsaKemEncapsulate(
            privateKey.publicKey,
            sharedSecretLen: 48,
            info: info
        )
        let secretDec = rsaKemDecapsulate(
            privateKey,
            ciphertext,
            sharedSecretLen: 48,
            info: info
        )

        @Assert(ciphertext.size, 256)
        @Assert(secretEnc.size, 48)
        @Assert(secretEnc, secretDec)
    }

    @TestCase
    public func testRsaKemRejectInvalidCiphertext(): Unit {
        let privateKey = loadRsa2048PrivateKey()

        let shortCipher = Array<Byte>(255, repeat: 0)
        try {
            _ = rsaKemDecapsulate(privateKey, shortCipher)
            @Fail("short RSA-KEM ciphertext should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        let outOfRangeCipher = Array<Byte>(256, repeat: UInt8(0xff))
        try {
            _ = rsaKemDecapsulate(privateKey, outOfRangeCipher)
            @Fail("RSA-KEM ciphertext representative out of range should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testEcdhKemRoundTrip(): Unit {
        let receiverPrivate = EcPrivateKey(P256, BigNum.one())
        let receiverPublic = EcPublicKey(P256, P256_GX, P256_GY)
        let info = "stage3-ecdh-kem".toArray()

        let (encapsulatedKey, secretEnc) = ecdhKemEncapsulate(
            receiverPublic,
            sharedSecretLen: 32,
            info: info
        )
        let secretDec = ecdhKemDecapsulate(
            receiverPrivate,
            encapsulatedKey,
            sharedSecretLen: 32,
            info: info
        )

        @Assert(encapsulatedKey.size, 65)
        @Assert(UInt8(encapsulatedKey[0]), UInt8(0x04))
        @Assert(secretEnc.size, 32)
        @Assert(secretEnc, secretDec)
    }

    @TestCase
    public func testEcdhKemRejectInvalidInput(): Unit {
        let receiverPrivate = EcPrivateKey(P256, BigNum.one())
        let receiverPublic = EcPublicKey(P256, P256_GX, P256_GY)

        let (encapsulatedKey, _) = ecdhKemEncapsulate(receiverPublic)
        let broken = encapsulatedKey.clone()
        broken[0] = UInt8(0x05)

        try {
            _ = ecdhKemDecapsulate(receiverPrivate, broken)
            @Fail("broken ECDH-KEM point prefix should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let p384Private = EcPrivateKey(P384, BigNum.one())
        try {
            _ = ecdhKemDecapsulate(p384Private, encapsulatedKey)
            @Fail("non-P256 ECDH-KEM decapsulation should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testKemComplianceRequireAllowed(): Unit {
        let defaultProfile = FipsProfile.phase1Default()
        rsaKemRequireAllowed(defaultProfile)
        ecdhKemRequireAllowed(defaultProfile)

        let kemOnly = FipsProfile.fromText("RSA-KEM\nECDH-KEM")
        rsaKemRequireAllowed(kemOnly)
        ecdhKemRequireAllowed(kemOnly)

        let blockedProfile = FipsProfile.fromText("AES-GCM")
        try {
            rsaKemRequireAllowed(blockedProfile)
            @Fail("RSA-KEM should be blocked when neither RSA-KEM nor RSA is allowed")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }

        try {
            ecdhKemRequireAllowed(blockedProfile)
            @Fail("ECDH-KEM should be blocked when neither ECDH-KEM nor ECDH is allowed")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }
}

private func loadRsa2048PrivateKey(): RsaPrivateKey {
    let path = "testdata/stage3/rsa_params_sample.txt"
    if (!exists(path)) {
        throw Exception("missing RSA vector file: ${path}")
    }

    let lines = String.fromUtf8(File.readFrom(path)).replace("\r", "\n").split('\n')
    var inTarget = false
    var n = ""
    var e = ""
    var d = ""

    for (rawLine in lines) {
        let line = rawLine.trimAscii()
        if (line.size == 0 || line.startsWith("#")) {
            continue
        }
        if (let Some(pos) <- line.indexOf("=")) {
            let key = line[..pos].trimAscii()
            let value = line[(pos + 1)..].trimAscii()
            if (key == "Vector") {
                if (inTarget && value != "RSA-2048") {
                    break
                }
                inTarget = (value == "RSA-2048")
                continue
            }
            if (!inTarget) {
                continue
            }
            if (key == "N") {
                n = value
            } else if (key == "E") {
                e = value
            } else if (key == "D") {
                d = value
            }
        }
    }

    if (n.size == 0 || e.size == 0 || d.size == 0) {
        throw Exception("RSA-2048 key vector is incomplete")
    }

    rsaPrivateKeyFromHex(n, e, d)
}
