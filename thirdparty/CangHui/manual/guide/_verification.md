# 指南验证报告

本页说明指南中的示例和能力声明分别经过哪一层验证。它不是平台发布承诺；某条命令能构建，不代表对应平台的生命周期、输入、打包和设备行为已经完成。

## 验证层级

| 层级 | 能说明什么 | 不能说明什么 |
|---|---|---|
| 源码/链接 | 仓颉语法、包导入和链接关系成立 | 窗口能启动、交互正确 |
| 单元/事件测试 | 状态、布局、事件和组件契约可重复执行 | 字体外观、平台窗口行为 |
| Renderer 快照 | 稳定初始帧可生成，可检查裁切和布局 | 键盘、拖动、系统对话框等完整交互 |
| 人工交互 | 指定宿主上的鼠标、键盘、窗口与系统集成可观察 | 其他宿主和设备自动获得同等结果 |
| 设备/打包 | 指定目标的生命周期、签名、安装和运行成立 | 其他版本、设备或发布渠道自动成立 |

## 当前自动化结果

使用 Cangjie `1.1.3 (cjnative)` 在 macOS arm64 上于 2026-08-30 执行：

| 命令 | 结果 | 覆盖 |
|---|---:|---|
| `cjpm build` | 通过 | CangHui 主包构建与链接 |
| `cjpm test --no-progress` | 844/844 | core、controls、text、graphics、scene3d、desktop、host、语义运行时、保留式 UI 与共享帧契约 |
| `cjpm test -g --no-progress` | 853/853 | release 模式主包、宏链接与同组契约 |
| `cd sdl && cjpm test --no-progress` | 118/118 | SDL 窗口、事件封装、输入、显示、文本与系统边界 |
| `cd tools/cuic && cjpm test --no-progress` | 72/72 | debug 模式 doctor、工程解析、缓存、脚本、probe/prnt 与 Symbol 生成 |
| `cd tools/cuic && cjpm test -g --no-progress` | 87/87 | release 模式 CUIC 与受保护能力排除契约 |

链接器仍会提示部分 Cangjie/SDL 动态或静态库的最低 macOS 版本高于应用声明的 `12.0`。这不影响当前宿主测试通过，但不能据此声明可移植的 macOS 12 发布包。

## 指南示例怎么验

- `role=complete` 示例应能放进相应空工程独立构建。
- `role=patch` 示例只表示对所链接基页的增量修改，不应单独运行。
- 纯概念片段用于解释状态、布局或事件边界，不作为完整程序。
- 涉及 Modal、菜单、拖动、焦点、文件对话框和窗口控制的页面，应同时保留人工观察步骤。
- 涉及快照时，优先使用 `cuic prnt`，并把截图看作视觉证据而不是函数行为的唯一证据。

## 仍需按平台验证

- iOS 的完整 CangHui 场景渲染、IME、无障碍、产品应用与正式打包；
- HarmonyOS/OpenHarmony 的应用宿主、生命周期、打包与设备运行；
- Windows 与 Linux 的当前宿主运行、动态库布置和发布包；
- Android 的渲染后端、Activity/NDK 桥和 APK 流程。

公共布局预览可以提前检查 Compact、Medium、Expanded 下的组合方式，但不能替代上述平台验收。
