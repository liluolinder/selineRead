[chui](../../index.md) › chui.text

# chui.text

```cangjie
import chui.text.*
```

文本编辑控件包：单行 [`TextField`](TextField.md)、多行 [`TextArea`](TextArea.md)、带建议列表的 [`ComboBox`](ComboBox.md)，以及三者共享的编辑模型 [`TextEditState`](TextEditState.md)（光标、选择与全部编辑操作）。控件负责绘制、命中与快捷键；文本、光标与锚点都是可绑定状态，应用可外部持有。`TextArea` 还可消费应用生成的、与文档修订号绑定的绘制装饰快照。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`ComboBox`](ComboBox.md) | 可输入的下拉组合框：在内嵌单行编辑框上浮出建议列表，输入即过滤；绑定文本就是控件的值，自由输入即使不匹配任何选项也被保留。 |
| [`TextArea`](TextArea.md) | 多行文本编辑控件：把编辑写回绑定的 `Bindable<String>`，带垂直滚动与右缘滚动条，行间导航按字节列对齐。 |
| [`TextAreaDecorationSnapshot`](TextAreaDecorationSnapshot.md) | 与一个文档修订号绑定的不可变装饰快照；过期快照不会被绘制。 |
| [`TextCompositionSnapshot`](TextCompositionSnapshot.md) | `TextArea` 的非持久化 IME 预编辑状态：组合文本、组合内选区、替换范围、文档修订与组合代次。 |
| [`TextEditState`](TextEditState.md) | 有光标的文本框与文本域共享的文本编辑模型：文本绑定、光标与选择锚点，以及在这三者上实现的全部编辑操作（插入/删除、按字符/行/整体移动与扩展选择、词与行选择）。 |
| [`TextField`](TextField.md) | 单行文本编辑控件：把输入写回绑定的 `Bindable<String>`，按桌面惯例提供点选拖选、双击选词、Ctrl 快捷键、分组撤销与光标水平跟随。 |

**枚举**

| 类型 | 说明 |
|---|---|
| [`TextAreaWrapMode`](TextAreaWrapMode.md) | `TextArea` 的逻辑行布局契约；当前明确支持一逻辑行一视觉行的 `NoWrap`。 |
| [`TextAreaUnderlineShape`](TextAreaDecorationStyle.md) | 文本装饰下划线形状；`Straight` 保持旧行为，`Squiggle` 绘制有界诊断波浪线。 |

**结构体**

| 类型 | 说明 |
|---|---|
| [`TextAreaDecoration`](TextAreaDecoration.md) | 一段半开 UTF-8 字节范围及其绘制样式。 |
| [`TextAreaDecorationStyle`](TextAreaDecorationStyle.md) | 可选的前景、背景与下划线颜色。 |
