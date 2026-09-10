[chui](../../index.md) › [chui.core](index.md) › Surface

# Surface

`Surface` 是只负责装饰组合的 public class：解析主题 material、绘制背景/边框/阴影、发布前景环境，
但不创建新的焦点、按压、动作或语义所有者。

```cangjie
public class Surface <: Widget
```

## 示例

```cangjie
Surface(
    shape: Shape.rounded(12.0),
    material: Materials.solid(Color.rgb(236, 241, 248)),
    clip: ClipPolicy.Shape
) {
    VStack(spacing: 6.vp) {
        Label("构建完成").bold()
        Label("Surface 不会吞掉子组件事件").muted()
    }.padding(14.0)
}
```

Surface 的 `handle`、焦点列表、弹性和布局参与信息都透明转发给 child。因此 `Surface { Button(...) }`
仍由 Button 独占交互；若需要让任意装饰内容本身成为一个动作面，请使用
[`InteractionSurface`](InteractionSurface.md)。

## 构造函数

```cangjie
public init(
    shape!: Shape = Shape.rectangle(),
    material!: MaterialProvider = Materials.themeSurface(),
    painter!: ?SurfacePainter = None,
    clip!: ClipPolicy = ClipPolicy.Unclipped,
    body!: () -> Unit
)
```

`shape` 决定背景几何，`material` 根据 Theme/SurfaceState 返回完整外观，`painter` 可选地只替换背景
绘制，`clip` 决定是否把 child 约束在表面外框中。也可用 `shape(value)`、`material(value)`、
`painter(value)`、`clip(value)` 链式替换。

## Shape

```cangjie
public struct Shape
```

P0 提供 `Shape.rectangle()` 与 `Shape.rounded(radius)`，并通过 `cornerRadius()` 暴露当前解析半径。
这是矩形/圆角矩形契约，不表示任意矢量路径已经实现。

## ClipPolicy

```cangjie
public enum ClipPolicy {
    | Unclipped
    | Shape
}
```

`Unclipped` 不限制 child；`Shape` 使用 renderer 的嵌套 clip 栈约束 child 外框。背景/material 始终按
Shape 的圆角绘制；[`InteractionSurface`](InteractionSurface.md) 的 Ink 使用同一半径，并由 renderer
按精确圆角轮廓裁剪，因此圆角动作面不会泄漏矩形 ripple。任意路径内容裁剪仍是后续能力。

## SurfaceState

`SurfaceState` 是 material 的只读输入，字段为 `enabled`、`readOnly`、`selected`、`expanded`、
`focused`、`hovered`、`pressed`。普通 Surface 只发布当前 enabled 状态；InteractionSurface 发布完整状态。

## SurfaceMaterial

`SurfaceMaterial` 包含：

- `style: SurfaceStyle`：填充、边框、阴影等绘制数据；最终圆角由 Shape 统一决定；
- `foreground` 与 `supportingForeground`：装饰 child 的继承颜色；
- `ink`：交互面使用的 InkWell 颜色。

## MaterialProvider 与 Materials

```cangjie
public interface MaterialProvider {
    func resolve(theme: Theme, state: SurfaceState): SurfaceMaterial
}
```

`Materials.solid(Color)`、`Materials.solid(SurfaceStyle)`、`Materials.themeSurface()` 与
`Materials.themePrimary()` 是当前内置 provider。自定义 provider 可以根据 Theme 与交互状态改变外观，
但不能自行拥有指针、焦点或语义动作。

## SurfacePainter

```cangjie
public class SurfacePainter
```

`SurfacePainter(paint: (UiContext, Rect, Shape, SurfaceMaterial) -> Unit)` 是低层背景绘制钩子。它适合
可选效果包在同一个 `Surface` 中绘制多层 SDR 光学、平台效果降级或调试覆盖；Surface 仍从 material
取得前景/辅助前景与 Ink，仍拥有 child 布局、clip 和透明事件转发。painter 不应重复实现 Surface，
也不能把装饰面变成新的交互 owner。

`Surface` 核心不内置 Liquid Glass 产品策略、平台原生代理或低功耗策略。二维 renderer 提供可选的
`BackdropEffectRequest` / `RendererEffectAdapter` / `RendererEffectReceipt` seam，效果包可在 painter 中
尝试采样当前帧背景；能力缺失、旧帧、预算超限或无障碍偏好仍由 provider/style 包保留确定性的
fallback。参见 [Renderer effects](../../../reference/renderer-effects.md)。
