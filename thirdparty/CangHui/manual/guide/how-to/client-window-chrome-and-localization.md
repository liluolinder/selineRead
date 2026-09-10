# 自绘标题栏与应用本地化

用无边框原生窗口承载可替换的客户端标题栏，并把应用字符串集中到确定性本地化目录。完成后，桌面端可以绘制自己的最小化、最大化和关闭控件，嵌入式或移动宿主可以隐藏这些控件；同一业务界面也能在运行时选择语言，而不把翻译判断散落在绘制代码中。

## 先划清宿主边界

`WindowSpec(..., decorated: false)` 只在创建窗口时移除系统边框。应用随后必须自行提供可拖动区域、最小化、最大化/恢复和关闭入口；否则用户会得到一个无法正常管理的窗口。

`ClientWindowChrome` 提供默认绘制和这些窗口动作，但不强迫应用采用固定外观。应用可以：

- 直接调用 `draw` 和 `handle` 使用默认标题栏；
- 复用 `ClientWindowChromeStyle` 的几何和 `DesktopApp` 的窗口动作，完全替换绘制；
- 在移动、嵌入式或宿主已提供标题栏时使用 `WindowChromePlacement.Hidden`。

标题栏应先处理指针事件，只有返回 `false` 的事件才继续进入业务内容。这样拖动和窗口按钮不会同时触发下面的画布。窗口按钮从按下到释放会捕获指针；按住移出原按钮后，本次手势永久取消，即使移回原按钮再释放也不会执行窗口动作。

```cangjie
let app = DesktopApp(WindowSpec("Operations", 960, 640, decorated: false))
let chrome = ClientWindowChrome(
    app,
    style: ClientWindowChromeStyle(
        placement: WindowChromePlacement.Trailing,
        height: 36.0,
        accent: Color.rgb(224, 242, 28)
    )
)

// 在自绘根控件中，先 chrome.handle(event, windowFrame)，再路由业务事件。
// 绘制时先 chrome.draw(renderer, windowFrame, title, pointerX, pointerY)，
// 业务内容使用 chrome.contentFrame(windowFrame) 作为可用矩形。
```

跨平台适配通常只需要替换 `ClientWindowChromeStyle`：Windows/Linux 常把控件放在右侧，macOS 风格外壳可放在左侧，移动宿主隐藏。产品如需不同图标、双击标题栏行为或系统菜单，可保留同一内容矩形契约，使用 `DesktopApp.requestWindowClose`、`minimizeWindow`、`toggleMaximizeWindow`、`setWindowPosition`、`windowPosition` 和 `windowFlags` 实现自己的控制器。

## 建立语言目录

`LocalizationCatalog` 是应用字符串的轻量确定性目录。它不规定资源必须来自代码、JSON、TOML 或平台资源包，因此跨平台适配器可以用同一接口灌入翻译。

```cangjie
let zh = LocaleTag.traditionalChinese()
let en = LocaleTag.english()
let strings = LocalizationCatalog(defaultLocale: zh)

strings.put(zh, "window.title", "營運中樞")
strings.put(en, "window.title", "Operations Hub")
strings.put(zh, "action.close", "關閉")
strings.put(en, "action.close", "Close")

let activeLocale = zh
let title = strings.resolve("window.title", activeLocale)
```

解析顺序为：精确语言、该语言的显式回退、目录默认语言、默认语言的显式回退、调用方回退文本、键本身。缺少翻译不会返回空字符串，也不会因为平台资源加载失败而阻断界面。

业务模型保存当前 `LocaleTag`，绘制或声明视图时按稳定键解析。建筑名、菜单名、事件文本和辅助功能标签都应使用同一目录；数值格式、日期格式和复数规则属于更高层的平台格式化能力，不应伪装成普通字符串替换。

## 验收

桌面端至少验证以下路径：窗口无系统边框；标题栏空白处可以拖动；按下控制按钮后移出、移回再松开仍不会执行；释放到标题栏外也不会把半个手势传给业务内容；最小化、最大化/恢复和关闭都可重复使用。嵌入式配置应保留完整内容高度且没有不可见命中区。

本地化至少验证：精确命中、语言回退、默认语言回退和缺键回退；切换语言后同一业务状态不重置。窗口标题、主要导航、动作、状态和错误信息都不应残留硬编码的第二语言。

相关 API：[`DesktopApp`](../../api/chui/desktop/DesktopApp.md)、[`CanvasWidget`](../../api/chui/media/CanvasWidget.md) 与 [`chui` 包入口](../../api/chui/index.md)。
