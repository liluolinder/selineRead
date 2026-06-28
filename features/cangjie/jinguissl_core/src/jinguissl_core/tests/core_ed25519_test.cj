package jinguissl_core.tests

import jinguissl_core.crypto.ed25519.{ed25519GeneratePrivateKeySeed, ed25519PublicKeyFromSeed, ed25519Sign, ed25519Verify}
import jinguissl_core.crypto.error.CryptoException

@Test
public class Ed25519TestSuite {
    @TestCase
    public func testSignAndPublicKeyAgainstBoringSslVectors(): Unit {
        let seed0 = hexToBytes("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
        let public0 = hexToBytes("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")
        let sig0 = hexToBytes(
            "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" +
            "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
        )
        @Assert(ed25519PublicKeyFromSeed(seed0), public0)
        @Assert(ed25519Sign(seed0, []), sig0)
        @Assert(ed25519Verify(public0, [], sig0), true)

        let seed1 = hexToBytes("4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb")
        let public1 = hexToBytes("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c")
        let message1 = hexToBytes("72")
        let sig1 = hexToBytes(
            "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da" +
            "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
        )
        @Assert(ed25519PublicKeyFromSeed(seed1), public1)
        @Assert(ed25519Sign(seed1, message1), sig1)
        @Assert(ed25519Verify(public1, message1, sig1), true)
    }

    @TestCase
    public func testVerifyBoringSslVectors(): Unit {
        @Assert(
            ed25519Verify(
                hexToBytes("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"),
                [],
                hexToBytes(
                    "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" +
                    "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
                )
            ),
            true
        )

        @Assert(
            ed25519Verify(
                hexToBytes("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c"),
                hexToBytes("72"),
                hexToBytes(
                    "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da" +
                    "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
                )
            ),
            true
        )
    }

    @TestCase
    public func testRejectTamperedSignature(): Unit {
        let publicKey = hexToBytes("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c")
        let message = hexToBytes("72")
        let signature = hexToBytes(
            "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da" +
            "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
        )
        signature[10] = UInt8(UInt8(signature[10]) ^ UInt8(0x40))
        @Assert(ed25519Verify(publicKey, message, signature), false)
    }

    @TestCase
    public func testRejectInvalidInputLengths(): Unit {
        @Assert(ed25519Verify([], [], []), false)
        @Assert(
            ed25519Verify(
                Array<Byte>(32, repeat: 0),
                [UInt8(0x01)],
                Array<Byte>(63, repeat: 0)
            ),
            false
        )
    }

    @TestCase
    public func testGenerateSeedAndRejectInvalidSeedLength(): Unit {
        let seed = ed25519GeneratePrivateKeySeed()
        @Assert(seed.size, 32)
        let publicKey = ed25519PublicKeyFromSeed(seed)
        let signature = ed25519Sign(seed, "ed25519-round-trip".toArray())
        @Assert(ed25519Verify(publicKey, "ed25519-round-trip".toArray(), signature), true)

        try {
            _ = ed25519PublicKeyFromSeed([UInt8(0x01)])
            @Fail("ed25519 public-key derivation should reject short seed")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            _ = ed25519Sign([UInt8(0x02)], [])
            @Fail("ed25519 sign should reject short seed")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
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
