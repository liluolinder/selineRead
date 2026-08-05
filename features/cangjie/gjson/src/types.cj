package gjson

import std.deriving.*

@Derive[ToString, Comparable]
public enum Kind {
    Null | False | True | Number | String | JSON
}

public class Result {
    public let kind: Kind
    public let raw: String
    public let str: String
    public let num: Float64
    public let index: Int64
    public let indexes: ArrayList<Int64>
    init() {
        this.kind = Kind.Null
        this.raw = ""
        this.str = ""
        this.num = 0.0
        this.index = 0
        this.indexes = ArrayList<Int64>()
    }
    init(kind: Kind) {
        this.kind = kind
        this.raw = ""
        this.str = ""
        this.num = 0.0
        this.index = 0
        this.indexes = ArrayList<Int64>()
    }
    init(kind: Kind, num: Float64) {
        this.kind = kind
        this.raw = ""
        this.str = ""
        this.num = num
        this.index = 0
        this.indexes = ArrayList<Int64>()
    }
    init(kind: Kind, raw: String, str: String, num: Float64, index: Int64, indexes: ArrayList<Int64>) {
        this.kind = kind
        this.raw = raw
        this.str = str
        this.num = num
        this.index = index
        this.indexes = indexes
    }
    public func array(): Array<Result> {
        if (this.kind == Kind.Null) {
            return Array<Result>()
        }
        if (!this.isArray()) {
            return Array<Result>(1, repeat: this)
        }
        let r = this.arrayOrMap(b'[', false)
        return r.a.toArray()
    }

    @Deprecated["use array() instead"]
    public func Array(): Array<Result> {
        return this.array()
    }
    public func isObject(): Bool {
        return this.kind == Kind.JSON && this.raw.size > 0 && this.raw[0] == b'{'
    }
    public func isArray(): Bool {
        return this.kind == Kind.JSON && this.raw.size > 0 && this.raw[0] == b'['
    }
    public func isString(): Bool {
        return this.kind == Kind.String
    }
    public func isBool(): Bool {
        return this.kind == Kind.True || this.kind == Kind.False
    }
    public func map(): HashMap<String, Result> {
        if (this.kind != Kind.JSON) {
            return HashMap<String, Result>()
        }
        let r = this.arrayOrMap(b'{', false)
        return r.o
    }
    public func exists(): Bool {
        return this.kind != Kind.Null || this.raw.size != 0
    }
    public func toString(): String {
        match (this.kind) {
            case Kind.String => return this.str
            case Kind.Number => return "${this.num}"
            case Kind.True => return "true"
            case Kind.False => return "false"
            case Kind.Null => return "null"
            case Kind.JSON => return this.raw
        }
    }
    public func value(): ?Any {
        match (this.kind) {
            case Kind.String => return this.str
            case Kind.False => return false
            case Kind.Number => return this.num
            case Kind.JSON =>
                let r = this.arrayOrMap(0, true)
                if (r.vc == b'{') {
                    return Some(r.oi)
                } else if (r.vc == b'[') {
                    return Some(r.ai)
                }
                return None
            case Kind.Null => None
            case Kind.True => return true
        }
    }
    private func parseJSONValueForArrayOrMap(json: String, start: Int64, indexOffset: Int64): (Result, Int64, Bool) {
        if (start >= json.size) {
            return (createNullResult(), start, false)
        }

        let (newIndex, value, ok) = parseValue(json, start)
        if (ok) {
            let adjustedValue = value.setIndex(value.index + indexOffset)
            return (adjustedValue, newIndex, true)
        }

        return (createNullResult(), start + 1, false)
    }

    // 确定JSON类型并跳过开头的空白字符
    private func determineJsonTypeAndSkipWhitespace(vc: Byte): (Byte, Int64) {
        let json = this.raw

        let targetChars = if (vc == 0) {
            [b'{', b'[']
        } else {
            [vc]
        }

        let (foundIndex, found) = skipToChar(json, 0, targetChars)
        var detectedVc: Byte = 0
        var newIndex = foundIndex

        if (found) {
            // 找到了目标字符
            detectedVc = if (vc == 0) { json[foundIndex] } else { vc }
            newIndex++  // 跳过找到的字符
        } else {
            // 没有找到目标字符，遇到非空白字符或到达末尾
            // detectedVc保持为0
        }

        return (detectedVc, newIndex)
    }

    // 处理对象条目
    private func processObjectEntry(r: ArrayOrMapResult, key: Result, value: Result, valueize: Bool): Unit {
        if (valueize) {
            if (!r.oi.contains(key.str)) {
                r.oi.add(key.str, value.value())
            }
        } else {
            if (!r.o.contains(key.str)) {
                r.o.add(key.str, value)
            }
        }
    }

