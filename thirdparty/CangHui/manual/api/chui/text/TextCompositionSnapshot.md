[chui](../../index.md) › [chui.text](index.md) › TextCompositionSnapshot

# TextCompositionSnapshot

`TextArea` 的非持久化 IME 预编辑状态。它区分候选文本与正式文档：`preedit`、组合内字符选区、待替换的 UTF-8 字节范围、捕获时文档修订和组合代次都被显式记录。

```cangjie
public struct TextCompositionSnapshot {
    public let active: Bool
    public let preedit: String
    public let selectionStart: Int64
    public let selectionLength: Int64
    public let replacementStartByte: Int64
    public let replacementEndByte: Int64
    public let documentRevision: UInt64
    public let generation: UInt64
}
```

预编辑更新不会修改 `Bindable<String>`。只有同一焦点所有者、同一文档修订下的提交才替换捕获范围；失焦或外部修改会让快照失效，从而避免重复提交和错误覆盖。

组合内 `selectionStart/selectionLength` 按 Unicode 字符计数；`replacementStartByte/replacementEndByte` 按 CangHui 文本 API 的 UTF-8 字节边界计数。
