# LinderHttp

一个基于仓颉语言开发的现代化 HTTP 客户端库,提供简洁优雅的 API 和强大的功能支持。

## 特性

- **链式调用**: 支持流畅的链式 API 设计,代码更简洁
- **HTTP/2 支持**: 完整支持 HTTP/2 协议及流控配置
- **TLS/SSL**: 内置安全的 TLS 配置,支持自定义证书
- **拦截器机制**: 提供请求/响应/错误拦截器,方便统一处理
- **多种请求体**: 支持 String、JSON、FormData、Multipart、Stream 等多种格式
- **WebSocket**: 封装 WebSocket 客户端,支持文本/二进制消息
- **快速请求**: 提供 `HttpQuick` 类似 axios 的快捷方法
- **代理支持**: 支持 HTTP/HTTPS 代理配置
- **自动重定向**: 可配置的自动重定向处理


## 快速开始

### 基础 GET 请求

```cangjie
import linderHttp.*

// 使用快捷方法
let response = HttpQuick.get("https://api.example.com/data")
println(response.getBodyString())

// 使用客户端实例
let client = LinderHttpClient(url: "https://api.example.com/data")
let response = client.send()
println(response.status)
```

### POST JSON 数据

```cangjie
import linderHttp.*
import stdx.encoding.json.*

// 快捷方法
let json = JsonObject()
json.put("name", "张三")
json.put("age", 25)
let response = HttpQuick.post("https://api.example.com/users", json)

// 链式调用
let response = LinderHttpClient(url: "https://api.example.com/users")
    .setMethod(RequestMethod.POST)
    .setBody(json)
    .send()
```

### 设置请求头

```cangjie
let response = LinderHttpClient(url: "https://api.example.com/data")
    .setHeader("Authorization", "Bearer token123")
    .setHeader("Content-Type", "application/json")
    .send()
```

### 处理响应

```cangjie
let response = HttpQuick.get("https://api.example.com/data")

// 获取状态码
println("状态码: ${response.status}")

// 获取响应体字符串
let body = response.getBodyString()

// 获取 JSON 对象
let json = response.getBodyJsonObject()

// 获取响应头
let contentType = response.getHeader("content-type")

// 保存为文件
response.getBodyFile(filePath: Path("./data.json"))
```

### 使用拦截器

```cangjie
// 创建拦截器
let interceptor = Interceptor(
    onRequest: { client => 
        println("发送请求: ${client.url}")
    },
    onError: { error, client => 
        println("请求失败: ${error.message}")
    },
    onResponse: { response => 
        println("收到响应: ${response.status}")
    }
)

// 使用拦截器
let response = LinderHttpClient(
    url: "https://api.example.com/data",
    interceptor: interceptor
).send()
```

### Multipart 文件上传

```cangjie
let multipart = MultipartFormData()
    .addText("username", "张三")
    .addFile("avatar", "photo.jpg", fileBytes)

let response = LinderHttpClient(url: "https://api.example.com/upload")
    .setMethod(RequestMethod.POST)
    .setBody(multipart)
    .send()
```

### WebSocket 连接

```cangjie
// 创建 WebSocket 客户端
let ws = WebSocketClient("wss://echo.websocket.org")

// 连接服务器
ws.connect()

// 发送消息
ws.sendText("Hello, WebSocket!")

// 接收消息
if (let Some(message) <- ws.readText()) {
    println("收到消息: ${message}")
}

// 关闭连接
ws.close()
```

### 配置超时和代理

```cangjie
let response = LinderHttpClient(url: "https://api.example.com/data")
    .setReadTimeout(Duration.second * 30)  // 30秒读取超时
    .setWriteTimeout(Duration.second * 10) // 10秒写入超时
    .setHttpProxy("http://proxy.example.com:8080")
    .setHttpsProxy("https://proxy.example.com:8443")
    .send()
```

## API 文档

详细的 API 文档请参考 [API_REFERENCE.md](./API_REFERENCE.md)

## 核心类

### LinderHttpClient

HTTP 客户端主类,提供完整的请求配置和发送功能。

**主要方法:**
- `setUrl(url)`: 设置请求 URL
- `setMethod(method)`: 设置请求方法
- `setHeader(key, value)`: 设置请求头
- `setBody(body)`: 设置请求体
- `send()`: 发送请求

### LinderHttpResponse

HTTP 响应封装类,提供多种响应数据访问方式。

**主要方法:**
- `getBodyString()`: 获取字符串响应体
- `getBodyJsonObject()`: 获取 JSON 对象
- `getBodyFile(filePath)`: 保存为文件
- `getHeader(key)`: 获取响应头

### HttpQuick

快捷请求类,提供类似 axios 的静态方法。

**主要方法:**
- `get(url)`: GET 请求
- `post(url, body)`: POST 请求
- `put(url, body)`: PUT 请求
- `delete(url)`: DELETE 请求

### WebSocketClient

WebSocket 客户端封装类。

**主要方法:**
- `connect()`: 建立连接
- `sendText(message)`: 发送文本消息
- `readText()`: 读取文本消息
- `close()`: 关闭连接

## 示例项目

查看 `examples/` 目录获取更多使用示例:

- 基础 HTTP 请求
- RESTful API 调用
- 文件上传下载
- WebSocket 实时通信
- 拦截器使用

## 贡献

欢迎提交 Issue 和 Pull Request!

## 许可证

MIT License

## 联系方式

如有问题或建议,请提交 Issue 或联系维护者。
