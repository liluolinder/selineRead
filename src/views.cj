package SelineRead

import chui.*
import std.collection.ArrayList
import zlibraryAPI4CJ.common.*
import zlibraryAPI4CJ.dataModel.*

// =====================================================================
// 主题色：全部令牌集中在 theme.cj（照 SelineDebugToolBox 模式），
// 视图只引用语义名，不出现裸色值。
// =====================================================================

let SIDEBAR_WIDE: Float32 = 190.0
let SIDEBAR_RAIL: Float32 = 64.0

// =====================================================================
// 根布局：左侧可展开/收起侧边栏 + 内容区（参考 SelineDebugToolBox）
// =====================================================================

func rootView(app: DesktopApp, state: AppState) {
    // 详情页只在「打开它的页签」下显示：切到其他页签再切回仍保留详情状态
    let inDetail = detailVisibleNow(state)
    ZStack {
        HStack(spacing: 0.vp) {
            sidePanel(state)
            VStack(spacing: 0.vp) {
                titleBar(app, state)
                // 详情页可见时整区切换为详情（各分支类型不同，包一层容器统一）
                VStack(spacing: 0.vp) {
                    if (inDetail) {
                        detailView(app, state)
                    } else if (state.currentTab.value == 0) {
                        homeView(app, state)
                    } else if (state.currentTab.value == 1) {
                        bookshelfView(app, state)
                    } else if (state.currentTab.value == 2) {
                        downloadsView(app, state)
                    } else {
                        homeView(app, state)
                    }
                }.fillHeight().flex()
            }.padding(0.vp, 0.vp, 12.vp, 0.vp).fillHeight().flex()
        }
        accountModal(app, state)
        settingModal(state)
        aboutModal(state)
        cancelDownloadModal(state)
        // 右下角 toast 层：不占布局、不拦截事件，始终位于最上层
        ToastLayer(state.toaster)
    }
}

// =====================================================================
// 侧边栏：品牌位 + 页签（首页/书架）+ 底部（账号/设置/关于/收起开关）
// 宽窄切换带宽度过渡动画，实现方式与 SelineDebugToolBox 相同
// =====================================================================

func sidePanel(state: AppState) {
    let progress = state.sidebarAnim.value
    let wide = progress >= 0.5
    let panelWidth = SIDEBAR_RAIL + (SIDEBAR_WIDE - SIDEBAR_RAIL) * progress
    FrameHandler(onFrame: { info => tickSidebarAnim(state, info.deltaMs) },
        keepsAlive: { => sidebarAnimating(state) }) {
        VStack {
            brandSlot(state, wide)
            navIconSlot(state, 0, "home", "首页", wide)
            navIconSlot(state, 1, "bookshelf", "收藏", wide)
            navIconSlot(state, 2, "download", "下载", wide)
            Spacer()
            actionIconSlot(state, "person", "账号", wide, {=> state.showAccount.value = true})
            // 主题切换按钮：深色/浅色切换
            themeToggleSlot(state, wide)
            actionIconSlot(state, "settings", "设置", wide, {=> state.showSetting.value = true})
            actionIconSlot(state, "about", "关于", wide, {=> state.showAbout.value = true})
            collapseSlot(state, wide)
        }.spacing(8.0).padding(12.0, 12.0).width(panelWidth).fillHeight()
            .background(sidebarBg(state.themeMode.value), 0.0)
    }
}

/** 侧栏宽窄过渡：每帧按 delta 时间趋近目标（0=收起、1=展开），指数缓出观感。 */
func tickSidebarAnim(state: AppState, deltaMs: UInt64) {
    let target: Float32 = if (state.sidebarExpanded.value) { 1.0 } else { 0.0 }
    let current = state.sidebarAnim.value
    let diff = target - current
    let ad = if (diff < 0.0) { -diff } else { diff }
    // 收敛后必须停止写状态：每帧的 State 写入都会递增状态代数、强制下一帧
    // 全量重绘——无条件写入曾导致空闲屏幕永久重绘循环（界面渐冻的根因）
    if (ad <= 0.001) {
        if (current != target) {
            state.sidebarAnim.value = target // 吸附到目标值，此写只触发最后一帧
        }
        return
    }
    let t = min(Float32(1.0), Float32(deltaMs) / Float32(40.0))
    state.sidebarAnim.value = current + diff * Float32(0.35) * t
}

/** 动画未收敛时返回 true，令 FrameHandler 保持重绘。 */
func sidebarAnimating(state: AppState): Bool {
    let target: Float32 = if (state.sidebarExpanded.value) { 1.0 } else { 0.0 }
    let diff = state.sidebarAnim.value - target
    if (diff < 0.0) {
        -diff > 0.001
    } else {
        diff > 0.001
    }
}

