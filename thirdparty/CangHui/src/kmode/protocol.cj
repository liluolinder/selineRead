package chui.kmode

import std.collection.ArrayList
import std.convert.*

/** Newline framing with hex UTF-8 fields keeps the open core dependency-free. */
public func encodeKModeRequest(request: KModeRequest): String {
    KMODE_PROTOCOL + "|" +
        request.id.toString() + "|" +
        kModeOperationName(request.operation) + "|" +
        encodeKModeText(request.endpoint) + "|" +
        encodeKModeText(request.payload)
}

public func decodeKModeRequest(line: String): KModeRequest {
    let parts = line.split("|")
    if (parts.size != 5 || parts[0] != KMODE_PROTOCOL) {
        throw IllegalArgumentException("invalid kMode request frame")
    }
    KModeRequest(
        Int64.parse(parts[1]),
        parseKModeOperation(parts[2]),
        endpoint: decodeKModeText(parts[3]),
        payload: decodeKModeText(parts[4])
    )
}

public func encodeKModeResponse(response: KModeResponse): String {
    KMODE_PROTOCOL + "|" +
        response.id.toString() + "|" +
        (if (response.ok) { "1" } else { "0" }) + "|" +
        encodeKModeText(response.status) + "|" +
        encodeKModeText(response.payload) + "|" +
        response.errorCode.toString() + "|" +
        encodeKModeText(response.errorMessage)
}

public func decodeKModeResponse(line: String): KModeResponse {
    let parts = line.split("|")
    if (parts.size != 7 || parts[0] != KMODE_PROTOCOL) {
        throw IllegalArgumentException("invalid kMode response frame")
    }
    KModeResponse(
        Int64.parse(parts[1]),
        parts[2] == "1",
        decodeKModeText(parts[3]),
        payload: decodeKModeText(parts[4]),
        errorCode: Int64.parse(parts[5]),
        errorMessage: decodeKModeText(parts[6])
    )
}

public func encodeKModeText(value: String): String {
    let digits = "0123456789abcdef".toRuneArray()
    var out = ""
    for (byte in value.toArray()) {
        out += digits[Int64(byte >> 4)].toString()
        out += digits[Int64(byte & 0x0f)].toString()
    }
    out
}

public func decodeKModeText(value: String): String {
    let runes = value.toRuneArray()
    if (runes.size % 2 != 0) {
        throw IllegalArgumentException("kMode hex field has odd length")
    }
    let bytes = ArrayList<UInt8>()
    var i: Int64 = 0
    while (i < runes.size) {
        let high = decodeHexNibble(runes[i])
        let low = decodeHexNibble(runes[i + 1])
        bytes.add(UInt8((high << 4) | low))
        i += 2
    }
    String.fromUtf8(bytes.toArray())
}

func decodeHexNibble(value: Rune): Int64 {
    if (value >= r'0' && value <= r'9') {
        return Int64(UInt32(value) - UInt32(r'0'))
    }
    if (value >= r'a' && value <= r'f') {
        return Int64(UInt32(value) - UInt32(r'a')) + 10
    }
    if (value >= r'A' && value <= r'F') {
        return Int64(UInt32(value) - UInt32(r'A')) + 10
    }
    throw IllegalArgumentException("invalid kMode hex digit")
}
