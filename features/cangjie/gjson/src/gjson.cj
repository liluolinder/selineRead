package gjson

public func parse(json: String): Result {
    var i = 0
    while (i < json.size) {
        if (!isWhitespaceOrControl(json[i])) {
            break
        }
        i++
    }
    
    if (i >= json.size) {
        return createNullResult()
    }
    
    let (_, result, success) = parseValue(json, Int64(i))
    if (success) {
        return result
    }
    return createNullResult()
}

// getBytes 处理字节数组的路径查询
// 注意: unsafe String.withRawData 在此处是安全的，因为:
// 1. 字节数组来源是用户传入的有效 JSON 数据
// 2. String.withRawData 只是重新包装字节，不修改内容
// 3. 如果字节数组不是有效 UTF-8，后续解析会失败但不会造成内存问题
public func getBytes(json: Array<Byte>, path: String): Result {
    let str = unsafe { String.withRawData(json) }
    return get(str, path)
}

// parseBytes 解析字节数组返回Result对象
// 注意: unsafe String.withRawData 在此处是安全的，原因同 getBytes
public func parseBytes(json: Array<Byte>): Result {
    let str = unsafe { String.withRawData(json) }
    return parse(str)
}

// 处理修饰符（@）和静态路径（!）前缀
func handleModifierOrStaticPath(json: String, path: String): ?Result {
    if (path.size <= 1) {
        return None
    }
    // 检查是否为修饰符或静态路径
    if ((path[0] == b'@' && !DisableModifiers) || path[0] == b'!') {
        let (npath, rjson, ok) = if (path[0] == b'@') {
            execModifier(json, path)
        } else {
            execStatic(json, path)
        }
        if (ok) {
            if (npath.size > 0 && (npath[0] == b'|' || npath[0] == b'.')) {
                let res = get(rjson, npath[1..])
                return Some(res.setIndex(0))
            }
            return Some(parse(rjson))
        }
    }
    return None
}

// 处理子选择器 ([...] 或 {...})
func handleSubSelector(json: String, path: String): ?Result {
    if (path.size <= 1 || (path[0] != b'[' && path[0] != b'{')) {
        return None
    }
    let (sels, npath, ok) = parseSubSelectors(path)
    if (!ok) {
        return None
    }
    let kind = path[0]
    let builder = StringBuilder()
    builder.append(if (kind == b'[') { '[' } else { '{' })
    var i = 0
    for (sel in sels) {
        let res = get(json, sel.path)
        if (res.exists()) {
            if (i > 0) {
                builder.append(',')
            }
            if (kind == b'{') {
                if (sel.name.size > 0) {
                    builder.append(sel.name)
                } else {
                    let last = nameOfLast(sel.path)
                    builder.append(escape(last))
                }
                builder.append(':')
            }
            builder.append(res.raw)
            i++
        }
    }
    builder.append(if (kind == b'[') { ']' } else { '}' })
    let res = createJSONResult(builder.toString())
    if (npath.size > 0) {
        return Some(res.get(npath[1..]))
    }
    return Some(res)
}

// 处理常规路径解析
func handleRegularPath(json: String, path: String): ParseContext {
    let ctx = ParseContext(json)
    if (path.size >= 2 && path[0] == b'.' && path[1] == b'.') {
        parseArray(ctx, 0, path[2..])
    } else {
        for (i in 0..json.size) {
            if (json[i] == b'{') {
                parseObject(ctx, i + 1, path)
                break
            } else if (json[i] == b'[') {
                parseArray(ctx, i + 1, path)
                break
            }
        }
    }
    return ctx
}

public func get(json: String, path: String): Result {
    // 优先处理修饰符和静态路径
    if (path.size > 1) {
        if (let Some(result) <- handleModifierOrStaticPath(json, path)) {
            return result
        }
        if (let Some(result) <- handleSubSelector(json, path)) {
            return result
        }
    }

    // 处理常规路径
    let ctx = handleRegularPath(json, path)

    // 处理管道操作
    if (ctx.piped) {
        let res = ctx.value.get(ctx.pipe)
        return res.setIndex(0)
    }

    // 填充索引并返回结果
    fillIndex(json, ctx)
    return ctx.value
}

// Helper functions
func nameOfLast(path: String): String {
    for (i in (path.size - 1)..0) {
        if (path[i] == b'|' || path[i] == b'.') {
            if (i > 0 && path[i - 1] != b'\\') {
                return path[i + 1..]
            }
        }
    }
    return path
}

