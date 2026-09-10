# 布局随设备旋转

设备旋转不是把原始陀螺仪数值直接塞给布局。稳定的链路分三层：平台宿主采样并去抖，公共事件只携带
规范化四分之一转，界面再声明每个方向真正需要的布局。

## 1. 平台侧归一化

HarmonyOS、iOS、Android 等宿主负责传感器权限、生命周期、采样频率、阈值和迟滞。姿态稳定后，映射为：

- `Portrait`
- `LandscapeClockwise`
- `PortraitUpsideDown`
- `LandscapeCounterClockwise`

原始 roll/pitch/yaw 和角速度仍由平台驱动持有，避免手持抖动触发连续重排。

## 2. 把事件送给 CangHui

回调已在 UI owner 上时调用：

```cangjie
app.queueDeviceRotation(
    DeviceRotationEvent(
        DeviceRotation.LandscapeClockwise,
        source: DeviceRotationSource.Gyroscope,
        timestampMs: sensorTimestamp
    )
)
```

回调来自工作线程时使用 `postDeviceRotation(event)`。它先经过线程安全的 owner queue，再作为普通
`UiEvent.DeviceRotationChanged` 分发；不要直接从工作线程修改布局状态。

## 3. 声明方向布局

```cangjie
DeviceRotationLayout(
    rotation: app.deviceRotation(),
    key: "dashboard",
    portrait: { => portraitDashboard() },
    landscape: { => landscapeDashboard() }
)
```

事件被宿主接受后，壳层冻结旧完整帧；`UiContext` 请求下一帧，下一次声明式构建读取新方向、选择目标
结构并冻结新完整帧。两帧随后按 `deviceRotationDeltaDegrees(from, to)` 的结果播放
`+90° / -90° / +180° / -180°` 整页旋转与交接。这里旋转的是含文字和浮层在内的整张界面，
并非只对两套布局做横向切换。传感器尚未报告时，
`app.deviceRotation()` 只用当前视口宽高选择一个确定的布局回退；`reportedDeviceRotation()` 仍返回
`Unknown`，不会伪称已有物理传感器证据。

## 验证

桌面/CI 不需要伪造系统截图或物理传感器。使用 `Synthetic` 来源排队方向事件，再运行：

```bash
cuic probe ascii examples/device_rotation device-rotation.layout
cuic prnt macos examples/device_rotation --output /tmp/canghui-device-rotation.bmp
```

结构输出应包含 `rotation-layout`，属性 `rotation` 随事件改变；画面中非活动布局不可点击、不可 Tab 聚焦。
默认整页旋转使用 `DesktopApp(..., deviceRotationAnimation: AnimationSpec.automatic(...))`，自动规格会遵循
主题运动等级，`reduceMotion` 下缩短为最小持续时间。
