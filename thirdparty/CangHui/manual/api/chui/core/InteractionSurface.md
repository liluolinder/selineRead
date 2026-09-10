[chui](../../index.md) › [chui.core](index.md) › InteractionSurface

# InteractionSurface

`InteractionSurface` 是承载任意装饰性 child 的单一交互所有者：它独占一个焦点 id、按压状态、
release-inside 动作、InkWell 与 semantic region。

```cangjie
public class InteractionSurface <: Widget
```

## 示例

```cangjie
InteractionSurface(
    action: {=> save()},
    role: ControlRole.Button,
    accessibilityLabel: "保存副本",
    key: Some("save-copy")
) {
    HStack(spacing: 8.vp) {
        Symbol(SymbolName.Save)
        VStack(spacing: 2.vp) {
            Label("保存副本").bold()
            Label("保留当前版本").muted()
        }
    }
}.surface(
    Shape.rounded(10.0),
    Materials.themePrimary(),
    clip: ClipPolicy.Shape
)
```

## 构造函数

```cangjie
public init(
    action!: () -> Unit,
    role!: ControlRole = ControlRole.Button,
    accessibilityLabel!: String = "",
    key!: ?String = None,
    readOnly!: Bool = false,
    selected!: ?Bool = None,
    expanded!: ?Bool = None,
    body!: () -> Unit
)
```

`key` 省略时按声明位置生成唯一 id；也可在构造后调用 `key(value)` 固定。`surface(shape, material, clip)`
让背景、焦点几何与 Ink 共用同一 Shape。`readOnly` 为 true 时不注册焦点、不接受动作，语义输出保留
`readonly=true / enabled=false`；`.enabled(false)` 继续走 Widget 的通用禁用传播。

## ControlRole

`ControlRole` 冻结当前交互面的语义角色：`Button`、`Link`、`Checkbox`、`Switch`，或携带稳定名称的
`Custom(String)`。角色参与探针与辅助语义，不代替 `accessibilityLabel`。

## 交互契约

- 主键在面内按下并在面内松开才激活；按住后移出会永久取消本次按压，即使回到内部再松开也不触发；
- 键盘焦点到达后 Enter 与空格激活；鼠标点击不会伪造 focus-visible；
- `ControlRole` 提供 Button、Link、Checkbox、Switch 与 `Custom(String)` 语义角色；空 Custom role 在构造时拒绝；
- `selected`、`expanded`、`enabled`、`readOnly`、focus/hover/press 同时流入 SurfaceState、
  ControlContentEnvironment 与 ComponentProbe 语义输出；
- 一个 InteractionSurface 只记录一个 `actionOwner`，显式同 owner `.probe(...)` 仍优先于自动语义。

## 装饰 slot 与结构错误

body 默认是装饰子树，不能嵌套 Button、Slider、TextField、EventHandler 或任何其他交互所有者。
检测使用 [`Widget.interactionOwnerIds()`](Widget.md#interactionownerids)，不把键盘焦点误当作交互所有权的
唯一来源；普通布局、Surface、纯装饰 Label/Symbol 与 FrameHandler 不会因此误报。构建时若发现交互 owner 后代：

1. 后代焦点 id 从本帧 Tab 环移除；
2. 外层也不注册焦点，且不向 child 派发动作事件；
3. `structuralDiagnostic()` 返回稳定的 `nested-interaction-owner: ...`；
4. ComponentProbe 报告 `structural-nested-interaction-owner`，并记录 `descendantInteractionOwnerIds`；
   `descendantFocusIds` 继续单独记录真正的焦点后代；
5. 子树仍正常绘制，但绘制期间的 interactions-enabled 上下文为 false，外层与嵌套输入、动作和快捷键语义
   全部失败关闭。

这条规则防止两个 action owner 覆盖同一命中面。需要多个独立动作时，应把多个 InteractionSurface 作为
Row/Column/ZStack 的兄弟组合，而不是相互嵌套。

## 边界

当前实现覆盖矩形/圆角矩形、solid/theme provider 与确定性 headless Draw IR。Button/IconButton 已把焦点、
release-inside/cancel、键盘激活与 Ink 所有权委托给该 primitive；为保持 ButtonStyle 连续动画、既有自动语义
名称和 Draw IR 兼容，两者仍由各自 recipe 绘制并记录 `Button.activate()` / `IconButton.activate()`，不调用
delegate 的绘制面。其他控件迁移、任意路径、Liquid Glass、平台 blur/native accessibility adapter 均未在此
API 中声称完成。
