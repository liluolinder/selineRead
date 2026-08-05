package gjson


import std.unittest.*
import std.unittest.testmacro.*
import std.env.getCommandLine

@Test
class GJSONTest {
    // 测试数据
    let json = """
    {
        "name": "Alice",
        "age": 30,
        "skills": ["Go", "Rust", "Cangjie"],
        "address": {
            "city": "Beijing",
            "zip": "100000"
        }
    }
    """

    // 测试 get 方法的基础功能
    @TestCase
    func testGetBasic() {
        let res = get(json, "name")
        @Assert(res.kind, Kind.String)
        @Assert(res.str, "Alice")
    }

    // 测试数组索引
    @TestCase
    func testGetArrayIndex() {
        let res = get(json, "skills.1")
        @Assert(res.kind, Kind.String)
        @Assert(res.str, "Rust")
    }

    // 测试嵌套对象
    @TestCase
    func testGetNested() {
        let res = get(json, "address.city")
        @Assert(res.kind, Kind.String)
        @Assert(res.str, "Beijing")
    }

    // 测试修饰符 @pretty
    @TestCase
    func testModifierPretty() {
        let res = get(json, "@pretty")
        @Assert(res.kind, Kind.JSON)
        @Assert(res.raw.contains("\n")) // 格式化后应包含换行
    }

    // // 测试修饰符 @reverse
    // @TestCase
    // func testModifierReverse() {
    //     let res = get(json, "skills@reverse")
    //     @Assert(res.kind, Kind.JSON)
    //     @Assert(res.raw, '["Cangjie","Rust","Go"]')
    // }

    // 测试无效路径
    @TestCase
    func testInvalidPath() {
        let res = get(json, "invalid.path")
        @Assert(res.kind, Kind.Null)
    }

    // 测试 parse 方法
    @TestCase
    func testParse() {
        let res = parse('{"key": "value"}')
        @Assert(res.kind, Kind.JSON)
        @Assert(res.raw, '{"key": "value"}')
    }

    // 测试 parseNumber
    @TestCase
    func testParseNumber() {
        let (raw, num) = parseNumber('123.45,', 0)
        @Assert(raw, "123.45")
        @Assert(num, 123.45)
    }
    @TestCase
    func testRuneit() {
       // 有效 Unicode 转义
       @Assert(runeit(#"4f60"#), r'你') // 仓颉字面量语法
       @Assert(runeit(#"2028"#), r'\u{2028}') // 有效 Unicode 转义
       // 无效转义
       @Assert(runeit(#"GGGG"#), r'0') // 无效 hex
       @Assert(runeit(#"00"#), r'0')   // 不完整转义
       @Assert(runeit(#"123"#), r'0')  // 不完整转义
    }
    // 测试 encodeRune 函数
    @TestCase
    func testEncodeRune() {
        // ASCII 字符
        let (bytes1, size1) = encodeRune(r'你')
        @Assert(size1, 3)
        @Assert(bytes1, '你'.toArray())


        let (bytes2, size2) = encodeRune(r'a')
        @Assert(size2, 1)
        @Assert(bytes2, 'a'.toArray())
    }

    // 测试中文支持
    @TestCase
    func testChineseKey() {
        let json = '{"名字": "张三", "年龄": 25}'
        let res = get(json, "名字")
        @Assert(res.kind, Kind.String)
        @Assert(res.str, "张三")
    }

    @TestCase
    func testChineseValue() {
        let json = '{"name": "你好世界", "city": "北京"}'
        let res1 = get(json, "name")
        @Assert(res1.str, "你好世界")
        
        let res2 = get(json, "city")
        @Assert(res2.str, "北京")
    }

    @TestCase
    func testChineseNested() {
        let json = '{"用户": {"姓名": "李四", "地址": {"城市": "上海"}}}'
        let res = get(json, "用户.地址.城市")
        @Assert(res.str, "上海")
    }

    @TestCase
    func testChineseArray() {
        let json = '{"列表": ["中文", "English", "混合Mixed"]}'
        let res0 = get(json, "列表.0")
        @Assert(res0.str, "中文")
        
        let res2 = get(json, "列表.2")
        @Assert(res2.str, "混合Mixed")
    }

    @TestCase
    func testChineseUnescape() {
        // 测试 unescape 对中文的处理
        let input = "你好世界"
        let result = unescape(input)
        @Assert(result, "你好世界")
    }

    @TestCase
    func testChineseWithEscape() {
        // 中文混合转义字符
        let json = '{"msg": "你好\\n世界"}'
        let res = get(json, "msg")
        @Assert(res.str, "你好\n世界")
    }

    @TestCase
    func testChinesePretty() {
        let json = '{"名字":"张三","年龄":25}'
        let res = get(json, "@pretty")
        @Assert(res.kind, Kind.JSON)
        // 格式化后应包含中文字符
        @Assert(res.raw.contains("张三"))
        @Assert(res.raw.contains("名字"))
    }

    @TestCase
    func testChineseUgly() {
        let json = """
        {
            "名字": "张三",
            "年龄": 25
        }
        """
        let res = get(json, "@ugly")
        @Assert(res.kind, Kind.JSON)
        @Assert(res.raw.contains("张三"))
        // 压缩后不应包含换行
        @Assert(!res.raw.contains("\n"))
    }

    @TestCase
    func testUnicodeEscapeChinese() {
        // Unicode 转义的中文字符 \u4f60 = 你
        let json = '{"msg": "\\u4f60\\u597d"}'
        let res = get(json, "msg")
        @Assert(res.str, "你好")
    }

}