    // 处理数组条目
    private func processArrayEntry(r: ArrayOrMapResult, value: Result, valueize: Bool): Unit {
        if (valueize) {
            r.ai.add(value.value())
        } else {
            r.a.add(value)
        }
    }

    // 主循环处理JSON值
    private func processJsonValuesLoop(json: String, startIndex: Int64, vc: Byte, valueize: Bool): ArrayOrMapResult {
        var i = startIndex
        var count = 0
        var key = createNullResult()
        var value = createNullResult()
        var r = ArrayOrMapResult()
        r.vc = vc

        // 初始化结果结构
        if (vc == b'{') {
            if (valueize) {
                r.oi = HashMap<String, Any>()
            } else {
                r.o = HashMap<String, Result>()
            }
        } else {
            if (valueize) {
                r.ai = ArrayList<Any>()
            } else {
                r.a = ArrayList<Result>()
            }
        }

        while (i < json.size) {
            if (isWhitespaceOrControl(json[i])) {
                i++
                continue
            }
            if (json[i] == b']' || json[i] == b'}') {
                break
            }
            // 使用统一的解析逻辑
            let (parsedValue, newIndex, ok) = parseJSONValueForArrayOrMap(json, i, this.index)
            if (!ok) {
                i = newIndex
                continue
            }
            value = parsedValue
            i = newIndex

            if (vc == b'{') {
                if (count % 2 == 0) {
                    key = value
                } else {
                    processObjectEntry(r, key, value, valueize)
                }
                count++
            } else {
                processArrayEntry(r, value, valueize)
            }
            i++
        }

        // 处理索引调整
        if (this.indexes.size == r.a.size) {
            for (idx in 0..r.a.size) {
                r.a[idx] = r.a[idx].setIndex(this.indexes[idx])
            }
        }
        return r
    }

    private func arrayOrMap(vc: Byte, valueize: Bool): ArrayOrMapResult {
        let json = this.raw
        let (detectedVc, startIndex) = determineJsonTypeAndSkipWhitespace(vc)
        return processJsonValuesLoop(json, startIndex, detectedVc, valueize)
    }
    public func less(token: Result, caseSensitive: Bool): Bool {
        if (this.kind < token.kind) {
            return true
        }
        if (this.kind > token.kind) {
            return false
        }
        if (this.kind == Kind.String) {
            if (caseSensitive) {
                return this.str < token.str
            }
            return stringLessInsensitive(this.str, token.str)
        }
        if (this.kind == Kind.Number) {
            return this.num < token.num
        }
        return this.raw < token.raw
    }
    public func paths(json: String): ArrayList<String> {
        if (this.indexes.size == 0) {
            return ArrayList<String>(0)
        }
        let paths = ArrayList<String>()
        this.forEach(
            {
                _, value =>
                paths.add(value.path(json))
                true
            }
        )
        if (paths.size != this.indexes.size) {
            return ArrayList<String>()
        }
        return paths
    }
    public func path(json: String): String {
        var path = StringBuilder()
        var comps = ArrayList<String>() // 原始组件
        var i = this.index - 1

        // 检查 JSON 是否有效

        if (this.index + this.raw.size > json.size || !json[this.index..].startsWith(this.raw)) {
            return "" // 静默失败，匹配 Go 的行为
        }

        // 反向遍历 JSON
        while (i >= 0) {
            if (isWhitespaceOrControl(json[i])) {
                i--
                continue
            }

            match (json[i]) {
                case b':' =>
                    // 在对象内，提取 key
                    while (i >= 0 && json[i] != b'"') {
                        i--
                    }
                    if (i < 0) {
                        return "" // 格式错误
                    }
                    let raw = revSquash(json[..i + 1])
                    i -= raw.size
                    comps.add(raw)
                    // 继续处理剩余部分
                    let remaining = revSquash(json[..i + 1])
                    i -= remaining.size
                    i++ // 调整索引

                case b'{' =>
                    // 遇到对象开头，可能是格式错误
                    return ""

                case b',' | b'[' =>
                    // 在数组内，计算位置
                    var arrIdx = 0
                    if (json[i] == b',') {
                        arrIdx++
                        i--
                    }
                    while (i >= 0) {
                        match (json[i]) {
                            case b':' => return "" // 意外冒号
                            case b',' => arrIdx++
                            case b'[' =>
                                comps.add(arrIdx.toString())
                                break
                            case b']' | b'}' | b'"' =>
                                let raw = revSquash(json[..i + 1])
                                i -= raw.size - 1
                            case _ => i--
                        }
                    }
                case _ => i--
            }
        }

        // 构建路径
        if (comps.size == 0) {
            return "@this" // 默认值
        }

        // 反向拼接组件
        for (idx in (comps.size - 1)..0 : -1) {
            let rcomp = parse(comps[idx])
            if (!rcomp.exists()) {
                return ""
            }
            let comp = escape(rcomp.string())
            path.append('.')
            path.append(comp)
        }
        if (path.size > 0) {
            return path.toString()[1..]
        }
        return ""
    }
    public func forEach(iterator: (Result, Result) -> Bool): Unit {
        if (!this.exists()) {
            return
        }
        if (this.kind != Kind.JSON) {
            iterator(createNullResult(), this)
            return
        }

        let json = this.raw
        var i = 0
        var isObject = false
        var key = Result()
        var value = Result()

        // 确定 JSON 类型（对象或数组）
        let (foundIndex, found) = skipToChar(json, i, [b'{', b'['])
        if (!found) {
            // 没有找到 { 或 [，遇到非空白字符或到达末尾
            return
        }
        i = foundIndex

        if (json[i] == b'{') {
            i++
            isObject = true
            key = setResultBase(Kind.String, "")
        } else {  // json[i] == b'['
            i++
            key = createNumberResult("", -1.0)
        }

        var str: String
        var escaped: Bool
        var ok: Bool
        var idx = 0

        // 主遍历逻辑
        while (i < json.size) {
            if (isObject) {
                // 处理对象的键
                if (json[i] != b'"') {
                    i++
                    continue
                }
                let s = i
                let strResult = parseString(json, i + 1)
                if (!strResult.ok) {
                    return
                }
                key = createStringResultWithIndex(raw, strResult.raw, s + this.index)
                i = strResult.index
            } else {
                key = key.setNum(key.num + 1.0)
            }

            // 跳过空白和分隔符
            i = skipWhitespaceCommaAndColon(json, i)

            // 解析值
            let s = i
            (i, value, ok) = parseValue(json, i)
            if (!ok) {
                return
            }

            // 处理索引
            if (this.indexes.size != 0) {
                if (idx < this.indexes.size) {
                    value = value.setIndex(this.indexes[idx])
                }
            } else {
                value = value.setIndex(s + this.index)
            }

            // 调用迭代器（最后一个元素也会被迭代，终止检查由外层循环条件处理）
            if (!iterator(key, value)) {
                return
            }
            idx++
        }
    }

