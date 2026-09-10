[chui](../../index.md) › [chui.core](index.md) › LayoutTransitionGeometry

# LayoutTransitionGeometry

`chui.core` 包中的 public struct

[`KeyedLayoutTransition.geometry()`](KeyedLayoutTransition.md#几何回执) 返回的确定性只读回执。

```cangjie
public struct LayoutTransitionGeometry {
    public let current: Rect
    public let target: Rect
    public let settled: Bool
}
```

- `current`：本帧用于绘制的插值矩形。
- `target`：父布局已经分配、普通输入已经采用的最终矩形。
- `settled`：四条 x/y/width/height 轨道是否都到达目标。

首次出现与卸载后重新挂载会返回 `current == target` 且 `settled == true`。
