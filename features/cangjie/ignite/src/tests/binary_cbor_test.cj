package ignite.tests

import ignite.binary.*

@Test
public class BinaryCborTestSuite {
    @TestCase
    public func testDecodeSimpleScalarKinds(): Unit {
        let uintValue = decodeCbor(hexToBytes("0a"))
        @Assert(uintValue.kind, CborKind.UnsignedInt)
        @Assert(uintValue.asUnsignedInt() ?? -1, 10)

        let negativeValue = decodeCbor(hexToBytes("21"))
        @Assert(negativeValue.kind, CborKind.NegativeInt)
        @Assert(negativeValue.asNegativeInt() ?? 0, -2)

        let byteStringValue = decodeCbor(hexToBytes("43010203"))
        @Assert(byteStringValue.kind, CborKind.ByteString)
        let bytes = byteStringValue.asByteString() ?? []
        @Assert(bytes.size, 3)
        @Assert(Int64(bytes[0]), 1)
        @Assert(Int64(bytes[2]), 3)

        let textValue = decodeCbor(hexToBytes("63666d74"))
        @Assert(textValue.kind, CborKind.TextString)
        @Assert(textValue.asTextString() ?? "", "fmt")
    }

    @TestCase
    public func testDecodeArrayAndOrderedMap(): Unit {
        let arrayValue = decodeCbor(hexToBytes("8301616142ff00"))
        @Assert(arrayValue.kind, CborKind.ArrayValue)
        let items = arrayValue.asArray() ?? []
        @Assert(items.size, 3)
        @Assert(items[0].asUnsignedInt() ?? -1, 1)
        @Assert(items[1].asTextString() ?? "", "a")
        @Assert(bytesToHex(items[2].asByteString() ?? []), "ff00")

        let mapValue = decodeCborMap(hexToBytes("a263666d74646e6f6e6568617574684461746143010203"))
        @Assert(mapValue.kind, CborKind.MapValue)
        @Assert((mapValue.getTextKey("fmt") ?? CborValue.textString("missing")).asTextString() ?? "", "none")
        @Assert(
            bytesToHex((mapValue.getTextKey("authData") ?? CborValue.byteString([UInt8(0xEE)])).asByteString() ?? []),
            "010203"
        )
    }

    @TestCase
    public func testDecodeIntegerKeyedMapForCoseLikeShape(): Unit {
        let mapValue = decodeCborMap(hexToBytes("a3010203" + "262043010203"))
        @Assert((mapValue.getIntKey(1) ?? CborValue.unsignedInt(0)).asUnsignedInt() ?? -1, 2)
        @Assert((mapValue.getIntKey(3) ?? CborValue.negativeInt(-1)).asNegativeInt() ?? 0, -7)
        @Assert(
            bytesToHex((mapValue.getIntKey(-1) ?? CborValue.byteString([UInt8(0xEE)])).asByteString() ?? []),
            "010203"
        )
    }

    @TestCase
    public func testDecodeRejectsIndefiniteLengthAndTrailingData(): Unit {
        assertCborFailure(hexToBytes("9f0102ff"), CborErrorCode.UnsupportedLength)
        assertCborFailure(hexToBytes("0102"), CborErrorCode.TrailingData)
    }

    @TestCase
    public func testDecodeRespectsConfiguredDepthLimit(): Unit {
        let option = CborDecodeOption(maxDepth: 1)
        assertCborFailure(hexToBytes("818101"), CborErrorCode.LimitExceeded, option: option)
    }
}

func assertCborFailure(
    bytes: Array<UInt8>,
    expectedCode: CborErrorCode,
    option!: CborDecodeOption = CborDecodeOption()
): Unit {
    try {
        let _ = decodeCbor(bytes, option: option)
        @Fail("CBOR decode should have failed")
    } catch (e: CborException) {
        @Assert(e.code, expectedCode)
    }
}

func hexToBytes(input: String): Array<UInt8> {
    let text = input.trimAscii().toAsciiLower()
    let runes = text.toRuneArray()
    if (runes.size == 0 || (runes.size % 2) != 0) {
        throw Exception("hex length must be even and non-empty")
    }
    let out = Array<UInt8>(runes.size / 2, repeat: 0)
    var i: Int64 = 0
    while (i < runes.size) {
        let hi = hexNibble(runes[i])
        let lo = hexNibble(runes[i + 1])
        if (hi < 0 || lo < 0) {
            throw Exception("invalid hex text")
        }
        out[i / 2] = UInt8((hi << 4) | lo)
        i += 2
    }
    out
}

func bytesToHex(input: Array<UInt8>): String {
    let chars = "0123456789abcdef".toRuneArray()
    var out = ""
    for (b in input) {
        let n = Int64(b)
        out += chars[(n >> 4) & 0x0F].toString()
        out += chars[n & 0x0F].toString()
    }
    out
}

func hexNibble(ch: Rune): Int64 {
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
