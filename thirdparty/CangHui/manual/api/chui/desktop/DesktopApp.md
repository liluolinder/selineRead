[chui](../../index.md) › [chui.desktop](index.md) › DesktopApp

# DesktopApp

`chui.desktop` 包中的 public class

桌面应用对象：拥有 SDL 窗口并运行帧循环——每帧从 [`run`](#run) 的界面构建函数重建组件树、布局、分发输入、绘制。闲置帧被跳过：只有输入、[`State`](../core/State.md) 写入、待处理的 [`UiOwnerQueue`](../core/UiOwnerQueue.md) 任务、窗口缩放或组件的 `ctx.requestFrame()` 才触发渲染，时间驱动的动画必须请求帧否则冻结。实际渲染帧由 [`FramePacing`](FramePacing.md) 决定跟随设备 VSync、固定目标帧率或不封顶。

## 声明

```cangjie
public class DesktopApp
```

## 说明

帧循环统一处理焦点、悬停、连续点击和指针事件。每个需要渲染的帧先 drain 当前 owner-task 快照，再构建声明式组件树；worker 可经 [`postToUi`](#posttoui) 投递不可变结果，但不能直接修改 UI `State`。事件先交给已打开的浮层，再进入普通组件树，因此弹出菜单和对话框不会把点击漏给下层控件；提示和浮层也绘制在普通内容之上。Tab 按组件构建顺序移动焦点，Shift+Tab 反向移动，且不会把 Tab 交给文本框。经 [`manage`](#manage) 注册的资源会在退出时按注册的相反顺序关闭，然后关闭窗口；即使组件抛出异常离开帧循环，也会关闭 owner queue、完成待处理 ticket 并执行这套清理。若清理同时报告 SDL owner-thread 错误，`run` 会继续抛出更早的帧循环异常。`cuic prnt` 会构建后直接启动应用可执行文件，并通过 [`DesktopCaptureRequest`](DesktopCaptureRequest.md) 的宿主请求采集稳定画面，不依赖 `cjpm run` 转发参数。旧应用仍兼容 `--snapshot <path.bmp>` 与 `--snapshot-frame`；`--profile` 输出各阶段的帧耗时。IME 候选窗会跟随聚焦文本控件报告的光标矩形。

## 示例

```cangjie verify
package docexample

import chui.*

// 完整桌面应用骨架:运行时开窗进入帧循环,关窗后 run 返回。
main(): Unit {
    let app = DesktopApp(
        WindowSpec("计数器", 360, 240),
        theme: Theme.light()
    )
    app.setMinimumSize(280, 180)
    app.run {
        let count = rememberState<Int64>("计数") {0}
        VStack(spacing: 12.vp) {
            Label("已点击 ${count.value} 次")
            Button("加一", {=> count.value = count.value + 1})
        }
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以窗口规格、主题、帧节奏、字体缩放、设备旋转动画、应用元数据与 SDL hint 创建桌面应用对象。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`manage(...)`](#manage) | 注册退出时自动关闭的资源（逆序关闭）。 |
| [`setMinimumSize(...)`](#setminimumsize) | 阻止窗口被缩小到给定逻辑尺寸以下。 |
| [`useBaseCursor(...)`](#usebasecursor) | 设置窗口的基础光标——没有控件申请其它形状时显示的形状（如绘图画布上的十字线）。 |
| [`clearRememberedState()`](#clearrememberedstate) | 在下一次重建前丢弃全部 `rememberState` 局部值。 |
| [`postToUi(...)`](#posttoui) | 从任意线程投递任务，在下一次声明式构建前由 UI owner 串行执行。 |
| [`uiOwnerEpoch()`](#uiownerepoch) | 读取 owner epoch，供 worker 准备乐观提交条件。 |
| [`deviceRotation()`](#devicerotation) | 返回供布局使用的有效方向；尚无宿主报告时按视口宽高回退。 |
| [`reportedDeviceRotation()`](#reporteddevicerotation) | 返回宿主最后报告的方向，未报告时保持 `Unknown`。 |
| [`queueDeviceRotation(...)`](#queuedevicerotation) | 在 UI owner 上把规范化方向排入普通事件路由。 |
| [`postDeviceRotation(...)`](#postdevicerotation) | 从任意线程经 owner queue 投递方向事件。 |
| [`openFileDialog(...)`](#openfiledialog) | 发起系统"打开文件"对话框，返回可轮询的请求。 |
| [`saveFileDialog(...)`](#savefiledialog) | 发起系统"保存文件"对话框。 |
| [`openFolderDialog(...)`](#openfolderdialog) | 发起系统"选择文件夹"对话框。 |
| [`run(...)`](#run) | 进入帧循环直到窗口关闭；`body` 每渲染帧重建视图树。 |

## 构造函数

### init

以窗口规格、主题、帧节奏、字体缩放、设备旋转动画、应用元数据与 SDL hint 创建桌面应用对象。元数据与 hint 在建窗前生效。

```cangjie
public init(
    spec: WindowSpec,
    theme!: Theme = Theme.light(),
    frameDelay!: UInt32 = UInt32(16),
    framePacing!: ?FramePacing = None,
    capture!: ?DesktopCaptureRequest = None,
    fontScale!: Float32 = 1.0,
    deviceRotationAnimation!: AnimationSpec = AnimationSpec.automatic(duration: UInt64(320)),
    metadata!: ?AppMetadata = None,
    hints!: Array<SdlHintSetting> = []
)
```

**参数**

- `spec`: `WindowSpec` — 标题、逻辑尺寸、DPI/垂直同步/超采样等一次性窗口选项（sdl 模块）。
- `theme!`: [`Theme`](../core/Theme.md) — 语义调色板；默认值为 `Theme.light()`。
- `frameDelay!`: `UInt32` — 兼容旧 `vsync: false` 调用的固定等待；显式 `framePacing` 或 VSync 设备模式不叠加此等待。默认 `16`。
- `framePacing!`: `?`[`FramePacing`](FramePacing.md) — 显式帧节奏；默认 `None`，普通 VSync 窗口跟随设备，kMode 对实际渲染帧不封顶。
- `capture!`: `?`[`DesktopCaptureRequest`](DesktopCaptureRequest.md) — 显式渲染采集请求；优先于宿主环境注入和旧命令行兼容输入，默认 `None`。
- `fontScale!`: `Float32` — 应用到 `fp` 长度的用户字体缩放；下限 0.1。默认 `1.0`。
- `deviceRotationAnimation!`: `AnimationSpec`（见 [`Animator`](../core/Animator.md)）— 设备方向事件触发的整页有向旋转；
  默认 320ms 自动规格，随主题运动等级缩放，并在减弱动态效果时缩到最短时长。
- `metadata!`: `?AppMetadata` — 应用名/版本等元数据（sdl.system）。默认 `None`。
- `hints!`: `Array<SdlHintSetting>` — 建窗前应用的 SDL hint。默认空。

**异常**

- `CuiException` — 应用元数据或 SDL hint 无法应用，或者窗口、渲染器、文本输入初始化失败时；CangHui 不捕获或改写该异常。

## 方法

### manage

注册退出时自动关闭的资源（逆序关闭）。

```cangjie
public func manage(resource: Resource): Unit
```

**参数**

- `resource`: `Resource` — 随应用生命周期存活的资源。

### setMinimumSize

阻止窗口被缩小到给定逻辑尺寸以下。布局不会在设计最小值以下重排，可缩放窗口应设置一个，避免内容被挤出屏幕。

```cangjie
public func setMinimumSize(width: Int32, height: Int32): Unit
```

**参数**

- `width`、`height`: `Int32` — 最小逻辑尺寸。

**异常**

- `CuiException` — SDL 拒绝设置窗口最小尺寸时；CangHui 不捕获或改写该异常。

### useBaseCursor

设置窗口的基础光标——没有控件申请其它形状时显示的形状（如绘图画布上的十字线）。悬停驱动的形状（按钮上的手形、文本上的 I 形）仍叠加其上。系统无法创建所选光标时保留当前或系统默认光标，不会让应用退出。

```cangjie
public func useBaseCursor(kind: SystemCursor): Unit
```

**参数**

- `kind`: `SystemCursor` — 系统光标种类（sdl.input）。

### clearRememberedState

在下一次重建前丢弃全部 `rememberState` 局部值。若从当前帧的事件回调调用，清理会延迟到
该帧提交或回滚后的安全边界，不会中断正在运行的布局、绘制或事件阶段。

```cangjie
public func clearRememberedState(): Unit
```

### postToUi

把 worker 已准备好的结果投递给应用的 UI owner。任务按 ticket 顺序在下一次声明式树构建之前执行，
因此可在任务体内修改 UI `State`。`baseEpoch` 可选：若执行时 owner epoch 已变化，任务不会运行，ticket
完成为 `RejectedStaleEpoch`。任务失败不阻断后续任务，但会完成为 `Failed`；应用关闭后投递立即完成为
`RejectedClosed`。

```cangjie
public func postToUi(
    action: UiOwnerTaskHandler,
    baseEpoch!: ?UInt64 = None,
    topologyHash!: String = ""
): UiOwnerTicket
```

**参数**

- `action`: `() -> Unit` — 只在 UI owner 上执行的小型提交任务。
- `baseEpoch!`: `?UInt64` — worker 开始准备时读取的 owner epoch；默认不检查。
- `topologyHash!`: `String` — 可选追踪元数据，队列不解释其内容。

**返回值** [`UiOwnerTicket`](../core/UiOwnerQueue.md#uiownerticket) — 可在 owner 领取前取消，并轮询最终 receipt。

### uiOwnerEpoch

原子读取当前 owner epoch。worker 可先保存此值，准备不可变结果，再把它作为 `postToUi(baseEpoch:)`
传回；期间若已有其他 owner task 提交或失败，旧结果会被拒绝。

```cangjie
public func uiOwnerEpoch(): UInt64
```

**返回值** `UInt64` — 当前 owner epoch。

### deviceRotation

返回供声明式布局使用的有效设备方向。平台尚未上报时，根据当前逻辑视口宽高确定竖屏/横屏回退；
这不改变 `reportedDeviceRotation()` 的传感器事实。

```cangjie
public func deviceRotation(): DeviceRotation
```

### reportedDeviceRotation

返回平台最后上报的规范化方向；首个事件到达前为 `DeviceRotation.Unknown`。

```cangjie
public func reportedDeviceRotation(): DeviceRotation
```

### queueDeviceRotation

在 UI owner 上把一个方向事件排入普通 `UiEvent` 路由。可传完整事件，也可传方向、来源和时间戳。

```cangjie
public func queueDeviceRotation(event: DeviceRotationEvent): Unit

public func queueDeviceRotation(
    rotation: DeviceRotation,
    source!: DeviceRotationSource = DeviceRotationSource.Host,
    timestampMs!: UInt64 = UInt64(0)
): Unit
```

### postDeviceRotation

从任意线程投递方向事件。事件先由线程安全的 UI owner queue 接收，再在 owner 上进入普通事件路由；
适合移动平台传感器或窗口方向回调。

```cangjie
public func postDeviceRotation(event: DeviceRotationEvent): UiOwnerTicket
```

### openFileDialog

发起系统"打开文件"对话框，返回可轮询的请求。对话框异步完成——在 [`FrameHandler`](../core/FrameHandler.md) 或下一帧轮询请求结果。

```cangjie
public func openFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest
```

**参数**

- `options!`: `FileDialogOptions` — 过滤器、初始目录等（sdl.dialogs）；默认值为 `FileDialogOptions()`。

**返回值** `FileDialogRequest` — 可轮询的异步请求（sdl.dialogs）。

**异常**

- `CuiException` — 文件对话框选项非法时；CangHui 不捕获或改写该异常。

### saveFileDialog

发起系统"保存文件"对话框。

```cangjie
public func saveFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest
```

**参数**

- `options!`: `FileDialogOptions` — 过滤器、初始目录等；默认值为 `FileDialogOptions()`。

**返回值** `FileDialogRequest` — 可轮询的异步请求。

**异常**

- `CuiException` — 文件对话框选项非法时；CangHui 不捕获或改写该异常。

### openFolderDialog

发起系统"选择文件夹"对话框。

```cangjie
public func openFolderDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest
```

**参数**

- `options!`: `FileDialogOptions` — 初始目录等文件夹选择选项；默认值为 `FileDialogOptions()`。

**返回值** `FileDialogRequest` — 可轮询的异步请求。

**异常**

- `CuiException` — 文件夹对话框选项非法时；CangHui 不捕获或改写该异常。

### run

进入帧循环直到窗口关闭；`body` 每渲染帧重建视图树。`body` 内可用 [`rememberState`](../core/functions.md#rememberstate) 保留键控局部状态；退出时（含异常路径）先逆序关闭受管资源、再关窗口。

```cangjie
public func run(body: () -> Unit): Unit
```

**参数**

- `body`: `() -> Unit` — 界面构建函数，声明整个界面。

## 另请参阅

- [`UiContext`](../core/UiContext.md) — 帧循环驱动的每帧上下文。
- [`UiOwnerQueue`](../core/UiOwnerQueue.md) — 底层 owner-task 顺序、取消与过期门合同。
- [`rememberState`](../core/functions.md#rememberstate) — 构建间保留的局部状态。
- `WindowSpec` / `SdlWindow`（见同版本 SDL API 参考）— 窗口层。
