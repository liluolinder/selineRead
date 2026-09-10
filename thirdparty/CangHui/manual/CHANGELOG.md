# CangHui Changelog

本 changelog 只记录开发者可观察的公开变化。

## Unreleased

## 0.17.0 (2026-08-30)

### 运行时与公开 API

- 新增 `SemanticRuntime`：库存 `ControlSemantics` 可在 `DesktopApp` 正常帧中自动形成有界、
  带窗口身份和 revision 的语义树；公开 snapshot/diff 与 Activate/Focus/Increment/Decrement/
  Dismiss 类型化动作。Voice/Agent 来源默认拒绝，密码值脱敏，且不包含坐标、按键、IPC、
  进程附加、socket 或命令执行入口。
- 新增 `DesktopApplication`、`WindowId` 与 `SdlEventEnvelope`：一个进程级
  SDL event pump 可管理多个独立窗口，并按窗口隔离焦点、浮层、指针捕获和 Scene3D 登记；
  进程级手柄事件只分配给活动窗口。内部 registry 不公开，托管窗口已拥有独立 semantic
  snapshot/diff/action 路由。
  高级 FrameGraph/effect/transition 同等能力仍待后续闭合。
- `Scene3DView` 新增显式 `PreferSharedFrame` 合成模式与 exactly-once lease 合同。当前 SDL
  生产路径可把有界 SDR CPU RGBA8 帧上传到同一 renderer device，并在普通组件树位置遵守
  sibling z-order、祖先 clip 与圆角；原生 private texture/fence、零拷贝和实机 HDR 未声称完成。

### 渲染内部与验证边界

- 阶段感知保留账本记录 build/measure/layout/paint/semantics/hit-test 的精确状态依赖，支持
  事务式提交/回滚与有界 damage；完整指纹一致的 keyed `Label` 可复用已提交测量输出，shape
  裁剪、无自定义 painter 且使用框架可解析材质的 `Surface` 可按实际阴影偏移提供 paint 证明；
  自定义材质 provider 保守升级为完整 damage。FrameGraph 按完整拓扑
  身份复用调度，同时保留逐帧验证、culling 与执行回执；其余普通 Widget 回调仍保守执行。
- SDL provider 统一 staging/preserve 与 binding snapshot cache，但最终仍执行整窗
  `SDL_RenderPresent`，本版本不声称平台 swapchain 已支持 partial present。
- 受保护的图形验证面新增 v2 AOT pipeline pack、能力 generation/ABI/预算校验、将内容意图、
  surface capability 与 provider HDR/EDR 激活回执分离的色彩管线，以及与独立 CPU oracle
  对比的 compute-vector 候选。它们没有从 `chui` 伞包公开，也不代表 GPU provider、实机
  HDR 或 compute 执行已交付。

- `Widget.probe(...)` 的三个无语义 provider 重载现在显式构造
  `None<ProbeSemanticProvider>`，避免消费者同时导入 SDL 等带 `None` 构造器的枚举时，
  clean 或增量依赖构建出现名称解析歧义；CI 新增外部消费碰撞夹具覆盖两种构建路径。
- 新增 provider-neutral 二维 renderer-effect 契约：`BackdropEffectRequest`、能力快照、帧 generation、
  预算与结构化 receipt；首个 `sdl-readback` adapter 在当前帧内有界采样背景并提供第一版柔化/折射，
  超预算、旧帧、无 provider、失败和降低透明度均保留 Liquid Glass 的确定性 fallback。当前原生像素
  证明限于 macOS SDL，shape union 与其他 GPU backend 未声称完成。
- 新增 `KeyedLayoutTransition`：以稳定业务 key 保留上一帧可见矩形，在重排和响应式网格换列时连续补间
  x/y/width/height；父布局、焦点与命中始终采用目标结构，中途重定向从当前可见位置继续。同步提供
  `LayoutTransitionClip`、`LayoutTransitionGeometry`、减少动态效果回归和可由 CUIC 回放的示例。
