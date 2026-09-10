# Scene3D 语义投影

CangHui Multiplatform 通过 `chui.scene3d` 提供 provider-neutral 的 3D 场景合同。
应用交付不可变的场景快照；可选 provider 负责把快照投影到具体渲染后端。
应用代码无需引入 bgfx 句柄、shader 字节或原生窗口指针。

`import chui.*` 会重新导出本页使用的 Scene3D 公开类型。

## 语义实体

`Scene3DEntitySnapshot` 保留实体身份、位置、可见性和一个通用类别，并允许以零值
保持类别默认尺寸，或显式提供 `scaleX/Y/Z` 与 `rotationX/Y/Z`。当前投影为八类实体
提供稳定的低多边形几何和颜色语义：

| `Scene3DEntityKind` | 几何家族 | 语义色角色 |
|---|---|---|
| `Floor` | `Slab` | `GroundNeutral` |
| `Route` | `Ribbon` | `RouteAccent` |
| `Vehicle` | `Box` | `VehicleAccent` |
| `UserMarker` | `Marker` | `UserHighlight` |
| `Structure` | `Box` | `StructureNeutral` |
| `Track` | `Ribbon` | `TrackNeutral` |
| `Facility` | `Marker` | `FacilityAccent` |
| `ExitMarker` | `Marker` | `ExitAccent` |

```cangjie
import chui.*

let camera = Scene3DCameraSnapshot(7.2, 5.4, 8.8, 0.0, -0.5, 0.0,
    fieldOfViewY: 48.0)
let frame = Scene3DFrameSnapshot("station-debug", camera: Some(camera))
frame.add(Scene3DEntitySnapshot(
    "floor",
    0.0,
    -0.35,
    0.0,
    kind: Scene3DEntityKind.Floor,
    scaleX: 4.8,
    scaleY: 0.10,
    scaleZ: 3.2
))
frame.add(Scene3DEntitySnapshot(
    "route-main",
    0.0,
    -0.18,
    0.0,
    kind: Scene3DEntityKind.Route
))
frame.add(Scene3DEntitySnapshot(
    "vehicle-01",
    0.55,
    0.0,
    0.0,
    kind: Scene3DEntityKind.Vehicle
))
frame.add(Scene3DEntitySnapshot(
    "user",
    -0.65,
    0.0,
    0.0,
    kind: Scene3DEntityKind.UserMarker
))
frame.seal()
```

`projectScene3DEntity` 把单个快照转换为 `Scene3DDebugEntityProjection`，同时保留
`entityId`、位置、尺寸、旋转和 `visible`。`Scene3DFrameSnapshot.camera` 是可选的；未提供
时 provider 保持原有默认相机。不指定 `kind`、相机或变换的旧构造调用仍按原有默认值
处理，因此原有消费者不需要为新增字段立即改写。

## Provider 边界

`Scene3DProvider` 按 attach / load / submit / present / detach 生命周期工作。快照在 submit
边界上封闭，provider 必须继续遵守 surface generation 和 frame ordering 检查。
`visible == false` 的实体保留在输入快照中，但不应提交可见几何。

框架仓内的 [`scene3d-bgfx`](../../packages/scene3d-bgfx/README.md) 是一个可选实现，目前只提供
macOS arm64 Metal 的当前主机验证。普通 CangHui 构建和一般消费者不会因此下载、
编译或链接 bgfx 原生库。

## Shared-frame 同树合成

`Scene3DView` 默认保持 `Scene3DCompositionMode.NativeChild`。需要让 3D 像素参与普通组件树
的 sibling z-order、祖先 clip、圆角和焦点绘制时，应用可以显式选择
`PreferSharedFrame`，并让 provider 同时实现 `Scene3DSharedFrameProvider`：

```cangjie
let controller = Scene3DViewController(
    "station-scene",
    host,
    provider,
    resource,
    frameSource,
    compositionMode: Scene3DCompositionMode.PreferSharedFrame
)
```

一次 acquire 使用 `Scene3DSharedFrameRequest` 绑定精确的 surface/generation/frame、逻辑尺寸、
缩放、placement revision 与设备方向。provider 返回的 `Scene3DSharedFrameLease` 还必须声明
像素尺寸、row bytes、颜色空间、alpha、动态范围、payload 类别与 acquire sync。框架会拒绝
旧 generation、错 frame、错 placement、溢出尺寸、需要等待但当前执行器无法兑现的同步，以及
当前路径不能安全消费的 payload。

当前生产可用路径是 `CpuRgba8`：SDL compositor 把最多 256 MiB 的自有像素副本上传到同一个
renderer device，在 `Scene3DView` 的正常 draw 位置以圆角纹理网格采样，因此不会绕过 sibling
顺序或祖先裁剪。lease 在 present、fallback、执行器失败、替换或放弃后调用一次
`finish(reason)`；回调异常被收敛为结构化 release receipt，不会重复释放。

`ProviderPrivateTexture` 与 opaque token/acquire-sync 合同已经存在，但当前选择的 SDL executor
没有据此声称原生 Metal/Vulkan/D3D/GLES/WebGPU 纹理与 fence 已经接通。`Extended` 动态范围
也只是内容意图，不是宿主已激活 HDR/EDR 的证明；当前 shared-frame 生产路径只接受 SDR。
因此这一版可用于同树 demo 与产品原型，但“零拷贝原生共享”和“实机 HDR 输出”仍需逐 backend
provider 与宿主回执。

