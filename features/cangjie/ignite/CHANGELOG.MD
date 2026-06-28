# Ignite Changelog

## Ignite `0700`
> 资产压缩、协同治理、H1/H2 truth 收口

### v0.7.2 `Ignite Now`
> client full consumer surface 官包版

- `+特性` client full consumer story 现在形成一条完整公开路径：`manual/samples/client/**` 可从 setup / quick GET / JSON POST / builder path / hooks / body access / retained recovery / retry override 一路走到 encrypted request 与 cleanup
- `+特性` `Ctx.jsonEncodeStream(obj, contentLength?)` 现在作为 `JsonEncodable` family 的显式流式 twin 进入公开面；`ctx.jsonEncode(...)` 继续保持 full-buffer，并继续只在 full-buffer 路径使用 `Config.jsonEncoder`
- `+测试` `ClientHookTestSuite`、`ClientRetryTestSuite`、`ClientStreamingTestSuite` 与 `ClientResponseRecoveryAcceptanceTestSuite` 继续补齐 focused regressions，并通过当前 accepted serial lane 的 full `294/294`
- `+测试` `JsonEncodeStreamCtxSugarTestSuite`、`JsonEncodeStreamMiddlewareCompatTestSuite` 与 `CompressMiddlewareTestSuite` 已覆盖 `jsonEncodeStream(...)` 的 known-length / unknown-length / HEAD、当前 middleware 边界与 real-HTTP streamed-compress subset
- `+测试` 新增 `ClientHostnameSensitiveTlsProofTestSuite` 作为 runtime-owned hostname/SNI blocker-anchor suite，继续诚实保留 `not currently proven`
- `=文档` `README` 多语言、client sample README、`manual/docs-md/client.md`、`manual/docs-md/api.md` 与 source-local guidance 统一到最新 client / JSON response 口径
- `=杂项` 包版本、框架版本常量与 banner render version fixtures 同步到 `0.7.2`

### v0.7.1 `Ignite Now`
> client retained recovery reset 与 failure-path freshness 刷新版

- `+特性` `RestClient` 新增 `clearRecoverySnapshots()`，允许长生命周期 client 在下一轮 probe / retry / 诊断前显式清空 retained client-side recovery
- `+特性` 当前 `client` recovery 公开面现在明确分成两层：response-side `observeSnapshot()/transportTouchpoint()` 回放，以及 client-side `lastClientObserveSnapshot()/lastClientTransportTouchpoint()` retained 留痕
- `+测试` `ClientResponseRecoveryAcceptanceTestSuite` 新增 reset + fresh failure-path acceptance，证明清空旧状态后，新的 experimental failure 仍能回收当前轮的 observe / touchpoint
- `=文档` README、多语言 README、client sample 与 `manual/docs-md/api.md` 回归到 retained recovery / reset 的最新公开口径
- `=杂项` 包版本、框架版本常量与 banner render version fixtures 同步到 `0.7.1`

### v0.7.0 `Ignite Now`
> `0700` 公开基线版

- `=文档` 将当前公开版本基线从 `0.6.41` 提升到 `0.7.0`
- `=文档` README / README-en / README-ru 的版本展示、状态说明与当前 `H1 ready-now / H2 guarded intake` 口径重新对齐
- `=文档` `manual/docs-md/README.md` 与 `manual/samples/README.md` 回归到当前 `0700` 公开入口，补齐 `H1/H2` 首读路径
- `+特性` 当前 line 已明确把 `transport` accepted-answer proof 与 `client` public recovery proof 收成更易 handoff 的 intake-facing truth
- `+特性` 自研 `server-socket` 已形成更长的 parser/session/body/writer/runtime-experiment proof ladder，但当前仍保持 experiment/runway 口径，不冒充 default public engine
- `=杂项` 包版本与框架版本常量同步到 `0.7.0`

## Ignite `0600`
> 传输解耦起步、观测留痕加固

### v0.6.41 `Ignite Now`
> 路由扩展面收口刷新

