# SDL API 参考

本文档覆盖 `sdl` 模块的应用级公开 API。`sdl.text`、raw 文件和任何非 `public` 声明均为实现细节。

## 包与导入

| 包 | 公开能力 |
|---|---|
| `sdl` | 几何、事件、渲染、表面、纹理、窗口、图标、版本 |
| `sdl.dialogs` | 文件对话框、消息框 |
| `sdl.displays` | 显示器与全屏模式 |
| `sdl.input` | 剪贴板、键盘、鼠标、光标 |
| `sdl.system` | 元数据、路径、文件系统、Hints、平台与时间 |

## 错误类型

`CuiException <: Exception` 表示 SDL 初始化、原生调用、资源状态或输入校验失败。尽管名称沿用 CangHui，
该异常定义在独立 `sdl` 根包中，单独使用 SDL 模块时同样适用。

## 字号

`FontSizes` 提供静态值：`CAPTION=13`、`BODY=15`、`CONTROL=15`、`TITLE=20`、`DISPLAY=32`。

## 几何与颜色

### `Color`

字段：`r`、`g`、`b`、`a: UInt8`。构造函数接受 RGB 或 RGBA 通道。

| 方法 | 说明 |
|---|---|
| `Color.rgb(r, g, b)` | 由 `Int64` 创建不透明颜色，自动限制通道范围 |
| `Color.rgba(r, g, b, a)` | 创建带透明度颜色 |
| `withAlpha(alpha)` | 返回替换透明度后的颜色 |

### 几何值类型

| 类型 | 字段/构造 | 辅助方法 |
|---|---|---|
| `Point` | `x`、`y: Float32` | — |
| `Size` | `w`、`h: Float32` | `zero()` |
| `Insets` | `top/right/bottom/left`；支持统一值或四边值构造 | `horizontal()`、`vertical()` |
| `Rect` | 可变 `x/y/w/h` | `zero`、`right`、`bottom`、`centerX`、`centerY`、`inset`、`shift`、`contains` |
| `Pen` | 命名参数 `width`、`color` | — |

`clampF32(value, low, high)` 将浮点值限制在闭区间内。

### `SurfaceStyle`

字段：`fill`、`border`、`radius`、`borderWidth`、`shadow`、`shadowOffsetY`。构造时除 `fill` 外均有
透明或零值默认值。`withFill`、`withBorder` 返回保留其他字段的新样式。

## 事件

### `Key`

成员：`Escape`、`Backspace`、`Enter`、`Tab`、`Delete`、`Space`、`Home`、`End`、`Left`、
`Right`、`Up`、`Down`、`Letter(UInt8)`、`Digit(UInt8)`、`RawScancode(Int32)`。

### `MouseButton`

成员：`Left`、`Middle`、`Right`、`RawCode(UInt8)`。

### `FrameInfo`

字段：`elapsedMs` 为 SDL 启动后的累计毫秒，`deltaMs` 为当前帧与上一帧的毫秒差。

### `UiEvent`

| 类别 | 枚举成员 |
|---|---|
| 生命周期 | `Frame(FrameInfo)`、`Quit`、`WindowResized(Int32, Int32)` |
| 键盘文本 | `KeyDown(Key, Bool)`、`KeyUp(Key)`、`TextInput(String)` |
| 鼠标 | `MouseMove`、`MouseDown`、`MouseUp`、`MouseWheel` |
| 拖放 | `DropBegin`、`DropFile`、`DropText`、`DropPosition`、`DropComplete` |
| 兜底 | `Unknown(UInt32)` |

鼠标和拖放坐标已按 `WindowSpec.scale` 换算为逻辑坐标；`KeyDown` 的第二个参数表示重复按键。

## `Renderer`

`Renderer` 由 `SdlWindow.renderer` 提供；通常不直接构造。`headless()` 用于无窗口测试。

### 帧与状态

