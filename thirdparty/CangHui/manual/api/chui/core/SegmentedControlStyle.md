[chui](../../index.md) › [chui.core](index.md) › SegmentedControlStyle

# SegmentedControlStyle

`SegmentedControlStyle` 是库存 [`SegmentedControl`](../controls/SegmentedControl.md) 与
[`TabView`](../controls/TabView.md) 共用的选中镜片样式。它不创建新控件：库存控件继续拥有等宽布局、
点击/键盘输入、绑定、焦点和语义，只把镜片矩形与标签前景交给样式解析。

```cangjie
public class SegmentedControlStyle
```

## 构造

```cangjie
public init(
    deformation!: Float32 = 0.0,
    paintIndicator!: (UiContext, Rect, SegmentedControlVisualState) -> Unit,
    foreground!: (Theme, Bool) -> Color
)
```

- `deformation`：0..1。0 保持单段宽度，1 完整采用独立快/慢弹簧前后缘形成的伸展矩形；越界值会截断。
- `paintIndicator`：绘制已由控件限制在行内的镜片矩形。
- `foreground`：按当前主题与是否为目标段返回标签颜色。

单控件调用 `.indicatorStyle(style)` 的优先级高于
`Theme.components.segmentedControlStyle`。没有提供样式时，控件保持原有 `selectedSurface()` 路径。

## SegmentedControlVisualState

```cangjie
public struct SegmentedControlVisualState
```

字段包括：

- `animatedIndex`：普通滑动弹簧的当前分数下标；
- `targetIndex`：绑定目标下标；
- `stretch`：0..1 的实时伸展量；
- `movingForward`：目标是否位于当前动画位置的正方向。

材质包可让高光宽度、边缘能量等随 `stretch` 改变，但不要在 painter 中再次实现点击或焦点。
