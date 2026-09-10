# 平台接口（开发者预览）

以下接口是 CangHui 母体为多平台/鸿蒙消费提供的平台无关抽象（HarmonyHap/CangHUI 负责
平台实现）：

- `chui.core.BoundedMailbox<T>`：线程安全有界 FIFO，适合平台宿主向 UI 线程投递事件/命令。
- `chui.core.PointerInputBridge`：收集合成指针 down/move/up/click，drain 为 `UiEvent`。
- `chui.media.ExternalFramePlane`：外部视频/相机/表面帧平面接口，可渲染进 CangHui Renderer。

Harmony 侧落地状态：

- `BoundedMailbox` / `PointerInputBridge` / `ExternalFramePlane` 已进入母体 main。
- HarmonyHap/CorePlayer 的薄适配代码已就位（`HarmonyExternalFramePlane` 实现母体接口），
  OHOS 构建验证与 ArkTS onTouch 接线待 Harmony/DevEco 环境完成，如实 `delivery-pending`。
