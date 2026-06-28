<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-Ignite-ff6b35?style=for-the-badge&labelColor=1a1a2e" alt="Ignite" />
  <img src="https://img.shields.io/badge/version-0.7.7-blue?style=for-the-badge&labelColor=1a1a2e" alt="Version" />
  <img src="https://img.shields.io/badge/license-Apache%202.0-green?style=for-the-badge&labelColor=1a1a2e" alt="License" />
</p>
<div align="center">
<pre style="background:#00000000">
┌───────────────────────────────────────────────────────┐
│                   <span style="color:#88C0D0;">Ignite v0.7.7</span>                      │
│   <span style="color:#6EB186;">http://127.0.0.1:8080</span><span style="color:#9AA0A6;"> || (bound on 0.0.0.0:8080)</span>    │
│                                                       │
│   Touchpoints .......... 16   Processes .......... 1  │
│   Prefork ......... Disabled   PID .......... 67271   │
│                                       <span style="color:#8A8A8A;"><i>_Ignite 0.7.7</i></span>  │
└───────────────────────────────────────────────────────┘
</pre>
<span style="font-weight:300;font-size:38px">Ignite / 叶燧</span><br/>
<span style="font-weight:100;font-size:26px">以仓颉语言打造、面向真实服务落地的 Web 框架</span>
<p align="center">
  <strong>仓颉胃，Express味</strong><br>
  <sub>富中间件 · 快速起服务 · 生产治理默认在场 · Server/Client 一体化演进</sub>
</p>
</div>
<p align="center">
  <a href="https://atomgit.com/Cinexus/ignite-cangjie">开源主仓</a> ·
  <a href="https://pkg.cangjie-lang.cn/package/ignite">中心仓</a>
</p>

## 为什么选择 Ignite?

> 点燃仓颉 Web 开发的第一把火。

仓颉（Cangjie）正在进入需要“真正能承载业务”的阶段，而 **Ignite** 的目标不是只做一个 Demo 框架，而是提供一条从首个接口、到安全治理、再到长期维护都更统一的 Web 服务路径。