/** 宽栏内容揭示度：progress 0.42→0.78 平滑升至 1（smoothstep）。 */
func sidebarReveal(state: AppState): Float32 {
    let p = state.sidebarAnim.value
    let t: Float32 = if (p <= Float32(0.42)) {
        Float32(0.0)
    } else if (p >= Float32(0.78)) {
        Float32(1.0)
    } else {
        (p - Float32(0.42)) / Float32(0.36)
    }
    t * t * (Float32(3.0) - Float32(2.0) * t)
}

/** 固定 40 高槽位：宽/窄形态共用同一纵向位置与高度（与参考项目一致，
 * 窄栏对称靠几何：rail 64 = 40 方块 + 左右各 12 padding，方块 hug 恰好填满）。 */
func sideSlot(content: () -> Unit) {
    HStack {
        content()
    }.mainAxisAlignment(MainAxisAlignment.Center).crossAxisAlignment(CrossAxisAlignment.Center).fillWidth().height(40.0)
}

/** 图标路径：取 assets/icon/{name}.png（非激活）或 {name}_active.png（激活）。 */
func iconPath(name: String, active: Bool, mode: Int64): String {
    let themeSuffix = if (mode == 2) { "_light" } else { "" }
    if (active) { "assets/icon/${name}_active${themeSuffix}.png" } else { "assets/icon/${name}${themeSuffix}.png" }
}

/** 固定尺寸图标 ImageView（同时设宽高，避免 fill 可用宽度）。 */
func sidebarIcon(path: String, size: Float32) {
    let len = Length(size, LengthUnit.Px)
    ImageView(path, preferredWidth: Some(len), preferredHeight: len).fit(ImageFit.Contain)
}

/** 侧边栏统一按钮：宽栏=图标+文字，窄栏=仅图标居中+Tooltip。
 * 图标尺寸统一 22×22，切换时只有文字显隐，图标位置不动。 */
