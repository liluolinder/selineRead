[chui](../../index.md) › [chui.text](index.md) › TextArea

# TextArea

`chui.text` 包中的 public class

多行文本编辑控件：把编辑写回绑定的 `Bindable<String>`，显式采用一逻辑行一视觉行的 no-wrap 契约，带双轴滚动与右缘/底缘滚动条，行间导航按字节列对齐。沿用单行编辑的全部桌面惯例（多击选择、Ctrl 快捷键表、分组撤销），文档的行拆分与最宽逻辑行按文本修订和字体度量缓存，不会每帧重扫整篇文本；绑定可以是 [`State`](../core/State.md)，也可以是任何 [`Bindable`](../core/Bindable.md) 实现。

## 声明

```cangjie
public class TextArea <: Widget
```

## 继承

`TextArea <: Widget` — 实现组件接口 [`Widget`](../core/Widget.md)。

## 说明

- **字节偏移语义**：与 [`TextField`](TextField.md) 相同，光标与选区锚点是 UTF-8 字节偏移。从外部接管 `cursor` 后再从外部移动它（加载文件、程序化粘贴）时必须连同 `anchor` 一起移动，否则陈旧锚点会张开一段用户从未做过的选区，下一次按键将整段替换。完整的编辑操作见 [`TextEditState`](TextEditState.md)。
- **键盘表**：方向键按字符移动，Up/Down 跨行且尽量保持字节列；Home/End 移到**行**首尾（单行控件则是全文首尾）；Enter 插入换行；按住 Shift 的所有导航键扩展选区；Ctrl+A/C/X/V/Z/Y 与 Ctrl+Shift+Z 同单行控件。
- **只读模式**：`editable: false` 时仍可移动光标、选择和复制；Ctrl+X 只复制而不删除，粘贴与撤销/重做会被忽略，控件不进入 Tab 焦点遍历。
- **嵌入式表面**：`chrome: TextAreaChrome.None`（或链式 `.chrome(...)`）只移除默认字段底色与描边；文本、选区、滚动条及共享 `scroll` 状态保持不变，适合编辑器行号和日志分栏。
- **逻辑行契约**：`wrapMode: TextAreaWrapMode.NoWrap` 是当前唯一支持的模式，也是默认值。视口变窄不会把一个逻辑源代码行拆成多个视觉行；软换行和“逻辑行到视觉行”投影尚未提供，框架不会用一个看似可选但实际不完整的布尔开关暗示它们存在。
- **双轴滚动**：`scroll` 是垂直偏移，`horizontalScroll` 是横向偏移；两者都可外部接管。触控板/侧倾滚轮的水平分量直接横移，Shift+垂直滚轮也横移，普通垂直滚轮仍纵向滚动。内容装得下时事件让给外层，不留死区。键盘编辑、导航与外部光标变化以最小距离让光标在两轴可见。
- **统一坐标平面**：普通/装饰文本、装饰背景、选区、光标、IME 锚点和指针命中都减去或加回同一个 `horizontalScroll`；应用不应自行平移其中一层。
- **IME 预编辑**：SDL 文本组合事件通过 [`TextCompositionSnapshot`](TextCompositionSnapshot.md) 进入控件。预编辑文本只在光标处临时绘制并更新候选框锚点，不写入绑定文本、撤销栈或文档修订；最终 `TextInput`/`Commit` 只替换捕获时的 UTF-8 字节选区一次。失焦、外部文档修订、指针跳转和普通编辑都会取消陈旧组合。
- **无障碍语义**：`.accessibilityLabel(...)` 为编辑区提供稳定名称；语义树同时公开正式文本值、焦点、可编辑/只读状态及 UTF-8 字节选区。只读区域保留可读值，但不会声明编辑动作。
- **滚动指示器**：`.verticalScrollBar(false)` / `.horizontalScrollBar(false)` 只隐藏对应滑块，不禁用滚动。行号 gutter 可共享正文的 `scroll` 并隐藏自己的指示器，由正文保留唯一可见滚动条。
- **粘贴换行处理**：保留多行内容，但把 Windows 的 CRLF 和单独的 CR 统一为 `\n`；否则行尾残留的 `\r` 会干扰 End、退格和文字测量。剪贴板不可用时复制/粘贴会静默失败，不会让控件退出。
- **撤销**：与单行控件相同——500 毫秒内连续编辑合并一步、光标跳转切分撤销组、栈上限 300 步；撤销/重做后自动滚动到光标行。
- **绘制装饰**：`decorations` 接收 [`Observable`](../core/Observable.md)`<TextAreaDecorationSnapshot>`，用于语法高亮、诊断标记或搜索命中。范围是精确的 UTF-8 字节边界；无效范围被忽略，快照修订号与文本不同时回退为普通文本绘制。装饰只影响画面，不接管 tokenizer、文本、光标、IME 或撤销栈。
- **绘制层级**：装饰背景 → 选区 → 字形/下划线 → 光标。重叠范围按输入顺序“后者覆盖前者”；归一化结果按文本修订、装饰修订和当前可见逻辑行窗口缓存。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("TextArea", 640, 420))
    app.run {
        let draft = rememberState<String>("draft") {"会议纪要"}
        let horizontal = rememberState<Float32>("draft-x") {0.0}
        let area = TextArea(draft, horizontalScroll: Some(horizontal),
            wrapMode: TextAreaWrapMode.NoWrap).autofocus()
        // 运行时：在多行编辑区输入、换行并滚动，绑定文本实时更新。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 构造多行编辑区，并把它注册进当前声明式构建块。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`autofocus()`](#autofocus) | 可编辑区域首次出现时申请键盘焦点，返回自身以便链式声明。 |
| [`undo()`](#undo) | 回退最近一组编辑；同时绑定在 Ctrl+Z。 |
| [`redo()`](#redo) | 重做最近撤销的编辑；同时绑定在 Ctrl+Y 与 Ctrl+Shift+Z。 |
| [`scrollOptions(value: ScrollOptions)`](#scrolloptions) | 选择平滑/即时滚轮行为，并配置步长、时长与曲线。 |
| [`horizontalScrollState(value: State<Float32>)`](#horizontalscrollstate) | 改用外部持有的横向偏移。 |
| [`wrapMode(value: TextAreaWrapMode)`](#wrapmode) | 显式选择逻辑行布局；当前支持 `NoWrap`。 |
| [`verticalScrollBar(visible: Bool)`](#verticalscrollbar) | 显示或隐藏纵向滚动指示器，不禁用滚动。 |
| [`horizontalScrollBar(visible: Bool)`](#horizontalscrollbar) | 显示或隐藏横向滚动指示器，不禁用滚动。 |
| [`chrome(value: TextAreaChrome)`](#chrome) | 选择普通字段外观或无框嵌入式表面。 |
| [`decorations(value: Observable<TextAreaDecorationSnapshot>)`](#decorations) | 更换与文档修订绑定的绘制装饰源。 |
| [`accessibilityLabel(value: String)`](#accessibilitylabel) | 设置供无障碍树和无图审计使用的稳定名称。 |
| [`measure(...)`](#measure) | [`Widget`](../core/Widget.md) 协议实现：占满全部可用空间。 |
| [`layout(...)`](#layout) | [`Widget`](../core/Widget.md) 协议实现：记录分配的框架矩形，供绘制与命中测试使用。 |
| [`draw(...)`](#draw) | [`Widget`](../core/Widget.md) 协议实现：绘制底框、选区、可见行、光标与右缘滚动条。 |
| [`handle(...)`](#handle) | [`Widget`](../core/Widget.md) 协议实现：处理滚动条与滚轮、定位与多击选择、字符输入、Enter 换行、编辑导航键及 Ctrl 快捷键表。 |
| [`isFlexible()`](#isflexible) | [`Widget`](../core/Widget.md) 协议实现：返回 `true`，在栈布局中参与剩余空间分配。 |
| [`focusableId()`](#focusableid) | [`Widget`](../core/Widget.md) 协议实现：可编辑时返回控件标识，只读区域返回 `None`。 |

## 构造函数

### init

构造多行编辑区，并把它注册进当前声明式构建块。

```cangjie
public init(
    text: Bindable<String>,
    key!: ?String = None,
    scroll!: ?State<Float32> = None,
    horizontalScroll!: ?State<Float32> = None,
    cursor!: ?State<Int64> = None,
    anchor!: ?State<Int64> = None,
    composition!: ?State<TextCompositionSnapshot> = None,
    editable!: Bool = true,
    chrome!: TextAreaChrome = TextAreaChrome.Field,
    wrapMode!: TextAreaWrapMode = TextAreaWrapMode.NoWrap,
    decorations!: ?Observable<TextAreaDecorationSnapshot> = None
)
```

**参数**

- `text`: `Bindable<String>` — 被编辑的文档；每次输入、粘贴与撤销都直接写回该绑定。
- `key!`: `?String` — 显式控件标识；默认 `None`，按声明顺序自动派生。需要编辑状态跨结构变化保留时传入稳定键。
- `scroll!`: `?State<Float32>` — 外部接管的垂直滚动偏移，逻辑像素；默认 `None`，控件在自身标识下保留。
- `horizontalScroll!`: `?State<Float32>` — 外部接管的横向滚动偏移，逻辑像素；默认 `None`，控件按自身标识保留。
- `cursor!`: `?State<Int64>` — 外部接管的光标字节偏移；默认 `None`，初值在文本末尾。
- `anchor!`: `?State<Int64>` — 外部接管的选区锚点字节偏移；默认 `None`，初值与光标重合（无选区）。接管时必须与 `cursor` 成对移动。
- `composition!`: `?State<TextCompositionSnapshot>` — 默认 `None`；外部可观察的非持久化 IME 组合状态。应用通常不需要直接写入；宿主组合事件由控件更新它。
- `editable!`: `Bool` — 默认 `true`；传 `false` 渲染为只读：可导航选择复制，不可编辑，不进入 Tab 焦点遍历。
- `chrome!`: `TextAreaChrome` — 默认 `Field`；传 `None` 不绘制默认字段底色和描边。
- `wrapMode!`: [`TextAreaWrapMode`](TextAreaWrapMode.md) — 默认且当前唯一支持 `NoWrap`。
- `decorations!`: `?Observable<TextAreaDecorationSnapshot>` — 默认 `None`；可传 `State` 或 `DerivedState` 发布的不可变装饰快照。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### autofocus

可编辑区域首次出现时申请键盘焦点，返回自身以便链式声明。焦点在该帧的指针事件之后一次性生效并显示焦点环；只读区域的申请被忽略。

```cangjie
public func autofocus(): TextArea
```

**返回值** `TextArea` — 控件自身。

### accessibilityLabel

设置编辑区在无障碍树、语义快照与 CUIC 无图审计中的稳定名称。空字符串会移除显式名称。

```cangjie
public func accessibilityLabel(value: String): TextArea
```

**返回值** `TextArea` — 控件自身。

### undo

回退最近一组编辑；同时绑定在 Ctrl+Z。回退后自动滚动到光标所在行；没有可回退的编辑时调用无效果。

```cangjie
public func undo(): Unit
```

### redo

重做最近撤销的编辑；同时绑定在 Ctrl+Y 与 Ctrl+Shift+Z。任何新编辑都会清空重做栈；没有可重做的编辑时调用无效果。

```cangjie
public func redo(): Unit
```

### scrollOptions

为文本区滚轮输入选择共享策略；默认 `ScrollOptions.web()`。

```cangjie
public func scrollOptions(value: ScrollOptions): TextArea
```

**参数** `value`: [`ScrollOptions`](../core/ScrollOptions.md) — 行为、步长、时长与曲线。

**返回值** `TextArea` — 本文本区自身，用于链式调用。

### chrome

选择普通字段外观或无框嵌入式表面；不改变文本视口、滚动和编辑语义。

```cangjie
public func chrome(value: TextAreaChrome): TextArea
```

**参数** `value`: `TextAreaChrome` — `Field` 或 `None`。

**返回值** `TextArea` — 本文本区自身，用于链式调用。

### horizontalScrollState

改用外部持有的横向逻辑像素偏移，适合恢复编辑器位置或与其他视图联动。

```cangjie
public func horizontalScrollState(value: State<Float32>): TextArea
```

### wrapMode

显式选择逻辑行布局。当前只提供 `TextAreaWrapMode.NoWrap`；该枚举为未来增加完整软换行契约保留类型安全的扩展面。

```cangjie
public func wrapMode(value: TextAreaWrapMode): TextArea
```

### verticalScrollBar

显示或隐藏纵向滚动指示器；隐藏不禁用滚轮、共享状态或光标揭示。

```cangjie
public func verticalScrollBar(visible: Bool): TextArea
```

### horizontalScrollBar

显示或隐藏横向滚动指示器；隐藏不禁用滚轮、共享状态或光标揭示。

```cangjie
public func horizontalScrollBar(visible: Bool): TextArea
```

### decorations

更换绘制装饰源；不改变文本、光标、选区、IME 和撤销的所有权。

```cangjie
public func decorations(value: Observable<TextAreaDecorationSnapshot>): TextArea
```

**参数** `value`: `Observable<TextAreaDecorationSnapshot>` — 应用生成的、与当前文本修订号绑定的不可变快照。

**返回值** `TextArea` — 本文本区自身，用于链式调用。

如果快照过期，本帧安全回退为普通文本绘制；应用下次发布当前修订的快照即可恢复。

### measure

[`Widget`](../core/Widget.md) 协议实现：占满全部可用空间。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

[`Widget`](../core/Widget.md) 协议实现：记录分配的框架矩形，供绘制与命中测试使用。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

[`Widget`](../core/Widget.md) 协议实现：绘制底框、选区、可见逻辑行、光标与双轴滚动条。先把两轴偏移限制在内容范围（仅在变化时写回）；聚焦时上报已经横向平移的 IME 光标锚点并维持光标闪烁。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

[`Widget`](../core/Widget.md) 协议实现：处理双轴滚动条与滚轮、定位与多击选择、字符输入、Enter 换行、编辑导航键及 Ctrl 快捷键表。水平分量优先横移，Shift+垂直滚轮横移，普通垂直分量纵向滚动；只读区域不申请文本光标形状。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### isFlexible

[`Widget`](../core/Widget.md) 协议实现：返回 `true`，在栈布局中参与剩余空间分配。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `true`，组件可参与父布局的弹性空间分配。

### focusableId

[`Widget`](../core/Widget.md) 协议实现：可编辑时返回控件标识，只读区域返回 `None`。只读区域从未注册焦点项，无需被 `.enabled(false)` 摘除。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 可编辑时返回参与键盘焦点导航的标识；只读文本区返回 `None`。

## 另请参阅

- [TextField](TextField.md) — 单行变体，带水平光标跟随。
- [TextEditState](TextEditState.md) — 两个控件共享的编辑操作。
- [ScrollBar](../core/ScrollBar.md) — 本控件复用的可拖动滚动条。
