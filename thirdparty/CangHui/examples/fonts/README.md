# fonts：本地字体文件加载

一张字体样本册，集中演示从本地字体文件加载字体：`Fonts.register(name, path)` 登记字体名到文件路径，
再由 `Label.fontFamily(name)` 按名套用。示例加载一款衬线（Georgia）与一款等宽（Consolas），与 CangHui
随包 HarmonyOS Sans 并列对照；可切换大样张所用字体并叠加粗体。找不到文件或缺字时自动进入回退链。

## 演示要点

- `Fonts.register(name, path)` 从本地字体文件加载：衬线、等宽各挑第一个存在的候选文件登记
- `Label.fontFamily(name)` 按注册名渲染；同一样张在三种字体下并列，字形差异一目了然
- 字体名与字体样式叠加：`SegmentedControl` 选字体、`Chip` 叠加粗体，加载字体也能加粗（打开该文件的粗体变体）
- 宽容回退：未注册、打不开或缺字的字体依次回退到随包 HarmonyOS Sans 和系统 UI 字体
- 字体名解析（挑第一个存在的候选）与选中项到字体名的映射都是纯函数，存在性以谓词注入，便于单测

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口；解析并注册字体（`firstExisting` + `FileSystem.exists`） |
| [data.cj](src/data.cj) | `TypeFace` 类型、跨平台字体候选、字体解析与选中映射（纯函数） |
| [model.cj](src/model.cj) | `FontsModel`：选中字体、粗体开关；当前字体名派生 |
| [views.cj](src/views.cj) | 标题、字体样本册、字体选择器 + 粗体开关、大样张 |
| [theme.cj](src/theme.cj) | 浅色主题（石青强调） |

## 关键实现

### 从本地文件注册字体

每种字体给出跨平台候选路径，挑第一个存在的文件登记；`Fonts.register` 只登记映射，运行时首用才真正打开：

```cangjie
if (let Some(path) <- firstExisting(face.candidates, {p => FileSystem.exists(p)})) {
    Fonts.register(family, path)
}
```

### 按名套用与字形回退

视图以 `Label.fontFamily(name)` 按名渲染；名称未注册、文件打不开或不覆盖整段文字时，渲染层继续使用
Theme/应用默认、随包 HarmonyOS Sans 和系统字体：

```cangjie
Label(SPECIMEN).fontFamily("demo-serif")   // 加载且覆盖文本则用 Georgia，否则继续回退
```

## 关于 CJK

示例加载的 Georgia / Consolas 是拉丁字体，不含 CJK 字形，故样张用拉丁文以专注对比衬线、等宽与无衬线的
字形；中文界面默认由随包 HarmonyOS Sans 承担。要在中文场景换字体，请注册含 CJK 的字体文件。

## 运行

```powershell
cd examples/fonts
cjpm run
```

用分段控件切换样张字体、`粗体` 开关叠加加粗。支持视觉回归快照：

```powershell
cuic prnt . --output fonts.bmp
```
