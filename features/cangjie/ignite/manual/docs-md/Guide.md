# Guide

## Ignite 是什么

Ignite 是一个用仓颉语言实现的 Web 框架。

它的目标不是把官方底层能力替换掉，而是在真实服务落地时，把大家反复要做的路由组织、中间件拼装、错误收口、Swagger、自检、静态托管、客户端联调这些事情收进一套更顺手的默认路径。

如果你喜欢 Go Fiber、Express 这类“上手快、心智轻”的框架体验，但又希望在仓颉里少写一层层样板，Ignite 会比较对味。

## 为什么选择 Ignite

Ignite 当前最有价值的地方，不是喊一个“超大而全”的口号，而是把几件真会天天用到的事情先做好：

- 首个接口可以很快跑通，`App / Router / Ctx` 认知成本低。
- 中间件、安全、审计、Swagger、自检这些常见能力不需要每个项目从零拼一次。
- 服务端和客户端可以在同一套公开语义下协作，减少“服务端一套、调用端再造一套”的割裂感。
- 平台口径、TLS 边界、压缩支持范围这些地方，文档尽量写直，不让你靠猜。

## 适合什么项目

Ignite 当前适合这些场景：

- REST API、后台服务、运维接口、内部平台
- 需要把路由、中间件、Swagger、静态资源、SSE、WebSocket 放在同一仓库里管理
- 希望把日志、审计、安全头、鉴权、请求 ID、错误收口作为默认工程能力的人
- 希望服务端和客户端在同一仓里协作，而不是分别造轮子的人

如果你只是想做一个最小实验，也能从 Ignite 起步；如果你准备把服务继续往生产推进，Ignite 目前已经能提供更完整的公开治理面。

## 比 `stdx.httpServer` 方便在哪

`stdx.httpServer` 是可靠的底层能力，但业务项目通常还要自己再补：

- 路由组织与前缀分组
- 中间件链与统一错误处理
- 安全头、鉴权、日志、审计、限流
- Swagger / OpenAPI、静态托管、SSE / WebSocket
- 首跑样例、进程内测试、客户端封装

Ignite 的价值不在于否定底层，而在于帮你把这些“每个服务都要再来一遍”的工程活，整理成更省心的默认路径。

## 环境要求

- `cangjie-sdk v1.1.0+`
- 与当前仓库兼容的 `cangjie-stdx` 运行时
- 从仓库根目录执行样例时，确保能找到 `cjpm.toml`

如果你只是先验证样例，建议先在框架仓内首跑；如果你已经在自己的业务仓里接入 Ignite，再改为从业务项目的可执行入口运行，会更顺。

## 依赖接入

### Git 依赖

如果你想先跟随主仓节奏接入，在业务仓的 `cjpm.toml` 中加入：

```toml
[dependencies]
Ignite = { git = "https://gitcode.com/cinyu/ignite-cangjie" }
```

### 中心仓

如果你走中心仓，请参考仓内的 [`../../cangjie-repo.toml.example`](../../cangjie-repo.toml.example) 配置本地 `cangjie-repo.toml`。

需要认证或私有源时，记得把认证配置留在本地，不要把 `cangjie-repo.toml` 一起提交到业务仓。

## Hello, Ignite!

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

如果你当前就在 Ignite 仓库根目录，最稳的首跑方式是：

```bash
cjpm build
./manual/samples/hello/run.sh
curl -i http://127.0.0.1:18808/health
```

## 首次运行建议顺序

建议按这条顺序理解公开能力，而不是一上来就看最长的文档：

1. [`manual/samples/hello`](../samples/hello/README.md)
   看最小服务、路由和健康检查是否能跑通。
2. [`manual/samples/api`](../samples/api/README.md)
   看参数、JSON、CRUD 组织方式。
3. [`manual/samples/swagger`](../samples/swagger/README.md)
   看 Swagger、`InterfaceSpec`、`TestOption` 与 `kmode` 的协作方式。
4. [`manual/samples/client`](../samples/client/README.md)
   看内置 `RestClient`、加密 JSON、multipart 与 observe headers。

如果你已经确认 Ignite 的味道和能力面基本对路，再继续读本目录下的 `api / middleware / client / advanced` 四页，会更顺。

## 常见失败与一行修复

- 找不到 `stdx` 静态库
  处理：设置 `IGNITE_STDX_STATIC=/path/to/cj_stdx_*_llvm/static`
- 运行时库路径缺失
  处理：设置 `IGNITE_CJ_RUNTIME_LIB_DIR=/path/to/cangjie/runtime/lib/<platform>`
- 样例脚本在错误目录执行
  处理：回到包含 `cjpm.toml` 的仓库根目录，再执行 `./manual/samples/.../run.sh`
- TLS 首跑排障困难
  处理：先保留 `enableTlsPrecheck: true`，用结构化错误定位问题；当前主线会通过 raw PEM/DER `PrivateKey` wrapper 避开已知 key-load crash family，仅在应急排障时临时回退为 `false`
- Swagger 启动行没显示
  处理：确认 `enableSwagger = true`，再检查 `enablePrintSwaggerUrl` 是否被关闭

如果问题仍未收敛，建议先执行：

```bash
cjpm test
```

这样通常能更快区分问题属于依赖、运行时、样例路径还是代码本身。

## 推荐阅读路径

- 想理解核心对象：继续看 [`api.md`](api.md)
- 想先看治理与安全：继续看 [`middleware.md`](middleware.md)
- 想做内置客户端联调：继续看 [`client.md`](client.md)
- 想看 WebSocket、SSE、Swagger、TLS 与静态托管：继续看 [`advanced.md`](advanced.md)