- `TextArea` 公开 `TextAreaWrapMode.NoWrap`、可绑定横向偏移、横向滚轮/Shift+滚轮和可拖动底部滑块；普通/装饰文本、选区、光标、IME 与命中测试共享同一横向坐标。最宽逻辑行按文档修订与字体度量缓存，editor 示例加入共享纵向滚动的行号 gutter。
- CUIC kMode/probe 启动器识别 CJPM 对空包目录发出的完整普通警告，同时继续拒绝任意
  应用 stdout、截断警告和近似伪装文本，保持帧协议为唯一响应权威。
- macOS SDL 窗口首次关闭现在核对创建时的原生线程；错线程调用在进入任何原生
  销毁前明确失败，已完成关闭继续幂等。`DesktopApp.run` 也不再让清理期错误
  覆盖更早的帧循环异常。
- `Widget.zIndex(Int64)` 为 `ZStack` 提供稳定的绘制与命中顺序：高值后绘制/先命中，
  同值保持声明顺序，不改变布局、焦点遍历与 `Frame` 广播。
- `cuic shell` 新增一次性 debug UI 回放与结构化 `snapshot/diff`；只启动自身构建的
  debug 子进程，事件白名单完成即退出，不连接现有 PID、不开放 listener/pipe/stdin 控制流，
  release cuic 拒绝入口且 release 应用剔除 opt-in/结果协议标记。
- `WindowSpec.cornerRadius` 为透明自绘窗口提供 SDL 原生 window shape，按缩放转换并在
  resize 后重建；系统装饰窗口继续使用平台原生圆角。

## 0.16.1 (2026-08-27)

- 修复 `HStack` / `Row` 中自然弹性控件加精确 `.width(...)` 后仍吞掉剩余空间的主轴分配
  问题；`.height(...)` 在 `VStack` 中对称生效，显式 `Flexible` / `.layoutWeight()` 保持原语义。
- `TextArea` 新增 `TextAreaChrome.Field | None`；只读行号、日志分栏等嵌入式表面可去掉
  默认输入框描边而不丢失滚动、选区和文本绘制。
- `ButtonStyle.quiet()` 提供无边框的通用紧凑命令样式；与 `Row + IconButton` 组合即可构建
  图标优先工具条，不新增用途型容器。
- `TreeView` 长标签按行内剩余宽度安全省略，避免窄侧栏中的内容覆盖或假性折叠。

## 0.16.0 (2026-08-27)

### 新增

- 新增 `chui.graphics` 跨后端适配合同：应用按 `Core3D` / `Compute3D` 等能力档位、
  限额与电源偏好协商 adapter，不把 Metal、Vulkan、D3D11/12、OpenGL ES、WebGPU
  或软件后端写入业务模型；选择结果与 surface generation 以结构化 receipt 返回。
- 新增带上限的保留式资源与 render packet：资源和 render-item 使用 slot + generation
  身份，序列化、解包和事务式 fake replay 会拒绝越界、悬空绑定、旧 generation 与
  半提交状态，为后续各平台 provider 保留稳定输入面。
- `Scene3DView` 成为可布局、可聚焦的普通 CangHui 叶节点；指针会转换到视图局部坐标，
  归一化手柄连接、轴与按键事件只路由给当前焦点所有者。
- 可选 `scene3d-bgfx` 提供 macOS 同窗口嵌入与原生依赖传递；HarmonyOS 侧新增带版本的
  XComponent C ABI 和 `HarmonyXComponentScene3DHost`，把 attach / resize / frame /
  detach 接入同一 Scene3D 宿主 SPI。

### 修复与验证

- macOS `cuic prnt` 把捕获子进程约束为一个仓颉调度处理器，并在 SDL 入口核对原生线程
  身份，避免等待捕获子进程时把 SDL event loop 迁移到错误线程。
- 新增源码归属包矩阵：全量门会构建并测试 `bench/`、`examples/`、`packages/` 与
  release fixture 中所有正向 `chui` 消费者；原生 Scene3D 输入缺失会留下明确 gap，
  涉及原生 3D 的改动可把该 gap 提升为硬失败。
