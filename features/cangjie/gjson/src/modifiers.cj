package gjson

import gjson.json_format.{pretty, ugly}

type ModifierFn = (String, String) -> String

let modifiers = HashMap<String, ModifierFn>()
let _ = {=> 
    addModifier("pretty", modPretty)
    addModifier("ugly", modUgly)
    addModifier("reverse", modReverse)
    addModifier("this", modThis)
    addModifier("length", modLength)
    addModifier("keys", modKeys)
    addModifier("values", modValues)
    addModifier("join", modJoin)
    addModifier("flatten", modFlatten)
    addModifier("valid", modValid)
    addModifier("tostr", modToStr)
    addModifier("fromstr", modFromStr)
    addModifier("group", modGroup)
    addModifier("dig", modDig)
}()

public func addModifier(name: String, fn: (String, String) -> String): Unit {
    modifiers.add(name, fn)
}

@Deprecated["use addModifier() instead"]
public func AddModifier(name: String, fn: (String, String) -> String): Unit {
    addModifier(name, fn)
}

public func modifierExists(name: String): Bool {
    modifiers.contains(name)
}

@Deprecated["use modifierExists() instead"]
public func ModifierExists(name: String): Bool {
    modifierExists(name)
}

// 通用JSON数组构建函数（泛型版本）
// 处理ArrayList<T>，使用转换函数将元素转换为字符串
func buildJsonArrayGeneric<T>(values: ArrayList<T>, toString: (T) -> String): String {
    if (values.size == 0) {
        return "[]"
    }
    let out = StringBuilder()
    out.append('[')
    var i = 0
    while (i < values.size) {
        if (i > 0) {
            out.append(',')
        }
        out.append(toString(values[i]))
        i++
    }
    out.append(']')
    return out.toString()
}

func buildJsonArrayFromStrings(values: ArrayList<String>): String {
    buildJsonArrayGeneric(values, { s => s })
}

// @pretty modifier makes the json look nice
func modPretty(json: String, _: String): String {
    // if (arg.size > 0) {
    //     let opts = pretty.DefaultOptions()
    //     Parse(arg).ForEach({key, value =>
    //         match (key.String()) {
    //             case "sortKeys" => opts.SortKeys = value.Bool()
    //             case "indent" => opts.Indent = cleanWS(value.String())
    //             case "prefix" => opts.Prefix = cleanWS(value.String())
    //             case "width" => opts.Width = value.Int()
    //         }
    //         true
    //     })
    //     return pretty.PrettyOptions(json.toBytes(), opts).toString()
    // }
    // return pretty.Pretty(json.toBytes()).toString()
    return pretty(json)
}

// @this returns the current element
func modThis(json: String, _: String): String {
    json
}

// @ugly modifier removes all whitespace
func modUgly(json: String, _: String): String {
    // pretty.Ugly(json.toBytes()).toString()
    return ugly(json)
}

// @reverse reverses array elements or object members
func modReverse(json: String, _: String): String {
    let res = parse(json)
    if (res.isArray()) {
        let values = res.array()
        // 创建反转后的数组
        let reversedValues = ArrayList<Result>()
        var i = 0
        while (i < values.size) {
            let reversedIndex = values.size - 1 - i
            reversedValues.add(values[reversedIndex])
            i++
        }
        return buildJSONArray(reversedValues)
    }
    if (res.isObject()) {
        let kvs = ArrayList<Result>()
        res.forEach({ key, value =>
            kvs.add(key)
            kvs.add(value)
            true
        })
        let out = StringBuilder()
        out.append('{')
        let pairCount = kvs.size / 2
        var i = 0
        while (i < pairCount) {
            let reversedIndex = (pairCount - 1 - i) * 2
            if (i > 0) {
                out.append(',')
            }
            out.append(kvs[reversedIndex].raw)
            out.append(':')
            out.append(kvs[reversedIndex + 1].raw)
            i++
        }
        out.append('}')
        return out.toString()
    }
    return json
}

func modFlatten(json: String, arg: String): String {
    let res = parse(json)
    if (!res.isArray()) {
        return json
    }
    
    let deep = Box<Bool>(false)
    if (arg.size > 0) {
        let argRes = parse(arg)
        argRes.forEach({ key, value => 
            if (key.str == "deep") {
                deep.value = value.bool()
            }
            true
        })
    }

    let out = StringBuilder()
    out.append('[')
    let idx = Box<Int64>(0)

    func appendValue(value: Result) {
        if (value.isArray()) {
            if (deep.value) {
                // Recursively flatten nested arrays
                let flattenedJson = modFlatten(value.raw, arg)
                let flattenedRes = parse(flattenedJson)
                let flatArr = flattenedRes.array()
                for (i in 0..flatArr.size) {
                    if (idx.value > 0) {
                        out.append(',')
                    }
                    out.append(flatArr[i].raw)
                    idx.value++
                }
            } else {
                // Just unwrap one level using Array() method
                let arr = value.array()
                for (i in 0..arr.size) {
                    if (idx.value > 0) {
                        out.append(',')
                    }
                    out.append(arr[i].raw)
                    idx.value++
                }
            }
        } else {
            // Non-array values are added as-is
            if (idx.value > 0) {
                out.append(',')
            }
            out.append(value.raw)
            idx.value++
        }
    }

    let arr = res.array()
    for (i in 0..arr.size) {
        appendValue(arr[i])
    }

    out.append(']')
    return out.toString()
}

