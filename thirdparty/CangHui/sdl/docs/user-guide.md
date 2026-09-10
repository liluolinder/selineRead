# SDL 使用指南

## 1. 窗口与事件循环

`WindowSpec` 配置标题、逻辑宽高、可调整大小、高 DPI 和逻辑缩放。`SdlWindow` 创建窗口和渲染器，
自动启动文本输入，并把 SDL 事件转换成 `UiEvent`。

事件轮询返回 `?UiEvent`。应持续调用，直到返回 `None`：

```cangjie
var current = window.pollEvent()
while (let Some(event) <- current) {
    match (event) {
        case UiEvent.Quit => running = false
        case UiEvent.KeyDown(key, repeat) => handleKey(key, repeat)
        case UiEvent.MouseDown(button, x, y) => beginAction(button, x, y)
        case _ => ()
    }
    current = window.pollEvent()
}
```

窗口扩展方法覆盖位置、最小/最大尺寸、边框、置顶、透明度、显示、最小化、全屏、鼠标相对模式、
输入抓取、进度状态和运行时查询。平台不支持的 SDL 能力可能抛出 `CuiException`。

## 2. 坐标、颜色与样式

- `Point`、`Size`、`Rect` 使用 `Float32` 逻辑坐标。
- `Insets` 表示上、右、下、左内边距。
- `Color.rgb/rgba` 接收 `Int64` 通道并自动限制到 `0..255`。
- `Pen` 组合描边宽度与颜色。
- `SurfaceStyle` 组合填充、边框、圆角、阴影，并提供 `withFill`、`withBorder` 派生方法。

`Rect.inset`、`shift`、`contains` 和中心点方法适合命中测试和布局计算。

## 3. 渲染器

`Renderer` 支持以下绘制层次：

- 基础图元：`point`、`line`、`rect`、`fill`。
- 抗锯齿描边：`strokeLine`、`strokeRect`、`strokeRoundedRect`、`strokeCircle`。
- 填充图元：`fillRoundedRect`、`fillRoundedRectSoft`、`fillCircle`。
- 文字：`text`、`textCenter`、`textWidth`、`textHeight`。
- 纹理：`texture`、`textureRotated`。
- 状态：缩放、视口、裁剪、颜色缩放、垂直同步和渲染目标解析。

`Renderer.headless()` 返回无设备渲染器，适合测试布局和事件逻辑。无头契约：**所有渲染入口均为
无操作**（含 `beginScene`/`endScene`/`clear`/`present`/`captureBmp` 与全部图元、视口、垂直同步、
颜色缩放设置），**所有查询返回中性值**（`vsync()` 为 0、`viewport()` 为零矩形、`colorScale()` 为
1.0；裁剪查询回退到逻辑裁剪栈——`pushClip`/`popClip`/`currentClip` 无头下照常维护）。文本度量
使用确定性的替身宽高，便于断言；它不代表真实字体或 GPU 输出验证。

## 4. 字体与文本

文本后端使用 SDL3_ttf 和平台 UI 字体候选：

- Windows：Microsoft YaHei UI，回退到 Segoe UI。
- macOS：优先使用已安装的 HarmonyOS Sans SC，其次尝试 PingFang、Hiragino Sans GB、STHeiti，
  最后才退化到 SF 系统字体。
- Linux：Noto Sans CJK，回退到 DejaVu Sans。

`FontSizes` 提供 `CAPTION=13`、`BODY=15`、`CONTROL=15`、`TITLE=20`、`DISPLAY=32`。渲染器按字号
缓存字体和文本对象，`textWidth` 与绘制使用相同字形度量。若系统没有任何候选字体，窗口初始化会
抛出 `CuiException`，而不是悄然使用低清位图字体。

粗体解析优先使用字体文件内部的真实 `Bold` 命名实例（随包 HarmonyOS Sans SC 为可变字体），
其次尝试独立的 Bold 伴随文件，最后才在基础字面上合成；因此 `.bold()` 不应从 HarmonyOS Sans
静默切换到系统字体，也不应把 Regular 的合成增宽冒充真实 Bold 字重。

## 5. 表面与纹理

