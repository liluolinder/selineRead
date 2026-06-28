package jinguissl_core.tests

import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.ed25519.{ed25519PublicKeyFromSeed, ed25519Sign, ed25519Verify}
import jinguissl_core.crypto.rsa.*

@Test
public class CoreSideChannelHarnessTestSuite {
    private let TEST_DIGEST_HEX: String =
        TEST_HEX_32_00112233445566778899AABBCCDDEEFF_00112233445566778899AABBCCDDEEFF

    @TestCase
    public func testRsaBlindingHarnessKeepsPkcs1v15RepresentativeStable(): Unit {
        let privateKey = harnessRsaVectorKey()
        let publicKey = privateKey.publicKey
        let digest = harnessHexToBytes(TEST_DIGEST_HEX)
        let expected = rsaSignPkcs1v15(privateKey, digest)
        @Assert(expected.size, 256)
        @Assert(rsaVerifyPkcs1v15(publicKey, digest, expected), true)

        var i = 0
        while (i < 4) {
            let signature = rsaSignPkcs1v15(privateKey, digest)
            @Assert(signature, expected)
            @Assert(rsaVerifyPkcs1v15(publicKey, digest, signature), true)
            i += 1
        }
    }

    @TestCase
    public func testEd25519FixedRoundHarnessKeepsBoringSslVectorsStable(): Unit {
        let seed = harnessHexToBytes("4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb")
        let publicKey = harnessHexToBytes("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c")
        let message = harnessHexToBytes("72")
        let signature = harnessHexToBytes(
            "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da" +
            "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
        )

        @Assert(ed25519PublicKeyFromSeed(seed), publicKey)
        @Assert(ed25519Sign(seed, message), signature)
        @Assert(ed25519Verify(publicKey, message, signature), true)
    }

    @TestCase
    public func testBigNumModExpHarnessCoversOddAndEvenModuli(): Unit {
        let oddResult = BigNum.fromHex("05").modExp(BigNum.fromHex("03"), BigNum.fromHex("0d"))
        @Assert(oddResult.toHex(), "08")

        let evenResult = BigNum.fromHex("05").modExp(BigNum.fromHex("03"), BigNum.fromHex("10"))
        @Assert(evenResult.toHex(), "0d")
    }
}

private func harnessRsaVectorKey(): RsaPrivateKey {
    let nHex = "cd0081ea7b2ae1ea06d59f7c73d9ffb94a09615c2e4ba7c636cef08dd3533ec3185525b015c769b99a77d6725bf9c3532a9b6e5f6627d5fb85160768d3dda9cbd35974511717dc3d309d2fc47ee41f97e32adb7f9dd864a1c4767a666ecd71bc1aacf5e7517f4b38594fea9b05e42d5ada9912008013e45316a4d9bb8ed086b88d28758bacaf922d46a868b485d239c9baeb0e2b64592710f42b2d1ea0a4b4802c0becab328f8a68b0073bdb546feea9809d2849912b390c1532bc7e29c7658f8175fae46f34332ff87bcab3e40649b98577869da0ea718353f0722754886913648760d122be676e0fc483dd20ffc31bda96a31966c9aa2e75ad03de47e1c44f"
    let eHex = "010001"
    let dHex = "60297ac7991b167a06d6b24758b8cbe208beb9b2d9ec9738bd80f90a2e35005dd7ce292d9e29ba885bd316fef1f20913bc0ac90d6b0808b2414d82104441d8624a33ce0233c8f780a48b375aff02d76712228a702484db3f9ebecccfbbee1709dba182800d949e9e4216e0bff3558388f8bd90da373a1d82743ec3fbdd1427fd16825a657a316912e8695365117ca2f845c909405fcac55f895fc15d20386c26ee78c9e99075029a178a6c1e4cf0c200e8a9cfb27e9d156f86e6c2adc22b1a84a1cd5ca5b2790875d79407c84b352395cb81cc3fed5bb043b69ede0c07204550025cee8c5f440170b6120bb48e0f747bcd8f522110850df043c428dfd1870531"
    rsaPrivateKeyFromHex(nHex, eHex, dHex)
}

private func harnessHexToBytes(hex: String): Array<Byte> {
    let clean = hex.trimAscii().replace(" ", "").replace("\n", "").replace("\t", "")
    if ((clean.size % 2) != 0) {
        throw Exception("invalid hex length")
    }
    let out = Array<Byte>(clean.size / 2, repeat: 0)
    var i = 0
    while (i < clean.size) {
        let hi = harnessHexNibble(clean[i])
        let lo = harnessHexNibble(clean[i + 1])
        out[i / 2] = UInt8((hi << 4) | lo)
        i += 2
    }
    out
}

private func harnessHexNibble(ch: Byte): UInt8 {
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
