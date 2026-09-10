[chui](../../index.md) › [chui.controls](index.md) › Chip

# Chip

`chui.controls` 包中的 public class

可选中的过滤标签：绑定 `Bindable<Bool>` 的圆角胶囊，可显示文本或任意装饰性 slot。点击释放在控件内（或聚焦后 Space/Enter）切换选中；按下后移出会永久取消本次动作。

## 声明

```cangjie
public class Chip <: Widget
```

## 继承

- [`Widget`](../core/Widget.md) — 组件协议（measure/layout/draw/handle 与焦点遍历）。

## 说明

Chip 与 [`Checkbox`](Checkbox.md) 共用 release-inside 约定。slot 可组合图标、标题、数量或状态点，但属于装饰子树：外层 Chip 仍是唯一焦点和激活所有者。未显式设色的 Label/Icon/Symbol 继承外层状态样式前景色。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Chip", 640, 420))
    app.run {
        let vegan = rememberState<Bool>("vegan") {false}
        let filter = Chip("素食", vegan)
        // 运行时：点击“素食”筛选筹片可在选中与未选中之间切换。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(text: String, selected: Bindable<Bool>, key!: ?String)`](#init) | 由文本与布尔绑定构造过滤标签。 |
| `init(selected: Bindable<Bool>, key!: ?String, body!: () -> Unit)` | 由装饰 slot 与布尔绑定构造过滤标签。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 按文本/slot、组件 compact padding 与最小高度测量。 |
| `controlStyle(value: ComponentControlStyle)` | 覆盖本 Chip 的共享组件状态样式。 |
| `accessibilityLabel(value: String)` | 为装饰 slot 设置语义名称；文本构造器默认使用 `text`。 |
| `animation(value: AnimationSpec)` | 覆盖 hover/press 动画属性。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配到的框架。 |
| [`isFlexible()`](#isflexible) | 恒返回 `false`——标签贴合内容，不参与栈的剩余空间分配。 |
| [`focusableId()`](#focusableid) | 返回本控件的焦点 id。 |
| [`draw(ctx: UiContext)`](#draw) | 选中画强调色实心胶囊，未选中画描边空心胶囊（悬停加深底色）；键盘聚焦时画外圈焦点环。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 胶囊内按下即翻转绑定值；聚焦时 Space/Enter 同效。 |

## 构造函数

### init

由文本与布尔绑定构造过滤标签。

```cangjie
public init(text: String, selected: Bindable<Bool>, key!: ?String = None)
```

**参数**

- `text`: `String` — 胶囊内的标签文本。
- `selected`: `Bindable<Bool>` — 双向绑定的选中状态。
- `key!`: `?String` — 显式控件标识；空串抛 `IllegalArgumentException`。默认 `None`，按构建顺序自动派生。

## 方法

### measure

按文本或 slot 内容加 [`ComponentTheme`](../core/ComponentTheme.md) 的 compact padding 测量；默认最小高度 28。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录分配到的框架。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### isFlexible

恒返回 `false`——标签贴合内容，不参与栈的剩余空间分配。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `false`，组件按自身请求尺寸参与布局。

### focusableId

返回本控件的焦点 id。构造时已注册为焦点项（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

### draw

选中画强调色实心胶囊，未选中画描边空心胶囊（悬停加深底色）；键盘聚焦时画外圈焦点环。文本颜色随选中态在强调色前景与正文色之间切换。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

胶囊内按下并在内部释放才翻转绑定值；聚焦时 Space/Enter 同效。按下后移出会取消，移回再释放也不会恢复本次动作。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

## 另请参阅

- [Checkbox](Checkbox.md) — 勾选框样式的布尔绑定。
- [Badge](Badge.md) — 外形相近但纯展示的状态标签。
