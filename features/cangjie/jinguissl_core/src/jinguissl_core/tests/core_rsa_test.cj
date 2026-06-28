package jinguissl_core.tests

import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.rsa.*

@Test
public class CoreRsaTestSuite {
    // 32-byte digest fixture used by deterministic RSA signature tests.
    private let TEST_DIGEST_HEX: String =
        TEST_HEX_32_00112233445566778899AABBCCDDEEFF_00112233445566778899AABBCCDDEEFF

    @TestCase
    public func testKeyValidationAccept2048(): Unit {
        rsaRequireAllowed(FipsProfile.phase1Default())
        rsaValidateKeyParameters(2048, BigNum.fromHex("010001"))
    }

    @TestCase
    public func testKeyValidationReject1024(): Unit {
        try {
            rsaValidateKeyParameters(1024, BigNum.fromHex("010001"))
            @Fail("RSA-1024 should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }

    @TestCase
    public func testKeyValidationRejectEvenExponent(): Unit {
        try {
            rsaValidateKeyParameters(2048, BigNum.fromHex("100"))
            @Fail("even RSA exponent should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testPkcs1v15SignVerifyWithVectorKey(): Unit {
        let nHex = "cd0081ea7b2ae1ea06d59f7c73d9ffb94a09615c2e4ba7c636cef08dd3533ec3185525b015c769b99a77d6725bf9c3532a9b6e5f6627d5fb85160768d3dda9cbd35974511717dc3d309d2fc47ee41f97e32adb7f9dd864a1c4767a666ecd71bc1aacf5e7517f4b38594fea9b05e42d5ada9912008013e45316a4d9bb8ed086b88d28758bacaf922d46a868b485d239c9baeb0e2b64592710f42b2d1ea0a4b4802c0becab328f8a68b0073bdb546feea9809d2849912b390c1532bc7e29c7658f8175fae46f34332ff87bcab3e40649b98577869da0ea718353f0722754886913648760d122be676e0fc483dd20ffc31bda96a31966c9aa2e75ad03de47e1c44f"
        let eHex = "010001"
        let dHex = "60297ac7991b167a06d6b24758b8cbe208beb9b2d9ec9738bd80f90a2e35005dd7ce292d9e29ba885bd316fef1f20913bc0ac90d6b0808b2414d82104441d8624a33ce0233c8f780a48b375aff02d76712228a702484db3f9ebecccfbbee1709dba182800d949e9e4216e0bff3558388f8bd90da373a1d82743ec3fbdd1427fd16825a657a316912e8695365117ca2f845c909405fcac55f895fc15d20386c26ee78c9e99075029a178a6c1e4cf0c200e8a9cfb27e9d156f86e6c2adc22b1a84a1cd5ca5b2790875d79407c84b352395cb81cc3fed5bb043b69ede0c07204550025cee8c5f440170b6120bb48e0f747bcd8f522110850df043c428dfd1870531"

        let privateKey = rsaPrivateKeyFromHex(nHex, eHex, dHex)
        let publicKey = privateKey.publicKey
        let digest = hexToBytes(TEST_DIGEST_HEX)

        let signature = rsaSignPkcs1v15(privateKey, digest)
        @Assert(signature.size, 256)
        @Assert(rsaVerifyPkcs1v15(publicKey, digest, signature), true)

        let badSignature = signature.clone()
        badSignature[0] = UInt8(badSignature[0]) ^ UInt8(0x01)
        @Assert(rsaVerifyPkcs1v15(publicKey, digest, badSignature), false)
    }

    @TestCase
    public func testPssSignVerifyWithVectorKey(): Unit {
        let nHex = "cd0081ea7b2ae1ea06d59f7c73d9ffb94a09615c2e4ba7c636cef08dd3533ec3185525b015c769b99a77d6725bf9c3532a9b6e5f6627d5fb85160768d3dda9cbd35974511717dc3d309d2fc47ee41f97e32adb7f9dd864a1c4767a666ecd71bc1aacf5e7517f4b38594fea9b05e42d5ada9912008013e45316a4d9bb8ed086b88d28758bacaf922d46a868b485d239c9baeb0e2b64592710f42b2d1ea0a4b4802c0becab328f8a68b0073bdb546feea9809d2849912b390c1532bc7e29c7658f8175fae46f34332ff87bcab3e40649b98577869da0ea718353f0722754886913648760d122be676e0fc483dd20ffc31bda96a31966c9aa2e75ad03de47e1c44f"
        let eHex = "010001"
        let dHex = "60297ac7991b167a06d6b24758b8cbe208beb9b2d9ec9738bd80f90a2e35005dd7ce292d9e29ba885bd316fef1f20913bc0ac90d6b0808b2414d82104441d8624a33ce0233c8f780a48b375aff02d76712228a702484db3f9ebecccfbbee1709dba182800d949e9e4216e0bff3558388f8bd90da373a1d82743ec3fbdd1427fd16825a657a316912e8695365117ca2f845c909405fcac55f895fc15d20386c26ee78c9e99075029a178a6c1e4cf0c200e8a9cfb27e9d156f86e6c2adc22b1a84a1cd5ca5b2790875d79407c84b352395cb81cc3fed5bb043b69ede0c07204550025cee8c5f440170b6120bb48e0f747bcd8f522110850df043c428dfd1870531"

        let privateKey = rsaPrivateKeyFromHex(nHex, eHex, dHex)
        let publicKey = privateKey.publicKey
        let digest = hexToBytes(TEST_DIGEST_HEX)

        let signature = rsaSignPss(privateKey, digest)
        @Assert(signature.size, 256)
        @Assert(rsaVerifyPss(publicKey, digest, signature), true)

        let badSignature = signature.clone()
        badSignature[signature.size - 1] = UInt8(badSignature[signature.size - 1]) ^ UInt8(0xff)
        @Assert(rsaVerifyPss(publicKey, digest, badSignature), false)
    }

    @TestCase
    public func testPkcs1v15SignVerifyWithHash(): Unit {
        let nHex = "cd0081ea7b2ae1ea06d59f7c73d9ffb94a09615c2e4ba7c636cef08dd3533ec3185525b015c769b99a77d6725bf9c3532a9b6e5f6627d5fb85160768d3dda9cbd35974511717dc3d309d2fc47ee41f97e32adb7f9dd864a1c4767a666ecd71bc1aacf5e7517f4b38594fea9b05e42d5ada9912008013e45316a4d9bb8ed086b88d28758bacaf922d46a868b485d239c9baeb0e2b64592710f42b2d1ea0a4b4802c0becab328f8a68b0073bdb546feea9809d2849912b390c1532bc7e29c7658f8175fae46f34332ff87bcab3e40649b98577869da0ea718353f0722754886913648760d122be676e0fc483dd20ffc31bda96a31966c9aa2e75ad03de47e1c44f"
        let eHex = "010001"
        let dHex = "60297ac7991b167a06d6b24758b8cbe208beb9b2d9ec9738bd80f90a2e35005dd7ce292d9e29ba885bd316fef1f20913bc0ac90d6b0808b2414d82104441d8624a33ce0233c8f780a48b375aff02d76712228a702484db3f9ebecccfbbee1709dba182800d949e9e4216e0bff3558388f8bd90da373a1d82743ec3fbdd1427fd16825a657a316912e8695365117ca2f845c909405fcac55f895fc15d20386c26ee78c9e99075029a178a6c1e4cf0c200e8a9cfb27e9d156f86e6c2adc22b1a84a1cd5ca5b2790875d79407c84b352395cb81cc3fed5bb043b69ede0c07204550025cee8c5f440170b6120bb48e0f747bcd8f522110850df043c428dfd1870531"

        let privateKey = rsaPrivateKeyFromHex(nHex, eHex, dHex)
        let publicKey = privateKey.publicKey
        // "WithHash" functions accept a pre-hashed digest + hash algorithm for DigestInfo tagging
        let digest = hexToBytes(TEST_DIGEST_HEX)

        let signature = rsaSignPkcs1v15WithHash(privateKey, digest, RsaHashAlgorithm.SHA256)
        @Assert(signature.size, 256)
        @Assert(rsaVerifyPkcs1v15WithHash(publicKey, digest, signature, RsaHashAlgorithm.SHA256), true)

        @Assert(rsaVerifyPkcs1v15WithHash(publicKey, digest, signature, RsaHashAlgorithm.SHA384), false)
    }

    @TestCase
    public func testPssSignVerifyWithHash(): Unit {
        let nHex = "cd0081ea7b2ae1ea06d59f7c73d9ffb94a09615c2e4ba7c636cef08dd3533ec3185525b015c769b99a77d6725bf9c3532a9b6e5f6627d5fb85160768d3dda9cbd35974511717dc3d309d2fc47ee41f97e32adb7f9dd864a1c4767a666ecd71bc1aacf5e7517f4b38594fea9b05e42d5ada9912008013e45316a4d9bb8ed086b88d28758bacaf922d46a868b485d239c9baeb0e2b64592710f42b2d1ea0a4b4802c0becab328f8a68b0073bdb546feea9809d2849912b390c1532bc7e29c7658f8175fae46f34332ff87bcab3e40649b98577869da0ea718353f0722754886913648760d122be676e0fc483dd20ffc31bda96a31966c9aa2e75ad03de47e1c44f"
        let eHex = "010001"
        let dHex = "60297ac7991b167a06d6b24758b8cbe208beb9b2d9ec9738bd80f90a2e35005dd7ce292d9e29ba885bd316fef1f20913bc0ac90d6b0808b2414d82104441d8624a33ce0233c8f780a48b375aff02d76712228a702484db3f9ebecccfbbee1709dba182800d949e9e4216e0bff3558388f8bd90da373a1d82743ec3fbdd1427fd16825a657a316912e8695365117ca2f845c909405fcac55f895fc15d20386c26ee78c9e99075029a178a6c1e4cf0c200e8a9cfb27e9d156f86e6c2adc22b1a84a1cd5ca5b2790875d79407c84b352395cb81cc3fed5bb043b69ede0c07204550025cee8c5f440170b6120bb48e0f747bcd8f522110850df043c428dfd1870531"

        let privateKey = rsaPrivateKeyFromHex(nHex, eHex, dHex)
        let publicKey = privateKey.publicKey
        let digest = hexToBytes(TEST_DIGEST_HEX)

        let signature = rsaSignPssWithHash(privateKey, digest, RsaHashAlgorithm.SHA256)
        @Assert(signature.size, 256)
        @Assert(rsaVerifyPssWithHash(publicKey, digest, signature, RsaHashAlgorithm.SHA256), true)

        @Assert(rsaVerifyPssWithHash(publicKey, digest, signature, RsaHashAlgorithm.SHA512), false)
    }

    @TestCase
    public func testPublicKeyFromHexRoundTrip(): Unit {
        let nHex = "cd0081ea7b2ae1ea06d59f7c73d9ffb94a09615c2e4ba7c636cef08dd3533ec3185525b015c769b99a77d6725bf9c3532a9b6e5f6627d5fb85160768d3dda9cbd35974511717dc3d309d2fc47ee41f97e32adb7f9dd864a1c4767a666ecd71bc1aacf5e7517f4b38594fea9b05e42d5ada9912008013e45316a4d9bb8ed086b88d28758bacaf922d46a868b485d239c9baeb0e2b64592710f42b2d1ea0a4b4802c0becab328f8a68b0073bdb546feea9809d2849912b390c1532bc7e29c7658f8175fae46f34332ff87bcab3e40649b98577869da0ea718353f0722754886913648760d122be676e0fc483dd20ffc31bda96a31966c9aa2e75ad03de47e1c44f"
        let eHex = "010001"
        let publicKey = rsaPublicKeyFromHex(nHex, eHex)
        @Assert(publicKey.bits(), 2048)
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
