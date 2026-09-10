[chui](../../index.md) › [chui.core](index.md) › ScrollOptions

# ScrollOptions

`chui.core` 包中的 public struct

可滚动组件共享的滚轮策略。默认 `web()` 采用平滑行为、72 逻辑像素步长、220ms 基准时长与
`cubic-bezier(0.22, 1, 0.36, 1)`；自动时长随主题 Basic / Standard / Full 档解析为约
165 / 220 / 275ms。

## 声明

```cangjie
public struct ScrollOptions {
    public let behavior: ScrollBehavior
    public let wheelStep: Float32
    public let animation: AnimationSpec
}
```

## 构造

```cangjie
public init(
    behavior!: ScrollBehavior = ScrollBehavior.Smooth,
    wheelStep!: Float32 = 72.0,
    animation!: AnimationSpec = AnimationSpec.automatic(...)
)
```

`wheelStep` 必须大于 0，否则抛 `IllegalArgumentException`。直接传 `AnimationSpec(...)` 可固定精确
时长与曲线；`AnimationSpec.automatic(...)` 会跟随主题动效档。

## 工厂方法

### web

```cangjie
public static func web(
    wheelStep!: Float32 = 72.0,
    duration!: UInt64 = Motion.normal,
    easing!: Easing = Easing.CubicBezier(0.22, 1.0, 0.36, 1.0)
): ScrollOptions
```

创建默认平滑策略。连续滚轮输入累计目标；外部偏移写入、滚动条操作、键盘揭示或内容边界收缩会取消旧目标。

### immediate

```cangjie
public static func immediate(wheelStep!: Float32 = 72.0): ScrollOptions
```

创建无保留动画的即时策略，适合兼容旧交互或确定性测试。

## 示例

```cangjie
let list = LazyColumn(1000, 40.0) { index => Label("Row ${index}") }
    .scrollOptions(ScrollOptions.web(duration: 180, easing: Easing.EaseOutCubic))

let exact = TextArea(text).scrollOptions(ScrollOptions.immediate(wheelStep: 48.0))
```

## 消费组件

`ScrollView`、`LazyColumn`、`LazyRow`、`LazyList`、`ListView`、`Table`、`TreeView`、
`TextArea`、`Dropdown` 与 `ComboBox` 均提供 `.scrollOptions(...)`。
