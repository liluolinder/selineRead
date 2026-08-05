package gjson

// 空白字符处理工具模块
// 基于Go版本优化模式，统一空白字符处理逻辑
// 职责：提供统一的空白字符识别、跳过和清理功能，提高性能和一致性

// 空白字符常量已移至 constants.cj 中统一管理

// isWhitespace 检查字符是否为空白字符（统一标准）
// 根据JSON规范，空白字符包括：空格(0x20)、制表符(0x09)、换行符(0x0A)、回车符(0x0D)
func isWhitespace(c: Byte): Bool {
    return c == SPACE || c == TAB || c == NEWLINE || c == CARRIAGE_RETURN
}

// isWhitespaceOrControl 检查字符是否为空白字符或控制字符
// 实现基于字符编码值 <= SPACE 的判断逻辑
func isWhitespaceOrControl(c: Byte): Bool {
    return c <= SPACE
}

// skipWhitespace 跳过字符串开头的空白字符，返回第一个非空白字符的索引
func skipWhitespace(json: String, start: Int64): Int64 {
    return skipCharacters(json, start, true, [])
}

// skipWhitespaceAndComma 跳过空白字符和逗号（常用于JSON解析）
func skipWhitespaceAndComma(json: String, start: Int64): Int64 {
    return skipCharacters(json, start, true, [b','])
}

// skipWhitespaceAndColon 跳过空白字符和冒号（用于对象键值对解析）
func skipWhitespaceAndColon(json: String, start: Int64): Int64 {
    return skipCharacters(json, start, true, [b':'])
}

// skipCharacters 统一字符跳过函数
// 跳过指定的字符，支持空白字符检查和额外字符跳过
func skipCharacters(json: String, start: Int64, skipWhitespace: Bool, extraChars: Array<Byte>): Int64 {
    var i = start
    while (i < json.size) {
        let ch = json[i]
        var shouldSkip = false

        // 检查是否跳过空白字符
        if (skipWhitespace) {
            let isWhitespace = isWhitespaceOrControl(ch)
            if (isWhitespace) {
                shouldSkip = true
            }
        }

        // 检查是否跳过额外字符
        if (!shouldSkip && extraChars.size > 0) {
            for (extraChar in extraChars) {
                if (ch == extraChar) {
                    shouldSkip = true
                    break
                }
            }
        }

        if (!shouldSkip) {
            break
        }
        i++
    }
    return i
}

// skipWhitespaceCommaAndColon 跳过空白字符、逗号和冒号（复合跳过函数）
func skipWhitespaceCommaAndColon(json: String, start: Int64): Int64 {
    return skipCharacters(json, start, true, [b',', b':'])
}

// skipToChar 跳过空白字符，直到找到目标字符或遇到非空白字符
// 返回: (找到的索引, 是否找到目标字符)
// 如果遇到非空白字符但不是目标字符，返回该位置并设置found=false
func skipToChar(json: String, start: Int64, targetChars: Array<Byte>): (Int64, Bool) {
    var i = start
    while (i < json.size) {
        let ch = json[i]

        // 如果是目标字符，直接返回
        for (targetChar in targetChars) {
            if (ch == targetChar) {
                return (i, true)
            }
        }

        // 如果是空白字符，继续跳过
        if (isWhitespaceOrControl(ch)) {
            i++
            continue
        }

        // 遇到非空白字符且不是目标字符，停止搜索
        return (i, false)
    }

    // 到达字符串末尾
    return (i, false)
}

// trimWhitespace 移除字符串两端的空白字符（函数式优化版本）
func trimWhitespace(s: String): String {
    if (s.size == 0) {
        return s
    }
    
    // 使用函数式编程方式：跳过开头的空白字符
    let afterLeading = skipWhile(s, isWhitespaceOrControl)
    if (afterLeading.size == 0) {
        return ""
    }
    
    // 找到最后一个非空白字符的位置
    let lastNonWhitespace = findLast(afterLeading, not(isWhitespaceOrControl))
    match (lastNonWhitespace) {
        case Some(pos) => return afterLeading[..pos + 1]
        case None => return ""
    }
}