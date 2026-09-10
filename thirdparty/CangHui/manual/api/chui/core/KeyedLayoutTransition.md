[chui](../../index.md) › [chui.core](index.md) › KeyedLayoutTransition

# KeyedLayoutTransition

`chui.core` 包中的 public class

让同一个带稳定 key 的子树在重排或响应式重布局时，从上一帧可见矩形连续移动和变形到父布局分配的
新矩形。它适合看板卡片重排、网格列数变化和工具区重组，不要求应用直接持有 `Animator`。

## 声明

```cangjie
public class KeyedLayoutTransition <: Widget
```

## 构造函数

```cangjie
public init(
    key: String,
    animation!: AnimationSpec = AnimationSpec.automatic(duration: Motion.normal),
    clip!: LayoutTransitionClip = LayoutTransitionClip.NoClip,
    content!: () -> Unit
)
```

- `key`：逻辑对象的稳定且非空标识。应使用记录 id，不要使用会随排序改变的数组下标。
- `animation!`：四条几何轨道共享的动画规格；默认跟随主题动效等级与减少动态效果设置。
- `clip!`：过渡绘制的裁剪策略。
- `content!`：被包裹的单个声明式子树。

父布局立即拥有目标矩形；普通输入、焦点遍历和父级测量均使用这个最终结构。绘制阶段才临时把子树布局到
当前插值矩形，完成后恢复目标矩形。因此，卡片尚在移动时，点击也已经属于新单元格，而不会命中旧位置。

动画途中再次改变目标时，四条轨道从当前可见矩形重新定向，不跳回第一次起点。首次出现直接稳定；某次
完整构建没有访问该 key 时，局部几何状态会被清理，之后同 key 重新挂载也从新位置静止开始。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let columns = State<Int64>(2)
    let ids = ["alpha", "beta", "gamma"]
    Grid(columns.value) {
        for (id in ids) {
            KeyedLayoutTransition(id, clip: LayoutTransitionClip.AnimatedBounds) {
                Panel { Label(id) }.contentPadding(12.vp)
            }
        }
    }.spacing(10.vp)
}
```

完整的可交互工程见 [`examples/layout_transition`](../../../../examples/layout_transition/README.md)。

## 几何回执

```cangjie
public func geometry(): LayoutTransitionGeometry
```

返回当前绘制矩形、父布局目标矩形与稳定状态，供确定性测试和探针投影使用。这个回执不改变动画进度；
动画仍在 `draw` 中推进。

## 能力边界

- 这是矩形布局连续性，不是任意旋转、透视或渲染器通用变换栈。
- 子内容在当前动画宽高内重新布局；需要纯像素缩放的场景应由未来的快照/变换原语承担。
- 删除项不会自动保留已卸载子树，因此不提供隐式退出动画。
- `zIndex`、Modal、原生 Surface 和窗口边界仍遵循各自的 stacking context。

## 另请参阅

- [LayoutTransitionClip](LayoutTransitionClip.md) — 过渡绘制裁剪策略。
- [LayoutTransitionGeometry](LayoutTransitionGeometry.md) — 可测试几何回执。
- [Animator](Animator.md) — `AnimationSpec` 所驱动的定时补间原语。
- [Keyed](Keyed.md) — 仅维持子树身份、不改变布局几何的轻量包装。
