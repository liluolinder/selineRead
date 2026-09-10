# SDL 示例集

本目录提供基于 `sdl` 模块的完整可运行示例，每个示例都是独立的 cjpm 可执行项目，
通过路径依赖引用上层的 `sdl` 模块：

```toml
[dependencies]
sdl = { path = "../.." }
```

| 示例 | 内容 | 主要演示 |
|---|---|---|
| [calculator](calculator/) | 四则运算计算器 | 鼠标命中测试、键盘文本输入、圆角面板与按键、文字度量与对齐 |
| [thunder](thunder/) | 雷霆战机纵版射击 | 固定逻辑尺寸的帧循环、按键持续状态、AABB 碰撞、粒子特效、HUD |

两个示例都配有教学文档（各自目录下的 `README.md`），从入口装配、状态建模、事件处理到
渲染分层逐段讲解，适合作为使用 `sdl` 模块开发图形应用的起步范本。

## 构建与运行

在示例目录（`examples/calculator` 或 `examples/thunder`）中：

```powershell
cjpm build
cjpm run
```

## 运行时动态库

`sdl` 模块从仓库根目录的 `.sdl3/` 链接 SDL3 与 SDL3_ttf。运行可执行文件时，Windows 需要能
找到 `SDL3.dll` 与 `SDL3_ttf.dll`：

- `cjpm run` 场景：把 `.sdl3/` 加入 `PATH`，或将两个 DLL 复制到 `target/release/bin/`。
- 分发场景：把 `SDL3.dll`、`SDL3_ttf.dll` 与可执行文件放在同一目录，详见
  [部署、动态库与 FFI 说明](../docs/deployment-and-ffi.md)。

```powershell
# 在示例目录下复制运行时 DLL（一次即可）
Copy-Item ..\..\.sdl3\SDL3.dll, ..\..\.sdl3\SDL3_ttf.dll target\release\bin\
```

文本渲染使用系统 UI 字体（Windows 为 Microsoft YaHei UI / Segoe UI），无需附带字体文件。

## 通用模式

两个示例遵循同一套结构约定，也是推荐给应用项目的组织方式：

- `main.cj` 只做装配：构造 `SdlWindow` 并交给主循环，用 try-with-resources 保证窗口关闭。
- 常量按语义收拢为承载类型（如 `View`、`Stage`、`Pal`），不散落魔法数字。
- 每帧渲染固定走 `beginScene → 绘制 → endScene → present`，由框架完成超采样抗锯齿。
- 事件在 `pollEvent` 循环中取空，输入状态与业务状态分离。
