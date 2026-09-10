# 设备旋转布局

这个示例展示 CangHui 的规范化设备旋转链：宿主把陀螺仪或系统方向回调去抖、归一化成
`DeviceRotationEvent`，经 `DesktopApp.queueDeviceRotation`（UI owner）或
`postDeviceRotation`（任意线程）送入事件路由；声明式界面读取 `app.deviceRotation()`，再由
`DeviceRotationLayout(rotation:)` 选择竖屏或横屏结构；`DesktopApp` 在结构重建前后冻结完整界面帧，
按事件的有向角度播放整页 `+90° / -90° / +180° / -180°` 旋转，而不是用布局切换假装旋转。

```bash
cjpm run
```

四个角度按钮使用 `Synthetic` 来源，方便桌面和 CI 在没有物理传感器时复现同一条链。真实移动
宿主应在平台侧完成权限、采样、阈值和去抖，不要把每个原始角速度样本直接变成布局事件。
