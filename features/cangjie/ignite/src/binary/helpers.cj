package ignite.binary

import std.collection.ArrayList

public func cloneBytes(input: Array<UInt8>): Array<UInt8> {
    let out = Array<UInt8>(input.size, repeat: 0)
    var i = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}

public func sliceBytes(input: Array<UInt8>, start: Int64, end!: Int64 = -1): Array<UInt8> {
    var st = start
    if (st < 0) {
        st = 0
    }
    if (st > input.size) {
        st = input.size
    }

    var ed = end
    if (ed < 0 || ed > input.size) {
        ed = input.size
    }
    if (ed < st) {
        ed = st
    }

    let out = Array<UInt8>(ed - st, repeat: 0)
    var i = st
    while (i < ed) {
        out[i - st] = input[i]
        i += 1
    }
    out
}

public func readUint16BE(input: Array<UInt8>, offset: Int64): UInt16 {
    requireReadableBytes(input, offset, 2)
    UInt16((Int64(input[offset]) << 8) | Int64(input[offset + 1]))
}

public func readUint32BE(input: Array<UInt8>, offset: Int64): UInt32 {
    requireReadableBytes(input, offset, 4)
    UInt32(
        (Int64(input[offset]) << 24) |
        (Int64(input[offset + 1]) << 16) |
        (Int64(input[offset + 2]) << 8) |
        Int64(input[offset + 3])
    )
}

public func base64UrlEncode(input: Array<UInt8>): String {
    let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".toRuneArray()
    var i: Int64 = 0
    var out = ""
    while (i < input.size) {
        let b0 = Int64(input[i])
        let b1 = if (i + 1 < input.size) { Int64(input[i + 1]) } else { -1 }
        let b2 = if (i + 2 < input.size) { Int64(input[i + 2]) } else { -1 }

        let x0 = b0 >> 2
        let x1 = ((b0 & 0x03) << 4) | (if (b1 >= 0) { (b1 >> 4) & 0x0F } else { 0 })
        out += table[x0].toString()
        out += table[x1].toString()

        if (b1 >= 0) {
            let x2 = ((b1 & 0x0F) << 2) | (if (b2 >= 0) { (b2 >> 6) & 0x03 } else { 0 })
            out += table[x2].toString()
        }
        if (b2 >= 0) {
            let x3 = b2 & 0x3F
            out += table[x3].toString()
        }

        i += 3
    }
    out
}

public func base64UrlDecode(input: String): Array<UInt8> {
    let cleaned = input.trimAscii()
    if (cleaned.size == 0) {
        return []
    }

    let chars = cleaned.toRuneArray()
    if (chars.size % 4 == 1) {
        throw Exception("invalid base64url length")
    }

    let out = ArrayList<UInt8>()
    var buffer: Int64 = 0
    var bits: Int64 = 0

    for (ch in chars) {
        let idx = base64UrlIndex(ch)
        if (idx < 0) {
            throw Exception("invalid base64url character")
        }
        buffer = (buffer << 6) | idx
        bits += 6
        if (bits >= 8) {
            bits -= 8
            out.add(UInt8((buffer >> bits) & 0xFF))
        }
    }

    if (bits > 0) {
        let mask = (Int64(1) << bits) - 1
        if ((buffer & mask) != 0) {
            throw Exception("invalid base64url tail")
        }
    }
    out.toArray()
}

func requireReadableBytes(input: Array<UInt8>, offset: Int64, length: Int64): Unit {
    if (offset < 0 || length < 0 || offset + length > input.size) {
        throw Exception("binary read out of range")
    }
}

func base64UrlIndex(ch: Rune): Int64 {
    if (ch >= r'A' && ch <= r'Z') {
        return Int64(UInt32(ch)) - Int64(UInt32(r'A'))
    }
    if (ch >= r'a' && ch <= r'z') {
        return Int64(UInt32(ch)) - Int64(UInt32(r'a')) + 26
    }
    if (ch >= r'0' && ch <= r'9') {
        return Int64(UInt32(ch)) - Int64(UInt32(r'0')) + 52
    }
    if (ch == r'-') {
        return 62
    }
    if (ch == r'_') {
        return 63
    }
    -1
}
