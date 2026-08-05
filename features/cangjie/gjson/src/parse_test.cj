package gjson

import std.unittest.*
import std.unittest.testmacro.*

@Test
class ParseTest {
    
    // 测试基本的JSON解析
    @TestCase
    func testParseBasicTypes() {
        // 测试数字
        let numResult = parse("123")
        @Assert(numResult.kind, Kind.Number)
        @Assert(numResult.num, 123.0)
        
        // 测试字符串
        let strResult = parse('"hello"')
        @Assert(strResult.kind, Kind.String)
        @Assert(strResult.str, "hello")
        
        // 测试布尔值
        let boolResult = parse("true")
        @Assert(boolResult.kind, Kind.True)
        @Assert(boolResult.bool(), true)
        
        let boolResult2 = parse("false")
        @Assert(boolResult2.kind, Kind.False)
        @Assert(boolResult2.bool(), false)
        
        // 测试null
        let nullResult = parse("null")
        @Assert(nullResult.kind, Kind.Null)
    }
    
    // 测试JSON对象解析
    @TestCase
    func testParseObject() {
        let json = '{"name": "Alice", "age": 30, "active": true}'
        let result = parse(json)
        @Assert(result.kind, Kind.JSON)
        @Assert(result.raw, json)
    }
    
    // 测试JSON数组解析
    @TestCase
    func testParseArray() {
        let json = '[1, 2, 3, "hello"]'
        let result = parse(json)
        @Assert(result.kind, Kind.JSON)
        @Assert(result.raw, json)
    }
    
    // 测试嵌套JSON解析
    @TestCase
    func testParseNestedJson() {
        let json = '{"user": {"name": "Bob", "details": {"age": 25, "skills": ["Go", "Rust"]}}}'
        let result = parse(json)
        @Assert(result.kind, Kind.JSON)
        @Assert(result.raw, json)
    }
    
    // 测试包含转义字符的字符串
    @TestCase
    func testParseEscapedString() {
        let json = '"hello\\nworld\\t\\"quoted\\""'
        let result = parse(json)
        @Assert(result.kind, Kind.String)
        @Assert(result.str, "hello\nworld\t\"quoted\"")
    }
    
    // 测试Unicode字符串
    @TestCase
    func testParseUnicodeString() {
        let json = '"你好世界"'
        let result = parse(json)
        @Assert(result.kind, Kind.String)
        @Assert(result.str, "你好世界")
    }
    
    // 测试数字的各种格式
    @TestCase
    func testParseNumbers() {
        // 整数
        let intResult = parse("42")
        @Assert(intResult.kind, Kind.Number)
        @Assert(intResult.num, 42.0)
        
        // 负数
        let negResult = parse("-17")
        @Assert(negResult.kind, Kind.Number)
        @Assert(negResult.num, -17.0)
        
        // 浮点数
        let floatResult = parse("3.14")
        @Assert(floatResult.kind, Kind.Number)
        @Assert(floatResult.num, 3.14)
        
        // 科学计数法
        let sciResult = parse("1.5e2")
        @Assert(sciResult.kind, Kind.Number)
        @Assert(sciResult.num, 150.0)
        
        // 负科学计数法
        let negSciResult = parse("-2.5e-1")
        @Assert(negSciResult.kind, Kind.Number)
        @Assert(negSciResult.num, -0.25)
    }
    
    // 测试空白字符处理
    @TestCase
    func testParseWithWhitespace() {
        let json = '  \t\n  {"key": "value"}  \r\n  '
        let result = parse(json)
        @Assert(result.kind, Kind.JSON)
        @Assert(result.raw, '{"key": "value"}')
    }
    
    // 测试无效JSON
    @TestCase
    func testParseInvalidJson() {
        // 不完整的对象
        let result1 = parse('{"key": ')
        @Assert(result1.kind, Kind.Null)
        
        // 不完整的数组
        let result2 = parse('[1, 2, ')
        @Assert(result2.kind, Kind.Null)
        
        // 无效的字符
        let result3 = parse('invalid')
        @Assert(result3.kind, Kind.Null)
        
        // 空字符串
        let result4 = parse('')
        @Assert(result4.kind, Kind.Null)
    }
    
    // 测试复杂的嵌套结构
    @TestCase
    func testParseComplexStructure() {
        let json = '''
        {
            "users": [
                {
                    "id": 1,
                    "name": "Alice",
                    "active": true,
                    "metadata": {
                        "created": "2023-01-01",
                        "tags": ["admin", "user"]
                    }
                },
                {
                    "id": 2,
                    "name": "Bob",
                    "active": false,
                    "metadata": null
                }
            ],
            "count": 2
        }
        '''
        let result = parse(json)
        @Assert(result.kind, Kind.JSON)
        // 验证原始JSON被保存
        @Assert(result.raw.contains("users"))
        @Assert(result.raw.contains("Alice"))
        @Assert(result.raw.contains("Bob"))
    }
    
    // 测试特殊数字值
    @TestCase
    func testParseSpecialNumbers() {
        // 零
        let zeroResult = parse("0")
        @Assert(zeroResult.kind, Kind.Number)
        @Assert(zeroResult.num, 0.0)
        
        // 负零
        let negZeroResult = parse("-0")
        @Assert(negZeroResult.kind, Kind.Number)
        @Assert(negZeroResult.num, -0.0)
        
        // 小数点开头
        let decimalResult = parse("0.5")
        @Assert(decimalResult.kind, Kind.Number)
        @Assert(decimalResult.num, 0.5)
    }
    
    // 测试空数组和空对象
    @TestCase
    func testParseEmptyStructures() {
        // 空对象
        let emptyObj = parse('{}')
        @Assert(emptyObj.kind, Kind.JSON)
        @Assert(emptyObj.raw, '{}')
        
        // 空数组
        let emptyArr = parse('[]')
        @Assert(emptyArr.kind, Kind.JSON)
        @Assert(emptyArr.raw, '[]')
    }
}