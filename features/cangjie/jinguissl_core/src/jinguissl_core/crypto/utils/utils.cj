package jinguissl_core.crypto.utils

import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}

private let GETENTROPY_OK: Int32 = Int32(0)
private let GETENTROPY_MAX_LEN: Int64 = 256

@When[os == "macOS"]
foreign func arc4random_buf(buffer: CPointer<UInt8>, size: UIntNative): Unit

@When[os == "Linux"]
foreign func getentropy(buffer: CPointer<UInt8>, size: UIntNative): Int32

@When[os == "Windows"]
@CallingConv[STDCALL]
foreign func SystemFunction036(buffer: CPointer<UInt8>, size: UInt32): Bool

/**
 * bytesToUInt32BE.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func bytesToUInt32BE(bytes: Array<Byte>, offset!: Int64 = 0): UInt32 {
    if (offset < 0 || offset + 4 > bytes.size) {
        throw CryptoException(OutOfBounds, "bytesToUInt32BE out of bounds")
    }
    let b0 = UInt32(UInt8(bytes[offset]))
    let b1 = UInt32(UInt8(bytes[offset + 1]))
    let b2 = UInt32(UInt8(bytes[offset + 2]))
    let b3 = UInt32(UInt8(bytes[offset + 3]))
    (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

/**
 * bytesToUInt32LE.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func bytesToUInt32LE(bytes: Array<Byte>, offset!: Int64 = 0): UInt32 {
    if (offset < 0 || offset + 4 > bytes.size) {
        throw CryptoException(OutOfBounds, "bytesToUInt32LE out of bounds")
    }
    let b0 = UInt32(UInt8(bytes[offset]))
    let b1 = UInt32(UInt8(bytes[offset + 1]))
    let b2 = UInt32(UInt8(bytes[offset + 2]))
    let b3 = UInt32(UInt8(bytes[offset + 3]))
    b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

public func uInt32ToBytesBE(value: UInt32): Array<Byte> {
    [
        UInt8((value >> 24) & UInt32(0xFF)),
        UInt8((value >> 16) & UInt32(0xFF)),
        UInt8((value >> 8) & UInt32(0xFF)),
        UInt8(value & UInt32(0xFF))
    ]
}

public func uInt32ToBytesLE(value: UInt32): Array<Byte> {
    [
        UInt8(value & UInt32(0xFF)),
        UInt8((value >> 8) & UInt32(0xFF)),
        UInt8((value >> 16) & UInt32(0xFF)),
        UInt8((value >> 24) & UInt32(0xFF))
    ]
}

public func secureCopy(source: Array<Byte>): Array<Byte> {
    source.clone()
}

/**
 * secureCopyInto.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func secureCopyInto(source: Array<Byte>, destination: Array<Byte>, dstOffset!: Int64 = 0): Unit {
    if (dstOffset < 0) {
        throw CryptoException(OutOfBounds, "destination offset must be non-negative")
    }
    if (destination.size - dstOffset < source.size) {
        throw CryptoException(OutOfBounds, "destination capacity is not enough")
    }
    var i = 0
    while (i < source.size) {
        destination[dstOffset + i] = source[i]
        i += 1
    }
}

public func secureZero(bytes: Array<Byte>): Unit {
    var i = 0
    while (i < bytes.size) {
        bytes[i] = 0
        i += 1
    }
}

public func constantTimeEquals(left: Array<Byte>, right: Array<Byte>): Bool {
    if (left.size != right.size) {
        return false
    }
    var diff: UInt8 = 0
    var i = 0
    while (i < left.size) {
        diff = diff | (UInt8(left[i]) ^ UInt8(right[i]))
        i += 1
    }
    diff == 0
}

/**
 * randomSeed.
 *
 * Compatibility wrapper for security-sensitive callers. It must fail closed
 * with csprngBytes(...) instead of falling back to a non-CSPRNG source.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func randomSeed(size!: Int64 = 32): Array<Byte> {
    csprngBytes(size)
}

public func csprngBytes(): Array<Byte> {
    csprngBytes(32)
}

/**
 * csprngBytes.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func csprngBytes(size: Int64): Array<Byte> {
    if (size <= 0) {
        throw CryptoException(InvalidArgument, "CSPRNG output size must be > 0")
    }
    if (size > Int64(Int32.Max)) {
        throw CryptoException(OutOfBounds, "CSPRNG output size is too large")
    }
    let out = Array<Byte>(size, repeat: 0)
    if (!fillSystemEntropy(out)) {
        throw CryptoException(Unsupported, "system CSPRNG backend is unavailable on this platform")
    }
    out
}

public func csprngIsAvailable(): Bool {
    let probe = Array<Byte>(1, repeat: 0)
    fillSystemEntropy(probe)
}

private func fillSystemEntropy(out: Array<Byte>): Bool {
    if (out.size == 0) {
        return true
    }
    if (fillSystemEntropyMac(out)) {
        return true
    }
    if (fillSystemEntropyLinux(out)) {
        return true
    }
    if (fillSystemEntropyWindows(out)) {
        return true
    }
    false
}

@When[os == "macOS"]
private func fillSystemEntropyMac(out: Array<Byte>): Bool {
    unsafe {
        var raw = acquireArrayRawData<Byte>(out)
        try {
            arc4random_buf(raw.pointer, UIntNative(out.size))
            true
        } finally {
            releaseArrayRawData<Byte>(raw)
        }
    }
}

@When[os != "macOS"]
private func fillSystemEntropyMac(out: Array<Byte>): Bool {
    false
}

@When[os == "Linux"]
private func fillSystemEntropyLinux(out: Array<Byte>): Bool {
    var offset: Int64 = 0
    while (offset < out.size) {
        let remain = out.size - offset
        let chunkLen = if (remain > GETENTROPY_MAX_LEN) {
            GETENTROPY_MAX_LEN
        } else {
            remain
        }
        let chunk = Array<Byte>(chunkLen, repeat: 0)
        if (!fillLinuxGetentropyChunk(chunk)) {
            return false
        }
        secureCopyInto(chunk, out, dstOffset: offset)
        offset += chunkLen
    }
    true
}

@When[os != "Linux"]
private func fillSystemEntropyLinux(_out: Array<Byte>): Bool {
    if (_out.size < 0) {
        return false
    }
    false
}

@When[os == "Linux"]
private func fillLinuxGetentropyChunk(chunk: Array<Byte>): Bool {
    unsafe {
        var raw = acquireArrayRawData<Byte>(chunk)
        try {
            getentropy(raw.pointer, UIntNative(chunk.size)) == GETENTROPY_OK
        } finally {
            releaseArrayRawData<Byte>(raw)
        }
    }
}

@When[os == "Windows"]
private func fillSystemEntropyWindows(out: Array<Byte>): Bool {
    unsafe {
        var raw = acquireArrayRawData<Byte>(out)
        try {
            SystemFunction036(raw.pointer, UInt32(out.size))
        } finally {
            releaseArrayRawData<Byte>(raw)
        }
    }
}

@When[os != "Windows"]
private func fillSystemEntropyWindows(_out: Array<Byte>): Bool {
    if (_out.size < 0) {
        return false
    }
    false
}
