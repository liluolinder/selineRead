/*
 * 应用外壳：自绘标题栏 + 可伸缩侧栏（与 seline_bili 一致）+ 内容面板 + 状态栏。
 *
 * 标题栏是**无边框窗口**里唯一能拖动窗口的区域：`SelineTitleBarSurface`
 * 负责背景与拖动，`SelineCaptionControls` 负责最小化/最大化/关闭。
 *
 * 侧栏是 `ZStack` 的**直接子节点**（浮层），内容区左边距 = 侧栏当前宽度；
 * 两者读同一个弹簧值，所以动画过程中不会留缝（见 `sidebar_rail.cj`）。
 */
package seline_read

import std.core.sleep
import std.math.*
import chui.*
import seline_ui.*

/** 标题栏高度（窗口按钮、居中搜索框都按它对齐）。 */
let TITLE_BAR_HEIGHT: Float32 = 52.0

/** 整个窗口的树。 */
func appShell(state: AppState): Unit {
    let palette = selineTheme().palette
    ZStack {
    VStack(spacing: vp(0.0)) {
        // 主题同步探针必须是整棵树最先绘制的节点：
        // 顶栏/侧栏/内容都按它对齐后的全局配色画，主题过渡两遍才各自正确。
        ThemeSyncProbe()
        titleBar(state)
        ZStack {

            // 内容区：左边距 = 侧栏当前宽度（与侧栏同一帧、同一表达式）
            SelineContentPanel(palette.surface, 14.0, true) {
                pageFor(state)
            }.padding(railVisibleWidth(), 0.0, 0.0, 0.0)
                .fillWidth().fillHeight()
            // 侧栏浮层：直接作为 ZStack 子节点，位置由父容器给（x=0）
            sidebarTabs(state)

            // 下载版本菜单：浮在最上层，点菜单外/切换页面自动关闭
            // 登录弹窗（最上层，遮罩会吞掉底层点击）
            if (state.loginDialogOpen.value) {
                loginDialogPanel(state)
            }
            // 底部右侧 toast：所有"横幅式"报错都走这里
            ErrorToastOverlay(state)
            if (state.downloadMenuOpen.value || state.downloadMenuClosing.value) {
                SelineContextMenuOverlay(state.downloadMenuItems(),
                    state.downloadMenuX(), state.downloadMenuY(),
                    {=> state.closeDownloadMenu()}, width: 250.0,
                    closing: state.downloadMenuClosing.value,
                    spring: state.downloadMenuSpring,
                    // 支点 = 「下载」按钮的右下角：菜单从按钮处展开（不是从左上角）
                    pivotX: state.downloadAnchor.x + state.downloadAnchor.w,
                    pivotY: state.downloadAnchor.y + state.downloadAnchor.h + 6.0)
            }

        }.alignment(Alignment.TopLeading)
            // `.flex()` 只声明"吃掉剩余高度"，不污染测量值
            .fillWidth().flex()
    }.fillWidth().fillHeight()
    // 全窗口覆盖：边缘 6px 内按下进入缩放，其余事件下传（不挡标题栏/按钮）
    WindowResizeEdges(state)
    }.alignment(Alignment.TopLeading).fillWidth().fillHeight()
}

/** 边缘缩放的感应带宽（逻辑像素）。 */
private let RESIZE_EDGE_BAND: Float32 = 6.0

/** 最近一次布局得到的窗口逻辑尺寸/当前光标模式（0 默认，1 水平，2 垂直）。 */
private var resizeWindowWidth: Float32 = 0.0
private var resizeWindowHeight: Float32 = 0.0
private var resizeCursorMode: Int64 = 0
private var resizeDisplayScale: Float32 = 1.0