// @length returns the length of an array or object
func modLength(json: String, _: String): String {
    let res = parse(json)
    if (res.isArray()) {
        // 使用 Array() 方法获取准确的长度
        let arr = res.array()
        return "${arr.size}"
    }
    if (res.isObject()) {
        // 对于对象，我们需要手动计算键的数量
        let obj = res.map()
        return "${obj.size}"
    }
    return "0"
}

// processObjectOrArray provides unified iteration logic for extracting keys or values
// 统一的对象或数组迭代处理函数，消除modKeys和modValues的重复逻辑
func processObjectOrArray(json: String, extractor: (Result, Result, Bool) -> String): String {
    let v = parse(json)
    if (!v.exists()) {
        return "[]"
    }

    let isObj = v.isObject()
    let results = ArrayList<String>()

    v.forEach({ key, value =>
        results.add(extractor(key, value, isObj))
        true
    })

    return buildJsonArrayFromStrings(results)
}

// @keys returns an array of object keys
// 使用通用迭代函数重构，消除重复逻辑
func modKeys(json: String, _: String): String {
    let res = parse(json)
    if (res.kind == Kind.Null) {
        return json  // 保持null输入
    }
    
    return processObjectOrArray(json, { key, _, isObj =>
        if (isObj) {
            key.raw
        } else {
            "null"
        }
    })
}

// @values returns an array of object values or array elements
// 使用通用迭代函数重构，消除重复逻辑
func modValues(json: String, _: String): String {
    let res = parse(json)
    if (res.isArray()) {
        return json  // 数组直接返回
    }
    
    return processObjectOrArray(json, { _, value, _ =>
        value.raw
    })
}

// @join joins array elements with a separator
func modJoin(json: String, arg: String): String {
    let res = parse(json)
    if (res.isArray()) {
        let separator = if (arg.size > 0) { arg } else { "," }
        let arr = res.array()
        let values = ArrayList<String>()
        
        var i = 0
        while (i < arr.size) {
            let value = arr[i]
            if (value.kind == Kind.String) {
                values.add(value.str)
            } else {
                values.add(value.raw)
            }
            i++
        }
        
        let out = StringBuilder()
        var j = 0
        while (j < values.size) {
            if (j > 0) {
                out.append(separator)
            }
            out.append(values[j])
            j++
        }
        // 转义为合法的 JSON 字符串字面量
        let dst = ArrayList<Byte>()
        appendJSONString(dst, out.toString())
        return unsafe { String.withRawData(dst.toArray()) }
    }
    return json
}

// @valid returns "true" if the json is valid, "false" otherwise
func modValid(json: String, _: String): String {
    let isValid = valid(json)
    return if (isValid) { "\"true\"" } else { "\"false\"" }
}

// @tostr converts a JSON value to a string representation
func modToStr(json: String, _: String): String {
    let res = parse(json)
    let strValue = res.toString()
    // 转义为合法的 JSON 字符串字面量
    let dst = ArrayList<Byte>()
    appendJSONString(dst, strValue)
    return unsafe { String.withRawData(dst.toArray()) }
}

// @fromstr parses a string as JSON 
func modFromStr(json: String, _: String): String {
    let res = parse(json)
    if (res.isString()) {
        // 转义为合法的 JSON 字符串字面量（含控制字符）
        let dst = ArrayList<Byte>()
        appendJSONString(dst, res.str)
        return unsafe { String.withRawData(dst.toArray()) }
    }
    return json
}

// @group groups array elements by a specified key
func modGroup(json: String, arg: String): String {
    let res = parse(json)
    if (!res.isArray()) {
        return json
    }
    
    let groups = HashMap<String, ArrayList<Result>>()
    res.forEach({ _, value =>
        let key = if (arg.size > 0) {
            value.get(arg).str
        } else {
            value.str
        }
        
        if (!groups.contains(key)) {
            groups.add(key, ArrayList<Result>())
        }
        groups.get(key)?.add(value)
        true
    })
    
    let out = StringBuilder()
    out.append('{')
    let idx = Box<Int64>(0)
    
    for ((key, values) in groups) {
        if (idx.value > 0) {
            out.append(',')
        }
        out.append("\"${key}\":")
        out.append('[')
        for (i in 0..values.size) {
            appendWithSeparator(out, values[i].raw, i == 0)
        }
        out.append(']')
        idx.value++
    }
    
    out.append('}')
    return out.toString()
}

// @dig digs into nested structures using a path
func modDig(json: String, arg: String): String {
    if (arg.size == 0) {
        return json
    }
    return get(json, arg).raw
}
