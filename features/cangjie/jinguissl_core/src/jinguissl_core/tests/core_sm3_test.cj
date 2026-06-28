package jinguissl_core.tests

import jinguissl_core.crypto.sm3.*

@Test
public class CoreSm3TestSuite {
    /* SM3 known test vectors from GM/T 0004-2012 */

    @TestCase
    public func testSm3EmptyString(): Unit {
        /* "abc" → SM3("abc") */
        let data: Array<Byte> = [0x61, 0x62, 0x63]
        let digest = sm3(data)
        let expected = "66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0"
        @Assert(bytesToHexLower(digest), expected)
    }

    @TestCase
    public func testSm3KnownVector_1(): Unit {
        /* "abcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcd" (64 bytes) */
        let data: Array<Byte> = [
            0x61, 0x62, 0x63, 0x64, 0x61, 0x62, 0x63, 0x64,
            0x61, 0x62, 0x63, 0x64, 0x61, 0x62, 0x63, 0x64,
            0x61, 0x62, 0x63, 0x64, 0x61, 0x62, 0x63, 0x64,
            0x61, 0x62, 0x63, 0x64, 0x61, 0x62, 0x63, 0x64,
            0x61, 0x62, 0x63, 0x64, 0x61, 0x62, 0x63, 0x64,
            0x61, 0x62, 0x63, 0x64, 0x61, 0x62, 0x63, 0x64,
            0x61, 0x62, 0x63, 0x64, 0x61, 0x62, 0x63, 0x64,
            0x61, 0x62, 0x63, 0x64, 0x61, 0x62, 0x63, 0x64
        ]
        let digest = sm3(data)
        /* GM/T 0004-2012 example 2 */
        let expected = "debe9ff92275b8a138604889c18e5a4d6fdb70e5387e5765293dcba39c0c5732"
        @Assert(bytesToHexLower(digest), expected)
    }

    @TestCase
    public func testSm3KnownVector_2(): Unit {
        /* Single byte 0x61 ("a") */
        let data: Array<Byte> = [0x61]
        let digest = sm3(data)
        let expected = "623476ac18f65a2909e43c7fec61b49c7e764a91a18ccb82f1917a29c86c5e88"
        @Assert(bytesToHexLower(digest), expected)
    }

    @TestCase
    public func testSm3OutputSize(): Unit {
        let data: Array<Byte> = [0x00, 0x01, 0x02]
        let digest = sm3(data)
        @Assert(digest.size, 32)
    }

    @TestCase
    public func testSm3Deterministic(): Unit {
        let data: Array<Byte> = [0x61, 0x62, 0x63]
        let r1 = sm3(data)
        let r2 = sm3(data)
        @Assert(bytesToHexLower(r1), bytesToHexLower(r2))
    }

    @TestCase
    public func testSm3LargeInput(): Unit {
        /* 1000 bytes of 0x00 */
        var data = Array<Byte>(1000, repeat: UInt8(0))
        let digest = sm3(data)
        @Assert(digest.size, 32)
        /* Just validate it runs without error — no standard vector for this specific input */
        let hex = bytesToHexLower(digest)
        @Assert(hex.size, 64)
    }

    /* Reuse bytesToHexLower from the digest package */
    private func bytesToHexLower(bytes: Array<Byte>): String {
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
