package jinguissl_core.tests

import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.ecc.*
import jinguissl_core.crypto.error.CryptoException

@Test
public class CoreEccTestSuite {
    private let TEST_DIGEST_HEX: String =
        TEST_HEX_32_00112233445566778899AABBCCDDEEFF_00112233445566778899AABBCCDDEEFF

    // Generator point (Gx, Gy) for P-256
    private let P256_GX_HEX: String = "6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296"
    private let P256_GY_HEX: String = "4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5"

    @TestCase
    public func testCurveNameParse(): Unit {
        @Assert(namedCurveFromText("secp256r1").toString(), "P-256")
        @Assert(namedCurveFromText("secp384r1").toString(), "P-384")
        @Assert(namedCurveFromText("secp521r1").toString(), "P-521")
        @Assert(namedCurveFromText("secp256k1").toString(), "secp256k1")
    }

    @TestCase
    public func testFipsCurvePolicy(): Unit {
        let profile = FipsProfile.phase1Default()
        ecdsaRequireAllowed(profile)
        ecdhRequireAllowed(profile)

        @Assert(isFipsCurve(P256), true)
        @Assert(isFipsCurve(P384), true)
        @Assert(isFipsCurve(P521), true)
        @Assert(isFipsCurve(SECP256K1), false)

        requireFipsCurve(P256)

        try {
            requireFipsCurve(SECP256K1)
            @Fail("secp256k1 should be blocked in FIPS curve policy")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }

    @TestCase
    public func testEcdsaP256SignVerify(): Unit {
        let privateKey = EcPrivateKey(P256, BigNum.one())
        let publicKey = EcPublicKey(
            P256,
            BigNum.fromHex(P256_GX_HEX),
            BigNum.fromHex(P256_GY_HEX)
        )

        let digest = hexToBytes(TEST_DIGEST_HEX)
        let (r, s) = ecdsaSign(privateKey, digest)
        @Assert(ecdsaVerify(publicKey, digest, r, s), true)

        // Verify rejects wrong signature
        let rBad = r.add(BigNum.one())
        @Assert(ecdsaVerify(publicKey, digest, rBad, s), false)
    }

    @TestCase
    public func testEcdsaP384SignVerify(): Unit {
        let gx = BigNum.fromHex("AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7")
        let gy = BigNum.fromHex("3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F")
        let publicKey = EcPublicKey(P384, gx, gy)
        let privateKey = EcPrivateKey(P384, BigNum.one())

        let digest = hexToBytes(
            "000102030405060708090a0b0c0d0e0f" +
            "101112131415161718191a1b1c1d1e1f" +
            "202122232425262728292a2b2c2d2e2f"
        )
        let (r, s) = ecdsaSign(privateKey, digest)
        @Assert(ecdsaVerify(publicKey, digest, r, s), true)
    }

    @TestCase
    public func testEcdsaP521SignVerify(): Unit {
        assertEcdsaSignVerify(P521, BigNum.one(), TEST_DIGEST_HEX)
    }

    @TestCase
    public func testEcdsaSecp256k1SignVerify(): Unit {
        assertEcdsaSignVerify(SECP256K1, BigNum.one(), TEST_DIGEST_HEX)
    }

    @TestCase
    public func testEcdsaP256VerifyVector1(): Unit {
        let pub = EcPublicKey(
            P256,
            BigNum.fromHex("f3033d1e548d245b5e45ff1147db8cd44db8a1f2823c3c164125be88f9a982c2"),
            BigNum.fromHex("3c078f6cee2f50e95e8916aa9c4e93de3fdf9b045abac6f707cfcb22d065638e")
        )
        @Assert(ecdsaVerify(
            pub,
            hexToBytes("e8d38e4c6a905a814b04c2841d898ed6da023c34"),
            BigNum.fromHex("d4255db86a416a5a688de4e238071ef16e5f2a20e31b9490c03dee9ae6164c34"),
            BigNum.fromHex("4e0ac1e1a6725bf7c6bd207439b2d370c5f2dea1ff4decf1650ab84c7769efc0")
        ), true)
    }

    @TestCase
    public func testEcdhP256SharedSecret(): Unit {
        let gx = BigNum.fromHex(P256_GX_HEX)
        let gy = BigNum.fromHex(P256_GY_HEX)
        let publicKey = EcPublicKey(P256, gx, gy)
        let privateKey = EcPrivateKey(P256, BigNum.one())

        let shared = ecdhDeriveSharedSecret(privateKey, publicKey)
        @Assert(shared, hexToBytes("6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296"))
    }

    @TestCase
    public func testEcdhP384SharedSecret(): Unit {
        let gx = BigNum.fromHex("AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7")
        let gy = BigNum.fromHex("3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F")
        let publicKey = EcPublicKey(P384, gx, gy)
        let privateKey = EcPrivateKey(P384, BigNum.one())

        let shared = ecdhDeriveSharedSecret(privateKey, publicKey)
        @Assert(shared.size, 48)
        @Assert(shared, publicKey.x.toBytesBE(paddedLen: 48))
    }

    @TestCase
    public func testStructuredVerifyInvalidDer(): Unit {
        let xBytes = BigNum.fromHex(P256_GX_HEX).toBytesBE(paddedLen: 32)
        let yBytes = BigNum.fromHex(P256_GY_HEX).toBytesBE(paddedLen: 32)
        // Truncated DER triggers a parse error
        let badDer = [UInt8(0x30), UInt8(0x04), UInt8(0x02), UInt8(0x01)]
        let request = Es256P256StructuredVerifyRequest(xBytes, yBytes, "test".toArray(), badDer)
        let outcome = tryEs256P256VerifyStructuredRequest(request)
        @Assert(outcome.ok, false)
        match (outcome.code) {
            case Some(_) => @Assert(true)
            case None => @Fail("expected error code")
        }
    }
}

private func assertEcdsaSignVerify(curve: NamedCurve, scalar: BigNum, digestHex: String): Unit {
    let privateKey = EcPrivateKey(curve, scalar)
    let publicKey = ecPublicFromPrivateKey(privateKey)
    let digest = hexToBytes(digestHex)
    let (r, s) = ecdsaSign(privateKey, digest)
    @Assert(ecdsaVerify(publicKey, digest, r, s), true)
    @Assert(ecdsaVerify(publicKey, digest, r.add(BigNum.one()), s), false)
}

private func encodeDerSignature(r: BigNum, s: BigNum): Array<Byte> {
    let rBytes = stripLeadingZero(r.toBytesBE(paddedLen: 32))
    let sBytes = stripLeadingZero(s.toBytesBE(paddedLen: 32))
    let rDer = encodeDerInteger(rBytes)
    let sDer = encodeDerInteger(sBytes)
    let seqContent = Array<Byte>(rDer.size + sDer.size, repeat: 0)
    var pos = 0
    var i = 0
    while (i < rDer.size) {
        seqContent[pos] = rDer[i]
        pos += 1
        i += 1
    }
    i = 0
    while (i < sDer.size) {
        seqContent[pos] = sDer[i]
        pos += 1
        i += 1
    }
    encodeDerSequence(seqContent)
}

private func encodeDerInteger(content: Array<Byte>): Array<Byte> {
    let tag = UInt8(0x02)
    let length = content.size
    if (length < 128) {
        let out = Array<Byte>(2 + length, repeat: 0)
        out[0] = tag
        out[1] = UInt8(length)
        var i = 0
        while (i < length) {
            out[2 + i] = content[i]
            i += 1
        }
        out
    } else {
        // Only handles short form (< 128)
        throw Exception("DER integer too long for simple encoder")
    }
}

private func encodeDerSequence(content: Array<Byte>): Array<Byte> {
    let tag = UInt8(0x30)
    let length = content.size
    if (length < 128) {
        let out = Array<Byte>(2 + length, repeat: 0)
        out[0] = tag
        out[1] = UInt8(length)
        var i = 0
        while (i < length) {
            out[2 + i] = content[i]
            i += 1
        }
        out
    } else {
        throw Exception("DER sequence too long for simple encoder")
    }
}

private func stripLeadingZero(bytes: Array<Byte>): Array<Byte> {
    if (bytes.size > 0 && UInt8(bytes[0]) >= UInt8(0x80)) {
        let out = Array<Byte>(bytes.size + 1, repeat: 0)
        out[0] = 0
        var i = 0
        while (i < bytes.size) {
            out[i + 1] = bytes[i]
            i += 1
        }
        out
    } else {
        bytes.clone()
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
    if (ch >= b'a' && ch <= b'f') {
        return UInt8(ch - b'a' + UInt8(10))
    }
    if (ch >= b'A' && ch <= b'F') {
        return UInt8(ch - b'A' + UInt8(10))
    }
    throw Exception("invalid hex char")
}
