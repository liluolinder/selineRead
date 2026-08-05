package gjson

import std.unittest.*
import std.unittest.testmacro.*

@Test
class ModifiersTest {
    // 测试数据
    let jsonObject = #"{"name": "Alice", "age": 30, "active": true}"#
    let jsonArray = #"["apple", "banana", "cherry"]"#
    let jsonNestedArray = #"[["a", "b"], ["c", "d"], ["e", "f"]]"#
    let jsonInvalid = #"{"name": "Alice", "age":}"#
    let jsonString = #""Hello World""#
    let jsonNumber = "42"
    let jsonBool = "true"
    let jsonNull = "null"
    let jsonComplex = #"{
        "users": [
            {"name": "Alice", "department": "Engineering"},
            {"name": "Bob", "department": "Engineering"}, 
            {"name": "Charlie", "department": "Sales"}
        ]
    }"#

    // 测试 @keys 修饰符
    @TestCase
    func testModifierKeys() {
        let res = get(jsonObject, "@keys")
        @Assert(res.kind, Kind.JSON)
        @Assert(res.raw.contains("name"))
        @Assert(res.raw.contains("age"))
        @Assert(res.raw.contains("active"))
        // 应该返回类似 ["name","age","active"] 的格式
        @Assert(res.raw.startsWith("["))
        @Assert(res.raw.endsWith("]"))
    }

    // 测试 @values 修饰符
    @TestCase
    func testModifierValues() {
        let res = get(jsonArray, "@values")
        @Assert(res.kind, Kind.JSON)
        @Assert(res.raw.contains("apple"))
        @Assert(res.raw.contains("banana"))
        @Assert(res.raw.contains("cherry"))
        @Assert(res.raw.startsWith("["))
        @Assert(res.raw.endsWith("]"))
    }

    // 测试 @join 修饰符（默认分隔符）
    @TestCase
    func testModifierJoinDefault() {
        let res = get(jsonArray, "@join")
        @Assert(res.kind, Kind.String)
        // 应该返回 "apple,banana,cherry"
        @Assert(res.str, "apple,banana,cherry")
    }

    // 测试 @join 修饰符（自定义分隔符）
    @TestCase
    func testModifierJoinCustom() {
        let res = get(jsonArray, "@join:|")
        @Assert(res.kind, Kind.String)
        // 应该返回 "apple|banana|cherry"
        @Assert(res.str, "apple|banana|cherry")
    }

    // 测试 @reverse 修饰符（数组）
    @TestCase
    func testModifierReverseArray() {
        let res = get(jsonArray, "@reverse")
        @Assert(res.kind, Kind.JSON)
        // 应该返回逆序的数组
        @Assert(res.raw.contains("cherry"))
        @Assert(res.raw.contains("banana"))
        @Assert(res.raw.contains("apple"))
        @Assert(res.raw.startsWith("["))
        @Assert(res.raw.endsWith("]"))
    }

    // 测试 @reverse 修饰符（对象）
    @TestCase
    func testModifierReverseObject() {
        let res = get(jsonObject, "@reverse")
        @Assert(res.kind, Kind.JSON)
        @Assert(res.raw.startsWith("{"))
        @Assert(res.raw.endsWith("}"))
    }

    // 测试 @length 修饰符（数组）
    @TestCase
    func testModifierLengthArray() {
        let res = get(jsonArray, "@length")
        @Assert(res.kind, Kind.Number)
        @Assert(res.num, 3.0)
    }

    // 测试 @length 修饰符（对象）
    @TestCase
    func testModifierLengthObject() {
        let res = get(jsonObject, "@length")
        @Assert(res.kind, Kind.Number)
        @Assert(res.num, 3.0)
    }

    // 测试 @flatten 修饰符（浅层）
    @TestCase
    func testModifierFlattenShallow() {
        let res = get(jsonNestedArray, "@flatten")
        @Assert(res.kind, Kind.JSON)
        // 应该将嵌套数组展平为 ["a","b","c","d","e","f"]
        @Assert(res.raw.contains("\"a\""))
        @Assert(res.raw.contains("\"b\""))
        @Assert(res.raw.contains("\"c\""))
        @Assert(res.raw.contains("\"d\""))
        @Assert(res.raw.contains("\"e\""))
        @Assert(res.raw.contains("\"f\""))
        @Assert(res.raw.startsWith("["))
        @Assert(res.raw.endsWith("]"))
    }

    // 测试 @valid 修饰符（有效JSON）
    @TestCase
    func testModifierValidTrue() {
        let res = get(jsonObject, "@valid")
        @Assert(res.kind, Kind.String)
        @Assert(res.str, "true")
    }

    // 测试 @valid 修饰符（无效JSON）
    @TestCase
    func testModifierValidFalse() {
        let res = get(jsonInvalid, "@valid")
        @Assert(res.kind, Kind.String)
        @Assert(res.str, "false")
    }

    // 测试 @tostr 修饰符
    @TestCase
    func testModifierToStr() {
        let res = get(jsonNumber, "@tostr")
        @Assert(res.kind, Kind.String)
        // 应该将数字转换为字符串表示
        @Assert(res.raw.contains("42"))
        @Assert(res.raw.startsWith("\""))
        @Assert(res.raw.endsWith("\""))
    }

    // 测试 @fromstr 修饰符
    @TestCase
    func testModifierFromStr() {
        let jsonStringified = #""{\"name\": \"Alice\"}""#
        let res = get(jsonStringified, "@fromstr")
        @Assert(res.kind, Kind.String)
        // 应该解析字符串中的JSON
        @Assert(res.str.contains("name"))
        @Assert(res.str.contains("Alice"))
    }

    // 测试 @group 修饰符
    @TestCase
    func testModifierGroup() {
        let res = get(jsonComplex, "users@group:department")
        @Assert(res.kind, Kind.JSON)
        // 应该按部门分组
        @Assert(res.raw.contains("Engineering"))
        @Assert(res.raw.contains("Sales"))
        @Assert(res.raw.startsWith("{"))
        @Assert(res.raw.endsWith("}"))
    }

    // 测试 @dig 修饰符
    @TestCase
    func testModifierDig() {
        let res = get(jsonComplex, "@dig:users.0.name")
        @Assert(res.kind, Kind.String)
        @Assert(res.str, "Alice")
    }

    // 测试修饰符链式调用
    @TestCase
    func testModifierChaining() {
        let res = get(jsonArray, "@reverse|@join:|")
        @Assert(res.kind, Kind.String)
        // 应该先反转，再用|连接
        @Assert(res.str, "cherry|banana|apple")
    }

    // 测试不存在的修饰符
    @TestCase
    func testModifierNotExists() {
        let res = get(jsonObject, "@nonexistent")
        // 应该返回原始JSON，因为修饰符不存在
        @Assert(res.kind, Kind.JSON)
        @Assert(res.raw, jsonObject)
    }

    // 测试修饰符应用于空值
    @TestCase
    func testModifierOnNull() {
        let res = get(jsonObject, "nonexistent@keys")
        @Assert(res.kind, Kind.Null)
    }

    // 测试 @this 修饰符
    @TestCase
    func testModifierThis() {
        let res = get(jsonObject, "@this")
        @Assert(res.kind, Kind.JSON)
        @Assert(res.raw, jsonObject)
    }

    // 测试 @pretty 修饰符
    @TestCase
    func testModifierPretty() {
        let res = get(jsonObject, "@pretty")
        @Assert(res.kind, Kind.JSON)
        // 格式化后应包含换行符和缩进
        @Assert(res.raw.contains("\n"))
        @Assert(res.raw.contains("  "))  // 缩进
        // 应该包含原始内容
        @Assert(res.raw.contains("Alice"))
        @Assert(res.raw.contains("30"))
        @Assert(res.raw.contains("true"))
    }

    // 测试 @ugly 修饰符
    @TestCase
    func testModifierUgly() {
        let formattedJson = ###"{
  "name": "Alice",
  "age": 30,
  "active": true
}"###
        let res = get(formattedJson, "@ugly")
        @Assert(res.kind, Kind.JSON)
        // 压缩后不应包含换行符和多余空格
        @Assert(!res.raw.contains("\n"))
        @Assert(!res.raw.contains("  "))  // 多余缩进
        // 应该包含原始内容
        @Assert(res.raw.contains("Alice"))
        @Assert(res.raw.contains("30"))
        @Assert(res.raw.contains("true"))
        // 压缩后应该移除所有不必要的空白字符
        @Assert(res.raw, #"{"name":"Alice","age":30,"active":true}"#)
    }

    // 测试 @tostr 输出的 JSON 合法性（含引号和反斜杠时需正确转义）
    // 回归测试: modToStr 手工拼引号不转义，产出非法 JSON
    @TestCase
    func testModifierToStrEscaping() {
        let res = get(#"{"msg":"he said \"hi\" and \\bye"}"#, "msg@tostr")
        @Assert(res.kind, Kind.String)
        // 输出必须是合法 JSON 字符串字面量
        @Assert(valid(res.raw), true)
        let reparsed = parse(res.raw)
        @Assert(reparsed.isString(), true)
        @Assert(reparsed.str, #"he said "hi" and \bye"#)
    }

    // 测试 @join 输出的 JSON 合法性（元素含引号时需正确转义）
    // 回归测试: modJoin 手工拼引号不转义，产出非法 JSON
    @TestCase
    func testModifierJoinEscaping() {
        let res = get(#"["a,b", "c\"d"]"#, "@join")
        @Assert(res.kind, Kind.String)
        @Assert(valid(res.raw), true)
        let reparsed = parse(res.raw)
        @Assert(reparsed.isString(), true)
        @Assert(reparsed.str, #"a,b,c"d"#)
    }

    // 测试 @fromstr 输出的 JSON 合法性（含控制字符时需正确转义）
    // 回归测试: modFromStr 只转义引号和反斜杠，未处理控制字符
    @TestCase
    func testModifierFromStrEscaping() {
        // JSON 文本: "line1\nline2\tend"（反斜杠转义形式）
        let res = get("\"line1\\nline2\\tend\"", "@fromstr")
        @Assert(res.kind, Kind.String)
        @Assert(valid(res.raw), true)
        let reparsed = parse(res.raw)
        @Assert(reparsed.isString(), true)
        @Assert(reparsed.str, "line1\nline2\tend")
    }
}