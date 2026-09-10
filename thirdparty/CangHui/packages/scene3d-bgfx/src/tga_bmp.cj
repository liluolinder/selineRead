package canghui_scene3d_bgfx

import std.fs.File

private let TGA_HEADER_SIZE: Int64 = 18
private let BMP_HEADER_SIZE: Int64 = 54

/** Converts the 32-bit uncompressed BGRA TGA emitted by bgfx to a 32-bit BMP. */
public func convertBgfxTgaToBmp(tgaPath: String, bmpPath: String): Unit {
    let source = File.readFrom(tgaPath)
    if (source.size < TGA_HEADER_SIZE) {
        throw IllegalArgumentException("bgfx screenshot TGA is truncated")
    }
    let idLength = Int64(source[0])
    if (source[1] != UInt8(0) || source[2] != UInt8(2)) {
        throw IllegalArgumentException("bgfx screenshot must be an uncompressed true-color TGA")
    }
    let width = readLe16(source, 12)
    let height = readLe16(source, 14)
    if (width <= 0 || height <= 0) {
        throw IllegalArgumentException("bgfx screenshot dimensions must be positive")
    }
    if (source[16] != UInt8(32)) {
        throw IllegalArgumentException("bgfx screenshot must use 32-bit BGRA pixels")
    }
    if ((source[17] & UInt8(0x20)) == UInt8(0)) {
        throw IllegalArgumentException("bgfx screenshot must use a top-left image origin")
    }
    let pixelOffset = TGA_HEADER_SIZE + idLength
    let rowBytes = width * 4
    let pixelBytes = rowBytes * height
    if (pixelOffset + pixelBytes > source.size) {
        throw IllegalArgumentException("bgfx screenshot pixel payload is truncated")
    }

    let output = Array<UInt8>(BMP_HEADER_SIZE + pixelBytes, repeat: UInt8(0))
    output[0] = UInt8(0x42)
    output[1] = UInt8(0x4D)
    writeLe32(output, 2, output.size)
    writeLe32(output, 10, BMP_HEADER_SIZE)
    writeLe32(output, 14, 40)
    writeLe32(output, 18, width)
    writeLe32(output, 22, height)
    writeLe16(output, 26, 1)
    writeLe16(output, 28, 32)
    writeLe32(output, 34, pixelBytes)

    for (destinationRow in 0..height) {
        let sourceRow = height - destinationRow - 1
        let sourceStart = pixelOffset + sourceRow * rowBytes
        let destinationStart = BMP_HEADER_SIZE + destinationRow * rowBytes
        for (columnByte in 0..rowBytes) {
            output[destinationStart + columnByte] = source[sourceStart + columnByte]
        }
    }
    File.writeTo(bmpPath, output)
}

private func readLe16(bytes: Array<UInt8>, offset: Int64): Int64 {
    Int64(bytes[offset]) | (Int64(bytes[offset + 1]) << 8)
}

private func writeLe16(bytes: Array<UInt8>, offset: Int64, value: Int64): Unit {
    bytes[offset] = UInt8(value & 0xFF)
    bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
}

private func writeLe32(bytes: Array<UInt8>, offset: Int64, value: Int64): Unit {
    bytes[offset] = UInt8(value & 0xFF)
    bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
    bytes[offset + 2] = UInt8((value >> 16) & 0xFF)
    bytes[offset + 3] = UInt8((value >> 24) & 0xFF)
}
