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

import std.math.*
import chui.*
import seline_ui.*

/** 标题栏高度（窗口按钮、居中搜索框都按它对齐）。 */
let TITLE_BAR_HEIGHT: Float32 = 52.0

/** 整个窗口的树。 */
func appShell(state: AppState): Unit {
    let palette = selineTheme().palette
    VStack(spacing: vp(0.0)) {
        titleBar(state)
        ZStack {
            // 内容区：左边距 = 侧栏当前宽度（与侧栏同一帧、同一表达式）
            SelineContentPanel(palette.surface, 14.0, true) {
                pageFor(state)
            }.padding(railVisibleWidth(), 0.0, 0.0, 0.0)
                .fillWidth().fillHeight()
            // 侧栏浮层：直接作为 ZStack 子节点，位置由父容器给（x=0）
            sidebarTabs(state)
            // 主题切换的辐射遮罩：盖住整窗，画一个从按钮位置扩张的圆
            if (state.themeRevealing.value) {
                ThemeRevealOverlay(state)
            }
            // 下载版本菜单：浮在最上层，点菜单外/切换页面自动关闭
            if (state.downloadMenuOpen.value || state.downloadMenuClosing.value) {
                SelineContextMenuOverlay(state.downloadMenuItems(),
                    state.downloadMenuX(), state.downloadMenuY(),
                    {=> state.closeDownloadMenu()}, width: 250.0,
                    closing: state.downloadMenuClosing.value)
            }
        }.alignment(Alignment.TopLeading)
            // `.flex()` 只声明"吃掉剩余高度"，不污染测量值
            .fillWidth().flex()
    }.background(palette.surfaceSunken).fillWidth().fillHeight()
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
    // 搜索不再是独立页签：提交搜索后结果就显示在「热门」页签里
    if (!state.lastKeyword.value.isEmpty()) {
        searchPage(state)
    } else {
        homePage(state)
    }
}
/**
 * 主题切换的「往外辐射」遮罩。
 *
 * chui 只支持矩形裁剪，做不出真正的圆形揭示，所以这里反过来画：
 * 在旧主题的界面上盖一个以按钮为圆心、半径逐渐变大的**新主题底色圆**，
 * 圆铺满整窗时再真正切换主题（`applyThemeSwitch`）。视觉上就是新主题从按钮处扩散开。
 */
class ThemeRevealOverlay <: Widget {
    private let state: AppState
    private var frame = Rect.zero()

    init(state: AppState) {
        this.state = state
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        // 目标主题的底色（还没切换，所以按 darkMode 取反）
        let target = if (state.darkMode.value) {
            SelineTheme.light()
        } else {
            SelineTheme.dark()
        }
        let originX = state.themeRevealOriginX()
        let originY = state.themeRevealOriginY()
        // 半径要盖到最远的角
        let dx = max(max(originX - frame.x, frame.right() - originX), 0.0)
        let dy = max(max(originY - frame.y, frame.bottom() - originY), 0.0)
        let maxRadius = Float32(sqrt(Float64(dx * dx + dy * dy)))
        // 约 420ms 的扩张（按帧 delta 推进，不依赖 State 弹簧）
        var progress = state.themeReveal.value + Float32(ctx.frame.deltaMs) / 420.0
        if (progress >= 1.0) {
            progress = 1.0
        }
        if (progress != state.themeReveal.value) {
            state.themeReveal.value = progress
        }
        let eased = 1.0 - (1.0 - progress) * (1.0 - progress)
        let radius = maxRadius * eased
        // 用一圈同心圆近似"实心圆"（renderer 没有圆填充，只有圆角矩形）
        paintSurface(ctx.renderer,
            Rect(originX - radius, originY - radius, radius * 2.0, radius * 2.0),
            target.palette.window, radius)
        if (progress >= 1.0) {
            state.applyThemeSwitch()
        } else {
            ctx.requestFrame()
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        true
    }
}