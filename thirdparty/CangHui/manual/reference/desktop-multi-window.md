# 桌面多窗口运行时

`DesktopApplication` 在一个进程级 SDL event pump 下管理多个互相隔离的原生窗口。每个托管
窗口拥有自己的 `SdlWindow`、`UiContext`、`StateStore`、`SemanticRuntime`、焦点、浮层、
指针捕获和 Scene3D 登记；SDL 原始事件的窗口身份通过 `WindowId` / `SdlEventEnvelope`
保留到路由边界。

`import chui.*` 会重新导出本页类型。

## 打开和运行

```cangjie
let app = DesktopApplication()
let mainWindow = app.openWindow(WindowSpec("Main", 900, 640), { =>
    VStack { Label("Main") }
})
let settingsWindow = app.openWindow(WindowSpec("Settings", 520, 420), { =>
    VStack { Label("Settings") }
})

let _ = app.focusWindow(settingsWindow)
app.run()
```

`openWindow` 会先创建、登记并绘制一帧，但不会进入嵌套事件循环。`run()` 是基于公开的
`pump()` + `step()` 组成的便利阻塞循环；需要接进自己的主循环时，可以分别调用：

- `pumpOne()` / `pump(limit:)`：排空有界数量的 SDL 事件并返回 `WindowDispatchReceipt`；
- `step()`：为所有仍打开的托管窗口各构建、布局、绘制并 present 一帧，返回
  `DesktopWindowStepReceipt`；
- `focusWindow`、`closeWindow`、`activeWindow`、`sessionCount` 与 `windowState`：管理窗口并读取隔离状态；
- `semanticSnapshot`、`semanticDiff` 与 `dispatchSemanticAction`：按精确 `WindowId` 读取或
  路由该窗口的 revision-bound 类型化语义动作；
- `close()`：关闭全部托管窗口与最后一份 SDL runtime lease。

所有这些调用都应留在创建 `DesktopApplication` 的原生 owner 线程。不要为每个窗口另起
`DesktopApp.run()`；多个嵌套 SDL event loop 会争用同一个进程事件队列。

## 路由规则

- 带 `WindowId` 的指针、键盘、窗口和 drop 事件只进入对应 session。
- `Quit` 请求关闭全部窗口；单窗 `WindowCloseRequested` 只关闭目标窗口。
- 进程级手柄事件路由给活动窗口，并在焦点转移、设备断开或窗口关闭时释放归属。
- `DesktopWindowSession` 是公开的宿主扩展面；registry 保持框架受保护并由
  `DesktopApplication.registerWindowSession` / `unregisterWindowSession` 控制，避免外部绕过
  托管窗口生命周期。自定义 session 仍须保证自己的窗口身份、owner 线程和资源关闭规则。

## 当前边界

托管多窗口路径已经能够绘制普通组件以及当前 SDL CPU RGBA8 的 Scene3D shared frame，并在
present 后释放 lease，并为每窗自动提交独立语义树、差分和类型化动作路由；它尚未取得单窗口
`DesktopApp` 高级 FrameGraph、renderer effects、主题/设备旋转 transition、采集和应用 Shell
活动窗口动作的完整同等能力。
macOS 已有非跳过的双原生窗口创建、绘制、聚焦与独立关闭烟测。窗口事件 envelope 解码和
精确路由矩阵目前由确定性测试分别覆盖；本轮不把测试内直接路由 envelope 改写成真实系统
输入穿过 `SdlRuntime.pollEvent()` 的端到端回执。Windows 与 Linux 保留代码路径，但在各自
宿主回执到位前不声称主机级运行证明。
