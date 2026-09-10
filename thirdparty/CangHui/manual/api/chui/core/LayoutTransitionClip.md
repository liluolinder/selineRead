[chui](../../index.md) › [chui.core](index.md) › LayoutTransitionClip

# LayoutTransitionClip

`chui.core` 包中的 public enum

控制 [`KeyedLayoutTransition`](KeyedLayoutTransition.md) 移动与变形期间的绘制裁剪。

```cangjie
public enum LayoutTransitionClip {
    | NoClip
    | AnimatedBounds
    | TargetBounds
}
```

| 成员 | 语义 |
|---|---|
| `NoClip` | 不额外裁剪；阴影和跨单元格内容可完整绘制。 |
| `AnimatedBounds` | 裁剪到当前插值矩形；适合卡片内容随宽高重排。 |
| `TargetBounds` | 裁剪到父布局最终矩形；适合内容不应越过新槽位的界面。 |

裁剪只影响绘制，不改变测量、焦点或命中矩形。
