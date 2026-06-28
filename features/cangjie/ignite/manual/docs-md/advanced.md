# Advanced

## 自定义 Logger

如果默认日志输出不够，你可以自己实现 `Logger` 接口，再通过 `LoggerConfig` 注入到 `loggerMiddleware`。

```cangjie
public class MyLogger: Logger {
    public func log(msg: String) {
        println("[MyLogger] " + msg)
    }
}

let loggerConfig = LoggerConfig(logger: MyLogger())
app.use(loggerMiddleware(config: loggerConfig))
```

如果你需要结构化日志，也可以启用 JSON 行输出，把数据继续送到外部日志系统。

## WebSocket

Ignite 提供直接的 WebSocket 入口：

```cangjie
app.ws("/chat", { conn =>
    while (true) {
        let msg = conn.readMessage()
        if (msg.isClose) { break }
        if (msg.isText) {
            conn.writeText("Echo: ${msg.text()}")
        }
    }
    conn.close()
})
```

这适合聊天室、实时通知、设备控制面等轻量实时场景。

## SSE

如果你只是单向推送事件，SSE 往往比 WebSocket 更轻：

```cangjie
app.get("/events", { ctx =>
    let sse = ctx.sse()
    sse.sendRetry(3000)
    sse.sendHeartbeat("ready")
    sse.sendEvent(#"{"count":1}"#, event: "counter", id: "1")
})
```

当前这条公开面要诚实说明两点：

- Ignite 现在会给 SSE 路径补 `X-Accel-Buffering: no`，并提供最小 heartbeat comment helper，避免常见代理缓冲误导。
- 但 `close()` / `flush()` 这类更强的生命周期控制，目前还受 `stdx.net.http.HttpResponseWriter` 已公开 surface 限制，不能在 `0600` 里假装已经补齐。

## 流式响应

对于边生成边输出的响应，可以直接拿到 writer：

```cangjie
app.get("/stream", { ctx =>
    let writer = ctx.writer()
    writer.writeString("chunk 1\n")
    writer.writeString("chunk 2\n")
    writer.writeString("chunk 3\n")
})
```

这里要把协议语义分清：

- `ctx.writer()` 表示“增量写响应体”，不是“强行给所有协议都套上 chunked”。
- HTTP/1.1 下，这条路径可以继续表现为 chunked 语义。
- HTTP/2 下，不能再发 `Transfer-Encoding`；Ignite 现在只在非 H2 路径补这个头。
- 当前底层 `stdx.net.http.HttpResponseWriter` 的本地 contract 写明：HTTP/2 下每次 `write(...)` 会把数据封装并发出。但这仍应和真实 H2 on-wire 验证分开表述，不要把“协议上成立”直接写成“本仓所有集成路径都已完全验透”。
- 当前工作区已经把旧的 `GeneralPrivateKey.decodeFromPem(...)` key-load crash seam 从 `api2/tls.cj` 主路径上移开，但本地 H2 on-wire closeout 仍未在这张包里重证；`manual/samples/h2wire/` 的价值仍然是把后续 proof holder 收成可复验样例，而不是提前宣称 H2 已 fully closed。

## 静态文件

如果只是做简单静态目录映射，使用 `app.static(prefix, root)` 即可。

它适合：

- 文档附件
- 前端打包产物里的固定资源
- 管理页依赖的小体量静态文件

## `staticSpa`

当你需要“有文件就发文件，没有文件就回退 `index.html`”时，用 `staticSpa`：

```cangjie
app.staticSpa("/", "frontend/out", "index.html")
```

当前公开语义里要特别记住两点：

- 路径匹配顺序仍然遵循 Ignite 正常路由顺序，所以通常应把 `staticSpa` 放在较后面。
- 出于安全考虑，含 `..` 的路径不会被当作普通静态文件放行。

## IgniteKit

`IgniteKit` 适合把轻量 HTML / CSS / 动态页面资源从主业务路由里剥离出来：

