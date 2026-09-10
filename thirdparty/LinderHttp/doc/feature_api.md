# LinderHttp API 参考

- AI generated 仅供参考

## 目录
- [1. 包结构概览](#1-包结构概览)
- [2. 枚举类型](#2-枚举类型)
  - [2.1 ConflictMethod](#21-conflictmethod)
  - [2.2 RequestBody](#22-requestbody)
  - [2.3 RequestMethod](#23-requestmethod)
  - [2.4 RequestUrl](#24-requesturl)
  - [2.5 MultipartPart](#25-multipartpart)
- [3. 工具函数](#3-工具函数)
  - [3.1 defaultTlsConfig()](#31-defaulttlsconfig)
  - [3.2 exportToFile](#32-exporttofile)
- [4. 核心类](#4-核心类)
  - [4.1 LinderHttpClient](#41-linderhttpclient)
    - [4.1.1 属性](#411-属性)
    - [4.1.2 构造方法](#412-构造方法)
    - [4.1.3 链式配置方法](#413-链式配置方法)
    - [4.1.4 发送请求](#414-发送请求)
  - [4.2 LinderHttpResponse](#42-linderhttpresponse)
    - [4.2.1 属性](#421-属性)
    - [4.2.2 计算属性](#422-计算属性)
    - [4.2.3 方法](#423-方法)
  - [4.3 HttpHeader](#43-httpheader)
    - [4.3.1 构造方法](#431-构造方法)
    - [4.3.2 方法](#432-方法)
  - [4.4 MultipartFormData](#44-multipartformdata)
    - [4.4.1 构造方法](#441-构造方法)
    - [4.4.2 方法](#442-方法)
    - [4.4.3 使用示例](#443-使用示例)
  - [4.5 Interceptor](#45-interceptor)
    - [4.5.1 属性](#451-属性)
    - [4.5.2 构造方法](#452-构造方法)
- [5. 便捷类](#5-便捷类)
  - [5.1 HttpQuick](#51-httpquick)
    - [5.1.1 静态方法](#511-静态方法)
    - [5.1.2 使用示例](#512-使用示例)
- [6. WebSocket类](#6-websocket类)
  - [6.1 WebSocketClient](#61-websocketclient)
    - [6.1.1 属性](#611-属性)
    - [6.1.2 构造方法](#612-构造方法)
    - [6.1.3 方法](#613-方法)
    - [6.1.4 使用示例](#614-使用示例)

---

## 1. 包结构概览

| 包名 | 主要功能 |
|------|----------|
| `linderHttp` | HTTP客户端、响应、拦截器、WebSocket、便捷请求方法等 |

---

## 2. 枚举类型

### 2.1 ConflictMethod
定义文件冲突处理策略。

| 枚举值 | 说明 |
|--------|------|
| `OverWrite` | 直接覆盖已存在的文件 |
| `Harmony` | 自动生成新文件名（格式：`原文件名(序号).扩展名`） |

---

### 2.2 RequestBody
表示HTTP请求体的不同类型。

| 枚举值 | 说明 |
|--------|------|
| `String(String)` | 字符串类型 |
| `InputStream(InputStream)` | 输入流类型 |
| `ByteArray(Array<Byte>)` | 字节数组类型 |
| `Object(DataModel)` | 数据模型对象 |
| `Json(JsonObject)` | JSON对象 |
| `UrlEncoded(Form)` | URL编码表单数据 |
| `Multipart(MultipartFormData)` | Multipart表单数据（文件上传） |

**静态构造方法：**
```cangjie
// String 类型请求体
RequestBody.from(v: String)

// InputStream 类型请求体
RequestBody.from(v: InputStream)

// ByteArray 类型请求体
RequestBody.from(v: Array<Byte>)

// UrlEncoded 类型请求体
RequestBody.from(v: Form)

// Object 类型请求体
RequestBody.from(v: DataModel)

// Json 类型请求体
RequestBody.from(v: JsonObject)

// Multipart 类型请求体
RequestBody.from(v: MultipartFormData)
```

---

### 2.3 RequestMethod
表示HTTP请求方法，实现`ToString`接口。

| 枚举值 | 字符串值 |
|--------|----------|
| `GET` | "GET" |
| `POST` | "POST" |
| `HEAD` | "HEAD" |
| `PUT` | "PUT" |
| `PATCH` | "PATCH" |
| `DELETE` | "DELETE" |
| `COPY` | "COPY" |
| `OPTIONS` | "OPTIONS" |
| `LINK` | "LINK" |
| `UNLINK` | "UNLINK" |
| `PURGE` | "PURGE" |
| `LOCK` | "LOCK" |
| `UNLOCK` | "UNLOCK" |
| `PROPFIND` | "PROPFIND" |
| `VIEW` | "VIEW" |
| `CUSTOM(String)` | 自定义字符串 |

---

### 2.4 RequestUrl
表示请求URL的类型。实现`ToString`接口。

| 枚举值 | 说明 |
|--------|------|
| `STRING(String)` | 字符串类型的URL |
| `URL(URL)` | URL对象类型 |

**静态构造方法：**
```cangjie
RequestUrl.from(v: String)  //  STRING 类型
RequestUrl.from(v: URL)     //  URL 类型
```

---

### 2.5 MultipartPart
Multipart表单项类型。

| 枚举值 | 说明 |
|--------|------|
| `Text(String, String)` | 文本字段（name, value） |
| `File(String, String, Array<Byte>)` | 文件字段（name, filename, content） |
| `FileStream(String, String, InputStream)` | 文件流字段（name, filename, stream） |

**方法：**
```cangjie
func getName(): String         // 获取字段名称
func getValue(): ?String       // 获取字段值（仅文本字段有效）
func getFilename(): ?String    // 获取文件名（仅文件字段有效）
```

---

## 3. 工具函数

### 3.1 defaultTlsConfig()
返回默认的TLS客户端配置，验证模式为`TrustAll`。

```cangjie
public func defaultTlsConfig(): TlsClientConfig
```

**注意事项：**
- `TrustAll`模式会信任所有证书，仅用于开发测试环境
- 生产环境建议使用更严格的验证模式

---

### 3.2 exportToFile
将内容导出到文件，支持冲突处理策略。

**字符串版本：**
```cangjie
public func exportToFile(
    content!: String, 
    filePath!: Path, 
    conflictMethod!: ConflictMethod = ConflictMethod.Harmony
): Unit
```

**输入流版本：**
```cangjie
public func exportToFile(
    content!: InputStream, 
    filePath!: Path,
    conflictMethod!: ConflictMethod = ConflictMethod.Harmony
): Unit
```

**参数说明：**
- `content` - 要写入的内容（字符串或输入流）
- `filePath` - 目标文件路径（包含文件名和扩展名）
- `conflictMethod` - 文件冲突解决策略，默认为`ConflictMethod.Harmony`

**冲突策略说明：**
- `Harmony`：自动生成新文件名（格式：`原文件名(序号).扩展名`）
- `OverWrite`：直接覆盖原文件

---

## 4. 核心类

### 4.1 LinderHttpClient
HTTP客户端主类，支持链式调用。

#### 4.1.1 属性

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `url` | `RequestUrl` | `RequestUrl.from('')` | 请求URL |
| `headers` | `HttpHeader` | 新建实例 | HTTP头部容器 |
| `tlsConfig` | `TlsClientConfig` | `defaultTlsConfig()` | TLS配置 |
| `method` | `String` | `'GET'` | HTTP方法 |
| `requestBody` | `?RequestBody` | `None` | 请求体 |
| `autoRedirect` | `Bool` | `true` | 是否自动重定向 |
| `readTimeout` | `Duration` | `15秒` | 读取超时 |
| `writeTimeout` | `Duration` | `15秒` | 写入超时 |
| `initialWindowSize` | `UInt32` | `65535` | HTTP/2流控窗口初始大小 |
| `enablePush` | `Bool` | `true` | 是否启用HTTP/2服务器推送 |
| `headerTableSize` | `UInt32` | `4096` | HPACK动态表初始大小 |
| `httpProxy` | `String` | `''` | HTTP代理（环境变量优先） |
| `httpsProxy` | `String` | `''` | HTTPS代理（环境变量优先） |

#### 4.1.2 构造方法
```cangjie
public init(
    url!: RequestUrl = RequestUrl.from(''),
    serverName!: String = '',
    tlsConfig!: ?TlsClientConfig = None,
    httpHeader!: ?HttpHeader = None,
    stdHeaders!: ?HttpHeaders = None,
    interceptor!: ?Interceptor = None,
    method!: RequestMethod = RequestMethod.GET,
    requestBody!: ?RequestBody = None,
    autoRedirect!: Bool = true,
    readTimeout!: Duration = Duration.second * 15,
    writeTimeout!: Duration = Duration.second * 15,
    initialWindowSize!: UInt32 = 65535,
    enablePush!: Bool = true,
    headerTableSize!: UInt32 = 4096,
    httpProxy!: String = '',
    httpsProxy!: String = ''
)
```

**参数说明：**
- `url` - 请求的目标URL（包含协议头，如https://）
- `serverName` - 自定义域名标识，用于TLS握手验证
  - 若未设置则从url自动设置
  - 优先级低于tlsConfig：若同时设置serverName和tlsConfig，serverName将被忽略
- `tlsConfig` - TLS客户端配置，默认使用defaultTlsConfig()
- `httpHeader` - 库专属HTTP头容器
- `stdHeaders` - 通用HTTP头容器
  - 互斥约束：httpHeader与stdHeaders不可同时设置，否则抛出IllegalArgumentException
- `interceptor` - HTTP拦截器，默认None
- `method` - 请求方法，默认GET
- `requestBody` - 请求附带数据，默认None
- `autoRedirect` - 是否自动重定向，默认true
- `readTimeout` - 读超时时间，默认15秒
- `writeTimeout` - 写超时时间，默认15秒
- `initialWindowSize` - 配置客户端 HTTP/2 流控窗口初始值，取值范围为 0 至 2^31 - 1
- `enablePush` - 配置客户端 HTTP/2 是否支持服务器推送
- `headerTableSize` - 配置客户端 HTTP/2 Hpack 动态表初始值
- `httpProxy` - 设置客户端 http 代理，默认使用系统环境变量 http_proxy 的值
- `httpsProxy` - 设置客户端 https 代理，默认使用系统环境变量 https_proxy 的值

#### 4.1.3 链式配置方法

##### `setUrl(v: RequestUrl/String/URL): LinderHttpClient`
设置请求URL并自动更新TLS域名。

**参数：**
- `v` - 目标URL，可以是`RequestUrl`枚举、`String`类型或`URL`对象

**说明：**
- 调用此方法将同步更新TLS配置的域名（如果`tlsConfig.serverName`未设置）
- 如果`tlsConfig`已设置`serverName`则无操作

**示例：**
```cangjie
client.setUrl("https://api.example.com")
    .setUrl(RequestUrl.from("https://api.example.com"))
```

---

##### `setHeader(v: HttpHeaders/HttpHeader/HashMap<String, String>): LinderHttpClient`
设置HTTP头部（覆盖式更新）。

**参数：**
- `v` - HTTP头容器，支持三种类型：
  - `HttpHeaders`：标准HTTP头容器，调用批量替换
  - `HttpHeader`：库专属HTTP头容器，直接替换
  - `HashMap<String, String>`：从HashMap批量设置

**说明：**
- `HttpHeaders`：调用`headers.setAll(v)`进行批量替换
- `HttpHeader`：直接替换整个头部容器
- `HashMap`：遍历HashMap逐个添加到HTTP头部

**示例：**
```cangjie
// 使用标准HttpHeaders
var headers = HttpHeaders()
headers.set("Content-Type", "application/json")
client.setHeader(headers)

// 使用HttpHeader
var httpHeader = HttpHeader()
httpHeader.add(key: "Content-Type", value: "application/json")
client.setHeader(httpHeader)

// 使用HashMap
var headerMap = HashMap<String, String>()
headerMap.put("Content-Type", "application/json")
client.setHeader(headerMap)
```

---

##### `setMethod(v: RequestMethod/String): LinderHttpClient`
设置HTTP请求方法。

**参数：**
- `v` - 请求方法，可以是`RequestMethod`枚举或自定义字符串

**说明：**
- 使用`RequestMethod`枚举版本：内部自动转换为字符串形式存储，保证方法名合法性
- 使用字符串版本：需自行确保方法名符合HTTP规范

**示例：**
```cangjie
// 使用枚举
client.setMethod(RequestMethod.POST)

// 使用自定义方法
client.setMethod("CUSTOM_METHOD")
```

---

##### `setInterceptor(v: Interceptor): LinderHttpClient`
设置HTTP拦截器。

**参数：**
- `v` - 拦截器对象

**示例：**
```cangjie
let intercept = Interceptor(
    onRequest: {http => println("发送请求: ${http.url}")},
    onError: {error, http => println("请求失败: ${error}")},
    onResponse: {res => println("收到响应: ${res.status}")}
)
client.setInterceptor(intercept)
```

---

##### `setServerName(v: String): LinderHttpClient`
自定义TLS握手域名。

**参数：**
- `v` - 域名标识字符串

**重要说明：**
- 此设置会被后续`setUrl()`调用覆盖
- 如需自定义域名，请在`setUrl()`之后调用此方法

**示例：**
```cangjie
client.setUrl("https://api.example.com")
    .setServerName("custom-domain.com") // 覆盖URL解析的域名
```

---

##### `setAutoRedirect(v: Bool): LinderHttpClient`
配置重定向策略。

**参数：**
- `v` - 是否自动重定向，`true`为启用，`false`为禁用

---

##### `setReadTimeout(v: Duration): LinderHttpClient`
设置读取响应超时阈值。

**参数：**
- `v` - 超时时间，单位为`Duration`

---

##### `setWriteTimeout(v: Duration): LinderHttpClient`
设置发送请求超时阈值。

**参数：**
- `v` - 超时时间，单位为`Duration`

---

##### `setBody(v: RequestBody/String/InputStream/Array<Byte>/DataModel/JsonObject/Form/MultipartFormData): LinderHttpClient`
设置请求附带数据。

**参数：**
- `v` - 请求体数据，支持多种类型

**支持的类型：**
1. `RequestBody`枚举：完整封装的各种请求体类型
2. `String`：字符串数据
3. `InputStream`：输入流数据
4. `Array<Byte>`：字节数组数据
5. `DataModel`：数据模型对象
6. `JsonObject`：JSON对象
7. `Form`：表单数据
8. `MultipartFormData`：Multipart表单数据

**示例：**
```cangjie
// 字符串数据
client.setBody("Hello World")

// 表单数据
var form = Form()
form.add("username", "admin")
form.add("password", "123456")
client.setBody(form)

// Multipart文件上传
var multipart = MultipartFormData()
multipart.addText("username", "admin")
    .addFile("avatar", "photo.jpg", fileBytes)
client.setBody(multipart)
```

---

##### `setInitialWindowSize(v: UInt32): LinderHttpClient`
配置客户端HTTP/2流控窗口初始值。

**参数：**
- `v` - 流控窗口大小，类型为`UInt32`

**取值范围：**
- `0` 至 `2^31 - 1`

---

##### `setEnablePush(v: Bool): LinderHttpClient`
配置客户端HTTP/2是否支持服务器推送。

**参数：**
- `v` - 是否启用服务器推送

---

##### `setHeaderTableSize(v: UInt32): LinderHttpClient`
配置客户端HTTP/2 HPACK动态表初始值。

**参数：**
- `v` - 动态表大小，类型为`UInt32`

---

##### `setHttpProxy(v: String): LinderHttpClient`
设置客户端HTTP代理。

**参数：**
- `v` - HTTP代理地址字符串

**默认行为：**
- 默认使用系统环境变量`http_proxy`的值

---

##### `setHttpsProxy(v: String): LinderHttpClient`
设置客户端HTTPS代理。

**参数：**
- `v` - HTTPS代理地址字符串

**默认行为：**
- 默认使用系统环境变量`https_proxy`的值

---

##### `clearBody(): LinderHttpClient`
清空请求附带数据。

**说明：**
- 将`requestBody`属性设置为`None`
- 用于在复用HTTP客户端实例时清除之前的请求体

---

##### `setDefaultHeader(): LinderHttpClient`
设置默认请求头。

**说明：**
- 将`headers`属性重置为新的`HttpHeader`实例
- 新实例会预置浏览器头信息

---

##### `destroy(): LinderHttpClient`
取消请求并清理资源。

**说明：**
- 如果HTTP客户端已创建，则关闭连接
- 将`client`属性设置为`None`
- 用于手动释放网络连接资源

### 4.1.4 发送请求

#### `send(needSetDefaultHeader: Bool = false): LinderHttpResponse`

**方法说明：**
发送HTTP请求并获取响应。

**参数：**
- `needSetDefaultHeader` - 是否设置为默认请求头，默认为`false`

**返回值：**
- `LinderHttpResponse` - 请求返回体对象

**请求发送流程：**
1. **拦截器预处理**：如果设置了`interceptor`且`onRequest`存在，先调用`onRequest()`方法
2. **客户端配置**：使用当前配置构建HTTP客户端
3. **请求构建**：根据URL、方法、头部、请求体等参数构建HTTP请求
4. **内容类型自动设置**：如果请求体存在且未设置`content-type`头部，根据请求体类型自动设置：
   - `String` → `"text/xml"`
   - `ByteArray` → `"application/octet-stream"`
   - `InputStream` → `"application/octet-stream"`
   - `UrlEncoded` → `"application/x-www-form-urlencoded"`
   - `Object` → `"application/json"`
   - `Json` → `"application/json"`
   - `Multipart` → `"multipart/form-data; boundary=xxxxx"`（自动生成boundary）
5. **发送请求**：通过HTTP客户端发送请求并接收响应
6. **拦截器后处理**：如果设置了`interceptor`且`onResponse`存在，调用`onResponse()`方法

**异常处理：**
- 请求发送过程中的异常会触发拦截器的`onError()`方法
- 所有异常都会被捕获

---

### 4.2 LinderHttpResponse
HTTP响应封装类。

#### 4.2.1 属性

| 属性名 | 类型 | 说明 |
|--------|------|------|
| `body` | `?InputStream` | 响应体数据流（只能读取一次） |
| `bodySize` | `?Int64` | 响应体大小 |
| `status` | `UInt16` | HTTP状态码 |
| `headers` | `HttpHeaders` | 响应头集合 |
| `isPersistent` | `Bool` | 连接是否保持 |
| `request` | `?HttpRequest` | 关联的请求对象 |

#### 4.2.2 计算属性

##### `location: ?Array<String>`
**重定向目标地址**

从`Location`响应头中提取的重定向地址数组。

**返回值说明：**
- `None` - 表示响应中不包含`Location`头部
- `Some(Array<String>)` - 包含1-N个URL地址的数组

---

##### `contentType: ?Array<String>`
**内容类型标识**

从`Content-Type`响应头中提取的MIME类型数组。

**返回值说明：**
- `None` - 表示响应中不包含`Content-Type`头部
- `Some(Array<String>)` - 包含1-N个内容类型标识的数组

**格式示例：**
- `["application/json; charset=utf-8"]`
- `["text/html; charset=UTF-8"]`

---

##### `setCookie: ?Array<String>`
**服务端设置的Cookie信息**

从`Set-Cookie`响应头中提取的Cookie字符串数组。

**返回值说明：**
- `None` - 表示响应中不包含`Set-Cookie`头部
- `Some(Array<String>)` - 包含1-N个Cookie字符串的数组

#### 4.2.3 方法

##### `getHeader(header: String): ?Array<String>`
获取指定响应头的值。

**参数：**
- `header` - 头部字段名

**返回值：**
- `?Array<String>` - 头部值数组，`None`表示该头部不存在

---

##### `getBodyStream(): InputStream`
获取原始响应体流。

**返回值：**
- `InputStream` - 未解码的二进制数据流

**重要限制：**
- 响应体流只能读取一次
- 调用两次会返回空或异常报错

---

##### `getBodyString(): String`
获取响应体字符串。

**返回值：**
- `String` - 按默认编码解码的字符串

**异常：**
- 会触发异常，详见`std.io.*`、`std.fs.*`

---

##### `getBodyJsonString(): String`
获取JSON格式字符串。

**返回值：**
- `String` - 格式化后的JSON字符串

**说明：**
此方法将响应体解析为JSON，然后重新格式化为标准JSON字符串。

---

##### `getBodyJsonValue(): JsonValue`
获取JsonValue对象。

**返回值：**
- `JsonValue` - 解析后的JSON值对象

---

##### `getBodyJsonObject(): JsonObject`
获取JsonObject对象。

**返回值：**
- `JsonObject` - 解析后的JSON对象

---

##### `getBodyDataModel(): DataModel`
获取DataModel对象。

**返回值：**
- `DataModel` - 序列化后的数据模型对象

---

##### `getBodyByteBuffer(): ByteBuffer`
获取响应体字节缓冲。

**返回值：**
- `ByteBuffer` - 内存连续的二进制数据缓冲

---

##### `getBodyFile(filePath!: Path, conflictMethod!: ConflictMethod = ConflictMethod.Harmony): Unit`
将响应体保存为文件。

**参数：**
- `filePath` - 目标文件路径（需包含文件名）
- `conflictMethod` - 文件冲突处理策略，默认`ConflictMethod.Harmony`

**冲突策略说明：**
- `ConflictMethod.Harmony`（默认）：自动重命名（如`file.txt` → `file(1).txt`）
- `ConflictMethod.OverWrite`：覆盖现有文件

---

##### `printHeaders(): Unit`
打印响应头到控制台。

**输出格式：**
- 每行格式：`HeaderName: [value1,value2]`

---

### 4.3 HttpHeader
HTTP头部管理类。

#### 4.3.1 构造方法
```cangjie
public init()  // 预置浏览器头部信息
```

**预置头部信息：**
创建`HttpHeader`实例时会自动添加以下浏览器头部：

| 头部字段 | 值 |
|----------|-----|
| `Sec-ch-ua` | `"Chromium";v="142", "Microsoft Edge";v="142", "Not_A Brand";v="99"` |
| `Sec-ch-ua-platform` | `"Windows"` |
| `User-agent` | `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0` |

#### 4.3.2 方法

##### `setAll(v: HttpHeaders): HttpHeader`
批量替换HTTP头。

**参数：**
- `v` - 新的`HttpHeaders`对象

**返回值：**
- `HttpHeader` - 当前对象实例（支持链式调用）

**说明：**
此操作将**完全覆盖**现有头信息。

---

##### `set(key!: String, value!: String): HttpHeader`
设置单一头字段（覆盖模式）。

**参数：**
- `key` - 头字段名（如`"Content-Type"`）
- `value` - 头字段值（如`"application/json"`）

**返回值：**
- `HttpHeader` - 当前对象实例（支持链式调用）

**行为说明：**
- 若字段已存在则覆盖原有值
- 若字段不存在则创建新字段

---

##### `add(key!: String, value!: String): HttpHeader`
添加头字段。

**参数：**
- `key` - 头字段名（如`"Accept"`）
- `value` - 头字段值（如`"text/html"`）

**返回值：**
- `HttpHeader` - 当前对象实例（支持链式调用）

**行为说明：**
- 若字段不存在则创建新字段
- 若字段已经存在，将在其对应的值列表中添加`value`

---

##### `delete(key!: String): HttpHeader`
删除头字段。

**参数：**
- `key` - 要删除的字段名

**返回值：**
- `HttpHeader` - 当前对象实例（支持链式调用）

---

##### `get(key: String): Collection<String>`
获取头字段值集合。

**参数：**
- `key` - 头字段名

**返回值：**
- `Collection<String>` - 值集合（可能为空集合）

---

##### `getFirst(key: String): ?String`
获取头字段首个值。

**参数：**
- `key` - 头字段名

**返回值：**
- `?String` - 字段的第一个值，不存在返回`None`

---

##### `isEmpty(): Bool`
检查头是否为空。

**返回值：**
- `Bool` - 当不含任何头字段时返回`true`

---

##### `printlnAll(): Unit`
打印所有头部到控制台。

---

### 4.4 MultipartFormData
Multipart/form-data请求体构建类，用于文件上传场景。

#### 4.4.1 构造方法
```cangjie
public init(boundary!: String = "")
```

**参数：**
- `boundary` - 可选的分隔符，如果不提供则自动生成

**说明：**
- 创建MultipartFormData实例
- boundary用于分隔不同的表单项
- 自动生成的boundary格式：`----Boundary{时间戳}{随机数}`

#### 4.4.2 方法

##### `getBoundary(): String`
获取boundary分隔符。

---

##### `addText(name: String, value: String): MultipartFormData`
添加文本字段。

**参数：**
- `name` - 字段名
- `value` - 字段值

**返回值：**
- `MultipartFormData` - 当前对象（支持链式调用）

---

##### `addFile(name: String, filename: String, content: Array<Byte>): MultipartFormData`
添加文件字段（字节数组）。

**参数：**
- `name` - 字段名
- `filename` - 文件名
- `content` - 文件内容（字节数组）

**返回值：**
- `MultipartFormData` - 当前对象（支持链式调用）

---

##### `addFileStream(name: String, filename: String, stream: InputStream): MultipartFormData`
添加文件字段（输入流）。

**参数：**
- `name` - 字段名
- `filename` - 文件名
- `stream` - 文件输入流

**返回值：**
- `MultipartFormData` - 当前对象（支持链式调用）

---

##### `getParts(): Array<MultipartPart>`
获取所有part。

---

##### `clear(): Unit`
清空所有part。

---

##### `build(): Array<Byte>`
构建multipart/form-data格式的字节数组。

**返回值：**
- `Array<Byte>` - 构建好的字节数组，可直接作为请求体发送

---

##### `getContentType(): String`
获取Content-Type头部值。

**返回值：**
- `String` - 格式为`multipart/form-data; boundary=xxxxx`

#### 4.4.3 使用示例

**基础文件上传：**
```cangjie
// 创建MultipartFormData实例
var multipart = MultipartFormData()

// 添加文本字段
multipart.addText("username", "admin")
multipart.addText("password", "123456")

// 添加文件
let fileBytes = File.readAllBytes(Path("avatar.jpg"))
multipart.addFile("avatar", "avatar.jpg", fileBytes)

// 发送请求
var client = LinderHttpClient()
client.setUrl(RequestUrl.from("https://api.example.com/upload"))
    .setMethod(RequestMethod.POST)
    .setBody(multipart)
    .send()
```

**多文件上传：**
```cangjie
var multipart = MultipartFormData()

// 添加多个文件
multipart.addFile("file1", "document1.pdf", File.readAllBytes(Path("doc1.pdf")))
    .addFile("file2", "document2.pdf", File.readAllBytes(Path("doc2.pdf")))
    .addFile("file3", "image.jpg", File.readAllBytes(Path("photo.jpg")))

// 发送请求
var client = LinderHttpClient()
client.setUrl(RequestUrl.from("https://api.example.com/upload-multiple"))
    .setMethod(RequestMethod.POST)
    .setBody(multipart)
    .send()
```

---

### 4.5 Interceptor
HTTP拦截器类。

#### 4.5.1 属性

| 属性名 | 类型 | 说明 |
|--------|------|------|
| `onRequest` | `?(LinderHttpClient) -> Unit` | 请求发送前拦截函数 |
| `onError` | `?(Exception, LinderHttpClient) -> Unit` | 请求失败拦截函数 |
| `onResponse` | `?(LinderHttpResponse) -> Unit` | 响应接收后拦截函数 |

#### 4.5.2 构造方法
```cangjie
public init(
    onRequest!: ?(LinderHttpClient) -> Unit = None,
    onError!: ?(Exception, LinderHttpClient) -> Unit = None,
    onResponse!: ?(LinderHttpResponse) -> Unit = None
)
```

**使用示例：**
```cangjie
let intercept = Interceptor(
    onRequest: {http => println("发送请求: ${http.url}")},
    onError: {error, http => println("请求失败: ${error}")},
    onResponse: {res => println("收到响应: ${res.status}")}
)

// 或者只注册需要的拦截器
let intercept = Interceptor(
    onRequest: {http => println("请求: ${http.url}")}
)
```

---

## 5. 便捷类

### 5.1 HttpQuick
HTTP便捷请求方法类，提供类似axios风格的快捷请求方法。所有方法均为静态方法。

#### 5.1.1 静态方法

##### GET请求
```cangjie
public static func get(url: String): LinderHttpResponse
public static func get(url: URL): LinderHttpResponse
public static func get(url: String, headers: HashMap<String, String>): LinderHttpResponse
```

##### POST请求
```cangjie
public static func post(url: String, body: String): LinderHttpResponse
public static func post(url: URL, body: String): LinderHttpResponse
public static func post(url: String, body: JsonObject): LinderHttpResponse
public static func post(url: String, body: Form): LinderHttpResponse
```

##### PUT请求
```cangjie
public static func put(url: String, body: String): LinderHttpResponse
public static func put(url: String, body: JsonObject): LinderHttpResponse
```

##### DELETE请求
```cangjie
public static func delete(url: String): LinderHttpResponse
public static func delete(url: URL): LinderHttpResponse
```

##### HEAD请求
```cangjie
public static func head(url: String): LinderHttpResponse
```

##### OPTIONS请求
```cangjie
public static func options(url: String): LinderHttpResponse
```

##### PATCH请求
```cangjie
public static func patch(url: String, body: String): LinderHttpResponse
public static func patch(url: String, body: JsonObject): LinderHttpResponse
```

#### 5.1.2 使用示例

```cangjie
// GET请求
let response = HttpQuick.get("https://api.example.com/data")

// POST请求（字符串）
let response = HttpQuick.post("https://api.example.com/data", "{\"name\": \"test\"}")

// POST请求（JSON对象）
let json = JsonObject()
json.put("name", "test")
let response = HttpQuick.post("https://api.example.com/data", json)

// POST请求（表单）
let form = Form()
form.add("username", "admin")
form.add("password", "123456")
let response = HttpQuick.post("https://api.example.com/login", form)

// DELETE请求
let response = HttpQuick.delete("https://api.example.com/data/123")
```

---

## 6. WebSocket类

### 6.1 WebSocketClient
WebSocket客户端封装类。

#### 6.1.1 属性

| 属性名 | 类型 | 说明 |
|--------|------|------|
| `url` | `URL` | 连接URL |
| `subProtocols` | `ArrayList<String>` | 子协议列表 |
| `headers` | `HttpHeaders` | 自定义请求头 |
| `tlsConfig` | `?TlsClientConfig` | TLS配置 |
| `selectedSubProtocol` | `?String` | 选定的子协议（连接成功后可用，只读） |

#### 6.1.2 构造方法
```cangjie
public init(url: String)
public init(url: URL)
```

**参数：**
- `url` - WebSocket服务器地址 (ws:// 或 wss://)

#### 6.1.3 方法

##### `setSubProtocols(protocols: ArrayList<String>/Array<String>): WebSocketClient`
设置子协议。

---

##### `addSubProtocol(protocol: String): WebSocketClient`
添加子协议。

---

##### `setHeaders(headers: HttpHeaders): WebSocketClient`
设置请求头。

---

##### `addHeader(name: String, value: String): WebSocketClient`
添加请求头。

---

##### `setTlsConfig(config: TlsClientConfig): WebSocketClient`
设置TLS配置。

---

##### `connect(): HttpHeaders`
连接WebSocket服务器。

**返回值：**
- `HttpHeaders` - 响应头信息

**异常：**
- `HttpException` - 连接失败时抛出

---

##### `sendText(message: String): Unit`
发送文本消息。

---

##### `sendBinary(data: Array<UInt8>): Unit`
发送二进制消息。

---

##### `ping(): Unit`
发送Ping帧。

---

##### `ping(payload: Array<UInt8>): Unit`
发送Ping帧（带负载）。

---

##### `pong(payload: Array<UInt8>): Unit`
发送Pong帧。

---

##### `read(): WebSocketFrame`
读取消息帧。

---

##### `readText(): ?String`
读取文本消息（自动处理分片）。

**返回值：**
- `?String` - 文本内容，如果是关闭帧返回`None`

---

##### `readBinary(): ?Array<UInt8>`
读取二进制消息（自动处理分片）。

**返回值：**
- `?Array<UInt8>` - 二进制数据，如果是关闭帧返回`None`

---

##### `close(status!: UInt16 = 1000): Unit`
发送关闭帧。

**参数：**
- `status` - 关闭状态码（默认1000表示正常关闭）

---

##### `closeConnection(status!: UInt16 = 1000): Unit`
发送关闭帧并关闭底层连接。

---

##### `isConnected(): Bool`
检查连接状态。

---

##### `getRawWebSocket(): ?WebSocket`
获取底层WebSocket对象。

#### 6.1.4 使用示例

```cangjie
// 创建WebSocket客户端
let ws = WebSocketClient("wss://echo.websocket.org")

// 设置子协议（可选）
ws.addSubProtocol("chat")

// 连接服务器
let respHeaders = ws.connect()
println("连接成功")

// 发送文本消息
ws.sendText("Hello, WebSocket!")

// 读取响应
if (let Some(message) <- ws.readText()) {
    println("收到消息: ${message}")
}

// 发送二进制消息
let data: Array<UInt8> = [1, 2, 3, 4, 5]
ws.sendBinary(data)

// 读取二进制响应
if (let Some(binaryData) <- ws.readBinary()) {
    println("收到二进制数据，长度: ${binaryData.size}")
}

// 发送Ping
ws.ping()

// 关闭连接
ws.closeConnection()
```

---

**完整示例：**
```cangjie
// 创建客户端并发送请求
let client = LinderHttpClient(url: RequestUrl.from("https://api.example.com/data"))
let response = client
    .setMethod(RequestMethod.POST)
    .setHeader(HttpHeader().set(key: "Content-Type", value: "application/json"))
    .setBody("{\"name\": \"test\"}")
    .send()

// 处理响应
println("状态码: ${response.status}")
if (let Some(contentType) <- response.contentType) {
    println("内容类型: ${contentType}")
}
let body = response.getBodyString()
println("响应体: ${body}")
```
