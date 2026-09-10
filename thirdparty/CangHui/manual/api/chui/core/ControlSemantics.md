[chui](../../index.md) › [chui.core](index.md) › ControlSemantics

# ControlSemantics

`ControlSemantics` 描述组合控件的唯一外层语义动作。

```cangjie
public struct ControlSemantics
```

字段包括 `role`、`label`、`value`、`placeholder`、`action`、`shortcut`、`actionOwner`，以及可选的
`selected`、`expanded`、`enabled`、`readOnly`。`placeholder` 是文本输入的语义提示，与
`label`/`accessibilityLabel` 明确区分，
只有非空时才发射。`recordControlSemantics(ctx, frame, widgetType, semantics)` 在 ComponentProbe 活跃时记录一个
semantic region，并把后代标记为 `decorative`。当外层 `.enabled(false)` 生效时，区域保留 role/label/value/状态，
增加 `disabled=true` 与 `enabled=false`，并移除 action/shortcut；显式 `.probe(...)` 也遵守同一规则且不受修饰符顺序影响。
不带 `ctx` 的旧重载保留兼容，但无法感知外层禁用状态。

`enabled`/`readOnly` 都是可选字段，未设置时不改变既有控件输出。显式 `enabled=false` 会与外层
`.enabled(false)` 一样移除 action/shortcut；`readOnly` 作为独立属性保留，便于 headless 与未来平台 adapter
区分只读和普通禁用。

Button、Chip、Checkbox、Dropdown 闭合面、Accordion header、IconButton、Switch、RadioButton、Slider、Picker、
Stepper、Rating、Breadcrumb、Pagination、StepIndicator 与 TextField 已自动记录，无需为每个内置控件手写
`.probe(...)`。JSON 保留完整属性；ASCII 图例展示 role/label/action/value/state 与可执行的坐标探针。

该契约用于无图验证和未来平台 adapter 输入；它不声称当前已完成 macOS、iOS、Android 或 HarmonyOS
原生 accessibility tree 映射。
