# typography：字体样式排版样张

一张字体样式样张，集中演示 `Label` 的字体样式修饰符 `bold()` / `italic()` / `underline()` /
`strikethrough()`：均由渲染层从单一系统字体经 SDL_ttf 实时合成，Latin 与 CJK 一视同仁，无需额外字体文件。
顶部四个 `Chip` 实时切换样式，下方字号阶梯逐档以当前样式渲染；另有一张各样式的静态参考卡作对照。

## 演示要点

- `Label` 字体样式修饰符 `bold()`、`italic()`、`underline()`、`strikethrough()`，可链式叠加（如 `bold().italic()`）
- 顶部四个 `Chip` 直接绑定模型各 `State<Bool>`（`State` 即 `Bindable<Bool>`），点选实时切换全局样式
- 字号阶梯 Display/Title/Body/Caption 逐档以当前合成样式渲染同一中西混排示范文本，验证样式对两种脚本一致生效
- 静态样式参考卡固定展示常规、粗体、斜体、下划线、删除线、粗斜体六种样子，不随开关变化，作为对照
- 当前样式的中文摘要（如「粗体 · 斜体」）由样式纯函数派生，显示在页脚

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 字号阶梯、样式参考表、样式合成与摘要（纯函数） |
| [model.cj](src/model.cj) | `TypographyModel`：四个样式开关；当前样式与摘要派生 |
| [views.cj](src/views.cj) | 标题、样式开关 Chip 行、实时字号阶梯、样式参考卡、页脚摘要 |
| [theme.cj](src/theme.cj) | 编辑排版风浅色主题（暖白纸面 + 近墨文字 + 靛蓝强调） |

## 关键实现

### 样式由系统字体合成

四种样式无需额外字体文件——渲染层对单一系统字体施加 SDL_ttf 的 `TTF_SetFontStyle`：faux 粗体加粗描边并加宽
步进，斜体倾斜字形，下划线/删除线加线。每个（字号，样式）组合各持一个字体句柄与成形缓存，度量随样式变化
（粗体更宽），布局、省略号与换行判定都按实绘样式计算。

### 当前样式是开关的纯函数

四个开关合成当前样式，视图每帧读取，切换 Chip 即重算：

```cangjie
func composeStyle(bold: Bool, italic: Bool, underline: Bool, strikethrough: Bool): FontStyle {
    FontStyle(bold: bold, italic: italic, underline: underline, strikethrough: strikethrough)
}
```

### 阶梯逐档套用同一样式

字号阶梯每档取框架标准字号，以当前合成样式渲染同一示范文本：

```cangjie
Label(SPECIMEN).fontSize(step.size).fontStyle(model.style()).maxLines(1)
```

## 运行

```powershell
cd examples/typography
cjpm run
```

点顶部 Chip 切换粗体/斜体/下划线/删除线，字号阶梯与页脚摘要随之更新。支持视觉回归快照：

```powershell
cuic prnt . --output typography.bmp
```
