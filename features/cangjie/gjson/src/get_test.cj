package gjson

import std.unittest.*
import std.unittest.testmacro.*

@Test
class GetTest {
    
    // 测试用的复杂JSON数据
    let complexJson = '''
    {
        "name": "Alice",
        "age": 30,
        "active": true,
        "score": 95.5,
        "skills": ["Go", "Rust", "Cangjie", "Python"],
        "address": {
            "street": "123 Main St",
            "city": "Beijing",
            "country": "China",
            "coordinates": {
                "lat": 39.9042,
                "lng": 116.4074
            }
        },
        "projects": [
            {
                "name": "Project A",
                "status": "completed",
                "team": ["Alice", "Bob"],
                "budget": 50000
            },
            {
                "name": "Project B", 
                "status": "in_progress",
                "team": ["Alice", "Charlie", "David"],
                "budget": 75000
            }
        ],
        "metadata": {
            "created": "2023-01-01T00:00:00Z",
            "updated": "2023-12-31T23:59:59Z",
            "tags": ["senior", "backend", "fullstack"]
        },
        "nullable_field": null
    }
    '''
    
    // 测试基本字段获取
    @TestCase
    func testGetBasicFields() {
        // 字符串字段
        let nameResult = get(complexJson, "name")
        @Assert(nameResult.kind, Kind.String)
        @Assert(nameResult.str, "Alice")
        
        // 数字字段
        let ageResult = get(complexJson, "age")
        @Assert(ageResult.kind, Kind.Number)
        @Assert(ageResult.num, 30.0)
        
        // 浮点数字段
        let scoreResult = get(complexJson, "score")
        @Assert(scoreResult.kind, Kind.Number)
        @Assert(scoreResult.num, 95.5)
        
        // 布尔字段
        let activeResult = get(complexJson, "active")
        @Assert(activeResult.kind, Kind.True)
        @Assert(activeResult.bool(), true)
        
        // null字段
        let nullResult = get(complexJson, "nullable_field")
        @Assert(nullResult.kind, Kind.Null)
    }
    
    // 测试数组访问
    @TestCase
    func testGetArrayAccess() {
        // 数组索引访问
        let skill0 = get(complexJson, "skills.0")
        @Assert(skill0.kind, Kind.String)
        @Assert(skill0.str, "Go")
        
        let skill1 = get(complexJson, "skills.1")
        @Assert(skill1.kind, Kind.String)
        @Assert(skill1.str, "Rust")
        
        let skill3 = get(complexJson, "skills.3")
        @Assert(skill3.kind, Kind.String)
        @Assert(skill3.str, "Python")
        
        // 数组长度
        let skillsCount = get(complexJson, "skills.#")
        @Assert(skillsCount.kind, Kind.Number)
        @Assert(skillsCount.num, 4.0)
        
        // 超出索引范围
        let outOfRange = get(complexJson, "skills.10")
        @Assert(outOfRange.kind, Kind.Null)
    }
    
    // 测试嵌套对象访问
    @TestCase
    func testGetNestedObjects() {
        // 嵌套对象字段
        let city = get(complexJson, "address.city")
        @Assert(city.kind, Kind.String)
        @Assert(city.str, "Beijing")
        
        let street = get(complexJson, "address.street")
        @Assert(street.kind, Kind.String)
        @Assert(street.str, "123 Main St")
        
        // 深层嵌套
        let lat = get(complexJson, "address.coordinates.lat")
        @Assert(lat.kind, Kind.Number)
        @Assert(lat.num, 39.9042)
        
        let lng = get(complexJson, "address.coordinates.lng")
        @Assert(lng.kind, Kind.Number)
        @Assert(lng.num, 116.4074)
    }
    
    // 测试数组中的对象访问
    @TestCase
    func testGetArrayObjects() {
        // 数组中的对象字段
        let project0Name = get(complexJson, "projects.0.name")
        @Assert(project0Name.kind, Kind.String)
        @Assert(project0Name.str, "Project A")
        
        let project1Budget = get(complexJson, "projects.1.budget")
        @Assert(project1Budget.kind, Kind.Number)
        @Assert(project1Budget.num, 75000.0)
        
        // 数组中对象的数组字段
        let project0Team0 = get(complexJson, "projects.0.team.0")
        @Assert(project0Team0.kind, Kind.String)
        @Assert(project0Team0.str, "Alice")
        
        let project1TeamCount = get(complexJson, "projects.1.team.#")
        @Assert(project1TeamCount.kind, Kind.Number)
        @Assert(project1TeamCount.num, 3.0)
    }
    
    // 测试修饰符
    @TestCase
    func testGetModifiers() {
        // @pretty 修饰符
        let prettyResult = get(complexJson, "@pretty")
        @Assert(prettyResult.kind, Kind.JSON)
        @Assert(prettyResult.raw.contains("\n"))
        
        // 数组反转修饰符
        let reverseSkills = get(complexJson, "skills@reverse")
        @Assert(reverseSkills.kind, Kind.JSON)
        @Assert(reverseSkills.raw.contains("Python"))
        
        // 数组长度修饰符
        let projectsCount = get(complexJson, "projects@length")
        @Assert(projectsCount.kind, Kind.Number)
        @Assert(projectsCount.num, 2.0)
    }
    
    // 测试路径不存在的情况
    @TestCase
    func testGetNonExistentPaths() {
        // 不存在的顶层字段
        let nonExistent = get(complexJson, "nonexistent")
        @Assert(nonExistent.kind, Kind.Null)
        
        // 不存在的嵌套字段
        let nonExistentNested = get(complexJson, "address.nonexistent")
        @Assert(nonExistentNested.kind, Kind.Null)
        
        // 不存在的数组索引
        let nonExistentIndex = get(complexJson, "skills.100")
        @Assert(nonExistentIndex.kind, Kind.Null)
        
        // 在非对象上访问字段
        let invalidPath = get(complexJson, "name.invalid")
        @Assert(invalidPath.kind, Kind.Null)
    }
    
