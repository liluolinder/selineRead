[chui](../../index.md) › [chui.core](index.md) › PageTransitionLayout

# PageTransitionLayout

`chui.core` 包中的 public class

在两棵页面子树之间播放横向交接，并连续插值容器测量尺寸。它是通用页面过渡，不表达设备的物理方向。

## 声明

```cangjie
public class PageTransitionLayout <: Widget
```

## 构造函数

```cangjie
public init(
    showSecond!: Bool,
    key!: ?String = None,
    animation!: AnimationSpec = AnimationSpec.automatic(duration: UInt64(260)),
    first!: () -> Unit,
    second!: () -> Unit
)
```

- `showSecond!`：`false` 显示 `first`，`true` 显示 `second`。
- `key!`：跨声明式重建保留动画器和两页局部状态的稳定标识。
- `animation!`：横向交接的时长与缓动；自动规格遵循主题运动等级和减弱动态效果设置。
- `first!` / `second!`：两棵页面子树。

两页都会构建和测量，以便尺寸连续变化；只有当前目标页接收普通事件并进入焦点环。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let second = State<Bool>(false)
    PageTransitionLayout(
        showSecond: second.value,
        key: "onboarding",
        first: { => Label("第一页") },
        second: { => Label("第二页") }
    )
}
```

## 另请参阅

- [DeviceRotationLayout](DeviceRotationLayout.md) — 根据设备姿态选择响应式结构。
- [Animator](Animator.md) — 定时补间原语。
