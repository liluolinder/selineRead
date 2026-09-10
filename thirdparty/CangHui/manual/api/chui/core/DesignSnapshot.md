[chui](../../index.md) › [chui.core](index.md) › DesignSnapshot

# DesignSnapshot

`canghui.design-snapshot/v1` 是供设计工具、无图审计与 CI 使用的确定性硬真相快照。它把稳定组件 ID、结构、计算几何、语义状态与 scoped Draw IR 对齐，但不包含截图推断、自然语言编辑策略、源代码重写或内部治理元数据。

## 快照内容

```cangjie
let snapshot = DesignSnapshot.fromSemantics(
    "studio.main",
    DesignSnapshotEnvironment("headless", 1440.0, 900.0, theme: "dark"),
    semanticRuntime.snapshot(),
    drawIr: renderer.drawIr(),
    states: [DesignSnapshotProperty("fixture", "normal")],
    inputDigest: "fixture:r3"
)

let canonicalJson = snapshot.toJson()
let changed = next.diff(snapshot)
```

- 节点层级支持 `document/page/state/screen/region/component/atomic`，普通语义树便利构造会生成一个 `screen` 根和若干 `component` 节点。
- 节点和属性按稳定标识排序；Draw IR 保持原始绘制顺序。相同输入重复导出会得到相同字节和 `contentDigest`。
- `contentDigest` 是 `chui-hash-v1` 变更检测值，不是密码学签名或文件完整性证明。
- `path`、`handle`、`token`、`secret`、`password`、`credential` 等敏感属性键会在存入快照时自动替换为 `[redacted]`；password role 的值沿用语义树规则为空。
- 节点、属性、Draw IR 与总文本均有硬上限；孤儿父节点、重复 ID、父级循环、绝对/遍历路径式身份会拒绝。

## 分层差分

`DesignSnapshot.diff(previous)` 返回 [`DesignSnapshotDiff`](#designsnapshotdiff)，分别列出：

- `structure`：增删节点或父级、节点种类、顺序、类型、role 改变；
- `geometry`：布局矩形改变；
- `style`：计算样式属性改变；
- `state`：label/value、组件状态或全局 fixture 状态改变；
- `draw`：Draw IR 改变所涉及的稳定 scope。

### DesignSnapshotDiff

```cangjie
public struct DesignSnapshotDiff {
    public let fromDigest: String
    public let toDigest: String
    public let structure: Array<String>
    public let geometry: Array<String>
    public let style: Array<String>
    public let state: Array<String>
    public let draw: Array<String>
}
```

## CUIC 导出

源码版 debug CUIC 可以直接从已有 `ComponentProbe` 生成同一协议：

```bash
cuic design snapshot component-gallery gallery.primary-button
cuic design snapshot component-gallery gallery.primary-button \
  --events $'press 80 35\nrelease 80 35'
```

命令向标准输出写入规范 JSON，适合重定向为设计输入或 CI 证据。它复用显式 Probe 注册与调试门，不新增 PID attach、坐标隧道或发布态控制入口。

公开 JSON 约束见 [canghui-design-snapshot-v1.schema.json](../../../../contracts/canghui-design-snapshot-v1.schema.json)。Schema 约束协议包络、节点、环境、属性及硬上限；Draw IR 的具体命令仍由 renderer 协议定义。