    @Deprecated["use forEach() instead"]
    public func ForEach(iterator: (Result, Result) -> Bool): Unit {
        this.forEach(iterator)
    }

    public func get(path: String): Result {
        var r = get(this.raw, path)
        if (r.indexes.size == 0) {
            r = r.setIndex(r.index + this.index)
        } else {
            for (i in 0..r.indexes.size) {
                r.indexes[i] += this.index
            }
        }
        return r
    }
    internal func setNum(num: Float64): Result {
        return Result(this.kind, this.raw, this.str, num, this.index, this.indexes)
    }
    internal func setIndex(index: Int64): Result {
        return Result(this.kind, this.raw, this.str, this.num, index, this.indexes)
    }
}

class ArrayOrMapResult {
    public var a: ArrayList<Result>
    public var ai: ArrayList<Any>
    public var o: HashMap<String, Result>
    public var oi: HashMap<String, Any>
    public var vc: Byte

    init() {
        this.a = ArrayList<Result>()
        this.ai = ArrayList<Any>()
        this.o = HashMap<String, Result>()
        this.oi = HashMap<String, Any>()
        this.vc = 0
    }
}

func stringLessInsensitive(a: String, b: String): Bool {
    for (i in 0..min(a.size, b.size)) {
        let aChar = a[i]
        let bChar = b[i]
        if (aChar >= b'A' && aChar <= b'Z') {
            if (bChar >= b'A' && bChar <= b'Z') {
                if (aChar < bChar) {
                    return true
                }
                if (aChar > bChar) {
                    return false
                }
            } else {
                if (aChar + 32 < bChar) {
                    return true
                }
                if (aChar + 32 > bChar) {
                    return false
                }
            }
        } else if (bChar >= b'A' && bChar <= b'Z') {
            if (aChar < bChar + 32) {
                return true
            }
            if (aChar > bChar + 32) {
                return false
            }
        } else {
            if (aChar < bChar) {
                return true
            }
            if (aChar > bChar) {
                return false
            }
        }
    }
    return a.size < b.size
}
