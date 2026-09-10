[chui](../../index.md) › [chui.desktop](index.md) › DesktopApplication

# DesktopApplication

`DesktopApplication` 以一个 SDL event pump 管理多个相互隔离的原生窗口。

```cangjie
public class DesktopApplication <: Resource
```

## 主要 API

| API | 说明 |
|---|---|
| `DesktopApplication()` | 获取一份进程级 SDL runtime lease，并创建空窗口 registry。 |
| `openWindow(spec, body, theme:, fontScale:, semanticWindowId:, semanticPolicy:, semanticLimits:, onSemanticAction:)` | 创建、登记并先绘制一帧，返回稳定 `WindowId`；每窗拥有独立语义 runtime。 |
| `focusWindow(id)` / `closeWindow(id)` | 聚焦或关闭一个托管窗口。 |
| `activeWindow()` / `sessionCount()` / `windowState(id)` | 查询活动窗口、只读 session 数或窗口隔离状态。 |
| `semanticSnapshot(id)` / `semanticDiff(id, previous)` | 读取指定托管窗口的语义树与差分。 |
| `dispatchSemanticAction(id, request)` | 将精确窗口/revision 绑定的类型化动作路由到该窗口。 |
| `pumpOne()` / `pump(limit:)` | 非阻塞路由有界数量事件并返回 `WindowDispatchReceipt`。 |
| `step()` | 为每个仍打开窗口构建、布局、绘制并 present 一帧。 |
| `run()` | 基于 `pump` + `step` 的便利阻塞循环。 |
| `close()` / `isClosed()` | 关闭全部托管窗口与最终 SDL runtime lease。 |

`DesktopWindowSession` 是宿主自定义窗口 session 的接口；registry 由应用私有持有，只能经
生命周期受控的方法登记/移除。它按 `SdlEventEnvelope.windowId` 路由普通事件，并把进程级
手柄事件交给活动窗口。相关回执为
`WindowDispatchReceipt`、`DesktopWindowStepReceipt` 与 `DesktopWindowStateReceipt`。

完整线程、事件和当前同等能力边界见[桌面多窗口运行时](../../../reference/desktop-multi-window.md)。