- CUIC 安装烟测不再只比较版本号：临时安装后的命令必须识别并构建仓库外的
  `[dependencies].chui` 消费者；共享安装版也可通过同一门禁核验。
- 本地源码安装的 provenance 只按实际复制的 `tools/cuic` 子树判定 `+dirty`，不再让
  框架其他目录中的无关工作树状态污染 CUIC 版本身份。

### 仍未声称

- 图形合同和 render packet 不是所列全部后端的完整驱动实现。当前真实像素证明仍集中在
  macOS arm64 Metal；Windows、Linux、Android 与 HarmonyOS provider 像素、实体手柄映射、
  发布者签名、商店发布、生产与 LTS 仍需各自回执。
- HarmonyOS 公共入口不包含 ArkTS/HAP 产品宿主，macOS 同机原生包也不是跨平台
  预编译二进制 SDK。应用的模型、材质、拾取、导航与输入策略继续由消费者拥有。

## 0.15.0 (2026-08-25)

### 新增

- 新增 ArkTS 风格 `Row` 通用水平容器与 `Widget.layoutWeight`：`space`、
  `justifyContent`、`alignItems` 和弹性子项直接复用既有 Stack 引擎；三段信息行通过普通
  padding、最小高度与中间子项权重组合，不再发布目的过窄的专用控件。
- 新增 `canghui-agent-ui` 公开 skill，把框架消费边界、三槽对齐、按钮本征高度、稳定图标、
  窄侧栏换行与亮/暗主题评审变成可直接复用的 Agent 工作流。
- 新增 SDK 式消费快速入口：应用使用锁定 `commitId`、`cjpm.lock` 与 CJPM 用户缓存直接
  `import chui.*`，无需在应用旁保留或修改完整 CangHui checkout。

### 修复与集成

- `Button` 与 `IconButton` 默认不再继承高 `HStack` 的纵向拉伸，避免普通按钮被协同生成代码
  意外撑成整行色块；显式 `.height(...)`/`.fillHeight()` 仍可有意覆盖。
- 基于 CorePlayer、ExplorerX 与 PiHub(CHUI) 的只读消费者审计，吸收了稳定三槽信息行、
  本征控制高度、窄侧栏 FlowRow、块级文本节奏和单状态主题等通用方法；播放、文件传输、
  Pi/DSH、产品导航与平台桥仍由消费者拥有，框架未复制其业务代码。
- 原 `docs/api`、`docs/guide` 与主题文档统一迁入 `manual/`，并彻底移除旧 `docs/` 入口。
  内部工程治理账本不再作为公开能力/组件矩阵随框架分发；公开审计会阻止旧目录和治理矩阵
  重新进入分发面。
- cuic 提升到 `0.6.0`。手册明确 `doctor → pview/probe ascii → prnt → 平台截图` 的
  分层证据顺序，并保留发布构建拒绝 probe/pview 特权执行的安全门。
- cuic 构建现在以消费者 manifest/lock 对应的 CangHui 根为准，并把隔离缓存中的 SDL3 同时加入
  编译期 `LIBRARY_PATH` 与运行期动态库路径；Git 源码依赖不再被 cuic 自身的开发 checkout
  遮蔽，也不要求把原生库写回 CJPM 源码缓存。Doctor 使用同一暂存根，并在缓存尚未生成时检查
  可自动供给它的 Homebrew provider，不再把可构建的全新消费者误报为硬阻塞。

### 仍未声称

- 当前“SDK 式”路径是受锁定和缓存管理的 Git 源码依赖，不是跨目标预编译二进制 SDK。
  后续二进制包仍需固定 Cangjie ABI/工具链、目标模块、native 运行时闭包、校验值、许可和发布者证据。
- 三个消费者只提供需求与方法证据；其产品视觉、平台宿主、设备行为和发布状态不随本版本成为
  CangHui 框架证明。

## 0.14.0 (2026-08-24)

### 安全与发布

- kMode 改为编译调试态专属能力：发布应用会忽略旧环境变量与 argv opt-in，
  `KModePolicy(enabled: true)` 在发布态强制失效，channel override 与 stdio host
  同样 fail closed。
