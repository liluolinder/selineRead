package ignite

import seajson.escapeJsonText as seaJsonEscapeJsonText

public func escapeJsonText(value: String): String {
    seaJsonEscapeJsonText(value)
}

func escapeJsonRune(r: Rune): String {
    if (r == r'\\') {
        return "\\\\"
    }
    if (r == r'"') {
        return "\\\""
    }
    if (r == r'\b') {
        return "\\b"
    }
    if (r == r'\f') {
        return "\\f"
    }
    if (r == r'\n') {
        return "\\n"
    }
    if (r == r'\r') {
        return "\\r"
    }
    if (r == r'\t') {
        return "\\t"
    }

    let piece = r.toString()
    let bytes = piece.toArray()
    if (bytes.size == 1) {
        let code = Int64(bytes[0])
        if (code < 0x20) {
            return "\\u00" + byteToLowerHex(bytes[0])
        }
    }
    piece
}

func byteToLowerHex(value: UInt8): String {
    let hexChars = "0123456789abcdef".toRuneArray()
    let n = Int64(value)
    hexChars[n >> 4].toString() + hexChars[n & 0x0F].toString()
}
