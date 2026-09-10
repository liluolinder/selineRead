[chui](../../index.md) › [chui.core](index.md) › ButtonStyle

# ButtonStyle

`ButtonStyle` 将主题、[`ButtonRole`](ButtonRole.md) 和连续交互状态解析为按钮外观。应用可以在单个
`Button` / `IconButton` 上调用 `buttonStyle`，也可以通过 [`ComponentTheme`](ComponentTheme.md)
一次覆盖全应用默认按钮外观。

紧凑命令行优先直接使用 `ButtonStyle.quiet()`：空闲状态无填充和描边，悬停、按下、焦点与
语义角色颜色仍由当前主题解析。它是通用样式而非工具栏容器，通常与 `Row + IconButton` 组合：

```cangjie
Row(space: 4.vp) {
    IconButton(IconName.OpenFolder) {=> open()}.buttonStyle(ButtonStyle.quiet())
    IconButton(IconName.Save) {=> save()}.buttonStyle(ButtonStyle.quiet())
}
```

```cangjie
let flat = ButtonStyle(resolve: {
    theme, role, state =>
    let base = theme.buttonSurface(role)
    ButtonAppearance(
        surface: SurfaceStyle(
            base.fill.lerp(theme.accentText, state.hover * 0.08),
            border: base.border,
            radius: 4.0,
            borderWidth: base.borderWidth
        ),
        foreground: match (role) {
            case ButtonRole.Normal => theme.text
            case _ => theme.accentText
        },
        ink: theme.inkColor(role: role),
        focusRadius: 4.0
    )
})
```

## ButtonVisualState

- `hover`: `0...1` 的悬停动画进度。
- `press`: `0...1` 的按压动画进度。
- `focused`: 按钮当前是否拥有焦点。

## ButtonAppearance

- `surface`: 外层填充、描边、圆角和阴影。
- `foreground`: 标题 Button 与 IconButton 的文字/图标颜色。
- `ink`: 指针或键盘激活产生的 InkWell 颜色。
- `focusRadius`: 焦点环与 InkWell 裁切圆角。

slot Button 的子树保持自己的文字和图标颜色；`ButtonAppearance.foreground` 不会隐式改写任意子树。

不要把 `foreground` 固定成白色：浅色或低明度差 accent 会产生“浅底白字”。强调角色应使用
`theme.accentText`，普通角色使用 `theme.text`，Ink 使用 `theme.inkColor(role: role)`。外观密度与布局
密度是两件事；`ButtonStyle.quiet()` 只改变绘制，不缩短 38 vp 的常规按钮基线。紧凑桌面按钮应同时
显式调用 `minControlSize(width: 0.0, height: 28.0)`，并保留可读的水平 `contentPadding`。