- cuic `0.5.0` 将 `kmode` / `probe` 执行、`pview`、`debug` 与设备捕获收进
  `-g` 构建门；发布 cuic 只保留 `kmode diff` / `probe diff` 静态检查。
- 新增源码网络/控制面审计与发布/调试 fixture 双态回放，防止用单一绿测推断
  release 没有特权入口。
- 新增 macOS candidate/publisher 审计和可选 Developer ID + Hardened Runtime +
  安全时间戳 + Keychain-profile 公证流程；危险 entitlement、开发机绝对路径、
  过大应用符号表、不安全依赖/rpath 与无效公证票据会被拒绝。
- `cuic package build` receipt 现在明确列出 trim/strip、release security audit 与
  publisher signing/notarization 尚未验证，避免把无签名输入包宣传成上架包。
- Windows 构建不再拼接 `cmd.exe` 命令字符串；`cjpm`、参数和环境通过进程 API
  分离传递，`&|%` 等元字符保持字面量。`doctor --verbose` 会保守遮盖绝对路径、
  凭据 URL、secret/key/token/cookie 形态与本机身份值。

### 文档与方法

- 新增中英文安全/发布来源手册，并把源码网络审计、双态控制面回放与 macOS
  发布者证据链接入仓库全量构建 skill。
- 修正中文公开面的 Scene3D 能力说明为八类 provider-neutral 语义投影；
  CangHui Multiplatform / `chui` 是主推广身份，消费者只作为独立验收证据。

### 仍未声称

- 代码签名不能让第三方 fork 无法反编译或二次修改；它让真实发布者产物的替换与
  注入可识别。App Store Connect 提交、审核、实际发布、生产与 LTS 仍需外部回执。

## 0.13.0 (2026-08-24)

### 新增

- `chui.scene3d` 在既有 `Floor`、`Route`、`Vehicle` 与 `UserMarker` 基础上新增
  `Structure`、`Track`、`Facility` 与 `ExitMarker`，并让封闭帧快照可携带通用实体
  尺寸、旋转和 provider-neutral `Scene3DCameraSnapshot`；旧构造保持默认兼容。
- 可选 `packages/scene3d-bgfx` provider 为八种语义类型维护独立资源，并在提交时
  消费帧相机和实体 SRT 变换。

### 修复与集成

- Scene3D Metal 原生门禁加入非默认相机、缩放与旋转实帧，避免只以核心单测推断
  可选驱动已经消费公开字段。
- 公开 manual 与全量构建 skill 修正 PineEase 0.2.0 证据边界：旧证据不证明会话同步、
  产品级视觉或商店上架就绪；产品级 3D 仍需消费者当前会话、制品启动与视觉复核。

### 仍未声称

- 语义调试几何不是产品网格、数字孪生、材质/模型导入、拾取或嵌入式 Scene3D
  视图；其他宿主运行时、发布者签名、公证、商店发布、生产与 LTS 仍需独立证明。

## 0.12.0 (2026-08-24)

### 新增

- `chui.scene3d` 新增带稳定实体类型的 provider-neutral 封闭快照：`Floor`、
  `Route`、`Vehicle` 与 `UserMarker` 可投影为 slab、ribbon、box 与 marker
  四类有界调试几何，同时保留实体身份、位置与可见性。
- 可选 `packages/scene3d-bgfx` provider 增加语义顶点资源、Metal 实帧捕获与
  外部原生归档供应门禁；普通 `chui` 构建不会下载或链接 bgfx 原生库。

### 修复与集成

- macOS SDL/Metal 预览宿主会消费 quit event 并公开只读 `shouldClose()`，使正常
  预览可在关闭请求后 detach；确定性截图模式仍保持有界退出。
- `cuic package build macos` 把生成 receipt 放在
  `Contents/Resources/canghui-packaging-receipt.json`，避免 `.app` 根目录的未封装内容
  破坏严格代码签名校验；Windows/Linux receipt 路径不变。
