package canghui_scene3d_bgfx

import std.fs.{File, exists, removeIfExists}

@Test
func bgfxTgaConvertsToBmpWithRowsAndDimensionsPreserved(): Unit {
    let tga = "/tmp/canghui-scene3d-bgfx-valid.tga"
    let bmp = "/tmp/canghui-scene3d-bgfx-valid.bmp"
    removeIfExists(tga)
    removeIfExists(bmp)
    let bytes = tgaFixture(2, 2, 32)
    File.writeTo(tga, bytes)

    convertBgfxTgaToBmp(tga, bmp)
    @Expect(exists(bmp))
    let output = File.readFrom(bmp)
    @Expect(output.size, Int64(70))
    @Expect(output[0], UInt8(0x42))
    @Expect(output[1], UInt8(0x4D))
    @Expect(output[18], UInt8(2))
    @Expect(output[22], UInt8(2))
    @Expect(output[54], UInt8(9))
    @Expect(output[62], UInt8(1))
    removeIfExists(tga)
    removeIfExists(bmp)
}

@Test
func bgfxTgaRejectsTruncatedPayload(): Unit {
    expectTgaRejected([UInt8(0), UInt8(0), UInt8(2)])
}

@Test
func bgfxTgaRejectsUnsupportedPixelDepth(): Unit {
    expectTgaRejected(tgaFixture(1, 1, 24))
}

@Test
func bgfxTgaRejectsMissingInput(): Unit {
    let tga = "/tmp/canghui-scene3d-bgfx-missing.tga"
    let bmp = "/tmp/canghui-scene3d-bgfx-missing.bmp"
    removeIfExists(tga)
    removeIfExists(bmp)
    var rejected = false
    try {
        convertBgfxTgaToBmp(tga, bmp)
    } catch (_: Exception) {
        rejected = true
    }
    @Expect(rejected)
    @Expect(!exists(bmp))
}

private func expectTgaRejected(bytes: Array<UInt8>): Unit {
    let tga = "/tmp/canghui-scene3d-bgfx-invalid.tga"
    let bmp = "/tmp/canghui-scene3d-bgfx-invalid.bmp"
    removeIfExists(tga)
    removeIfExists(bmp)
    File.writeTo(tga, bytes)
    var rejected = false
    try {
        convertBgfxTgaToBmp(tga, bmp)
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
    @Expect(!exists(bmp))
    removeIfExists(tga)
}

private func tgaFixture(width: Int64, height: Int64, bits: Int64): Array<UInt8> {
    let pixelBytes = if (bits == 32) { width * height * 4 } else { width * height * 3 }
    let bytes = Array<UInt8>(18 + pixelBytes, repeat: UInt8(0))
    bytes[2] = UInt8(2)
    bytes[12] = UInt8(width & 0xFF)
    bytes[13] = UInt8((width >> 8) & 0xFF)
    bytes[14] = UInt8(height & 0xFF)
    bytes[15] = UInt8((height >> 8) & 0xFF)
    bytes[16] = UInt8(bits)
    bytes[17] = UInt8(0x20)
    for (i in 0..pixelBytes) { bytes[18 + i] = UInt8(i + 1) }
    bytes
}
