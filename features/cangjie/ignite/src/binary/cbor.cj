package ignite.binary

import std.collection.ArrayList

public enum CborKind <: Equatable<CborKind> & ToString {
    | UnsignedInt
    | NegativeInt
    | ByteString
    | TextString
    | ArrayValue
    | MapValue

    public operator func ==(right: CborKind): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: CborKind): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case UnsignedInt => 0
            case NegativeInt => 1
            case ByteString => 2
            case TextString => 3
            case ArrayValue => 4
            case MapValue => 5
        }
    }

    public func toString(): String {
        match (this) {
            case UnsignedInt => "unsigned-int"
            case NegativeInt => "negative-int"
            case ByteString => "byte-string"
            case TextString => "text-string"
            case ArrayValue => "array"
            case MapValue => "map"
        }
    }
}

public enum CborErrorCode <: Equatable<CborErrorCode> & ToString {
    | MalformedInput
    | UnsupportedType
    | UnsupportedLength
    | LimitExceeded
    | TrailingData

    public operator func ==(right: CborErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: CborErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case MalformedInput => 0
            case UnsupportedType => 1
            case UnsupportedLength => 2
            case LimitExceeded => 3
            case TrailingData => 4
        }
    }

    public func toString(): String {
        match (this) {
            case MalformedInput => "MALFORMED_INPUT"
            case UnsupportedType => "UNSUPPORTED_TYPE"
            case UnsupportedLength => "UNSUPPORTED_LENGTH"
            case LimitExceeded => "LIMIT_EXCEEDED"
            case TrailingData => "TRAILING_DATA"
        }
    }
}

public class CborException <: Exception {
    public let code: CborErrorCode

