[chui](../../index.md) › [chui.core](index.md) › ComponentControlStyle

# ComponentControlStyle

`ComponentControlStyle` 为 Chip、Checkbox、Dropdown 闭合面和 Accordion header 提供共享的状态外观解析器。
既可以在单个控件上调用 `controlStyle(...)`，也可以通过 [`ComponentTheme`](ComponentTheme.md) 设置应用默认值。

```cangjie
let navigationControls = ComponentControlStyle(resolve: {
    theme, kind, state =>
    let radius = match (kind) {
        case ComponentControlKind.Chip => 999.0
        case _ => 6.0
    }
    ComponentControlAppearance(
        surface: SurfaceStyle(
            if (state.selected || state.expanded) { theme.accentSoft } else { theme.field },
            border: if (state.focused) { theme.accent } else { theme.panelEdge },
            radius: radius,
            borderWidth: 1.0
        ),
        foreground: theme.text,
        indicator: theme.accent,
        ink: theme.inkColor(),
        focusRadius: radius
    )
})
```

## ComponentControlKind

- `Chip`
- `Checkbox`
- `Dropdown`
- `AccordionHeader`

## ComponentControlState

- `hover`、`press`: `0...1` 的交互动画进度。
- `focused`: 是否持有键盘焦点。
- `selected`: 当前是否被选中。
- `selection`: `0...1` 的选择/展开连续进度；Accordion 用它保留标题底面的展开过渡。
- `expanded`: Dropdown 或 Accordion 当前是否展开。

## ComponentControlAppearance

- `surface`: 控件外层表面；Checkbox 中表示框形 indicator 表面。
- `foreground`: 内建文本内容的前景色。
- `indicator`: Checkbox 选中块、Dropdown/Accordion disclosure 的颜色。
- `ink`: 激活反馈颜色。
- `focusRadius`: 焦点环与 InkWell 裁切圆角。

slot 子树保持自己的文字与图标颜色。样式不会向任意子树隐式传播前景色。
