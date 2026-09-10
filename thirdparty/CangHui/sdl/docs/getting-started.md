# SDL 快速入门

## 创建项目

```text
hello_sdl/
├── cjpm.toml
└── src/
    └── main.cj
```

`cjpm.toml`：

```toml
[package]
cjc-version = "1.0.5"
name = "hello_sdl"
version = "0.1.0"
output-type = "executable"

[dependencies]
sdl = { path = "../CangHui/sdl" }
```

## 最小渲染循环

```cangjie
package hello_sdl

import sdl.{Color, FontSizes, Rect, SdlWindow, UiEvent, WindowSpec}

main(): Unit {
    let window = SdlWindow(WindowSpec("SDL 仓颉示例", 720, 480))
    try {
        var running = true
        while (running) {
            var current = window.pollEvent()
            while (let Some(event) <- current) {
                match (event) {
                    case UiEvent.Quit => running = false
                    case UiEvent.WindowResized(_, _) => let _ = window.refreshSize()
                    case _ => ()
                }
                current = window.pollEvent()
            }

            let renderer = window.renderer
            renderer.beginScene(Float32(window.width), Float32(window.height), Color.rgb(246, 248, 252))
            renderer.fillRoundedRect(Rect(32.0, 32.0, 260.0, 72.0), 14.0, Color.rgb(35, 112, 215))
            renderer.text("你好，SDL3_ttf", 52.0, 55.0, Color.rgb(255, 255, 255), pointSize: FontSizes.TITLE)
            renderer.endScene()
            renderer.present()
            window.delay(UInt32(16))
        }
    } finally {
        window.close()
    }
}
```

渲染顺序为 `beginScene` → 绘制调用 → `endScene` → `present`。`beginScene` 和 `endScene` 管理框架的
离屏超采样目标；直接调用 `clear` 和 `present` 也可工作，但不会自动使用完整的场景解析流程。

## 构建与运行

```powershell
cjpm build
cjpm run
```

若直接分发可执行文件，必须同时部署 `SDL3.dll` 与 `SDL3_ttf.dll`，详见
[部署、动态库与 FFI](deployment-and-ffi.md)。

## 生命周期要求

- `SdlWindow` 实现 `Resource`，应在 `finally`、try-with-resources 或明确的退出路径中关闭。
- `Surface`、`Texture`、`Cursor` 同样需要确定性关闭。
- `SdlWindow.close` 会释放渲染器内部资源、停止文本输入、销毁窗口并调用 `SDL_Quit`。
- 当前封装以单主窗口生命周期为主要使用模型；不要让多个窗口无序竞争全局 SDL 初始化和退出。
