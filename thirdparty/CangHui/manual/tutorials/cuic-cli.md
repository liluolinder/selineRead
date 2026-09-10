# cuic 工具链使用教程

cuic 是 CangHui 的集成生命周期 CLI。以下命令在 `tools/cuic/bin/cuic`（或安装后的 `cuic`）。

## 构建 / 测试 / 运行

```bash
cuic build [platform] [project]
cuic test [platform] [project]
cuic run [platform] [project|example]
```

- 默认生产（release）语义。
- 无参数时优先当前 `cjpm.toml` 项目，否则回退 `notepad` 示例。

## 调试渠道

`kmode` / `probe` 执行、`pview`、`shell`、`debug` 与设备截图属于特权开发面，必须使用
`cjpm build -g` 构建的 cuic。发布 cuic 会显式拒绝这些路径，只保留
`kmode diff` / `probe diff` 静态冲突检查；发布应用同样不会接受旧环境变量或
`--kmode-stdio` 注入。

调试子进程的 stdout 仍由帧协议独占。cuic 只跳过完整匹配的已知 CJPM 启动诊断（包括
空包目录的 `there is no '.cj' file ... will not be scanned as source code` 警告）；任意应用
stdout、截断警告或近似伪装文本都会在首个协议帧前明确失败，不能借通用 `Warning:` 前缀
绕过协议污染检查。

```bash
cuic debug [platform] [project] [--device <alias>] [--app <bundle>] [-- <app args...>]
```

- 显式调试渠道命令面；当前设备捕获通道为 `delivery-pending`，渲染面穿透待 Harmony 侧。

## 截图 / 设备界面获取

```bash
cuic prnt [platform] [project] [--output out.png] [--frames N] [-- <app args...>]
cuic prnt [platform] [project] --device <alias> --app <bundle> --output out.jpeg
```

- 桌面：`prnt` 构建后直接启动产物，使用 `DesktopCaptureRequest`，不依赖 `cjpm run` 参数转发。
- 设备：仅调试 cuic 的 `--device <alias> --app <bundle>` 校验设备与包，当前使用系统截屏 fallback
  （输出标注为 fallback）；渲染面穿透通道待 Harmony 侧实现。

## ASCII 布局输出

```bash
cuic pview [project] <probe> [--columns <20..240>] [--rows <8..100>] [--script <file>|--events <script>]
```

- 从 recording-headless Draw IR 输出确定性 ASCII 布局，不开窗口。
- 示例：
  ```bash
  cuic pview examples/component-gallery gallery.primary-button --columns 72 --rows 20
  cuic pview coreplayer.layout --events 'press 80 35\nrelease 80 35'
  ```
- `cuic probe ascii` 是兼容别名。

## 设计硬真相导出

```bash
cuic design snapshot [project] <probe> [--script <file>|--events <script>]
```

- 复用已有 `ComponentProbe`，从最终采样帧导出 `canghui.design-snapshot/v1` 规范 JSON。
- 输出对齐稳定组件 ID、层级、布局、语义状态和 scoped Draw IR；相同输入的字节与 digest 稳定。
- 敏感属性入场脱敏，且命令仍受 debug 门保护；它不读取系统截图，也不开放发布态输入隧道。

## 一次性界面事件与无图观察

```bash
cuic shell snapshot [project]
cuic shell click [project] <x> <y>       # touch 是别名
cuic shell focus [project] <component-id>
cuic shell run [project] --events 'snapshot
click 120 48
diff'
```

- `shell` 只构建并启动一个 debug 子进程；不连接任意现有 PID，不开放 socket、listener、
  stdin 控制管道，也不执行 shell 文本。白名单脚本完成后应用自动退出。
- 支持 `click/touch`、`down/press`、`move`、`up/release`、`focus`、`key`、`text`、
  `snapshot`、`diff`；最多 128 条、64 KiB。坐标事件经过正常 CangHui 命中测试，不能
  直接调用应用函数。
- `snapshot` 返回 viewport、当前焦点、可聚焦节点和交互所有者；`diff` 返回相邻渲染帧
  的新增/移除节点与焦点变化。先用它确认真实运行态，再用 `pview` 查几何、`prnt` 查像素。
- release cuic 会拒绝 `shell`，release 应用也不会保留脚本 opt-in 与结果协议标记。

## UI 健康审计

```bash
cuic ui audit [project] <probe> [--script <file>|--events <script>] \
  [--fail-on <info|warning|error>]
```

- 输出 canghui.ui-health/v1 规范 JSON；达到 fail-on 阈值时退出码非零。
- 诊断来自语义、布局和 Draw IR 硬证据；无法证明的对比度会明确标为 unknown。
- 它不打开系统截图、不自动改源码，适合放在 pview 之后、prnt 之前。

## 生成 HarmonyOS 投影

```bash
cuic prepare harmony [project] [--json]
```

- 读取 canghui.toml 的 [harmony] 段，只写项目内声明的 generated output。
- 相同输入二次执行无写入；源、资源、框架模板或生成树漂移会失败，不覆盖人工内容。
- 生成结果提供 Cangjie source、Ability/XComponent/IME host 模板、native header 和 rawfile staging；产品身份、权限、签名仍由消费端拥有。

## 设备列表

```bash
cuic device list
cuic device list --json
```

- 通过 hdc 列出已连接设备（如 `192.168.0.108:5555`）。

## 更多

- `cuic help` 提供完整用法与 pview 教程。
- `cuic doctor [target]` 检查各平台工具链就绪度。
- 发布前运行 `scripts/verify-privileged-release-exclusion.sh`；macOS 来源、签名与
  公证门见 [`manual/reference/security-and-release.zh-CN.md`](../reference/security-and-release.zh-CN.md)。
