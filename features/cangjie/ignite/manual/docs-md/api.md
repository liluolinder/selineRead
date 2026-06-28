# API

## App

`App` 是 Ignite 的入口对象。你通常会在这里完成这些事情：

- 注册路由
- 组织路由组
- 挂载中间件
- 配置 Swagger / OpenAPI
- 注册错误处理与关闭钩子
- 启动监听或做进程内测试

```cangjie
let app = App(config: Config(appName: "MyService"))

app.get("/health", { ctx =>
    ctx.json(#"{"ok":true}"#)
})

app.listen("0.0.0.0", 3000)
```

## Router

日常使用时，你通常不需要单独操作底层 `Router`，而是通过 `App` 和 `Group` 完成路由组织。

公开语义上可以把它理解为：

- `App` 负责全局注册
- `Group` 负责带前缀、带组级中间件的模块化组织
- 路由匹配、冲突处理与命名规则由内部路由层负责收敛

## Ctx

`Ctx` 贯穿一个请求的完整生命周期，是你最常打交道的对象。

它主要负责：

- 读取请求信息：方法、路径、Header、Body、Cookie
- 读取参数：路径参数、查询参数、表单、multipart
- 写回响应：状态码、JSON、文本、HTML、文件、流式输出
- 暂存本地状态：供中间件和处理函数共享

```cangjie
app.get("/users/:id", { ctx =>
    let id = ctx.params("id")
    let fields = ctx.queryDefault("fields", "all")
    ctx.json(#"{"id":"${id}","fields":"${fields}"}"#)
})
```

## 路由注册

Ignite 提供比较直接的注册方式：

```cangjie
app.get("/users", listUsers)
app.post("/users", createUser)
app.put("/users/:id", updateUser)
app.delete("/users/:id", deleteUser)
app.all("/health", healthHandler)
```

如果你希望像 Express / Fiber 那样在单条路由上挂一个明确的 handler chain，现在也可以直接传 `Array<Handler>`：

```cangjie
let userReadChain: Array<Handler> = [
    requireAuth,
    auditUserRead,
    listUsers
]

app.get("/users", userReadChain)
app.post("/users", [requireAuth, createUser])
```

当你需要补充 Swagger 或接口元数据时，可以把 `RouteOption` 一起传入：

```cangjie
let option = RouteOption()
option.withSummary("Create user")
option.withTag("user")
option.withOperationId("user.create")

app.post("/users", createUser, option: option)
```

如果你想替换默认的 `404 / 405` 返回体，也可以在 `App` 层注册 hook：

```cangjie
app.notFound({ ctx =>
    let _ = ctx.status(404).json(#"{"error":"route_not_found"}"#)
})

app.methodNotAllowed({ ctx =>
    let _ = ctx.status(405).json(#"{"error":"method_not_allowed"}"#)
})
```

当前 contract 里，这两条 fallback 仍会继续经过全局 middleware 链，`405` 也仍会保留 `Allow` 头与 `OPTIONS` 语义。

## 路径参数与查询参数

- 路径参数：`ctx.params("id")`
- 查询参数：`ctx.query("name")`
- 带默认值的查询参数：`ctx.queryDefault("page", "1")`
- 区分 URL 查询和表单时，可以用 `ctx.queryFromUrl(...)` 与 `ctx.queryFromForm(...)`

```cangjie
app.get("/search/:type", { ctx =>
    let kind = ctx.params("type")
    let keyword = ctx.queryDefault("q", "ignite")
    ctx.json(#"{"type":"${kind}","q":"${keyword}"}"#)
})
```

## 请求级 locals

如果中间件和处理函数之间只需要传递字符串，继续用原来的：

- `ctx.setLocal(key, value)`
- `ctx.getLocal(key)`

如果你需要在一次请求内临时携带 typed object / typed scalar，现在也可以用：

- `ctx.setLocalValue(key, value)`
- `ctx.getLocalValue<T>(key)`

