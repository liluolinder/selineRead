[chui](../../index.md) › [chui.core](index.md) › DeviceRotationLayout

# DeviceRotationLayout

`chui.core` 包中的 public class

由规范化设备方向驱动的自适应布局选择器。应用分别声明竖屏和横屏子树；`rotation` 改变后，下一次
声明式构建立即采用目标结构。完整界面的有向旋转动画由宿主壳层在重建前后冻结帧并统一完成，布局
组件本身不会再用横向交接假装设备旋转。

## 声明

```cangjie
public class DeviceRotationLayout <: Widget
```

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("旋转布局", 640, 420))
    app.run {
        DeviceRotationLayout(
            rotation: app.deviceRotation(),
            key: "shell",
            portrait: { =>
                VStack { Label("竖屏"); Label("上下排列") }
            },
            landscape: { =>
                HStack { Label("横屏"); Label("左右排列") }
            }
        )
    }
}
```

## 构造函数

```cangjie
public init(
    rotation!: DeviceRotation,
    key!: ?String = None,
    portrait!: () -> Unit,
    landscape!: () -> Unit
)
```

- `rotation!`：本帧采用的规范化设备方向，通常传 `DesktopApp.deviceRotation()`。
- `key!`：保留两套子树局部状态的稳定标识；默认按声明顺序推导。
- `portrait!`：`Portrait`、`PortraitUpsideDown` 与 `Unknown` 使用的子树。
- `landscape!`：顺/逆时针横屏使用的子树。

两套子树都会构建以保留声明式局部状态，但只有目标方向的子树参与测量、布局、绘制、事件、交互
owner 与焦点出口；非活动子树不会进入 Tab 焦点环。`DesktopApp` 收到方向事件后先冻结旧完整帧，
下一帧重建目标布局并冻结新完整帧，再把两帧按有向角度整体旋转和交接，因此文字、浮层与后代像素
真正作为一个界面运动，结束后仍以目标布局的正向坐标参与交互。

## 另请参阅

- [DesktopApp](../desktop/DesktopApp.md) — 设备方向读取和宿主事件注入。
- [PageTransitionLayout](PageTransitionLayout.md) — 独立保留的双页面横向交接动画。
- [布局随设备旋转](../../../guide/how-to/adapt-device-rotation.md) — 平台回调到声明式布局的完整流程。
