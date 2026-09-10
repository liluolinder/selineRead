# 实拍截图

本目录保存真机/桌面实拍截图，作为 cuic 能力证据（非像素级回归证明）。

- `canghui-coreplayer.jpeg`：HUAWEI MateBook Pro（HarmonyOS API 24）上
  `cc.c2l.corePlayer` 系统截屏（3120x1755），通过 `cuic prnt --device --app` 获取。
- `canghui-explorer.png`：`cn.cryi.explorerxcui` 系统截屏转换的 PNG（3120x1755）。

说明：当前设备截图走系统截屏 fallback；CangHui 渲染面穿透通道待 Harmony 侧实现。
