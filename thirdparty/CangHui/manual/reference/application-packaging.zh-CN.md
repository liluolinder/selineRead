# 应用打包

[English](application-packaging.md) | **中文**

`canghui.toml` 是工程侧的应用身份、逻辑资源与系统能力策略声明。`cuic`
读取这份声明，但平台原生 provider 仍保持独立。

## 最小声明

```toml
[application]
name = "Demo"
identifier = "dev.example.demo"
version = "1.0.0"
publisher = "Celading"

[assets]
application-icon = "assets/app.png"
resources = ["assets/data", "assets/i18n"]

[system]
single-instance = true
status-item = true
notifications = true
settings = true
```

资源路径必须相对于工程目录。绝对路径、`~`、包含 `..` 的路径、已声明资源树中
任意层级的符号链接以及不存在的资源都会被拒绝。递归符号链接检查可避免资源目录
在打包时引入工程外文件。图标按逻辑角色分别声明，`cuic` 不会擅自把应用图标
猜成状态栏或通知图标。应用名还必须是跨平台安全的产物名；Windows 保留字符、
设备保留名以及首尾空格或句点都会被拒绝。

## 确定性规划

```text
cuic package plan macos .
cuic package plan windows . --json
cuic package plan linux . --json
```

命令会校验 manifest，并输出身份、输入资源、预期生成文件、provider 状态和
签名门。它只生成规划，不会构建 `.app`、生成 Windows 资源、签名或发布产物。
相同 manifest、工程与目标平台会得到字段顺序稳定的同形结果。

## 无签名产物生成

```text
cuic package build macos .
cuic package build windows . --output dist/windows-input --json
cuic package build linux . --output dist/linux-input --json
```

`package build` 会生成边界明确的无签名产物，并写入采用
`canghui.packaging-artifact.v0` 结构的 `canghui-packaging-receipt.json`。
macOS 将 receipt 放在可被签名封装的 `Contents/Resources` 内，Windows 与 Linux
仍放在产物根目录。
macOS 默认输出到 `dist/<Name>.app`，Windows 与 Linux 默认输出到
`dist/<Name>`。`--output` 只接受工程内相对目录；绝对路径、越界路径和非空目录
都会被拒绝，命令不会隐式覆盖既有产物。输出目录也不能位于已声明资源目录内部，
从而避免生成中的产物递归复制到自身资源树。

在 macOS 宿主上，macOS 路由会先执行正常的锁定依赖 `cuic build`，再把真实
可执行文件复制到 `Contents/MacOS`，同时生成 `Info.plist`、`PkgInfo`、资源树和
逻辑图标角色文件。receipt 位于 `Contents/Resources`，避免下游签名时在 `.app`
根目录出现未封装文件。receipt 会明确记录原生运行时依赖仍由宿主管理，且该无签名
bundle 尚未完成启动验收，同时记录 release trim/strip、发布安全审计、发布者签名
与公证均未验证。

Windows 与 Linux 路由可以在其他宿主上生成输入树，但不会伪装成已经跨平台编译：

- Windows 生成 executable manifest、版本资源源码、AppUserModelID、资源与图标输入。
- Linux 生成 desktop entry、`share/applications`、图标树和应用资源树。

图标字节不会被改名伪装成另一种格式。只有真实 `.icns` 或 `.ico` 使用对应原生
文件名；PNG、SVG 等输入保留扩展名，并继续作为转换或平台 Provider 门禁显示。

## 平台边界

- macOS 可生成本地无签名 `.app`；签名、公证、自包含运行时闭合和启动验收仍是独立门。
- Windows 生成资源编译输入；PE 可执行文件、资源编译、签名和 MSIX 发布仍未完成。
- Linux 生成桌面打包输入树；真实宿主可执行回放、系统安装、托盘和通知仍未完成。

`cuic doctor` 会报告声明、引用资源和两份打包 schema 是否就绪，但就绪状态不等于
运行时或发布证明。

发布编译契约、特权通道负回放、Developer ID/Hardened Runtime 签名与公证门见
[安全边界与发布来源证明](security-and-release.zh-CN.md)。无签名
`package build` receipt 绝不是发布者或商店证据。

移动宿主使用独立的分阶段 receipt，因为平台输入树、已签名安装包和真机回放是
三类不同事实。参见[移动应用宿主](mobile-application-host.zh-CN.md)与
`canghui-mobile-host-package-v0.schema.json`。
