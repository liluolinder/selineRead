package jinguissl_core.tests

import jinguissl_core.compat.bn.*
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.error.CryptoException

@Test
public class CoreBigNumCompatTestSuite {
    @TestCase
    public func testBnNewAndBinaryRoundTrip(): Unit {
        let zero = BN_new()
        let expectedZero: Array<Byte> = [0]
        @Assert(BN_bn2bin(zero), expectedZero)

        let reused = BN_new()
        let parsed = BN_bin2bn([0x12, 0x34], out: reused)
        let expectedBytes: Array<Byte> = [0x12, 0x34]
        @Assert(BN_bn2bin(parsed), expectedBytes)
        @Assert(BN_bn2bin(reused), expectedBytes)
    }

    @TestCase
    public func testBnArithmeticWrappersStayNarrow(): Unit {
        let a = BN_bin2bn([0x0A])
        let b = BN_bin2bn([0x03])
        let expectedAdd: Array<Byte> = [0x0D]
        let expectedSub: Array<Byte> = [0x07]
        let expectedMul: Array<Byte> = [0x1E]
        let expectedQuotient: Array<Byte> = [0x03]
        let expectedRemainder: Array<Byte> = [0x01]

        @Assert(BN_bn2bin(BN_add(a, b)), expectedAdd)
        @Assert(BN_bn2bin(BN_sub(a, b)), expectedSub)
        @Assert(BN_bn2bin(BN_mul(a, b)), expectedMul)

        let (q, r) = BN_div(a, b)
        @Assert(BN_bn2bin(q), expectedQuotient)
        @Assert(BN_bn2bin(r), expectedRemainder)
        @Assert(BN_bn2bin(BN_mod(a, b)), expectedRemainder)
    }

    @TestCase
    public func testBnExpInverseAndShiftSurface(): Unit {
        let base = BN_bin2bn([0x05])
        let exponent = BN_bin2bn([0x03])
        let modulus = BN_bin2bn([0x0D])
        let expectedExp: Array<Byte> = [0x7D]
        let expectedModExp: Array<Byte> = [0x08]
        let expectedInverse: Array<Byte> = [0x08]
        let expectedLShift: Array<Byte> = [0x01, 0x00]
        let expectedRShift: Array<Byte> = [0x10]

        @Assert(BN_bn2bin(BN_exp(base, exponent)), expectedExp)
        @Assert(BN_bn2bin(BN_mod_exp(base, exponent, modulus)), expectedModExp)
        @Assert(BN_bn2bin(BN_mod_inverse(base, modulus)), expectedInverse)
        @Assert(BN_bn2bin(BN_lshift(BN_bin2bn([0x01]), 8)), expectedLShift)
        @Assert(BN_bn2bin(BN_rshift(BN_bin2bn([0x01, 0x00]), 4)), expectedRShift)
    }

    @TestCase
    public func testBigNumCoreHelpersStayStable(): Unit {
        let parsed = BigNum.fromHex("0x00ff")
        @Assert(parsed.toHex(), "ff")

        let left = BigNum.fromHex("10")
        let right = BigNum.fromHex("0f")
        @Assert(left.cmp(right), Int64(1))
        @Assert(right.cmp(left), Int64(-1))
        @Assert(left.cmp(BigNum.fromHex("10")), Int64(0))

        let gcd = BigNum.gcd(BigNum.fromHex("18"), BigNum.fromHex("0c"))
        @Assert(gcd.toHex(), "0c")
    }

    @TestCase
    public func testBigNumModSqrtStaysSelfContained(): Unit {
        let value = BigNum.fromHex("04")
        let prime = BigNum.fromHex("0b")
        let root = BigNum.modSqrt(value, prime)
        let squared = root.mul(root).mod(prime)
        @Assert(squared.toHex(), "04")
    }

    @TestCase
    public func testBigNumBoundaryFailuresStayExplicit(): Unit {
        try {
            _ = BigNum.fromHex("")
            @Fail("BigNum.fromHex should reject empty input")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        try {
            _ = BN_div(BN_bin2bn([0x01]), BN_new())
            @Fail("BN_div should reject divide-by-zero")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "DIVIDE_BY_ZERO")
        }
    }

    @TestCase
    public func testModInversePrimeFixedSchedule(): Unit {
        func check(value: BigNum, p: BigNum, bitLen: Int64): Unit {
            let expected = value.modInverse(p)
            let got = value.modInversePrimeFixedSchedule(p, bitLen)
            if (got.toHex() != expected.toHex()) {
                @Fail("modInversePrimeFixedSchedule expected ${expected.toHex()} got ${got.toHex()}")
            }
        }

        let p13 = BigNum.fromHex("0d")
        check(BigNum.fromHex("05"), p13, 4)
        check(BigNum.one(), p13, 4)
        check(BigNum.fromHex("0c"), p13, 4)

        let p251 = BigNum.fromHex("fb")
        check(BigNum.fromHex("03"), p251, 8)

        let p25519 = BigNum.fromHex("7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed")
        check(BigNum.fromHex("02"), p25519, 255)
        check(BigNum.fromHex("05"), p25519, 255)
        check(BigNum.one(), p25519, 255)

        let p3 = BigNum.fromHex("03")
        check(BigNum.fromHex("02"), p3, 2)
    }

    @TestCase
    public func testModInversePrimeFixedScheduleRejectsInvalidInputs(): Unit {
        try {
            _ = BigNum.fromHex("02").modInversePrimeFixedSchedule(BigNum.fromHex("00"), 1)
            @Fail("modInversePrimeFixedSchedule should reject zero modulus")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            _ = BigNum.fromHex("02").modInversePrimeFixedSchedule(BigNum.fromHex("04"), 3)
            @Fail("modInversePrimeFixedSchedule should reject even modulus")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            _ = BigNum.fromHex("02").modInversePrimeFixedSchedule(BigNum.fromHex("0d"), 0)
            @Fail("modInversePrimeFixedSchedule should reject non-positive bitLength")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            _ = BigNum.fromHex("0d").modInversePrimeFixedSchedule(BigNum.fromHex("0d"), 4)
            @Fail("modInversePrimeFixedSchedule should reject non-invertible value")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "NO_MOD_INVERSE")
        }
    }
}
