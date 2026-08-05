package gjson


// ============================================================================
// 路径工具合并模块
// 合并自: path_utils.cj + path_processing.cj
// 基于Go版本优化模式，提供统一的路径处理功能
// 职责：路径解析、管道处理、字符安全检查和路径结构定义
// ============================================================================

// ============================================================================
// 路径处理工具函数（原path_processing.cj内容）
// ============================================================================

// isDotPiperChar checks if the next char is '@', '[', or '{'
func isDotPiperChar(s: String): Bool {
    if (DisableModifiers) {
        return false
    }
    let c = s[0]
    if (c == b'@') {
        var i = 1
        while (i < s.size) {
            if (s[i] == b'.' || s[i] == b'|' || s[i] == b':') {
                break
            }
            i++
        }
        return modifiers.contains(s[1..i])
    }
    return c == b'[' || c == b'{'
}

// isSafePathKeyChar checks if a character is safe for unescaped path keys
// 使用函数式编程模式：组合谓词函数
func isSafePathKeyChar(c: Byte): Bool {
    let isSafeRange = or(
        or(
            and({ x => x >= b'a' }, { x => x <= b'z' }),     // 小写字母
            and({ x => x >= b'A' }, { x => x <= b'Z' })      // 大写字母
        ),
        and({ x => x >= b'0' }, { x => x <= b'9' })          // 数字
    )

    let isSpecialSafe = or(
        or({ x => x <= b' ' }, { x => x > b'~' }),           // 控制字符或高位字符
        or(
            or({ x => x == b'_' }, { x => x == b'-' }),      // 下划线和连字符
            { x => x == b':' }                               // 冒号
        )
    )

    return isSafeRange(c) || isSpecialSafe(c)
}

// ============================================================================
// 路径结构定义和解析函数（原path_utils.cj内容）
// ============================================================================

// Common path splitting result structure
struct PathSplitResult {
    public var part: String
    public var path: String
    public var pipe: String
    public var piped: Bool
    public var more: Bool

    init() {
        this.part = ""
        this.path = ""
        this.pipe = ""
        this.piped = false
        this.more = false
    }
}

// parseCommonPathElements extracts common path parsing logic for | and . characters
func parseCommonPathElements(path: String, i: Int64, checkDotPiper: Bool): (PathSplitResult, Bool) {
    var r = PathSplitResult()
    match (path[i]) {
        case b'|' =>
            r.part = path[..i]
            r.pipe = path[i+1..]
            r.piped = true
            return (r, true)
        case b'.' =>
            r.part = path[..i]
            let isDotPiper = i < path.size - 1 && isDotPiperChar(path[i+1..])
            if (checkDotPiper && isDotPiper) {
                r.pipe = path[i+1..]
                r.piped = true
            } else {
                r.path = path[i+1..]
                r.more = true
            }
            return (r, true)
        case _ => return (r, false)
    }
}

struct ArrayPathResult {
    public var part: String
    public var path: String
    public var pipe: String
    public var piped: Bool
    public var more: Bool
    public var alogok: Bool
    public var arrch: Bool
    public var alogkey: String
    public var query: QueryInfo

    init() {
        this.part = ""
        this.path = ""
        this.pipe = ""
        this.piped = false
        this.more = false
        this.alogok = false
        this.arrch = false
        this.alogkey = ""
        this.query = QueryInfo()
    }
    init(query: QueryInfo){
        this()
        this.query = query
    }
}

struct ObjectPathResult {
    public var part: String
    public var path: String
    public var pipe: String
    public var piped: Bool
    public var wild: Bool
    public var more: Bool

    init() {
        this.part = ""
        this.path = ""
        this.pipe = ""
        this.piped = false
        this.wild = false
        this.more = false
    }
}

struct QueryInfo {
    public var on: Bool
    public var all: Bool
    public var path: String
    public var op: String
    public var value: String

    init() {
        this.on = false
        this.all = false
        this.path = ""
        this.op = ""
        this.value = ""
    }
    init(op:String, value: String) {
        this()
        this.op = op
        this.value = value
    }
}

struct QueryParseResult {
    public var path: String
    public var op: String
    public var value: String
    public var remain: String
    public var index: Int64
    public var vesc: Bool
    public var ok: Bool

    init() {
        this.path = ""
        this.op = ""
        this.value = ""
        this.remain = ""
        this.index = 0
        this.vesc = false
        this.ok = false
    }

    init(path: String, op: String, value: String, remain: String, index: Int64, vesc: Bool, ok: Bool) {
        this.path = path
        this.op = op
        this.value = value
        this.remain = remain
        this.index = index
        this.vesc = vesc
        this.ok = ok
    }
}

