[CangHui 指南](../index.md) › Agent UI 评审

# 让生成式界面保持克制、可读和可验收

## 目标

把常见的生成式 UI 偏差变成可操作的框架规则：按钮不过高、内容不靠超大边框分组、图标来源稳定、
信息行的标题与尾随状态各归其位、窄侧栏不溢出，并用 cuic 留下可重复证据。

## 先选对布局语义

### 用 Row 表达三段内容的空间所有权

`Row` 是通用水平容器。前导与尾随内容按自身宽度收缩，中间内容添加 `.layoutWeight()` 后获得
剩余宽度；padding、最小高度和表面由当前产品自己组合。下面的 12/8 vp 留白、8 vp 间距和
44 vp 最小高度是一份信息行配方，不是框架强加的业务样式：

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("信息行", 520, 260))
    app.run {
        Row(space: 8.vp) {
            Icon(IconName.OpenFolder)
            VStack(spacing: 2.vp) {
                Label("CorePlayer").bold().maxLines(1)
                Label("最近同步 2 分钟前").muted().fontSize(12.fp).maxLines(1)
            }.hug().layoutWeight()
            Label("已就绪").muted().maxLines(1)
        }.padding(12.vp, 8.vp).minHeight(44.vp).fillWidth()
    }
}
```

这会得到 `[图标  标题/说明                 状态]`。`SpaceAround` 会把三段都推开，容易得到
`[图标        标题        状态]`；它适合同权导航项，不适合有主内容所有权的信息行。只有两个端点时
可以用 `Row.justifyContent(SpaceBetween)` 或 `HStack + Spacer`；有主内容所有权的三段行优先给
中间子项添加 `.layoutWeight()`。

`Row` 本身不拥有点击。整行只有一个动作时，可在外层使用 `Button` 或
`InteractionSurface`；如果尾部还有独立按钮，不要再让整行抢同一个交互所有权。

### 让控件保持本征高度

普通 `Button` 和 `IconButton` 默认最小高度 38 vp，在高 `HStack` 中不会被交叉轴拉成大色块。
`.height(...)`/`.fillHeight()` 仍是显式覆盖，只用于分段控件、触摸大目标等明确设计。普通工具栏和
列表操作不要把容器高度直接传给按钮。

按钮默认已有主题内边距。自定义 slot 时可用 `.contentPadding(...)` 调整，但不要清零后依赖文字
自身宽高；先在最短标签、最长标签和字体缩放下检查命中面积。

## 控制视觉噪声

- 分组优先使用留白、`Surface`/`Panel` 与主题表面；普通边缘保持 1 逻辑像素。厚边框只用于焦点、
  强警示或明确品牌构图，不能成为每张卡的默认装饰。
- 图标使用内置 `IconName`、`IconButton` 或 `cuic symbol generate` 生成的声明子集。不要使用
  Emoji、普通文本字形或依赖本机字体的 iconfont；它们会改变基线、宽度和跨平台结果。
- 一张卡先保留标题、必要说明、状态/动作。长解释移到详情、帮助或 tooltip；说明文本用
  `muted()`、较小字号和 `maxLines(...)` 建立层级。
- 主题必须由同一状态/令牌派生，并传给同一视图的所有卡片、弹层与空状态；不要在暗色页面残留
  硬编码浅色卡。

## 窄容器与侧栏

固定宽侧栏内的不定数量筛选按钮/chip 使用 `FlowRow` 自动换行。若必须单行，先计算按钮最小宽度、
间距与左右 padding 的总和；不能以设计稿宽度“看起来能放下”作为证明。主内容行常用
`.hug().fillWidth()`：先按内容取得合理高度，再只在水平方向占满。

## 用 cuic 验收

按下面顺序检查窄、常规、宽三个视口，并覆盖亮/暗主题：

1. `cuic pview`/`cuic probe ascii`：顺序、区域、几何、尾随对齐、溢出、按钮高度；
2. `cuic prnt`：字体、颜色、边缘、裁切、图像和主题；
3. 事件测试：点击、键盘、焦点、Modal 与状态变化；
4. 系统/设备截图：只补窗口外壳、输入法、系统菜单、设备合成和真实平台集成。

不要用系统截图代替前两层。反过来，ASCII 也不证明字体或像素正确；每类证据只回答自己的问题。

## 评审清单

- 三槽信息行的尾随信息是否贴近尾端，而不是平均散开？
- 普通按钮是否为本征高度并保留 padding？是否有人无意添加 `.fillHeight()`？
- 图标是否来自稳定矢量/符号 API？
- 文本能否在 5 秒内看出标题、说明、状态和主动作？
- 侧栏筛选项在最窄支持宽度是否换行或降级？
- 暗色主题是否仍有硬编码浅色 Surface？
- 是否同时保留 ASCII/结构证据与必要的像素证据？

相关页面：[选择布局](choose-layout.md)、[稳定身份列表](data-list.md)、
[快照与性能记录](snapshot-and-profile.md)、[`Row`](../../api/chui/core/Row.md)。
