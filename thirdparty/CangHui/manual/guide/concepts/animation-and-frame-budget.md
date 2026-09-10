[CangHui 指南](../index.md) › 动画与帧预算

# 动画状态与帧预算

## 先用一句话说明

动画把跨帧进度保存在稳定对象中，并且只在尚未到达目标或本来就要循环时请求下一帧。

先理解[构建生命周期](composition-and-lifecycle.md)和[资源所有权](resources-and-media.md)。控件树会重建，动画器若每次构建都重新创建，就会不断回到起点；帧循环若无条件持续，则静止窗口仍消耗 CPU/GPU。

## 为什么重要

桌面动画需要同时满足流畅和空闲低开销。按钮滑块到达终点后不再需要帧，骨架屏的 Pulse 却必须持续循环，文件对话框轮询只在请求未完成期间需要 FrameHandler。把三者都写成永久每帧回调，会让“声明式”错误地等于持续刷新。

CangHui 提供三种不同的动画方式。`Spring` 根据当前位置、速度和物理参数逐渐到达目标；`Animator` 在指定时长内按 Easing 从当前值走到目标；`Pulse` 没有终点，适合呼吸灯或骨架屏。`FrameHandler` 只是每帧调用一次的入口，动画状态和“是否已经稳定”仍应交给相应动画器。组件级自动动效通过 `AnimationSpec` 与主题的 `MotionLevel.Basic / Standard / Full` 相连。

## 工作模型

每个动画都回答四个问题：状态由谁持有、目标从哪来、哪段代码推进时间、何时停止请求帧。

`Animator.animate(ctx, target:)` 与 `Spring.animate(ctx, target:)` 会读取帧间隔、推进状态，并在尚未稳定时请求下一帧。到达目标后它们不再请求，因此静止控件可以回到按需绘制。`Pulse.animate(ctx)` 每次都会请求下一帧，因为循环本身就是目标。

`AnimationSpec.automatic(...)` 表示“由主题决定表达力度”：Basic 使用较小位移并把自动时长缩为 3/4，Standard 使用标准值，Full 使用更强位移并把自动时长放大为 5/4。直接构造 `AnimationSpec(...)` 表示产品已指定精确时间和曲线，切换 MotionLevel 不会改写它。这个区分避免全局主题误改关键流程的既定节奏。

动画对象必须跨构建保留。可以放进应用模型，或放在稳定局部状态/对象中。不要在 draw 中创建新 Animator，也不要在构建函数中按墙钟直接计算并写 State；构建只描述目标，draw 或 FrameHandler 推进当前值。

## 选择与取舍

- 明确时长、需要与产品动效规范一致：Animator + Easing。
- 目标可能在中途改变、希望有自然追随：Spring。
- 永续加载/呼吸：Pulse，并在内容就绪后卸载使用它的控件。
- 倒计时、异步请求轮询：条件挂载 FrameHandler；完成后移除。
- 只想让高度展开/收起：优先用 Reveal 等成品容器，不必自建动画器。
- 同一对象在排序或响应式网格中换槽位：用 `KeyedLayoutTransition`，并给对象稳定业务 key。
- 组件应跟随主题力度：使用 `AnimationSpec.automatic(...)`。
- 产品规范要求精确 320ms：使用 `AnimationSpec(duration: UInt64(320), easing: ...)`。

性能判断不能只看 FPS。垂直同步会把结果量化到刷新周期，真正的瓶颈要看构建、布局、绘树、降采样和呈现各阶段。先用 `--profile` 取证，再减少可见节点、复杂几何或不必要续帧。

## 应用这个模型

下面对比确定时长与物理追随。两个对象都应由模型持有，而不是在每次 draw 新建：

```cangjie role=contrast
let fade = Animator(0.0, duration: Motion.normal, easing: Easing.EaseInOutQuad)
let slide = Spring(0.0)

let opacity = fade.animate(ctx, target: if (shown) {1.0} else {0.0})
let offset = slide.animate(ctx, target: if (shown) {0.0} else {24.0})
```

组件可以选择自动或精确播放属性：

```cangjie role=contrast
let theme = Theme.dark(motionLevel: MotionLevel.Full)

Button("Follow theme", onClick)
    .animation(AnimationSpec.automatic(duration: Motion.normal, easing: Motion.decelerate))

Button("Exact timing", onClick)
    .animation(UInt64(320), easing: Easing.EaseOutBack)
```

指针激活与动画状态必须使用同一取消边界：move in 后按下可以进入 press；按住移出必须立即取消
press/InkWell，外部 release 不执行回调。只有 release-inside 才完成 click。Button、IconButton、
Accordion header 与 StepIndicator 已到达节点都遵循这一语义。

下面跟踪一个只在运行中挂载的计时器。暂停后不再构建 FrameHandler，因此它不再请求帧；根内容仍正常显示：

```cangjie role=trace
if (model.running.value) {
    FrameHandler(onFrame: {info => model.tick(Int64(info.deltaMs))}) {
        timerView(model)
    }
} else {
    timerView(model)
}
```

这和“FrameHandler 回调里什么都不做”不同：只要挂载，帧钩子仍会请求下一帧。停止条件应体现在控件树中。

## 常见误解

- **“Animator 放在构建闭包里也会继续。”** 若对象随重建重新创建，进度会重置。
- **“所有动画都应该用 FrameHandler。”** 动画器已经包含推进和稳定判断，FrameHandler 适合通用时钟或轮询。
- **“动画停住是 Easing 错了。”** 先检查对象是否稳定保留、是否调用带 UiContext 的 animate、是否还有续帧请求。
- **“Pulse 到达 1 就结束。”** Pulse 是循环时间线，没有 settled 终点。
- **“按下过就应该在释放时执行。”** 指针移出表示取消意图；外部释放不能补发点击。
- **“移动中的卡片还应该在旧位置响应。”** `KeyedLayoutTransition` 只让绘制矩形过渡，输入和焦点立即属于目标布局。
- **“数组下标可以作为重排 key。”** 下标表示槽位，不表示对象；排序后会把保留几何错配给另一条记录。
- **“帧率低就关闭超采样。”** 先读阶段剖析；可见节点、文本成形或几何可能才是主要耗时。

## 相关 API

- [`Animator`](../../api/chui/core/Animator.md) 与 [`Easing`](../../api/chui/core/Easing.md) — 确定时长动效。
- [`Spring`](../../api/chui/core/Spring.md) — 物理追随。
- [`Pulse`](../../api/chui/core/Pulse.md) — 循环时间线。
- [`FrameHandler`](../../api/chui/core/FrameHandler.md) — 条件帧钩子。
- [`KeyedLayoutTransition`](../../api/chui/core/KeyedLayoutTransition.md) — 重排与响应式重布局的矩形连续性。

## 下一步

在[驱动动画](../how-to/animate-with-frames.md)中运行确定性动画程序，再用[快照与帧剖析](../how-to/snapshot-and-profile.md)区分视觉结果和性能证据。
