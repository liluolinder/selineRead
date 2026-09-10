[chui](../../index.md) › chui.controls

# chui.controls

```cangjie
import chui.controls.*
```

成品控件库：选择与数值输入（勾选、开关、单选、滑杆、步进、评分）、下拉与菜单（下拉框、右键菜单、菜单栏、日期/时间选择）、导航（分段、页签、面包屑、分页、步骤指示）、数据展示（表格、树、列表、富文本、徽章、进度）、以及模态对话框、Toast 通知、折叠面板、分栏与可重排列表。全部建立在 [`chui.core`](../core/index.md) 的组件契约、状态绑定与浮层协议之上。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`Accordion`](Accordion.md) | 可折叠分区的竖向堆叠：每个分区可使用文本或装饰 slot header，并保留一个外层交互所有者。 |
| [`Badge`](Badge.md) | 紧凑的状态标签：圆角胶囊底上画同色系文本，纯展示、不响应交互。 |
| [`Breadcrumb`](Breadcrumb.md) | 面包屑路径：以箭头分隔的一行层级段（如 首页 › 文档 › 项目），末段为当前位置、前段可点击返回上级路径。 |
| [`Checkbox`](Checkbox.md) | 带文本或装饰 slot 的勾选框，双向绑定一个 `Bindable<Bool>`。 |
| [`Chip`](Chip.md) | 可选中的文本/slot 过滤胶囊，release-inside 或聚焦后 Space/Enter 切换选中。 |
| [`ContextMenu`](ContextMenu.md) | 给任意子内容包上右键上下文菜单的透明包装组件。 |
| [`DataColumn`](DataColumn.md) | Table.of 的类型化列定义：表头、列宽、数值标记与从行数据 T 抽取单元格文本的 value 抽取器。 |
| [`DatePicker`](DatePicker.md) | 日期字段：点击弹出月历浮层，双向绑定一个 `Bindable<CalendarDate>`。 |
| [`Dropdown`](Dropdown.md) | 下拉选择框：闭合面可显示当前文本或装饰 slot，展开行保持字符串选择列表。 |
| [`ListView`](ListView.md) | 单选字符串列表：可滚动的行列表，点击或键盘移动选择，双向绑定选中下标 `Bindable<Int64>`。 |
| [`MenuBar`](MenuBar.md) | 应用菜单栏：一行水平排列的菜单标题，点击标题即在其正下方弹出下拉菜单，菜单打开时指针掠过其他标题即切换过去。 |
| [`Modal`](Modal.md) | 模态对话框：`presented` 为真时把 `body` 子树布局在一块对视口居中的面板里，经浮层浮于整棵界面树之上并压暗背景，事件一律不再落到背景树。 |
| [`Pagination`](Pagination.md) | 长分页内容（搜索结果、表格、商品目录）的页码导航条：上一页/下一页箭头夹着一段窗口化页码——恒含首末页与当前页两侧的邻页，其间空缺折叠为省略号。 |
| [`Picker`](Picker.md) | 在一组有限字符串项之间前后切换的紧凑选择器：两端各一枚 ‹ › 按钮、中间显示当前项，切换在两端回绕。 |
| [`ProgressBar`](ProgressBar.md) | 把可观察数值显示为水平填充条的只读进度指示，中央叠加百分比标签。 |
| [`ProgressRing`](ProgressRing.md) | 环形进度指示：淡色轨道整环上，自 12 点方向顺时针扫出与 `value`（0…1 比例，越界截断）相当的前景弧，中心可叠加取整百分比。 |
| [`RadioButton`](RadioButton.md) | 整数值互斥选择组中的一个选项：同组各项共享一个 `Bindable<Int64>`，激活任一项即把共享值设为该项的 `value`。 |
| [`Rating`](Rating.md) | 以一排实心/空心圆点输入 0…`count` 整数评分的控件：实心圆点表示当前评分，其余为空心，默认五点。 |
| [`ReorderableList`](ReorderableList.md) | 行高固定、可拖拽重排的垂直列表：每行左侧带握点手柄，按住手柄拖动即抬起该行随指针移动、其余行让位露出落点，松手调用 onMove(from, to) 提交——列表只报告移动，数据始终由调用方持有并自行重排。 |
| [`RichText`](RichText.md) | 行内多样式文本组件：把一串 RichSpan（配色、加粗、变字号的文本段与行内图标）排在同一行内，超出可用宽度自动换行到任意多行。 |
| [`SegmentedControl`](SegmentedControl.md) | 把互斥选项排成一行等宽段、由滑动指示块标记当前选中的单选控件。 |
| [`Slider`](Slider.md) | 拖动圆钮在闭区间内取值的滑杆，双向绑定 `Bindable<Float32>`：按下即跳到指针处并开始拖拽，`step` 为正时值吸附到 `lower + k·step` 的离散刻度，为 0（默认）则连续取值。 |
| [`SplitView`](SplitView.md) | 用一根可拖动分隔条把空间分给两个窗格的容器，让用户在侧栏与文档、列表与详情之间自行调配空间。 |
| [`StepIndicator`](StepIndicator.md) | 多步流程（结账、引导、向导）的横向步骤进度条：编号节点由连接线串起，`current` 之前的步骤实心打勾、当前步高亮、其后置灰。 |
| [`Stepper`](Stepper.md) | 带减/增按钮与键盘支持的整数值编辑器：两端 −/+ 各步进一次，值始终夹在闭区间内。 |
| [`Switch`](Switch.md) | 绑定布尔状态的桌面开关：滑轨带圆钮，点击（或聚焦后 Enter/Space）取反 `checked`，圆钮以弹簧动画滑向新位置。 |
| [`Table`](Table.md) | 多列、可排序的数据表格：固定表头、窗口化滚动的正文与单行选择。 |
| [`TableColumn`](TableColumn.md) | Table 数据表格的一列定义：表头标题、固定像素宽度与是否数值列。 |
| [`TabView`](TabView.md) | 顶部页签条加整页内容区的页签容器，同一时刻只有选中页参与布局、绘制与事件。 |
| [`TimePicker`](TimePicker.md) | 带弹出选择面板的时间字段：闭合时显示绑定的 [`TimeOfDay`](TimeOfDay.md)，点击（或聚焦后按 Enter/Space/Down）经交互浮层弹出面板，面板把 24 小时网格与逐分钟编辑器配成一对。 |
| [`Toaster`](Toaster.md) | 瞬态 Toast 通知的调度器：保存当前仍在显示的通知及各自的剩余时间，从任意处调用 `show` 即可加入一条消息。 |
| [`ToastLayer`](ToastLayer.md) | 把一个 [`Toaster`](Toaster.md) 的通知渲染到视口右下角并驱动其时钟的浮层组件。 |
| [`TreeNode`](TreeNode.md) | [`TreeView`](TreeView.md) 的一个节点：稳定的 `id`、显示用的 `label`、可选的前置 `icon` 与子节点数组，纯数据、构造后不可变。 |
| [`TreeView`](TreeView.md) | 带展开/折叠的层级列表——文件浏览器、大纲、导航树。 |

