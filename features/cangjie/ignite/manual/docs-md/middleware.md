# Middleware

## 中间件总览与执行模型

Ignite 的中间件是公开能力里非常关键的一层。它解决的不是“能不能拦一次请求”，而是把日志、安全、审计、压缩、限流、恢复、静态托管这些常见职责收成统一的服务入口。

执行模型可以简单理解为`洋葱模型`，通过 `ctx.next()` 传递控制权：

```
Request ──► Logger ──► CORS ──► Auth ──► Handler
                                          │
Response ◄── Logger ◄── CORS ◄── Auth ◄───┘
```


- 先注册的中间件先进入请求链，也最后处理响应链。
- 组级中间件只影响该组及其子组。
- 当多个能力需要配合时，优先考虑“语义顺序”，不要只图省事全部堆在一起。

一个常见组合大致会长这样：

```cangjie
import ignite.middleware.*

app.use(requestIdMiddleware())
app.use(loggerMiddleware())
app.use(auditMiddleware())
app.use(recoverMiddleware())
app.use(corsMiddleware())
app.use(securityMiddleware())
app.use(compressMiddleware())
```

## 安全类

### `securityMiddleware`

统一写入常见安全响应头，适合做服务默认安全基线。公开文档层面，它负责的内容包括：

- `X-Content-Type-Options`
- `X-Frame-Options`
- `HSTS`
- `CSP`

如果你之前关心 HSTS 是否支持，当前公开答案是支持的，并且归在这条中间件里。

### `corsMiddleware`

用于跨域控制。适合给前后端分离场景、管理后台或浏览器调用接口设定来源、方法、Header 与凭证策略。

### `csrfMiddleware`

采用双提交 Cookie 思路做 CSRF 校验，适合仍然保留 Cookie 会话的管理端或表单类服务。

### `basicAuthMiddleware`

最直接的 Basic Auth 方案，适合内网管理面、临时运维入口或快速验证路径。

### `keyAuthMiddleware`

提供 API Key 鉴权，支持从 Header、Query 或 Cookie 中提取。

### `jwtMiddleware`

当前公开主线支持 `HS256`，并允许从 Header、Query、Cookie 提取 token。

通过校验后，框架会把常用结果注入上下文，例如：

- `jwt_claims`
- `jwt_sub`
- `jwt_token`

如果你需要更强的密钥治理或外部身份系统对接，建议把这条中间件作为统一入口，再把复杂策略放在业务层或网关层收敛。

### `encryptCookieMiddleware`

提供 Cookie 加解密能力，当前公开口径是 AEAD v1 双读新写迁移路径。它适合：

- 登录态 Cookie 加固
- 历史 Cookie 格式迁移
- 需要保留服务端无状态读写体验，但又不想裸奔明文 Cookie 的场景

## 观测与治理类

### `loggerMiddleware`

请求日志入口，可配合 `LoggerConfig` 自定义输出方式、自定义 logger、实体日志与 JSON 行输出。

需要结构化日志接入时，可以把它作为服务默认日志主线。

### `auditMiddleware`

用于统一审计事件输出，适合这些场景：

- 访问关键接口
- 记录 actor / action / result
- 安全事件留痕
- 把 requestId、riskLevel、securityCode 等字段整理成结构化记录

如果你的服务要面向审计、复盘或安全排查，这条中间件的价值会很直接。

### `accessLogMiddleware`

偏访问日志视角，适合记录 IP、延迟、User-Agent 这类流量信息。

### `requestIdMiddleware`

为请求补齐 `X-Request-ID`，方便串联日志、审计和错误排查。

### `recoverMiddleware`

负责 panic 恢复，避免单次异常直接把服务执行链打穿。

如果你启用 `kmode`，还可以把它与 `RecoverConfig.kmodeFailover` 一起用在首跑或应急探测场景里，但这属于调试与验证辅助，不应被误当成默认高可用编排方案。

### `kmodeMiddleware`

`kmode` 是 `0500` 阶段一个非常有识别度的调试与首跑治理能力。

它当前有两种公开用法：

- `kmodeMiddleware(Bool)`：兼容旧模式，但默认只对 loopback IP 开启 `legacyOpen`，并会打印 warning，适合本机快速开关
- `kmodeMiddleware(policy)`：策略模式，基于 `KModePolicy` 控制 Header Key、IP 白名单与 capability

在公开语义里，`kmode` 主要用于：

- 首跑调试
- 自检接口门禁
- 维护者验证路径

它不等于生产期开着的“超级开关”。

如果你需要非本机来源也进入 `kmode`，请改用显式 `KModePolicy(...)`，而不是继续假设 `kmodeMiddleware(Bool)` 会默认对所有来源放开。

### 安全可观测与日志等级

除了中间件本身，Ignite 还公开了安全指标快照与日志等级语义：