/* 命中边/角的标识（只是本地常量，和 Win32 无关）。 */
private let EDGE_LEFT: Int64 = 1
private let EDGE_RIGHT: Int64 = 2
private let EDGE_TOP: Int64 = 3
private let EDGE_BOTTOM: Int64 = 4
private let EDGE_TOPLEFT: Int64 = 5
private let EDGE_TOPRIGHT: Int64 = 6
private let EDGE_BOTTOMLEFT: Int64 = 7
private let EDGE_BOTTOMRIGHT: Int64 = 8
/**
 * 无边框窗口的边缘缩放。
 *
 * frameless 窗口没有系统边框，也没有缩放光标，这里自己补：
 *   1. 在窗口边缘 6 个逻辑像素内按下 → 进入缩放态，起 12ms 轮询循环跟踪鼠标；
 *   2. 拖动期间只改窗口**尺寸**（左上角固定，不动位置）；
 *   3. 悬停在边缘时用 chui 的 `ctx.claimHover` 申请缩放光标（SDL 光标）；
 *   4. 非边缘区域返回 false，事件继续下传，不挡标题栏拖动和普通点击。
 */
class WindowResizeEdges <: Widget {
    private let state: AppState
    private var frame = Rect.zero()
    private let edgeSize: Float32 = 6.0


    init(state: AppState) {
        this.state = state
        emit(this)
    }

    public func isFlexible(): Bool {
        true
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        // 用视口逻辑尺寸（= 整个窗口），不用 rect：ZStack 在测量阶段可能给它
        // 一个更小的临时高度（例如扣掉标题栏的 768），按矩形算会误判边缘。
        resizeWindowWidth = ctx.viewportWidth
        resizeWindowHeight = ctx.viewportHeight
        resizeDisplayScale = if (ctx.displayScale > Float32(0.1)) { ctx.displayScale } else { Float32(1.0) }
    }

    public func draw(ctx: UiContext): Unit {
        syncWindowResizeCursor(state, ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseMove(_, _) =>
                syncWindowResizeCursor(state, ctx)
                false
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                match (hitTest(x, y)) {
                    case Some(code) =>
                        startResize(ctx, code)
                        true
                    case None => false
                }
            case _ => false
        }
    }

    /** 开始一次缩放：轮询鼠标位移直到松开；窗口位置保持不变。 */
    private func startResize(ctx: UiContext, code: Int64): Unit {
        let app = state.window()
        let global = Mouse.globalState()
        let startGlobalX = global.x
        let startGlobalY = global.y
        let startPos = app.windowPosition()
        let startPosX = startPos.x
        let startPosY = startPos.y
        let startWidth = ctx.viewportWidth
        let startHeight = ctx.viewportHeight
        let scale = if (ctx.displayScale > Float32(0.1)) {
            ctx.displayScale
        } else {
            Float32(1.0)
        }
        let left = code == EDGE_LEFT || code == EDGE_TOPLEFT || code == EDGE_BOTTOMLEFT
        let right = code == EDGE_RIGHT || code == EDGE_TOPRIGHT || code == EDGE_BOTTOMRIGHT
        let top = code == EDGE_TOP || code == EDGE_TOPLEFT || code == EDGE_TOPRIGHT
        let bottom = code == EDGE_BOTTOM || code == EDGE_BOTTOMLEFT || code == EDGE_BOTTOMRIGHT
        let _ = spawn {=>
            while (Mouse.state().left) {
                let cur = Mouse.globalState()
                let dLogX = (cur.x - startGlobalX) / scale
                let dLogY = (cur.y - startGlobalY) / scale
                var newW = startWidth
                var newH = startHeight
                if (left) { newW = startWidth - dLogX }
                if (right) { newW = startWidth + dLogX }
                if (top) { newH = startHeight - dLogY }
                if (bottom) { newH = startHeight + dLogY }
                if (newW < 900.0) { newW = 900.0 }
                if (newH < 600.0) { newH = 600.0 }
                var newPosX = startPosX
                var newPosY = startPosY
                if (left) { newPosX = startPosX + Int32(dLogX * scale) }
                if (top) { newPosY = startPosY + Int32(dLogY * scale) }
                let wInt = Int32(newW)
                let hInt = Int32(newH)
                let px = newPosX
                let py = newPosY
                let movePos = left || top
                app.postToUi({=>
                    if (movePos) {
                        app.setWindowPosition(px, py)
                    }
                    app.setWindowSize(wInt, hInt)
                })
                sleep(12 * Duration.millisecond)
            }
        }
    }

