# 跨后端 Graphics 适配

`chui.graphics` 是 CangHui Multiplatform 的 GPU 中立边界。应用描述需要的能力、资源与
绘制意图，平台 provider 再选择 Metal、Vulkan、D3D、OpenGL ES、WebGPU 或软件实现。
后端名称只出现在 provider 的能力与诊断结果里，不应写进业务状态或 Scene3D 模型。

`import chui.*` 会重新导出本页涉及的公开类型。

## 先协商能力

应用使用 `GraphicsAdapterRequest` 提交档位、能力、最低限额与电源偏好；
`GraphicsAdapter` 返回 `GraphicsAdapterSelection`。`Core3D` 是保守的可移植渲染档位，
`Compute3D` 额外要求 compute pipeline 与 storage buffer，`NativeExtended` 则明确接受
平台扩展。`allowFallback` 只允许 provider 返回可见的 `Degraded`，不会把缺失能力伪装成
完整支持。

```cangjie
let request = GraphicsAdapterRequest(
    GraphicsProfile.Core3D,
    powerPreference: GraphicsPowerPreference.HighPerformance,
    requiredCapabilities: [GraphicsCapability.Instancing],
    allowFallback: false
)
let selection = adapter.select(request, surfaceLease)
if (!selection.ok()) {
    throw IllegalStateException(selection.code)
}
```

`GraphicsSurfaceLease` 由宿主创建，包含逻辑/像素尺寸、缩放、颜色空间、透明模式与严格
递增的 generation。`platformToken` 是 provider 私有解析的 opaque token；应用不得把原生
窗口或 GPU handle 塞入场景数据、日志或跨进程协议。

## 再提交保留式 Render Packet

`GraphicsRenderPacket` 携带一组 `GraphicsSceneDelta`。资源与 render item 都使用
`slot + generation` 身份：同一 slot 复用时必须增加 generation，release 后的旧引用不能
重新生效。resource payload、delta 数量与整包字节数都有硬上限。

包可以通过 `packGraphicsRenderPacket` 生成确定性字节；解包和 `NullGraphicsReplay`
会先完整验证，再原子提交。悬空 binding、重复身份、旧 generation、释放仍被引用的资源
或部分失败都不会污染已提交状态。这一 fake replay 证明协议和状态机，不证明 GPU 像素。

## 与 Scene3D 的关系

`Scene3DFrameSnapshot` 是更高层的语义输入；Scene3D provider 可以把模型、材质与相机
翻译为 graphics resources/render items，再交给具体 adapter。应用通常不需要直接构造
render packet，除非正在实现新的渲染层或平台 provider。

当前仓库已经证明公共合同、确定性 replay、macOS arm64 的可选 bgfx4cj/Metal 路径与
HarmonyOS XComponent 宿主入口。它没有据此声称 Vulkan、D3D、OpenGL ES 或 WebGPU
provider 已经完整交付；每个后端仍需独立的编译、像素、生命周期、输入与发布回执。

## 桌面 FrameGraph 与 damage 边界

桌面运行时内部已经能按 build / measure / layout / paint / semantics / hit-test 阶段记录精确
`State` 依赖，事务式提交或回滚保留节点，并把有证明的变化合并为有界 damage。FrameGraph
按完整拓扑身份复用调度结果；每帧的资源验证、damage、pass culling 和执行回执仍重新计算，
不会因为命中 schedule cache 就跳过安全检查。

这不是“任意 Widget 已全面增量执行”的声明。当前只有两类框架自有证明会改变执行方式：稳定
key 下，文本、字体度量 generation、排版环境与约束均完全相同的 `Label` 可以复用已提交的测量
输出；没有自定义 painter、对子树执行 shape 裁剪、且使用框架可解析材质的 `Surface`，可以按
实际阴影偏移与框架阴影余量约束 paint damage。普通 Widget 回调、未裁剪子树、自定义材质
provider、未知 painter、结构或布局不确定性仍保守执行或升级到 full-root damage。当前 SDL
provider 会使用单一 staging/preserve 路径限制内部重绘，
但最终仍调用整窗 `SDL_RenderPresent`；没有声称操作系统 compositor 或 swapchain 已经支持
partial present。

跨后端 AOT pipeline-pack、HDR/EDR 规划与 compute-vector 路径目前保留在 `chui.graphics`
受保护实现面，用于验证 ABI、能力 generation、budget、输出激活回执及 CPU oracle 一致性。
它们尚未从 `chui` 伞包公开，也不能作为 Metal/Vulkan/D3D/GLES/WebGPU provider、实机 HDR
或 GPU compute 已交付的依据。
