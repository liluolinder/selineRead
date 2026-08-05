package gjson

// executor.cj - 分离的验证和执行逻辑
// 基于Go版本的优化模式，将execModifier和execStatic函数从gjson.cj移至此文件
// 保持职责分离：gjson.cj专注于核心API，executor.cj处理路径执行逻辑

// execModifier handles modifier paths like @pretty, @reverse, etc.
func execModifier(json: String, path: String): (String, String, Bool) {
    if (path.size < 2 || path[0] != b'@') {
        return ("", json, false)
    }
    
    var i = 1
    while (i < path.size && path[i] != b'.' && path[i] != b'|' && path[i] != b':') {
        i++
    }
    
    let name = path[1..i]
    let (arg, newI) = if (i < path.size && path[i] == b':') {
        // Extract argument after colon - go to end of string or next real separator
        var j = i + 1
        // 对于冒号后的参数，只有在遇到点号分隔符时才停止，管道符可能是参数的一部分
        while (j < path.size && path[j] != b'.') {
            j++
        }
        (path[i+1..j], j)
    } else {
        ("", i)
    }
    
    if (modifiers.contains(name)) {
        let modifier = match (modifiers.get(name)) {
            case Some(m) => m
            case None => { json: String, arg: String => json }
        }
        let result = modifier(json, arg)
        let remaining = if (newI < path.size) { path[newI..] } else { "" }
        return (remaining, result, true)
    }
    
    // 不存在的修饰符：无剩余路径返回原始JSON，有剩余路径让出给常规路径处理
    let remaining = if (newI < path.size) { path[newI..] } else { "" }
    if (remaining.size > 0) {
        return (remaining, json, false)
    }
    return (remaining, json, true)
}

// execStatic handles static paths starting with !
// Literals: !value constructs a static JSON value
// Examples: !"Happysoft" → "Happysoft", !true → true, !123 → 123
func execStatic(json: String, path: String): (String, String, Bool) {
    if (path.size < 2 || path[0] != b'!') {
        return ("", json, false)
    }
    
    var i = 1
    while (i < path.size && path[i] != b'.' && path[i] != b'|') {
        i++
    }
    
    let lit = path[1..i]
    let remaining = if (i < path.size) { path[i..] } else { "" }
    
    // Check if literal is already valid JSON
    if (valid(lit)) {
        return (remaining, lit, true)
    }
    
    // Not valid JSON, treat as string and quote it
    let quoted = "\"" + escape(lit) + "\""
    return (remaining, quoted, true)
}
