package SelineRead

import chui.*
import std.math.*

// 无边框窗口的自绘标题栏：参照 SelineDebugToolBox 的实现——
// WindowDragHandle 在自身矩形内按下左键时记录鼠标与窗口起点，
// 移动时按增量 setWindowPosition；双击切换最大化/还原。
// 右上角为自绘「— 最小化 / □ 最大化还原 / × 关闭」三键。

/** 拖拽状态：按下时刻/位置与拖拽进行中标志（仅 UI 线程访问）。 */
public class WindowDragState {
    public var dragging: Bool = false
    public var grabMouseX: Float32 = 0.0
    public var grabMouseY: Float32 = 0.0
    public var grabWindowX: Int32 = 0
    public var grabWindowY: Int32 = 0
    // 上次左键按下时刻（ctx.frame.elapsedMs 单调毫秒）与位置：双击最大化判定用
    public var lastClickAtMs: UInt64 = UInt64.Max
    public var lastClickX: Float32 = -1.0
    public var lastClickY: Float32 = -1.0
}

/**
 * 标题栏拖拽区：作为弹性子项占住行中段空白，把左侧品牌区与右侧窗口三键推到两端。
 */
public class WindowDragHandle <: Widget {
    private static let OWNER_ID: String = "WindowDragHandle"
    private let app: DesktopApp
    private let state: WindowDragState
    private var frame = Rect.zero()

    public init(app: DesktopApp, state: WindowDragState) {
        this.app = app
        this.state = state
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        // 与标题栏等高的固定高度，占满整行供点击命中（横向由弹性分配负责）
        Size(0.0, 44.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(_: UiContext): Unit {}

    public func isFlexible(): Bool {
        true
    }

    // chui 将 MouseMove/MouseUp 先路由给 pointerCaptureOwner，控件须暴露自己的
    // interactionOwner 才能在按下后持续收到移动事件
    public func interactionOwnerIds(): Array<String> {
        [WindowDragHandle.OWNER_ID]
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    let now = ctx.frame.elapsedMs
                    let dx = if (x >= state.lastClickX) { x - state.lastClickX } else { state.lastClickX - x }
                    let dy = if (y >= state.lastClickY) { y - state.lastClickY } else { state.lastClickY - y }
                    // 双击判定：距上次左键按下 ≤500ms 且位移很小 → 切换最大化/还原
                    let doubleClick = state.lastClickAtMs != UInt64.Max &&
                        now >= state.lastClickAtMs && now - state.lastClickAtMs <= UInt64(500) &&
                        dx + dy <= 8.0
                    state.lastClickAtMs = now
                    state.lastClickX = x
                    state.lastClickY = y
                    if (doubleClick) {
                        app.toggleMaximizeWindow()
                        true
                    } else {
                        let mouse = Mouse.globalState()
                        let pos = app.windowPosition()
                        state.dragging = true
                        state.grabMouseX = mouse.x
                        state.grabMouseY = mouse.y
                        state.grabWindowX = pos.x
                        state.grabWindowY = pos.y
                        ctx.capturePointer(WindowDragHandle.OWNER_ID)
                        Mouse.capture(true)
                        true
                    }
                } else {
                    false
                }
            case UiEvent.MouseMove(_, _) =>
                if (state.dragging) {
                    let mouse = Mouse.globalState()
                    app.setWindowPosition(state.grabWindowX + Int32(mouse.x - state.grabMouseX),
                        state.grabWindowY + Int32(mouse.y - state.grabMouseY))
                    true
                } else {
                    false
                }
            case UiEvent.MouseUp(MouseButton.Left, _, _) =>
                if (state.dragging) {
                    state.dragging = false
                    ctx.releasePointerCapture(WindowDragHandle.OWNER_ID)
                    Mouse.capture(false)
                    true
                } else {
                    false
                }
            case _ => false
        }
    }
}

/** 右上角自绘窗口控制三键（最小化 / 最大化还原 / 关闭）。 */
func windowControlButtons(app: DesktopApp, mode: Int64): Unit {
    Button(onClick: {
        => app.minimizeWindow()
    }, style: Some(WINDOW_BUTTON_STYLE)) {
        ImageView(iconPath("minus", false, mode), fit: ImageFit.Contain,
            preferredWidth: Length(18.0, LengthUnit.Vp), preferredHeight: Length(18.0, LengthUnit.Vp))
    }.width(38.0).height(38.0)
    Button(onClick: {
        => app.toggleMaximizeWindow()
    }, style: Some(WINDOW_BUTTON_STYLE)) {
        let maximized = app.windowFlags().maximized
        ImageView(if (maximized) { iconPath("arrow_down_right_and_arrow_up_left", false, mode) } else {
            iconPath("arrow_up_left_and_arrow_down_right", false, mode)
        }, fit: ImageFit.Contain,
            preferredWidth: Length(18.0, LengthUnit.Vp), preferredHeight: Length(18.0, LengthUnit.Vp))
    }.width(38.0).height(38.0)
    Button(onClick: {
        => app.requestWindowClose()
    }, style: Some(WINDOW_BUTTON_STYLE)) {
        ImageView(iconPath("xmark", false, mode), fit: ImageFit.Contain,
            preferredWidth: Length(18.0, LengthUnit.Vp), preferredHeight: Length(18.0, LengthUnit.Vp))
    }.width(38.0).height(38.0)
}

/** 应用标题栏：左段卡片/列表切换（靠左）+ 两侧拖拽区夹持居中的搜索组
 * （首页）或返回/收藏键（详情页）+ 右侧窗口三键。
 * 拖拽区面积大（左右各占剩余空白），双击可最大化。
 * 左内边距对齐各页面卡片左边缘：首页 14 / 详情页 20。 */
func titleBar(app: DesktopApp, state: AppState): Unit {
    // 详情页只在「打开它的页签」下生效（切到其他页签再切回仍显示详情）
    let inDetail = detailVisibleNow(state)
    let downloadsTab = !inDetail && state.currentTab.value == 2
    let shelfTab = !inDetail && state.currentTab.value == 1
    let leftPad: Float32 = if (inDetail) { 20.0 } else { 14.0 }
    HStack {
        if (inDetail) {
            detailNavButtons(app, state)
        } else if (downloadsTab) {
            // 下载页签：打开下载文件夹（常驻）+ 清空已完成（仅存在已结束任务时出现）
            Button("打开文件夹", {=> openDownloadsFolder()})
            if (hasFinishedDownloads(state)) {
                Button("清空已完成", {=> clearCompletedDownloads(state)})
            }
        } else if (shelfTab) {
            // 书架页签：卡片/列表切换 + 刷新（无搜索框）
            shelfSwitcher(state)
            if (!state.currentUser.value.isNone()) {
                Button("刷新", {=> fetchSaved(app, state)})
            }
        } else {
            homeSwitcher(state)
        }
        WindowDragHandle(app, state.windowDrag).flex(1.0)
        if (!inDetail && !downloadsTab && !shelfTab) {
            homeSearchBar(app, state)
        }
        WindowDragHandle(app, state.windowDrag).flex(1.0)
        windowControlButtons(app, state.themeMode.value)
    }.spacing(10.0).crossAxisAlignment(CrossAxisAlignment.Center).hug().fillWidth()
        .padding(leftPad, 8.0, 10.0, 0.0)
}
