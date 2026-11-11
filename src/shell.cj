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
            // 主题同步探针（必须在最前面：先对齐全局配色再画内容）
            ThemeSyncProbe()
            // 内容区：左边距 = 侧栏当前宽度（与侧栏同一帧、同一表达式）
            SelineContentPanel(palette.surface, 14.0, true) {
                pageFor(state)
            }.padding(railVisibleWidth(), 0.0, 0.0, 0.0)
                .fillWidth().fillHeight()
            // 侧栏浮层：直接作为 ZStack 子节点，位置由父容器给（x=0）
            sidebarTabs(state)

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
    }.fillWidth().fillHeight()
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