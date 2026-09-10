# 移动应用宿主

[English](mobile-application-host.md) | **中文**

`canghui.mobile-application-host.v0` 是 CangHui 与 iOS、Android、HarmonyOS
应用宿主之间的公共边界。它补充现有生命周期、视口、触摸、存储和原生 Surface
契约，但不替代平台 SDK，也不会凭空生成可上架安装包。

## Provider 边界

每个平台 Provider 实现 `MobileApplicationHostProvider`，并报告：

- 平台与安装包类型；
- 当前应用生命周期及 lifecycle epoch；
- 当前原生 Surface generation；
- 所请求宿主能力的权限状态，并写入 receipt；
- 已有证据真正达到的最高打包阶段。

原生回调携带 `MobileHostCallbackContext`。只有 lifecycle epoch 与 Surface
generation 同时匹配当前 receipt，回调才可进入 Cangjie UI owner queue。这样可
避免旧 Scene、Activity、Ability 或已销毁 Surface 把过期动作送入当前界面。

## 证据阶段

| 阶段 | 含义 | 明确不代表 |
| --- | --- | --- |
| `contract-ready` | Provider 能消费公共契约。 | 尚无平台输入树。 |
| `input-tree` | 平台元数据、资源和原生输入已具备。 | 结果不可宣称可安装。 |
| `signed-package` | 平台安装包已有有效签名证据。 | 尚无真机运行证明。 |
| `device-proven` | 已签名安装包通过有记录的真机回放。 | 不等于商店发布或生产就绪。 |

公共 transition predicate 只允许单步向前推进，Provider 在应用新 receipt 时必须
拒绝回退。`MobileHostPackageReceipt` 会拒绝平台与安装包类型不匹配、输入树阶段
后仍为空、同一 capability 出现重复权限项、未签名却声称可安装，以及没有通过
真机回放却声称 `device-proven` 的 receipt。JSON schema 同步表达阶段前置条件；
跨项的重复权限检查仍由运行时完成。

## 当前平台状态

- iOS/iPadOS 已有 UIKit `CAMetalLayer` 原生 Surface 适配器，以及历史模拟器、
  真机 bootstrap 证明。`IOSMobileApplicationHostProvider` 现在把现有 iOS 输入树
  绑定到 receipt，并拒绝生命周期或 Surface 代际过期的 receipt 回放。当前有效的
  开发 profile 已通过一次真机 `devicectl` 安装。设备信任开启后，同一 probe 已成功
  启动并报告 Metal drawable 就绪、31 个 clear frame、detach/reattach generation 回放，
  以及合成 touch、pointer、trait 入口。该结论只证明 static-package probe；完整声明式
  CangHui 场景与产品验收仍未完成。验证脚本同时支持 macOS
  `security cms` 解码与 `openssl smime` 兼容回退，且不会把 profile 内容写入项目证据。
- Android 已有 Java/JNI/NDK `SurfaceView` bootstrap；Cangjie Android runtime
  链接、产品 APK 和真机回放仍未完成。
- HarmonyOS 通过独立实现的 Ability/XComponent 或 OHNativeWindow Provider 消费
  同一契约。本仓不携带 ArkTS 工程或 HAP，因此不宣称 HarmonyOS 运行证明。

运行 `cuic doctor ios`、`cuic doctor android` 或 `cuic doctor harmonyos`，可把
本机工具链事实与这份公共 Provider 边界一起查看。

## 无头语义回放

`canghui.mobile-host-replay.v0` 可在不打开窗口的情况下展示阶段化 receipt，
并判断回调是否仍属于当前宿主代际。`mobileHostReplayHandler` 接受零行或多行
`actionId|lifecycleEpoch|surfaceGeneration`，逐项返回 `current`、
`stale-lifecycle`、`stale-surface` 或 `stale-lifecycle-and-surface`，同时保留
receipt 中真实的未签名、签名与真机证明状态。

