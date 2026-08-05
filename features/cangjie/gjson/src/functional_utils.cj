package gjson


// 函数式编程工具模块

// 高阶函数类型定义
type Predicate<T> = (T) -> Bool
type Mapper<T, R> = (T) -> R

// findLast 在字符串中查找最后一个满足条件的字符位置
func findLast(s: String, predicate: Predicate<Byte>): ?Int64 {
    var i = s.size - 1
    while (i >= 0) {
        if (predicate(s[i])) {
            return Some(i)
        }
        i--
    }
    return None
}

// skipWhile 跳过字符串开头满足条件的字符
func skipWhile(s: String, predicate: Predicate<Byte>): String {
    var i = 0
    while (i < s.size && predicate(s[i])) {
        i++
    }
    return s[i..]
}

// 函数组合工具
func not<T>(predicate: Predicate<T>): Predicate<T> {
    { x => !predicate(x) }
}

func and<T>(pred1: Predicate<T>, pred2: Predicate<T>): Predicate<T> {
    { x => pred1(x) && pred2(x) }
}

func or<T>(pred1: Predicate<T>, pred2: Predicate<T>): Predicate<T> {
    { x => pred1(x) || pred2(x) }
}
