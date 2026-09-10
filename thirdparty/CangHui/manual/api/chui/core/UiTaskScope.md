[chui](../../index.md) › [chui.core](index.md) › UiTaskScope

# UiTaskScope

UiTaskScope 在已有 UiOwnerQueue 上提供有界的后台准备生命周期。prepare 在 worker 执行并返回不可变结果；apply 通过 owner queue 回到 UI owner，才允许修改 State 或组件。

```cangjie
let scope = UiTaskScope("app.search", app.uiOwnerQueue(),
    policy: UiTaskPolicy.LatestOnly)

let ticket = scope.submit(
    {=> buildSearchResult(query) },
    {result => results.value = result},
    surfaceGeneration: Some(windowGeneration)
)
```

UiTaskPolicy 支持 SingleFlight、LatestOnly、Queue(limit) 与 Debounce(ms)。取消是协作式的：它阻止未领取的 owner apply，但不会强杀已经运行的外部函数。close 会取消未完成任务并永久拒绝新提交，不会关闭共享 UiOwnerQueue。

UiTaskSubmission.status() 在进入 owner queue 后映射原有 UiOwnerReceipt；过期 epoch 或 surface generation 统一呈现为 RejectedStaleOwner。框架不会替业务做重试、事务回滚、进程管理或协议策略。