| 方法 | 说明 |
|---|---|
| `beginScene(logicalWidth, logicalHeight, clearColor)` | 开始场景并准备超采样目标 |
| `endScene()` | 将高分辨率目标解析到窗口 |
| `present()` | 提交当前帧 |
| `clear(color)`、`setColor(color)` | 清屏和设置基础绘制颜色 |
| `setScale(scale)` | 设置渲染缩放，必须大于零 |
| `setVSync(vsync)`、`vsync()` | 设置/读取垂直同步模式 |
| `setViewport(rect)`、`resetViewport()`、`viewport()` | 视口控制 |
| `setClip(rect)`、`resetClip()`、`clipRect()`、`clipEnabled()` | 裁剪控制 |
| `setColorScale(scale)`、`colorScale()` | 颜色缩放 |
| `setColorFloat(r,g,b,a)` | 使用 `0..1` 浮点通道设置颜色 |

### 图元与文本

| 方法组 | 方法 |
|---|---|
| 基础 | `point`、`line`、`rect`、`fill` |
| 描边 | `strokeLine`、`strokeRect`、`strokeRoundedRect`、`strokeCircle` |
| 填充 | `fillRoundedRect`、`fillRoundedRectSoft`、`fillCircle` |
| 圆 | `circle`，可指定最小分段数 |
| 文本 | `text`、`textCenter`、`textWidth`、`textHeight` |
| 截图 | `captureBmp(path)` |

文本方法默认使用 `FontSizes.BODY`。`fillRoundedRectSoft` 的 `feather` 表示边缘渐隐宽度。

## 表面与纹理

### `Surface <: Resource`

| API | 说明 |
|---|---|
| `Surface.create(width, height)` | 创建 RGBA 表面 |
| `Surface.load(path)` | 根据扩展名读取 BMP/PNG |
| `loadBmp`、`loadPng` | 显式格式读取 |
| `clear(color)`、`writePixel(x,y,color)` | 修改像素 |
| `saveBmp(path)` | 保存 BMP |
| `isClosed()`、`close()` | 生命周期管理 |

`ImageFileFormat` 包含 `Bmp`、`Png`；`imageFormatFromPath(path)` 按扩展名判断，非 PNG 默认 BMP。

### `Texture <: Resource`

字段：`width`、`height`。方法：`size`、`setColorMod`、`setAlpha`、`setBlendMode`、`isClosed`、`close`。

`TextureBlendMode`：`None`、`Blend`、`Add`、`Mod`、`Mul`。
`TextureFlip`：`None`、`Horizontal`、`Vertical`、`Both`。

`TextureRenderOptions(source=None, center=None, flip=None)` 保存旋转绘制的可选源矩形、中心和翻转模式。

渲染器纹理扩展：

- `textureFromSurface(surface): Texture`
- `loadTexture(path): Texture`
- `texture(texture, destination, source=None): Unit`
- `textureRotated(texture, destination, angle, options=TextureRenderOptions()): Unit`

## 窗口

### `WindowSpec`

`WindowSpec(title, width, height, resizable=true, highDpi=true, scale=1.0, vsync=true, supersample=2, decorated=true, frameless=false, cornerRadius=0.0)`。非正缩放会归一化为 `1.0`；`decorated=false` / `frameless=true` 在创建时请求无系统边框窗口，应用必须自行提供拖动、最小化、最大化和关闭入口。正 `cornerRadius` 以逻辑像素创建透明原生 window shape，并在 resize 后重建；系统装饰窗口通常应保留 `0.0`，交给平台绘制自身圆角。

### `SdlWindow <: Resource`

公开字段：可变 `width`、`height`，只读 `scale`、`renderer`、`id`。

