[chui](../../index.md) › [chui.core](index.md) › GestureSurface

# GestureSurface

GestureSurface 是 InteractionSurface 的便利构造器。它在同一个焦点、语义与 action owner 下组合 tap、double tap、long press、drag、hover 和 pointer capture，不产生第二套命中树。

```cangjie
GestureSurface(
    action: {=> open(item) },
    accessibilityLabel: "Open " + item.name,
    key: Some(item.id),
    gestures: GestureHandlers(
        onLongPress: Some({=> beginSelection(item) }),
        onDragUpdate: Some({x, y, dx, dy => movePreview(x, y, dx, dy)}),
        onDragEnd: Some({x, y => dropAt(x, y)})
    )
) {
    fileCard(item)
}
```

键盘 Enter/Space 与手柄 South 保留普通激活。鼠标、触摸和笔应由平台宿主先归一为同一 pointer 事件；远程桌面原始指针转发仍属于产品协议。嵌套 Button 或其他交互 owner 会沿用 InteractionSurface 的 fail-closed 诊断。
