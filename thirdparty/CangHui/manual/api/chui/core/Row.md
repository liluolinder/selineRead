[chui](../../index.md) › [chui.core](index.md) › Row

# Row

`chui.core` 包中的 public class

ArkTS 风格的通用水平线性容器。`Row` 复用 CangHui 与 `HStack` 相同的弹性布局引擎，
默认槽间距为 0、主轴从起点排列、交叉轴居中。框架不替业务预设三槽、padding、最小高度或点击；
这些都用普通子项和 [`Widget`](Widget.md) 修饰器组合。

## 声明

```cangjie
public class Row <: Widget
```

## 构造

```cangjie
public init(
    space!: Length = 0.vp,
    padding!: LengthInsets = LengthInsets.zero(),
    flexible!: Bool = true,
    body!: () -> Unit
)
```

- `space!`：相邻子项的固定间距。
- `padding!`：容器内部四边留白；普通页面也可用链式 `.padding(...)`。
- `flexible!`：本 Row 是否参与父容器的弹性分配。
- `body!`：按声明顺序收集子项。

## 常用组合

三段信息行不需要专用控件：让中间内容获得剩余宽度，再按产品令牌添加尺寸和留白。

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("信息行", 520, 260))
    app.run {
        Row(space: 8.vp) {
            Icon(IconName.OpenFolder)
            VStack(spacing: 2.vp) {
                Label("CorePlayer").bold().maxLines(1)
                Label("最近同步 2 分钟前").muted().fontSize(12.fp).maxLines(1)
            }.hug().layoutWeight()
            Label("已就绪").muted().maxLines(1)
        }.padding(12.vp, 8.vp).minHeight(44.vp).fillWidth()
    }
}
```

布局结果是 `[图标  标题/说明                 状态]`。`layoutWeight` 只表达空间所有权；
它不会自动添加卡片外观、点击行为或业务语义。

## 方法

| 方法 | 说明 |
|---|---|
| `space(value: Length/Float32): Row` | 修改相邻子项间距。 |
| `justifyContent(value: MainAxisAlignment): Row` | 设置水平主轴的剩余空间分配。 |
| `alignItems(value: CrossAxisAlignment): Row` | 设置垂直交叉轴对齐；默认 `Center`。 |
| `flexible(value: Bool): Row` | 控制 Row 本身是否参与父容器弹性分配。 |
| `hug(): Row` | 让 Row 本身沿父容器主轴按内容收缩。 |

## 选择 Row 还是 HStack

- 从 ArkTS 迁移或希望直接表达 `space`、`justifyContent`、`alignItems`、`layoutWeight` 时用 `Row`。
- 既有 CangHui 代码可以继续使用 `HStack`、`spacing`、`mainAxisAlignment`、
  `crossAxisAlignment` 和 `flex`；两者不是两套布局引擎。
- 只有两个端点时，`justifyContent(SpaceBetween)` 很直接；有主内容所有权时，优先给中间子项
  `layoutWeight()`，不要用 `SpaceAround` 平均摊开三段内容。