    public init(code: CborErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public class CborDecodeOption {
    public let maxDepth: Int64
    public let maxCollectionEntries: Int64
    public let maxByteStringLength: Int64
    public let maxTextStringLength: Int64

    public init(
        maxDepth!: Int64 = 32,
        maxCollectionEntries!: Int64 = 1024,
        maxByteStringLength!: Int64 = 1024 * 1024,
        maxTextStringLength!: Int64 = 1024 * 1024
    ) {
        this.maxDepth = if (maxDepth > 0) { maxDepth } else { 32 }
        this.maxCollectionEntries = if (maxCollectionEntries > 0) { maxCollectionEntries } else { 1024 }
        this.maxByteStringLength = if (maxByteStringLength > 0) { maxByteStringLength } else { 1024 * 1024 }
        this.maxTextStringLength = if (maxTextStringLength > 0) { maxTextStringLength } else { 1024 * 1024 }
    }
}

public class CborValue {
    public let kind: CborKind
    let _numberValue: Int64
    let _byteStringValue: Array<UInt8>
    let _textStringValue: String
    let _arrayValue: Array<CborValue>
    let _mapEntries: Array<(CborValue, CborValue)>

    init(
        kind: CborKind,
        numberValue!: Int64 = 0,
        byteStringValue!: Array<UInt8> = [],
        textStringValue!: String = "",
        arrayValue!: Array<CborValue> = [],
        mapEntries!: Array<(CborValue, CborValue)> = []
    ) {
        this.kind = kind
        this._numberValue = numberValue
        this._byteStringValue = cloneBytes(byteStringValue)
        this._textStringValue = textStringValue
        this._arrayValue = cloneCborValueArray(arrayValue)
        this._mapEntries = cloneCborMapEntries(mapEntries)
    }

    public static func unsignedInt(value: Int64): CborValue {
        CborValue(CborKind.UnsignedInt, numberValue: value)
    }

    public static func negativeInt(value: Int64): CborValue {
        CborValue(CborKind.NegativeInt, numberValue: value)
    }

    public static func byteString(value: Array<UInt8>): CborValue {
        CborValue(CborKind.ByteString, byteStringValue: value)
    }

    public static func textString(value: String): CborValue {
        CborValue(CborKind.TextString, textStringValue: value)
    }

    public static func arrayValue(items: Array<CborValue>): CborValue {
        CborValue(CborKind.ArrayValue, arrayValue: items)
    }

    public static func mapValue(entries: Array<(CborValue, CborValue)>): CborValue {
        CborValue(CborKind.MapValue, mapEntries: entries)
    }

    public func asUnsignedInt(): ?Int64 {
        if (kind == CborKind.UnsignedInt) {
            return Some(_numberValue)
        }
        None
    }

    public func asNegativeInt(): ?Int64 {
        if (kind == CborKind.NegativeInt) {
            return Some(_numberValue)
        }
        None
    }

    public func asInt64(): ?Int64 {
        match (kind) {
            case CborKind.UnsignedInt => Some(_numberValue)
            case CborKind.NegativeInt => Some(_numberValue)
            case _ => None
        }
    }

    public func asByteString(): ?Array<UInt8> {
        if (kind == CborKind.ByteString) {
            return Some(cloneBytes(_byteStringValue))
        }
        None
    }

    public func asTextString(): ?String {
        if (kind == CborKind.TextString) {
            return Some(_textStringValue)
        }
        None
    }

    public func asArray(): ?Array<CborValue> {
        if (kind == CborKind.ArrayValue) {
            return Some(cloneCborValueArray(_arrayValue))
        }
        None
    }

    public func asMapEntries(): ?Array<(CborValue, CborValue)> {
        if (kind == CborKind.MapValue) {
            return Some(cloneCborMapEntries(_mapEntries))
        }
        None
    }

    public func getTextKey(key: String): ?CborValue {
        if (kind != CborKind.MapValue) {
            return None
        }
        for ((entryKey, entryValue) in _mapEntries) {
            if (let Some(textKey) <- entryKey.asTextString()) {
                if (textKey == key) {
                    return Some(entryValue)
                }
            }
        }
        None
    }

    public func getIntKey(key: Int64): ?CborValue {
        if (kind != CborKind.MapValue) {
            return None
        }
        for ((entryKey, entryValue) in _mapEntries) {
            if (let Some(value) <- entryKey.asInt64()) {
                if (value == key) {
                    return Some(entryValue)
                }
            }
        }
        None
    }
}

public func decodeCbor(
    input: Array<UInt8>,
    option!: CborDecodeOption = CborDecodeOption()
): CborValue {
    let reader = CborReader(cloneBytes(input), option)
    let value = reader.readValue(0)
    if (reader.hasRemaining()) {
        throw CborException(CborErrorCode.TrailingData, "trailing bytes remain after CBOR value")
    }
    value
}

public func decodeCborMap(
    input: Array<UInt8>,
    option!: CborDecodeOption = CborDecodeOption()
): CborValue {
    let value = decodeCbor(input, option: option)
    if (value.kind != CborKind.MapValue) {
        throw CborException(CborErrorCode.UnsupportedType, "CBOR root value is not a map")
    }
    value
}

class CborPrefixDecodeResult {
    let value: CborValue
    let bytesRead: Int64

    init(value: CborValue, bytesRead: Int64) {
        this.value = value
        this.bytesRead = bytesRead
    }
}

func decodeCborPrefix(
    input: Array<UInt8>,
    option!: CborDecodeOption = CborDecodeOption()
): CborPrefixDecodeResult {
    let reader = CborReader(cloneBytes(input), option)
    let value = reader.readValue(0)
    CborPrefixDecodeResult(value, reader.offset)
}

class CborReader {
    let data: Array<UInt8>
    let option: CborDecodeOption
    var offset: Int64 = 0

    init(data: Array<UInt8>, option: CborDecodeOption) {
        this.data = data
        this.option = option
    }

    func hasRemaining(): Bool {
        offset < data.size
    }

    func readValue(depth: Int64): CborValue {
        if (depth > option.maxDepth) {
            throw CborException(CborErrorCode.LimitExceeded, "CBOR nesting depth exceeded")
        }

        let initialByte = Int64(readByte())
        let majorType = initialByte >> 5
        let additionalInfo = initialByte & 0x1F

        match (majorType) {
            case 0 => CborValue.unsignedInt(readLength(additionalInfo, "unsigned integer"))
            case 1 => decodeNegativeInt(additionalInfo)
            case 2 => CborValue.byteString(readByteString(additionalInfo))
            case 3 => CborValue.textString(readTextString(additionalInfo))
            case 4 => CborValue.arrayValue(readArrayItems(additionalInfo, depth))
            case 5 => CborValue.mapValue(readMapEntries(additionalInfo, depth))
            case _ =>
                throw CborException(
                    CborErrorCode.UnsupportedType,
                    "unsupported CBOR major type: ${majorType}"
                )
        }
    }

    func decodeNegativeInt(additionalInfo: Int64): CborValue {
        let encoded = readLength(additionalInfo, "negative integer")
        if (encoded >= 9223372036854775807) {
            throw CborException(CborErrorCode.UnsupportedLength, "negative integer exceeds Int64 range")
        }
        CborValue.negativeInt(-1 - encoded)
    }

    func readByteString(additionalInfo: Int64): Array<UInt8> {
        let byteLength = readLength(additionalInfo, "byte string length")
        if (byteLength > option.maxByteStringLength) {
            throw CborException(CborErrorCode.LimitExceeded, "CBOR byte string exceeds configured limit")
        }
        readExactBytes(byteLength)
    }

    func readTextString(additionalInfo: Int64): String {
        let textLength = readLength(additionalInfo, "text string length")
        if (textLength > option.maxTextStringLength) {
            throw CborException(CborErrorCode.LimitExceeded, "CBOR text string exceeds configured limit")
        }
        let bytes = readExactBytes(textLength)
        try {
            String.fromUtf8(bytes)
        } catch (_: Exception) {
            throw CborException(CborErrorCode.MalformedInput, "CBOR text string is not valid UTF-8")
        }
    }

    func readArrayItems(additionalInfo: Int64, depth: Int64): Array<CborValue> {
        let itemCount = readLength(additionalInfo, "array length")
        if (itemCount > option.maxCollectionEntries) {
            throw CborException(CborErrorCode.LimitExceeded, "CBOR array exceeds configured entry limit")
        }
        let out = ArrayList<CborValue>()
        var i: Int64 = 0
        while (i < itemCount) {
            out.add(readValue(depth + 1))
            i += 1
        }
        out.toArray()
    }

    func readMapEntries(additionalInfo: Int64, depth: Int64): Array<(CborValue, CborValue)> {
        let pairCount = readLength(additionalInfo, "map length")
        if (pairCount > option.maxCollectionEntries) {
            throw CborException(CborErrorCode.LimitExceeded, "CBOR map exceeds configured entry limit")
        }
        let out = ArrayList<(CborValue, CborValue)>()
        var i: Int64 = 0
        while (i < pairCount) {
            let key = readValue(depth + 1)
            let value = readValue(depth + 1)
            out.add((key, value))
            i += 1
        }
        out.toArray()
    }

    func readLength(additionalInfo: Int64, context: String): Int64 {
        if (additionalInfo < 24) {
            return additionalInfo
        }
        match (additionalInfo) {
            case 24 => Int64(readByte())
            case 25 => readUint16()
            case 26 => readUint32()
            case 27 => readUint64AsInt64()
            case 31 =>
                throw CborException(
                    CborErrorCode.UnsupportedLength,
                    "indefinite-length CBOR is not supported for ${context}"
                )
            case _ =>
                throw CborException(
                    CborErrorCode.UnsupportedLength,
                    "unsupported CBOR additional info ${additionalInfo} for ${context}"
                )
        }
    }

    func readByte(): UInt8 {
        if (offset >= data.size) {
            throw CborException(CborErrorCode.MalformedInput, "unexpected end of CBOR input")
        }
        let value = data[offset]
        offset += 1
        value
    }

    func readUint16(): Int64 {
        ensureRemaining(2)
        let value = Int64(readUint16BE(data, offset))
        offset += 2
        value
    }

    func readUint32(): Int64 {
        ensureRemaining(4)
        let value = Int64(readUint32BE(data, offset))
        offset += 4
        value
    }

    func readUint64AsInt64(): Int64 {
        ensureRemaining(8)
        var value: UInt64 = 0
        var i: Int64 = 0
        while (i < 8) {
            value = (value << 8) | UInt64(data[offset + i])
            i += 1
        }
        offset += 8
        if (value > UInt64(9223372036854775807)) {
            throw CborException(CborErrorCode.UnsupportedLength, "CBOR integer exceeds Int64 range")
        }
        Int64(value)
    }

    func readExactBytes(length: Int64): Array<UInt8> {
        ensureRemaining(length)
        let out = Array<UInt8>(length, repeat: 0)
        var i: Int64 = 0
        while (i < length) {
            out[i] = data[offset + i]
            i += 1
        }
        offset += length
        out
    }

    func ensureRemaining(length: Int64): Unit {
        if (length < 0 || offset + length > data.size) {
            throw CborException(CborErrorCode.MalformedInput, "unexpected end of CBOR input")
        }
    }
}

func cloneCborValueArray(input: Array<CborValue>): Array<CborValue> {
    let out = ArrayList<CborValue>()
    for (item in input) {
        out.add(item)
    }
    out.toArray()
}

func cloneCborMapEntries(input: Array<(CborValue, CborValue)>): Array<(CborValue, CborValue)> {
    let out = ArrayList<(CborValue, CborValue)>()
    for (item in input) {
        out.add(item)
    }
    out.toArray()
}
