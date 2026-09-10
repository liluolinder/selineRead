# Renderer effects

CangHui 的二维合成效果采用“样式请求、renderer 决定、receipt 回报”的可选适配器模型。
它用于 `Surface` 已经开始绘制时，对当前帧中位于组件后方的像素做有界采样；它不属于
`chui.graphics` 的独立 3D/compute device，也不会把 Metal、Vulkan、D3D、GLES 或 WebGPU
写进主题 API。

## 基本用法

多数应用不需要直接调用这一层。`canghui_style_liquid_glass` 会先尝试 backdrop effect，
然后继续绘制自己的 SDR 边缘、雾气、tint 和前景形变：

```cangjie
let receipt = LiquidGlass.paintWithReceipt(
    renderer,
    Rect(40.0, 40.0, 260.0, 72.0),
    spec: LiquidGlassSpec(variant: LiquidGlassVariant.Clear)
)

if (!receipt.applied()) {
    // 内容和布局仍已由 Liquid Glass 的确定性 fallback 正常绘制。
}
```

自定义效果包可直接构造 `BackdropEffectRequest`：

```cangjie
let receipt = renderer.applyBackdropEffect(BackdropEffectRequest(
    Rect(40.0, 40.0, 260.0, 72.0),
    cornerRadius: 28.0,
    blurRadius: 12.0,
    refraction: 0.42,
    edgeResponse: 0.8,
    expectedFrameGeneration: renderer.effectFrameGeneration()
))
```

`RendererEffectReceipt` 会报告 `status`、`code`、`providerId`、帧 generation、实际采样像素
和本帧 effect 序号。`lastEffectReceipt()` 与 recording renderer 的 `effect.backdrop` Draw IR
可供 probe、CUIC 和诊断界面读取。

## 帧与资源规则

- 请求只在 `beginScene` 与 `endScene` 之间有效；跨帧保留的请求应携带
  `expectedFrameGeneration`，旧 generation 会以 `stale-frame` 拒绝。
- `bounds` 是布局矩形；`transformedBounds` 可携带调用者已经求出的最终轴对齐覆盖范围。
  provider 不猜测或重放调用者的变换。
- provider 必须与当前 viewport 取交集；resize 会开始新 generation，因此旧尺寸请求不会
  静默复用。
- `maxSamplePixels` 与 `maxEffectsPerFrame` 是硬预算。超限返回可观察的 degraded receipt，
  由样式走 fallback；不得悄悄扩大同步读回。
- 替换 adapter 会先结束并释放旧 adapter；renderer 关闭时 release 幂等执行。provider
  异常会转成 receipt，不应让纯装饰效果吃掉应用内容。
- `reduceTransparency` 在样式层直接选择不透明材质，不调用 backdrop adapter。

## 当前 provider 矩阵

| Provider | Backdrop | Blur/refraction | Shape union | 证明边界 |
| --- | --- | --- | --- | --- |
| `sdl-readback` | 支持，当前帧有界同步采样 | 支持第一版多采样柔化与镜片取样 | 不支持，明确返回 `shape-union-unsupported` | macOS SDL 真窗口测试与 `cuic prnt` 像素证明 |
| Headless/未安装 | 不支持 | fallback | 不支持 | receipt 与 Draw IR 证明 |

`sdl-readback` 只读取每个请求所需的扩展矩形，并在当帧创建、使用、释放临时 texture；它是
可用的首个 native-backed adapter，但同步 readback 仍是有成本的路径。大量列表项、全屏玻璃或
每帧无上限 effect 不属于推荐用法。

多个重叠 Surface 在首版 SDL provider 中是稳定的独立请求，不是假装过的 shape union。
如果调用者设置 `requireShapeUnion: true`，provider 会拒绝并保留样式 fallback。后续 Metal、
Vulkan、D3D、GLES、WebGPU provider 可以在同一 capability/receipt 契约下提供真正的 GPU
background texture、pass 合并或形状 union，但必须分别给出平台运行与像素证据。

## 非声明

- 不是 Apple 原生材质或私有 API；
- 不承诺与任一平台逐像素一致；
- macOS SDL 证据不等于其他平台 provider 已完成；
- renderer effect 不拥有 `Surface` 的布局、内容、命中、焦点或语义。

可运行示例见 [`examples/liquid-glass-effects`](../../examples/liquid-glass-effects/README.md)。