func parseArrayPath(path: String): ArrayPathResult {
    var r = ArrayPathResult()
    for (j in 0..path.size) {
        var i = j

        // Check common path elements first (optimized)
        let (common, handled) = parseCommonPathElements(path, i, !r.arrch)
        if (handled) {
            r.part = common.part
            r.path = common.path
            r.pipe = common.pipe
            r.piped = common.piped
            r.more = common.more
            return r
        }

        match (path[i]) {
            case b'#' =>
                r.arrch = true
                if (i == 0) {
                    if (path.size > 1 && path[1] == b'.') {
                        r.alogok = true
                        r.alogkey = path[2..]
                        r.path = path[..1]
                    } else if (path.size > 1 && (path[1] == b'[' || path[1] == b'(')) {
                        // 解析查询条件
                        r.query.on = true
                        let qr = parseQuery(path[i..])
                        if (!qr.ok) {
                            break
                        }
                        if (qr.value.size >= 2 && qr.value[0] == b'"' && qr.value[qr.value.size-1] == b'"') {
                            let unescaped = qr.value[1..qr.value.size-1]
                            if (qr.vesc) {
                                r.query.value = unescape(unescaped)
                            } else {
                                r.query.value = unescaped
                            }
                        } else {
                            r.query.value = qr.value
                        }
                        r.query.path = qr.path
                        r.query.op = qr.op
                        i = qr.index - 1
                        if (i+1 < path.size && path[i+1] == b'#') {
                            r.query.all = true
                        }
                        // 注意：这里不处理 qr.remain，剩余路径由循环继续扫描 '.'/'|' 分隔符
                    } else {
                        // 单独的 # - 返回数组长度
                        r.part = "#"
                        r.path = path[1..]
                        return r
                    }
                }
            case _ => continue
        }
    }
    r.part = path
    r.path = ""
    return r
}

func parseObjectPath(path: String): ObjectPathResult {
    var r = ObjectPathResult()
    for (j in 0..path.size) {
        var i = j

        // Check common path elements first (optimized)
        let (common, handled) = parseCommonPathElements(path, i, true)
        if (handled) {
            r.part = common.part
            r.path = common.path
            r.pipe = common.pipe
            r.piped = common.piped
            r.more = common.more
            return r
        }

        match (path[i]) {
            case b'@' =>
                if (i > 0) {
                    r.part = path[..i]
                    r.pipe = path[i..]
                    r.piped = true
                    return r
                }
                // @ at position 0 is a regular key, not a pipe
                continue
            case b'*' | b'?' =>
                r.wild = true
                continue
            case b'\\' =>
                // 处理转义字符 - 使用更高效的字符串构建
                let bytes = ArrayList<Byte>()
                for (k in 0..i) {
                    bytes.add(path[k])
                }
                i++
                while (i < path.size) {
                    if (path[i] == b'\\') {
                        i++
                        if (i < path.size) {
                            bytes.add(path[i])
                        }
                        i++
                        continue
                    }
                    // 检查管道分隔符（被转义的点号不应该作为分隔符）
                    if (path[i] == b'|') {
                        r.part = unsafe { String.withRawData(bytes.toArray()) }
                        r.pipe = path[i+1..]
                        r.piped = true
                        return r
                    }
                    match (path[i]) {
                        case b'*' | b'?' =>
                            r.wild = true
                            bytes.add(path[i])
                        case _ => bytes.add(path[i])
                    }
                    i++
                }
                r.part = unsafe { String.withRawData(bytes.toArray()) }
                return r
            case _ => continue
        }
    }
    r.part = path
    return r
}

func parseQuery(query: String): QueryParseResult {
    if (query.size < 2 || query[0] != b'#' || (query[1] != b'(' && query[1] != b'[')) {
        return QueryParseResult("", "", "", "", 0, false, false)
    }
    var i = 2
    var j = 0
    var depth = 1
    var vesc = false
    while (i < query.size) {
        let ch = query[i]
        if (depth == 1 && j == 0) {
            match (ch) {
                case b'!'| b'='| b'<'| b'>'| b'%' => j = i
                case _ => ()
            }
        }
        if (ch == b'\\') {
            i++
            vesc = true
        } else if (ch == b'[' || ch == b'(') {
            depth++
        } else if (ch == b']' || ch == b')') {
            depth--
            if (depth == 0) {
                break
            }
        } else if (ch == b'"') {
            i++
            while (i < query.size) {
                if (query[i] == b'\\') {
                    i++
                    vesc = true
                } else if (query[i] == b'"') {
                    break
                }
                i++
            }
        }
        i++
    }
    if (depth > 0) {
        return QueryParseResult("", "", "", "", i, false, false)
    }
    var path = ""
    var op = ""
    var value = ""
    var remain = query[i+1..]
    if (j > 0) {
        path = trimWhitespace(query[2..j])
        value = trimWhitespace(query[j..i])
        // 解析操作符
        let v0 = value[0]
        let v1 = if (value.size > 1) { value[1] } else { b'\0' }
        let opsz = match ((v0, v1)) {
            case (b'!', b'=') => 2
            case (b'!', b'%') => 2
            case (b'<', b'=') => 2
            case (b'>', b'=') => 2
            case (b'=', b'=') => 2
            case (b'!', _) => 1
            case (b'<', _) => 1
            case (b'>', _) => 1
            case (b'=', _) => 1
            case (b'%', _) => 1
            case _ => 0
        }
        op = value[..opsz]
        value = trimWhitespace(value[opsz..])
    } else {
        path = trimWhitespace(query[2..i])
    }
    return QueryParseResult(path, op, value, remain, i + 1, vesc, true)
}