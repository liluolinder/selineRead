package jinguissl_core.tests

import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.x25519.{X25519_KEY_LEN, x25519ClampPrivateKey, x25519DeriveSharedSecret, x25519GeneratePrivateKey, x25519PublicFromPrivate}

@Test
public class X25519TestSuite {
    @TestCase
    public func testRfc7748DhVectors(): Unit {
        let alicePrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let bobPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")

        let alicePublic = x25519PublicFromPrivate(alicePrivate)
        let bobPublic = x25519PublicFromPrivate(bobPrivate)

        @Assert(bytesToHex(alicePublic), "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")
        @Assert(bytesToHex(bobPublic), "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")

        let aliceShared = x25519DeriveSharedSecret(alicePrivate, bobPublic)
        let bobShared = x25519DeriveSharedSecret(bobPrivate, alicePublic)
        @Assert(aliceShared, bobShared)
        @Assert(bytesToHex(aliceShared), "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742")
    }

    @TestCase
    public func testClampAndGeneratePrivateKey(): Unit {
        let raw = Array<Byte>(X25519_KEY_LEN, repeat: UInt8(0xff))
        let clamped = x25519ClampPrivateKey(raw)
        @Assert(UInt8(clamped[0]) & UInt8(0x07), UInt8(0))
        @Assert(UInt8(clamped[31]) & UInt8(0x80), UInt8(0))
        @Assert(UInt8(clamped[31]) & UInt8(0x40), UInt8(0x40))

        let generated = x25519GeneratePrivateKey()
        @Assert(generated.size, X25519_KEY_LEN)
        @Assert(UInt8(generated[0]) & UInt8(0x07), UInt8(0))
        @Assert(UInt8(generated[31]) & UInt8(0x80), UInt8(0))
        @Assert(UInt8(generated[31]) & UInt8(0x40), UInt8(0x40))
    }

    @TestCase
    public func testRejectInvalidLengthAndAllZeroSharedSecret(): Unit {
        try {
            _ = x25519PublicFromPrivate([UInt8(0x01), UInt8(0x02)])
            @Fail("short private key should fail")
        } catch (_: CryptoException) {
            @Assert(true)
        }

        let privateKey = x25519ClampPrivateKey(hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"))
        let lowOrderPoint = Array<Byte>(X25519_KEY_LEN, repeat: 0)
        try {
            _ = x25519DeriveSharedSecret(privateKey, lowOrderPoint)
            @Fail("all-zero shared secret should be rejected")
        } catch (_: CryptoException) {
            @Assert(true)
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

private func bytesToHex(bytes: Array<Byte>): String {
    if (bytes.size == 0) {
        return ""
    }
    let table: Array<String> = [
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9", "a", "b", "c", "d", "e", "f"
    ]
    var out = ""
    for (b in bytes) {
        let value = UInt8(b)
        out += table[Int64((value >> 4) & UInt8(0x0f))]
        out += table[Int64(value & UInt8(0x0f))]
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
