package gjson


// Result辅助构造函数

// 创建基础的空Result
func createNullResult(): Result {
    Result(Kind.Null, "", "", 0.0, 0, ArrayList<Int64>())
}

// 创建JSON类型Result
func createJSONResult(raw: String): Result {
    Result(Kind.JSON, raw, "", 0.0, 0, ArrayList<Int64>())
}

// 创建字符串类型Result
func createStringResult(raw: String, str: String): Result {
    Result(Kind.String, raw, str, 0.0, 0, ArrayList<Int64>())
}

// 创建带索引的字符串类型Result
func createStringResultWithIndex(raw: String, str: String, index: Int64): Result {
    Result(Kind.String, raw, str, 0.0, index, ArrayList<Int64>())
}

// 创建数字类型Result
func createNumberResult(raw: String, num: Float64): Result {
    Result(Kind.Number, raw, "", num, 0, ArrayList<Int64>())
}

// 创建布尔类型Result (True)
func createTrueResult(raw: String): Result {
    Result(Kind.True, raw, "", 0.0, 0, ArrayList<Int64>())
}

// 创建布尔类型Result (False)
func createFalseResult(raw: String): Result {
    Result(Kind.False, raw, "", 0.0, 0, ArrayList<Int64>())
}

// 通用Result设置函数
func setResultBase(kind: Kind, raw: String): Result {
    Result(kind, raw, "", 0.0, 0, ArrayList<Int64>())
}

// 创建带raw的Null类型Result
func createNullResultWithRaw(raw: String): Result {
    Result(Kind.Null, raw, "", 0.0, 0, ArrayList<Int64>())
}

// 创建带raw的True类型Result
func createTrueResultWithRaw(raw: String): Result {
    Result(Kind.True, raw, "", 0.0, 0, ArrayList<Int64>())
}

// 创建带raw的False类型Result
func createFalseResultWithRaw(raw: String): Result {
    Result(Kind.False, raw, "", 0.0, 0, ArrayList<Int64>())
}

// 快速创建常用的Result实例
// 将 Result 列表构建为 JSON 数组字符串
// 统一数组构建逻辑，替代各处重复的 StringBuilder 拼接
func buildJSONArray(values: ArrayList<Result>): String {
    if (values.size == 0) {
        return "[]"
    }
    let out = StringBuilder()
    out.append('[')
    for (i in 0..values.size) {
        if (i > 0) {
            out.append(',')
        }
        out.append(values[i].raw)
    }
    out.append(']')
    return out.toString()
}