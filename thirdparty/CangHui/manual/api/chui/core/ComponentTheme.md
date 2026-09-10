[chui](../../index.md) › [chui.core](index.md) › ComponentTheme

# ComponentTheme

`ComponentTheme` 是 [`Theme`](Theme.md) 的组件级覆盖层。它保留背景、文字、强调色等语义 Token，
同时允许产品改变 Button、选择/披露控件的状态外观、组件排版/间距/形状和 Panel 默认表面，避免每个调用点重复传入同一套样式。

```cangjie
let productTheme = Theme.light().withComponents(ComponentTheme(
    buttonStyle: Some(productButtonStyle()),
    buttonLayout: ButtonLayoutStyle(
        contentPadding: LengthInsets(18.vp, 10.vp),
        minWidth: 88.0,
        minHeight: 44.0
    ),
    controlStyle: Some(navigationControlStyle()),
    typography: ComponentTypography(control: 16.fp),
    spacing: ComponentSpacing(controlMinHeight: 44.0, inlineGap: 10.vp),
    shape: ComponentShape(controlRadius: Some(6.0), pillRadius: Some(18.0)),
    panelSurface: Some(SurfaceStyle(
        Color.rgb(250, 250, 247),
        border: Color.rgba(0, 0, 0, 0),
        radius: 2.0
    ))
))
```

## 字段

- `buttonStyle`: 可选 [`ButtonStyle`](ButtonStyle.md)，同时作用于 Button 与 IconButton。
- `buttonLayout`: 标题/slot Button 的默认内边距与最小尺寸。
- `panelSurface`: 可选 Panel 默认表面；单个 `Panel.style(...)` 仍可覆盖它。
- `controlStyle`: 可选 [`ComponentControlStyle`](ComponentControlStyle.md)，作用于 Chip、Checkbox、Dropdown 与 Accordion header。
- `typography`: `ComponentTypography(control)`，为这些库存控件提供统一的语义字号。
- `spacing`: `ComponentSpacing`，包含 compact/control/selection 内边距、inline gap、最小高度和 indicator 尺寸。
- `shape`: `ComponentShape`，可覆盖 small/control/pill 圆角；未提供的值继承 Theme。
- `segmentedControlStyle`: 可选 [`SegmentedControlStyle`](SegmentedControlStyle.md)，只替换库存
  SegmentedControl/TabView 的选中镜片绘制、前景解析和形变量；控件继续拥有输入、焦点与布局。

## ButtonLayoutStyle

`ButtonLayoutStyle(contentPadding, minWidth, minHeight)` 默认使用水平 12 vp、垂直 0 vp、最小宽度 72、
最小高度 38。单个 Button 可用 `contentPadding` 与 `minControlSize` 覆盖这些默认值。

## Decorative Slots

Button、Chip、Checkbox、Dropdown 闭合面与 Accordion header 的 slot 都是装饰子树。外层控件独占焦点、
指针捕获、release-inside 激活、move-out 取消和键盘动作；slot 中误放的可聚焦控件不会进入 Tab 环或收到事件。
真正的复合控件需要另行定义焦点、事件与无障碍契约。
