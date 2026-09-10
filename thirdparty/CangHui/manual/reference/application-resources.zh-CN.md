# 应用资源运行时

ApplicationResources 把 canghui.toml 已声明、由 cuic package/prepare staging 的资源映射为运行时逻辑名称。应用请求逻辑名，不遍历相对根猜文件。

```cangjie
let resources = ApplicationResources([
    ApplicationResourceDeclaration("body-font", "assets/fonts/body.ttf",
        role: ApplicationResourceRole.TextFont, family: "Demo Sans"),
    ApplicationResourceDeclaration("symbols", "assets/symbols/catalog.json",
        role: ApplicationResourceRole.SymbolCatalog),
    ApplicationResourceDeclaration("license", "LICENSE",
        role: ApplicationResourceRole.License)
], [
    ApplicationResourceRoot.macBundle(bundleRoot),
    ApplicationResourceRoot.source(projectRoot)
])

resources.registerFonts()
let catalog = resources.resolve("symbols")
```

根按调用方给出的顺序解析，并在回执中保留 source、macos-bundle、windows-package、linux-package 或 mobile-rawfile provenance。未声明名称、遍历、符号链接、缺失文件、重复逻辑名和过期移动端 generation 都会失败关闭。

source 根直接对应项目；macOS、Windows、Linux helper 与 cuic package 的资源布局一一对应；Harmony 生成目录使用 ApplicationResourceRoot.mobileRawfile，由当前宿主 generation 注入。字体注册只处理 TextFont、FallbackFont、SymbolFont；符号目录的解析和业务子集仍由应用决定。