- `=修复` router 现在允许 `"/*"` 在根路径 `"/"` 上命中，同时保持显式 `"/"` 路由优先于 catch-all
- `+特性` `App` / `Group` 的 `get/post/put/delete/patch/head/options/all` 现在都支持 `Array<Handler>` 公开写法，减少 route-level middleware 只能靠包装函数嵌套的表达负担
- `+特性` `App` 新增 `notFound(...)` 与 `methodNotAllowed(...)` hook，仍保留全局 middleware 链、`Allow` 头与 `OPTIONS` 语义
- `+特性` `Ctx` 新增 `setLocalValue(...)` / `getLocalValue<T>(...)`，让 typed request locals 可以和原有字符串 locals 并存
- `=文档` 同步 `manual/docs-md/api.md`、README 多语言说明、目标航线表述与版本常量到 `0.6.41`

### v0.6.1 `Ignite Now`
> `0600` 首个工作基线版

- `=文档` 将当前活跃版本基线从 `0.5.31` 提升到 `0.6.1`，标记 `0600` 迭代线开始
- `+特性` Client 新增结构化 observe 快照，可通过 `onObserve(...)` 获取成功 / 失败观测结果，并支持 `JSON / log line` 双输出
- `+特性` Client 补齐 transport touchpoint 留痕，请求结束后可读取最近一次 transport 选择与 observe 快照
- `+特性` Server 启动观察链继续加固，启动失败分类、transport touchpoint 与 observe snapshot 现在更容易形成连续诊断面
- `=修复` transport 错误模型补入 TLS handshake fallback candidate 的内部判定语义，但当前公开 HTTPS 默认路径与 fallback 承诺不变
- `=文档` README / README-en / README-ru / Swagger sample / 版本常量同步到 `0.6.1`

## Ignite `0500`
> 可用、可信、快上手

### v0.5.68 `bugFix`
> `0500` bugfix 收口与 client / swagger 观测修正版

- `=修复` `HTTP/2` 流式响应不再继续带出 `HTTP/1.1` 专属流式头，避免 `transfer-encoding` / `connection` 语义污染 `h2`
- `=修复` `RestClient` 观测错误补齐 `phase / causeCode / retryable`，并阻止 `TLS` / `CRYPTO` 错误被错误重试
- `=修复` `RequestBuilder` 退避等待从忙等改为 `sleep`，减少无意义 CPU 空转
- `=修复` Swagger JSON 输出对 `title / description / version` 做统一 JSON 转义，补齐控制字符回归
- `+测试` 新增 client timeout / TLS transport、response hook observe header 与 Swagger / JSON 转义回归覆盖
- `=文档` 根 README 与 manual 入口正文收口，补齐 `docs-md` 主入口与公开文档分流说明
- `=杂项` 包版本、框架版本常量、Swagger sample 与自检测试版本统一到 `0.5.68`

### v0.5.31 `Ignite Now`
> 平台矩阵细化与 README 首屏收口版

- `=文档` 将当前公开版本基线从 `0.5.27` 提升到 `0.5.31`
- `=文档` README / README-en / README-ru 的版本展示、Banner 预览宽度与当前运行时输出重新对齐
- `=文档` 支持平台矩阵细化，单列 `OpenHarmony x86_64`、`EulerOS Taishan/x86_64`、`HarmonyOS arm64`，并为 `LoongArch64` 预留位置
- `=文档` manual / Swagger sample / 自检测试中的当前版本显示同步到 `0.5.31`
- `=杂项` 包版本与框架版本常量同步到 `0.5.31`

### v0.5.27 `Ignite Now`
> 本地 release 预备版

- `=文档` 将当前公开版本基线从 `0.5.25` 提升到 `0.5.27`
- `=文档` README / README-en / README-ru 的当前版本展示同步到 `0.5.27`
- `+特性` `0500` 默认 Banner 收口到新经典样式：顶部三段式、`Touchpoints` 显示词、右下角小签名 `_Ignite <framework-version>`
- `+特性` 新增 `Config.enablePrintSwaggerUrl`，允许 Swagger 路由存在但不打印启动 `Swagger UI: ...` 行
- `=文档` README / README-en / README-ru / manual / Swagger sample 同步补齐 Banner、Swagger 显示开关与路径说明
- `=文档` 澄清当前 HTTPS 默认路径仍以 `stdx` TLS 或反向代理 TLS 终结为准，`jinguissl` 不作为默认监听链替代承诺
- `=杂项` 包版本、Swagger 示例元数据与相关测试版本同步到 `0.5.27`
- `=杂项` 为本地 `v0.5.27` tag 做准备，本次不推送远端

### v0.5.25
> `0500` 公开收口与多语言同步版

