# 安全边界与发布来源证明

[English](security-and-release.md) | **中文**

CangHui 将开发检查能力与可分发应用行为分开。边界由编译条件落实，并对最终
可执行文件做双态回放；环境变量不是发布安全边界。

## 特权开发面

| 能力 | 发布构建 | 调试构建（`-g`） |
| --- | --- | --- |
| 应用 kMode stdio 入口 | 始终拒绝，包括旧环境变量与 argv 注入 | 仅在显式请求 stdio 时可用 |
| 显式 `KModePolicy(enabled: true)` | 强制收敛为 disabled | 执行 capability policy |
| `KModeChannelModule` 覆盖 | 拒绝 | 需要 admin policy；传输认证仍由 module 负责 |
| `cuic kmode` / `probe` 执行与 `pview` | 拒绝 | 可用 |
| `cuic shell` 一次性 UI 事件脚本 | 拒绝；应用不保留 opt-in/结果标记 | 仅白名单 debug 子进程，可用后自动退出 |
| `cuic debug` 与 `prnt --device/--app` | 拒绝 | 在已实现的平台路径上可用 |
| `kmode diff` / `probe diff` | 保留静态源码冲突检查 | 可用 |

仓库没有内置 socket、listener、远端 relay 或 `KModeChannelModule` 实现。
channel interface 是传输中立 SPI，不是隐藏隧道。未来远端 module 必须自行完成
claim 校验、身份绑定、防重放、能力分域、限速/缓冲与敏感信息脱敏，并重新通过
平台安全审查。local、loopback 或设备转发都不能充当认证。

`cuic shell` 也不构成新增传输：它不会 attach 任意 PID，不读取 stdin 命令流，不监听
socket/pipe，不解释 shell 字符串。cuic 只把最多 128 条、64 KiB 的白名单 UI 脚本交给
自己启动的 debug 应用；应用逐帧走正常命中/焦点/键盘事件路径，输出结构化观察后退出。

cuic 也把宿主执行和诊断信息移出 shell 文本边界。Windows 构建会把 `cjpm` 参数
和环境分开传给进程 API，项目输入中的 `cmd.exe` 元字符不会被展开成第二条命令；
verbose doctor 证据会保守遮盖绝对宿主路径、带凭据 URL、secret/key/token/cookie
形态和本机身份值。

源码与二进制门必须同时执行：

```bash
./scripts/audit-network-control-surface.sh
./scripts/verify-privileged-release-exclusion.sh
```

第二条命令会同时构建发布/调试 cuic 与专用消费者 fixture。发布 fixture 在旧
`CANGHUI_KMODE`、transport 环境变量和 argv 同时注入时仍拒绝；调试 fixture
则保留有界的 health/shutdown stdio 回放。

## 反编译与二次修改

源码门不会让机器码变得无法查看或修改。它负责从真实发布执行策略中移除特权路径；
发布者签名、Hardened Runtime 与公证再让替换、注入和非可信再分发可被 macOS
识别与拒绝。攻击者仍可以制作另一份签名不同或无签名的 fork，并诱导用户运行。
分发身份、下载哈希和更新通道所有权仍由产品发布者负责。

## 发布编译契约

每个从源码构建的仓颉可执行文件与源码依赖都必须使用当前工具链参数：

```text
--trimpath <本次构建的精确绝对源码前缀> --strip-all
```

`--trimpath` 需要本次构建真实使用的绝对前缀，不适合作为固定值提交进公开
`cjpm.toml`。根包的选项也不能证明独立构建或缓存中的依赖已经裁剪。自动化必须
覆盖每个源码包，并在完整产物组装后再次审计；只要仍有开发机路径、发布 kMode
opt-in 或过大的应用符号表，CangHui candidate gate 就会失败。

## macOS 证据链

`cuic package build` 生成的是无签名输入产物。receipt 会明确记录 trim/strip、
发布安全审计、发布者签名与公证尚未验证。真实 Developer ID 分发应依次完成：

1. 按发布编译契约构建应用与完整运行时闭包；
2. 运行 candidate audit；
3. 对嵌套 Mach-O 与 app 进行 Hardened Runtime + 安全时间戳签名；
4. 通过 Keychain profile 提交公证、staple 票据，再跑 publisher audit。

```bash
./scripts/audit-macos-release.sh --candidate dist/MyApp.app

CANGHUI_DEVELOPER_ID_APPLICATION='Developer ID Application: Publisher (TEAMID)' \
CANGHUI_NOTARY_PROFILE='notary-keychain-profile' \
./scripts/sign-notarize-macos.sh dist/MyApp.app

./scripts/audit-macos-release.sh --publisher dist/MyApp.app
```

签名命令只接收 identity 名称与 Keychain profile 引用，不在 argv 中接收密码、
私钥或 API secret。publisher audit 会独立验证 deep/strict 签名、Developer ID
authority、Team ID、Hardened Runtime、安全时间戳、危险 entitlement 缺失、
Gatekeeper、公证票据、运行时路径、源码路径泄露、发布调试标记和应用符号表。

Developer ID 公证证明的是直接分发产物；App Store Connect 提交、商店审核与
实际发布仍是独立 owner receipt，不能由这套门禁推导。
