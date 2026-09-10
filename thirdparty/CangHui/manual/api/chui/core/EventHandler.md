[chui](../../index.md) › [chui.core](index.md) › EventHandler

# EventHandler

`chui.core` 包中的 public class

在子树收到事件之前先把每个事件交给回调的透明包装组件，回调返回 `true` 即消费该事件。布局、绘制与弹性行为全部转发给子树，因此把它包在任意位置都不改变界面，只改变事件路由。

## 声明

```cangjie
public class EventHandler <: Widget
```

## 继承

EventHandler <: [`Widget`](Widget.md)

## 说明

典型用法是处理应用级键盘快捷键：把整个界面包进 `EventHandler`，在回调里处理方向键、回车、Escape 等按键；回调不处理的事件继续交给子控件。`Frame` 是逐帧广播事件，回调与子控件都会收到，不能在这里拦截；需要每帧更新状态时改用 [`FrameHandler`](FrameHandler.md)。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("EventHandler", 640, 420))
    app.run {
        let status = rememberState<String>("shortcut.status") {"等待按键"}
        EventHandler(onEvent: {
            event => match (event) {
                case UiEvent.KeyDown(Key.Escape, _) =>
                    status.value = "已处理 Escape"
                    true
                case _ => false
            }
        }) {
            VStack {
                Label("按 Escape 触发应用快捷键")
                Label(status.value)
                // 运行时：按 Escape 后第二行变为“已处理 Escape”；其它按键继续交给子控件。
            }
        }
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(onEvent!: (UiEvent) -> Bool, body!: () -> Unit)`](#init) | 以事件回调与界面构建函数块创建包装。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 把可用空间原样转给子树并返回其测量尺寸。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 把分配到的区域原样交给子树布局。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制子树。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 先把事件交给回调，回调未消费时再下发给子树。 |
| [`isFlexible()`](#isflexible) | 转发子树的弹性参与声明。 |
| [`flexWeight()`](#flexweight) | 转发子树声明的弹性权重。 |
| [`acceptsStretch(axis: Axis)`](#acceptsstretch) | 转发子树是否允许在给定轴上被拉伸。 |
| [`participatesInLayout()`](#participatesinlayout) | 转发子树是否占据父布局中的位置。 |
| [`focusableId()`](#focusableid) | 转发子树的单一焦点项 id。 |
| [`focusableIds()`](#focusableids) | 转发子树注册的全部焦点项。 |
| [`interactionOwnerIds()`](#interactionownerids) | 声明 EventHandler 自身的普通事件所有权，并合并子树所有者。 |

## 构造函数

### init

以事件回调与界面构建函数块创建包装。

```cangjie
public init(onEvent!: (UiEvent) -> Bool, body!: () -> Unit)
```

**参数**

- `onEvent!`: `(UiEvent) -> Bool` — 先于子树收到每个事件；返回 `true` 即消费，子树不再看到该事件。`Frame` 事件的返回值被忽略。
- `body!`: `() -> Unit` — 界面构建函数块；块内声明多个组件时自动竖排为一个子树。

## 方法

### measure

把可用空间原样转给子树并返回其测量尺寸。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当帧上下文。
- `available`: `Size` — 可用空间，逻辑像素。

**返回值** `Size` — 子树的测量尺寸。

### layout

把分配到的区域原样交给子树布局。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `rect`: `Rect` — 分配给本包装组件的区域，单位为逻辑像素。

### draw

绘制子树。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。

### handle

先把事件交给回调，回调未消费时再下发给子树。`Frame` 事件例外：回调与子树都会收到，且本方法总是返回 `false`，帧脉搏因此无法被拦截。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `event`: `UiEvent` — 待处理的输入事件。

**返回值** `Bool` — 事件被回调或子树消费时为 `true`。

### isFlexible

转发子树的弹性参与声明。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 子树是否参与所在栈的弹性分配。

### flexWeight

转发子树声明的弹性权重。

```cangjie
public func flexWeight(): Float32
```

**返回值** `Float32` — 子树的权重份额。

### acceptsStretch

转发子树是否允许在给定轴上被拉伸。

```cangjie
public func acceptsStretch(axis: Axis): Bool
```

**参数**

- `axis`: [`Axis`](Axis.md) — 询问的轴向。

**返回值** `Bool` — 子树允许被拉伸时为 `true`。

### participatesInLayout

转发子树是否占据父布局中的位置。

```cangjie
public func participatesInLayout(): Bool
```

**返回值** `Bool` — 子树参与布局时为 `true`。

### focusableId

转发子树的单一焦点项 id。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 子树的焦点项 id，子树不可聚焦时为 `None`。

### focusableIds

转发子树注册的全部焦点项。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 子树内全部焦点项 id，按声明顺序。

### interactionOwnerIds

声明 `EventHandler` 自身能够消费普通事件，并合并 child 的交互所有者。该声明独立于焦点：即使 child 只是
Label，EventHandler 仍是一个 owner，不能放进 [`InteractionSurface`](InteractionSurface.md) 的装饰 slot。

```cangjie
public func interactionOwnerIds(): Array<String>
```

**返回值** `Array<String>` — 以 `EventHandler` 开头的子树交互所有者列表。

## 另请参阅

- [FrameHandler](FrameHandler.md) — 按帧回调的姊妹包装，用于动画与帧内轮询。
- [Widget](Widget.md) — 事件派发与消费语义的协议定义。
