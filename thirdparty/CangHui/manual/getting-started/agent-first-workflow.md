# Agent 首次工作流

本页给自动化宿主一条短而强制的顺序。目标是先恢复框架和项目事实，再写界面；不要凭常见 Web/ArkUI
习惯猜 CangHui API，也不要只靠一张屏幕截图判断布局。

## 1. 先读，不先改

按顺序阅读：

1. 本页；
2. [SDK 式消费](sdk-consumption.md)，确认你在改应用还是框架；
3. [Agent UI 评审规则](../guide/how-to/agent-ui-review.md)；
4. 与任务直接相关的一页[渐进式指南](../guide/index.md)和精确 [API](../api/index.md)。

使用者项目默认通过 `import chui.*` 和锁定依赖消费框架。除非任务明确要求修复 CangHui，
不要切换成本地路径、修改依赖缓存或复制框架源码。

## 2. 建立基线

```bash
cuic version
cuic doctor <platform> .
cuic build <platform> .
cuic test <platform> .
```

记录命令版本和真实退出码。若本机 `cuic` 版本落后于项目声明，先安装/构建匹配版本；不要把旧命令
缺少能力误判为框架缺陷。

## 3. 先看结构，再看像素

对已有 probe，优先运行：

```bash
cuic shell snapshot .
cuic pview . <probe-id> --columns 96 --rows 32
# 等价入口：cuic probe ascii . <probe-id> --columns 96 --rows 32
```

`shell snapshot/diff` 先核对真实运行态的焦点与交互节点；需要回放时使用一次性 debug
`shell click/focus/run`，不要接管任意已有进程。ASCII 用来核对区域顺序、宽高、尾随信息位置、按钮是否被纵向拉伸，以及窄视口是否溢出。
需要像素、字体、裁切或主题证据时再运行：

```bash
cuic prnt <platform> . --output artifacts/ui.png
```

若应用还没有 probe，先为关键视图提供稳定 probe/semantic id，不要直接跳过可重复验收。
`shell`、`pview`/probe 执行需要 debug cuic；发布版拒绝特权通道是安全门，不是失败。

## 4. 使用框架的默认安全形状

- 三段信息行用 `Row`，给中间内容添加 `.layoutWeight()`；不要用三个 `Spacer` 或
  `SpaceAround` 猜间距。
- 普通按钮不写零 padding，不把 `.fillHeight()` 当默认修饰器；高容器中按钮会保持自身高度。
- 图标用 `Icon`/`IconButton`/`Symbol`，不用单字文本、Emoji 或 iconfont 冒充。
- 筛选 chips 在窄容器中用 `FlowRow`；文本保留标题、说明、尾随状态的层级，不把说明书塞进卡片。
- 使用同一份状态派生主题，并在亮/暗主题、窄/常规/宽视口检查一次。

## 5. 交付证据而不是观感句子

至少返回：修改文件、构建/测试结果、ASCII 观察、像素观察（若涉及视觉）、未运行的平台或设备门。
系统截图只证明平台最终合成画面；它不能替代 CangHui 的结构、语义与确定性框架捕获。
