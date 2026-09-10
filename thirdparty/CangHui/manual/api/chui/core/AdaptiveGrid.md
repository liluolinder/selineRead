[chui](../../index.md) › [chui.core](index.md) › AdaptiveGrid

# AdaptiveGrid

AdaptiveGrid 根据可用宽度、最小单元宽度和间距稳定计算列数，不改变固定列 Grid 与 LazyGrid 的语义。

```cangjie
AdaptiveGrid(160.0, minColumns: 1, maxColumns: 4) {
    ForEach(items, key: { item => item.id }) { item => card(item) }
}.spacing(12.0)
```

列数由 adaptiveGridColumns(...) 计算；单元格等宽，每行高度取该行最高内容。需要跨断点保留局部状态时，继续使用稳定 Keyed/ForEach key；需要移动动画时复用 KeyedLayoutTransition。
