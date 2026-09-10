[chui](../../index.md) › chui.desktop

# chui.desktop

```cangjie
import chui.desktop.*
```

桌面应用对象包：[`DesktopApp`](DesktopApp.md) 拥有一个 SDL 窗口与渲染循环；
[`DesktopApplication`](DesktopApplication.md) 以一个进程级 event pump 管理互相隔离的多个窗口。
闲置帧被跳过（脏帧机制），[`DesktopCaptureRequest`](DesktopCaptureRequest.md) 提供稳定采集接口；
旧 `--snapshot` 仅作兼容。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`DesktopApp`](DesktopApp.md) | 桌面应用对象：拥有 SDL 窗口并运行帧循环——每帧从 [`run`](DesktopApp.md#run) 的界面构建函数重建组件树、布局、分发输入、绘制。 |
| [`DesktopApplication`](DesktopApplication.md) | 一个 SDL event pump 下的多窗口 runtime，提供非阻塞 pump/step 与便利 run 循环。 |
| [`DesktopCaptureRequest`](DesktopCaptureRequest.md) | 宿主与框架之间的一次稳定渲染采集请求。 |

**接口**

| 类型 | 说明 |
|---|---|
| `DesktopWindowSession` | 自定义宿主窗口 session 的身份、事件分发与关闭接口。 |

**结构体**

| 类型 | 说明 |
|---|---|
| `WindowDispatchReceipt` | 一次窗口或全局事件路由结果。 |
| `DesktopWindowStepReceipt` | 一个托管窗口的一次非阻塞构建/绘制/present 结果。 |
| `DesktopWindowStateReceipt` | 焦点、浮层、指针捕获与 Scene3D 登记的窗口隔离快照。 |

**枚举**

| 类型 | 说明 |
|---|---|
| [`FramePacing`](FramePacing.md) | 桌面渲染帧的设备同步、固定目标帧率或不封顶策略。 |

## 函数

| 函数 | 说明 |
|---|---|
| `framePacingName` | 返回 `device`、`fixed-<fps>fps` 或 `unbounded` 的稳定诊断名称。 |
