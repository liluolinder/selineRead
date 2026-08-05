package gjson


// ============================================================================
// 字符串工具合并模块
// 合并自: string_utils.cj + json_string_utils.cj
// 基于Go版本优化模式，提供统一的字符串处理功能
// 职责：字符串转义、JSON压缩、字符编码和路径组件处理
// ============================================================================

// ============================================================================
// JSON字符串处理函数（原json_string_utils.cj内容）
// ============================================================================

// squash returns the squashed JSON string (expects leading '[', '{', '(', or '"')
func squash(json: String): String {
    var i = 0
    var depth = 0
    if (json[0] != b'"') {
        i = 1
        depth = 1
    }
    while (i < json.size) {
        if (json[i] >= b'"' && json[i] <= b'}') {
            match (json[i]) {
                case b'"' =>
                    i++
                    let s2 = i
                    while (i < json.size) {
                        if (json[i] > b'\\') {
                            i++
                            continue
                        }
                        if (json[i] == b'"') {
                            if (json[i - 1] == b'\\') {
                                var n = 0
                                var j = i - 2
                                while (j >= s2) {
                                    if (json[j] != b'\\') {
                                        break
                                    }
                                    n++
                                    j--
                                }
                                if (n % 2 == 0) {
                                    i++
                                    continue
                                }
                            }
                            break
                        }
                        i++
                    }
                    if (depth == 0) {
                        if (i >= json.size) {
                            return json
                        }
                        return json[..i + 1]
                    }
                case b'{' | b'[' | b'(' => depth++
                case b'}' | b']' | b')' =>
                    depth--
                    if (depth == 0) {
                        return json[..i + 1]
                    }
                case _ => ()
            }
        }
        i++
    }
    return json
}

// revSquash returns the reverse squashed JSON string (expects trailing ']', '}', ')', or '"')
func revSquash(json: String): String {
    var i = json.size - 1
    var depth = 0
    if (json[i] != b'"') {
        depth = 1
    }
    if (json[i] == b'}' || json[i] == b']' || json[i] == b')') {
        i--
    }
    while (i >= 0) {
        match (json[i]) {
            case b'"' =>
                i--
                while (i >= 0) {
                    if (json[i] == b'"') {
                        var esc = 0
                        while (i > 0 && json[i - 1] == b'\\') {
                            i--
                            esc++
                        }
                        if (esc % 2 == 1) {
                            i += esc
                            continue
                        }
                        i += esc
                        break
                    }
                    i--
                }
                if (depth == 0) {
                    if (i < 0) {
                        i = 0
                    }
                    return json[i..]
                }
            case b'}' | b']' | b')' => depth++
            case b'{' | b'[' | b'(' =>
                depth--
                if (depth == 0) {
                    return json[i..]
                }
            case _ => ()
        }
        i--
    }
    return json
}

// ============================================================================
// 通用字符串处理函数（原string_utils.cj内容）
// ============================================================================

func unescape(json: String): String {
    let bytes = ArrayList<Byte>()
    var i = 0
    while (i < json.size) {
        match (json[i]) {
            case b'\\' =>
                i++
                if (i >= json.size) {
                    break
                }
                match (json[i]) {
                    case b'\\' => bytes.add(b'\\')
                    case b'/' => bytes.add(b'/')
                    case b'b' => bytes.add(0x08)
                    case b'f' => bytes.add(0x0C)
                    case b'n' => bytes.add(b'\n')
                    case b'r' => bytes.add(b'\r')
                    case b't' => bytes.add(b'\t')
                    case b'"' => bytes.add(b'"')
                    case b'u' =>
                        if (i+5 > json.size) {
                            break
                        }
                        let r = runeit(json[i+1..])
                        if (r != r'0') {
                            let (encoded, size) = encodeRune(r)
                            for (b in encoded) {
                                bytes.add(b)
                            }
                            i += 5
                            i--
                        }
                    case _ => ()
                }
            case _ =>
                if (json[i] < b' ') {
                    break
                }
                bytes.add(json[i])
        }
        i++
    }
    return unsafe { String.withRawData(bytes.toArray()) }
}

// escape 转义路径组件
func escape(comp: String): String {
    var i = 0
    while (i < comp.size) {
        if (!isSafePathKeyChar(comp[i])) {
            let bytes = ArrayList<Byte>()
            for (j in 0..i) {
                bytes.add(comp[j])
            }
            while (i < comp.size) {
                if (!isSafePathKeyChar(comp[i])) {
                    bytes.add(b'\\')
                }
                bytes.add(comp[i])
                i++
            }
            return unsafe { String.withRawData(bytes.toArray()) }
        }
        i++
    }
    return comp
}

func appendHex16(dst: ArrayList<Byte>, x: UInt16): ArrayList<Byte> {
    dst.add(HEX_CHARS[Int64(x >> 12) & 0xF])
    dst.add(HEX_CHARS[Int64(x >> 8) & 0xF])
    dst.add(HEX_CHARS[Int64(x >> 4) & 0xF])
    dst.add(HEX_CHARS[Int64(x) & 0xF])
    return dst
}

// encodeRune encodes a rune into UTF-8 bytes and returns the bytes and size
func encodeRune(r: Rune): (Array<Byte>, Int64) {
    let buf = ArrayList<Byte>(4)

    // Convert Rune to UInt32 for bit operations
    let u = UInt32(r)

    if (u <= 0x7F) {
        // 1-byte sequence (0xxxxxxx)
        buf.add(UInt8(u))
    } else if (u <= 0x7FF) {
        // 2-byte sequence (110xxxxx 10xxxxxx)
        buf.add(UInt8(0xC0 | (u >> 6)))
        buf.add(UInt8(0x80 | (u & 0x3F)))
    } else if (u <= 0xFFFF) {
        // 3-byte sequence (1110xxxx 10xxxxxx 10xxxxxx)
        buf.add(UInt8(0xE0 | (u >> 12)))
        buf.add(UInt8(0x80 | ((u >> 6) & 0x3F)))
        buf.add(UInt8(0x80 | (u & 0x3F)))
    } else if (u <= 0x10FFFF) {
        // 4-byte sequence (11110xxx 10xxxxxx 10xxxxxx 10xxxxxx)
        buf.add(UInt8(0xF0 | (u >> 18)))
        buf.add(UInt8(0x80 | ((u >> 12) & 0x3F)))
        buf.add(UInt8(0x80 | ((u >> 6) & 0x3F)))
        buf.add(UInt8(0x80 | (u & 0x3F)))
    } else {
        // Invalid rune, use replacement character (U+FFFD)
        buf.add(0xEF)
        buf.add(0xBF)
        buf.add(0xBD)
    }
    return (buf.toArray(), Int64(buf.size))
}

func decodeRuneInString(s: String): (Rune, Int64) {
    if (s.size == 0) {
        return (r'0', 0)
    }
    let runes = s.toRuneArray()
    if (runes.size > 0) {
        let r = runes[0]
        return (r, Rune.utf8Size(r))
    }
    return (r'0', 1)
}

func appendWithSeparator(sb: StringBuilder, value: String, isFirst: Bool, separator!: Byte = b','): Unit {
    if (!isFirst) {
        sb.append(separator)
    }
    sb.append(value)
}