# LinderHttp API 参考文档

本文档提供 LinderHttp 库的完整 API 参考。

## 目录

- [核心类](#核心类)
  - [LinderHttpClient](#linderhttpclient)
  - [LinderHttpResponse](#linderhttpresponse)
  - [HttpHeader](#httpheader)
  - [Interceptor](#interceptor)
- [快捷方法](#快捷方法)
  - [HttpQuick](#httpquick)
- [数据模型](#数据模型)
  - [RequestMethod](#requestmethod)
  - [RequestBody](#requestbody)
  - [RequestUrl](#requesturl)
  - [MultipartFormData](#multipartformdata)
  - [ConflictMethod](#conflictmethod)
- [WebSocket](#websocket)
  - [WebSocketClient](#websocketclient)

---

## 核心类

### LinderHttpClient

HTTP 客户端主类,提供 HTTP 请求的构建和发送功能。

#### 构造函数

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

**参数说明:**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| url | RequestUrl | 空字符串 | 请求的目标 URL |
| serverName | String | '' | TLS 握手域名,为空时自动从 URL 解析 |
| tlsConfig | ?TlsClientConfig | None | TLS 客户端配置 |
| httpHeader | ?HttpHeader | None | 库专属 HTTP 头容器 |
| stdHeaders | ?HttpHeaders | None | 标准 HTTP 头容器 |
| interceptor | ?Interceptor | None | HTTP 拦截器 |
| method | RequestMethod | GET | 请求方法 |
| requestBody | ?RequestBody | None | 请求体数据 |
| autoRedirect | Bool | true | 是否自动重定向 |
| readTimeout | Duration | 15秒 | 读取超时时间 |
| writeTimeout | Duration | 15秒 | 写入超时时间 |
| initialWindowSize | UInt32 | 65535 | HTTP/2 流控窗口初始值 |
| enablePush | Bool | true | HTTP/2 是否支持服务器推送 |
| headerTableSize | UInt32 | 4096 | HTTP/2 Hpack 动态表初始值 |
| httpProxy | String | '' | HTTP 代理地址 |
| httpsProxy | String | '' | HTTPS 代理地址 |

#### 公共属性

```cangjie
public var url: RequestUrl                    // 请求 URL
public var headers: HttpHeader                // HTTP 头部
public var tlsConfig: TlsClientConfig         // TLS 配置
public var method: String                     // 请求方法
public var requestBody: ?RequestBody          // 请求体
public var autoRedirect: Bool                 // 自动重定向
public var readTimeout: Duration              // 读取超时
public var writeTimeout: Duration             // 写入超时
public var initialWindowSize: UInt32          // HTTP/2 流控窗口
public var enablePush: Bool                   // HTTP/2 推送支持
public var headerTableSize: UInt32            // HTTP/2 动态表大小
public var httpProxy: String                  // HTTP 代理
public var httpsProxy: String                 // HTTPS 代理
```

#### 方法

##### setUrl

设置请求 URL 并自动更新 TLS 域名。

```cangjie
public func setUrl(v: RequestUrl): LinderHttpClient
public func setUrl(v: String): LinderHttpClient
public func setUrl(v: URL): LinderHttpClient
```

**参数:**
- `v`: URL,支持 RequestUrl、String 或 URL 类型

**返回:** 当前对象(支持链式调用)

**示例:**
```cangjie
client.setUrl("https://api.example.com/data")
```

##### setHeader

设置 HTTP 请求头。

```cangjie
public func setHeader(v: HttpHeaders): LinderHttpClient
public func setHeader(v: HttpHeader): LinderHttpClient
public func setHeader(v: HashMap<String, String>): LinderHttpClient
```

**参数:**
- `v`: 请求头,支持 HttpHeaders、HttpHeader 或 HashMap 类型

**返回:** 当前对象(支持链式调用)

**示例:**
```cangjie
client.setHeader("Authorization", "Bearer token123")
```

##### setMethod

设置请求方法。

```cangjie
public func setMethod(v: RequestMethod): LinderHttpClient
public func setMethod(v: String): LinderHttpClient
```

**参数:**
- `v`: 请求方法,支持 RequestMethod 枚举或自定义字符串

**返回:** 当前对象(支持链式调用)

**示例:**
```cangjie
client.setMethod(RequestMethod.POST)
client.setMethod("CUSTOM")
```

##### setBody

设置请求体。

```cangjie
public func setBody(v: RequestBody): LinderHttpClient
public func setBody(v: String): LinderHttpClient
public func setBody(v: InputStream): LinderHttpClient
public func setBody(v: Array<Byte>): LinderHttpClient
public func setBody(v: DataModel): LinderHttpClient
public func setBody(v: JsonObject): LinderHttpClient
public func setBody(v: Form): LinderHttpClient
public func setBody(v: MultipartFormData): LinderHttpClient
```

**参数:**
- `v`: 请求体数据,支持多种类型

**返回:** 当前对象(支持链式调用)

**示例:**
```cangjie
client.setBody("{\"name\": \"test\"}")
client.setBody(jsonObject)
client.setBody(multipartData)
```

##### setInterceptor

设置拦截器。

```cangjie
public func setInterceptor(v: Interceptor): LinderHttpClient
```

**参数:**
- `v`: 拦截器对象

**返回:** 当前对象(支持链式调用)

##### setServerName

自定义 TLS 握手域名。

```cangjie
public func setServerName(v: String): LinderHttpClient
```

**参数:**
- `v`: 域名标识

**返回:** 当前对象(支持链式调用)

##### setAutoRedirect

配置重定向策略。

```cangjie
public func setAutoRedirect(v: Bool): LinderHttpClient
```

**参数:**
- `v`: 是否自动重定向

**返回:** 当前对象(支持链式调用)

##### setReadTimeout

设置读取超时时长。

```cangjie
public func setReadTimeout(v: Duration): LinderHttpClient
```

**参数:**
- `v`: 超时时间

**返回:** 当前对象(支持链式调用)

##### setWriteTimeout

设置写入超时时长。

```cangjie
public func setWriteTimeout(v: Duration): LinderHttpClient
```

**参数:**
- `v`: 超时时间

**返回:** 当前对象(支持链式调用)

##### setHttpProxy / setHttpsProxy

设置代理。

```cangjie
public func setHttpProxy(v: String): LinderHttpClient
public func setHttpsProxy(v: String): LinderHttpClient
```

**参数:**
- `v`: 代理地址

**返回:** 当前对象(支持链式调用)

##### send

发送请求。

```cangjie
public func send(needSetDefaultHeader!: Bool = false): LinderHttpResponse
```

**参数:**
- `needSetDefaultHeader`: 是否设置为默认请求头,默认为 false

**返回:** 响应对象

**示例:**
```cangjie
let response = client.send()
```

##### clearBody

清空请求体。

```cangjie
public func clearBody(): LinderHttpClient
```

**返回:** 当前对象(支持链式调用)

##### destroy

取消请求并关闭客户端。

```cangjie
public func destroy(): LinderHttpClient
```

**返回:** 当前对象(支持链式调用)

---

### LinderHttpResponse

HTTP 响应封装类,提供响应数据的访问和处理功能。

#### 构造函数

```cangjie
public LinderHttpResponse(
    public var body!: ?InputStream = None,
    public var bodySize!: ?Int64 = None,
    public var status!: UInt16,
    public var headers!: HttpHeaders,
    public var isPersistent!: Bool,
    public var request!: ?HttpRequest = None
)

public init()
```

#### 公共属性

```cangjie
public var body: ?InputStream          // 响应体数据流
public var bodySize: ?Int64            // 响应体字节长度
public var status: UInt16              // HTTP 状态码
public var headers: HttpHeaders        // 响应头集合
public var isPersistent: Bool          // 连接是否保持
public var request: ?HttpRequest       // 关联的请求对象
```

#### 属性

##### location

重定向目标地址。

```cangjie
public prop location: ?Array<String>
```

**返回:** Location 头部的 URL 数组,None 表示无重定向

##### contentType

内容类型标识。

```cangjie
public prop contentType: ?Array<String>
```

**返回:** Content-Type 头部数组

##### setCookie

服务端设置的 Cookie。

```cangjie
public prop setCookie: ?Array<String>
```

**返回:** Set-Cookie 头部数组

#### 方法

##### getHeader

获取指定响应头的值。

```cangjie
public func getHeader(header: String): ?Array<String>
```

**参数:**
- `header`: 头部字段名

**返回:** 头部值数组,None 表示不存在

##### getBodyStream

获取原始响应体流。

```cangjie
public func getBodyStream(): InputStream
```

**返回:** 未解码的二进制数据流

##### getBodyString

获取响应体字符串。

```cangjie
public func getBodyString(): String
```

**返回:** 按默认编码解码的字符串

##### getBodyJsonString

获取格式化的 JSON 字符串。

```cangjie
public func getBodyJsonString(): String
```

**返回:** 格式化的 JSON 字符串

##### getBodyJsonValue

解析为 JsonValue。

```cangjie
public func getBodyJsonValue(): JsonValue
```

**返回:** JsonValue 对象

##### getBodyJsonObject

解析为 JsonObject。

```cangjie
public func getBodyJsonObject(): JsonObject
```

**返回:** JsonObject 对象

##### getBodyDataModel

解析为 DataModel。

```cangjie
public func getBodyDataModel(): DataModel
```

**返回:** DataModel 对象

##### getBodyByteBuffer

获取响应体字节缓冲。

```cangjie
public func getBodyByteBuffer(): ByteBuffer
```

**返回:** 内存连续的二进制数据缓冲

##### getBodyFile

将响应体保存为文件。

```cangjie
public func getBodyFile(
    filePath!: Path, 
    conflictMethod!: ConflictMethod = ConflictMethod.Harmony
): Unit
```

**参数:**
- `filePath`: 目标文件路径
- `conflictMethod`: 文件冲突处理策略,默认自动重命名

##### printHeaders

打印响应头到控制台。

```cangjie
public func printHeaders(): Unit
```

---

### HttpHeader

HTTP 头部管理类,提供请求头的设置、添加、删除和查询功能。

#### 构造函数

```cangjie
public init()
```

初始化时预置浏览器默认头部:
- Sec-ch-ua: Chromium 浏览器标识
- Sec-ch-ua-platform: Windows 平台标识
- User-agent: Edge 浏览器用户代理

#### 公共属性

```cangjie
public var rawHeaders: HttpHeaders    // 底层 HTTP 头存储容器
```

#### 方法

##### setAll

批量替换 HTTP 头。

```cangjie
public func setAll(v: HttpHeaders): HttpHeader
```

**参数:**
- `v`: 新的 HttpHeaders 对象

**返回:** 当前对象(支持链式调用)

##### set

设置单一头字段(覆盖模式)。

```cangjie
public func set(key!: String, value!: String): HttpHeader
```

**参数:**
- `key`: 头字段名
- `value`: 头字段值

**返回:** 当前对象(支持链式调用)

##### add

添加头字段。

```cangjie
public func add(key!: String, value!: String): HttpHeader
```

**参数:**
- `key`: 头字段名
- `value`: 头字段值

**返回:** 当前对象(支持链式调用)

**说明:** 若字段已存在,将在其值列表中添加新值

##### delete

删除头字段。

```cangjie
public func delete(key!: String): HttpHeader
```

**参数:**
- `key`: 要删除的字段名

**返回:** 当前对象(支持链式调用)

##### get

获取头字段值集合。

```cangjie
public func get(key: String): Collection<String>
```

**参数:**
- `key`: 头字段名

**返回:** 值集合(可能为空集合)

##### getFirst

获取头字段首个值。

```cangjie
public func getFirst(key: String): ?String
```

**参数:**
- `key`: 头字段名

**返回:** 字段的第一个值,不存在返回 None

##### isEmpty

检查头是否为空。

```cangjie
public func isEmpty(): Bool
```

**返回:** 当不含任何头字段时返回 true

##### printlnAll

打印所有头字段。

```cangjie
public func printlnAll(): Unit
```

---

### Interceptor

HTTP 拦截器,允许在请求生命周期的关键点插入自定义逻辑。

#### 构造函数

```cangjie
public init(
    onRequest!: ?(LinderHttpClient) -> Unit = None,
    onError!: ?(Exception, LinderHttpClient) -> Unit = None,
    onResponse!: ?(LinderHttpResponse) -> Unit = None
)
```

**参数:**
- `onRequest`: 请求前拦截函数
- `onError`: 错误拦截函数
- `onResponse`: 响应拦截函数

#### 公共属性

```cangjie
public let onRequest: ?(LinderHttpClient) -> Unit
public let onError: ?(Exception, LinderHttpClient) -> Unit
public let onResponse: ?(LinderHttpResponse) -> Unit
```

**示例:**
```cangjie
let interceptor = Interceptor(
    onRequest: { client => println("请求: ${client.url}") },
    onError: { error, client => println("错误: ${error.message}") },
    onResponse: { response => println("响应: ${response.status}") }
)
```

---

## 快捷方法

### HttpQuick

提供类似 axios 风格的快捷请求方法,所有方法均为静态方法。

#### GET 请求

```cangjie
public static func get(url: String): LinderHttpResponse
public static func get(url: URL): LinderHttpResponse
public static func get(url: String, headers: HashMap<String, String>): LinderHttpResponse
```

**示例:**
```cangjie
let response = HttpQuick.get("https://api.example.com/data")
```

#### POST 请求

```cangjie
public static func post(url: String, body: String): LinderHttpResponse
public static func post(url: URL, body: String): LinderHttpResponse
public static func post(url: String, body: JsonObject): LinderHttpResponse
public static func post(url: String, body: Form): LinderHttpResponse
```

**示例:**
```cangjie
let response = HttpQuick.post("https://api.example.com/users", jsonString)
let response = HttpQuick.post("https://api.example.com/users", jsonObject)
```

#### PUT 请求

```cangjie
public static func put(url: String, body: String): LinderHttpResponse
public static func put(url: String, body: JsonObject): LinderHttpResponse
```

**示例:**
```cangjie
let response = HttpQuick.put("https://api.example.com/users/1", jsonObject)
```

#### DELETE 请求

```cangjie
public static func delete(url: String): LinderHttpResponse
public static func delete(url: URL): LinderHttpResponse
```

**示例:**
```cangjie
let response = HttpQuick.delete("https://api.example.com/users/1")
```

#### HEAD 请求

```cangjie
public static func head(url: String): LinderHttpResponse
```

#### OPTIONS 请求

```cangjie
public static func options(url: String): LinderHttpResponse
```

#### PATCH 请求

```cangjie
public static func patch(url: String, body: String): LinderHttpResponse
public static func patch(url: String, body: JsonObject): LinderHttpResponse
```

---

## 数据模型

### RequestMethod

HTTP 请求方法枚举,包含所有标准 HTTP 方法以及自定义方法支持。

```cangjie
public enum RequestMethod <: ToString {
    | GET
    | POST
    | HEAD
    | PUT
    | PATCH
    | DELETE
    | COPY
    | OPTIONS
    | LINK
    | UNLINK
    | PURGE
    | LOCK
    | UNLOCK
    | PROPFIND
    | VIEW
    | CUSTOM(String)
}
```

**方法:**

##### toString

转换为字符串。

```cangjie
public func toString(): String
```

---

### RequestBody

HTTP 请求体类型枚举,支持多种请求体格式。

```cangjie
public enum RequestBody {
    | String(String)
    | InputStream(InputStream)
    | ByteArray(Array<Byte>)
    | Object(DataModel)
    | Json(JsonObject)
    | UrlEncoded(Form)
    | Multipart(MultipartFormData)
}
```

**静态方法:**

##### from

创建 RequestBody 实例。

```cangjie
public static func from(v: String): RequestBody
public static func from(v: InputStream): RequestBody
public static func from(v: Array<Byte>): RequestBody
public static func from(v: Form): RequestBody
public static func from(v: DataModel): RequestBody
public static func from(v: JsonObject): RequestBody
public static func from(v: MultipartFormData): RequestBody
```

---

### RequestUrl

请求 URL 类型枚举,支持字符串 URL 和 URL 对象两种形式。

```cangjie
public enum RequestUrl <: ToString {
    | STRING(String)
    | URL(URL)
}
```

**静态方法:**

##### from

创建 RequestUrl 实例。

```cangjie
public static func from(v: String): RequestUrl
public static func from(v: URL): RequestUrl
```

**方法:**

##### toString

转换为字符串。

```cangjie
public func toString(): String
```

---

### MultipartFormData

Multipart/form-data 请求体,用于构建 multipart/form-data 格式的 HTTP 请求体。

#### 构造函数

```cangjie
public init(boundary!: String = "")
```

**参数:**
- `boundary`: 可选的分隔符,如果不提供则自动生成

#### 方法

##### getBoundary

获取 boundary 分隔符。

```cangjie
public func getBoundary(): String
```

##### addText

添加文本字段。

```cangjie
public func addText(name: String, value: String): MultipartFormData
```

**参数:**
- `name`: 字段名
- `value`: 字段值

**返回:** 当前对象(支持链式调用)

##### addFile

添加文件字段(字节数组)。

```cangjie
public func addFile(name: String, filename: String, content: Array<Byte>): MultipartFormData
```

**参数:**
- `name`: 字段名
- `filename`: 文件名
- `content`: 文件内容

**返回:** 当前对象(支持链式调用)

##### addFileStream

添加文件字段(输入流)。

```cangjie
public func addFileStream(name: String, filename: String, stream: InputStream): MultipartFormData
```

**参数:**
- `name`: 字段名
- `filename`: 文件名
- `stream`: 文件输入流

**返回:** 当前对象(支持链式调用)

##### getParts

获取所有 part。

```cangjie
public func getParts(): Array<MultipartPart>
```

##### clear

清空所有 part。

```cangjie
public func clear(): Unit
```

##### build

构建 multipart/form-data 格式的字节数组。

```cangjie
public func build(): Array<Byte>
```

**返回:** 构建好的字节数组

##### getContentType

获取 Content-Type 头部值。

```cangjie
public func getContentType(): String
```

**返回:** `multipart/form-data; boundary=xxxxx`

---

### ConflictMethod

文件冲突处理策略枚举。

```cangjie
public enum ConflictMethod {
    | OverWrite  // 覆盖现有文件
    | Harmony    // 自动重命名(如 file.txt → file(1).txt)
}
```

---

## WebSocket

### WebSocketClient

WebSocket 客户端封装类,提供简化的 WebSocket 连接和消息收发功能。

#### 构造函数

```cangjie
public init(url: String)
public init(url: URL)
```

**参数:**
- `url`: WebSocket 服务器地址 (ws:// 或 wss://)

#### 公共属性

```cangjie
public var url: URL                      // 连接 URL
public var subProtocols: ArrayList<String> // 子协议列表
public var headers: HttpHeaders          // 自定义请求头
public var tlsConfig: ?TlsClientConfig   // TLS 配置
```

#### 属性

##### selectedSubProtocol

选定的子协议(连接成功后可用)。

```cangjie
public prop selectedSubProtocol: ?String
```

#### 方法

##### setSubProtocols

设置子协议。

```cangjie
public func setSubProtocols(protocols: ArrayList<String>): WebSocketClient
public func setSubProtocols(protocols: Array<String>): WebSocketClient
```

**返回:** 当前对象(支持链式调用)

##### addSubProtocol

添加子协议。

```cangjie
public func addSubProtocol(protocol: String): WebSocketClient
```

**返回:** 当前对象(支持链式调用)

##### setHeaders

设置请求头。

```cangjie
public func setHeaders(headers: HttpHeaders): WebSocketClient
```

**返回:** 当前对象(支持链式调用)

##### addHeader

添加请求头。

```cangjie
public func addHeader(name: String, value: String): WebSocketClient
```

**返回:** 当前对象(支持链式调用)

##### setTlsConfig

设置 TLS 配置。

```cangjie
public func setTlsConfig(config: TlsClientConfig): WebSocketClient
```

**返回:** 当前对象(支持链式调用)

##### connect

连接 WebSocket 服务器。

```cangjie
public func connect(): HttpHeaders
```

**返回:** 响应头信息

**异常:** 连接失败时抛出 HttpException

##### sendText

发送文本消息。

```cangjie
public func sendText(message: String): Unit
```

**参数:**
- `message`: 文本内容

##### sendBinary

发送二进制消息。

```cangjie
public func sendBinary(data: Array<UInt8>): Unit
```

**参数:**
- `data`: 二进制数据

##### ping

发送 Ping 帧。

```cangjie
public func ping(): Unit
public func ping(payload: Array<UInt8>): Unit
```

**参数:**
- `payload`: 负载数据(可选)

##### pong

发送 Pong 帧。

```cangjie
public func pong(payload: Array<UInt8>): Unit
```

**参数:**
- `payload`: 负载数据

##### read

读取消息帧。

```cangjie
public func read(): WebSocketFrame
```

**返回:** WebSocketFrame 对象

##### readText

读取文本消息(自动处理分片)。

```cangjie
public func readText(): ?String
```

**返回:** 文本内容,如果是关闭帧返回 None

##### readBinary

读取二进制消息(自动处理分片)。

```cangjie
public func readBinary(): ?Array<UInt8>
```

**返回:** 二进制数据,如果是关闭帧返回 None

##### close

发送关闭帧。

```cangjie
public func close(status!: UInt16 = 1000): Unit
```

**参数:**
- `status`: 关闭状态码,默认 1000 表示正常关闭

##### closeConnection

发送关闭帧并关闭底层连接。

```cangjie
public func closeConnection(status!: UInt16 = 1000): Unit
```

**参数:**
- `status`: 关闭状态码

##### isConnected

检查连接状态。

```cangjie
public func isConnected(): Bool
```

**返回:** 是否已连接

##### getRawWebSocket

获取底层 WebSocket 对象。

```cangjie
public func getRawWebSocket(): ?WebSocket
```

**返回:** WebSocket 对象

---

## 完整示例

### RESTful API 调用

```cangjie
import linderHttp.*
import stdx.encoding.json.*

// GET 请求
let users = HttpQuick.get("https://api.example.com/users").getBodyJsonObject()

// POST 创建用户
let newUser = JsonObject()
newUser.put("name", "张三")
newUser.put("email", "zhangsan@example.com")

let created = LinderHttpClient(url: "https://api.example.com/users")
    .setMethod(RequestMethod.POST)
    .setBody(newUser)
    .send()

// PUT 更新用户
let updateData = JsonObject()
updateData.put("name", "李四")

let updated = HttpQuick.put("https://api.example.com/users/1", updateData)

// DELETE 删除用户
let deleted = HttpQuick.delete("https://api.example.com/users/1")
```

### 文件上传

```cangjie
import linderHttp.*
import std.fs.*

// 读取文件
let fileBytes = File(Path("./photo.jpg")).readBytes()

// 构建 multipart 数据
let multipart = MultipartFormData()
    .addText("username", "张三")
    .addText("description", "我的头像")
    .addFile("avatar", "photo.jpg", fileBytes)

// 上传
let response = LinderHttpClient(url: "https://api.example.com/upload")
    .setMethod(RequestMethod.POST)
    .setBody(multipart)
    .send()

println("上传结果: ${response.status}")
```

### 使用拦截器记录日志

```cangjie
import linderHttp.*
import std.time.*

let logInterceptor = Interceptor(
    onRequest: { client => 
        println("[${DateTime.now()}] 发送请求: ${client.method} ${client.url}")
    },
    onError: { error, client => 
        println("[${DateTime.now()}] 请求失败: ${error.message}")
    },
    onResponse: { response => 
        println("[${DateTime.now()}] 收到响应: ${response.status}")
    }
)

let response = LinderHttpClient(
    url: "https://api.example.com/data",
    interceptor: logInterceptor
).send()
```

### WebSocket 实时通信

```cangjie
import linderHttp.*

let ws = WebSocketClient("wss://echo.websocket.org")

// 连接
let headers = ws.connect()
println("连接成功")

// 发送消息
ws.sendText("Hello, WebSocket!")

// 接收消息
while (true) {
    if (let Some(message) <- ws.readText()) {
        println("收到: ${message}")
        if (message == "exit") {
            break
        }
    } else {
        break
    }
}

// 关闭连接
ws.closeConnection()
```