    /** 返回命中的边/角；不在边缘附近返回 None。 */
    private func hitTest(x: Float32, y: Float32): ?Int64 {
        if (frame.w <= 0.0 || frame.h <= 0.0) {
            return None
        }
        let nearLeft = x - frame.x <= edgeSize
        let nearRight = frame.right() - x <= edgeSize
        let nearTop = y - frame.y <= edgeSize
        let nearBottom = frame.bottom() - y <= edgeSize
        if (nearLeft && nearTop) { return Some(EDGE_TOPLEFT) }
        if (nearRight && nearTop) { return Some(EDGE_TOPRIGHT) }
        if (nearLeft && nearBottom) { return Some(EDGE_BOTTOMLEFT) }
        if (nearRight && nearBottom) { return Some(EDGE_BOTTOMRIGHT) }
        if (nearLeft) { return Some(EDGE_LEFT) }
        if (nearRight) { return Some(EDGE_RIGHT) }
        if (nearTop) { return Some(EDGE_TOP) }
        if (nearBottom) { return Some(EDGE_BOTTOM) }
        None
    }
}





/**
 * 自绘标题栏：底层可拖动 surface + 居中搜索框 + 左标题/右窗口按钮。
 *
 * 三层 `ZStack`：底层背景，中层居中搜索框（`SelineCenteredLeaf` 拒绝拉伸，
 * 父容器才会按内容尺寸把它摆在正中），顶层左右两端。
 */
func titleBar(state: AppState): Unit {
    ZStack {
        SelineTitleBarSurface(state.window())
        SelineCenteredLeaf(SelineTextField(state.searchText.value,
            {text =>
                state.searchText.value = text
                state.onSearchTextChanged(text)
            },
            placeholder: "搜索书名、作者、关键词…", glyph: "search", height: 36.0,
            paste: true, onSubmit: {=> state.submitSearch()}).width(520.0))
        HStack(spacing: vp(SELINE_SPACE_MD)) {
            SelineWindowTitle("Seline Read", glyph: "cloud", image: state.iconPath())
            Spacer()
            SelineCaptionControls(state.window(), barHeight: TITLE_BAR_HEIGHT)
        }.hug().fillWidth()
            .padding(vp(SELINE_PAGE_MARGIN), vp(0.0), vp(10.0), vp(0.0))
    }.height(TITLE_BAR_HEIGHT)
}


/** 按当前状态分派页面：详情页（二级）优先于一级页签。 */
func pageFor(state: AppState): Unit {
    if (state.detailOpen.value) {
        detailPage(state)
        return
    }
    if (state.booklistOpen.value) {
        booklistDetailPage(state)
        return
    }
    // 用 if 而不是 `match` + 常量：`case 常量名` 在这里是绑定模式，会匹配一切。
    let tab = state.tab.value
    if (tab == TAB_FAVORITES) {
        favoritesPage(state)
        return
    }
    if (tab == TAB_BOOKLISTS) {
        booklistsPage(state)
        return
    }
    if (tab == TAB_DOWNLOADS) {
        downloadsPage(state)
        return
    }
    if (tab == TAB_SETTINGS) {
        settingsPage(state)
        return
    }
    if (tab == TAB_ACCOUNT) {
        accountPage(state)
        return
    }
    // 搜索不再是独立页签：提交搜索后结果就显示在「热门」页签里
    if (!state.lastKeyword.value.isEmpty()) {
        searchPage(state)
    } else {
        homePage(state)
    }
}
/**
 * 主题同步探针：放在根 `ZStack` 的**第一个**子节点。
 *
 * chui 的主题过渡会把同一棵控件树分两遍画（`ctx.theme` 依次为旧/新主题）。
 * 我们的控件读全局 `selineTheme()`，所以在每一遍开始前先把全局主题对齐到
 * `ctx.theme`；因为 `ZStack` 按子节点顺序绘制，探针先画，后面所有内容就是
 * 该遍对应的配色 —— 圆形揭示时颜色才会跟着辐射边界走。
 */
