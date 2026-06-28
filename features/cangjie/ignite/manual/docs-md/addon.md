# Addon

## 项目结构

如果你想快速理解 Ignite 主仓公开布局，可以先按下面这张图看：

```text
ignite/
├── src/
│   ├── app.cj            # App 生命周期、路由注册、服务启停
│   ├── config.cj         # Config 配置对象
│   ├── ctx.cj            # 请求上下文与响应能力
│   ├── router.cj         # 路由匹配与组织
│   ├── swagger.cj        # OpenAPI / Swagger 输出
│   ├── ignitekit.cj      # IgniteKit 轻量资源映射
│   ├── middleware/       # 安全、治理、压缩、缓存、代理等中间件
│   ├── governance/       # audit、kmode、日志等级、脱敏等治理模块
│   └── client/           # RestClient、RequestBuilder、ClientResponse、CookieStore
├── manual/docs-md/       # 中文正文文档源稿
├── manual/docs-web/      # 网站文档呈现层占位
├── manual/samples/       # 可运行样例
├── CHANGELOG.MD          # 中文版本时间线
└── CHANGELOG-en.MD       # 英文版本时间线
```

## 支持平台矩阵

当前公开支持矩阵如下：

| 系统 / 平台 | 架构 / 机型线 | 状态 | 说明 |
|:---|:---|:---:|:---|
| macOS | aarch64 (Apple Silicon) | ✅ | 默认开发主线之一 |
| macOS | x86_64 (Intel) | ✅ | 已覆盖 |
| Linux | x86_64 | ✅ | 通用 GNU/Linux |
| Linux | aarch64 | ✅ | 通用 GNU/Linux |
| EulerOS | Taishan | ✅ | 与通用 Linux ARM 线分开记录 |
| EulerOS | x86_64 | ✅ | 发行版环境单列 |
| Windows | x86_64 | ✅ | 默认 Windows 兼容线 |
| OpenHarmony | aarch64 | ✅ | OHOS 公开适配线 |
| OpenHarmony | x86_64 | ✅ | 已通过认证 |
| HarmonyOS | arm64 | ✅ | 终端 / 设备侧部署线 |
| LoongArch | LoongArch64 | 规划中 | 后续平台扩展预留 |

这里展示的是当前已经明确公开的支持面，后续平台扩展会继续往这里补。

## 文档入口说明

当前公开文档层次建议按这个顺序理解：

1. 根 [`../../README.md`](../../README.md)
2. [`README.md`](README.md)
3. [`../samples/README.md`](../samples/README.md)
4. [`../../CHANGELOG.MD`](../../CHANGELOG.MD)

各自职责是：

- 根 README：门面与方向
- 根 README 里的 `Ignite 生态`：项目故事、公开展示与外部认知入口
- `docs-md`：正文与能力解释
- `samples`：可运行路径
- `CHANGELOG`：版本时间线

## 后续演进与参与方式

如果你准备参与 Ignite 的后续演进，当前公开建议是：

- 优先从文档、样例、公开回归与低风险能力补充开始
- 修改前先确认是公开能力、内部规划，还是历史归档内容
- 对公开文档保持节制，但也要让它好读、好懂、有辨识度

如果你是第一次参与，根 README + `Guide.md` + `manual/samples/README.md` 这三处通常足够你建立稳定上下文。
