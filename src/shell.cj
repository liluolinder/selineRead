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
import seline_read.platform.*

/** 标题栏高度（窗口按钮、居中搜索框都按它对齐）。 */
let TITLE_BAR_HEIGHT: Float32 = 52.0

/** 整个窗口的树。 */
func appShell(state: AppState): Unit {
    let palette = selineTheme().palette
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
            // 无边框窗口的边缘缩放：只吃「窗口边缘 6px 内」的按下，其余事件下传
            WindowResizeEdges(state)

        }.alignment(Alignment.TopLeading)
            // `.flex()` 只声明"吃掉剩余高度"，不污染测量值
            .fillWidth().flex()
    }.fillWidth().fillHeight()
}

/**
 * 无边框窗口的边缘缩放。
 *
 * frameless 窗口没有系统边框、也没有缩放光标，这里自己实现：
 *   1. 在窗口边缘 6 个逻辑像素内按下 → 记录起始尺寸/光标；
 *   2. 起一个轮询循环（约 12ms）跟踪鼠标：按住期间按位移算新尺寸并调
 *      `setWindowSize`（拖左/上边时同时移动窗口，保持被拖的边跟手）；
 *      松开鼠标结束。
 *   3. 非边缘区域返回 false，事件继续下传，不挡普通点击。
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

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(_: UiContext): Unit {}

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
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

    /** 开始一次缩放：轮询鼠标位移直到松开。 */
    private func startResize(ctx: UiContext, code: Int64): Unit {
        let app = state.window()
        let pos = app.windowPosition()
        let global = Mouse.globalState()
        let startGlobalX = global.x
        let startGlobalY = global.y
        let startPosX = pos.x
        let startPosY = pos.y
        let startWidth = ctx.viewportWidth
        let startHeight = ctx.viewportHeight
        let scale = if (ctx.displayScale > Float32(0.1)) {
            ctx.displayScale
        } else {
            Float32(1.0)
        }
        let left = code == HT_LEFT || code == HT_TOPLEFT || code == HT_BOTTOMLEFT
        let right = code == HT_RIGHT || code == HT_TOPRIGHT || code == HT_BOTTOMRIGHT
        let top = code == HT_TOP || code == HT_TOPLEFT || code == HT_TOPRIGHT
        let bottom = code == HT_BOTTOM || code == HT_BOTTOMLEFT || code == HT_BOTTOMRIGHT
        let _ = spawn {=>
            while (Mouse.state().left) {
                let cur = Mouse.globalState()
                let dPhysX = cur.x - startGlobalX
                let dPhysY = cur.y - startGlobalY
                var newW = startWidth
                var newH = startHeight
                if (left) { newW = startWidth - dPhysX / scale }
                if (right) { newW = startWidth + dPhysX / scale }
                if (top) { newH = startHeight - dPhysY / scale }
                if (bottom) { newH = startHeight + dPhysY / scale }
                if (newW < 900.0) { newW = 900.0 }
                if (newH < 600.0) { newH = 600.0 }
                var newPosX = startPosX
                var newPosY = startPosY
                if (left) { newPosX = startPosX + Int32(dPhysX) }
                if (top) { newPosY = startPosY + Int32(dPhysY) }
                let movePos = newPosX != startPosX || newPosY != startPosY
                let wInt = Int32(newW)
                let hInt = Int32(newH)
                let px = newPosX
                let py = newPosY
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
        if (nearLeft && nearTop) { return Some(HT_TOPLEFT) }
        if (nearRight && nearTop) { return Some(HT_TOPRIGHT) }
        if (nearLeft && nearBottom) { return Some(HT_BOTTOMLEFT) }
        if (nearRight && nearBottom) { return Some(HT_BOTTOMRIGHT) }
        if (nearLeft) { return Some(HT_LEFT) }
        if (nearRight) { return Some(HT_RIGHT) }
        if (nearTop) { return Some(HT_TOP) }
        if (nearBottom) { return Some(HT_BOTTOM) }
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

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
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