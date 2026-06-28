package jinguissl_core.tests

import jinguissl_core.crypto.aes.*
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.digest.bytesToHexLower
import jinguissl_core.crypto.error.CryptoException

private let TEST_HEX_AES_BLOCK: String = "0011" + "2233" + "445566778899aabbccddeeff"

@Test
public class AesTestSuite {
    @TestCase
    public func testAesSingleBlockVectors(): Unit {
        let pt = hexToBytes(TEST_HEX_AES_BLOCK)

        let k128 = hexToBytes("000102030405060708090a0b0c0d0e0f")
        let c128 = aesBlockEncrypt(k128, pt)
        assertHex(c128, "69c4e0d86a7b0430d8cdb78070b4c55a")
        @Assert(aesBlockDecrypt(k128, c128), pt)

        let k192 = hexToBytes("000102030405060708090a0b0c0d0e0f1011121314151617")
        let c192 = aesBlockEncrypt(k192, pt)
        assertHex(c192, "dda97ca4864cdfe06eaf70a0ec0d7191")
        @Assert(aesBlockDecrypt(k192, c192), pt)

        let k256 = hexToBytes("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
        let c256 = aesBlockEncrypt(k256, pt)
        assertHex(c256, "8ea2b7ca516745bfeafc49904b496089")
        @Assert(aesBlockDecrypt(k256, c256), pt)
    }

    @TestCase
    public func testAesEcbAndPkcs7(): Unit {
        let key = hexToBytes("2b7e151628aed2a6abf7158809cf4f3c")
        let plain = hexToBytes(
            "6bc1bee22e409f96e93d7e117393172a" +
            "ae2d8a571e03ac9c9eb76fac45af8e51" +
            "30c81c46a35ce411e5fbc1191a0a52ef" +
            "f69f2445df4f9b17ad2b417be66c3710"
        )
        let expected = hexToBytes(
            "3ad77bb40d7a3660a89ecaf32466ef97" +
            "f5d3d58503b9699de785895a96fdbaaf" +
            "43b1cd7f598ece23881b00e3ed030688" +
            "7b0c785e27e8ad3f8223207104725dd4"
        )

        let cipher = aesEcbEncrypt(key, plain)
        @Assert(cipher, expected)
        @Assert(aesEcbDecrypt(key, cipher), plain)

        let padded = aesEcbEncrypt(key, "hello aes".toArray(), pkcs7: true)
        @Assert(aesEcbDecrypt(key, padded, pkcs7: true), "hello aes".toArray())
    }

    @TestCase
    public func testAesCbcVector(): Unit {
        let key = hexToBytes("2b7e151628aed2a6abf7158809cf4f3c")
        let iv = hexToBytes("000102030405060708090a0b0c0d0e0f")
        let plain = hexToBytes(
            "6bc1bee22e409f96e93d7e117393172a" +
            "ae2d8a571e03ac9c9eb76fac45af8e51" +
            "30c81c46a35ce411e5fbc1191a0a52ef" +
            "f69f2445df4f9b17ad2b417be66c3710"
        )
        let expected = hexToBytes(
            "7649abac8119b246cee98e9b12e9197d" +
            "5086cb9b507219ee95db113a917678b2" +
            "73bed6b8e3c1743b7116e69e22229516" +
            "3ff1caa1681fac09120eca307586e1a7"
        )

        let cipher = aesCbcEncrypt(key, iv, plain)
        @Assert(cipher, expected)
        @Assert(aesCbcDecrypt(key, iv, cipher), plain)

        let padded = aesCbcEncrypt(key, iv, "hello cbc".toArray(), pkcs7: true)
        @Assert(aesCbcDecrypt(key, iv, padded, pkcs7: true), "hello cbc".toArray())
    }

    @TestCase
    public func testAesCtrVector(): Unit {
        let key = hexToBytes("2b7e151628aed2a6abf7158809cf4f3c")
        let counter = hexToBytes("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
        let plain = hexToBytes(
            "6bc1bee22e409f96e93d7e117393172a" +
            "ae2d8a571e03ac9c9eb76fac45af8e51" +
            "30c81c46a35ce411e5fbc1191a0a52ef" +
            "f69f2445df4f9b17ad2b417be66c3710"
        )
        let expected = hexToBytes(
            "874d6191b620e3261bef6864990db6ce" +
            "9806f66b7970fdff8617187bb9fffdff" +
            "5ae4df3edbd5d35e5b4f09020db03eab" +
            "1e031dda2fbe03d1792170a0f3009cee"
        )

        let cipher = aesCtrCrypt(key, counter, plain)
        @Assert(cipher, expected)
        @Assert(aesCtrCrypt(key, counter, cipher), plain)
    }

    @TestCase
    public func testAesGcmVectorsAndTagCheck(): Unit {
        let key1 = hexToBytes("00000000000000000000000000000000")
        let iv1 = hexToBytes("000000000000000000000000")
        let pt1 = hexToBytes("00000000000000000000000000000000")
        let (ct1, tag1) = aesGcmEncrypt(key1, iv1, pt1)
        assertHex(ct1, "0388dace60b6a392f328c2b971b2fe78")
        assertHex(tag1, "ab6e47d42cec13bdf53a67b21257bddf")
        @Assert(aesGcmDecrypt(key1, iv1, ct1, tag1), pt1)

        let key2 = hexToBytes("feffe9928665731c6d6a8f9467308308")
        let iv2 = hexToBytes("cafebabefacedbaddecaf888")
        let aad2 = hexToBytes("feedfacedeadbeeffeedfacedeadbeefabaddad2")
        let pt2 = hexToBytes(
            "d9313225f88406e5a55909c5aff5269a" +
            "86a7a9531534f7da2e4c303d8a318a72" +
            "1c3c0c95956809532fcf0e2449a6b525" +
            "b16aedf5aa0de657ba637b39"
        )
        let expectedCt2 = "42831ec2217774244b7221b784d0d49c" +
            "e3aa212f2c02a4e035c17e2329aca12e" +
            "21d514b25466931c7d8f6a5aac84aa05" +
            "1ba30b396a0aac973d58e091"
        let expectedTag2 = "5bc94fbc3221a5db94fae95ae7121a47"

        let (ct2, tag2) = aesGcmEncrypt(key2, iv2, pt2, aad: aad2)
        assertHex(ct2, expectedCt2)
        assertHex(tag2, expectedTag2)
        @Assert(aesGcmDecrypt(key2, iv2, ct2, tag2, aad: aad2), pt2)

        let badTag = tag2.clone()
        badTag[0] = UInt8(badTag[0]) ^ UInt8(0x01)
        try {
            _ = aesGcmDecrypt(key2, iv2, ct2, badTag, aad: aad2)
            @Fail("aesGcmDecrypt should fail with wrong tag")
        } catch (_: CryptoException) {
            @Assert(true)
        }
    }

    @TestCase
    public func testAesGcmContextAndSchedulePath(): Unit {
        let key = hexToBytes("feffe9928665731c6d6a8f9467308308")
        let iv = hexToBytes("cafebabefacedbaddecaf888")
        let aad = hexToBytes("feedfacedeadbeeffeedfacedeadbeefabaddad2")
        let pt = hexToBytes(
            "d9313225f88406e5a55909c5aff5269a" +
            "86a7a9531534f7da2e4c303d8a318a72" +
            "1c3c0c95956809532fcf0e2449a6b525" +
            "b16aedf5aa0de657ba637b39"
        )

        let schedule = aesPrepareKey(key)
        let ctx = AesGcmContext(schedule)
        let (ct, tag) = aesGcmEncryptWithContext(ctx, iv, pt, aad: aad)

        let expectedCt = "42831ec2217774244b7221b784d0d49c" +
            "e3aa212f2c02a4e035c17e2329aca12e" +
            "21d514b25466931c7d8f6a5aac84aa05" +
            "1ba30b396a0aac973d58e091"
        let expectedTag = "5bc94fbc3221a5db94fae95ae7121a47"
        assertHex(ct, expectedCt)
        assertHex(tag, expectedTag)
        @Assert(aesGcmDecryptWithContext(ctx, iv, ct, tag, aad: aad), pt)
    }

    @TestCase
    public func testAesGcmIntoApis(): Unit {
        let key = hexToBytes("feffe9928665731c6d6a8f9467308308")
        let iv = hexToBytes("cafebabefacedbaddecaf888")
        let aad = hexToBytes("feedfacedeadbeeffeedfacedeadbeefabaddad2")
        let pt = hexToBytes(
            "d9313225f88406e5a55909c5aff5269a" +
            "86a7a9531534f7da2e4c303d8a318a72" +
            "1c3c0c95956809532fcf0e2449a6b525" +
            "b16aedf5aa0de657ba637b39"
        )
        let expectedCt = "42831ec2217774244b7221b784d0d49c" +
            "e3aa212f2c02a4e035c17e2329aca12e" +
            "21d514b25466931c7d8f6a5aac84aa05" +
            "1ba30b396a0aac973d58e091"
        let expectedTag = "5bc94fbc3221a5db94fae95ae7121a47"

        let ctx = aesNewGcmContext(key)
        let ct = Array<Byte>(pt.size, repeat: 0)
        let tag = Array<Byte>(16, repeat: 0)
        aesGcmEncryptIntoWithContext(ctx, iv, pt, ct, tag, aad: aad)
        assertHex(ct, expectedCt)
        assertHex(tag, expectedTag)

        let recovered = Array<Byte>(pt.size, repeat: 0)
        aesGcmDecryptIntoWithContext(ctx, iv, ct, tag, recovered, aad: aad)
        @Assert(recovered, pt)

        let profile = FipsProfile.phase1Default()
        let ctChecked = Array<Byte>(pt.size, repeat: 0)
        let tagChecked = Array<Byte>(16, repeat: 0)
        aesGcmEncryptIntoWithContextChecked(profile, ctx, iv, pt, ctChecked, tagChecked, aad: aad)
        @Assert(ctChecked, ct)
        @Assert(tagChecked, tag)

        let recoveredChecked = Array<Byte>(pt.size, repeat: 0)
        aesGcmDecryptIntoWithContextChecked(profile, ctx, iv, ctChecked, tagChecked, recoveredChecked, aad: aad)
        @Assert(recoveredChecked, pt)

        try {
            aesGcmEncryptIntoWithContext(ctx, iv, pt, Array<Byte>(pt.size - 1, repeat: 0), Array<Byte>(16, repeat: 0), aad: aad)
            @Fail("AES-GCM into encrypt must reject short ciphertext output")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            aesGcmEncryptIntoWithContext(ctx, iv, pt, Array<Byte>(pt.size, repeat: 0), Array<Byte>(8, repeat: 0), aad: aad, tagLen: 16)
            @Fail("AES-GCM into encrypt must reject short tag output")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            aesGcmDecryptIntoWithContext(ctx, iv, ct, tag, Array<Byte>(pt.size - 1, repeat: 0), aad: aad)
            @Fail("AES-GCM into decrypt must reject short plaintext output")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testAesEngineSelectionAndEnforcement(): Unit {
        @Assert(aesCurrentEngineKind(hardwareHint: "none").toString(), "SOFTWARE")
        @Assert(aesHardwareAvailable(hardwareHint: "none"), false)
        @Assert(aesProbeHardware(backendHint: "none").backend, "none")

        let key = hexToBytes("000102030405060708090a0b0c0d0e0f")
        let schedule = aesPrepareKey(key, requestedEngine: SOFTWARE, hardwareHint: "none")
        @Assert(schedule.engine.active.toString(), "SOFTWARE")
        @Assert(schedule.engine.backend, "none")

        let ctx = aesNewGcmContext(key, requestedEngine: AUTO, hardwareHint: "none")
        @Assert(ctx.engine.active.toString(), "SOFTWARE")
        @Assert(ctx.engine.backend, "none")

        try {
            _ = aesPrepareKey(key, requestedEngine: HARDWARE, hardwareHint: "none")
            @Fail("HARDWARE engine must fail when hardware is unavailable")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testAesHardwareShimSelection(): Unit {
        let key = hexToBytes("000102030405060708090a0b0c0d0e0f")
        let iv = hexToBytes("000000000000000000000000")
        let pt = hexToBytes(TEST_HEX_AES_BLOCK)
        let mounts = aesListHardwareMountPoints()
        @Assert(mounts.size >= 3, true)
        @Assert(mounts[0].backend, "aesni")
        @Assert(mounts[1].backend, "armv8-ce")
        @Assert(mounts[2].backend, "shim")
        @Assert(mounts[2].available, true)
        @Assert(mounts[2].accelerated, false)
        @Assert(mounts[2].detected, true)
        @Assert(aesDefaultHardwareBackendHint(), expectedDefaultAesHardwareBackendHint())

        let probe = aesProbeHardware(backendHint: "shim")
        @Assert(probe.available, true)
        @Assert(probe.backend, "shim")
        @Assert(probe.accelerated, false)

        let bridge = AesNativeBridgeSpec(
            "aesni",
            "/opt/jinkui/lib/libjinguissl_aesni.dylib",
            symbolPrefix: "jinkui_aes"
        )
        let contract = aesBuildNativeBridgeContract(bridge)
        @Assert(contract.backend, "aesni")
        @Assert(contract.abiVersion, 1)
        @Assert(contract.expandKeySymbol, "jinkui_aes_expand_key")
        @Assert(contract.encryptBlocksSymbol, "jinkui_aes_encrypt_blocks")
        @Assert(contract.decryptBlocksSymbol, "jinkui_aes_decrypt_blocks")
        @Assert(contract.ghashMulSymbol, "jinkui_aes_ghash_mul")

        let bridgeProbe = aesProbeHardwareWithNativeBridge(bridge)
        @Assert(bridgeProbe.available, true)
        @Assert(bridgeProbe.backend, "aesni")
        @Assert(bridgeProbe.accelerated, false)

        let bridgeEngine = aesResolveEngineWithNativeBridge(bridge, requested: HARDWARE)
        @Assert(bridgeEngine.active.toString(), "HARDWARE")
        @Assert(bridgeEngine.backend, "aesni")
        @Assert(bridgeEngine.accelerated, false)

        let engine = aesResolveEngine(requested: HARDWARE, hardwareHint: "shim")
        @Assert(engine.active.toString(), "HARDWARE")
        @Assert(engine.backend, "shim")
        @Assert(engine.accelerated, false)

        let schedule = aesPrepareKey(key, requestedEngine: HARDWARE, hardwareHint: "shim")
        @Assert(schedule.engine.active.toString(), "HARDWARE")
        @Assert(schedule.engine.backend, "shim")

        let ctx = aesNewGcmContext(key, requestedEngine: HARDWARE, hardwareHint: "shim")
        @Assert(ctx.engine.active.toString(), "HARDWARE")
        @Assert(ctx.engine.backend, "shim")

        let (ct, tag) = aesGcmEncryptWithContext(ctx, iv, pt)
        @Assert(aesGcmDecryptWithContext(ctx, iv, ct, tag), pt)

        let aesniProbe = aesProbeHardware(backendHint: "aesni")
        @Assert(aesniProbe.available, false)
        @Assert(aesniProbe.backend, "none")

        try {
            _ = AesNativeBridgeSpec("not-supported", "/tmp/libx.dylib")
            @Fail("invalid native bridge backend must be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            _ = aesResolveEngine(requested: HARDWARE, hardwareHint: "invalid-backend")
            @Fail("invalid backend hint must be rejected for HARDWARE selection")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testAesAutomaticDefaultSelection(): Unit {
        let expectedDefault = expectedDefaultAesHardwareBackendHint()
        @Assert(aesDefaultHardwareBackendHint(), expectedDefault)

        let key = hexToBytes("000102030405060708090a0b0c0d0e0f")
        let ctx = aesNewGcmContext(key)
        if (expectedDefault == "armv8-ce") {
            @Assert(ctx.engine.active.toString(), "HARDWARE")
            @Assert(ctx.engine.backend, "armv8-ce")
            @Assert(ctx.engine.accelerated, true)
            return
        }

        @Assert(ctx.engine.active.toString(), "SOFTWARE")
        @Assert(ctx.engine.backend, "none")
    }

    @TestCase
    public func testAesArmv8CeNativeBackendPath(): Unit {
        let probe = aesProbeHardware(backendHint: "armv8-ce")
        if (!probe.available) {
            @Assert(probe.backend, "none")
            @Assert(probe.accelerated, false)
            return
        }
        @Assert(probe.available, true)
        @Assert(probe.backend, "armv8-ce")
        @Assert(probe.accelerated, true)

        let key = hexToBytes("feffe9928665731c6d6a8f9467308308")
        let iv = hexToBytes("cafebabefacedbaddecaf888")
        let aad = hexToBytes("feedfacedeadbeeffeedfacedeadbeefabaddad2")
        let pt = hexToBytes(
            "d9313225f88406e5a55909c5aff5269a" +
            "86a7a9531534f7da2e4c303d8a318a72" +
            "1c3c0c95956809532fcf0e2449a6b525" +
            "b16aedf5aa0de657ba637b39"
        )

        let ctx = aesNewGcmContext(key, requestedEngine: HARDWARE, hardwareHint: "armv8-ce")
        @Assert(ctx.engine.active.toString(), "HARDWARE")
        @Assert(ctx.engine.backend, "armv8-ce")
        @Assert(ctx.engine.accelerated, true)

        let (ct, tag) = aesGcmEncryptWithContext(ctx, iv, pt, aad: aad)
        let expectedCt = "42831ec2217774244b7221b784d0d49c" +
            "e3aa212f2c02a4e035c17e2329aca12e" +
            "21d514b25466931c7d8f6a5aac84aa05" +
            "1ba30b396a0aac973d58e091"
        let expectedTag = "5bc94fbc3221a5db94fae95ae7121a47"
        assertHex(ct, expectedCt)
        assertHex(tag, expectedTag)
        @Assert(aesGcmDecryptWithContext(ctx, iv, ct, tag, aad: aad), pt)
    }

    @TestCase
    public func testAesArmv8CeNativeBridgeRawKeyBlobPath(): Unit {
        let probe = aesProbeHardware(backendHint: "armv8-ce")
        if (!probe.available) {
            @Assert(probe.backend, "none")
            @Assert(probe.accelerated, false)
            return
        }

        let key = hexToBytes("000102030405060708090a0b0c0d0e0f")
        let pt = hexToBytes(TEST_HEX_AES_BLOCK)
        let bridge = AesNativeBridgeSpec("armv8-ce", "")
        let handle = aesOpenNativeBridge(bridge)
        @Assert(handle.probe.backend, "armv8-ce")
        @Assert(handle.probe.available, true)
        @Assert(handle.probe.accelerated, true)

        let shape = aesNativeBridgeDescribeCallShape(handle, key.size)
        @Assert(shape.backend, "armv8-ce")
        @Assert(shape.expandedKeyBlobBytes, 28)
        @Assert(shape.roundCount, 10)
        @Assert(shape.roundKeyWordCount, 44)

        let expanded = aesNativeBridgeExpandKey(handle, key)
        @Assert(expanded.size, 28)
        @Assert(expanded[7], UInt8(1))

        let bridgeCt = aesNativeBridgeEncryptBlocks(handle, expanded, pt)
        let softwareCt = aesEcbEncrypt(key, pt)
        @Assert(bridgeCt, softwareCt)
        @Assert(aesNativeBridgeDecryptBlocks(handle, expanded, bridgeCt), pt)
    }

    @TestCase
    public func testAesArmv8CePointerApiPath(): Unit {
        let probe = aesProbeHardware(backendHint: "armv8-ce")
        if (!probe.available) {
            @Assert(probe.backend, "none")
            @Assert(probe.accelerated, false)
            return
        }

        let key = hexToBytes("feffe9928665731c6d6a8f9467308308")
        let iv = hexToBytes("cafebabefacedbaddecaf888")
        let aad = hexToBytes("feedfacedeadbeeffeedfacedeadbeefabaddad2")
        let pt = hexToBytes(
            "d9313225f88406e5a55909c5aff5269a" +
            "86a7a9531534f7da2e4c303d8a318a72" +
            "1c3c0c95956809532fcf0e2449a6b525" +
            "b16aedf5aa0de657ba637b39"
        )
        let expectedCt = hexToBytes(
            "42831ec2217774244b7221b784d0d49c" +
            "e3aa212f2c02a4e035c17e2329aca12e" +
            "21d514b25466931c7d8f6a5aac84aa05" +
            "1ba30b396a0aac973d58e091"
        )
        let expectedTag = hexToBytes("5bc94fbc3221a5db94fae95ae7121a47")

        let keyPtr = unsafe { LibC.malloc<UInt8>(count: key.size) }
        let ivPtr = unsafe { LibC.malloc<UInt8>(count: iv.size) }
        let aadPtr = unsafe { LibC.malloc<UInt8>(count: aad.size) }
        let ptPtr = unsafe { LibC.malloc<UInt8>(count: pt.size) }
        let ctPtr = unsafe { LibC.malloc<UInt8>(count: pt.size) }
        let tagPtr = unsafe { LibC.malloc<UInt8>(count: 16) }
        let outPtr = unsafe { LibC.malloc<UInt8>(count: pt.size) }
        if (
            keyPtr.isNull() ||
            ivPtr.isNull() ||
            aadPtr.isNull() ||
            ptPtr.isNull() ||
            ctPtr.isNull() ||
            tagPtr.isNull() ||
            outPtr.isNull()
        ) {
            if (keyPtr.isNotNull()) {
                unsafe { LibC.free(keyPtr) }
            }
            if (ivPtr.isNotNull()) {
                unsafe { LibC.free(ivPtr) }
            }
            if (aadPtr.isNotNull()) {
                unsafe { LibC.free(aadPtr) }
            }
            if (ptPtr.isNotNull()) {
                unsafe { LibC.free(ptPtr) }
            }
            if (ctPtr.isNotNull()) {
                unsafe { LibC.free(ctPtr) }
            }
            if (tagPtr.isNotNull()) {
                unsafe { LibC.free(tagPtr) }
            }
            if (outPtr.isNotNull()) {
                unsafe { LibC.free(outPtr) }
            }
            @Fail("native pointer test allocation failed")
            return
        }

        try {
            writeArrayToPointer(key, keyPtr)
            writeArrayToPointer(iv, ivPtr)
            writeArrayToPointer(aad, aadPtr)
            writeArrayToPointer(pt, ptPtr)

            let encryptStatus = unsafe {
                aesArmv8CeGcmEncryptPointers(
                    keyPtr,
                    key.size,
                    ivPtr,
                    iv.size,
                    aadPtr,
                    aad.size,
                    ptPtr,
                    pt.size,
                    ctPtr,
                    tagPtr,
                    16
                )
            }
            @Assert(encryptStatus, Int32(0))
            @Assert(readPointerToArray(ctPtr, pt.size), expectedCt)
            @Assert(readPointerToArray(tagPtr, 16), expectedTag)

            let decryptStatus = unsafe {
                aesArmv8CeGcmDecryptPointers(
                    keyPtr,
                    key.size,
                    ivPtr,
                    iv.size,
                    aadPtr,
                    aad.size,
                    ctPtr,
                    pt.size,
                    tagPtr,
                    16,
                    outPtr
                )
            }
            @Assert(decryptStatus, Int32(0))
            @Assert(readPointerToArray(outPtr, pt.size), pt)
        } finally {
            unsafe { LibC.free(outPtr) }
            unsafe { LibC.free(tagPtr) }
            unsafe { LibC.free(ctPtr) }
            unsafe { LibC.free(ptPtr) }
            unsafe { LibC.free(aadPtr) }
            unsafe { LibC.free(ivPtr) }
            unsafe { LibC.free(keyPtr) }
        }
    }

    @TestCase
    public func testAesNativeBridgeMarshalAndSoftwareDispatch(): Unit {
        let key = hexToBytes("603deb1015ca71be2b73aef0857d7781" + "1f352c073b6108d72d9810a30914dff4")
        let pt = hexToBytes("6bc1bee22e409f96e93d7e117393172a" + "ae2d8a571e03ac9c9eb76fac45af8e51")

        let bridge = AesNativeBridgeSpec("aesni", "/opt/jinkui/lib/libjinguissl_aesni.dylib")
        let handle = aesOpenNativeBridge(bridge)
        @Assert(handle.contract.expandKeySymbol, "jinguissl_aes_expand_key")
        @Assert(handle.probe.backend, "aesni")
        @Assert(handle.probe.available, true)
        @Assert(handle.probe.accelerated, false)

        let shape = aesNativeBridgeDescribeCallShape(handle, key.size)
        @Assert(shape.backend, "aesni")
        @Assert(shape.keyBytes, 32)
        @Assert(shape.roundCount, 14)
        @Assert(shape.roundKeyWordCount, 60)
        @Assert(shape.expandedKeyBlobBytes, 252)
        @Assert(shape.blockBytes, 16)
        @Assert(shape.requiresBlockAlignedPayload, true)

        let expanded = aesNativeBridgeExpandKey(handle, key)
        @Assert(expanded.size, 252)

        let bridgeCt = aesNativeBridgeEncryptBlocks(handle, expanded, pt)
        let softwareCt = aesEcbEncrypt(key, pt)
        @Assert(bridgeCt, softwareCt)

        let recovered = aesNativeBridgeDecryptBlocks(handle, expanded, bridgeCt)
        @Assert(recovered, pt)

        let h = hexToBytes("66e94bd4ef8a2c3b884cfa59ca342b2e")
        let x = hexToBytes("0388dace60b6a392f328c2b971b2fe78")
        let ghashProduct = aesNativeBridgeGhashMul(handle, h, x)
        assertHex(ghashProduct, "5e2ec746917062882c85b0685353deb7")

        let badMagic = expanded.clone()
        badMagic[0] = UInt8(0x00)
        try {
            _ = aesNativeBridgeEncryptBlocks(handle, badMagic, pt)
            @Fail("invalid expanded-key blob magic must be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let badAbi = expanded.clone()
        badAbi[4] = UInt8(0x02)
        try {
            _ = aesNativeBridgeEncryptBlocks(handle, badAbi, pt)
            @Fail("expanded-key blob ABI mismatch must be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        try {
            _ = aesNativeBridgeEncryptBlocks(handle, expanded, pt[..17])
            @Fail("native bridge encrypt must reject non-block-aligned input")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testComplianceCheckedAesRejectsAndAllows(): Unit {
        let profile = FipsProfile.phase1Default()
        let key = hexToBytes("000102030405060708090a0b0c0d0e0f")
        let pt = hexToBytes(TEST_HEX_AES_BLOCK)

        try {
            _ = aesEcbEncryptChecked(profile, key, pt)
            @Fail("AES-ECB should be rejected by default FIPS profile")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }

        let iv = hexToBytes("000000000000000000000000")
        let ctx = aesNewGcmContext(key)
        let (ct, tag) = aesGcmEncryptWithContextChecked(profile, ctx, iv, pt)
        @Assert(aesGcmDecryptWithContextChecked(profile, ctx, iv, ct, tag), pt)
    }

    @TestCase
    public func testComplianceCheckedAesCustomProfile(): Unit {
        let profile = FipsProfile.fromText("AES-ECB")
        let key = hexToBytes("000102030405060708090a0b0c0d0e0f")
        let pt = hexToBytes(TEST_HEX_AES_BLOCK)

        let ct = aesEcbEncryptChecked(profile, key, pt)
        @Assert(aesEcbDecryptChecked(profile, key, ct), pt)

        try {
            _ = aesGcmEncryptChecked(profile, key, hexToBytes("000000000000000000000000"), pt)
            @Fail("AES-GCM should be rejected by custom profile")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }
}

private func assertHex(actual: Array<Byte>, expectedHex: String): Unit {
    @Assert(bytesToHexLower(actual), expectedHex.toAsciiLower())
}

@When[os == "macOS" && arch == "aarch64"]
private func expectedDefaultAesHardwareBackendHint(): String {
    let probe = aesProbeHardware(backendHint: "armv8-ce")
    if (probe.available && probe.accelerated) {
        return "armv8-ce"
    }
    ""
}

@When[os != "macOS" || arch != "aarch64"]
private func expectedDefaultAesHardwareBackendHint(): String {
    ""
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

private func writeArrayToPointer(bytes: Array<Byte>, ptr: CPointer<UInt8>): Unit {
    var i = 0
    while (i < bytes.size) {
        unsafe { ptr.write(i, bytes[i]) }
        i += 1
    }
}

private func readPointerToArray(ptr: CPointer<UInt8>, size: Int64): Array<Byte> {
    let out = Array<Byte>(size, repeat: 0)
    var i = 0
    while (i < size) {
        out[i] = unsafe { ptr.read(i) }
        i += 1
    }
    out
}