    // 测试简单JSON结构
    @TestCase
    func testGetSimpleJson() {
        let simpleJson = '{"key": "value", "number": 42}'
        
        let key = get(simpleJson, "key")
        @Assert(key.kind, Kind.String)
        @Assert(key.str, "value")
        
        let number = get(simpleJson, "number")
        @Assert(number.kind, Kind.Number)
        @Assert(number.num, 42.0)
    }
    
    // 测试数组JSON
    @TestCase
    func testGetArrayJson() {
        let arrayJson = '[{"name": "Alice"}, {"name": "Bob"}, {"name": "Charlie"}]'
        
        let first = get(arrayJson, "0.name")
        @Assert(first.kind, Kind.String)
        @Assert(first.str, "Alice")
        
        let second = get(arrayJson, "1.name")
        @Assert(second.kind, Kind.String)
        @Assert(second.str, "Bob")
        
        let count = get(arrayJson, "#")
        @Assert(count.kind, Kind.Number)
        @Assert(count.num, 3.0)
    }
    
    // 测试特殊字符在字段名中
    @TestCase
    func testGetSpecialCharacters() {
        let specialJson = '{"field-with-dash": "value1", "field_with_underscore": "value2", "field.with.dots": "value3"}'
        
        let dashField = get(specialJson, "field-with-dash")
        @Assert(dashField.kind, Kind.String)
        @Assert(dashField.str, "value1")
        
        let underscoreField = get(specialJson, "field_with_underscore")
        @Assert(underscoreField.kind, Kind.String)
        @Assert(underscoreField.str, "value2")
    }
    
    // 测试空字符串和空值
    @TestCase
    func testGetEmptyValues() {
        let emptyJson = '{"empty_string": "", "empty_array": [], "empty_object": {}}'
        
        let emptyString = get(emptyJson, "empty_string")
        @Assert(emptyString.kind, Kind.String)
        @Assert(emptyString.str, "")
        
        let emptyArray = get(emptyJson, "empty_array")
        @Assert(emptyArray.kind, Kind.JSON)
        @Assert(emptyArray.raw, "[]")
        
        let emptyObject = get(emptyJson, "empty_object")
        @Assert(emptyObject.kind, Kind.JSON)
        @Assert(emptyObject.raw, "{}")
        
        // 空数组长度
        let emptyArrayLen = get(emptyJson, "empty_array.#")
        @Assert(emptyArrayLen.kind, Kind.Number)
        @Assert(emptyArrayLen.num, 0.0)
    }
    
    // 测试多层嵌套和复杂路径
    @TestCase
    func testGetComplexPaths() {
        let nestedJson = '''
        {
            "level1": {
                "level2": {
                    "level3": {
                        "level4": {
                            "value": "deep_value",
                            "array": [1, 2, 3, {"nested": "item"}]
                        }
                    }
                }
            }
        }
        '''
        
        let deepValue = get(nestedJson, "level1.level2.level3.level4.value")
        @Assert(deepValue.kind, Kind.String)
        @Assert(deepValue.str, "deep_value")
        
        let deepArrayItem = get(nestedJson, "level1.level2.level3.level4.array.3.nested")
        @Assert(deepArrayItem.kind, Kind.String)
        @Assert(deepArrayItem.str, "item")
    }
    
    // 测试获取整个对象或数组
    @TestCase
    func testGetWholeStructures() {
        let json = '{"user": {"name": "Alice", "age": 30}, "items": [1, 2, 3]}'
        
        let userObj = get(json, "user")
        @Assert(userObj.kind, Kind.JSON)
        @Assert(userObj.raw.contains("Alice"))
        @Assert(userObj.raw.contains("30"))
        
        let itemsArray = get(json, "items")
        @Assert(itemsArray.kind, Kind.JSON)
        @Assert(itemsArray.raw, "[1, 2, 3]")
    }
    
    // 测试 Result.get 嵌套查询的 index 偏移
    // 回归测试: types.cj Result.get 中 if/else 逻辑颠倒导致 index 未偏移
    @TestCase
    func testGetNestedIndexOffset() {
        let r1 = get("{\"a\":{\"b\":1}}", "a")
        // "a" 的值 {"b":1} 从位置 5 开始
        @Assert(r1.index, 5)
        
        let r2 = r1.get("b")
        // "b" 的值 1 绝对位置 = 相对位置5 + 外层偏移5 = 10
        @Assert(r2.index, 10)
    }
    
    // 测试 Result.get 对聚合查询 indexes 的偏移
    // 回归测试: types.cj Result.get 在 indexes 非空时错误调用 setIndex 覆盖 indexes
    @TestCase
    func testGetAggregateIndexes() {
        let r1 = get("{\"a\":[1,2,3]}", "a")
        @Assert(r1.index, 5)
        
        let r2 = r1.get("#(==2)#")
        // 匹配元素 2 相对位置 3，偏移后绝对位置 8
        @Assert(r2.indexes.size, 1)
        @Assert(r2.indexes[0], 8)
    }
    
    // 测试路径以 . 结尾时不应崩溃
    // 回归测试: path_tools.cj isDotPiperChar 对空串越界
    @TestCase
    func testGetWithTrailingDot() {
        let r = get("{\"a\":1}", "a.")
        // 尾随点视为不匹配路径，安全返回 Null 而不是抛异常
        @Assert(r.kind, Kind.Null)
    }
}