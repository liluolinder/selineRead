# Surface、交互所有权与容器排版

CangHui 把“如何画一个面”和“谁拥有动作”拆成两层。`Surface` 只负责背景、
边框、阴影、裁剪和前景环境；`InteractionSurface` 才拥有焦点、按压、键盘动作与
语义区域。这样组合型卡片不需要靠嵌套按钮来获得点击行为。

## 只做装饰的 Surface

```cangjie
Surface(
    shape: Shape.rounded(12.0),
    material: Materials.themeSurface(),
    clip: ClipPolicy.Shape
) {
    VStack(spacing: 6.vp) {
        Label("构建完成").bold()
        Label("内部按钮仍拥有自己的动作").muted()
        Button("查看报告", {=> openReport()})
    }.padding(14.vp)
}
```

`Surface` 不创建额外焦点或点击所有者，所以其中的 `Button` 仍独立处理输入。

## 一个动作对应一个 InteractionSurface

```cangjie
InteractionSurface(
    action: {=> openWorkspace()},
    role: ControlRole.Button,
    accessibilityLabel: "打开工作区",
    key: Some("open-workspace")
) {
    HStack(spacing: 8.vp) {
        Icon(IconName.OpenFolder)
        VStack(spacing: 2.vp) {
            Label("打开工作区")
            Label("本地或远程").muted().fontSize(12.fp)
        }
    }
}.surface(
    Shape.rounded(10.0),
    Materials.themePrimary(),
    clip: ClipPolicy.Shape
)
```

slot 必须是装饰子树。不要在一个 `InteractionSurface` 里再放 `Button`、
`TextField` 或另一个 `InteractionSurface`；框架会报告稳定的结构诊断并关闭该
冲突区域的交互。多个动作应作为兄弟组件排列。

当前 Shape 契约是矩形与圆角矩形；它不代表任意矢量路径、平台 blur 或 Liquid
Glass 已经实现。

## 让排版从容器继承

```cangjie
VStack(spacing: 6.vp) {
    Label("继承 18fp 粗体")
    Label("显式关闭粗体").bold(value: false)
    Label("显式恢复完整常规样式").fontStyle(FontStyle.regular)
    RichText([
        RichSpan.text("继承粗体；"),
        RichSpan.text("片段常规 14fp")
            .fontStyle(FontStyle.regular)
            .fontSize(14.fp)
    ])
}.fontSize(18.fp).bold()
```

环境逐字段继承：内层只覆盖自己声明的字段，其他字段继续沿用外层值。
`.bold(value: false)` 只清除粗体；`.fontStyle(FontStyle.regular)` 会显式清除
粗体、斜体、下划线与删除线。容器排版目前由语义文本叶子消费，不会自动改写
所有自绘控件的内部文字。

更多类型和边界见 [`Surface`](../api/chui/core/Surface.md)、
[`InteractionSurface`](../api/chui/core/InteractionSurface.md) 与
[`TypographyEnvironment`](../api/chui/core/TypographyEnvironment.md)。
