# 运行时语义交互

`SemanticRuntime` 把库存控件已经发布的 `ControlSemantics` 收集为一棵有界、带修订号的
进程内语义树。它供原生无障碍适配器、可信语音入口、应用内 Agent 和无图检查读取同一份
组件身份与动作事实；它不是坐标点击器，也不会创建 IPC、socket、进程附加或命令执行入口。

`import chui.*` 会重新导出本页类型。

## `DesktopApp` 自动接线

`DesktopApp` 的普通构建/布局/绘制帧会自动收集库存控件的 `ControlSemantics`。应用可为窗口
指定稳定身份、限制、来源策略与类型化动作 fallback 处理器。库存可聚焦控件会先通过框架的
普通焦点/键盘事件路径实际执行；只有内建路由拒绝时才调用 fallback：

```cangjie
let app = DesktopApp(
    WindowSpec("Semantic example", 720, 480),
    semanticWindowId: "main",
    semanticPolicy: SemanticInteractionPolicy(agent: true),
    onSemanticAction: { request =>
        // 自定义、非库存动作的受控 fallback。
        request.nodeId == "toolbar.save" &&
            semanticActionName(request.action) == "activate"
    }
)

let before = app.semanticSnapshot()
let changed = app.semanticDiff(before)
let receipt = app.dispatchSemanticAction(SemanticActionRequest(
    "main",
    app.semanticSnapshot().revision,
    "toolbar.save",
    SemanticActionKind.Activate,
    SemanticActionSource.Agent
))
```

动作必须同时匹配 `windowId`、`expectedRevision`、`nodeId`、控件声明的 action 与来源策略。
旧 revision、错误窗口、禁用/只读控件、未声明动作和未授权来源都会得到拒绝回执。
`Voice` 与 `Agent` 默认关闭；`Accessibility`、`Keyboard` 与 `Gamepad` 默认允许，但真正的
宿主入口仍由应用或平台适配器持有。类型化动作不会转换为坐标、命令字符串或外部控制通道。

## 树、差分和上限

- `SemanticTreeSnapshot` 是一个窗口的一次已提交树；`SemanticTreeDiff` 按稳定 ID 报告
  `added`、`removed` 与 `changed`。构造与运行时查询都会深拷贝数组，因此调用方只能修改
  自己持有的副本，不会反向污染已提交树。
- `SemanticNode` 保存父子身份、声明顺序、逻辑矩形、role、label/value/placeholder、状态与
  类型化动作。`role == "password"` 的 value 在进入树之前强制清空。
- 默认上限为 2048 节点、32 层、256 KiB 文本；编译期硬上限分别为 4096、64 与 1 MiB。
  重复 ID、未平衡父栈或越界帧会整体失败，不提交半棵树。
- 自定义宿主可直接使用 `SemanticRuntime.beginFrame`、`record`、`commitFrame` / `cancelFrame`；
  运行中控件的自动收集只由框架受保护的帧作用域启用。

## 当前边界

这套运行时提供跨宿主的语义事实和安全动作模型，不等于 macOS AX、Windows UIA、Linux
AT-SPI 或 HarmonyOS 原生无障碍 provider 已经实现。`DesktopApp` 与 `DesktopApplication`
托管窗口均已自动接线，并保持独立窗口身份与 revision。调试用 `cuic shell` 仍是单独的 debug-only、
一次性回放通道，不能用语义运行时绕过发布构建的控制面隔离。
