package ignite.tests

import ignite.binary.*

@Test
public class BinaryHelperTestSuite {
    @TestCase
    public func testBase64UrlRoundTripWithoutPadding(): Unit {
        let raw = "ignite-binary".toArray()
        let encoded = base64UrlEncode(raw)
        @Assert(encoded, "aWduaXRlLWJpbmFyeQ")
        @Assert(String.fromUtf8(base64UrlDecode(encoded)), "ignite-binary")
    }

    @TestCase
    public func testBase64UrlRejectsMalformedInput(): Unit {
        try {
            let _ = base64UrlDecode("A")
            @Fail("invalid base64url length should fail")
        } catch (_: Exception) {
            @Assert(true)
        }

        try {
            let _ = base64UrlDecode("abcd*")
            @Fail("invalid base64url character should fail")
        } catch (_: Exception) {
            @Assert(true)
        }
    }

    @TestCase
    public func testCloneAndSliceBytesKeepIndependentCopies(): Unit {
        let source = Array<UInt8>(5, repeat: 0)
        source[0] = UInt8(10)
        source[1] = UInt8(20)
        source[2] = UInt8(30)
        source[3] = UInt8(40)
        source[4] = UInt8(50)

        let cloned = cloneBytes(source)
        let sliced = sliceBytes(source, 1, end: 4)
        source[1] = UInt8(99)

        @Assert(Int64(cloned[1]), 20)
        @Assert(sliced.size, 3)
        @Assert(Int64(sliced[0]), 20)
        @Assert(Int64(sliced[2]), 40)
    }

    @TestCase
    public func testReadUintBigEndianHelpers(): Unit {
        let bytes = [UInt8(0x01), UInt8(0x02), UInt8(0x03), UInt8(0x04), UInt8(0x05)]
        @Assert(Int64(readUint16BE(bytes, 1)), 0x0203)
        @Assert(Int64(readUint32BE(bytes, 1)), 0x02030405)
    }

    @TestCase
    public func testReadUintBigEndianBoundsCheck(): Unit {
        try {
            let _ = readUint32BE([UInt8(1), UInt8(2), UInt8(3)], 0)
            @Fail("out-of-range read should fail")
        } catch (_: Exception) {
            @Assert(true)
        }
    }
}
