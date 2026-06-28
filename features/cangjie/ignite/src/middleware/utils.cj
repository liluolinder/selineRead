package ignite.middleware

import std.collection.ArrayList
import ignite.security as security

func base64Decode(input: String): Array<UInt8> {
    let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let tableArr = table.toRuneArray()
    let chars = input.toRuneArray()
    let result = ArrayList<UInt8>()
    var buffer: Int64 = 0
    var bits: Int64 = 0
    for (ch in chars) {
        if (ch == r'=') { break }
        let idx = runeIndexOf(tableArr, ch)
        if (idx < 0) { continue }
        buffer = (buffer << 6) | idx
        bits += 6
        if (bits >= 8) {
            bits -= 8
            result.add(UInt8((buffer >> bits) & 0xFF))
        }
    }
    result.toArray()
}

func base64Encode(data: Array<UInt8>): String {
    let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let chars = table.toRuneArray()
    var result = ""
    var i: Int64 = 0
    while (i < data.size) {
        let b0 = Int64(data[i])
        let b1 = if (i + 1 < data.size) { Int64(data[i + 1]) } else { 0 }
        let b2 = if (i + 2 < data.size) { Int64(data[i + 2]) } else { 0 }
        let triple = (b0 << 16) | (b1 << 8) | b2
        result += chars[(triple >> 18) & 0x3F].toString()
        result += chars[(triple >> 12) & 0x3F].toString()
        if (i + 1 < data.size) {
            result += chars[(triple >> 6) & 0x3F].toString()
        } else {
            result += "="
        }
        if (i + 2 < data.size) {
            result += chars[triple & 0x3F].toString()
        } else {
            result += "="
        }
        i += 3
    }
    result
}

func runeIndexOf(arr: Array<Rune>, ch: Rune): Int64 {
    for (i in 0..arr.size) {
        if (arr[i] == ch) { return i }
    }
    -1
}

func bytesToHex(data: Array<UInt8>): String {
    let hexChars = "0123456789abcdef".toRuneArray()
    var result = ""
    for (b in data) {
        let n = Int64(b)
        result += hexChars[n >> 4].toString()
        result += hexChars[n & 0x0F].toString()
    }
    result
}

func generateRandomHex(length: Int64): String {
    if (length <= 0) {
        return ""
    }
    security.randomHex(length)
}

func strStartsWith(s: String, prefix: String): Bool {
    if (s.size < prefix.size) { return false }
    let sArr = s.toRuneArray()
    let pArr = prefix.toRuneArray()
    for (i in 0..pArr.size) {
        if (sArr[i] != pArr[i]) { return false }
    }
    true
}

func substringFrom(s: String, start: Int64): String {
    let runes = s.toRuneArray()
    var result = ""
    for (i in start..runes.size) {
        result += runes[i].toString()
    }
    result
}

func strContains(haystack: String, needle: String): Bool {
    let hArr = haystack.toRuneArray()
    let nArr = needle.toRuneArray()
    if (nArr.size == 0) { return true }
    if (hArr.size < nArr.size) { return false }
    for (i in 0..=(hArr.size - nArr.size)) {
        var found = true
        for (j in 0..nArr.size) {
            if (hArr[i + j] != nArr[j]) {
                found = false
                break
            }
        }
        if (found) { return true }
    }
    false
}
