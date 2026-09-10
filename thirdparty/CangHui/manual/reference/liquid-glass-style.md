# Liquid Glass 样式包

`packages/style-liquid-glass` 是 CangHui Multiplatform 的可选样式包，公开包名为
`canghui_style_liquid_glass`。它复用 `chui` 的主题与材质扩展点，不改变核心控件 API。

## 引用

```toml
[dependencies]
chui = { path = "../CangHui" }
canghui_style_liquid_glass = { path = "../CangHui/packages/style-liquid-glass" }
```

```cangjie
import chui.*
import canghui_style_liquid_glass.*

let preferences = LiquidGlassPreferences(
    reduceTransparency: false,
    increaseContrast: false,
    reduceMotion: false
)
let app = DesktopApp(
    WindowSpec("Glass", 900, 700),
    theme: LiquidGlass.light(preferences: preferences)
)
```

单个悬浮功能层使用 `Surface` 与公开材质：

```cangjie
Surface(
    shape: Shape.rounded(28.0),
    material: LiquidGlass.material(spec: LiquidGlassSpec(
        variant: LiquidGlassVariant.Regular,
        tint: Some(Color.rgb(0, 122, 255)),
        interactive: false,
        radius: 28.0,
        preferences: preferences
    )),
    painter: Some(LiquidGlass.surfacePainter(spec: LiquidGlassSpec(
        variant: LiquidGlassVariant.Clear,
        radius: 28.0,
        optics: LiquidGlassOptics(clarity: 0.94, haze: 0.18)
    ))),
    clip: ClipPolicy.Shape
) {
    HStack { /* navigation or controls */ }.padding(16.vp, 12.vp)
}
```

`Regular` 适合工具条、侧栏和浮动导航；`Clear` 是高透明镜片，适合视觉内容丰富且仍能保证
文字对比的背景；`Vapor` 用更高 haze 模拟气态、雾化的内部层次。`LiquidGlassOptics` 可分别调整
`clarity`、`haze`、`edgeEnergy`、`chromaticEdge` 与 `deformation`。
交互按钮可直接使用 `LiquidGlass.buttonStyle()`，整套内置控件则由 `LiquidGlass.light()` 或
`LiquidGlass.dark()` 的 `ComponentTheme` 统一接管。内置 `SegmentedControl` 和 `TabView` 会继续拥有
输入、焦点与布局，只把选中镜片交给样式包绘制；镜片的前后缘使用不同弹簧，在切换时产生可见的
伸展、收拢形变。`reduceMotion` 会将形变量降为零。

## 无障碍与层级

- `reduceTransparency` 把半透明表面替换为不透明表面；
- `increaseContrast` 提高边缘对比与描边宽度；
- `reduceMotion` 传入主题，收敛自动动画；
- 玻璃主要属于导航和重要悬浮控件层，不要给内容区每张卡重复套玻璃；
- 主动作可以 tint，普通动作保留中性玻璃，危险动作仍使用语义危险色。

## 当前渲染边界

第一版已经提供真实的前景几何形变，以及由渐变、薄雾、内外高光、色散边缘和阴影组成的 SDR
高透感模拟。当前 `sdl-readback` adapter 还能在严格像素/数量预算内采样当前帧已绘背景，执行
第一版多采样柔化与镜片取样；`LiquidGlass.paintWithReceipt`、`Renderer.lastEffectReceipt()` 和
Draw IR 会说明实际应用或降级原因。缺少 adapter、旧帧、预算超限、provider 失败或
`reduceTransparency` 时仍使用同一套确定性 SDR/不透明 fallback，不改变 Surface 内容与交互。

首个 provider 的同步 readback 适合少量导航与悬浮控制，不适合无上限列表或全屏堆叠；它尚不支持
多个玻璃形状的 union，并明确返回 `shape-union-unsupported`。详见
[Renderer effects](renderer-effects.md)。macOS SDL 像素证明不等同于 Apple 平台原生材质，也不构成
iOS、Metal、Vulkan、D3D、GLES 或 WebGPU backend 已完成的证明。

设计依据来自 Apple 公开的
[HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、
[Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
与 [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)。包内不含 Apple 资产。
