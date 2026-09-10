# 5 分钟：像 SDK 一样引用 CangHui

## 结论

应用可以直接依赖 `chui` 并构建，不需要把完整 CangHui 仓库放在应用旁边修改。
当前公开交付是**锁定提交的 Git 源码依赖**：CJPM 将依赖放进用户缓存，应用只保留
manifest 与 `cjpm.lock`。它已经具有“引用后构建”的 SDK 使用体验，但不是预编译二进制 SDK。

## 创建应用

先安装并核对与目标 CangHui 版本匹配的 cuic：

```bash
cuic version
cuic init HelloCangHui --name hello_canghui --platform macos
cd HelloCangHui
cuic dependency update
cuic doctor macos .
cuic build macos .
cuic run macos .
```

生成的依赖形态是：

```toml
[dependencies]
chui = { git = "https://github.com/Celading/CangHui.git", commitId = "<reviewed-commit>" }
```

应用代码只需：

```cangjie
import chui.*
```

提交 `cjpm.lock`，让 CI 与其他开发机复用同一解析结果。只有明确升级 CangHui 时才更新
`commitId` 并重新执行 `cuic dependency update`；普通构建不会隐式刷新依赖。
`cuic build` 会以 manifest/lock 指向的框架根准备隔离的 SDL3 原生缓存，并同时提供编译期和
运行期库搜索路径；不需要、也不应手工修改 CJPM 中的 CangHui 源码缓存。

## 什么时候才需要本地源码路径

仅在修改 CangHui 本身，或使用已经准备好的离线源码目录时使用：

```bash
cuic init HelloCangHuiDev --canghui-path ../CangHui
```

不要为了调整应用界面而进入依赖缓存修改框架；能在应用层完成的主题、组件组合与业务状态都留在应用。
需要框架能力时，以最小复现向 CangHui 提交需求，再升级锁定提交。

## 未来二进制 SDK

后续可以增加按 `macos-arm64`、HarmonyOS phone/PC 等目标发布的预编译 SDK 包，进一步避免
消费者编译框架源码。但它必须同时固定 Cangjie 编译器/ABI、公开模块、SDL/native 运行时闭包、
校验值、许可证和发布者签名；不能把某台机器上的 `target/` 当作通用 SDK。现阶段可移植且受支持的
路径仍是上面的 Git 依赖 + lock + 用户缓存。

完整缓存、覆盖与平台边界见[轻量消费工作流](../reference/consumer-workflow.zh-CN.md)。