- `securityMetricsSnapshot()`：可读取 `decryptFailures`、`signatureFailures`、`certRejects`
- 普通模式下日志默认更偏向稳定输出
- `kmode` 下可放宽到更详细的调试等级

## 流量与缓存类

### `rateLimitMiddleware`

按 IP 或自定义 key 限流，适合公共接口、登录口、管理面入口等高频场景。

### `bodyLimitMiddleware`

限制请求体大小，减少异常 payload 对服务的冲击。

### `timeoutMiddleware`

对超时请求做记录与治理收口，适合把长耗时接口拉回到可观测面。

### `cacheMiddleware`

做内存缓存 GET 响应，适合轻量只读接口和静态型数据输出。

### `compressMiddleware`

当前 `0500` 公开压缩能力的基线是：

- 已支持：`gzip`、`deflate`
- 当前未支持：`br` / Brotli
- 当两者都可接受且权重相同，默认优先 `gzip`

同时它还支持：

- 按 `Accept-Encoding` 协商
- 最小压缩体积阈值 `minBytes`
- `skipIfNoGain`，避免压缩后反而变大

如果你需要 Brotli，请把它视作外部扩展方向，而不是当前主仓已默认落地能力。

### `etagMiddleware`

配合 `If-None-Match` 做 `304` 协商，适合文件类或稳定资源类响应。

## 其他公开中间件

### `sessionMiddleware`

提供会话 ID Cookie 与 SessionStore 组合，适合仍需要服务端会话态的管理端场景。

### `redirectMiddleware`

做 URL 重定向规则，适合老路径迁移或入口整形。

### `rewriteMiddleware`

做 URL 重写，并把结果写入上下文，适合做轻量网关式改写。

### `staticFileMiddleware`

用于静态文件服务。更完整的静态目录与 `staticSpa` 说明见 [`advanced.md`](advanced.md)。

### `faviconMiddleware`

提供 `favicon.ico` 这类高频静态入口的快速响应。

### `healthCheckMiddleware`

适合统一暴露健康检查端点，方便部署探活与首跑验证。

### `idempotencyMiddleware`

围绕 `X-Idempotency-Key` 做请求幂等控制，适合支付、任务派发、重试写请求等场景。

### `proxyMiddleware`

反向代理入口。当前公开语义里，它还支持可选的 X509 校验入口，适合在服务内做受控的代理转发。

`ProxyConfig` 新增可选的 `tlsConfig: ?TlsClientConfig` 入参，当上游目标为 `https` 时，通过 `ClientBuilder.tlsConfig(tc)` 将 TLS 配置注入出站连接。如果不设置，当前主线仍会保留旧的 missing-TLS boundary；在要求显式 TLS 配置的运行时上，会直接停在 `TLS must be configured` 这一层。设置后可通过 `TlsClientConfig.verifyMode` 控制证书校验策略，并让 proxy 继续越过这道旧边界。

在 `ig0600` 当前实现里，`proxyMiddleware` 已经补上几条更实用的 payload-path 行为：

- 透传并保留原始 query string
- 过滤 `connection`、`transfer-encoding` 这类 hop-by-hop 头，避免把 HTTP/1.1 语义头硬塞进不合适的链路
- 大请求体转发时，若请求体尚未被上层读成内存、且 framing 可安全确定，会直接把请求 `InputStream` 转发给上游，而不是默认整包缓冲
- 大文件或未知长度响应回传时，会直接 relay 上游响应体，不再强制先读完整包

当前仍保留一条保守约束：

- 如果上游目标是 `https`，并且当前请求体长度未知，框架会默认先落临时文件、补 `content-length` 后再转发，避免错误地发送 `Transfer-Encoding` 到潜在 HTTP/2 链路
- 这条 `https unknown-length -> temp-file fallback` 回退现在已由回归测试锁住；即使上游连接最终失败，也不会悄悄退回到错误的分块转发语义
- 如果你想跑一条更聚焦的 maintainer probe，当前也可以直接执行 `./manual/samples/proxy_transport_acceptance/probe.sh`

## 组合建议

如果你在搭建一个典型 API 服务，可以从下面这条顺序起步：

1. `requestIdMiddleware`
2. `loggerMiddleware`
3. `auditMiddleware`
4. `recoverMiddleware`
5. `corsMiddleware`
6. `securityMiddleware`
7. `jwtMiddleware` 或其他鉴权中间件
8. `bodyLimitMiddleware`
9. `compressMiddleware`
10. `etagMiddleware` / `cacheMiddleware`

如果是管理后台或运维面，再按需要补 `sessionMiddleware`、`csrfMiddleware`、`staticFileMiddleware`。

## 想继续看什么

- 想理解 `RestClient`：继续看 [`client.md`](client.md)
- 想看 Swagger、TLS、静态托管、WebSocket：继续看 [`advanced.md`](advanced.md)
