[chui](../../index.md) › [chui.core](index.md) › UiOwnerQueue

# UiOwnerQueue

`chui.core` 包中的 public class

线程安全的多 producer、单 UI owner 提交队列。worker 只准备不可变结果并调用 `post`；唯一 UI owner
调用 `drain`，在 live UI 上执行小型提交任务。队列提供确定性顺序、乐观 epoch/native-surface
generation 门、取消、关闭和最终 receipt，但不提供事务隔离或回滚。

## 声明

```cangjie
public class UiOwnerQueue
```

## 构造函数

```cangjie
public init(wake!: ?UiOwnerWakeHandler = None)
```

`wake` 是可选的线程安全宿主唤醒回调。任务入队后调用；其异常被忽略，因为投递已经成功。

## 方法

### post

```cangjie
public func post(
    action: UiOwnerTaskHandler,
    baseEpoch!: ?UInt64 = None,
    surfaceGeneration!: ?Int64 = None,
    topologyHash!: String = ""
): UiOwnerTicket
```

在锁内取得单调 `sequence` 并排队。`baseEpoch` 与 `surfaceGeneration` 是可选执行前条件；不匹配时
任务体不运行。`topologyHash` 仅随 receipt 透传，供上层 SceneDiff 或诊断协议关联，不由队列解释。
generation 小于零抛 `IllegalArgumentException`。队列关闭后仍返回 ticket，但它已带
`RejectedClosed` receipt。

### drain

```cangjie
public func drain(maxTasks!: Int64 = 1024): Array<UiOwnerReceipt>
```

由 UI owner 串行执行至多 `maxTasks` 个任务。调用开始时先取有界快照，所以任务体内再次 `post` 的工作
留到下一次 drain。多个误并发的 drain 会被串行化，但自定义宿主仍有责任始终从同一个 UI owner 调用。
`maxTasks <= 0` 抛 `IllegalArgumentException`。

任务通过取消和陈旧门后，owner epoch 在执行任务体之前推进。任务抛出 `Exception` 时 receipt 为
`Failed`，后续任务继续执行；epoch 不回退，因为失败前可能已部分修改 live UI。

### cancelAllPending

```cangjie
public func cancelAllPending(reason!: String = "UI owner queue cancelled"): Array<UiOwnerReceipt>
```

取消当前尚未被 drain 领取的快照并返回 receipt。队列保持开放，之后仍可投递。

### close

```cangjie
public func close(reason!: String = "UI owner queue closed"): Array<UiOwnerReceipt>
```

永久关闭队列并取消当前待处理任务。与关闭并发的投递要么进入取消快照，要么立即完成为
`RejectedClosed`，不会留下永久未完成的 ticket。`isClosed()` 返回关闭状态。

### 状态查询

```cangjie
public func hasPending(): Bool
public func pendingCount(): Int64
public func currentEpoch(): UInt64
public func isClosed(): Bool
public func setSurfaceGeneration(generation: ?Int64): Unit
public func surfaceGeneration(): ?Int64
```

`setSurfaceGeneration(None)` 表示表面已分离；此时带具体 generation 的任务会被拒绝。

## UiOwnerTicket

producer 持有的线程安全票据。

```cangjie
public class UiOwnerTicket {
    public let sequence: UInt64
    public let baseEpoch: ?UInt64
    public let surfaceGeneration: ?Int64
    public let topologyHash: String

    public func cancel(): Bool
    public func isCancellationRequested(): Bool
    public func receipt(): ?UiOwnerReceipt
}
```

`cancel()` 只在任务仍等待 owner 领取时返回 `true`。owner 原子 claim 后，即使任务体尚未结束也不能再
取消。`receipt()` 在排队或执行中返回 `None`，解决后返回不可变回执。

## UiOwnerReceipt

```cangjie
public class UiOwnerReceipt {
    public let sequence: UInt64
    public let status: UiOwnerTaskStatus
    public let ownerEpoch: UInt64
    public let topologyHash: String
    public let message: String
}
```

`Committed` 与 `Failed` 任务已取得执行 epoch；取消和拒绝不推进 epoch。

## UiOwnerTaskStatus

```cangjie
public enum UiOwnerTaskStatus {
    | Committed
    | Cancelled
    | RejectedClosed
    | RejectedStaleEpoch
    | RejectedSurfaceGeneration
    | Failed
}
```

`uiOwnerTaskStatusName(status)` 返回稳定的小写连字符名称，适合日志和协议字段。

## 示例

```cangjie
let queue = UiOwnerQueue()
let prepared = "worker result"
let base = queue.currentEpoch()
let ticket = queue.post({=> applyPreparedResult(prepared)}, baseEpoch: Some(base))

// 只由 UI owner 调用。
let receipts = queue.drain()
```

## 另请参阅

- [`State`](State.md) — 必须由 UI owner 修改的可观察状态。
- [`DesktopApp`](../desktop/DesktopApp.md) — 已在帧首集成队列的桌面宿主。
