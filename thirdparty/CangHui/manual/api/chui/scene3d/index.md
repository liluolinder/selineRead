[chui](../../index.md) › chui.scene3d

# chui.scene3d

```cangjie
import chui.scene3d.*
```

Provider-neutral 的 3D 快照、宿主生命周期、嵌入式 `Scene3DView` 与可选 shared-frame
同树合成合同。产品模型、资产导入、材质、导航与平台驱动不进入公共场景 schema。

## Shared frame

| 类型 | 说明 |
|---|---|
| [`Scene3DCompositionMode`](SharedFrame.md#scene3dcompositionmode) | 选择默认 native child 或显式优先 shared frame。 |
| [`Scene3DSharedFrameProvider`](SharedFrame.md#scene3dsharedframeprovider) | provider 的可选 acquire 扩展。 |
| [`Scene3DSharedFrameRequest`](SharedFrame.md#scene3dsharedframerequest) | 绑定精确 surface/generation/frame 与 placement 的请求。 |
| [`Scene3DSharedFrameLease`](SharedFrame.md#scene3dsharedframelease) | 带 payload、同步事实及 exactly-once finish 的有界资源。 |
| [`Scene3DSharedFrameReleaseReceipt`](SharedFrame.md#释放) | provider release callback 的结构化结果。 |

其余语义实体、相机、provider、view host 和 HarmonyOS XComponent 入口见
[Scene3D 语义投影](../../../reference/scene3d.md)。
