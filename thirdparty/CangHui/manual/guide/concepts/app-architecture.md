[CangHui 指南](../index.md) › 应用结构

# 模型、动作与界面边界

## 先用一句话说明

模型保存事实，动作完成一次业务变化，界面只显示事实并把用户意图交给动作。

这套边界建立在[状态、绑定与派生值](state-and-binding.md)之上。状态解决“值放在哪里”，应用结构继续回答“谁可以修改它、文件和后台任务放在哪里、怎样让主要规则可以脱离窗口测试”。

## 为什么重要

计数器可以把全部代码写在按钮回调里；记事本、任务看板或进程工具却不行。若打开文件、修改数组、校验、Toast 文案和控件声明挤在同一个构建闭包中，读者很快会遇到三类问题：同一动作被按钮和快捷键复制；错误路径没有恢复 busy 状态；纯业务规则只能启动窗口后测试。

CangHui 不要求特定目录模板，但真实示例反复体现同一职责分工。`model.cj` 保存事实和可测试规则，`views.cj` 声明控件，`file_actions.cj` 或 `worker.cj` 处理外部系统，`main.cj` 组装依赖和运行应用。文件名可以变化，依赖方向不应反转：模型不寻找按钮，文件层不直接操纵旧控件对象。

## 工作模型

把一次交互看成单向闭环：控件产生“选择任务”或“保存文档”意图；动作函数读取模型、验证并提交一次状态变化；构建函数再次读取模型，呈现新的列表、详情或错误。派生值只从事实计算，避免动作还要同步标题、计数和按钮启用状态。

基础设施是文件对话框、文件系统、剪贴板、进程和后台工作等会失败、会等待或需要关闭的边界。动作可以调用基础设施，但要把结果转换成模型理解的成功/失败值。后台闭包不能直接写 UI `State`；它向线程安全信箱发布普通数据，再由 UI 帧收取。

一个可维护项目可以采用以下依赖方向：

- `model.cj`：领域值、`State`、纯查询和纯变换；
- `actions.cj`：校验、选择、删除、保存请求等用例；
- `views.cj`：读取模型，声明 Label、Table、TextArea、Modal；
- `desktop.cj`：对话框、剪贴板、文件和后台适配；
- `main.cj`：创建模型、长期服务、主题和 `DesktopApp`。

## 选择与取舍

小页面不必为了“架构”创建五个空文件。先在一个文件里保持函数边界；当模型需要纯测试、多个输入入口共享动作，或基础设施需要替换时再拆文件。拆分依据是变化原因，而不是每个类型一个文件。

局部展开、临时选择等只服务一个声明位置的值仍可使用 `rememberState`。业务任务、文档正文、待保存路径等需要跨页面或被测试的事实放进显式模型。外部请求句柄由明确所有者保存，完成后清理；不要让每次构建重新发起请求。

## 应用这个模型

下面的对照把可测试规则与控件声明分开。`complete` 只是模型动作，界面可以让按钮、菜单和快捷键都调用它：

```cangjie role=contrast
class TaskModel {
    let selectedId = State<String>("")
    let status = State<String>("请选择任务")

    func select(id: String): Unit {
        selectedId.value = id
        status.value = "已选择 ${id}"
    }
}

func taskToolbar(model: TaskModel): Unit {
    Button("选择 alpha", {=> model.select("alpha")})
    Label(model.status.value)
}
```

下面的跟踪片段显示边界间只传普通值。工作线程发布结果；UI 帧中的动作才更新状态。失败也应走同一个 `publish`，这样 busy 不会永久停住：

```cangjie role=trace
// desktop/worker：不持有 UI State。
let _ = spawn {
    try {
        mailbox.publish(loadSnapshot())
    } catch (error: Exception) {
        mailbox.publish("加载失败：${error.message}")
    }
}

// views：FrameHandler 回调位于 UI 帧。
FrameHandler(onFrame: {_ =>
    match (mailbox.collect()) {
        case Some(result) => model.status.value = result
        case None => ()
    }
}) { renderWorkbench(model) }
```

这两段的关键不是类名，而是依赖方向：基础设施把结果交给动作，动作更新模型，视图读取模型。控件对象不进入后台闭包，线程锁内不做耗时工作。

## 常见误解

- **“多文件自然等于解耦。”** 若 views 仍直接操作文件、model 仍引用控件，换文件名不会改善边界。
- **“所有状态都应放进一个巨型模型。”** 状态应提升到读写它的最低共同所有者，局部交互不必污染应用模型。
- **“动作函数只能由按钮调用。”** 动作描述业务意图，按钮、菜单、快捷键和测试都可以调用。
- **“错误只需打印到终端。”** 桌面用户需要模型中的可见失败状态，并能重试或取消。
- **“构建闭包适合发起一次性请求。”** 构建会重跑；请求必须由事件动作发起并有稳定所有者。

## 相关 API

- [`State`](../../api/chui/core/State.md) 与 [`DerivedState`](../../api/chui/core/DerivedState.md) — 模型事实和派生结果。
- [`FrameHandler`](../../api/chui/core/FrameHandler.md) — UI 帧中的结果收取点。
- [`DesktopApp`](../../api/chui/desktop/DesktopApp.md) — 应用与资源所有者。

## 下一步

在[任务工作台教程](../tutorials/task-workbench.md)中把模型、动作、筛选和主从界面组合成完整程序；需要文件和后台服务时继续[桌面文件与后台任务](../how-to/desktop-files-and-background.md)。