- `=文档` 将当前公开版本基线同步到 `0.5.25`
- `=文档` README / README-en / README-ru 对齐当前仓库布局、依赖写法与公开入口
- `=文档` 明确 `manual/` 为公开文档入口，继续收束公开入口与目录视图
- `=文档` 首跑说明继续以可验证路径为准，不把当前仓库包装成可直接 `cjpm run` 的可执行项目
- `=杂项` 包版本、Swagger 示例元数据与相关测试版本同步到 `0.5.25`

### v0.5.21 `Git`
作为`0500`版本组，目前基线版本`0.5.21`已完成:
- `+特性` Server / Client 双线能力面进一步拉齐，减少“服务端一套、客户端再重造一套”的割裂感
- `+特性` 压缩中间件补齐：`compressMiddleware`、`CompressConfig`、`Accept-Encoding` 协商、`gzip/deflate`、最小压缩阈值、`skipIfNoGain`
- `+特性` JWT 中间件进入主线：`JwtConfig`、`jwtMiddleware`、claims 注入、标准 `WWW-Authenticate` 返回
- `+特性` 新增 `bindJsonOr400`，统一 `invalid_json` / `invalid_payload` / `validation_failed` 的请求绑定错误语义
- `+特性` 新增 `handleForTest` 与 `AppTestResponse`，支持无需手动 `listen` 的服务链路断言
- `+特性` 新增 `nameRoute` / `urlFor`，并支持 `RouteOption.operationId` 直接作为路由名
- `+特性` 新增 `IgniteKit`，用于轻量 HTML / CSS / 动态页面资源映射
- `+特性` 新增自检API模块最小闭环：`RequestBodySpec`、`TestOption`、`InterfaceSpec`、`App.interfaceSpecs()`
- `+特性` Swagger 语义增强：支持 requestBody、response example、`x-ignite-test` 扩展信息
- `+特性` kmode 下支持最小 mock / probe 自检响应，可通过 `x-ignite-test` / `__ignite_test` 触发，并附带 `IGTEST-0500` 标记
- `+特性` 样例矩阵继续补齐：`hello`、`api`、`ignitekit`、`dualport`、`swagger`、`files`、`middleware`
- `=修复` TLS 路径继续收口：`enableTlsPrecheck`、jinkuiSSL precheck 与 stdx TLS 构造 / 回退路径并存
- `=修复` 文件下载与 Range 场景补齐流式发送、`HEAD` 语义与大文件回归
- `=文档` README、样例、Freeze、Benchmark、Release Report 与当前实现对齐
- `=杂项` release guard、sample compile guard、`cjlint` baseline、server/client API freeze 全链打通

### v0.5.01
> `0500` 版本组早期占位版本，不展开，只保留编号痕迹。

- `=杂项` 进行一个安卓 APP 占位的行为
- `=杂项` 作为 `0500` 阶段的早期编号预留版本存在

---

## Ignite `0400`
> 安全治理集成、面向生产级步进

### v0.4.71
> `0400` 工作区收口刷新版

- `=文档` `cjpm.toml`、README / README-en / README-ru 当前版本展示同步到 `0.4.71`
- `=文档` 支持平台矩阵细化，补回 `OpenHarmony x86_64` 与 `EulerOS Taishan/x86_64`
- `=文档` 英文 / 俄文 README 补齐 Swagger `enablePrintSwaggerUrl` 与路径语义说明

### v0.4.67 `Git` `CangjiePkg`
> 理论 `0400` 阶段最后一版

- `=修复` `api2` / 本机 IP 检测问题
- `=杂项` 继续为 `0500` 的可信发布与主线收口做过渡


### v0.4.57 `Git` `CangjiePkg`
> 网络事件监听

- `+特性` IP 变动监听，支持网卡地址变化事件

### v0.4.47 `Git` `CangjiePkg`
> 编译时版本宏、网络 IP 排序与 Windows 编码修复

- `+特性` 编译时从 `cjpm.toml` 读取框架版本
- `+特性` `getNetworkInfo().ips` 排序，用于启动横幅显示
- `+特性` 静态 SPA 支持：`staticSpa(prefix, root, indexFile)`
- `+特性` `api2.getPreferredLocalIP()` 辅助函数
- `=修复` Windows 下 `ipconfig` 输出 UTF-8 解码问题，避免崩溃
- `=文档` 新增俄文 README；同步英文 README（标语、环境、依赖、架构图）
- `=杂项` Windows / Linux 编译与链接选项继续优化