## macOS 嵌入式 provider

需要 Metal 3D 的应用先把冻结的 bgfx 原生归档与 SDL 动态库准备到一个同机目录：

```bash
BGFX4CJ_ROOT=/path/to/bgfx4cj \
BGFX_NATIVE_ROOT=/path/to/accepted-native-archives \
./scripts/prepare-scene3d-bgfx-macos-native.sh /tmp/chui-scene3d-native

export CANGHUI_SCENE3D_BGFX_MACOS_NATIVE_DIR=/tmp/chui-scene3d-native
export DYLD_LIBRARY_PATH="$CANGHUI_SCENE3D_BGFX_MACOS_NATIVE_DIR:${DYLD_LIBRARY_PATH:-}"
```

应用的 `cjpm.toml` 只需同时引用 `chui` 和 `canghui_scene3d_bgfx`。provider 通过
`[ffi.c]` 把自身的原生归档传给最终链接，应用不需要复制 provider 源码或复写一组
bgfx/framework 链接参数。完整构造和同窗口嵌入方式见
[`scene3d-bgfx-metal-embedded`](../../examples/scene3d-bgfx-metal-embedded/)。

```toml
[dependencies]
chui = { path = "/path/to/CangHui" }
canghui_scene3d_bgfx = { path = "/path/to/CangHui/packages/scene3d-bgfx" }
```

这是 macOS arm64 的源码包加同机原生包流程，还不是跨平台二进制 SDK。Windows、
Linux 以及 macOS x86_64 仍需要各自 provider 和制品验证。

## HarmonyOS XComponent 宿主

`HarmonyXComponentScene3DHost` 已把 XComponent 的原生 surface 生命周期接到与 macOS
相同的 `Scene3DViewHost` SPI。CangHui 只接收整数事实，不拥有 ArkTS 组件、
`OH_NativeXComponent`、HAP 身份、签名或产品输入策略。

应用侧构造 host 后继续使用普通的 `Scene3DViewController`。Vulkan 是默认后端；若平台
provider 明确走 EGL/GLES，可在构造时选择 `NativeSurfaceBackend.OpenGLES`。

```cangjie
let host = HarmonyXComponentScene3DHost(
    "station-scene",
    requestDisplayFrame: { => platformDisplayScheduler.requestFrame() }
)
let controller = Scene3DViewController(
    "station-scene", host, provider, resource, frameSource
)
```

平台原生层包含
[`CangHuiHarmonyXComponentHost.h`](../../platform/harmony/include/CangHuiHarmonyXComponentHost.h)，
并在已有 XComponent 生命周期点按以下顺序提交：

1. `surface-created`：递增 generation，调用 `canghui_harmony_surface_attach`；
2. `surface-changed`：保持 generation，调用 `canghui_harmony_surface_resize`；
3. display/vsync callback：调用 `canghui_harmony_surface_frame`；
4. `surface-destroyed`：调用 `canghui_harmony_surface_detach`。

`native_window` 转换为 `int64_t` 只发生在同一进程的 native ingress；公开 receipt、场景
快照和应用模型都不会携带指针。回调只更新 mutex 保护的整数快照，renderer、observer
与 provider 生命周期由 CangHui UI owner 调用 `host.refresh()` 或 `requestFrame()` 时消费。
旧 generation 会返回 `-2`；非正 handle、超出 `65535` 的单边像素尺寸、超出
`0.1–16.0` 的缩放或倒退的帧时钟返回 `-1`。

平台侧可以在现有 `CangHUI_OHOS_SurfacePublish` 同一回调中并列提交这个 ABI：前者继续
服务 SDL/OHNativeWindow provider，后者服务 CangHui `Scene3DViewHost`。这是接线合同，
不是 HAP 或真机验收声明；真机证明仍须由 Harmony owner 构建、安装并用 `hap prnt`
留存 attach / resize / frame / detach 收据。

## macOS 关闭生命周期

可选 `MacOSSdlMetalHost` 在 `pump()` 中排空 SDL event 队列。收到
`SDL_EVENT_QUIT` 后，`shouldClose()` 返回 `true`；消费者应结束自己的正常帧循环，
随后调用 provider `detach` 并关闭宿主。`shouldClose()` 只是关闭请求，不会替产品
决定路由状态、资源策略或退出文案。

```cangjie
while (!host.shouldClose()) {
    host.pump()
    let _ = provider.submit(frame, clock)
    let _ = provider.present(clock)
}
let _ = provider.detach(surface.id, surface.generation)
host.close()
```

确定性捕获可以按固定帧数退出，但一次捕获成功不能替代正常窗口关闭路径的证明。
通用 provider 的 Metal 图也不能替代产品消费者证明：产品仍需拥有领域对象映射、
用户入口、fallback、生命周期和最终制品验收。

## 非目标

这一通用投影不是产品场景模型、材质系统或美术规范。它不包含模型/纹理导入、
文字标注、拾取、碰撞、导航算法、实时传输或移动端渲染认证。
产品可以把自身领域对象投影为上述八类通用低多边形实体，但领域类型不应进入 CangHui
公开合同。