func fillIndex(json: String, ctx: ParseContext): Unit {
    if (ctx.value.raw.size > 0 && !ctx.calcd) {
        var index = 0
        if (ctx.value.raw.size <= json.size) {
            let rawFirstChar = if (ctx.value.raw.size > 0) { ctx.value.raw[0] } else { b'\0' }
            let isStringVal = rawFirstChar == b'"'
            for (i in 0..(json.size - ctx.value.raw.size + 1)) {
                if (json[i] == rawFirstChar) {
                    var found = true
                    for (j in 0..ctx.value.raw.size) {
                        if (json[i + j] != ctx.value.raw[j]) {
                            found = false
                            break
                        }
                    }
                    if (found) {
                        if (isStringVal) {
                            let after = i + ctx.value.raw.size
                            var skipPos = after
                            while (skipPos < json.size && json[skipPos] <= b' ') {
                                skipPos++
                            }
                            if (skipPos < json.size && json[skipPos] == b':') {
                                continue
                            }
                        }
                        index = i
                        break
                    }
                }
            }
        }
        ctx.value = ctx.value.setIndex(Int64(index))
    }
}

// runeit returns the rune from the the \uXXXX
func runeit(json: String): Rune {
    if (json.size < 4) {
        return r'0'
    }
    let hex = json[..4]
    match (Rune.tryParse("'\\u{${hex}}'")) {
        case Some(r) => return r
        case None => return r'0'
    }
}

class ParseContext {
    public let json: String
    public var value: Result
    public var pipe: String
    public var piped: Bool
    public var calcd: Bool

    init(json: String) {
        this.json = json
        this.value = createNullResult()
        this.pipe = ""
        this.piped = false
        this.calcd = false
    }
}
public func getMany(json: String, paths: Array<String>): Array<Result> {
    let results = Array<Result>(paths.size, repeat: Result())
    for (i in 0..paths.size) {
        let path = paths[i]
        results[i] = get(json, path)
    }
    return results
}

public func getManyBytes(json: Array<Byte>, paths: Array<String>): Array<Result> {
    let res = Array<Result>(paths.size, repeat: Result())
    for (i in 0..paths.size) {
        let path = paths[i]
        res[i] = getBytes(json, path)
    }
    return res
}

class SubSelector {
    public let name: String
    public let path: String
    
    init(name: String, path: String) {
        this.name = name
        this.path = path
    }
}

func parseSubSelectors(path: String): (ArrayList<SubSelector>, String, Bool) {
    let sels = ArrayList<SubSelector>()
    var i = 1  // Skip initial '[' or '{'
    var depth = 1
    var colon = 0
    var start = 1
    var modifier = 0
    var ok = false

    func pushSel() {
        let sel = if (colon == 0) {
            SubSelector("", path[start..i])
        } else {
            SubSelector(path[start..colon], path[colon+1..i])
        }
        sels.add(sel)
        colon = 0
        modifier = 0
        start = i + 1
    }

    while (i < path.size) {
        match (path[i]) {
            case b'\\' => i++
            case b'@' => if (modifier == 0 && i > 0 && (path[i-1] == b'.' || path[i-1] == b'|')) {
                modifier = i
            }
            case b':' => if (modifier == 0 && colon == 0 && depth == 1) {
                colon = i
            }
            case b',' => if (depth == 1) {
                pushSel()
            }
            case b'"' => i++
                while (i < path.size) {
                    if (path[i] == b'\\') {
                        i++
                    } else if (path[i] == b'"') {
                        break
                    }
                    i++
                }
            case b'[' | b'(' | b'{' => depth++
            case b']' | b')' | b'}' => 
                depth--
                if (depth == 0) {
                    pushSel()
                    let newPath = path[i+1..]
                    return (sels, newPath, true)
                }
            case _ => ()
        }
        i++
    }
    return (sels, "", false)
}

func appendJSONString(dst: ArrayList<Byte>, s: String): ArrayList<Byte> {
    dst.add(b'"')
    for (j in 0..s.size) {
        var i = j
        let c = s[i]
        if (c < b' ') {
            dst.add(b'\\')
            match (c) {
                case b'\b' => dst.add(b'b')
                case b'\f' => dst.add(b'f')
                case b'\n' => dst.add(b'n')
                case b'\r' => dst.add(b'r')
                case b'\t' => dst.add(b't')
                case _ =>
                    dst.add(b'u')
                    appendHex16(dst, UInt16(c))
            }
        } else if (!DisableEscapeHTML && (c == b'>' || c == b'<' || c == b'&')) {
            dst.add(b'\\')
            dst.add(b'u')
            appendHex16(dst, UInt16(c))
        } else if (c == b'\\') {
            dst.add(b'\\')
            dst.add(b'\\')
        } else if (c == b'"') {
            dst.add(b'\\')
            dst.add(b'"')
        } else if (c > 127) {
            // 处理UTF-8字符
            let (r, n) = decodeRuneInString(s[i..])
            if (n == 0 ) {
                break
            }
            if (r == r'0' && n == 1) {
                dst.add(all: "\\ufffd".toArray())
            } else if (r == r'\u{2028}' || r == r'\u{2029}') {
                dst.add(all: "\\u202".toArray())
                dst.add(HEX_CHARS[r.position() & 0xF])
            } else {
                dst.add(all: s[i..i+n].toArray())
            }
            i = i + n - 1
        } else {
            dst.add(c)
        }
    }
    dst.add(b'"')
    return dst
}
