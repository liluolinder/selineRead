# SDL 模块文档中心

本目录记录独立 `sdl` 模块的使用方式、公开 API 和原生部署要求。

1. [快速入门](getting-started.md)：建立依赖并运行窗口与渲染循环。
2. [SDL 使用指南](user-guide.md)：窗口、事件、绘制、文本、资源、输入和系统集成。
3. [SDL API 参考](api-reference.md)：按包查阅公开类型、枚举和方法。
4. [部署、动态库与 FFI](deployment-and-ffi.md)：Windows 动态库、cjpm 链接名和内部 ABI 边界。

## 模块定位

`sdl` 是 SDL3 和 SDL3_ttf 的仓颉安全封装，可独立用于游戏和图形应用，也作为 CangHui 的底层运行时。
应用 API 使用仓颉类型表达，不暴露原始 C 指针。除非参与模块开发，不应导入 `sdl.text` 或依赖
任何 raw 声明。
