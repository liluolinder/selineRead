[chui](../../index.md) › [chui.core](index.md) › ControlContentEnvironment

# ControlContentEnvironment

`ControlContentEnvironment` 是组合控件绘制装饰性 slot 时压入 [`UiContext`](UiContext.md) 的只读环境。

```cangjie
public struct ControlContentEnvironment
```

它公开：

- `foreground` 与 `supportingForeground`；
- `role` 与唯一 `interactionOwner`；
- `selected`、`expanded`、`focused`、`hovered`、`pressed`；
- `enabled` 与 `readOnly`。

Label、Icon 与 Symbol 仅在没有显式颜色时继承环境颜色。自定义 Widget 可在 `draw(ctx)` 中调用
`ctx.controlContentEnvironment()`；没有外层组合控件时返回 `None`。`withControlContentEnvironment` 使用
栈式作用域，嵌套绘制结束后自动恢复上一个环境。

[`InteractionSurface`](InteractionSurface.md) 会把完整交互状态写入环境；普通装饰
[`Surface`](Surface.md) 只发布 material 前景与当前 enabled 状态。已有调用者不传新字段时仍默认
`enabled=true / readOnly=false`；环境入栈时，UiContext 会把该值与当前 `.enabled(...)` scope 做逻辑与，
因此既有 slot 控件也不会在禁用子树中看到错误的 enabled=true。

该类型是框架和未来原生 accessibility adapter 的稳定输入之一，但本身不代表平台辅助功能桥已安装。