`Surface` 是 CPU 侧像素表面：

```cangjie
try (surface = Surface.create(128, 128)) {
    surface.clear(Color.rgba(0, 0, 0, 0))
    surface.writePixel(10, 10, Color.rgb(255, 0, 0))
    surface.saveBmp("output.bmp")
}
```

可通过 `Surface.load` 按扩展名读取 BMP 或 PNG，也可显式调用 `loadBmp`、`loadPng`。

纹理由渲染器创建：

```cangjie
let texture = window.renderer.loadTexture("image.png")
try (resource = texture) {
    resource.setBlendMode(TextureBlendMode.Blend)
    window.renderer.texture(resource, Rect(20.0, 20.0, 320.0, 180.0))
}
```

`TextureRenderOptions` 控制源区域、旋转中心和水平/垂直翻转。关闭后的表面或纹理不可重复用于创建或
绘制，封装会抛出 `CuiException`。

## 6. 输入

- `Keyboard.modifiers()` 返回 Shift、Ctrl、Alt、GUI/Command 和锁定键状态。
- `Mouse.state(scale)` 返回按逻辑缩放换算后的坐标和按键状态。
- `Mouse.capture(enabled)` 控制全局鼠标捕获。
- `Cursor.system(kind)` 创建系统光标；`setActive` 激活，`show/hide/isVisible` 控制可见性。
- `Clipboard` 支持普通文本、主选择文本和自定义 MIME 二进制数据。

传入剪贴板的 MIME 类型、数据数组和文本会经过边界校验。调用方仍应限制外部数据大小并验证业务格式。

## 7. 对话框

### 文件对话框

`FileDialogs.openFile/saveFile/openFolder` 返回 `FileDialogRequest`。SDL 文件对话框为异步 API：

```cangjie
let request = FileDialogs.openFile(
    options: FileDialogOptions(filters: [FileDialogFilter("文本", "txt")]),
    window: Some(window)
)

match (request.result()) {
    case FileDialogResult.FileDialogPending => ()
    case FileDialogResult.FileDialogSelected(paths, _) => usePaths(paths)
    case FileDialogResult.FileDialogCanceled => ()
    case FileDialogResult.FileDialogFailed(message) => report(message)
}
```

筛选模式应使用 SDL 接受的扩展名形式，不包含路径分隔符或通配符。`allowMany` 控制是否允许多选。

### 消息框

`showSimpleMessageBox` 显示单按钮提示；`showMessageBox` 支持按钮 ID、默认回车/退出按钮、按钮顺序和
颜色方案，并返回用户选择的按钮 ID。

## 8. 显示器

`primaryDisplayInfo`、`displayInfo`、`allDisplayInfos` 返回显示器名称、边界、可用区域、内容缩放、
方向和当前模式。`fullscreenDisplayModes` 枚举全屏模式，`closestFullscreenDisplayMode` 查找最接近
给定尺寸和刷新率的模式。显示器 ID 由 SDL 管理，不应持久化到跨进程配置。

## 9. 系统与文件能力

- `ApplicationMetadata`：设置应用名称、版本、标识符、创建者、URL 和类型。
- `ApplicationPaths`：查询程序目录、当前目录、偏好目录和用户文件夹。
- `FileSystem`：目录创建、删除、重命名、复制、路径信息和目录 glob。
- `SdlHints`：在 SDL 初始化前或运行时设置支持的提示项。
- `platformName`、`cpuInfo`、`powerInfo`：平台、CPU/内存和电源信息。
- `Time`：当前时间、日期分解、Windows FILETIME、日历辅助和区域格式偏好。
- `PerformanceClock`：毫秒/纳秒时钟、性能计数器和精确延迟。

窗口创建前生效的 Hints 必须在构造 `SdlWindow` 或 `DesktopApp` 之前设置。

## 10. 错误和线程约束

SDL 返回失败、空指针或非法状态时通常转换为 `CuiException`。可预期的“无结果”使用 `Option`，异步
对话框状态使用枚举。窗口创建、事件轮询、渲染和资源销毁应位于同一 UI 线程；不要在后台线程直接
操作窗口或渲染器。