```cangjie
class CurrentActor {
    let id: String
    init(id: String) {
        this.id = id
    }
}

app.use({ ctx =>
    ctx.setLocal("mode", "strict")
    ctx.setLocalValue("actor", CurrentActor("u-1"))
    ctx.next()
})

app.get("/me", { ctx =>
    let mode = ctx.getLocal("mode") ?? "unknown"
    let actorId = match (ctx.getLocalValue<CurrentActor>("actor")) {
        case Some(actor) => actor.id
        case None => "missing"
    }
    _ = ctx.json(#"{"mode":"${mode}","actor":"${actorId}"}"#)
})
```

这层设计当前的定位是“补足 request-context 表达力”，不是引入一个复杂的 DI 容器，因此生命周期仍然严格限定在单次请求内。

## 响应方法一览

`Ctx` 提供的响应方法覆盖了多数服务常用路径：

- `ctx.requestBody()`：拿到底层 `InputStream`，适合自己做流式消费
- `ctx.bodyBytes()` / `ctx.bodyString()`：把请求体读成字节或字符串，适合普通体积请求
- `ctx.saveBodyToFile(path)`：把请求体直接推到文件，适合大 body 上传落盘
- `ctx.json(body)`：直接回 JSON 字符串
- `ctx.jsonSerialize(obj)`：类型实现序列化能力时回 JSON
- `ctx.jsonEncode(obj)`：走 `JsonEncodable` 或自定义 `Config.jsonEncoder`
- `ctx.jsonEncodeStream(obj, contentLength?)`：对象实现 `JsonWriterEncodable` 时走流式 JSON；这条路径不使用 `Config.jsonEncoder`
- `ctx.sendString(body)`：纯文本响应
- `ctx.html(body)`：HTML 响应
- `ctx.send(bytes)`：原始字节
- `ctx.sendStream(stream, ...)`：直接发送 `InputStream`，适合大响应体或文件式输出
- `ctx.writer()`：增量写响应体；HTTP/1.1 下可表现为 chunked，HTTP/2 下不应该再补 `Transfer-Encoding`
- `ctx.sse()`：SSE 单向推送；H2 检测路径下不会再主动注入 H1 专属头，并会补最小 anti-buffering 头与 heartbeat helper
- `ctx.sendStatus(404)`：状态码 + 默认消息
- `ctx.redirect("/login")`：重定向
- `ctx.noContent()`：`204 No Content`
- `ctx.sendFile(path)` / `ctx.download(path, filename)` / `ctx.sendFileRange(path)`：文件与 Range 响应

```cangjie
app.get("/ping", { ctx =>
    ctx.status(200).sendString("pong")
})
```

大上传场景更推荐这样写：

```cangjie
app.post("/upload-large", { ctx =>
    let saved = ctx.saveBodyToFile("/tmp/upload-large.bin")
    ctx.status(201).json(#"{"saved":"# + saved.toString() + #"}"#)
})
```

这条大 body 落盘路径现在不只是 `handleForTest(...)` 下可用：

- 真实 HTTP/1.1 `content-length` 上传已经有回归覆盖
- 真实 HTTP/1.1 `chunked` 上传也已经有回归覆盖
- 现有回归还会确认 `saveBodyToFile(...)` 没有先把请求体塞进 `ctx.bodyBytes()` 缓存再落盘
- 如果你想直接跑可视化入口，当前可以从 [`manual/samples/files/README.md`](../samples/files/README.md) 开始

如果你要问“HTTP/2 下还能不能流式返回”，答案不是靠 `Transfer-Encoding`：

- RFC 7540 禁止在 HTTP/2 消息里使用 `Transfer-Encoding`
- `ctx.sendStream(...)` 现在已经有真实 HTTP/1.1 `known-length`、`unknown-length`、`HEAD` 三条线路的回归覆盖
- `ctx.jsonEncodeStream(...)` 是 `JsonEncodable` family 的显式流式 twin：`ctx.jsonEncode(...)` 继续保持 full-buffer，并继续只在这条 full-buffer 路上使用 `Config.jsonEncoder`
- `ctx.writer()` / `sendFile(...)` 这类增量写路径在 H2 下应该依赖底层 writer 的分次发送能力，而不是 H1 的 chunked 头部语义
- 所以 H2 路径的重点是“不要发错头”，以及“确认底层 transport 的多次 write 的确被逐次发出”
- 如果你想先从 runnable sample 体验 `sendStream(...)` 的公开用法，也可以直接看 [`manual/samples/files/README.md`](../samples/files/README.md)

