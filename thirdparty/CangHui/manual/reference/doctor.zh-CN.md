# 多平台 Doctor

[English](doctor.md) | **中文**

`cuic doctor` 用于报告 CangHui 开发环境的就绪情况，但不会因为报告里列出了某个平台，就暗示该平台已经在当前宿主上实现或验证。

```bash
./tools/cuic/bin/cuic doctor
./tools/cuic/bin/cuic doctor macos --verbose
./tools/cuic/bin/cuic doctor ios --json
```

可选目标为 `macos`、`windows`、`linux`、`ios`、`harmonyos` 或 `android`。未指定时默认使用当前宿主平台。每份报告仍会列出全部平台分组，使跨平台缺口保持可见。

## 状态模型

| 状态 | 含义 |
|---|---|
| `ready` | 当前宿主可执行该检查，并且已经通过。 |
| `degraded` | 能力仍可使用或检查，但存在不阻塞的缺项。 |
| `blocked` | 必须先修复报告中的要求，指定目标才能继续。 |
| `unsupported` | 当前 CangHui 版本或当前宿主无法执行该能力。 |

修复动作分为 `automatic`、`manual`、`unsupported`、`none`。人类可读输出会在受影响的检查旁显示对应动作。

## 退出状态

只有全局检查或显式请求的目标包含 `blocked` 或 `unsupported` 时，进程才返回非零状态。未请求平台的限制会继续显示，但不会让本来可用的宿主流程失败。`degraded` 本身不会使命令失败。

对于使用 Git 依赖的应用，缺少 `cjpm.lock` 或其中的 CangHui commit 与 manifest 不一致时，
全局工程分组会进入 `blocked`。检查 manifest pin 后再显式运行 `cuic dependency update`；doctor
与构建类命令不会隐式修复 lock。

因此下面的写法适合 CI：

```bash
./tools/cuic/bin/cuic doctor macos --json > doctor.json
```

JSON 文档遵循 [`canghui.doctor.v0`](../../contracts/canghui-doctor-v0.schema.json)。未使用 `--verbose` 时，每个 `evidence` 字段都是空字符串。详细模式可能包含工具版本和文件系统位置，但签名身份与已连接设备只会输出摘要，不会直接暴露完整身份。

新报告会在稳定的 `cliVersion` 旁增加 `cliProvenance`。其中 `channel` 为
`development`、`local-source` 或 `release`；安装产物的 `revision` 是精确 Git
提交，本地源码含未提交输入时带 `+dirty`，直接在仓库内构建且未嵌入来源时则诚实标记为
`unembedded`。该字段在 v0 schema 中保持可选，使已经保存的旧报告仍可通过校验。

iOS 分组会分别报告静态包 bootstrap 与 native-surface 适配器。当前适配器包含整数 C ABI、
UIKit `CAMetalLayer`、生命周期与安全区入口、触摸转发、`CADisplayLink`、generation 门控的
detach/reattach 重放，以及模拟器/真机验证器。完整 CangHui 场景渲染、IME、无障碍、应用打包
与产品验收仍属于后续平台工作。

## 检查分组

报告覆盖：

- 仓颉编译器与包管理器是否可用；
- 仓库、包与集成 CLI 是否一致；
- macOS、Windows、Linux、iOS、HarmonyOS/OpenHarmony、Android 就绪度；
- 适用平台上的 SDL 运行库或开发库；
- 随包 HarmonyOS Sans 及其许可证回执；
- Symbol 核心、可选 Provider 与按需生成；
- kMode 与 `cui.probe.v0` 的重复注册健康状态。

只有显式请求 `ios` 或 `harmonyos` 时，doctor 才会运行签名和已连接设备相关命令，使默认桌面诊断保持有界、可预测。

iOS 分组会把已经可检查的静态包启动流程与尚未完成的 GUI 后端分开报告。构建脚本、Objective-C 启动辅助、回放脚本和双目标结果各自独立显示；在 iOS 应用目标完成设备验收前，`CAMetalLayer/MTKView` 原生 surface 渲染器仍是阻塞项。

如果 iOS SDK 不在默认的 `/Library/Frameworks/Cangjie/1.3.0-alpha-ios`，请设置 `CANGHUI_IOS_HOME` 或 `CANGJIE_IOS_HOME`。
