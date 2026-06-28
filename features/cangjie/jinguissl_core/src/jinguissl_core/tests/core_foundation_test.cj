package jinguissl_core.tests

import jinguissl_core.crypto.base as corebase
import jinguissl_core.crypto.error.*
import jinguissl_core.crypto.utils.*

@Test
public class CoreFoundationTestSuite {
    @TestCase
    public func testCryptoErrorSurfaceStaysStable(): Unit {
        @Assert(CryptoErrorCode.InvalidArgument.toString(), "INVALID_ARGUMENT")
        @Assert(CryptoErrorCode.OutOfBounds.toString(), "OUT_OF_BOUNDS")
        @Assert(CryptoErrorCode.Unsupported.toString(), "UNSUPPORTED")
    }

    @TestCase
    public func testEndianEnumShape(): Unit {
        @Assert(corebase.Endian.Big.toString(), "BIG")
        @Assert(corebase.Endian.Little.toString(), "LITTLE")
        @Assert(
            corebase.Endian.Big != corebase.Endian.Little,
            true
        )
    }

    @TestCase
    public func testSecureBytesCloneClearAndDestroyLifecycle(): Unit {
        let source: Array<Byte> = [1, 2, 3, 4]
        let secure = corebase.SecureBytes(source)
        source[0] = 9

        let expectedInit: Array<Byte> = [1, 2, 3, 4]
        @Assert(secure.bytes(), expectedInit)
        @Assert(secure.size, 4)
        @Assert(secure.isDestroyed, false)

        secure.clear()
        let expectedCleared: Array<Byte> = [0, 0, 0, 0]
        @Assert(secure.bytes(), expectedCleared)

        secure.destroy()
        @Assert(secure.isDestroyed, true)
        secure.destroy()

        try {
            _ = secure.bytes()
            @Fail("SecureBytes.bytes should fail after destroy")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            secure.setAt(0, 1)
            @Fail("SecureBytes.setAt should fail after destroy")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testSecureBytesBoundsAndFactoryValidation(): Unit {
        let secure = corebase.SecureBytes.withSize(3)
        let expectedZeros: Array<Byte> = [0, 0, 0]
        @Assert(secure.bytes(), expectedZeros)

        try {
            _ = corebase.SecureBytes.withSize(-1)
            @Fail("SecureBytes.withSize should reject negative size")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            secure.setAt(3, 7)
            @Fail("SecureBytes.setAt should reject out-of-range index")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }
    }

    @TestCase
    public func testByteBufferAppendAndClear(): Unit {
        let buffer = corebase.ByteBuffer([1, 2])
        buffer.append(UInt8(3))
        buffer.append([4, 5])
        @Assert(buffer.size, 5)
        let expected: Array<Byte> = [1, 2, 3, 4, 5]
        @Assert(buffer.toArray(), expected)

        buffer.clear()
        @Assert(buffer.size, 0)
        @Assert(buffer.toArray().size, 0)
    }

    @TestCase
    public func testEndianConversionHelpers(): Unit {
        let bytesBE: Array<Byte> = [0x12, 0x34, 0x56, 0x78]
        let bytesLE: Array<Byte> = [0x78, 0x56, 0x34, 0x12]

        @Assert(bytesToUInt32BE(bytesBE), UInt32(0x12345678))
        @Assert(bytesToUInt32LE(bytesLE), UInt32(0x12345678))
        @Assert(uInt32ToBytesBE(0x12345678), bytesBE)
        @Assert(uInt32ToBytesLE(0x12345678), bytesLE)
    }

    @TestCase
    public func testSecureCopyZeroAndConstantTimeHelpers(): Unit {
        let source: Array<Byte> = [1, 2, 3, 4]
        let copied = secureCopy(source)
        @Assert(copied, source)

        source[0] = 9
        @Assert(copied[0], UInt8(1))

        let dst: Array<Byte> = [0, 0, 0, 0, 0, 0]
        secureCopyInto(copied, dst, dstOffset: 2)
        let expectedAfterCopy: Array<Byte> = [0, 0, 1, 2, 3, 4]
        @Assert(dst, expectedAfterCopy)
        @Assert(constantTimeEquals([1, 2, 3], [1, 2, 3]), true)
        @Assert(constantTimeEquals([1, 2, 3], [1, 2, 4]), false)
        @Assert(constantTimeEquals([1, 2, 3], [1, 2]), false)

        secureZero(dst)
        let expectedAfterZero: Array<Byte> = [0, 0, 0, 0, 0, 0]
        @Assert(dst, expectedAfterZero)
    }

    @TestCase
    public func testRandomSeedAndCsprngBoundary(): Unit {
        let seed = randomSeed(size: 16)
        @Assert(seed.size, 16)

        try {
            _ = randomSeed(size: 0)
            @Fail("randomSeed(size: 0) should throw")
        } catch (_: CryptoException) {
            @Assert(true)
        }

        let available = csprngIsAvailable()
        if (available) {
            let out = csprngBytes(32)
            @Assert(out.size, 32)
        } else {
            try {
                _ = csprngBytes(32)
                @Fail("csprngBytes should fail when backend is unavailable")
            } catch (e: CryptoException) {
                @Assert(e.code.toString(), "UNSUPPORTED")
            }
        }
    }

    @TestCase
    public func testBoundsChecks(): Unit {
        try {
            _ = bytesToUInt32BE([1, 2, 3], offset: 0)
            @Fail("bytesToUInt32BE should throw on short input")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }

        try {
            let dst: Array<Byte> = [0, 0]
            secureCopyInto([1, 2, 3], dst)
            @Fail("secureCopyInto should throw when destination is too small")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }
    }
}