| 功能 | 方法 |
|---|---|
| 基础 | `setTitle`、`setSize`、`refreshSize`、`pollEvent`、`pollEventEnvelope`、`ticks`、`delay` |
| 文本输入 | `setTextInputArea` |
| 生命周期 | `isClosed`、`close` |
| 位置尺寸 | `setPosition`、`position`、`setMinimumSize`、`setMaximumSize` |
| 外观 | `setBordered`、`setResizable`、`setAlwaysOnTop`、`setOpacity` |
| 显示状态 | `show`、`hide`、`raiseWindow`、`maximize`、`minimize`、`restore`、`setFullscreen` |
| 同步提示 | `sync`、`flash`、`setRelativeMouseMode` |
| 查询 | `title`、`windowFlags`、`shapeReceipt`、`sizeInPixels`、`safeArea`、`minimumSize`、`maximumSize` |
| 边框缩放 | `borderSize`、`setAspectRatio`、`aspectRatio`、`opacity`、`pixelDensity`、`displayScale` |
| 抓取焦点 | `setKeyboardGrab`、`setMouseGrab`、`keyboardGrabbed`、`mouseGrabbed` |
| 鼠标区域 | `setMouseGrabRect`、`mouseGrabRect`、`setFocusable`、`showSystemMenu` |
| 任务进度 | `setProgressState`、`progressState`、`setProgressValue`、`progressValue` |
| 平台扩展 | `setFillDocument` |

### 窗口值类型

- `WindowPosition(x,y)`。
- `WindowAspectRatio(minimum,maximum)`。
- `WindowBorderSize(top,left,bottom,right)`。
- `WindowFlash`：`Cancel`、`Briefly`、`UntilFocused`。
- `WindowProgressState`：`Inactive`、`Indeterminate`、`Normal`、`Paused`、`Error`。
- `WindowShapeApplyStatus`：`NotRequested`、`Applied`、`Failed`；`WindowShapeReceipt` 记录请求
  半径、实际应用半径、像素尺寸和运行时结果，但不把一次 API 成功误报成目标合成器视觉验收。
- `WindowFlags`：保存 `raw` 及 fullscreen、hidden、resizable、focus、grab、high-DPI、Vulkan、Metal、
  transparent 等 SDL 窗口标志的布尔解析结果。

## 图标与版本

`IconName`：`NewDocument`、`OpenFolder`、`Save`、`SaveAs`、`Copy`、`Paste`、`Refresh`、`Trash`、
`Brush`、`Calendar`、`Process`、`Calculator`、`ChevronLeft`、`ChevronRight`。

`drawIcon(renderer, icon, rect, color, weight=1.6)` 绘制矢量图标。
`sdlVersion()` 返回 SDL 整数版本，`sdlRevision()` 返回修订字符串。

## `sdl.input`

### 剪贴板

`ClipboardData(mimeType, bytes)` 表示一个 MIME 数据项。

`Clipboard` 静态方法：`setText`、`hasText`、`getText`、`setPrimarySelectionText`、
`hasPrimarySelectionText`、`getPrimarySelectionText`、`setData`、`clearData`、`hasData`、`getData`、
`mimeTypes`。`getData` 返回 `?Array<UInt8>`。

### 键盘与鼠标

`KeyModifiers` 包含 `raw`、`shift`、`ctrl`、`alt`、`gui`、`command`、`capsLock`、`numLock`、
`mode`、`scrollLock`、`level5`。`Keyboard.modifiers()` 获取当前状态。

`MouseState` 包含坐标、左/中/右键和原始按键位；`Mouse.state(scale=1)` 查询状态，
`Mouse.capture(enabled)` 控制捕获。

### 光标

`SystemCursor` 覆盖默认、文本、等待、十字、进度、移动、禁止、指针及各方向缩放光标。
`Cursor.system(kind)` 创建光标；实例方法为 `setActive`、`isClosed`、`close`，静态方法为
`show`、`hide`、`isVisible`。

## `sdl.dialogs`

### 文件对话框

- `FileDialogFilter(name, pattern)`：筛选器名称与 SDL 扩展模式。
- `FileDialogOptions(filters=[], defaultLocation=None, allowMany=false)`：可变配置。
- `FileDialogResult`：`Pending`、`Canceled`、`Selected(paths, filterIndex)`、`Failed(message)`，实际枚举名
  均带 `FileDialog` 前缀。
- `FileDialogRequest.result()`、`isDone()`：异步结果查询。
- `FileDialogs.openFile/saveFile/openFolder(options, window=None)`：启动原生对话框。

### 消息框

