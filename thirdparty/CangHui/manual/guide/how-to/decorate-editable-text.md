<!-- kind: how-to; audience: desktop-app-developer -->

# 为可编辑文本添加令牌装饰

## 目标

在不改写 `TextArea` 编辑、IME 和撤销语义的前提下，绘制语法颜色、搜索背景或诊断下划线。一个最小生产器约需 15 分钟。

## 边界

`TextArea` 只消费绘制快照。Tokenizer、语言服务、诊断策略和颜色规则属于应用；不要把它们塞进框架控件。文本、光标、锚点和撤销栈仍由原有编辑模型持有。

## 操作步骤

### 1. 用文档修订发布快照

```cangjie role=patch
let document = model.text
let decorations = document.map({value =>
    // tokenize(value) 返回精确 UTF-8 字节范围，并保持业务顺序。
    TextAreaDecorationSnapshot(document.revision, tokenize(value))
})
```

范围使用 `[startByte, endByte)`，两端必须是码点边界。请从 tokenizer 的字节位置直接生成；不要把字符序号当成字节偏移，也不要要求框架替你“就近修正”错误边界。

### 2. 声明绘制效果

```cangjie role=patch
TextAreaDecoration(
    token.startByte,
    token.endByte,
    TextAreaDecorationStyle(
        foreground: Some(palette.keyword),
        background: None,
        underline: Some(palette.danger)
    )
)
```

同一快照中的项可重叠，后面的项覆盖前面的重叠部分。因此可先放语法类别，再放当前搜索命中或更高优先级的诊断。

### 3. 把快照交给 TextArea

```cangjie role=patch
TextArea(document, decorations: Some(decorations))
```

也可在建立控件后链式调用 `.decorations(decorations)`。框架只归一化当前可见逻辑行，并按文本、装饰和视口修订缓存结果。

## 确认结果

输入、选择、输入法组合、撤销和重做应与无装饰时一致。在 tokenizer 尚未返回新修订的短暂窗口内，旧快照应消失而不是错位绘制；新快照到达后自动恢复。

运行仓库内 `examples/editor`可观察真实外部消费者：标题使用前景与下划线，正文使用半透明背景，编辑后由 `DerivedState` 按新修订重新发布。

## 常见错误

- 快照用旧 `documentRevision`：框架会正确忽略，视觉上看起来像“高亮消失”。
- 用 Unicode 字符个数作偏移：遇到中文或 emoji 后范围失效。
- 在装饰生成器里改写文本或光标：会破坏单向绘制边界并引起反复重建。
- 依赖框架合并相邻同色范围：边界切段是确定的，但不承诺合并。

## 相关 API

[`TextArea`](../../api/chui/text/TextArea.md)、[`TextAreaDecoration`](../../api/chui/text/TextAreaDecoration.md)、[`TextAreaDecorationSnapshot`](../../api/chui/text/TextAreaDecorationSnapshot.md)。
