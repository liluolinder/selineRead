package ignite.tests

import ignite.binary.*

@Test
public class BinaryCoseTestSuite {
    @TestCase
    public func testDecodeEs256P256Ec2PublicKey(): Unit {
        let key = decodeCoseEc2PublicKey(coseHexToBytes(
            "a50102032620012158200102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202258202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
        ))

        @Assert(key.keyType, CoseKeyType.Ec2)
        @Assert(key.algorithm, CoseAlgorithm.Es256)
        @Assert(key.curve, CoseCurve.P256)
        @Assert(coseBytesToHex(key.x), "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20")
        @Assert(coseBytesToHex(key.y), "2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40")
    }

    @TestCase
    public func testDecodeRejectsWrongRootKindAndTrailingData(): Unit {
        assertCoseFailure(coseHexToBytes("83010203"), CoseErrorCode.MalformedInput)
        assertCoseFailure(
            coseHexToBytes(
                "a50102032620012158200102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202258202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f4000"
            ),
            CoseErrorCode.MalformedInput
        )
    }

    @TestCase
    public func testDecodeRejectsUnsupportedKtyAlgAndCurve(): Unit {
        assertCoseFailure(
            coseHexToBytes(
                "a50101032620012158200102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202258202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
            ),
            CoseErrorCode.UnsupportedKeyType
        )

        assertCoseFailure(
            coseHexToBytes(
                "a50102032720012158200102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202258202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
            ),
            CoseErrorCode.UnsupportedAlgorithm
        )

        assertCoseFailure(
            coseHexToBytes(
                "a50102032620022158200102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202258202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
            ),
            CoseErrorCode.UnsupportedCurve
        )
    }

    @TestCase
    public func testDecodeRejectsMissingOrWrongCoordinateFields(): Unit {
        assertCoseFailure(
            coseHexToBytes(
                "a40102032620012158200102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
            ),
            CoseErrorCode.MissingField
        )

        assertCoseFailure(
            coseHexToBytes(
                "a501020326200121182a2258202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
            ),
            CoseErrorCode.InvalidField
        )

        assertCoseFailure(
            coseHexToBytes(
                "a501020326200121581f0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2258202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
            ),
            CoseErrorCode.InvalidField
        )
    }
}

func assertCoseFailure(bytes: Array<UInt8>, expectedCode: CoseErrorCode): Unit {
    try {
        let _ = decodeCoseEc2PublicKey(bytes)
        @Fail("COSE decode should have failed")
    } catch (e: CoseException) {
        @Assert(e.code, expectedCode)
    }
}

func coseHexToBytes(input: String): Array<UInt8> {
    let text = input.trimAscii().toAsciiLower()
    let runes = text.toRuneArray()
    if (runes.size == 0 || (runes.size % 2) != 0) {
        throw Exception("hex length must be even and non-empty")
    }
    let out = Array<UInt8>(runes.size / 2, repeat: 0)
    var i: Int64 = 0
    while (i < runes.size) {
        let hi = coseHexNibble(runes[i])
        let lo = coseHexNibble(runes[i + 1])
        if (hi < 0 || lo < 0) {
            throw Exception("invalid hex text")
        }
        out[i / 2] = UInt8((hi << 4) | lo)
        i += 2
    }
    out
}

func coseBytesToHex(input: Array<UInt8>): String {
    let chars = "0123456789abcdef".toRuneArray()
    var out = ""
    for (b in input) {
        let n = Int64(b)
        out += chars[(n >> 4) & 0x0F].toString()
        out += chars[n & 0x0F].toString()
    }
    out
}

func coseHexNibble(ch: Rune): Int64 {
    match (ch) {
        case r'0' => 0
        case r'1' => 1
        case r'2' => 2
        case r'3' => 3
        case r'4' => 4
        case r'5' => 5
        case r'6' => 6
        case r'7' => 7
        case r'8' => 8
        case r'9' => 9
        case r'a' => 10
        case r'b' => 11
        case r'c' => 12
        case r'd' => 13
        case r'e' => 14
        case r'f' => 15
        case _ => -1
    }
}