**结构体**

| 类型 | 说明 |
|---|---|
| [`AccordionSection`](AccordionSection.md) | `Accordion` 分区描述：标题文本或装饰 header slot，加正文构建函数。 |
| [`CalendarDate`](CalendarDate.md) | 一个日历日——年、月（1–12）、日（1–31），不含时刻与时区。 |
| [`Menu`](Menu.md) | `MenuBar` 菜单栏的一个顶级菜单描述：标题加其下拉包含的菜单项。 |
| [`MenuItem`](MenuItem.md) | 菜单中的一个条目：标签、选中时执行的动作、可选的右对齐快捷键提示与可用标记。 |
| [`RichSpan`](RichSpan.md) | RichText 中的一段带样式行内片段：一段文本或一枚行内图标，可逐段配色、加粗、斜体、加装饰线、换字体、调字号、垫高亮底或挂点击动作。 |
| [`TimeOfDay`](TimeOfDay.md) | 表示一天内的时刻，只有小时（0–23）和分钟（0–59），不含日期与时区；[`TimePicker`](TimePicker.md) 用它保存选中时间。 |

**枚举**

| 类型 | 说明 |
|---|---|
| [`BadgeKind`](BadgeKind.md) | `Badge` 徽标的语义配色：中性、主题强调色，或信息/成功/警告/危险四种状态色。 |
| [`ToastKind`](ToastKind.md) | Toast 通知的类别，决定通知卡片左侧强调条的颜色。 |
