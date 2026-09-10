[chui](../../index.md) › [chui.scene3d](index.md) › Shared frame

# Scene3D Shared Frame

## Scene3DCompositionMode

`NativeChild` 是默认路径；`PreferSharedFrame` 只有在 provider 实现
`Scene3DSharedFrameProvider` 且返回当前执行器可安全消费的 lease 时才启用同树合成，否则
保留可见 fallback。

## Scene3DSharedFrameProvider

```cangjie
public interface Scene3DSharedFrameProvider {
    func acquireSharedFrame(request: Scene3DSharedFrameRequest): ?Scene3DSharedFrameLease
}
```

## Scene3DSharedFrameRequest

请求包含 `surfaceId`、`generation`、`frameId`、逻辑宽高、scale、`placementRevision` 与
`rotationCode`。provider 不应猜测或复用旧几何。

## Scene3DSharedFrameLease

lease 声明像素宽高、row bytes、`Scene3DSharedColorSpace`、`Scene3DSharedAlphaMode`、
`Scene3DSharedDynamicRange`、`Scene3DSharedFramePayloadKind` 与 `Scene3DSharedAcquireSync`。
`CpuRgba8` 通过 `copyRgbaPixels()` 返回拥有权副本；`ProviderPrivateTexture` 只携带不透明 token，
公共 API 从不暴露原生 handle。

## 释放

`finish(Scene3DSharedFrameFinishReason)` 接受 `Presented`、`Rejected`、`Fallback`、
`ExecutorFailed`、`Replaced` 或 `Abandoned`，并缓存第一次 release 的
`Scene3DSharedFrameReleaseReceipt`。随后重复 finish/close 不会再次调用 provider callback。

当前 SDL 生产路径只消费有界 SDR `CpuRgba8`；native private texture/fence 与 HDR/EDR 激活
仍待对应 provider 和宿主证明。详见[Scene3D 语义投影](../../../reference/scene3d.md)。
