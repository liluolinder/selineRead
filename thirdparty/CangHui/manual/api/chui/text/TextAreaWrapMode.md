[chui](../../index.md) › [chui.text](index.md) › TextAreaWrapMode

# TextAreaWrapMode

`chui.text` 包中的 public enum

定义 [`TextArea`](TextArea.md) 的逻辑行到视觉行布局契约。

```cangjie
public enum TextAreaWrapMode {
    | NoWrap
}
```

| 值 | 语义 |
|---|---|
| `NoWrap` | 一个以 `\n` 分隔的逻辑行始终对应一个视觉行；超出宽度的内容通过横向滚动访问。 |

当前没有软换行模式。`NoWrap` 的类型化公开面避免应用依赖隐含裁剪行为，也给未来完整的视觉行投影、gutter 对齐和软换行命中契约留下兼容扩展点。