如果你在 Client 侧用了 `RestClient`，响应拿回来后还可以继续读结构化 transport 留痕：

- `resp.observeSnapshot()`：把响应头里的 observe 字段回放成 `ClientObserveSnapshot`
- `resp.transportTouchpoint()`：把已选 backend / reason / fallbackChain 等字段回放成 `ClientTransportTouchpoint`
- `client.lastClientObserveSnapshot()`：读取最近一次请求在 client 侧保留的 observe 快照，成功/失败都可用
- `client.lastClientTransportTouchpoint()`：读取最近一次请求在 client 侧保留的 transport 选择留痕，失败于响应前也能保留
- `client.clearRecoverySnapshots()`：在下一轮 probe / retry / 诊断前显式清空 retained recovery，避免把上一轮结果误读成当前窗口

这样做的好处是，联调排障时不必只盯日志文本，也不用手工一个个去读 `x-ignite-observe-*` 头。

这三条 client-side retained API 和 response-side replay 不是互相替代的关系：

- response-side replay 更适合“我已经拿到了响应对象，想从响应头里回放结构化信息”
- client-side retained recovery 更适合“请求在更早阶段失败了，或者我想在一次长生命周期 client 上保留最后一跳诊断”
- 如果你希望把 retained recovery 严格切成“这一轮请求只看这一轮”，就在开始下一轮前先调一次 `clearRecoverySnapshots()`

## `ignite.binary`

如果你在写协议型中间件、认证组件，或者准备处理 `CBOR / COSE / authenticatorData` 这类二进制结构，`ignite.binary` 现在已经有第一批最小 helper 可以直接拿来用：

- `base64UrlEncode(...)` / `base64UrlDecode(...)`
- `cloneBytes(...)`
- `sliceBytes(...)`
- `readUint16BE(...)` / `readUint32BE(...)`
- `decodeCbor(...)` / `decodeCborMap(...)`
- `decodeCoseEc2PublicKey(...)`
- `decodeAuthenticatorData(...)`
- `decodeAttestedCredentialData(...)`
- `decodeAttestationObject(...)`

这组能力当前的定位不是“完整二进制框架”，而是 `ig0600` 先把共享 primitive 稳定下来，避免 `security`、`client crypto`、`jwt`、后续 `WebAuthn` 需求继续各自复制一套实现。

```cangjie
import ignite.binary.*

let signCount = readUint32BE(authenticatorData, 33)
let challenge = String.fromUtf8(base64UrlDecode(challengeB64u))
let coseKey = decodeCoseEc2PublicKey(credentialPublicKeyBytes)
let authData = decodeAuthenticatorData(authenticatorData)
let attested = decodeAttestedCredentialData(authData)
let attestation = decodeAttestationObject(attestationObjectBytes)
```

当前边界也要说清楚：

- 这里只是最小 primitive 层
- `CBOR` 目前只覆盖 definite-length 的 `unsigned / negative / bytes / text / array / map`
- `COSE` 目前也只覆盖最窄的 read-only `ES256 / P-256 EC2 COSE_Key` 结构化提取
- `authenticatorData` 目前只覆盖固定头解包：`rpIdHash / flags / signCount / tail`
- attested credential data 目前只覆盖 `AAGUID / credentialId / credentialPublicKeyBytes / remainingBytes`
- `attestationObject` 目前只覆盖最外层 `fmt / authData / attStmt`
- 还不是完整 `CBOR` ecosystem
- 也不是完整 `COSE_Key` 解释层，更不是通用 `COSE` framework
- 也还不是完整 `attestationObject` / attestation statement / trust chain 解释层
- 更不是 WebAuthn ceremony 本身