- `MessageBoxKind`：`Error`、`Warning`、`Information`。
- `MessageBoxButtonOrder`：平台默认、从左到右、从右到左。
- `MessageBoxButton(label, id, returnKeyDefault=false, escapeKeyDefault=false)`。
- `MessageBoxColor` 与 `MessageBoxColorScheme`：消息框颜色配置。
- `MessageBoxOptions(title,message)`：可变 `kind`、按钮、顺序和可选颜色方案。
- `showSimpleMessageBox(...)`：显示简单消息框。
- `showMessageBox(options, window=None): Int32`：返回按钮 ID。

## `sdl.displays`

### 数据类型

- `DisplayOrientation`：未知、横向、翻转横向、纵向、翻转纵向。
- `DisplayMode`：宽、高、像素密度、刷新率。
- `DisplayGeometry`：完整边界、可用边界、内容缩放。
- `DisplayOrientations`：自然方向和当前方向。
- `DisplayModes`：可选桌面模式和当前模式。
- `DisplayInfo`：ID、名称、几何、方向、模式。
- `FullscreenModeRequest(width,height,refreshRate=0,includeHighDensityModes=true)`。

### 查询函数

`displayIds`、`primaryDisplayInfo`、`displayInfo`、`allDisplayInfos`、`fullscreenDisplayModes`、
`closestFullscreenDisplayMode`、`displayInfoForPoint`、`displayInfoForRect`。

## `sdl.system`

### 应用元数据

`AppMetadataType`：应用、游戏、媒体播放器或自定义类型。
`AppMetadataProperty`：名称、版本、标识符、创建者、版权、URL、应用类型或自定义属性。

`AppMetadata` 可变字段：`name`、`version`、`identifier`、`creator`、`copyright`、`url`、`appType`。
构造函数直接接收前三项，其余可在创建后赋值。

`ApplicationMetadata` 静态方法：`apply`、`set`、`remove`、`get`。

### 路径与文件系统

`UserFolder`：Home、Desktop、Documents、Downloads、Music、Pictures、PublicShare、SavedGames、
Screenshots、Templates、Videos。

`ApplicationPaths`：`basePath`、`currentDirectory`、`preferencePath(org,app)`、`userFolder`。

`FileSystemEntryType`：Missing、File、Directory、Other。`PathInfo` 保存类型、大小和创建/修改/访问时间。
`FileSystem`：`createDirectory`、`remove`、`rename`、`copyFile`、`pathInfo`、`exists`、
`globDirectory(path, pattern=None, caseInsensitive=false)`。

### SDL Hints

`HintPriority`：Default、Normal、Override。`SdlHint` 包含 AppId、AppName、文件对话框驱动、IME UI、
鼠标焦点、VSync、回车隐藏 IME、屏保、视频驱动、Windows Alt+F4 和自定义提示。

`SdlHintSetting(hint,value,priority=Normal)`。`SdlHints` 方法：`set`（两个重载）、`setBool`、`apply`、
`get`、`getBool`、`reset`、`resetAll`。

### 平台、电源与 CPU

- `platformName(): String`
- `cpuInfo(): CpuInfo`：逻辑核心、缓存线、内存、页大小及 SIMD 能力。
- `powerInfo(): PowerInfo`：`PowerState`、可选剩余秒数和电量百分比。
- `openUrl(url): Unit`

`PowerState`：Error、Unknown、OnBattery、NoBattery、Charging、Charged。

### 时间

`DateFormat`、`ClockFormat`、`Weekday` 表示区域格式和星期。`DateTimeLocalePreferences` 保存日期格式与
时钟格式偏好。`DateTimeParts` 保存年月日、时分秒、纳秒、可选星期和 UTC 偏移。
`WindowsFileTime` 保存高低 32 位。

`Time` 静态方法：`currentNanoseconds`、`currentDateTime(local=true)`、`toDateTime`、`toNanoseconds`、
`toWindowsFileTime`、`fromWindowsFileTime`、`daysInMonth`、`dayOfYear`、`dayOfWeek`、
`localePreferences`。

### 高精度计时

`PerformanceClock`：`ticksMilliseconds`、`ticksNanoseconds`、`counter`、`frequency`、
`delayNanoseconds`、`delayPrecise`、`millisecondsToNanoseconds`。
