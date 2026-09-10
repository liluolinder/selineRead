# Symbol

[English](symbols.md) | **中文**

CangHui 通过 `SymbolName`、`Symbol`、`SymbolProvider`、`SymbolAdapter` 和 `Symbols` 提供与具体图标库解耦的矢量 Symbol。核心包包含一组较小的内建兼容图标。Material Symbols、Ant Design Icons、Arco Design Icons 作为独立可选包提供。

## 核心用法

```cangjie
import chui.*

Symbol(SymbolName("save", provider: "builtin"),
    size: 24.vp, weight: 500.0, accessibilityLabel: "保存")
```

`Icon` 与 `IconButton` 同时接受旧的 `IconName` 枚举和 `SymbolName`，现有调用方可以逐步迁移。

## 可选 Provider

应用只添加实际使用的 Provider：

```toml
[dependencies]
chui = { path = "../CangHui" }
canghui_symbol_material = { path = "../CangHui/packages/symbol-material" }
canghui_symbol_ant = { path = "../CangHui/packages/symbol-ant" }
canghui_symbol_arco = { path = "../CangHui/packages/symbol-arco" }
```

查看当前已经适配的图标清单及固定的上游源码版本：

```bash
./tools/cuic/bin/cuic symbol list --json
./tools/cuic/bin/cuic symbol list material
```

标准 Provider id 为 `material`、`ant`、`arco`。CLI 为兼容保留 `material-design`、`antd`，以及常见误拼 `acro`。

## 声明子集生成

根据应用实际引用的 Symbol，生成一份由应用拥有的注册表：

```bash
./tools/cuic/bin/cuic symbol generate \
  material:add@primary_add ant:check arco:right \
  --output src/generated_symbols.cj \
  --package example_app
```

在第一次解析 `Symbol` 之前，于应用启动阶段调用一次 `registerCangHuiSymbols()`。生成文件只包含声明过的注册项，也只导入选中的 Provider 包。标准名重复或跨 Provider 导出名冲突会在写入源码前失败。

Provider 目录必须通过校验，才能向生成的仓颉源码提供 import 或类型名。Symbol 名、变体与源码路径也使用受限语法。机器可读目录与生成回执由 [`canghui-symbol-v0.schema.json`](../../contracts/canghui-symbol-v0.schema.json) 定义。

## 解析规则

- 带 Provider 的名称先经过对应 Adapter，因此 `material:plus` 等稳定别名可以解析到 `material.add`。
- 不支持的变体会降级到 Provider 已提供的变体，并设置 `SymbolResolution.variantFallback`。
- 带方向语义的 Symbol 可以在从右到左的上下文中自动镜像。
- 缺失 Symbol 默认使用内建缺失标记；严格模式会抛出确定性诊断。
- Draw IR 记录请求名与解析名、Provider、变体、字重、方向、镜像、无障碍标签和兜底状态。

当前可选包只适配一小组经过检查的样例清单，不会把完整上游图标库全部打包。各包的 `UPSTREAM.md`、`symbols.catalog` 与许可证文件固定了清单使用的准确仓库版本和源码路径。