## 路由组

当接口需要按模块拆分时，用 `group` 会比手动拼路径更顺：

```cangjie
let api = app.group("/api/v1")
api.get("/users", listUsers)
api.post("/users", createUser)

let admin = api.group("/admin")
admin.get("/stats", statsHandler)
```

如果你给组级挂中间件，这些中间件会应用到该组及其子组的路由上。

## Config

`Config` 负责统一描述应用运行期设置。常见字段可以按这几组理解：

- 服务识别：`appName`、`appVersion`、`serverHeader`
- 基础限制：`bodyLimit`、`readTimeout`、`writeTimeout`
- Swagger：`enableSwagger`、`swaggerPath`、`enableSwaggerCache`、`enablePrintSwaggerUrl`
- 启动体验：`enablePrintRoutes`、`enableBannerSignature`
- 调试与自检：`kmode`、`kmodePanicHandler`
- TLS：`tlsCertFile`、`tlsKeyFile`、`enableTlsPrecheck`
- JSON：`jsonEncoder`

```cangjie
let config = Config(
    appName: "MyService",
    appVersion: "1.0.0",
    bodyLimit: 10 * 1024 * 1024,
    enableSwagger: true,
    swaggerPath: "/swagger",
    enablePrintSwaggerUrl: true,
    enableBannerSignature: true,
    enableTlsPrecheck: true
)

let app = App(config: config)
```

## 请求绑定与校验 `bindJsonOr400`

`Ctx.bindJsonOr400<T>(decoder, validate?)` 的价值在于把“JSON 解码失败”和“业务校验失败”的返回语义集中起来。

```cangjie
import stdx.encoding.json.JsonValue

public class CreateUserReq {
    public let name: String
    public init(name: String) {
        this.name = name
    }
}

func decodeCreateUserReq(v: JsonValue): CreateUserReq {
    let obj = v.asObject()
    CreateUserReq(obj.get("name").orThrow().asString())
}

app.post("/users", { ctx =>
    if (let Some(req) <- ctx.bindJsonOr400<CreateUserReq>(
        decodeCreateUserReq,
        validate: { data =>
            if (data.name.trimAscii().size == 0) {
                return Some("name is required")
            }
            None
        }
    )) {
        _ = ctx.status(201).sendString("created:${req.name}")
    }
})
```

绑定失败时会自动返回 `400` JSON，`reason` 为：

- `invalid_json`
- `invalid_payload`
- `validation_failed`

## 命名路由与 `urlFor`

Ignite 允许你给路由命名，再反向生成 URL。常见写法有两种：

- 在 `RouteOption` 里设置 `operationId`
- 用 `app.nameRoute(method, path, name)` 单独命名

```cangjie
app.get(
    "/users/:id/posts/:postId",
    getUserPost,
    option: RouteOption().withOperationId("user.post.detail")
)

let url = app.urlFor(
    "user.post.detail",
    params: [("id", "42"), ("postId", "7")],
    query: [("include", "meta data")]
) ?? "/fallback"
```

如果路由不存在，或者缺少必须的路径参数，`urlFor` 会返回 `None`。

## `handleForTest`

`handleForTest` 是 Ignite 非常实用的一条公开能力：不需要真正起监听器，也能把请求打进 `App` 做断言。

```cangjie
let app = App()
app.use({ ctx =>
    ctx.next()
    _ = ctx.setHeader("x-mw", "hit")
})
app.get("/ping", { ctx => _ = ctx.sendString("pong") })

let resp = app.handleForTest("GET", "/ping")
@Assert(resp.status, 200)
@Assert(resp.body, "pong")
@Assert(resp.header("x-mw") ?? "", "hit")
```

当你在做：

- 中间件链路回归
- `bindJsonOr400` 错误语义断言
- 命名路由与响应头检查
- 首跑样例的轻量验证

这条能力会非常顺手。
