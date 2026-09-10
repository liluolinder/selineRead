[chui](../../index.md) › chui.core

# chui.core

```cangjie
import chui.core.*
```

UI 核心包：提供 [`Widget`](Widget.md) 接口和链式修饰器、栈/网格/流式/层叠/滚动/按需创建的布局容器、按钮与文本等基础控件、状态与双向绑定、动画、主题、容器 [`TypographyEnvironment`](TypographyEnvironment.md)、每帧上下文 [`UiContext`](UiContext.md)、[`UiOwnerQueue`](UiOwnerQueue.md)，以及浮层和焦点处理。`chui.controls`、`chui.text`、`chui.media` 的控件都建立在本包之上。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`Animator`](Animator.md) | 按固定时长与 [`Easing`](Easing.md) 曲线把数值从当前位置补间到目标的动画器——CSS transition 与 SwiftUI/Compose `.animation(...)` 背后的模型。 |
| [`Binding`](Binding.md) | 指向另一个可绑定值中某个字段的双向绑定，用 Bindable.project 创建。 |
| [`Button`](Button.md) | 带主题表面的按压按钮，既可使用居中标题，也可承载任意装饰性内容 slot。 |
| [`ButtonStyle`](ButtonStyle.md) | 按 hover、press、focus 与语义角色解析 Button/IconButton 外观的状态样式。 |
| [`ComponentControlStyle`](ComponentControlStyle.md) | 按选择/展开、hover、press 与 focus 解析 Chip、Checkbox、Dropdown 和 Accordion header 外观。 |
| [`DerivedState`](DerivedState.md) | 由一个或多个源计算出的只读可观察状态，用 derive 或 Observable.map 创建。 |
| [`DesignSnapshot`](DesignSnapshot.md) | 把稳定结构、计算几何、语义状态与 scoped Draw IR 合成为有界、可差分的 `canghui.design-snapshot/v1` 硬真相。 |
| [`AdaptiveGrid`](AdaptiveGrid.md) | 按可用宽度和最小单元宽度稳定推导列数的等宽响应式网格。 |
| [`Divider`](Divider.md) | 分隔内容的 1 逻辑像素发丝线，走向由 `axis` 指定、长度由父栈拉伸铺满。 |
| [`DeviceRotationLayout`](DeviceRotationLayout.md) | 根据规范化设备方向选择竖屏/横屏结构；宿主统一旋转完整界面帧。 |
| [`DeviceRotationTransition`](DeviceRotationTransition.md) | 供平台壳层复用的有向整帧设备旋转事务。 |
| [`EventHandler`](EventHandler.md) | 在子树收到事件之前先把每个事件交给回调的透明包装组件，回调返回 `true` 即消费该事件。 |
| [`Flexible`](Flexible.md) | 把内容纳入所在栈空间分配的包装组件：按权重分得剩余空间，而非按内容收缩。 |
| [`FlowRow`](FlowRow.md) | 把子组件从左到右排布、放不下时自动换到内容高度新行的流式容器。 |
| [`FrameHandler`](FrameHandler.md) | 每渲染帧调用一次回调并自动请求续帧的透明包装组件，是时间驱动动画与帧内轮询的挂载点。 |
| [`Grid`](Grid.md) | 把子组件排进固定列数、等宽单元格的网格容器，行高取本行最高的单元格。 |
| [`HScrollBar`](HScrollBar.md) | [`ScrollBar`](ScrollBar.md) 的水平镜像：为沿 x 轴滚动的表面提供同样的滑块拖拽与轨道分页控制器。 |
| [`HStack`](HStack.md) | 沿水平主轴排布子组件的弹性栈容器：以尾随 lambda 声明子组件，间距、主轴/交叉轴对齐与弹性参与可链式配置。 |
| [`Icon`](Icon.md) | 以方形边长绘制的非交互矢量图标，默认 18 vp、取主题文字色。 |
| [`IconButton`](IconButton.md) | 以图标为面、可选带文字标签的按钮，激活方式与 [`Button`](Button.md) 完全相同。 |
| [`InteractionSurface`](InteractionSurface.md) | 为任意装饰内容提供一个焦点、按压、release-inside 动作、Ink 与 semantic owner 的交互面。 |
| [`UiTaskScope`](UiTaskScope.md) | 在 UiOwnerQueue 上提供 single-flight、latest-only、bounded queue 与 debounce 后台准备生命周期。 |
| [`Keyed`](Keyed.md) | 给子树赋予稳定声明式标识的透明包装组件：其下的局部状态键与控件交互标识都以该键为命名空间。 |
| [`KeyedLayoutTransition`](KeyedLayoutTransition.md) | 让带稳定 key 的子树在重排或响应式重布局时，从当前可见矩形连续移动和变形到新槽位。 |
| [`Label`](Label.md) | 单行或多行文本组件：默认单行、溢出以省略号截断，字体样式经链式构建器就地配置。 |
| [`LazyColumn`](LazyColumn.md) | 只构建视口附近行的定行高垂直滚动列表，构建、布局与绘制均为 O(可见) 而非 O(行数)。 |
| [`LazyList`](LazyList.md) | 行高由 `heightOf` 逐行给定的惰性垂直滚动列表，是 [`LazyColumn`](LazyColumn.md) 的变高对应物。 |
| [`LazyRow`](LazyRow.md) | 只构建视口附近列的定列宽水平滚动条带，是 [`LazyColumn`](LazyColumn.md) 的水平对应物。 |
| [`Overlay`](Overlay.md) | 浮在整棵组件树之上的交互浮层：下拉弹出面板、菜单或对话框。 |
| [`Panel`](Panel.md) | 带主题表面与内容内边距的卡片式容器，是划分界面区块的基础构件。 |
| [`PageTransitionLayout`](PageTransitionLayout.md) | 在两棵页面子树之间播放横向交接并插值测量尺寸。 |
| [`Pulse`](Pulse.md) | 永动的循环时间线——骨架屏微光、呼吸状态点、加载脉冲。 |
| [`Reveal`](Reveal.md) | 在零与内容自然高度之间缓动过渡的展开/收起容器，切换 `shown` 即让内容滑入滑出。 |
| [`Row`](Row.md) | ArkTS 风格的通用水平容器；以 `space`、`justifyContent`、`alignItems` 和子项 `layoutWeight` 表达布局。 |
| [`ScrollBar`](ScrollBar.md) | 供滚动容器内部复用的垂直滚动条拖拽控制器，把命中滚动条的按下与移动转发给它，即得一致的滑块拖拽与轨道分页行为。 |
| [`ScrollView`](ScrollView.md) | 裁剪显示、支持滚轮与拖动滚动条的垂直滚动视口，滚动位置按稳定标识跨帧保留。 |
| [`SemanticRuntime`](SemanticRuntime.md) | 每窗口的有界、带 revision 语义树与类型化动作调度器，不创建远程控制面。 |
| [`SegmentedControlStyle`](SegmentedControlStyle.md) | 为库存 SegmentedControl/TabView 解析可形变选中镜片及标签前景，不接管输入与布局。 |
| [`Spacer`](Spacer.md) | 测量为零并吸收所在栈剩余空间的空白弹性组件，把兄弟组件推向两端。 |
| [`Spacing`](Spacing.md) | 4 像素栅格上的间距尺度：七档命名间隔，以虚拟像素的 Length 值表达。 |
| [`Radii`](Radii.md) | 圆角半径尺度，虚拟像素：小档给标签与输入框、中档给卡片、大档给醒目表面，pill 收成全圆头。 |
| [`Motion`](Motion.md) | 动效令牌：三档标准动画时长（毫秒）与四条角色化缓动曲线，与 Animator、Spring 搭配使用。 |
| [`Materials`](Surface.md#materialprovider-与-materials) | 创建 solid、theme surface 与 theme primary material provider。 |
| [`Spring`](Spring.md) | 跨帧把数值弹性逼近目标的弹簧-阻尼器。 |
| [`State`](State.md) | 可写的单一数据源可观察状态：对 value 赋值会推进修订号，并在调用线程上同步通知全部观察者。 |
| [`StateObservation`](StateObservation.md) | 由 Observable.observe 返回的可取消的观察句柄：持有它就持续收到回调，close() 后不再收到。 |
| [`StateStore`](StateStore.md) | 跨声明式重建保留显式键控局部状态的容器：一次完整构建未访问的条目会被移除，与视图卸载语义一致。 |
| [`Surface`](Surface.md) | 绘制 material 并发布前景环境、但不新增交互所有者的装饰组合面。 |
| [`SurfacePainter`](Surface.md#surfacepainter) | 只替换 Surface 背景绘制、保留 material 前景与 child 所有权的低层效果钩子。 |
| [`Tooltip`](Tooltip.md) | 为任意控件包上悬停提示：指针在子组件上驻留 500 毫秒后，提示文本被绘制在整棵组件树之上；其余时刻是完全透明的包装。 |
| [`UiContext`](UiContext.md) | 每帧传给全部组件回调的服务枢纽：渲染器与主题、指针与帧状态，以及焦点、悬停、按下、拖拽、提示与浮层等共享交互协议。 |
| [`UiOwnerQueue`](UiOwnerQueue.md) | 多 producer、单 UI owner 的顺序提交队列，提供 epoch/surface generation 门、取消、关闭和完成回执。 |
| [`UiOwnerReceipt`](UiOwnerQueue.md#uiownerreceipt) | owner task 的不可变最终回执：状态、执行 epoch、追踪 hash 与消息。 |
| [`UiOwnerTicket`](UiOwnerQueue.md#uiownerticket) | producer 持有的任务票据：暴露顺序号、取消入口和最终回执。 |
| [`VStack`](VStack.md) | 沿垂直主轴排布子组件的弹性栈容器：以尾随 lambda 声明子组件，间距、主轴/交叉轴对齐与弹性参与可链式配置。 |
| [`ZStack`](ZStack.md) | 把子组件按声明顺序自底向顶叠放、并在同一框架内对齐的层叠容器。 |

**结构体**

| 类型 | 说明 |
|---|---|
| [`Corners`](Corners.md) | 背景四角的独立圆角半径，即 CSS 四值 `border-radius` 模型，按左上、右上、右下、左下排列。 |
| [`ButtonAppearance`](ButtonStyle.md#buttonappearance) | ButtonStyle 返回的表面、前景、InkWell 与焦点圆角。 |
| [`ButtonLayoutStyle`](ComponentTheme.md#buttonlayoutstyle) | 标题/slot Button 的默认内容内边距与最小尺寸。 |
| [`ButtonVisualState`](ButtonStyle.md#buttonvisualstate) | 连续 hover/press 进度与焦点状态。 |
| [`ComponentTheme`](ComponentTheme.md) | Theme 中的 Button、选择/披露控件、Panel 与组件令牌覆盖层。 |
| [`ComponentControlAppearance`](ComponentControlStyle.md#componentcontrolappearance) | 非 Button 交互控件的表面、前景、indicator、InkWell 与焦点圆角。 |
| [`ComponentControlState`](ComponentControlStyle.md#componentcontrolstate) | 选择/展开、hover、press 与 focus 状态。 |
| [`ComponentShape`](ComponentTheme.md) | 可继承 Theme 的 small/control/pill 组件圆角。 |
| [`ComponentSpacing`](ComponentTheme.md) | compact/control/selection 内边距、间距、最小高度与 indicator 尺寸。 |
| [`ComponentTypography`](ComponentTheme.md) | Chip、Checkbox、Dropdown 与 Accordion header 的 control 语义字号。 |
| [`ControlContentEnvironment`](ControlContentEnvironment.md) | 当前装饰内容的前景、supporting 前景、role、action owner 与交互状态。 |
| [`ControlSemantics`](ControlSemantics.md) | role、label/value、action、shortcut、owner 与可选选择/展开状态。 |
| [`DesignSnapshotDiff`](DesignSnapshot.md#designsnapshotdiff) | 按结构、几何、样式、状态和绘制 scope 分类的稳定 ID 差分。 |
| [`DesignSnapshotEnvironment`](DesignSnapshot.md) | 不携带本机路径、进程或句柄的可重放视口环境。 |
| [`DesignSnapshotProperty`](DesignSnapshot.md) | 可排序、可入场脱敏的一条计算样式或状态事实。 |
| [`Gradient`](Gradient.md) | 圆角背景用的双色线性渐变填充，默认自上而下、`vertical` 为 false 时自左向右。 |
| [`LayoutTransitionGeometry`](LayoutTransitionGeometry.md) | 键控布局过渡的当前绘制矩形、父布局目标矩形与稳定状态回执。 |
| [`Length`](Length.md) | 带显式单位的一维尺寸，写作 `100.px`、`24.vp` 或 `15.fp`。 |
| [`LengthInsets`](LengthInsets.md) | 四边各自携带单位的间距，供 padding 类 API 使用，布局时解析为逻辑像素的 `Insets`。 |
| [`Shadow`](Shadow.md) | 可配置的组件阴影，包含水平/垂直偏移、模糊、扩散和颜色，作用类似 CSS `box-shadow`。 |
| [`ScrollOptions`](ScrollOptions.md) | 可滚动组件共享的滚轮策略：选择即时或平滑行为，并配置步长、播放时长与曲线。 |
| [`SemanticActionReceipt`](SemanticRuntime.md#相关类型) | 精确窗口/revision 绑定动作的结构化接受或拒绝结果。 |
| [`SemanticActionRequest`](SemanticRuntime.md#相关类型) | 按窗口、revision、节点、动作和来源发起的类型化请求。 |
| [`SemanticInteractionPolicy`](SemanticRuntime.md#相关类型) | 控制 Accessibility/Keyboard/Gamepad/Voice/Agent 来源；Voice/Agent 默认关闭。 |
| [`SemanticNode`](SemanticRuntime.md#相关类型) | 已脱敏的一个语义节点、状态与可用动作。 |
| [`SemanticRuntimeLimits`](SemanticRuntime.md#相关类型) | 每窗口节点、深度与文本字节上限。 |
| [`SemanticTreeDiff`](SemanticRuntime.md#相关类型) | 两个 revision 之间的 added/removed/changed 稳定 ID 集。 |
| [`SemanticTreeSnapshot`](SemanticRuntime.md#相关类型) | 一个窗口的一次深拷贝隔离语义树快照。 |
| [`SegmentedControlVisualState`](SegmentedControlStyle.md#segmentedcontrolvisualstate) | 选中镜片的实时下标、目标、伸展量与运动方向。 |
| [`Shape`](Surface.md#shape) | Surface 与 Ink 共用的矩形/圆角矩形几何。 |
| [`SurfaceMaterial`](Surface.md#surfacematerial) | MaterialProvider 返回的表面样式、前景、supporting 前景与 Ink 颜色。 |
| [`SurfaceState`](Surface.md#surfacestate) | MaterialProvider 接收的 enabled/readonly/selection/focus/hover/press 只读状态。 |
| [`Theme`](Theme.md) | 组件共用的语义调色板、动效设置与组件级覆盖层。 |
| [`TypographyEnvironment`](TypographyEnvironment.md) | 容器传给 Label、RichText 与 RichSpan 的逐字段字族、字号和样式环境。 |

**接口**

| 类型 | 说明 |
|---|---|
| [`Bindable`](Bindable.md) | 可读、可写并能通知变化的值。 |
| [`LengthUnits`](LengthUnits.md) | 为数值字面量提供 `.px`/`.vp`/`.fp` 长度后缀的接口。 |
| [`MaterialProvider`](Surface.md#materialprovider-与-materials) | 从 Theme 与 SurfaceState 解析 SurfaceMaterial，不拥有事件或焦点。 |
| [`Observable`](Observable.md) | 可读、可观察值的抽象：读取当前值、暴露修订号、订阅变更，并可 map 出派生状态。 |
| [`Widget`](Widget.md) | 所有组件共同实现的立即模式契约：每帧参与测量、布局、绘制与事件处理，并自带尺寸、内边距、表面、排版环境、阴影、弹性、可见性等整套链式修饰器。 |

**枚举**

| 类型 | 说明 |
|---|---|
| [`Alignment`](Alignment.md) | 九宫格式的二维对齐，供 [`ZStack`](ZStack.md) 这类把子组件放进同一框架的容器定位不拉伸的子组件。 |
| [`Axis`](Axis.md) | 布局方向轴：水平或垂直。 |
| [`ButtonRole`](ButtonRole.md) | 按钮的语义角色：常规、主要或危险，决定主题为按钮生成的表面配色。 |
| [`ClipPolicy`](Surface.md#clippolicy) | 选择不裁剪 child，或按 Surface shape 的当前边界进行裁剪。 |
| [`ControlRole`](InteractionSurface.md#构造函数) | InteractionSurface 的 button/link/checkbox/switch/custom 语义角色。 |
| [`CrossAxisAlignment`](CrossAxisAlignment.md) | 栈在交叉轴上放置子组件的策略：靠端、居中或拉伸填满。 |
| [`CursorShape`](CursorShape.md) | 控件在指针悬停期间申请的语义指针形状，由宿主映射为各平台的原生光标。 |
| [`Easing`](Easing.md) | 把 `[0, 1]` 内的动画进度映射为缓动后进度的时序曲线。 |
| [`LengthUnit`](LengthUnit.md) | 长度值的单位：物理像素 `Px`、虚拟像素 `Vp` 或随用户字体缩放的字体像素 `Fp`。 |
| [`LayoutTransitionClip`](LayoutTransitionClip.md) | 选择键控布局过渡不裁剪、裁剪到动画矩形或裁剪到目标矩形。 |
| [`MainAxisAlignment`](MainAxisAlignment.md) | 栈沿主轴分配剩余空间的策略：靠端、居中或三种等分间隔。 |
| [`ScrollBehavior`](ScrollBehavior.md) | 滚轮输入立即改变偏移，或沿保留式缓动曲线逐帧到达目标。 |
| [`SemanticActionKind`](SemanticRuntime.md#相关类型) | Activate/Focus/Increment/Decrement/Dismiss 类型化动作。 |
| [`SemanticActionSource`](SemanticRuntime.md#相关类型) | Accessibility/Keyboard/Gamepad/Voice/Agent 请求来源。 |
| [`TextAlign`](TextAlign.md) | 文本在所分配框架内的水平对齐方式：行首、居中或行尾。 |
| [`UiOwnerTaskStatus`](UiOwnerQueue.md#uiownertaskstatus) | owner task 的最终状态：提交、取消、关闭/过期拒绝或失败。 |

**外部类型扩展**

| 类型 | 说明 |
|---|---|
| [`Int64 (extension)`](extensions.md#int64-的-lengthunits-实现) | 整数字面量的 `.px`/`.vp`/`.fp` 长度后缀。 |
| [`Float64 (extension)`](extensions.md#float64-的-lengthunits-实现) | 浮点字面量的 `.px`/`.vp`/`.fp` 长度后缀。 |

## 函数

| 函数 | 说明 |
|---|---|
| [`derive`](functions.md#derive) | 返回从一到多个源计算出的只读派生状态。 |
| [`ForEach`](functions.md#foreach) | 为每个数据项声明一棵键控子树。 |
| [`ForEachIndexed`](functions.md#foreachindexed) | 以位置为标识、为每个数据项声明一棵键控子树。 |
| [`LazyGrid`](functions.md#lazygrid) | 垂直滚动的虚拟化网格：`data` 排成 `columns` 等宽列并按行开窗，海量均匀单元格（照片墙、卡片网格）只花一屏的成本。 |
| [`GestureSurface`](GestureSurface.md) | 在一个 InteractionSurface owner 下组合 tap、double tap、long press、drag、hover 与 pointer capture。 |
| [`currentStateGeneration`](functions.md#currentstategeneration) | 原子读取进程级状态写入观察代号。 |
| [`rememberState`](functions.md#rememberstate) | 返回由活动 [`DesktopApp`](../desktop/DesktopApp.md) 构建保留的局部状态。 |
| `scrollBehaviorName` | 返回 `immediate` 或 `smooth` 的稳定诊断名称。 |
| [`drawFocusRing`](functions.md#drawfocusring) | 绘制键盘焦点环：贴着控件的强调色圆角描边，画在边界外 2 像素处，读作独立于控件自身边缘的光晕。 |
| [`emit`](functions.md#emit) | 把新构造的组件注册进最内层打开的构建块。 |
| [`focusableControlIdentity`](functions.md#focusablecontrolidentity) | 一步完成按构建顺序分配标识并注册为焦点项。 |
| [`claimHoverIfInside`](functions.md#claimhoverifinside) | 当 MouseMove 落在 `frame` 内时，为 `id` 申请悬停状态和指定的指针形状。 |
