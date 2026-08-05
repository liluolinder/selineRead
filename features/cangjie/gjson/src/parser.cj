package gjson



func parseObject(ctx: ParseContext, ii: Int64, path: String): (Int64, Bool) {
    var i = ii
    var key = createNullResult()
    var value = createNullResult()
    var isMatch = false
    var json = ctx.json

    // 解析路径 (支持转义和通配符)
    let rp = parseObjectPath(path)
    if (!rp.more && rp.piped) {
        ctx.pipe = rp.pipe
        ctx.piped = true
    }

    while (i < json.size) {
        // 跳过空白字符
        i = skipWhitespace(json, i)
        if (i >= json.size) {
            break
        }

        // 解析键 (严格 JSON 字符串格式)
        if (json[i] == b'"') {
            let s = i
            var kesc = false
            var ok = false
            (i, key, kesc, ok) = parseKeyString(json, i + 1)
            if (!ok) {
                return (i, false)
            }

            // 检查键是否匹配路径 (支持通配符和转义)
            if (rp.wild) {
                isMatch = if (kesc) {
                    matchLimit(unescape(key.str), rp.part)
                } else {
                    matchLimit(key.str, rp.part)
                }
            } else {
                isMatch = if (kesc) {
                    rp.part == unescape(key.str)
                } else {
                    rp.part == key.str
                }
            }
            // 注意：这里不要限制 isMatch，让键匹配的逻辑在后面处理
        } else if (json[i] == b'}') {
            i++
            break
        } else {
            i++
            continue
        }

        // 跳过冒号和空白
        i = skipWhitespaceAndColon(json, i)

        // 解析值
        let (newI, res, ok) = parseValue(json, i)
        if (!ok) {
            return (i, false)
        }
        value = res
        i = newI

        // 检查是否匹配键且没有更多路径部分
        let hit = isMatch && !rp.more
        if (hit) {
            ctx.value = value
            return (i, true)
        }
        
        // 如果键匹配但还有更多路径部分，需要递归处理
        if (isMatch && rp.more) {
            if (let Some(v) <- parseNested(value, rp.path)) {
                ctx.value = v
                return (i, true)
            }
        }

        // 跳过逗号和空白
        i = skipWhitespaceAndComma(json, i)
    }

    (i, false)
}

// 解析键字符串 (类似 Go 的实现)
// 使用统一的字符串解析核心函数重构，消除重复逻辑
func parseKeyString(json: String, ii: Int64): (Int64, Result, Bool, Bool) {
    var s = ii
    let strResult = parseString(json, ii)

    var key = createNullResult()
    if (strResult.ok) {
        // 成功解析，创建Result对象
        // raw包含引号，需要提取未转义的内容
        let content = if (strResult.raw.size >= 2) {
            if (strResult.escaped) {
                unescape(strResult.raw[1..strResult.raw.size-1])  // 去掉引号并转义
            } else {
                strResult.raw[1..strResult.raw.size-1]  // 去掉引号
            }
        } else {
            ""  // 理论上不会发生，但防御性编程
        }
        key = createStringResultWithIndex(strResult.raw, content, s-1)  // s-1是引号的位置
        return (strResult.index, key, strResult.escaped, true)
    } else {
        // 解析失败，创建默认Result
        // raw已经是json[s-1..]，即从引号到字符串末尾
        let content = if (strResult.raw.size > 1) { strResult.raw[1..] } else { "" }
        key = createStringResultWithIndex(strResult.raw, content, s-1)
        return (strResult.index, key, strResult.escaped, false)
    }
}

