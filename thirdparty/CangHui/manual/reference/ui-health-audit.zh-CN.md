# CUIC UI Health Audit

UI Health 在既有 DesignSnapshot、语义、布局与 Draw IR 上给出确定性诊断，不依赖系统截图，也不自动改写应用。

```bash
cuic ui audit . gallery.primary-button --fail-on warning
```

结果协议为 canghui.ui-health/v1，包含稳定 code、severity、componentId、rectangle、evidenceSource 与公开组件建议。当前检查小/异常拉伸交互目标、无 label 的 icon action、兄弟交互重叠、内容越出 owner、重复 action owner、精确相邻边框接缝，以及前后快照的几何变化。

对前景与背景无法同时证明的原生/图片内容，contrast 必须报告 unknown，不能猜测。--fail-on 支持 info、warning、error；达到阈值时命令返回非零。该命令复用 compiler-debug probe 通道，不开放发布态输入隧道。
