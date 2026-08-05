# GJSON 仓颉版

<div align="center">

**快速获取JSON值**

[![测试状态](https://img.shields.io/badge/测试-107/107通过-brightgreen.svg)](#测试覆盖)
[![仓颉版本](https://img.shields.io/badge/仓颉-0.59.6-blue.svg)](#环境要求)
[![语法文档](https://img.shields.io/badge/文档-路径语法-33aa33.svg)](#路径语法)

</div>

GJSON 是一个提供快速且简单方式从JSON文档中获取值的仓颉(Cangjie)语言库。
它具有一行检索、点号路径、迭代遍历、修饰符处理等特性。

这是基于 [GJSON go](https://github.com/tidwall/gjson) 的仓颉语言移植版本。在移植过程中进行了模块化重构和架构优化，充分适配仓颉语言特性。

## 环境要求

- 仓颉编程语言 1.0.0
- cjpm (仓颉包管理工具)

## 快速开始

### 安装使用

```toml
[dependencies]
  gjson = { git = "https://gitcode.com/ystyle/gjson-cj", branch = "master"}
```

### 基本用法

```cangjie
import gjson.*

let json = #"{"name":{"first":"Janet","last":"Prichard"},"age":47}"#

func main() {
    let value = get(json, "name.last")
    println(value.str)  // 输出: Prichard
}
```

### 测试运行

```bash
cjpm test
```

## 路径语法

路径是由点号分隔的键序列。键可以包含特殊通配符 `*` 和 `?`。
使用索引作为键来访问数组值。使用 `#` 字符获取数组元素数量或访问子路径。
点号和通配符可以用 `\\` 转义。

### 示例JSON

```json
{
  "name": {"first": "Tom", "last": "Anderson"},
  "age": 37,
  "children": ["Sara","Alex","Jack"],
  "fav.movie": "Deer Hunter",
  "friends": [
    {"first": "Dale", "last": "Murphy", "age": 44, "nets": ["ig", "fb", "tw"]},
    {"first": "Roger", "last": "Craig", "age": 68, "nets": ["fb", "tw"]},
    {"first": "Jane", "last": "Murphy", "age": 47, "nets": ["ig", "tw"]}
  ]
}
```

### 路径示例

```
"name.last"          // "Anderson"
"age"                // 37
"children"           // ["Sara","Alex","Jack"]
"children.#"         // 3
"children.1"         // "Alex"
"child*.2"           // "Jack"
"c?ildren.0"         // "Sara"
"fav\.movie"         // "Deer Hunter"
"friends.#.first"    // ["Dale","Roger","Jane"]
"friends.1.last"     // "Craig"
```

### 查询语法

使用 `#(...)` 查询数组中的首个匹配项，使用 `#(...)#` 查找所有匹配项。
支持比较运算符 `==`、`!=`、`<`、`<=`、`>`、`>=`，以及模式匹配运算符 `%`（匹配）和 `!%`（不匹配）。

```
friends.#(last=="Murphy").first    // "Dale"
friends.#(last=="Murphy")#.first   // ["Dale","Jane"]
friends.#(age>45)#.last            // ["Craig","Murphy"]
friends.#(first%"D*").last         // "Murphy"
friends.#(first!%"D*").last        // "Craig"
friends.#(nets.#(=="fb"))#.first   // ["Dale","Roger"]
```

## Result 类型

GJSON 支持 JSON 类型：`string`、`number`、`bool` 和 `null`。
数组和对象作为原始JSON类型返回。

`Result` 类型包含以下字段：

```cangjie
public class Result {
    public let kind: Kind        // 类型：Null, False, True, Number, String, JSON
    public let raw: String       // 原始JSON字符串
    public let str: String       // 字符串值
    public let num: Float64      // 数字值
    public let index: Int64      // 在原JSON中的索引位置
    public let indexes: ArrayList<Int64>  // 匹配元素的所有索引
}
```

### 实用方法

```cangjie
result.exists()      // 检查值是否存在
result.value()       // 获取通用值
result.int()         // 获取整数值
result.uint()        // 获取无符号整数值
result.float()       // 获取浮点数值
result.string()      // 获取字符串值
result.bool()        // 获取布尔值
result.array()        // 获取数组值
result.map()         // 获取对象映射
result.get(path)     // 获取子路径值
result.forEach()      // 遍历数组或对象
```

> **注意：** 旧版大写 API（`Array()`、`ForEach()`、`Time()`、`Valid()`、`ValidBytes()`、`AddModifier()`、`ModifierExists()`）已标记 `@Deprecated` 废弃，仍可调用（编译期会产生 warning），新代码请使用小写版本。


## 修饰符和路径链

### 内置修饰符

修饰符是对JSON进行自定义处理的路径组件。多个路径可以用管道符 `|` 链接。

支持的内置修饰符：

- `@reverse` - 反转数组或对象成员顺序
- `@ugly` - 移除JSON中的所有空白字符
- `@pretty` - 美化JSON格式，增强可读性
- `@this` - 返回当前元素
- `@valid` - 验证JSON是否有效
- `@flatten` - 扁平化数组
- `@join` - 连接数组元素
- `@keys` - 返回对象键数组
- `@values` - 返回对象值数组
- `@tostr` - 将JSON转换为字符串
- `@fromstr` - 从字符串解析JSON
- `@group` - 按指定键分组对象数组
- `@dig` - 深度搜索值
- `@length` - 获取数组或对象长度

### 修饰符示例

```
"children|@reverse"              // ["Jack","Alex","Sara"]
"children|@reverse|0"            // "Jack"
"friends|@keys"                  // 获取对象键
"children|@join:|"               // "apple|banana|cherry"
"data|@flatten"                  // 扁平化嵌套数组
```

### 修饰符参数

修饰符可以接受可选参数，参数可以是有效的JSON文档或字符。

```
"array|@join:|"                  // 使用 | 作为分隔符连接
"object|@pretty:{"sortKeys":true}"  // 美化并排序键
```

### 自定义修饰符

可以添加自定义修饰符：

```cangjie
addModifier("case", { json: String, arg: String =>
    if (arg == "upper") {
        return json.toAsciiUpper()
    }
    if (arg == "lower") {
        return json.toAsciiLower()
    }
    return json
})
```

```
"children|@case:upper"           // ["SARA","ALEX","JACK"]
"children|@case:lower|@reverse"  // ["jack","alex","sara"]
```

## 核心API

以下是 GJSON-CJ 提供的完整 API 参考，涵盖所有核心函数、类型方法和扩展功能。

### API概览

| 类别 | 关键API | 描述 |
|------|---------|------|
| **核心解析** | `parse()`, `get()`, `getMany()` | JSON字符串解析和路径查询 |
| **字节处理** | `getBytes()`, `parseBytes()` | 高性能字节数组处理 |
| **结果处理** | `Result`类方法 | 类型安全的值访问和转换 |
| **批量操作** | `getMany()` | 一次查询多个路径 |
| **验证函数** | `valid()`, `validBytes()` | JSON语法验证 |

### 主要函数

```cangjie
// 解析JSON字符串
func parse(json: String): Result

// 根据路径获取值
func get(json: String, path: String): Result

// 处理字节数组
func getBytes(json: Array<Byte>, path: String): Result
func parseBytes(json: Array<Byte>): Result

// 批量获取
func getMany(json: String, paths: Array<String>): Array<Result>

// JSON验证
func valid(json: String): Bool
func validBytes(json: Array<Byte>): Bool
```

### 结果检查

```cangjie
// 检查值是否存在
let value = get(json, "name.last")
if (!value.exists()) {
    println("没有找到姓氏")
} else {
    println(value.str)
}

// 一步检查
if (get(json, "name.last").exists()) {
    println("存在姓氏")
}
```

### 遍历数组或对象

```cangjie
let result = get(json, "programmers")
result.forEach({ key, value =>
    println(value.str)
    return true  // 继续遍历
})
```

### 获取嵌套数组值

```cangjie
// 获取所有程序员的姓氏
let result = get(json, "programmers.#.lastName")
let names = result.array()
for (name in names) {
    println(name.str)
}

// 查询数组中的对象
let name = get(json, #"programmers.#(lastName="Hunter").firstName"#)
println(name.str)  // 输出: "Elliotte"
```

### API详细参考

#### 1. 核心解析函数

| 函数 | 签名 | 描述 |
|------|------|------|
| `parse` | `func parse(json: String): Result` | 解析JSON字符串返回Result对象 |
| `get` | `func get(json: String, path: String): Result` | 根据路径获取JSON中的值 |
| `getBytes` | `func getBytes(json: Array<Byte>, path: String): Result` | 处理字节数组的路径查询 |
| `parseBytes` | `func parseBytes(json: Array<Byte>): Result` | 解析字节数组返回Result对象 |
| `getMany` | `func getMany(json: String, paths: Array<String>): Array<Result>` | 批量获取多个路径的值 |
| `valid` | `func valid(json: String): Bool` | 验证JSON字符串是否有效 |
| `validBytes` | `func validBytes(json: Array<Byte>): Bool` | 验证字节数组是否包含有效JSON |

#### 2. Result类型方法

**字段（只读）**:
- `kind: Kind` - 值类型（Null, False, True, Number, String, JSON）
- `raw: String` - 原始JSON字符串
- `str: String` - 字符串值
- `num: Float64` - 数字值
- `index: Int64` - 在原JSON中的索引位置
- `indexes: ArrayList<Int64>` - 匹配元素的所有索引

**实用方法**:
- `exists(): Bool` - 检查值是否存在
- `value(): Any` - 获取通用值（类型推断）
- `int(): Int64` - 获取整数值
- `uint(): UInt64` - 获取无符号整数值
- `float(): Float64` - 获取浮点数值
- `string(): String` - 获取字符串值
- `bool(): Bool` - 获取布尔值
- `array(): Array<Result>` - 获取数组值
- `map(): HashMap<String, Any>` - 获取对象映射
- `get(path: String): Result` - 获取子路径值
- `forEach(fn: (Result, Result) => Bool)` - 遍历数组或对象

#### 3. 路径语法总结

- **点号路径**：`"name.first"`、`"children.1"`
- **通配符**：`*`（匹配任意多个字符）、`?`（匹配单个字符）
- **数组操作**：`#`（获取长度）、`#(查询条件)`（筛选）
- **转义字符**：`\`（转义点号和通配符）
- **管道链接**：`|`（修饰符链式处理）
- **查询运算符**：`==`、`!=`、`<`、`<=`、`>`、`>=`、`%`（匹配）、`!%`（不匹配）

#### 4. 修饰符系统

**内置修饰符**：
- `@reverse` - 反转数组或对象成员顺序
- `@ugly` - 移除JSON中的所有空白字符
- `@pretty` - 美化JSON格式，增强可读性
- `@this` - 返回当前元素
- `@valid` - 验证JSON是否有效
- `@flatten` - 扁平化数组
- `@join` - 连接数组元素（可指定分隔符）
- `@keys` - 返回对象键数组
- `@values` - 返回对象值数组
- `@tostr` - 将JSON转换为字符串
- `@fromstr` - 从字符串解析JSON
- `@group` - 按指定键分组对象数组
- `@dig` - 深度搜索值
- `@length` - 获取数组或对象长度

**自定义修饰符**：
```cangjie
addModifier("case", { json: String, arg: String =>
    if (arg == "upper") {
        return json.toAsciiUpper()
    }
    if (arg == "lower") {
        return json.toAsciiLower()
    }
    return json
})
```

#### 5. JSON Lines支持（特殊前缀）

- `..#` - 获取行数
- `..1` - 获取第2行（索引从0开始）
- `..#.name` - 获取所有行的name字段
- `..#(name="May").age` - 查询特定行的字段

#### 6. 配置选项

- `DisableModifiers: Bool` - 全局变量，禁用修饰符系统以提升性能
- `addModifier(name: String, fn: (String, String) => String)` - 注册自定义修饰符

## JSON Lines 支持

支持使用 `..` 前缀处理 [JSON Lines](http://jsonlines.org/) 格式：

```
{"name": "Gilbert", "age": 61}
{"name": "Alexa", "age": 34}
{"name": "May", "age": 57}
{"name": "Deloise", "age": 44}
```

```
..#                   // 4
..1                   // {"name": "Alexa", "age": 34}
..3                   // {"name": "Deloise", "age": 44}
..#.name              // ["Gilbert","Alexa","May","Deloise"]
..#(name="May").age   // 57
```

## 性能特性

- **零拷贝解析** - 使用字符串切片避免内存分配
- **高效路径查询** - 优化的点号路径和查询语法  
- **ReDoS防护** - 防止正则拒绝服务攻击
- **索引优化** - 智能索引计算和缓存
- **模块化架构** - 按功能分离的专门模块，提高代码组织性
- **函数式编程** - 引入高阶函数和函数组合，提升代码抽象层次
- **统一处理逻辑** - 空白字符处理、Result构造等的标准化优化

## 测试覆盖

```bash
$ cjpm test
测试结果: 107/107 通过 ✅
- 基础解析测试: ✅
- 路径查询测试: ✅  
- 修饰符测试: ✅
- 边界条件测试: ✅
- 性能测试: ✅
- 查询语法测试: ✅
- Multipaths测试: ✅
- Tilde运算符测试: ✅
```

## 项目结构

```
gjson-cj/
├── src/
│   ├── gjson.cj             # 主要API和路径处理入口
│   ├── types.cj             # Result类型定义
│   ├── result_helpers.cj    # Result构造辅助函数
│   ├── result_ext.cj        # Result扩展方法
│   ├── executor.cj          # 修饰符和静态路径执行
│   ├── modifiers.cj         # 内置修饰符实现
│   ├── parser.cj            # JSON解析核心
│   ├── value_parser.cj      # 值解析器
│   ├── string_parser.cj     # 字符串解析器
│   ├── path_tools.cj        # 路径解析工具（合并）
│   ├── string_tools.cj      # 字符串处理工具（合并）
│   ├── whitespace_utils.cj  # 空白字符处理
│   ├── functional_utils.cj  # 函数式编程工具
│   ├── bool_eval.cj         # 布尔评估模块
│   ├── query_match.cj       # 查询匹配模块
│   ├── literal_utils.cj     # 字面值解析工具
│   ├── num_utils.cj         # 数字处理工具
│   ├── constants.cj         # 常量定义
│   ├── config.cj            # 配置选项
│   ├── valid.cj             # JSON验证
│   ├── json_format/         # JSON格式化模块
│   │   └── format.cj        # 美化/压缩格式化
│   └── *_test.cj            # 测试文件
├── cjpm.toml                # 项目配置
├── README.md                # 本文档
├── SYNTAX.md                # 路径语法参考
└── OPTIMIZATION_PLAN.md     # 优化计划文档
```

## 开发指南

### 构建

```bash
cjpm build
```

### 测试

```bash
cjpm test          # 运行所有测试
cjpm test -v       # 详细输出
```

### 清理

```bash
cjpm clean
```

## 许可证

本项目遵循原 GJSON 项目的许可证条款。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 相关项目

- [GJSON Go版本](https://github.com/tidwall/gjson) - 原始Go实现
- [SJSON](https://github.com/tidwall/sjson) - JSON修改库
- [JJ](https://github.com/tidwall/jj) - 命令行JSON工具

---

<div align="center">

**让JSON查询变得简单快速** 🚀

</div>
