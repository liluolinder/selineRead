package jinguissl.tests

import jinguissl.contract.*

/**
 * Contract-digest wrapper test suite.
 *
 * Each test delegates to the same core implementation tested by
 * CoreDigestTestSuite. These tests verify that the contract wrappers
 * (contractSha256, contractHash, contractHmac, etc.) route correctly
 * through to core and produce identical output.
 */
@Test
public class ContractDigestTestSuite {
    @TestCase
    public func testContractSha256EmptyStringKnownVector(): Unit {
        let empty: Array<Byte> = []
        let digest = contractSha256(empty)
        let hex = contractBytesToHexLower(digest)
        @Assert(hex, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @TestCase
    public func testContractSha384EmptyStringKnownVector(): Unit {
        let empty: Array<Byte> = []
        let digest = contractSha384(empty)
        let hex = contractBytesToHexLower(digest)
        @Assert(hex, "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b")
    }

    @TestCase
    public func testContractSha512EmptyStringKnownVector(): Unit {
        let empty: Array<Byte> = []
        let digest = contractSha512(empty)
        let hex = contractBytesToHexLower(digest)
        @Assert(hex, "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e")
    }

    @TestCase
    public func testContractHashDispatcherRoutesCorrectly(): Unit {
        let empty: Array<Byte> = []
        @Assert(contractBytesToHexLower(contractHash(HashAlgorithm.MD5, empty)), "d41d8cd98f00b204e9800998ecf8427e")
        @Assert(contractBytesToHexLower(contractHash(HashAlgorithm.SHA1, empty)), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
        @Assert(contractBytesToHexLower(contractHash(HashAlgorithm.SHA256, empty)), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        @Assert(contractBytesToHexLower(contractHash(HashAlgorithm.SHA384, empty)), "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b")
        @Assert(contractBytesToHexLower(contractHash(HashAlgorithm.SHA512, empty)), "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e")
    }

    @TestCase
    public func testContractSha256KnownDataVector(): Unit {
        let data: Array<Byte> = [0x61, 0x62, 0x63] // "abc"
        let digest = contractSha256(data)
        let hex = contractBytesToHexLower(digest)
        @Assert(hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @TestCase
    public func testContractBytesToHexEdgeCases(): Unit {
        @Assert(contractBytesToHexLower([]), "")
        @Assert(contractBytesToHexLower([0x00]), "00")
        @Assert(contractBytesToHexLower([0xff]), "ff")
        @Assert(contractBytesToHexLower([0xab, 0xcd, 0xef]), "abcdef")
    }

    @TestCase
    public func testContractHmacSha256KnownVector(): Unit {
        let key: Array<Byte> = [0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
                                 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
                                 0x0b, 0x0b, 0x0b, 0x0b]
        let data: Array<Byte> = [0x48, 0x69, 0x20, 0x54, 0x68, 0x65, 0x72, 0x65] // "Hi There"
        let expected = "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
        let result = contractHmac(HashAlgorithm.SHA256, key, data)
        @Assert(contractBytesToHexLower(result), expected)
    }

    @TestCase
    public func testContractHkdfExtractExpandRoundtrip(): Unit {
        let ikm: Array<Byte> = [0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
                                 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
                                 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b]
        let salt: Array<Byte> = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                                 0x08, 0x09, 0x0a, 0x0b, 0x0c]
        let info: Array<Byte> = [0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7,
                                 0xf8, 0xf9]
        let prk = contractHkdfExtract(HashAlgorithm.SHA256, salt, ikm)
        @Assert(prk.size > 0, true)
        let okm = contractHkdfExpand(HashAlgorithm.SHA256, prk, info, 42)
        @Assert(okm.size, 42)
    }

    @TestCase
    public func testContractHkdfFull(): Unit {
        let ikm: Array<Byte> = [0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
                                 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
                                 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b]
        let salt: Array<Byte> = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                                 0x08, 0x09, 0x0a, 0x0b, 0x0c]
        let info: Array<Byte> = [0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7,
                                 0xf8, 0xf9]
        let okm = contractHkdf(HashAlgorithm.SHA256, ikm, info, 42, salt: salt)
        @Assert(okm.size, 42)
    }

    @TestCase
    public func testContractHkdfEmptySalt(): Unit {
        let prk = contractHkdfExtract(HashAlgorithm.SHA256, [], [0x01, 0x02])
        @Assert(prk.size, 32)
    }

    @TestCase
    public func testContractHkdfExpandZeroOutput(): Unit {
        let prk = Array<Byte>(32, repeat: 0xab)
        let result = contractHkdfExpand(HashAlgorithm.SHA256, prk, [], 0)
        @Assert(result.size, 0)
    }
}