```cangjie
let kit = IgniteKit(prefix: "/web")
_ = kit.css("/app.css", "body{font-family:monospace;}")
_ = kit.html("/index.html", "<h1>{{title}}</h1>", vars: [("title", "IgniteKit")])
_ = kit.dynamicHtml("/hello.html", { ctx =>
    let name = (ctx.queryFromUrl("name") ?? "ignite").trimAscii()
    kit.renderTemplate("<h1>Hello, {{name}}</h1>", vars: [("name", name)])
})
_ = kit.mount(app)
```

它适合：

- 运维页
- 管理后台小页面
- 快速验证 SSR 前的轻量页面
- 小体量动态资源映射

当前 `0500` 阶段里，IgniteKit 仍然留在 Ignite 主仓公开能力内，不在这一轮文档里提前展开拆包叙事。

## Swagger / OpenAPI

Swagger 是 `0500` 阶段非常重要的一条公开能力。

```cangjie
let app = App(config: Config(
    enableSwagger: true,
    swaggerPath: "/swagger",
    enablePrintSwaggerUrl: true,
    kmode: true
))
```

三个公开配置点要分清：

- `enableSwagger`：控制 Swagger UI 与 OpenAPI JSON 路由是否存在
- `swaggerPath`：同时控制 UI 路径与 `${swaggerPath}/json`
- `enablePrintSwaggerUrl`：只控制启动时是否打印 `Swagger UI: ...` 这一行

如果你给路由配置了 `RequestBodySpec`、`ResponseSpec`、`TestOption`，这些信息会进入 `InterfaceSpec` 和最终的 OpenAPI 输出。

当前公开边界还要记住：

- `x-ignite-test` 是接口元数据，不是生产自动化开关
- 运行态自检只在 `Config.kmode = true` 时生效
- 自检可通过 Header `x-ignite-test` 或 Query `__ignite_test` / `__igtest` 触发

## TLS / HTTPS

Ignite 现在支持 HTTPS，但公开文档要把边界说清楚。

```cangjie
let app = App(config: Config(
    tlsCertFile: "./cert.pem",
    tlsKeyFile: "./key.pem",
    enableTlsPrecheck: true
))

app.listen("0.0.0.0", 443)
```

当前公开主线是：

- 默认 HTTPS 路径仍以 `stdx` TLS 构造为准
- `enableTlsPrecheck` 默认开启，会先做 `jinguissl` 预检，再进入当前 TLS 构造路径；当前主线会把原始 PEM/DER key 包在一个轻量 `PrivateKey` wrapper 里交给 TLS native 层，避免在已知 runtime lane 上直接落回 `GeneralPrivateKey.describe()` 崩溃点
- `jinguissl` 当前不是默认 HTTPS 监听替代方案
- 如果你要更稳妥的生产接入，仍可优先考虑现有默认路径或在反向代理层完成 TLS 终结

部署时还要特别注意：

- 一次 `app.listen(addr, port)` 只对应一条监听器
- 如果你同时需要 HTTP 与 HTTPS，当前更推荐反向代理、两个实例，或参考 [`manual/samples/dualport`](../samples/README.md) 的验证思路，而不是假定框架会自动双端口编排

如果证书链没问题，开启 TLS 后服务端会协商 HTTP/2 ALPN；这属于当前默认路径的一部分，但不代表已经进入更激进的传输演进承诺。

## 优雅关闭与错误收口

Ignite 支持统一错误处理和关闭钩子：

```cangjie
app.onError({ ctx, err =>
    println("[Error] ${err.message}")
    ctx.status(500).json(#"{"error":"${err.message}"}"#)
})

app.onShutdown({
    println("Releasing resources...")
})
```

建议把这些钩子视作服务生命周期的一部分，而不是最后补丁：

- `onError` 负责统一错误语义
- `onShutdown` 负责资源释放与退出前清理
