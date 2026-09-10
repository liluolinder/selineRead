[chui](../../index.md) › [chui.core](index.md) › SemanticRuntime

# SemanticRuntime

`SemanticRuntime` 是一个窗口内的有界语义树与类型化动作调度器。它不创建网络、IPC、
进程附加、坐标点击、按键或命令执行入口。

```cangjie
public class SemanticRuntime
```

## 构造

```cangjie
SemanticRuntime(
    windowId: String,
    policy: SemanticInteractionPolicy = SemanticInteractionPolicy(),
    limits: SemanticRuntimeLimits = SemanticRuntimeLimits(),
    handler: SemanticActionHandler = {_ => false}
)
```

## 帧与查询

| API | 说明 |
|---|---|
| `beginFrame()` | 开始一次事务式语义收集。 |
| `pushParent(id)` / `popParent()` | 为随后记录的节点建立有界父级作用域。 |
| `record(frame, widgetType, semantics, interactionsEnabled:)` | 记录一个 `ControlSemantics` 节点；非活动帧中为空操作。 |
| `commitFrame()` | 校验并提交整棵树，revision 加一，返回 `SemanticTreeSnapshot`。 |
| `cancelFrame()` | 放弃当前未提交节点。 |
| `snapshot()` / `diff(previous)` | 读取当前树，或按稳定 ID 比较两个 revision。 |
| `dispatch(request)` | 校验窗口、revision、节点、动作、状态与来源策略后调用 handler。 |

## 相关类型

- `SemanticRuntimeLimits`：默认 2048 节点、32 层与 256 KiB 文本，并受公开硬上限常量约束。
- `SemanticInteractionPolicy`：Accessibility/Keyboard/Gamepad 默认允许，Voice/Agent 默认拒绝。
- `SemanticActionKind`：`Activate`、`Focus`、`Increment`、`Decrement`、`Dismiss`。
- `SemanticActionSource`：`Accessibility`、`Keyboard`、`Gamepad`、`Voice`、`Agent`。
- `SemanticActionRequest` / `SemanticActionReceipt`：精确窗口和 revision 绑定的动作与回执。
- `SemanticNode`、`SemanticTreeSnapshot`、`SemanticTreeDiff`：构造与查询边界均深拷贝隔离的
  节点、快照与 ID 级差分；调用方可修改自己持有的数组，但不会反向改写运行时状态。

`DesktopApp.semanticSnapshot`、`semanticDiff` 与 `dispatchSemanticAction` 已接到同一运行时。
完整安全边界见[运行时语义交互](../../../reference/semantic-runtime.md)。