### v0.4.41 `Git` `CangjiePkg`
> kmode 与日志接口抽象

- `+特性` `Config.kmode` 与 `kmodeMiddleware`
- `+特性` `Logger` 接口及 `DefaultLogger` 实现，支持 `enableEntityLog`
- `+特性` 从 `cjpm.toml` 通过脚本读取框架版本
- `=修复` Windows 环境下 `getPreferredLocalIP` 跳过，避免端口占用误报
- `=文档` README 同步更新

### v0.4.27 `Git` `CangjiePkg`
> 配置与横幅系统优化

- `+特性` `Config.appVersion`，支持自定义应用版本并用于横幅标题
- `+特性` `Config.enablePrintRoutes` 开关细化
- `=修复` 启动横幅健壮性增强
- `=文档` README / CHANGELOG 同步
- `=杂项` 版本号升至 `0.4.27`

### v0.4.07 `Git` `CangjiePkg`
> 文档同步与基础特性补充

- `+特性` Swagger UI 缓存控制
- `+特性` JSON Helper 与编码辅助能力
- `+特性` 文件下载与 Range 请求支持
- `=文档` 添加项目链接与基础文档同步
- `=杂项` 版本号更新至 `0.4.07`

---

## Ignite `0300`
> 服务成套、能力成形、体验拉齐

### 核心特性

- `+特性` **中间件全家桶**  
  `AccessLog`, `Favicon`, `HealthCheck`, `StaticFile`, `Proxy`,  
  `RequestID`, `RateLimit`, `Idempotency`, `Redirect`, `Rewrite`,  
  `ETag`, `Cache`, `BodyLimit`, `Timeout`,  
  `EncryptCookie`, `Session`,  
  `Security Headers + CSRF`,  
  `Basic Auth`, `Key Auth`  
  以及共享工具库（base64, HMAC, 随机字符串）

- `+特性` **路由引擎升级**  
  严格路由冲突检测、`removeRoute`、参数校验、路径归一化  
  修复连续斜杠（consecutive paths）问题（完整版）

- `+特性` **上下文增强**  
  `bodyBytes` 缓存、响应体缓存  
  multipart 表单完整 API（含文件上传 `FormFile`, `MultipartForm`）  
  `Ctx.query()` 支持回退到 form 参数，新增 `queryFromUrl()` / `queryFromForm()`

- `+特性` **TLS 与 Swagger**  
  支持 TLS、可配置的 Swagger UI 静态资源  
  HTTP 客户端增强：multipart / 表单编码

- `+特性` **API2 基础能力**  
  跨平台 `getNetworkInfo()`，用于 `0.0.0.0` 启动时横幅显示

- `+特性` **流式传输与 WebSocket**  
  core 层继续加固 Streaming / WebSocket 能力

- `+特性` **开发者体验**  
  彩色终端输出完善、完整 MIME 类型支持

- `=文档` 更新 README（中间件列表与用法）
- `=杂项` 添加 `cjlintignore.cfg`，修正包版本元数据

## Ignite `0200`
> 蓝图内定，开始拓影

- `=修复` 请求上下文（`ctx`）处理逻辑调整
- `=修复` 路由连续斜杠（consecutive paths）问题的基础处理
- `=杂项` 后续代码清理（follow-up cleanup）
- `=杂项` 准备初始发布资源（`prepare initial publish assets`）
- `=杂项` MIME 类型完善与彩色输出细节优化

## Ignite `0100`
> 仓颉胃，Express味

- 实验性项目，本地构建孵化
- `+特性` 基础 core 层：流式传输（Streaming）、WebSocket 基础支持、HTTP 客户端基础能力
- `+特性` 彩色终端输出
- `+特性` MIME 类型基础兼容
- `+特性` 最简单的请求响应处理（基于 `httpServerKit` 引导）
- `=杂项` 初始提交（`Initial commit`）
- `=杂项` 项目结构初始化、`.gitignore` 优化

# 说明
- `+特性` / `=修复` / `=文档` / `=杂项` 用于后续可视化标识
- `Git` `CangjiePkg` 表示该版本已同步 Git 与仓颉中心仓
- 未标记 `Git` `CangjiePkg` 的版本，表示未以“双同步完成”作为该版本状态结论
- `0100`~`0300`仅保留阶段摘要，不再继续细拆子版本
