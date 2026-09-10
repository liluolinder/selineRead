[chui](../../index.md) › [chui.core](index.md) › TypographyEnvironment

# TypographyEnvironment

`chui.core` 包中的 public struct

容器传给后代语义文本的逐字段排版环境：字族、字号，以及粗体、斜体、下划线和删除线。每个字段都可独立省略，内层只覆盖自己提供的字段。

## 声明

```cangjie
public struct TypographyEnvironment
```

## 说明

环境由 [`Widget.typography`](Widget.md#typography) 或便捷修饰器 `fontFamily` / `fontSize` / `fontStyle` / `bold` / `italic` / `underline` / `strikethrough` 作用于一棵子树。最近的内层环境逐字段覆盖外层；没有提供的字段继续继承。首批消费此环境的语义文本叶子是 [`Label`](Label.md)、[`RichText`](../controls/RichText.md) 与其中的 [`RichSpan`](../controls/RichSpan.md)。自绘控件不会仅因位于该容器内就自动改变其内部文字。

叶子的显式配置优先于环境，而且同样逐字段生效。例如片段 `.bold(value: false)` 只清除继承的粗体，不影响继承的斜体；`.fontStyle(FontStyle.regular)` 则显式清除四个样式字段。未被环境或叶子指定的字号回退到 15 fp，字族回退到主题字体，样式回退到 Regular。

环境覆盖组件的 `measure`、`layout`、`draw` 与 `handle` 全阶段，因而文字测量、绘制、换行缓存和富文本链接命中使用同一组有效值。经 [`UiContext.setOverlay`](UiContext.md#setoverlay) 登记的浮层捕获登记位置的有效环境，延迟绘制与事件派发不会丢失声明上下文。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let panel = VStack {
        Label("继承 22fp 粗体")
        Surface {
            RichText([
                RichSpan.text("继承粗体；"),
                RichSpan.text("显式常规 14fp").fontStyle(FontStyle.regular).fontSize(14.0)
            ])
        }
    }.fontSize(22.fp).bold()

    let ctx = UiContext(Renderer.headless(), Theme.light())
    let size = panel.measure(ctx, Size(640.0, 480.0))
    println("容器宽 ${Int64(size.w)}")
}
```

## 构造函数

```cangjie
public init(
    fontFamily!: ?String = None,
    fontSize!: ?Length = None,
    bold!: ?Bool = None,
    italic!: ?Bool = None,
    underline!: ?Bool = None,
    strikethrough!: ?Bool = None
)
```

所有参数都表示可选覆盖；`None` 不是“恢复默认”，而是继续继承。

## 方法

### merging

把更深一层 `overrides` 逐字段覆盖到当前环境，返回新值；当前值与参数都不变。

```cangjie
public func merging(overrides: TypographyEnvironment): TypographyEnvironment
```

### resolvedFontStyle

返回完整 `FontStyle`；环境里仍为 `None` 的样式字段按 `false` 解析。

```cangjie
public func resolvedFontStyle(): FontStyle
```

### withFontFamily / withFontSize

返回只替换相应字段的新环境。

```cangjie
public func withFontFamily(value: String): TypographyEnvironment
public func withFontSize(value: Length): TypographyEnvironment
```

### withFontStyle

用完整 `FontStyle` 替换四个样式字段。传入 `FontStyle.regular` 会显式清除继承样式。

```cangjie
public func withFontStyle(value: FontStyle): TypographyEnvironment
```

### withBold / withItalic / withUnderline / withStrikethrough

分别覆盖一个样式字段，不改动其他字段；省略 `value` 时为 `true`，传 `false` 可显式清除该项继承值。

```cangjie
public func withBold(value!: Bool = true): TypographyEnvironment
public func withItalic(value!: Bool = true): TypographyEnvironment
public func withUnderline(value!: Bool = true): TypographyEnvironment
public func withStrikethrough(value!: Bool = true): TypographyEnvironment
```

## 字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `fontFamily` | `?String` | 已注册字体名；`None` 继续继承。 |
| `fontSize` | `?Length` | 字号；`None` 继续继承。 |
| `bold` | `?Bool` | 粗体覆盖；`Some(false)` 显式关闭。 |
| `italic` | `?Bool` | 斜体覆盖；`Some(false)` 显式关闭。 |
| `underline` | `?Bool` | 下划线覆盖；`Some(false)` 显式关闭。 |
| `strikethrough` | `?Bool` | 删除线覆盖；`Some(false)` 显式关闭。 |

## 另请参阅

- [Widget](Widget.md) — 声明式容器修饰器入口。
- [UiContext](UiContext.md) — 有效环境的查询与作用域协议。
- [Label](Label.md) — 单样式语义文本叶子。
- [RichText](../controls/RichText.md) — 可逐片段覆盖环境的富文本叶子。