消费者应在自己的 `@KModeLink` 函数中调用该 handler。这样 endpoint 仍归应用
所有，`cuic kmode diff` 也能在依赖图中提前拒绝重名。
`examples/mobile-host-replay` 展示了这一模式，并携带 iOS、Android、HarmonyOS
三份未签名 input-tree fixture。它不会生成 IPA、APK 或 HAP，无头回放也不等于
真机证明。示例另有 `mobile.demo.ios.provider.replay` endpoint，通过
`IOSMobileApplicationHostProvider` 展示仓内 UIKit probe、bootstrap、runtime 和
include 输入树，以及 current/stale 回调判断；它不运行 UIKit/Metal，不做 Xcode
签名，也不代表 iPad 真机证明。

## 外部签名器准备

`canghui.mobile-signing-preparation.v0` 从未签名的 `input-tree` 生成一份不含
秘密信息的交接 receipt。请求只包含输出名称以及 `ios-signing-identity`、
`ios-provisioning-profile` 等不透明能力标签；不接收证书、密钥、描述文件内容、
口令、Shell 命令或文件路径。声明标签完整时状态为 `requirements-satisfied`，缺项
时保持 `blocked`。这个状态不声称当前宿主真的持有有效签名身份；该事实仍以
`cuic doctor` 与平台签名器为准。

准备动作不会推进移动安装包 receipt。它的 JSON 始终保留
`signedPackage=false` 与 `installable=false`；必须由 Xcode 或其他平台所有的
签名器产生独立验证过的签名证据，公共 receipt 才能推进到 `signed-package`。

## 外部签名器 receipt 绑定

`canghui.mobile-external-signer-receipt.v0` 会把不透明的签名器元数据绑定到
准备结果的输出名、生命周期 epoch、原生 surface generation 和有限的 source
binding，并校验 `sha256:` 摘要格式，拒绝过期或不匹配的绑定。`accepted` 只表示
receipt 与当前准备契约相符，不验证签名字节、不执行签名器，也不会推进
`MobileHostPackageReceipt`；平台 owner 仍需独立验证签名包后，公共 receipt 才能进入
`input-tree` 之后的阶段。

## 签名包证据

`canghui.mobile-signed-package-evidence.v0` 是下一道显式门禁。平台 owner
提供验证器工具、验证策略和验证 receipt 的受限标签，以及已验证产物的大小，并且
输出名称、`sha256:` 摘要和 source binding 必须与已接受的签名器 receipt 完全一致。
CangHui 会拒绝失败结果、过期的 lifecycle 或 Surface 代际、摘要/输出不匹配，以及
没有扎根于当前未签名 input-tree 的证据。

只有 `applied` receipt 才能把 `MobileHostPackageReceipt` 从 `input-tree` 推进到
`signed-package`。`IOSMobileApplicationHostProvider` 会拒绝通过普通
`applyPackageReceipt` 直接完成这一跳，平台代码必须使用
`applySignedPackageEvidence`。CangHui 本身仍不会运行 `codesign`、`apksigner`、
HAP 签名器或其验证命令。

此时 `installable=true` 只表示产物具备尝试安装的资格；receipt 仍明确保持
`installationProven=false` 与 `deviceProven=false`。实际安装、启动、渲染和真机
回放属于后续相互独立的证据阶段。

## 安装尝试 receipt

`canghui.mobile-installation-attempt.v0` 用于记录一次由平台 owner 控制的安装器
边界所报告的结果。请求会重复签名产物的输出名、`sha256:` 摘要与大小，并增加平台
owner、目标设备类别、安装器工具、安装策略和外部 receipt ID 等受限不透明标签。
它不会接收设备 UDID、文件路径、命令行、凭据或安装包字节。

只有当前 package 仍处于 `signed-package`，且已应用的签名包证据继续精确匹配应用
身份、lifecycle epoch、原生 Surface generation 与前序 input-tree，receipt 才会进入
`recorded`。匹配的 `failed` 结果只记录失败尝试，不证明安装；匹配的 `installed`
结果可以报告 `installationProven=true`，但不会推进 `MobileHostPackageReceipt`。

CangHui 不执行安装器，也不独立验证安装器结果。因此安装 receipt 始终保留
`launchProven=false`、`renderingProven=false` 与 `deviceProven=false`。启动观察、
渲染表面证据和语义真机回放仍需后续独立 receipt。
