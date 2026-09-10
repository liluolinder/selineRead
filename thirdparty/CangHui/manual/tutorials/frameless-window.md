# 桌面无边框窗口

CangHui 桌面 `WindowSpec` 支持无边框窗口：

```cangjie
let app = DesktopApp(WindowSpec("MyApp", 720, 480, frameless: true))
```

- `frameless: true` 等价于 `decorated: false`，会设置 `SDL_WINDOW_BORDERLESS`。
- 窗口仍可调整大小（`resizable` 默认 true）。
- 无边框窗口的拖动/窗口控制请使用 `ClientWindowChrome` 组件（最小化/最大化/关闭/拖动）。
- Harmony 后端不受影响。

## 原生主窗口圆角

系统装饰窗口在 macOS 上本来就由 AppKit 提供圆角，不要再叠一层自定义裁切。只有
自绘标题栏/无边框窗口需要显式窗口形状：

```cangjie
let app = DesktopApp(WindowSpec(
    "MyApp",
    720,
    480,
    frameless: true,
    cornerRadius: 18.0
))
```

`cornerRadius` 使用逻辑像素。正值会创建透明窗口并通过 SDL 原生 window shape 裁掉四角；
窗口缩放或 resize 后框架会按物理像素重建 mask，因此透明角也不参与系统命中。它不同于
根组件 `.background(..., radius)`：后者只改变内容绘制，窗口外形仍是矩形。当前实现已在
macOS SDL 路径编译与单元门验证；Windows/Linux 的最终合成外观仍需各平台实机验收。
