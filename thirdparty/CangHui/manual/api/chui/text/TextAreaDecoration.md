[chui](../../index.md) › [chui.text](index.md) › TextAreaDecoration

# TextAreaDecoration

`chui.text` 包中的 public struct

把一段半开 UTF-8 字节范围 `[startByte, endByte)` 与绘制样式关联。

## 声明

```cangjie
public struct TextAreaDecoration {
    public let startByte: Int64
    public let endByte: Int64
    public let style: TextAreaDecorationStyle

    public init(startByte: Int64, endByte: Int64, style: TextAreaDecorationStyle)
}
```

`startByte` 和 `endByte` 都必须是文本的精确码点边界，不能落在多字节字符内部。负偏移、空范围、越界或非码点边界范围均被安全忽略，不会被自动吸附到附近字符。

同一快照内范围可重叠；输入数组中较后的项在重叠部分胜出。

## 相关 API

[`TextAreaDecorationStyle`](TextAreaDecorationStyle.md)、[`TextAreaDecorationSnapshot`](TextAreaDecorationSnapshot.md)、[`TextArea`](TextArea.md)。