func sidebarButton(state: AppState, iconName: String, title: String, active: Bool, wide: Bool, action: () -> Unit) {
    let bg = if (active) { BRAND_SOFT_BG } else { CLEAR_SURFACE }
    let btn = Button(onClick: {=> action()},
        style: Some(SurfaceStyle(bg, radius: 9.0))) {
        if (wide) {
            let a = Int64(255.0 * sidebarReveal(state))
            HStack(spacing: 10.0.vp) {
                sidebarIcon(iconPath(iconName, active, state.themeMode.value), 22.0)
                if (active) {
                    Label(title).bold().fontSize(16.0).foregroundColor(BRAND_COLOR.withAlpha(a))
                } else {
                    Label(title).bold().fontSize(16.0).foregroundColor(sidebarText(state.themeMode.value).withAlpha(a))
                }
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
        } else {
            HStack {
                sidebarIcon(iconPath(iconName, active, state.themeMode.value), 22.0)
            }.mainAxisAlignment(MainAxisAlignment.Center).crossAxisAlignment(CrossAxisAlignment.Center).hug()
        }
    }.fillWidth().height(40.0)
    if (wide) { btn } else { Tooltip(text: title) { btn } }
}

/** 品牌槽：图标+应用名，宽栏和窄栏共用同一图标尺寸 22×22。 */
func brandSlot(state: AppState, wide: Bool) {
    sideSlot {
        if (wide) {
            let a = Int64(255.0 * sidebarReveal(state))
            Button(onClick: {=>}, style: Some(SurfaceStyle(CLEAR_SURFACE, radius: 9.0))) {
                HStack(spacing: 10.0.vp) {
                    sidebarIcon(if (state.themeMode.value == 2) { "assets/icon_brand_light.png" } else { "assets/icon_brand.png" }, 22.0)
                    Label("SelineRead").bold().fontSize(16.0).foregroundColor(sidebarText(state.themeMode.value).withAlpha(a))
                }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            }.fillWidth().height(40.0)
        } else {
            HStack {
                sidebarIcon(if (state.themeMode.value == 2) { "assets/icon_brand_light.png" } else { "assets/icon_brand.png" }, 22.0)
            }.mainAxisAlignment(MainAxisAlignment.Center).crossAxisAlignment(CrossAxisAlignment.Center).width(40.0).height(40.0)
        }
    }
}

/** 页签槽。 */
func navIconSlot(state: AppState, page: Int64, iconName: String, title: String, wide: Bool) {
    sideSlot {
        sidebarButton(state, iconName, title, state.currentTab.value == page, wide, {=> state.currentTab.value = page})
    }
}

/** 底部动作槽。 */
func actionIconSlot(state: AppState, iconName: String, title: String, wide: Bool, action: () -> Unit) {
    sideSlot {
        sidebarButton(state, iconName, title, false, wide, {=> action()})
    }
}

/** 主题切换槽：深色/浅色切换按钮。点击时从按钮中心圆形扩散切换主题。 */
func themeToggleSlot(state: AppState, wide: Bool) {
    let isDark = state.themeMode.value != 2
    let icon = if (isDark) { "sun" } else { "moon" }
    let label = if (isDark) { "浅色" } else { "深色" }
    // 按钮中心原点：侧栏展开时约 (95, 600)，收起时约 (32, 600)
    let originX = if (wide) { 95.0 } else { 32.0 }
    sideSlot {
        sidebarButton(state, icon, label, false, wide, {=>
            let newMode = if (isDark) { Int64(2) } else { Int64(1) }
            state.themeMode.value = newMode
            state.themeOriginX.value = Float32(originX)
            state.themeOriginY.value = Float32(600.0)
            state.applyTheme(newMode)
        })
    }
}

/** 底部折叠槽。 */
func collapseSlot(state: AppState, wide: Bool) {
    sideSlot {
        if (wide) {
            let a = Int64(255.0 * sidebarReveal(state))
            Button(onClick: {=> state.sidebarExpanded.value = false},
                style: Some(ACTION_BUTTON_STYLE)) {
                HStack(spacing: 10.0.vp) {
                    sidebarIcon(iconPath("chevron_left", false, state.themeMode.value), 22.0)
                    Label("收起").fontSize(16.0).foregroundColor(sidebarText(state.themeMode.value).withAlpha(a))
                }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            }.fillWidth().height(40.0)
        } else {
            Tooltip(text: "展开侧栏") {
                Button(onClick: {=> state.sidebarExpanded.value = true},
                    style: Some(RAIL_BUTTON_STYLE)) {
                    HStack {
                        sidebarIcon(iconPath("chevron_right", false, state.themeMode.value), 22.0)
                    }.mainAxisAlignment(MainAxisAlignment.Center).crossAxisAlignment(CrossAxisAlignment.Center).hug()
                }.fillWidth().height(40.0)
            }
        }
    }
}

// =====================================================================
// 首页：搜索 + 瀑布/列表切换（仿 ZlibHome）
// =====================================================================

func homeView(app: DesktopApp, state: AppState) {
    // 搜索行已上移到标题栏，这里只留内容区
    VStack(spacing: 12.0.vp) {
        // homeContent 各分支返回不同控件类型（推断为 Any），包一层容器统一；
        // 右侧再加 10 缩进与滚动条拉开距离
        VStack(spacing: 0.vp) {
            homeContent(app, state)
        }.fillHeight().flex().padding(0.0, 0.0, 10.0, 0.0)
    }
    // 外层：顺序为 (left, top, right, bottom) —— 左/上/下 14，右 4，
    // 滚动条贴近窗口右边框
    .padding(14.0, 14.0, 4.0, 14.0).fillHeight().flex()
}

/** 标题栏左段：卡片/列表切换（靠左独立，不参与居中）。 */
func homeSwitcher(state: AppState) {
    SegmentedControl(["卡片", "列表"], state.showType)
}

/** 标题栏书架段：卡片/列表切换（与首页各自独立的状态）。 */
func shelfSwitcher(state: AppState) {
    SegmentedControl(["卡片", "列表"], state.shelfShowType)
}

/** 标题栏中段：搜索框 + 搜索按钮（由两侧拖拽区夹持居中）。
 * 搜索态返回推荐改为清空搜索框触发（见 pollSearchClear），不再放按钮。 */
func homeSearchBar(app: DesktopApp, state: AppState) {
    HStack(spacing: 10.0.vp) {
        TextField(state.searchInput, placeholder: "搜索书名、作者...")
            .onSubmit({=> doSearch(app, state)}).width(320.0)
        Button("搜索", {=> doSearch(app, state)}, role: ButtonRole.Primary)
    }.hug().crossAxisAlignment(CrossAxisAlignment.Center)
}

func homeContent(app: DesktopApp, state: AppState) {
    let books = if (state.isSearchMode.value) { state.searchBooks.value } else { state.recommendBooks.value }
    if (state.homeSkeletonOn.value || (state.isHomeLoading.value && books.isEmpty())) {
        // 加载中（推荐/搜索）：骨架屏，结构与真实内容同构
        homeSkeleton(state)
    } else if (!state.homeError.value.isEmpty() && books.isEmpty()) {
        homeErrorView(app, state)
    } else if (books.isEmpty()) {
        homeCenterTip(if (state.isSearchMode.value) { "没有找到相关书籍" } else { "暂无推荐内容" }, "")
    } else {
        if (state.showType.value == 0) {
            homeBookGrid(app, state, books)
        } else {
            homeBookList(app, state, books)
        }
    }
}

func homeCenterTip(text: String, sub: String) {
    VStack(spacing: 8.0.vp) {
        Spacer()
        ProgressRing(0.35, diameter: 48.0, showLabel: false)
        Label(text).fontSize(16.0).textAlign(TextAlign.Center)
        if (!sub.isEmpty()) {
            Label(sub).muted().fontSize(12.0).textAlign(TextAlign.Center)
        }
        Spacer()
    }.fillWidth()
}

func homeErrorView(app: DesktopApp, state: AppState) {
    VStack(spacing: 8.0.vp) {
        Spacer()
        Label("获取出错").bold().fontSize(18.0).textAlign(TextAlign.Center)
        Label(state.homeError.value).muted().textAlign(TextAlign.Center).maxLines(3)
        Button("重试", {=>
            if (state.isSearchMode.value) { doSearch(app, state) } else { fetchRecommend(app, state) }
        }, role: ButtonRole.Primary)
        Spacer()
    }.fillWidth()
}

// 瀑布卡片网格：列数随内容区宽度自适应（每列约 190px，2~6 列），
// 封面按 3:4 宽高比撑满列宽，行高按列宽实时推算，滚动不溢出行槽。
func homeBookGrid(app: DesktopApp, state: AppState, books: Array<BookInfoBrief>): Unit {
    VStack(spacing: 0.vp) {
        WidthProbe(state)
        let w = state.contentWidth.value
        let spacing: Float32 = 14.0
        let cols = max(2, min(6, Int64(Float64(w) / 190.0)))
        // 列内宽（卡片 contentPadding 左右各 10）→ 封面 3:4 高 → 行高
        let innerW = max(120.0, (Float64(w) - Float64((cols - 1) * Int64(spacing))) / Float64(cols) - 20.0)
        let coverH = innerW * 4.0 / 3.0
        // 行高 = 上下内边距20 + 封面 + 间隔8 + 标题行26(14pt粗体行高) + 间隔4 + 作者行18 + 底部余量12
        // 文字区 68：实测旧值 50 低估行高导致标题触底被裁
        let itemH = Float32(20.0 + coverH + 8.0 + 26.0 + 4.0 + 18.0 + 12.0)
        let grid = LazyGrid(books, cols, itemH, spacing: spacing, columnSpacing: spacing,
            scroll: Some(state.homeGridScroll)) { book: BookInfoBrief =>
            homeGridCard(app, state, book, coverH)
        }
        let _ = grid.onReachEnd(threshold: 320.0, action: {=> loadMoreSearch(app, state)})
    }
}

// 探针宽度记忆：跨视图重建存活（探针实例在每次 rebuild 时都会被重新构造，
// 实例字段记不住上一次宽度，会导致 layout 每帧写 State → 无限重排循环空转）
var widthProbeLastW: Float64 = -1.0

/** 内容区宽度探针：0 高控件，layout 时上报宽度（变化超 8px 才写，避免重排循环）。 */
class WidthProbe <: Widget {
    private let state: AppState

    init(state: AppState) {
        this.state = state
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(0.0, 0.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        let w = Float64(rect.w)
        // 守卫基于包级记忆（非实例字段）：宽度稳定后绝不再写 State
        if (widthProbeLastW < 0.0 || w - widthProbeLastW > 8.0 || widthProbeLastW - w > 8.0) {
            widthProbeLastW = w
            state.contentWidth.value = w
        }
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func isFlexible(): Bool {
        false
    }
}

func homeGridCard(app: DesktopApp, state: AppState, book: BookInfoBrief, coverH: Float64): Unit {
    ensureCover(app, state, book.id, book.cover)
    // 整卡可点：进入书籍详情
    Button(onClick: {=> openBriefDetail(app, state, book)}, style: Some(panelCardStyle(state.themeMode.value))) {
        VStack(spacing: 6.0.vp) {
            // 封面撑满列内宽、3:4 高（Cover 裁切），文字区紧随其后不溢出行槽
            coverView(app, state, book.id, book.title, coverH * 3.0 / 4.0, coverH, fillWidth: true)
            Label(book.title).bold().fontSize(14.0).maxLines(1)
            Label(book.author).muted().fontSize(11.0).maxLines(1)
        }
    }.contentPadding(LengthInsets(10.0.vp, 10.0.vp)).fillWidth()
}

// 列表模式：每行列数随内容区宽度自适应（每列约 400px，1~3 列），
// 行内仍是「左封面右文字」的行卡，窄窗时自动退化为单列。
func homeBookList(app: DesktopApp, state: AppState, books: Array<BookInfoBrief>): Unit {
    VStack(spacing: 0.vp) {
        WidthProbe(state)
        let w = state.contentWidth.value
        let spacing: Float32 = 10.0
        let cols = max(1, min(3, Int64(w / 400.0)))
        // 行高 = 封面 88 + contentPadding 上下各 12 = 112
        let grid = LazyGrid(books, cols, 112.0, spacing: spacing, columnSpacing: spacing,
            scroll: Some(state.homeListScroll)) { book: BookInfoBrief =>
            ensureCover(app, state, book.id, book.cover)
            bookListRow(app, state, book.id, book.title, book.author, "", onClick: {=> openBriefDetail(app, state, book)})
        }
        let _ = grid.onReachEnd(threshold: 320.0, action: {=> loadMoreSearch(app, state)})
    }
}

// 通用列表行：仿 HomeListBookCover（左封面，右标题作者）
func bookListRow(app: DesktopApp, state: AppState, id: UInt64, title: String, author: String, extra: String, onClick!: () -> Unit): Unit {
    // 整行可点：进入书籍详情
    Button(onClick: onClick, style: Some(panelCardStyle(state.themeMode.value))) {
        HStack(spacing: 12.0.vp) {
            coverView(app, state, id, title, 66.0, 88.0)
            VStack(spacing: 5.0.vp) {
                Label(title).bold().fontSize(16.0).maxLines(1)
                Label(author).muted().fontSize(13.0).maxLines(1)
                if (!extra.isEmpty()) {
                    Label(extra).muted().fontSize(11.0).maxLines(1)
                }
            }
            Spacer()
        }
    }.contentPadding(LengthInsets(14.0.vp, 12.0.vp)).fillWidth()
}

// 封面占位：取书名首个字符
func coverInitial(title: String): String {
    let t = title.trimAscii()
    for (r in t.runes()) {
        return r.toString()
    }
    return "书"
}

// =====================================================================
// 书架：只展示 Z-Library 收藏（卡片/列表可切换，滑到底部自动续取下一页）
// =====================================================================

func bookshelfView(app: DesktopApp, state: AppState) {
    VStack(spacing: 0.vp) {
        if (state.currentUser.value.isNone()) {
            VStack(spacing: 8.0.vp) {
                Spacer()
                Label("尚未登录").bold().fontSize(20.0).textAlign(TextAlign.Center)
                Label("请先登录 Z-Library 后查看收藏").muted().textAlign(TextAlign.Center)
                Spacer()
            }.fillWidth().fillHeight().flex()
        } else if (state.isShelfLoading.value && state.savedBooks.value.isEmpty()) {
            VStack(spacing: 8.0.vp) {
                Spacer()
                ProgressRing(0.35, diameter: 48.0, showLabel: false)
                Label("正在获取收藏...").muted().textAlign(TextAlign.Center)
                Spacer()
            }.fillWidth().fillHeight().flex()
        } else if (!state.shelfError.value.isEmpty() && state.savedBooks.value.isEmpty()) {
            VStack(spacing: 8.0.vp) {
                Spacer()
                Label("获取出错").bold().fontSize(18.0).textAlign(TextAlign.Center)
                Label(state.shelfError.value).muted().textAlign(TextAlign.Center).maxLines(3)
                Button("重试", {=> fetchSaved(app, state)}, role: ButtonRole.Primary)
                Spacer()
            }.fillWidth().fillHeight().flex()
        } else if (state.savedBooks.value.isEmpty()) {
            VStack(spacing: 8.0.vp) {
                Spacer()
                Label("暂无收藏").bold().fontSize(20.0).textAlign(TextAlign.Center)
                Label("在书籍详情页点击「收藏」即可加入收藏").muted().textAlign(TextAlign.Center)
                Spacer()
            }.fillWidth().fillHeight().flex()
        } else {
            VStack(spacing: 0.vp) {
                if (state.shelfShowType.value == 0) {
                    shelfBookGrid(app, state)
                } else {
                    shelfBookList(app, state)
                }
            }.fillHeight().flex().padding(0.0, 0.0, 10.0, 0.0)
        }
    }.padding(14.0, 14.0, 4.0, 14.0).fillHeight().flex()
}

/** 收藏卡片网格（列数随内容区宽度自适应，与首页同构）。 */
func shelfBookGrid(app: DesktopApp, state: AppState) {
    let books = state.savedBooks.value
    VStack(spacing: 0.vp) {
        WidthProbe(state)
        let w = state.contentWidth.value
        let spacing: Float32 = 14.0
        let cols = max(2, min(6, Int64(Float64(w) / 190.0)))
        let innerW = max(120.0, (Float64(w) - Float64((cols - 1) * Int64(spacing))) / Float64(cols) - 20.0)
        let coverH = innerW * 4.0 / 3.0
        let itemH = Float32(20.0 + coverH + 8.0 + 26.0 + 4.0 + 18.0 + 12.0)
        let grid = LazyGrid<BookInfo>(books, cols, itemH, spacing: spacing, columnSpacing: spacing,
            scroll: Some(state.shelfGridScroll)) { book: BookInfo =>
            ensureCover(app, state, book.id, book.cover)
            Button(onClick: {=> openBookDetail(state, book, saved: true)}, style: Some(panelCardStyle(state.themeMode.value))) {
                VStack(spacing: 6.0.vp) {
                    coverView(app, state, book.id, book.title, coverH * 3.0 / 4.0, coverH, fillWidth: true)
                    Label(book.title).bold().fontSize(14.0).maxLines(1)
                    Label(bookAuthorText(book)).muted().fontSize(11.0).maxLines(1)
                }
            }.contentPadding(LengthInsets(10.0.vp, 10.0.vp)).fillWidth()
        }
        let _ = grid.onReachEnd(threshold: 320.0, action: {=> loadMoreSaved(app, state)})
    }.fillHeight().flex()
}

/** 收藏列表（每行列数随宽度自适应，与首页同构）。 */
func shelfBookList(app: DesktopApp, state: AppState) {
    let books = state.savedBooks.value
    VStack(spacing: 0.vp) {
        WidthProbe(state)
        let w = state.contentWidth.value
        let spacing: Float32 = 10.0
        let cols = max(1, min(3, Int64(w / 400.0)))
        let grid = LazyGrid<BookInfo>(books, cols, 112.0, spacing: spacing, columnSpacing: spacing,
            scroll: Some(state.shelfListScroll)) { book: BookInfo =>
            ensureCover(app, state, book.id, book.cover)
            bookListRow(app, state, book.id, book.title, bookAuthorText(book),
                "${book.extension} · ${book.filesizeString}", onClick: {=> openBookDetail(state, book, saved: true)})
        }
        let _ = grid.onReachEnd(threshold: 320.0, action: {=> loadMoreSaved(app, state)})
    }.fillHeight().flex()
}

// BookInfo.author 是 Option<String>，统一展示
func bookAuthorText(book: BookInfo): String {
    match (book.author) {
        case Some(a) => if (a.isEmpty()) { "未知作者" } else { a }
        case None => "未知作者"
    }
}

// =====================================================================
// 账号管理弹窗（仿 ZlibraryAccount 居中弹层：未登录显示登录表单）
// =====================================================================

func accountModal(app: DesktopApp, state: AppState) {
    Modal(state.showAccount, onDismiss: {=> state.showAccount.value = false}) { =>
        if (state.currentUser.value.isNone()) {
            loginForm(app, state)
        } else {
            userInfoPanel(state)
        }
    }
}

func loginForm(app: DesktopApp, state: AppState) {
    VStack(spacing: 12.0.vp) {
        Label("登录 Z-Library").bold().fontSize(22.0)
        TextField(state.emailInput, placeholder: "邮箱")
        TextField(state.passwordInput, placeholder: "密码").secureEntry()
        if (!state.loginError.value.isEmpty()) {
            Label(state.loginError.value).muted().fontSize(12.0).maxLines(2)
        }
        Button(if (state.isLoggingIn.value) { "登录中..." } else { "登录" }, {=> doLogin(app, state)},
            role: ButtonRole.Primary)
        Label("还没有账号？请前往 Z-Library 官网注册").muted().fontSize(11.0)
    }.padding(4.0).width(360.0)
}

func userInfoPanel(state: AppState) {
    VStack(spacing: 12.0.vp) {
        Label("Zlib 账号").muted().fontSize(12.0)
        Label(state.userName.value).bold().fontSize(20.0).maxLines(1)
        if (!state.downloadLimit.value.isEmpty()) {
            Label(state.downloadLimit.value).muted()
        }
        Button("退出登录", {=> doLogout(state)}, role: ButtonRole.Danger)
    }.padding(4.0).width(320.0)
}

// =====================================================================
// 设置 / 关于
// =====================================================================

func settingModal(state: AppState) {
    Modal(state.showSetting, onDismiss: {=> state.showSetting.value = false}) { =>
        VStack(spacing: 16.0.vp) {
            Label("设置").bold().fontSize(18.0)
            Divider()

            // ---- Z-Library 域名 ----
            VStack(spacing: 6.0.vp) {
                Label("Z-Library 服务地址").muted().fontSize(12.0)
                HStack(spacing: 8.0.vp) {
                    TextField(state.settingsZlibUrl, placeholder: "https://...")
                        .width(260.0)
                    Button("保存", {=>
                        let url = state.settingsZlibUrl.value.trimAscii()
                        if (!url.isEmpty()) {
                            applyZlibUrl(url)
                            saveSettings(url, state.themeMode.value, state.downloadPath.value)
                            state.toaster.show("域名已保存", kind: ToastKind.Success)
                        }
                    }, role: ButtonRole.Primary)
                }.crossAxisAlignment(CrossAxisAlignment.Center)
            }

            Divider()

            // ---- 下载路径 ----
            VStack(spacing: 6.0.vp) {
                Label("下载目录").muted().fontSize(12.0)
                HStack(spacing: 8.0.vp) {
                    TextField(state.downloadPath, placeholder: "下载目录路径...")
                        .width(260.0)
                    Button("保存", {=>
                        let path = state.downloadPath.value.trimAscii()
                        if (!path.isEmpty()) {
                            applyDownloadPath(path)
                            saveSettings(zlibBaseUrl, state.themeMode.value, path)
                            state.toaster.show("下载目录已保存", kind: ToastKind.Success)
                        }
                    }, role: ButtonRole.Primary)
                }.crossAxisAlignment(CrossAxisAlignment.Center)
            }

            Divider()
            Button("关闭", {=> state.showSetting.value = false})
        }.padding(12.0).width(400.0)
    }
}

func aboutModal(state: AppState) {
    Modal(state.showAbout, onDismiss: {=> state.showAbout.value = false}) { =>
        VStack(spacing: 8.0.vp) {
            Label("SelineRead · Windows 版").bold().fontSize(18.0)
            Label("一个 Z-Library 阅读应用").muted()
            Label("基于仓颉语言与 CangHui (chui) 框架").muted()
            Label("请求库：zlibraryAPI4CJ").muted()
            Divider()
            Button("关闭", {=> state.showAbout.value = false})
        }.padding(8.0).width(360.0)
    }
}

// =====================================================================
// =====================================================================
// 下载管理页面
// =====================================================================

/** 简单进度条：直接接收 0~1 静态值（无需 Observable），用于下载任务行。 */
class SimpleProgressBar <: Widget {
    private let value: Float32
    private let thickness: Float32
    private var frame = Rect.zero()

    init(value: Float32, thickness!: Float32 = 6.0) {
        this.value = value
        this.thickness = thickness
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, thickness)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (frame.w <= 0.0) {
            return
        }
        let radius = min(frame.h, frame.w) / 2.0
        ctx.renderer.fillRoundedRect(frame, radius, ctx.theme.field)
        let v = if (value < 0.0) { Float32(0.0) } else if (value > 1.0) { Float32(1.0) } else { value }
        let w = frame.w * v
        if (w > 0.5) {
            ctx.renderer.fillRoundedRect(Rect(frame.x, frame.y, w, frame.h), radius, ctx.theme.accent)
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func isFlexible(): Bool {
        false
    }
}

/** 查找指定书籍正在进行的下载任务（供详情页显示该书进度，而非全局进度）。 */
func activeDownloadTask(state: AppState, bookId: UInt64): ?DownloadTaskInfo {
    for (t in state.downloadTasks.value) {
        if (t.bookId == bookId && (t.status == "下载中" || t.status == "等待中")) {
            return Some(t)
        }
    }
    None
}

/** 是否存在已结束（非进行中）的下载任务。 */
func hasFinishedDownloads(state: AppState): Bool {
    for (t in state.downloadTasks.value) {
        if (t.status != "下载中" && t.status != "等待中") {
            return true
        }
    }
    false
}

/** 下载管理页面：展示所有下载任务，支持取消。 */
func downloadsView(app: DesktopApp, state: AppState) {
    let tasks = state.downloadTasks.value
    VStack(spacing: 12.0.vp) {
        if (tasks.isEmpty()) {
            VStack(spacing: 8.0.vp) {
                Spacer()
                Label("暂无下载任务").bold().fontSize(18.0).textAlign(TextAlign.Center)
                Label("在书籍详情页点击下载按钮即可添加任务").muted().textAlign(TextAlign.Center)
                Spacer()
            }.fillWidth().fillHeight().flex()
        } else {
            ScrollView {
                VStack(spacing: 8.0.vp) {
                    for (i in 0..tasks.size) {
                        downloadTaskRow(app, state, tasks[i], i)
                    }
                }.hug().fillWidth()
            }.fillHeight().flex()
        }
    }.padding(14.0).fillHeight().flex()
}

/** 单个下载任务行：封面缩略图 + 书名 + 进度条 + 状态 + 操作。 */
func downloadTaskRow(app: DesktopApp, state: AppState, task: DownloadTaskInfo, index: Int64) {
    // 触发封面加载（缓存未就绪时显示首字占位）
    if (task.bookId != UInt64(0) && !task.coverUrl.isEmpty()) {
        ensureCover(app, state, task.bookId, task.coverUrl)
    }
    Panel(style: Some(panelCardStyle(state.themeMode.value))) {
        HStack(spacing: 14.0.vp) {
            // 封面缩略图（3:4）
            Panel(style: Some(coverFrameStyle(state.themeMode.value))) {
                coverView(app, state, task.bookId, task.bookName, 48.0, 64.0)
            }.contentPadding(0.0.vp, 0.0.vp)

            // 中间：书名 + 进度条 + 状态行
            VStack(spacing: 8.0.vp) {
                Label(task.bookName).bold().fontSize(15.0).maxLines(1)
                SimpleProgressBar(Float32(task.percent / 100.0)).fillWidth()
                HStack(spacing: 10.0.vp) {
                    Label("${Int64(task.percent)}%").fontSize(12.0).bold()
                    Label(task.status).fontSize(12.0).foregroundColor(statusColor(task.status))
                    if (task.status == "下载中" && !task.speed.isEmpty()) {
                        Label(task.speed).fontSize(12.0).muted()
                    }
                }.hug()
            }.crossAxisAlignment(CrossAxisAlignment.Start).hug().flex()

            // 右侧操作
            if (task.status == "下载中" || task.status == "等待中") {
                Button("取消", {=> cancelDownload(state, index)})
            }
            if (task.status == "失败") {
                Label("失败").foregroundColor(DANGER_TEXT).fontSize(13.0)
            }
            if (task.status == "已完成") {
                Label("已完成").foregroundColor(Color.rgb(74, 222, 128)).fontSize(13.0)
            }
            if (task.status == "已取消") {
                Label("已取消").muted().fontSize(13.0)
            }
        }.crossAxisAlignment(CrossAxisAlignment.Center).hug().fillWidth()
    }.hug().fillWidth()
}

/** 根据状态返回颜色。 */
func statusColor(status: String): Color {
    if (status == "下载中") {
        BRAND_COLOR
    } else if (status == "已完成") {
        Color.rgb(74, 222, 128)
    } else if (status == "失败") {
        DANGER_TEXT
    } else if (status == "已取消") {
        Color.rgb(203, 213, 225)
    } else {
        Color.rgb(203, 213, 225)
    }
}

/** 取消指定下载任务（按列表下标）。 */
func cancelDownload(state: AppState, index: Int64) {
    let tasks = state.downloadTasks.value
    if (index < 0 || index >= tasks.size) {
        return
    }
    if (tasks[index].status == "下载中" || tasks[index].status == "等待中") {
        // 真正中断该任务底层的下载（各任务独占槽位，互不影响）
        cancelDownloadSlot(tasks[index].slot)
    }
    tasks[index].status = "已取消"
    state.downloadTasks.value = tasks
    state.toaster.show("已取消下载", kind: ToastKind.Info)
}

/** 取消指定书籍正在进行的下载（详情页重复点击下载时确认后调用）。 */
func cancelDownloadByBookId(state: AppState, bookId: UInt64) {
    let tasks = state.downloadTasks.value
    var cancelled = false
    for (i in 0..tasks.size) {
        if (tasks[i].bookId == bookId && (tasks[i].status == "下载中" || tasks[i].status == "等待中")) {
            cancelDownloadSlot(tasks[i].slot)
            tasks[i].status = "已取消"
            cancelled = true
        }
    }
    if (cancelled) {
        state.downloadTasks.value = tasks
        state.toaster.show("已取消下载", kind: ToastKind.Info)
    }
}

/** 同一本书重复点击下载时的确认框。 */
func cancelDownloadModal(state: AppState) {
    Modal(state.showCancelDownload, onDismiss: {=> state.showCancelDownload.value = false}) { =>
        VStack(spacing: 12.0.vp) {
            Label("该书籍正在下载").bold().fontSize(18.0)
            Label(state.cancelTargetTitle.value).muted().maxLines(2)
            Label("是否取消当前下载任务？").muted().fontSize(12.0)
            HStack(spacing: 10.0.vp) {
                Button("继续下载", {=> state.showCancelDownload.value = false})
                Button("取消下载", {=>
                    cancelDownloadByBookId(state, state.cancelTargetBookId.value)
                    state.showCancelDownload.value = false
                }, role: ButtonRole.Danger)
            }.hug()
        }.padding(8.0).width(340.0)
    }
}

/** 清空所有已完成/已取消/失败的任务。 */
func clearCompletedDownloads(state: AppState) {
    let tasks = state.downloadTasks.value
    var remaining = ArrayList<DownloadTaskInfo>()
    for (t in tasks) {
        if (t.status == "下载中" || t.status == "等待中") {
            remaining.add(t)
        }
    }
    state.downloadTasks.value = remaining
    state.toaster.show("已清空", kind: ToastKind.Info)
}