class ThemeSyncProbe <: Widget {
    init() {
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(0.0, 0.0)
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(ctx: UiContext): Unit {
        setSelineTheme(selineThemeForChuiTheme(ctx.theme))
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func isFlexible(): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }
}
/**
 * 右下角错误 toast。
 *
 * 之前错误是页面里的一条横幅（红字条），现在统一改成"浮在右下角的提示"：
 * 从底部滑入 + 淡入，3.2 秒后自动消失；不打断操作（`handle` 永远返回 false）。
 */
class ErrorToastOverlay <: Widget {
    private let state: AppState
    private var frame = Rect.zero()

    init(state: AppState) {
        this.state = state
        emit(this)
    }

    public func isFlexible(): Bool {
        true
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        // 用视口逻辑尺寸（= 整个窗口），不用 rect：ZStack 在测量阶段可能给它
        // 一个更小的临时高度（例如扣掉标题栏的 768），按矩形算会误判边缘。
        resizeWindowWidth = ctx.viewportWidth
        resizeWindowHeight = ctx.viewportHeight
        resizeDisplayScale = if (ctx.displayScale > Float32(0.1)) { ctx.displayScale } else { Float32(1.0) }
    }

    public func draw(ctx: UiContext): Unit {
        let text = state.toastText.value
        let target: Float32 = if (text.isEmpty()) { 0.0 } else { 1.0 }
        let progress = state.toastSpring.animate(ctx, target: target)
        if (text.isEmpty() && progress < 0.02) {
            return
        }
        let theme = selineTheme()
        let palette = theme.palette
        let viewportW = ctx.viewportWidth
        let viewportH = ctx.viewportHeight
        let margin: Float32 = 18.0
        let maxWidth: Float32 = 380.0
        let lines = wrapTextByWidth(ctx, text, maxWidth - 52.0, theme.fontLabel, theme.fontFamily)
        let lineHeight: Float32 = theme.fontLabel + 5.0
        let textHeight: Float32 = lineHeight * Float32(lines.size)
        let boxH: Float32 = textHeight + 24.0
        let boxW: Float32 = maxWidth
        let alpha = clamp01(progress)
        let one: Float32 = 1.0
        let offset: Float32 = (one - alpha) * 16.0
        let box = Rect(viewportW - margin - boxW, viewportH - margin - boxH + offset, boxW, boxH)
        let a = Int64(Float64(alpha) * 255.0)
        paintCard(ctx.renderer, box, palette.surfaceRaised.withAlpha(a), 12.0,
            border: palette.borderStrong.withAlpha(a),
            shadow: palette.shadow.withAlpha(Int64(Float32(palette.shadow.a) * alpha)),
            shadowSpread: 16.0, shadowOffsetY: 3.0)
        // 图标/颜色跟随 toast 语义：成功=绿勾，错误=红叹号，信息=蓝叹号
        let kind = state.toastKind.value
        let glyph = match (kind) {
            case ToastKind.Success => "check"
            case _ => "warn"
        }
        let tone = match (kind) {
            case ToastKind.Success => palette.success
            case ToastKind.Error => palette.danger
            case ToastKind.Info => palette.info
        }
        drawGlyph(ctx.renderer, glyph,
            Rect(box.x + 14.0, box.y + (box.h - 16.0) * 0.5, 16.0, 16.0),
            tone.withAlpha(a), 1.0)
        var y = box.y + 12.0
        for (line in lines) {
            paintText(ctx.renderer, line,
                Rect(box.x + 40.0, y, box.w - 52.0, lineHeight),
                palette.text.withAlpha(a), theme.fontLabel, family: theme.fontFamily)
            y += lineHeight
        }
        if (progress > 0.0 && progress < 1.0) {
            ctx.requestFrame()
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }
}
/** 按当前鼠标位置（ctx 坐标，事件驱动，和 SDL 输入一致）同步边缘光标。 */
func syncWindowResizeCursor(state: AppState, ctx: UiContext): Unit {
    if (resizeWindowWidth <= Float32(1.0) || resizeWindowHeight <= Float32(1.0)) {
        return
    }
    let mouseX = ctx.mouseX
    let mouseY = ctx.mouseY
    let inside = mouseX >= Float32(0.0) && mouseX <= resizeWindowWidth &&
        mouseY >= Float32(0.0) && mouseY <= resizeWindowHeight
    var mode: Int64 = 0
    if (inside) {
        let nearLeft = mouseX <= RESIZE_EDGE_BAND
        let nearRight = resizeWindowWidth - mouseX <= RESIZE_EDGE_BAND
        let nearTop = mouseY <= RESIZE_EDGE_BAND
        let nearBottom = resizeWindowHeight - mouseY <= RESIZE_EDGE_BAND
        if (nearLeft || nearRight) {
            mode = 1
        } else if (nearTop || nearBottom) {
            mode = 2
        }
    }
    if (mode == resizeCursorMode) {
        return
    }
    resizeCursorMode = mode
    let app = state.window()
    if (mode == 1) {
        app.useBaseCursor(SystemCursor.EwResize)
    } else if (mode == 2) {
        app.useBaseCursor(SystemCursor.NsResize)
    } else {
        app.useBaseCursor(SystemCursor.Default)
    }
}
/**
 * 后台轮询全局鼠标位置来切换边缘缩放光标。
 *
 * 不用 `Mouse.state()`：SDL 只在窗口持有鼠标焦点时更新它，窗口未聚焦时会给出
 * 陈旧坐标。`Mouse.globalState()` 是桌面坐标，配合窗口位置/DPI 缩放换算成
 * 窗口内逻辑坐标，任何情况下都准。切换用 `DesktopApp.useBaseCursor`（SDL 光标）。
 */
func startResizeCursorLoop(state: AppState): Unit {
    let app = state.window()
    let _ = spawn {=>
        while (true) {
            sleep(30 * Duration.millisecond)
            if (resizeWindowWidth <= Float32(1.0) || resizeWindowHeight <= Float32(1.0)) {
                continue
            }
            let scale = resizeDisplayScale
            let windowPos = app.windowPosition()
            let global = Mouse.globalState()
            let lx = (global.x - Float32(windowPos.x)) / scale
            let ly = (global.y - Float32(windowPos.y)) / scale
            let inside = lx >= Float32(0.0) && lx <= resizeWindowWidth &&
                ly >= Float32(0.0) && ly <= resizeWindowHeight
            var mode: Int64 = 0
            if (inside) {
                let nearLeft = lx <= RESIZE_EDGE_BAND
                let nearRight = resizeWindowWidth - lx <= RESIZE_EDGE_BAND
                let nearTop = ly <= RESIZE_EDGE_BAND
                let nearBottom = resizeWindowHeight - ly <= RESIZE_EDGE_BAND
                if (nearLeft || nearRight) {
                    mode = 1
                } else if (nearTop || nearBottom) {
                    mode = 2
                }
            }
            if (mode == resizeCursorMode) {
                continue
            }
            resizeCursorMode = mode

            let target = mode
            app.postToUi({=>
                if (target == 1) {
                    app.useBaseCursor(SystemCursor.EwResize)
                } else if (target == 2) {
                    app.useBaseCursor(SystemCursor.NsResize)
                } else {
                    app.useBaseCursor(SystemCursor.Default)
                }
            })
        }
    }
}