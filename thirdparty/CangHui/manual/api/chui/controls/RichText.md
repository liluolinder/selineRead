[chui](../../index.md) › [chui.controls](index.md) › RichText

# RichText

`chui.controls` 包中的 public class

行内多样式文本组件：把一串 [`RichSpan`](RichSpan.md)（配色、加粗、变字号的文本段与行内图标）排在同一行内，超出可用宽度自动换行到任意多行。是单一样式 [`Label`](../core/Label.md) 的多样式、带图标对应物，统计大数字、更新日志、可点击链接等混排文本都由它承担。

## 声明

```cangjie
public class RichText <: Widget
```

## 继承

`RichText <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

`RichText` 先从最近容器的 [`TypographyEnvironment`](../core/TypographyEnvironment.md) 取得基准字族、字号和样式，再由组件显式字号以及各 [`RichSpan`](RichSpan.md) 显式字段逐项覆盖。未自带字号的片段继承有效基准字号；`.bold(value: false)` 只清除继承粗体，`.fontStyle(FontStyle.regular)` 显式清除四项继承样式。同一行内不同字号的片段相互居中，行高随最高片段增长。仍未指定的值回退到主题字族、15 fp 与 Regular。

换行按文字习惯处理：CJK 逐字可断，空格分隔的文字回退到空格处断行，行中开始的 ASCII 词（标识符、议题号）放得进一行时整词移到下一行、绝不拦腰截断；图标作为方形盒随文字流动。

带 [`onTap`](RichSpan.md#ontap) 的链接片段可交互：按下并在同一片段盒上松开触发动作、悬停显示交互指针；每个链接片段按声明序注册为键盘焦点项，Tab 依次走过、Enter/Space 激活，键盘聚焦的链接画焦点环。不含链接的 `RichText` 不注册、不分配任何交互结构，保持纯静态。

测量语义：内容只占一行时贴合内容宽（行内嵌进横排容器时按内容收身），一旦换行即充满可用宽度。排版结果按宽度、有效字号、样式、字族与显示缩放缓存，测量、绘制和链接命中共用，不逐帧重排。换行后的水平对齐由 [`textAlign(...)`](#textalign) 控制（默认 Leading），按行实测宽度逐行偏移；对齐只影响绘制与链接命中盒，不改变测量与换行。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("RichText", 640, 420))
    app.run {
        let opened = rememberState<Int64>("opened") {0}
        let notice = RichText(
            [
                RichSpan.text("同步完成，"),
                RichSpan.text("查看详情").underline().onTap({=> opened.value = opened.value + 1})
            ]
        )
        Label("链接已触发 ${opened.value} 次").muted()
        // 运行时：点击“查看详情”片段触发动作，普通片段只参与排版。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以片段序列与可选基准字号构造多样式文本。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`fontSize(...)`](#fontsize) | 设置未自带字号的片段共享的基准字号。 |
| [`textAlign(value: TextAlign)`](#textalign) | 设置换行后各行在框架内的水平对齐：Leading（默认）/ Center / Trailing。 |
| [`lineSpacing(value: Float32)`](#linespacing) | 设置相邻换行之间的间距，默认与 Label 一致。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 单行时贴合内容宽、换行后充满可用宽；高度随行内最大字号增长且不低于基准行高。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录文本框架。 |
| [`draw(ctx: UiContext)`](#draw) | 逐片段画高亮底、文字或图标，给键盘聚焦的链接片段画焦点环；内容块垂直居中，与 Label 同行时基线对齐。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 链接片段上按下并松开触发其动作、悬停申请交互指针，Enter/Space 激活聚焦链接；无链接时恒不消费。 |
| [`focusableIds()`](#focusableids) | 按声明序返回每个链接片段的焦点项；无链接时为空。 |

## 构造函数

### init

以片段序列与可选基准字号构造多样式文本。

```cangjie
public init(
    spans: Array<RichSpan>,
    fontSize!: ?Length = None,
    key!: ?String = None
)
```

**参数**

- `spans`: `Array<RichSpan>` — 按序排布的片段。
- `fontSize!`: `?`[`Length`](../core/Length.md) — 显式基准字号；默认 `None`，先继承容器字号，仍未提供时使用 15 fp。
- `key!`: `?String` — 显式标识，作链接片段焦点与按压追踪的作用域；默认 `None`，按构建顺序自动派生。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### fontSize

设置组件的显式基准字号，覆盖容器继承字号；未自带字号的片段共享该值。两个重载分别接受带单位的 `Length` 与字体像素（fp）数值。

```cangjie
public func fontSize(value: Length): RichText
```

```cangjie
public func fontSize(value: Float32): RichText
```

**参数**

- `value`: [`Length`](../core/Length.md) — `Length` 重载接收带单位的基准字号；`Float32` 重载接收字体像素（fp）数值，随用户字体缩放。

**返回值** `RichText` — 返回自身以便链式调用。

### lineSpacing

设置相邻换行之间的逻辑像素间距，默认 `2.0`，只作用于行与行之间；单行内容不受影响。该属性与 `textAlign`、链接绘制及命中共用同一份布局几何。

```cangjie
public func lineSpacing(value: Float32): RichText
```

`value` 必须是非负有限值，否则抛出 `IllegalArgumentException`。返回自身以便链式调用。

### textAlign

设置换行后各行在框架内的水平对齐，默认 `Leading`。对齐按行计算：每行用自己实测的行宽偏移，`Center` 使各行居中、`Trailing` 右对齐，行宽超出框架时该行不偏移、绝不出现在框架左侧。`Leading`/`Trailing` 是方向无关语义，不折叠成 Left/Right，为未来 RTL 排版方向保留同一枚举。对齐只影响绘制与链接命中盒，不改变测量与换行结果。

```cangjie
public func textAlign(value: TextAlign): RichText
```

**参数**

- `value`: [`TextAlign`](../core/TextAlign.md) — `Leading`（默认，靠前）/ `Center`（居中）/ `Trailing`（靠后）。

**返回值** `RichText` — 返回自身以便链式调用。

### measure

单行时贴合内容宽、换行后充满可用宽；高度随行内最大字号增长且不低于基准行高。单行与否按行数判断——一行里孤立的大字号片段仍按单行收身（统计组件“大数值 + 小单位”的典型场景）。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录文本框架。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

逐片段画高亮底、文字或图标，给键盘聚焦的链接片段画焦点环；内容块垂直居中，与 [`Label`](../core/Label.md) 同行时基线对齐。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

链接片段上按下并松开触发其动作、悬停申请交互指针，Enter/Space 激活聚焦链接；无链接时恒不消费。按下同时把该链接设为焦点锚（不画环），与按钮的按下-释放语义一致。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableIds

按声明序返回每个链接片段的焦点项；无链接时为空。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 各可点击链接用于参与键盘焦点导航的标识。

## 另请参阅

- [RichSpan](RichSpan.md) — 片段的构建工厂与链式样式配置。
- [Label](../core/Label.md) — 单一样式的普通文本。
- [TypographyEnvironment](../core/TypographyEnvironment.md) — 容器提供的逐字段排版环境。
