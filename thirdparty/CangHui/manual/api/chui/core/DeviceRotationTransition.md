[chui](../../index.md) › [chui.core](index.md) › DeviceRotationTransition

# DeviceRotationTransition

`chui.core` 包中的 public class

供平台壳层复用的整帧设备旋转事务。它分别冻结旧界面与重建后的新界面，按规范化方向之间的有向角度
旋转并交接两张完整帧；应用通常不直接构造，`DesktopApp` 已自动管理其生命周期。

方向差保留 `+90°`、`-90°`、`+180°` 与 `-180°`。其中相反姿态的两个 180° 由起点和终点决定，
不会把所有半周旋转压成同一个方向。旋转期间目标纹理按当前角度等比缩放，保证旋转后的边界留在视口内。

## 声明

```cangjie
public class DeviceRotationTransition
```

## 宿主契约

平台壳层在方向事件帧捕获旧树，下一帧按新方向完成布局后捕获新树；只有两张快照都就绪后才推进动画。
过渡完成必须调用 `close()` 释放纹理。自动 `AnimationSpec` 会遵循主题运动等级和减弱动态效果设置。

## 另请参阅

- [DeviceRotationLayout](DeviceRotationLayout.md) — 应用层竖屏/横屏结构选择。
- [DesktopApp](../desktop/DesktopApp.md) — 默认宿主实现与动画配置。
