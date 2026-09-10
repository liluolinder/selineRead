[chui](../../index.md) › [chui.text](index.md) › TextAreaDecorationSnapshot

# TextAreaDecorationSnapshot

`chui.text` 包中的 public class

发布一组与特定 `Bindable<String>.revision` 绑定的不可变绘制装饰。

## 声明

```cangjie
public class TextAreaDecorationSnapshot {
    public let documentRevision: UInt64

    public init(documentRevision: UInt64, decorations: Array<TextAreaDecoration>)
    public func decorations(): Array<TextAreaDecoration>
}
```

构造器会复制输入数组，`decorations()` 也返回防御性副本；因此可安全放入 `State` 或 `DerivedState`，而不与 `TextArea` 共享可变范围集合。

`documentRevision` 必须与绘制当帧的文本修订号一致。不一致表示 tokenizer 结果已过期：`TextArea` 忽略整份快照并使用普通文本路径，避免把旧偏移绘制到新文档。

## 相关 API

[`TextAreaDecoration`](TextAreaDecoration.md)、[`TextAreaDecorationStyle`](TextAreaDecorationStyle.md)、[`TextArea`](TextArea.md)。
