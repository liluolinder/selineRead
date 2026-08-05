package gjson

// 统一字符串解析器模块
// 提取字符串解析的重复逻辑，提供一致的API
// 基于Go版本优化模式，统一tostr、parseStringCore、squash中的字符串解析逻辑


// 字符串匹配上下文，用于跟踪解析状态
class StringMatchContext {
    public let json: String
    public var i: Int64
    public var escaped: Bool
    public var startPos: Int64

    init(json: String, startPos: Int64) {
        this.json = json
        this.i = startPos
        this.escaped = false
        this.startPos = startPos
    }
}

// 核心字符串匹配函数
// 从当前位置开始匹配一个JSON字符串（期望当前位置是开头的'"'）
// 返回: (结束索引, 是否包含转义字符, 是否成功找到匹配的引号)
func matchStringQuote(ctx: StringMatchContext): (Int64, Bool, Bool) {
    let json = ctx.json
    var i = ctx.i
    let startQuote = i  // 记录起始引号位置
    var escaped = false
    i++  // 跳过开头的引号

    while (i < json.size) {
        // 使用优化的字符跳过：ASCII值大于'\'的字符可以直接跳过
        if (json[i] > b'\\') {
            i++
            continue
        }

        if (json[i] == b'"') {
            // 检查引号是否被转义
            if (i > 0 && json[i-1] == b'\\') {
                var slashCount = 0
                var j = i - 2
                while (j >= startQuote && json[j] == b'\\') {
                    slashCount++
                    j--
                }
                // 偶数个斜杠表示引号被转义
                if (slashCount % 2 == 0) {
                    i++
                    continue
                }
            }
            // 找到匹配的结束引号
            return (i, escaped, true)
        }

        if (json[i] == b'\\') {
            escaped = true
            i++
            continue
        }

        i++
    }

    // 没有找到匹配的引号
    return (i, escaped, false)
}

// 解析JSON字符串并返回StringParseResult
// 这是parseStringCore的替代实现，使用统一的核心匹配函数
func parseStringUnified(json: String, startIndex: Int64): StringParseResult {
    if (startIndex >= json.size || json[startIndex] != b'"') {
        return StringParseResult(startIndex, "", false, false)
    }

    let ctx = StringMatchContext(json, startIndex)
    let (endIndex, escaped, ok) = matchStringQuote(ctx)

    if (ok) {
        let raw = json[startIndex..endIndex + 1]
        return StringParseResult(endIndex + 1, raw, escaped, true)
    } else {
        let raw = if (endIndex < json.size) { json[startIndex..endIndex] } else { json[startIndex..] }
        return StringParseResult(endIndex, raw, escaped, false)
    }
}

// 解析JSON字符串并返回原始字符串和未转义内容
// 这是tostr的替代实现，使用统一的核心匹配函数
func extractStringUnified(json: String): (String, String) {
    if (json.size == 0 || json[0] != b'"') {
        return (json, if (json.size > 1) { json[1..] } else { "" })
    }

    let ctx = StringMatchContext(json, 0)
    let (endIndex, escaped, ok) = matchStringQuote(ctx)

    if (ok) {
        let raw = json[..endIndex + 1]
        let content = if (escaped) {
            unescape(json[1..endIndex])
        } else {
            json[1..endIndex]
        }
        return (raw, content)
    } else {
        let raw = if (endIndex < json.size) { json[..endIndex] } else { json }
        let content = if (escaped) {
            unescape(json[1..])
        } else if (json.size > 1) {
            json[1..]
        } else {
            ""
        }
        return (raw, content)
    }
}