- PineEase 0.2.0 作为外部消费者证明了产品语义映射、Canvas 2.5D fallback、
  macOS arm64 Metal 伴随预览、SDL 退出/detach 与同宿主上架候选包。消费者证明不
  扩大框架自身的跨平台或产品模型声明。
- 全量构建 skill 新增条件式 Scene3D 原生门禁，明确区分通用 provider 捕获与产品
  消费者证明。

### 仍未声称

- 语义调试几何不是产品网格、数字孪生、材质/模型导入、拾取或嵌入式 Scene3D
  视图；其他宿主运行时、发布者签名、公证、商店发布、生产与 LTS 仍需独立证明。

## 0.11.0 (2026-08-23)

### 新增

- 正式统一 **CangHui（仓绘）**、**CangHui Multiplatform** 与根包 `chui`；
  `cui.probe.v0`、`CUI_*`、`cuic`、`--cui-path` 等既有兼容标识保持不变。
- 新增类型化应用身份、普通/安全设置 provider、应用菜单、状态项、通知权限与
  deep-link 路由契约。
- 新增 macOS 无签名 `.app` 生成，以及 Windows/Linux 的确定性打包输入树与 receipt；
  签名、安装、商店发布和跨宿主运行仍是独立门禁。
- 新增 iOS、Android、HarmonyOS 的平台中立 host/package receipt 与移动生命周期、
  安全区、触摸、文件选择、存储、主题、通知和后台任务契约；这些 receipt 不代表
  完整产品宿主已经随框架交付。
- 新增装饰性 `Surface`、单动作所有者 `InteractionSurface`、组件级样式/语义与
  嵌套交互所有者的确定性诊断。
- 新增容器排版环境；`Label`、`RichText` 与 `RichSpan` 可逐字段继承字族、字号、
  粗体、斜体、下划线和删除线，并允许显式清除继承样式。
- `TextField` 增加 placeholder 契约；`RichText` 增加对齐与行距能力。

### 修复与集成

- 应用打包会递归拒绝已声明资源树中的符号链接，避免嵌套链接把工程外文件带入产物。
- 公开 manual、参考链接、版本镜像与仓库内构建 skill 纳入同一审计门禁；SDL 测试在
  release CI 中不再被降级为非阻断警告。
- `.bold()` 使用真实字体变体解析；找不到真实粗体时才保留兼容回退。容器字体设置会
  同时影响测量、布局、绘制、输入几何与延迟浮层。

### 仍未声称

- 本版本不声称 HarmonyOS 产品宿主、任意路径 Surface、Liquid Glass、平台 blur、
  原生无障碍适配、签名/商店发布或 Windows/Linux 真实宿主运行已经完成。

## 0.10.0 (2026-08-15)

### 新增

- **cuic `pview`**：把当前 CangHui 布局输出为确定性 ASCII 图（`probe ascii` 保留为别名）。
- **cuic `prnt --device/--app`**：设备界面获取命令面；当前为系统截屏 fallback，
  渲染面穿透通道待 Harmony 侧实现。
- **cuic `debug`**：显式调试渠道命令面（生产构建保持默认）。
- **cuic `device list [--json]`**：列出 hdc 设备。
- **`WindowSpec(frameless: true)`**：桌面无边框窗口（等价 `decorated: false`）。
- **`ExternalFramePlane`**：平台无关外部帧平面接口。
- **`PointerInputBridge` / `BoundedMailbox<T>`**：线程安全输入桥与有界队列。

### 变更

- 版本线 `0.9.2 -> 0.10.0`。
- 桌面 `cuic prnt` 不再依赖 `cjpm run` 参数转发（使用 `DesktopCaptureRequest`）。

### 修复 / 内部

- sdl 归属记录（`UPSTREAM`/`LICENSE`/`NOTICE`）与 Windows DLL SHA-256。
- 已闭环特性合入 main（真实桌面捕获、无头 ASCII、设备截图、调试命令面等）。

### 待办（公开）

- Harmony 渲染面穿透 capture service。
- Harmony onTouch -> PointerInputBridge 薄适配（OHOS 构建验证）。
- CangHui CI 门禁。
