# HarmonyOS 应用投影

cuic prepare harmony 把一份规范 Cangjie 源树投影到项目内受限生成目录，并附带 CangHui 的 Ability、XComponent、输入和资源宿主模板。它不是第二份产品源码，也不接管 bundle identity、权限、签名或业务页面。

在 canghui.toml 中声明：

```toml
[harmony]
source-roots = ["src", "feature"]
exclude = ["src/desktop"]
target-package = "dev.example.app"
output = ".canghui/generated/harmony"
transforms = ["replace:package app.desktop=>package app.harmony"]
```

然后运行：

```bash
cuic prepare harmony . --json
```

只接受显式 exact replace 规则，不执行正则、脚本或任意命令。源码、资源、框架模板和 native header 都进入 inputDigest；生成树（不含自身 receipt）进入 outputDigest。相同输入的第二次运行无写入返回原回执；任一侧漂移或无 CangHui receipt 的既有目录都会拒绝覆盖。

生成模板包含：

- Ability lifecycle、安全区、系统主题与生命周期 epoch；
- XComponent/OHNativeWindow surface generation 和帧入口，复用现有 HarmonyNativeSurfaceBridge；
- 有界 pointer/key mailbox，触摸、鼠标和笔统一成 pointer packet；
- focus id、caret rectangle、UTF-8 composition range、selection、commit/delete/submit 输入契约；
- resources/rawfile staging，运行时由 ApplicationResources.mobileRawfile 解析。

Harmony 平台 provider 存在时仍需执行真实 Harmony 构建与设备验收。设备 IME 全覆盖、无障碍 action、产品权限和签名没有现场证据时保持 field-gated。