与直接使用官方 `stdx.httpServer` 相比，Ignite 更强调 **减少样板代码、统一中间件组织、沉淀默认实践、降低服务重复搭建成本**。  
与 [Fiber](https://gofiber.io/) 这类强调轻量体验的主流框架相比，Ignite 尽可能的在仓颉生态里，给你近似的体验：能不能快速上手，同时把审计、安全、Swagger、静态托管、Client 能力一起收进统一框架。

我们相信，好的框架应该像一片叶子轻盈穿梭，又能像燧石碰撞瞬间点燃。  
因此我们取 **“叶”** 之灵动，取 **“燧”** 之开创，命名它为 **叶燧 (Ignite)**。

## 当前状态（0.7.7）

- `0700` 现在是当前公开/治理主线，重点不再只是“继续堆能力”，而是把现有能力压成更容易交接、验收和云端恢复的 truth lane。
- `H1` 是当前最成熟的 intake 方向：`hello / api / client / files` 这几条公开样例路径已经足够支撑 first-run 与常见 payload/stream/client 联调。
- `H2` 现在仍是 `guarded intake`：有 smoke、guard、writer/sendStream honest wording，但不应被讲成已经 fully green 的 commodity lane。
- 自研 `server-socket` runway 已经有了 parser/session/body/writer/runtime experiment proof ladder，但它仍是 experiment/runway truth，不是默认 public engine 切换承诺。

```
    ┌─────────────────────────────────────────┐
    │            Ignite Architecture          │
    │                                         │
    │   Request ──► Router (Trie) ──► Match   │
    │                                   │     │
    │              Middleware Chain ◄───┘     │
    │              │     │     │              │
    │              ▼     ▼     ▼              │
    │          Logger   CORS   Recover        │
    │            │                            │
    │            ▼                            │
    │       Handler ──► Ctx ──► Response      │
    │                    │                    │
    │           ┌────────┼────────┐           │
    │           ▼        ▼        ▼           │
    │         JSON     SSE    WebSocket       │
    └─────────────────────────────────────────┘
```


### Ignite 适合什么项目

- 需要快速搭建 REST API、后台服务、运维接口、内部平台
- 需要把 Swagger、静态资源、SSE、WebSocket、文件下载统一收进一个仓库
- 希望在仓颉生态里少做一遍“审计、恢复、限流、日志、安全”样板工程
- 希望服务端与客户端能力尽量统一，减少重复封装

### 为什么不直接用 stdx.httpServer

`stdx.httpServer` 当然是可靠的底层能力，但在真实项目里，团队通常还要继续补这些东西：

- 路由组织与分组约定
- 中间件链与统一错误处理
- 安全头、鉴权、日志、审计、限流
- Swagger / OpenAPI、静态托管、SSE / WebSocket
- 测试入口、Client 封装、项目级默认模板

Ignite 的价值不是替代官方底层，而是把这些高频重复劳动收敛成一套更适合业务团队长期维护的默认路径。

### Ignite 的强力点

- `App / Router / Ctx` 足够直，起服务快，不用先学一堆仪式。
- `logger / audit / recover / requestId / security / swagger` 默认就在主线上，不是让你每个项目再拼一遍。
- `bindJsonOr400`、`handleForTest`、`urlFor`、`InterfaceSpec` 这些高频能力已经成形。
- `RestClient` 跟 Server 一起演进，联调时不必再额外造一层陌生封装。
- OpenHarmony、HarmonyOS、EulerOS、通用 Linux 的平台口径已经分列，后续还有 LoongArch 预留。

## 快速开始

先别读长篇，先把 `hello` 跑起来。

### 环境要求

- 仓颉sdk环境 [`cangjie-sdk`](https://cangjie-lang.cn/download) v1.1.0+
- 仓颉标准扩展库 [`cangjie-stdx`](https://gitcode.com/Cangjie/cangjie_stdx/releases/v1.1.0-beta.24.1)
  >如需[`仓颉 nightly[含stdx链接]`](https://gitcode.com/Cangjie/nightly_build)
- 支持平台：详见下方《支持平台》矩阵（已区分 OpenHarmony、HarmonyOS、EulerOS 与通用 Linux）
- 依赖接入：在业务仓的 `cjpm.toml` 中增加 Git 依赖；中心仓接入与认证仓配置，继续看 [`manual/docs-md/Guide.md`](manual/docs-md/Guide.md)。

```toml
[dependencies]
Ignite = { git = "https://gitcode.com/cinyu/ignite-cangjie" }
```

```cangjie
import ignite.*

main() {
    let app = App()

    app.get("/", { ctx =>
        ctx.json(#"{"message":"Hello, Ignite!"}"#)
    })

    app.listen("0.0.0.0", 3000)
}
```

如果你要继续往下走，推荐顺序是 `hello -> api -> swagger -> client`。  
更完整的首跑顺序、样例选择、中心仓配置和常见失败修复，请看 [`manual/docs-md/Guide.md`](manual/docs-md/Guide.md) 与 [`manual/samples/README.md`](manual/samples/README.md)。

## 特性亮点

- 起手轻：`App / Router / Group / Ctx` 心智干净，适合快速起 REST API、后台服务和内部平台。
- 治理不缺席：安全、审计、日志、请求 ID、限流、压缩、缓存、会话、重写、代理、健康检查都在主线能力面里。
- 接口可解释：Swagger / OpenAPI、`InterfaceSpec`、`TestOption`、`x-ignite-test` 和 `kmode` 让接口不仅能跑，还能讲清楚。
- 错误收得住：`bindJsonOr400` 统一常见请求绑定错误语义，首跑排障少走弯路。
- 路由更像“框架”而不是“脚手架”：命名路由、`RouteOption.operationId`、`urlFor`、组级中间件、route-level handler array、可替换 `404/405` hook 都已经接上。
- 联调不分家：内置 `RestClient`、Builder 模式、Retry / Hook / Observe、Cookie v2、multipart、加密请求与 X509 校验入口，响应侧可直接拿 `observeSnapshot()` / `transportTouchpoint()`，client 侧也保留 `lastClientObserveSnapshot()` / `lastClientTransportTouchpoint()` 并支持 `clearRecoverySnapshots()` 显式切段。
- 大请求体有直落盘路径：`requestBody()` / `saveBodyToFile(...)` 可以避免先把整包 body 全塞进内存。
- 静态和动态都能接：`static`、`staticSpa`、`IgniteKit` 都在公开能力面上。
- 边界说人话：当前 HTTPS 默认路径、压缩支持范围、样例入口都写在公开文档里，不让你靠猜。

## API 基础速览

Ignite 的核心对象不多，但都很像“拿来就能干活”的那种狠角色：

- `App`：负责把服务真正支起来，路由、生命周期、错误处理、Swagger 都从这里起手。
- `Router / Group`：负责把接口按模块排整齐，不用每个项目自己重新发明组织方式。
- `Ctx`：负责拿请求、回响应、读参数、写 Cookie、做流式输出，也是 request locals 的承载面；其中 `writer()` 是增量写接口，H2 路径不依赖 `Transfer-Encoding`。
- `Config`：负责把服务名、版本、超时、Swagger、TLS、Banner、kMode 这些运行期口径收在一起。
- `RouteOption`：负责把接口的 `summary`、`tag`、`operationId`、请求体、响应和测试元数据挂上去。
- `RestClient`：负责让调用端别再另造一套陌生心智，联调时直接沿用 Ignite 的语义。
- `handleForTest`：负责在不手动 `listen` 的情况下，把请求直接打进 `App` 做回归断言。

具体方法级说明见 [`manual/docs-md/api.md`](manual/docs-md/api.md)。

## 中间件
### 集成提供大量中间件
具体方法级说明见 [`manual/docs-md/middleware.md`](manual/docs-md/middleware.md)。

### 自定义中间件

```cangjie
let authMiddleware: Handler = { ctx =>
    let token = ctx.header("Authorization")
    if (let Some(t) <- token) {
        ctx.setLocal("user", "authenticated")
        ctx.next()
    } else {
        ctx.status(401).json(#"{"error": "Unauthorized"}"#)
    }
}

app.use(authMiddleware)
```

中间件执行遵循洋葱模型，通过 `ctx.next()` 传递控制权：

```
Request ──► Logger ──► CORS ──► Auth ──► Handler
                                          │
Response ◄── Logger ◄── CORS ◄── Auth ◄───┘
```

## 项目结构

```text
ignite/
├── src/                 # Ignite 主体源码
├── manual/docs-md/      # 中文正文文档源稿
├── manual/docs-web/     # 后续网站化呈现层
├── manual/samples/      # 可运行样例与首跑路径
├── CHANGELOG.MD         # 中文版本时间线
└── CHANGELOG-en.MD      # 英文版本时间线
```

## 支持平台

| 系统 / 平台 | 架构 / 机型线 | 状态 | 说明 |
|:---|:---|:---:|:---|
| macOS | aarch64 (Apple Silicon) | ✅ | 默认开发主线之一 |
| macOS | x86_64 (Intel) | ✅ | 已覆盖 |
| Linux | x86_64/aarch64 | ✅ | 通用 GNU/Linux |
| EulerOS | Taishan/x86_64 | ✅ | 与通用 Linux |
| Windows | x86_64 | ✅ | 默认 Windows 兼容线 |
| OpenHarmony | aarch64/x86_64 | ✅ | OHOS 公开适配线 |
| HarmonyOS | arm64 | ✅ | 终端 / 设备侧部署线 |
| LoongArch | LoongArch64 | 规划中 | 后续平台扩展预留 |

## Ignite生态

### 叶燧星火

> Trusted by teams that move at the speed of light.

- [`兰鹿`](https://gitcode.com/copur/lanlu) - 基于仓颉语言的漫画归档管理系统
- [`SoonLink/溯联`](https://gitcode.com/cinyu/SoonLink) - 基于仓颉语言的跨端文件管理系统
- [`Ignite-Benchmark`](https://atomgit.com/cinyu/ignite-benchmark) - 面向 `0400/0500` 标准实践的基准仓
- [`easyTODO-core`](https://gitcode.com/cinyu/easyTODO-core) - 纯仓颉 + HTML 的 TODO 后端
- [`igMessanging`](https://atomgit.com/cinyu/igMessanging) - 纯仓颉 + HTML 的聊天室后端

### 叶燧薪柴

> Fueling the engines of innovation.

- [`brotli_middleware`](https://gitcode.com/copur/brotli_middleware) - 面向 Ignite 生态的 Brotli 中间件扩展

更多 `IgniteKit-*` 扩展与 `Cangku / Cangjie-Cangku` 同级基础设施方向仍在内部整理中，当前公开口径仍以已落地能力为准。

## 文档与入口

- [`manual/docs-md/README.md`](manual/docs-md/README.md)：中文正文主入口，适合从首页继续往深处看。
- [`manual/samples/README.md`](manual/samples/README.md)：最快把 Ignite 跑起来的样例矩阵和顺序。
- [`CHANGELOG.MD`](CHANGELOG.MD)：中文版本时间线与阶段收口记录。
- [`CHANGELOG-en.MD`](CHANGELOG-en.MD)：英文版本时间线。
- [`manual/docs-web/README.md`](manual/docs-web/README.md)：后续网站文档的入口预留位。

## 参与后续演进

- 如果你是第一次接触 Ignite，建议先跑 `hello -> api -> swagger -> client` 这条样例路径，再判断它是不是你要的框架。
- 如果你已经在业务里用上了，欢迎把 issue、建议、踩坑和改进点带回来，Ignite 很需要真实反馈来继续长大。
- 如果你准备参与贡献，文档修正、样例回归、公开能力补充和低风险问题收口，都是非常好的入口。

## 许可证

Ignite 基于 [Apache License 2.0](LICENSE) 开源。

---

<p align="center">
  <sub>使用仓颉，点燃无限可能。</sub><br>
  <strong>Built with Cangjie. Ignited by passion.</strong>
</p>
