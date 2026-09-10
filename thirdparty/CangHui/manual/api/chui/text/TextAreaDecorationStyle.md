[chui](../../index.md) › [chui.text](index.md) › TextAreaDecorationStyle

# TextAreaDecorationStyle

`chui.text` 包中的 public struct

描述 `TextArea` 字节范围的绘制样式。任一字段为 `None` 时保留控件原有主题值或不绘制该效果。

## 声明

```cangjie
public struct TextAreaDecorationStyle {
    public let foreground: ?Color
    public let background: ?Color
    public let underline: ?Color
    public let underlineShape: TextAreaUnderlineShape

    public init(
        foreground!: ?Color = None,
        background!: ?Color = None,
        underline!: ?Color = None,
        underlineShape!: TextAreaUnderlineShape = TextAreaUnderlineShape.Straight
    )
}
```

- `foreground`: 字形颜色；`None` 使用主题文本色。
- `background`: 文本范围背景色；`None` 不绘制。
- `underline`: 紧贴字形底部的下划线颜色；`None` 不绘制。
- `underlineShape`: 下划线形状；`Straight` 保持兼容直线，`Wave` 绘制确定性且有段数上限的诊断波浪线。

背景位于选区之下，字形和下划线位于选区之上，光标最后绘制。

## 相关 API

[`TextAreaDecoration`](TextAreaDecoration.md)、[`TextAreaDecorationSnapshot`](TextAreaDecorationSnapshot.md)、[`TextArea`](TextArea.md)。
