# SDL3 Apple 宿主说明

[English](sdl3-apple-host.md) | **中文**

## 参考来源

- `Ravbug/sdl3-sample@d6c3c1b46cfab879a4cae71e3da5fb908dc02563`，许可证为 CC0-1.0。
- `KevinVitale/SwiftSDL@c9c26670c6aaa8130001064e3133a305082f70dc`，许可证为 MIT。

这些项目仅作为设计参考。CangHui 没有复制其中的 Swift 或 C++ 源码。

## 两种宿主模式

独立 SDL3 应用和嵌入原生视图是两种不同的部署形态，不应强行共用一个虚假的窗口模型：

- `OwnedWindow`：SDL3 持有应用回调、事件泵、窗口和渲染器，适合独立 CangHui 应用。
- `EmbeddedSurface`：UIKit、HarmonyOS 或其他应用持有原生视图，并把带 generation 的 surface 转交给 CangHui。

两种模式共用 `HostApplicationLoop`、宿主生命周期与输入服务，以及同一棵仓颉组件/布局树。

## 回调生命周期

SDL3 的 `SDL_AppInit`、`SDL_AppIterate`、`SDL_AppEvent`、`SDL_AppQuit` 分别负责初始化、逐帧工作、事件投递与确定性退出。CangHui 使用 `HostLoopResult` 和 `HostApplicationLoop` 表达可跨平台复用的部分，各平台适配层再把这些回调映射到固定的仓颉调度线程。

## Apple 打包事实

Apple 宿主必须保留：

- 真实的应用 Bundle 和启动屏声明；
- 高像素密度窗口创建；
- 分别查询逻辑尺寸与像素尺寸；
- 在 iOS 上静态链接或正确嵌入运行时依赖；
- 把资源放进应用 Bundle，而不是依赖桌面进程相对路径。

## 已有所有权规则

SwiftSDL 的通用指针 owner、销毁回调、类型化 SDL 错误与分配辅助是有价值的绑定模式，但 CangHui 已提供对应规则：

- `Resource` 实现提供幂等、确定性的 `close`；
- `CuiException` 与 SDL 返回值检查；
- 释放 SDL 内存前，把原生数组与字符串转换为仓颉拥有的值；
- `DesktopApp` 按逆序关闭受管资源。

再增加一套通用 owner 抽象会削弱而不是改善当前所有权模型。

## 当前限制

- 仓颉线程采用 M:N 调度，macOS SDL/AppKit 窗口仍要求创建与事件泵处于同一原生线程。
  `cuic prnt` 因此仅为捕获子进程设置 `cjProcessorNum=1`；普通应用若在建窗后执行会挂起
  的启动工作，也必须采用同一约束或把工作移到事件循环启动后。`SdlWindow` 会在轮询前
  检查线程身份，以明确异常替代跨线程原生崩溃。首次 `close()` 采用同一规则：线程不符
  时不会进入任何原生销毁调用，已完成关闭仍保持幂等；若帧循环已有异常，`DesktopApp`
  也会保留原异常而不让清理期线程错误覆盖它。这个 fail-closed 守卫不能在 owner loop
  已消失后恢复清理，应用仍须让首次关闭发生在 owner thread，不能把它当成跨线程编排器。
- 直接绑定 `SDL_EnterAppMainCallbacks` 需要等待完整的 iOS 宿主入口与生命周期集成。
- SDL3 GPU 封装与着色器打包属于渲染器专项工作。
- CangHui 不内置 SDL3 源码或 XCFramework。
- SwiftUI/UIKit 应用外壳属于应用侧代码，不属于公共框架源码。
