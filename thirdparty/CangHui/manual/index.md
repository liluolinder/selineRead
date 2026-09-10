# CangHui Manual

CangHui（仓绘）是 Cangjie 多平台声明式 GUI 框架，公开包名与缩写为 `chui`。
`manual/` 是唯一的公开文档入口。

## 第一次来这里

根据你的任务只读一条路径，不必先通读全部 API：

1. **在应用中引用 CangHui**：先看 [5 分钟 SDK 式消费](getting-started/sdk-consumption.md)，
   再运行 `cuic doctor`。普通使用者不需要克隆或修改完整 CangHui 仓库。
2. **让 Agent 实现或审查界面**：先看 [Agent 首次工作流](getting-started/agent-first-workflow.md)，
   再看 [Agent UI 评审规则](guide/how-to/agent-ui-review.md)。优先使用 `cuic pview`/`probe ascii`
   和 `cuic prnt`，不要一开始就依赖系统截图。
3. **系统学习框架**：进入[渐进式使用指南](guide/index.md)，从首窗口、状态、布局逐步前进。
4. **维护框架或准备发布**：使用[全量构建 Skill](skills/canghui-full-build/SKILL.md)，
   它不会把公共源码构建误写成平台、签名或商店证明。

## 手册地图

- [快速开始](getting-started/index.md)：依赖消费与 Agent 首次作业顺序。
- [渐进式指南](guide/index.md)：按学习路径和实际任务组织。
- [教程](tutorials/index.md)：cuic、无边框窗口、平台接口与 Surface。
- [API 参考](api/index.md)：精确类型、构造函数和成员。
- [专题参考](reference/index.md)：架构、doctor、probe、字体、Symbol、安全与平台边界。
- [自动化 Skills](skills/)：Agent 可直接采用的有界工作流。
- [实拍截图](screenshots/index.md)与[公开 Changelog](CHANGELOG.md)。

## 默认 UI 安全形状

- 普通按钮保留主题默认内边距与最小高度；`Button`/`IconButton` 在高 `HStack` 中保持
  自身高度，只有显式 `.height(...)`/`.fillHeight()` 才纵向铺满。
- 图标使用 `Icon`、`IconButton` 或按需生成的 `Symbol`，不要用 Emoji、普通文字或
  iconfont 冒充稳定图标。
- “图标—标题/说明—尾随信息”使用 [`Row`](api/chui/core/Row.md)，给中间内容添加
  `.layoutWeight()`：两端按内容收缩，中间吃掉剩余宽度，避免把三段内容平均摊开。
- 窄侧栏中的不定数量筛选项使用 `FlowRow`；普通信息行优先 44–48 vp，边框通常保持
  1 逻辑像素，并在窄/常规/宽视口及亮/暗主题下分别核验。

## cuic 证据顺序

```bash
cuic doctor macos .
cuic shell snapshot .
cuic pview . <probe-id> --columns 96 --rows 32
cuic prnt macos . --output artifacts/ui.png
```

`shell snapshot/diff` 给出运行中焦点与交互变化，`pview`（亦可写 `cuic probe ascii`）
给出确定性结构与几何，`prnt` 给出框架像素。`shell` 是一次性 debug 子进程脚本，不是
常驻控制端口。`shell`、`pview`、probe 执行和设备捕获属于调试渠道，发布版 cuic 拒绝它们是预期安全行为；请使用
与项目匹配的 debug cuic。只有验证窗口外壳、输入法、系统菜单、设备合成等平台事实时，
系统截图才是必要证据，且不能替代结构化/ASCII 结果。

公开面审计：

```bash
python3 manual/skills/canghui-full-build/scripts/audit_public_surface.py
```

## 版本

当前 `chui` 版本线：`0.17.0`（见 [CHANGELOG](CHANGELOG.md)）。
