package gjson


// 查询匹配模块
// 基于Go版本优化模式，将查询匹配相关的工具函数从utils.cj分离至此文件
// 职责：处理JSON查询条件匹配、模式匹配和类型特定的比较操作

// matchLimit limits ReDos complexity with a simple implementation
func matchLimit(str: String, pattern: String): Bool {
    // 简单的性能安全实现：限制字符串和模式的最大长度
    let maxLength = 10000
    let maxPatternLength = 1000
    
    if (str.size > maxLength || pattern.size > maxPatternLength) {
        return false
    }
    
    // 实现基本的通配符匹配，限制复杂度
    return basicWildcardMatch(str, pattern, 0, 0, 0)
}

// 基本的通配符匹配实现，带有复杂度限制
func basicWildcardMatch(str: String, pattern: String, si: Int64, pi: Int64, depth: Int64): Bool {
    // 防止递归过深造成性能问题
    if (depth > 1000) {
        return false
    }
    
    var piVar = pi
    var siVar = si
    
    if (piVar >= pattern.size) {
        return siVar >= str.size
    }
    
    if (siVar >= str.size) {
        // 检查剩余的模式是否全是通配符
        while (piVar < pattern.size && pattern[piVar] == b'*') {
            piVar++
        }
        return piVar >= pattern.size
    }
    
    let pchar = pattern[piVar]
    let schar = str[siVar]
    
    match (pchar) {
        case b'*' =>
            // 通配符匹配：尝试匹配0个或多个字符
            return basicWildcardMatch(str, pattern, siVar, piVar + 1, depth + 1) ||
                   basicWildcardMatch(str, pattern, siVar + 1, piVar, depth + 1)
        case b'?' =>
            // 单字符通配符
            return basicWildcardMatch(str, pattern, siVar + 1, piVar + 1, depth + 1)
        case _ =>
            // 精确匹配
            if (schar == pchar) {
                return basicWildcardMatch(str, pattern, siVar + 1, piVar + 1, depth + 1)
            } else {
                return false
            }
    }
}

// queryMatches checks if a Result matches a query condition (optimized)
func queryMatches(rp: ArrayPathResult, value: Result): Bool {
    var val = value
    var rpv = rp.query.value
    
    // If there's a query path, get the field value first
    if (rp.query.path.size > 0) {
        val = value.get(rp.query.path)
    }
    
    // Optimize boolean conversion (~prefix optimization)
    if (rpv.size > 0 && rpv[0] == b'~') {
        rpv = rpv[1..]
        var ish = false
        var ok = true
        match (rpv) {
            case "*" =>
                ish = val.exists()
                ok = true
            case "null" =>
                ish = nullish(val)
                ok = true
            case "true" =>
                ish = trueish(val)
                ok = true
            case "false" =>
                ish = falseish(val)
                ok = true
            case _ => ok = false
        }
        if (ok) {
            rpv = "true"
            val = if (ish) {
                setResultBase(Kind.True, "")
            } else {
                setResultBase(Kind.False, "")
            }
        } else {
            rpv = ""
            val = createNullResult()
        }
    }
    
    // Early return if value doesn't exist
    if (!val.exists()) {
        return false
    }
    
    // Early return for empty operator (simple existence check)
    if (rp.query.op == "") {
        return true
    }
    
    // Type-specific optimized matching
    match (val.kind) {
        case Kind.String => 
            return matchStringValue(val.str, rp.query.op, rpv)
        case Kind.Number =>
            let rpvn = Float64.tryParse(rpv) ?? 0.0
            return matchNumberValue(val.num, rp.query.op, rpvn)
        case Kind.True =>
            return matchBoolValue(true, rp.query.op, rpv)
        case Kind.False =>
            return matchBoolValue(false, rp.query.op, rpv)
        case _ => return false
    }
}

// Optimized string matching
func matchStringValue(str: String, op: String, value: String): Bool {
    match (op) {
        case "=" | "==" => return str == value
        case "!=" => return str != value
        case "<" => return str < value
        case "<=" => return str <= value
        case ">" => return str > value
        case ">=" => return str >= value
        case "%" => return matchLimit(str, value)
        case "!%" => return !matchLimit(str, value)
        case _ => return false
    }
}

// Optimized number matching
func matchNumberValue(num: Float64, op: String, value: Float64): Bool {
    match (op) {
        case "=" | "==" => return num == value
        case "!=" => return num != value
        case "<" => return num < value
        case "<=" => return num <= value
        case ">" => return num > value
        case ">=" => return num >= value
        case _ => return false
    }
}

// Optimized boolean matching
func matchBoolValue(b: Bool, op: String, value: String): Bool {
    match (op) {
        case "=" | "==" => return (b && value == "true") || (!b && value == "false")
        case "!=" => return (b && value != "true") || (!b && value != "false")
        case ">" => return b && value == "false"
        case ">=" => return b || value == "false"
        case "<" => return !b && value == "true"
        case "<=" => return !b || value == "true"
        case _ => return false
    }
}