package gjson


// 简化的JSON值解析器
// 直接解析单个JSON值，无需中间上下文

// checkNumericChar 检查字符是否为数字开头字符
func checkNumericChar(ch: Byte): Bool {
    (ch >= b'0' && ch <= b'9') || ch == b'-' || ch == b'+' ||
           ch == b'i' || ch == b'I' || ch == b'N'
}

// parseValue 直接解析JSON值
// 返回: (新索引, 解析结果, 是否成功)
func parseValue(json: String, i: Int64): (Int64, Result, Bool) {
    if (i >= json.size) {
        return (i, createNullResult(), false)
    }

    let ch = json[i]
    match (ch) {
        case b'"' => parseValueString(json, i)
        case b'{' => parseValueBlock(json, i, b'{', b'}')
        case b'[' => parseValueBlock(json, i, b'[', b']')
        case b'n' => parseValueNull(json, i)
        case b't' => parseValueBool(json, i, true)
        case b'f' => parseValueBool(json, i, false)
        case _ =>
            if (checkNumericChar(ch)) {
                parseValueNumber(json, i)
            } else {
                (i, createNullResult(), false)
            }
    }
}

// 解析字符串值
func parseValueString(json: String, i: Int64): (Int64, Result, Bool) {
    let strResult = parseString(json, i + 1)
    if (!strResult.ok) {
        return (strResult.index, createNullResult(), false)
    }
    let content = if (strResult.escaped) {
        unescape(strResult.raw[1..strResult.raw.size - 1])
    } else {
        strResult.raw[1..strResult.raw.size - 1]
    }
    return (strResult.index, createStringResult(strResult.raw, content), true)
}

// 解析对象或数组块
func parseValueBlock(json: String, i: Int64, startChar: Byte, endChar: Byte): (Int64, Result, Bool) {
    let (newI, raw) = parseBlock(json, i)
    if (raw.size == 0 || raw[raw.size - 1] != endChar) {
        return (newI, createNullResult(), false)
    }
    return (newI, createJSONResult(raw), true)
}

// 解析null
func parseValueNull(json: String, i: Int64): (Int64, Result, Bool) {
    if (i + 1 < json.size && json[i + 1] != b'u') {
        return parseValueNumber(json, i)
    }
    let raw = tolit(json[i..])
    return (i + raw.size, createNullResultWithRaw(raw), true)
}

// 解析布尔值
func parseValueBool(json: String, i: Int64, isTrue: Bool): (Int64, Result, Bool) {
    let raw = tolit(json[i..])
    let result = if (isTrue) { createTrueResultWithRaw(raw) } else { createFalseResultWithRaw(raw) }
    return (i + raw.size, result, true)
}

// 解析数字
func parseValueNumber(json: String, i: Int64): (Int64, Result, Bool) {
    let ch = json[i]
    if (ch == b'i' && !json[i..].startsWith("infinity")) {
        return (i, createNullResult(), false)
    }
    if (ch == b'I' && !json[i..].startsWith("Infinity")) {
        return (i, createNullResult(), false)
    }
    if (ch == b'N' && !json[i..].startsWith("NaN")) {
        return (i, createNullResult(), false)
    }
    let (raw, num) = parseNumber(json, i)
    return (i + raw.size, createNumberResult(raw, num), true)
}