// 解析 JSON 数组
func parseArray(ctx: ParseContext, ii: Int64, path: String): (Int64, Bool) {
    var i = ii
    var index = 0
    var isMatch = false
    let json = ctx.json

    // 处理管道逻辑
    let rp = parseArrayPath(path)
    if (!rp.more && rp.piped) {
        ctx.pipe = rp.pipe
        ctx.piped = true
    }

    // 特殊处理：如果路径是单独的 # 号，计算数组长度
    if (rp.part == "#" && !rp.more) {
        var count = 0
        while (i < json.size) {
            // 跳过空白字符
            i = skipWhitespace(json, i)
            if (i >= json.size || json[i] == b']') {
                break
            }

            // 解析值（不保存结果，只计数）
            let (newI, _, ok) = parseValue(json, i)
            if (!ok) {
                return (i, false)
            }

            count++
            i = newI

            // 跳过逗号和空白
            while (i < json.size && (json[i] <= b' ' || json[i] == b',')) {
                i++
            }
        }

        // 返回数组长度作为数字
        ctx.value = createNumberResult("${count}", Float64(count))
        return (i, true)
    }

    // 处理 #(...)# 返回所有匹配的情况
    if (rp.query.on && rp.query.all) {
        let matchedResults = ArrayList<Result>()
        let matchedIndexes = ArrayList<Int64>()
        
        while (i < json.size) {
            i = skipWhitespace(json, i)
            if (i >= json.size || json[i] == b']') {
                break
            }

            let s = i
            let (newI, res, ok) = parseValue(json, i)
            if (!ok) {
                return (i, false)
            }

            if (queryMatches(rp, res)) {
                matchedResults.add(res)
                matchedIndexes.add(Int64(s))
            }

            index++
            i = newI
            i = skipWhitespaceAndComma(json, i)
        }

        // 构建结果数组
        if (matchedResults.size > 0) {
            // 如果有后续路径，对每个匹配元素应用
            if (rp.more && rp.path.size > 0) {
                let subResults = ArrayList<Result>()
                for (matchedRes in matchedResults) {
                    let subRes = matchedRes.get(rp.path)
                    if (subRes.exists()) {
                        subResults.add(subRes)
                    }
                }
                ctx.value = Result(Kind.JSON, buildJSONArray(subResults), "", 0.0, 0, ArrayList<Int64>())
            } else {
                ctx.value = Result(Kind.JSON, buildJSONArray(matchedResults), "", 0.0, 0, matchedIndexes)
            }
            return (i, true)
        }
        return (i, false)
    }

    while (i < json.size) {
        // 跳过空白字符
        i = skipWhitespace(json, i)
        if (i >= json.size || json[i] == b']') {
            break
        }

        // 解析值
        let (newI, res, ok) = parseValue(json, i)
        if (!ok) {
            return (i, false)
        }

        // 检查数组路径匹配
        if (rp.arrch) {
            if (rp.alogok) {
                // #. 操作符 - 收集所有元素的指定字段
                if (rp.alogkey.size > 0) {
                    // 需要收集所有元素的字段
                    let allResults = ArrayList<Result>()
                    var tempI = i
                    
                    while (tempI < json.size) {
                        tempI = skipWhitespace(json, tempI)
                        if (tempI >= json.size || json[tempI] == b']') {
                            break
                        }
                        
                        let (nextI, elemRes, elemOk) = parseValue(json, tempI)
                        if (!elemOk) {
                            break
                        }
                        
                        let fieldRes = elemRes.get(rp.alogkey)
                        if (fieldRes.exists()) {
                            allResults.add(fieldRes)
                        }
                        
                        tempI = nextI
                        tempI = skipWhitespaceAndComma(json, tempI)
                    }
                    
                    // 构建结果数组
                    if (allResults.size > 0) {
                        ctx.value = createJSONResult(buildJSONArray(allResults))
                        return (tempI, true)
                    }
                    return (tempI, false)
                }
                isMatch = true
            } else if (rp.query.on) {
                // 查询条件 - 检查条件
                isMatch = queryMatches(rp, res)
            } else {
                // 简单数组计数
                isMatch = true
            }
        } else {
            // 索引匹配
            let targetIndex = Int64.tryParse(rp.part) ?? -1
            isMatch = (index == targetIndex)
        }

        if (isMatch) {
            ctx.value = res
            if (rp.more) {
                return parseNext(ctx, newI, rp.path)
            }
            return (newI, true)
        }

        index++
        i = newI

        // 跳过逗号和空白
        i = skipWhitespaceAndComma(json, i)
    }

    (i, false)
}

// 解析字符串（处理转义字符）
// 统一字符串解析核心函数
// 返回: (新索引, 原始字符串, 是否转义, 是否成功)
// 参数ii: 起始引号之后的索引（即'"'的下一个字符位置）

// StringParseResult 用于替代 parseStringCore 函数的4元素元组返回值
struct StringParseResult {
    public var index: Int64
    public var raw: String
    public var escaped: Bool
    public var ok: Bool

    init() {
        this.index = 0
        this.raw = ""
        this.escaped = false
        this.ok = false
    }

    init(index: Int64, raw: String, escaped: Bool, ok: Bool) {
        this.index = index
        this.raw = raw
        this.escaped = escaped
        this.ok = ok
    }
}

func parseString(json: String, ii: Int64): StringParseResult {
    parseStringUnified(json, if (ii > 0) { ii - 1 } else { 0 })
}

// 解析 JSON 对象或数组（块）
func parseBlock(json: String, i: Int64): (Int64, String) {
    let raw = squash(json[i..])
    return (i + raw.size, raw)
}

// 解析数字 - 使用现有的tonum函数
func parseNumber(json: String, i: Int64): (String, Float64) {
    return tonum(json[i..])
}

// 在嵌套的 JSON 值上继续解析路径
// 统一 parseObject/parseArray 的递归逻辑
func parseNested(value: Result, path: String): ?Result {
    if (!value.isObject() && !value.isArray()) {
        return None
    }
    let newCtx = ParseContext(value.raw)
    var hit = false
    if (value.isObject()) {
        let (_, rhit) = parseObject(newCtx, 1, path) // 跳过开头的 '{'
        hit = rhit
    } else {
        let (_, rhit) = parseArray(newCtx, 1, path) // 跳过开头的 '['
        hit = rhit
    }
    if (hit) {
        return Some(newCtx.value)
    }
    return None
}

// 辅助函数：解析下一个路径部分
func parseNext(ctx: ParseContext, i: Int64, path: String): (Int64, Bool) {
    if (path.size == 0) {
        return (i, true)
    }

    // 去掉开头的 '.' 前缀（直接路径无需 dot 前缀）
    let remainingPath = if (path[0] == b'.') { path[1..] } else { path }

    if (let Some(v) <- parseNested(ctx.value, remainingPath)) {
        ctx.value = v
        return (i, true)
    }

    return (i, false)
}
