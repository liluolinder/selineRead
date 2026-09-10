# wenkai：本地字体样本册（CJK 多字重加载）

一页霞鹜文楷（LXGW WenKai）字体样本册，演示 `Fonts.register` 从本地字体文件加载真实 CJK 字体：三个比例
字重（Light/Regular/Medium）与一个等宽变体各占一个注册名，`fontFamily(name)` 按名套用即换字重。楷体的
笔意与系统黑体一望而知——这是本地字体加载管线对 CJK 字形的端到端实证。

## 演示要点

- 多字重即多次注册：每个字重文件登记一个名字（`wenkai-light` / `wenkai` / `wenkai-medium` / `wenkai-mono`），切换字重就是切换名字
- 大字样张卡整卡随切换器换字重；字重对比卡三行同文案各绑一名，笔画粗细并排可辨
- 等宽变体渲染代码行与易混字形（`0O 1lI 2Z 5S 8B`）
- 宽容回退：字体文件缺失时同样的名字整页回退系统字体，页面结构不变，状态条给出获取指引
- 纯函数可测：目录探测（注入存在性谓词）与字重登记（注入注册函数）均不依赖真实文件系统

## 字体获取

示例读取仓库 `.todo/testfonts/` 下的霞鹜文楷字体文件（该目录不入库）。字体为开源项目
LXGW WenKai（SIL OFL 1.1 授权），从其发布页下载以下文件放入该目录即可：
`LXGWWenKai-Light.ttf`、`LXGWWenKai-Regular.ttf`、`LXGWWenKai-Medium.ttf`、`LXGWWenKaiMono-Regular.ttf`。

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口：探测目录、登记字重、启动窗口 |
| [data.cj](src/data.cj) | 字重表、样张文案，纯函数 `resolveFontsDir`/`registerWeights` |
| [model.cj](src/model.cj) | `WenkaiModel`：登记数、选中字重、状态文案 |
| [views.cj](src/views.cj) | 标题、字重切换、样张卡、字重对比卡、等宽卡、状态条 |
| [theme.cj](src/theme.cj) | 米白纸感主题 + 朱砂点缀 |

## 关键实现

### 多字重登记

一个字重文件就是一个注册名，切换字重即换名引用：

```cangjie
let dir = resolveFontsDir(FONT_DIR_CANDIDATES, {p => FileSystem.exists(p)})
let registered = registerWeights(dir, {name, path => Fonts.register(name, path)})
// 视图侧：
Label(SPECIMEN_POEM).fontFamily(model.family()) // "wenkai-light" / "wenkai" / "wenkai-medium"
```

### 缺失即回退

渲染层对未注册名与打不开的文件都回退系统字体，故示例不做任何条件分支：字体在则楷体，
不在则黑体，页面结构与交互完全一致。渲染层对已缓存字体面在新字号/样式变体上的打开失败同样回退，
中途拔盘/换文件不会中帧崩溃。

## 运行

```powershell
cd examples/wenkai
cjpm run
```

切换上方三档字重观察同一段文字的笔画变化。支持视觉回归快照：

```powershell
cuic prnt . --output wenkai.bmp
```
