/*
 * 可伸缩侧栏（与 seline_bili 一致的交互与几何）。
 *
 * 布局契约：所有几何只来自 `RAIL_PROGRESS.value`（0..1 的弹簧值）：
 *   - 侧栏占用宽度 = 56 + (220 - 56) * t
 *   - 行排版宽度恒为 220，外层裁切到占用宽度
 *   - 行内一切 x 都相对 `frame` 推算
 *
 * 弹簧在**帧回调**里推进（`railAdvance`），结果写在普通引用 `RAIL_PROGRESS` 里；
 * 每帧写 `State` 会让整棵树每帧重建（闪烁），而只在 draw 里推进会被脏帧跳过卡住。
 */
package seline_read


import chui.*
import seline_ui.*

/** 展开 / 收起两种宽度。 */
let RAIL_EXPANDED: Float32 = 220.0
let RAIL_COLLAPSED: Float32 = 56.0
/** 侧栏行高 / 展开态左右内边距。 */
let SIDEBAR_ROW_HEIGHT: Float32 = 44.0
let SIDEBAR_INSET: Float32 = 8.0
/** 「分区」组标题行高与子项行高。 */

/** 页签下标：内容页在前，设置固定在底部。 */
let TAB_HOME: Int64 = 0
let TAB_FAVORITES: Int64 = 1
let TAB_BOOKLISTS: Int64 = 2
let TAB_DOWNLOADS: Int64 = 3
let TAB_SETTINGS: Int64 = 4
let TAB_ACCOUNT: Int64 = 5

/** 内容页签（搜索不再是独立页签：结果直接显示在「热门」页签里）。 */
let APP_TABS: Array<SelineRailItem> = [
    // 图标语义：热门=火苗、收藏=星、书单=带书签的列表、下载=下载
    SelineRailItem("热门", "flame", "flame_fill"),
    SelineRailItem("收藏", "star-o", "star"),
    SelineRailItem("书单", "list_book", "list_book_fill"),
    SelineRailItem("下载", "download-o", "download")
]

/** 侧栏进度的帧间通道：帧回调写入，构建/绘制读取。 */
class RailProgress {
    var value: Float32 = 0.0
}

let RAIL_PROGRESS: RailProgress = RailProgress()

/**
 * 侧栏弹簧；**必须在视图构建阶段创建**（`rememberState` 要求处于构建中）。
 */
class RailSpring {
    let spring: Spring

    init() {
        this.spring = rememberState<Spring>("rail.spring") {
            // 阻尼比 ~0.88：不来回弹。现在内容宽度不再逐帧重排，出帧很便宜，
            // 动画时长放到 ~230ms（原来 ~150ms 只有 9 帧，看起来发"跳"）。
            Spring(0.0, stiffness: 360.0, damping: 34.0)
        }.value
    }

    /**
     * 推进一帧；返回 `true` 表示已经到位。
     *
     * **直接按本帧真实 deltaMs 积分**，不再量化成固定 8ms 步长：
     * 窗口没有 vsync 时一帧只有 5~6ms，8ms 的定量步长会让弹簧每帧走 0 或 1 步，
     * 于是宽度序列像 0、8、8、16、16…ms 这样跳，视觉上就是"一顿一顿"。
     * chui 的 `Spring.tick` 内部已把步长夹到 40ms，直接喂真实 delta 是稳定的。
     */
    func advance(target: Float32, deltaMs: Float32): Bool {
        if (spring.value == target) {
            return true
        }
        let stepMs = if (deltaMs < 1.0) { UInt64(1) } else { UInt64(Int64(deltaMs)) }
        let _ = spring.animate(target: target, deltaMs: stepMs)
        spring.value == target
    }
}

/** 弹簧缓存：帧回调与视图构建必须拿到同一个对象。 */
private var railSpringCache: ?RailSpring = None

/** 取（必要时创建）弹簧。**只能在视图构建过程中调用**。 */
func rail(): RailSpring {
    match (railSpringCache) {
        case Some(value) => value
        case None =>
            let created = RailSpring()
            railSpringCache = Some(created)
            RAIL_PROGRESS.value = created.spring.value
            created
    }
}

/** 侧栏弹簧的唯一推进点，每帧一次（挂在根的 `FrameHandler` 上）。 */
func railAdvance(state: AppState, deltaMs: Float32): Unit {
    match (railSpringCache) {
        case None => ()
        case Some(railSpring) =>
            let target: Float32 = if (state.railExpanded.value) { 1.0 } else { 0.0 }
            let _ = railSpring.advance(target, deltaMs)
            if (RAIL_PROGRESS.value != railSpring.spring.value) {
                RAIL_PROGRESS.value = railSpring.spring.value
                // 手动测试诊断：侧栏动画逐帧记录进度与像素宽度
                writeDebugLog("RAIL dt=${Int64(deltaMs)} t=${railSpring.spring.value} w=${railVisibleWidth()} target=${target}")
            }
            // 像素宽度已经到位就立刻吸附到目标值：
            // 弹簧的收敛阈值是 5e-4（对 0..1 的进度来说远小于 1 像素），否则浮点会
            // 继续"爬"好几百帧（实测一次切换要 ~4~5 秒才真正停下），
            // 期间 `railAnimating` 恒为真 → 应用一直按满帧率空转重绘。
            if (railVisibleWidth() == railWidthAt(target)) {
                railSpring.spring.reset(target)
                RAIL_PROGRESS.value = target
            }
            if (railSpring.spring.value == target && state.railProgress.value != target) {
                state.railProgress.value = target
            }
    }
}

/** 侧栏弹簧是否还在运动（决定是否继续请求帧）。 */
func railAnimating(state: AppState): Bool {
    match (railSpringCache) {
        case Some(railSpring) =>
            let target: Float32 = if (state.railExpanded.value) { 1.0 } else { 0.0 }
            railSpring.spring.value != target
        case None => false
    }
}


/** 进度 `t` 对应的整像素宽度（用于判断"视觉上已经到位"）。 */
func railWidthAt(t: Float32): Float32 {
    let clamped = clamp01(t)
    Float32(Int64(RAIL_COLLAPSED + (RAIL_EXPANDED - RAIL_COLLAPSED) * clamped))
}

/** 当前可见宽度（整像素）。 */
func railVisibleWidth(): Float32 {
    let t = max(0.0, RAIL_PROGRESS.value)
    Float32(Int64(RAIL_COLLAPSED + (RAIL_EXPANDED - RAIL_COLLAPSED) * t))
}

/** 当前进度，夹到 0..1（弹簧过冲值不参与颜色/淡入计算）。 */
func railT(): Float32 {
    clamp01(RAIL_PROGRESS.value)
}

/**
 * 左侧竖排页签栏。
 *
 * `ZStack`（背景板 + 裁剪内容）都拉伸到同一个矩形；
 * 宽度由 `RailShell.measure` 给当前可见值，内容按 220 排版后裁切。
 */
func sidebarTabs(state: AppState): Unit {
    let expanded = state.railExpanded.value
    let selectedTab = if (state.detailOpen.value) { -1 } else { state.tab.value }
    let _ = rail()
    let palette = selineTheme().palette
    RailShell(palette.surfaceSunken) {
        railRows(state, expanded, selectedTab)
    }
}

/** 侧栏外壳：唯一决定侧栏宽度的地方。 */
class RailShell <: Widget {
    private let backdrop: Color
    private let content: Widget
    private var frame = Rect.zero()

    public init(background: Color, body!: () -> Unit) {
        this.backdrop = background
        let collected = Array<?Widget>(1, { _ => None })
        let _ = Reveal(shown: true, key: Some("rail.shell")) {
            collected[0] = Some(Panel(padding: LengthInsets.zero(),
                style: Some(SurfaceStyle(Color.rgba(0, 0, 0, 0))), flexible: false, body: body))
        }
        this.content = collected[0].getOrThrow()
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let _ = content.measure(ctx, Size(RAIL_EXPANDED, available.h))
        Size(railVisibleWidth(), available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        let width = railVisibleWidth()
        frame = Rect(rect.x, rect.y, width, rect.h)
        content.layout(ctx, Rect(rect.x, rect.y, RAIL_EXPANDED, rect.h))
    }

    public func draw(ctx: UiContext): Unit {
        if (frame.w <= 0.5) {
            return
        }
        // 在 draw 时取色：主题过渡分两遍绘制，构建期抓色会让侧栏瞬时换色
        ctx.renderer.fill(frame, selineTheme().palette.window)
        ctx.renderer.pushClip(frame)
        try {
            content.draw(ctx)
        } finally {
            ctx.renderer.popClip()
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(_, x, y) =>
                if (!frame.contains(x, y) && ctx.dragId.isEmpty()) { return false }
            case UiEvent.MouseUp(_, x, y) =>
                if (!frame.contains(x, y) && ctx.dragId.isEmpty()) { return false }
            case UiEvent.MouseMove(x, y) =>
                if (!frame.contains(x, y)) { return false }
            case UiEvent.MouseWheel(_, _, x, y) =>
                if (!frame.contains(x, y)) { return false }
            case _ => ()
        }
        content.handle(ctx, event)
    }

    public func acceptsStretch(axis: Axis): Bool {
        match (axis) {
            case Axis.Horizontal => false
            case Axis.Vertical => true
        }
    }

    public func focusableIds(): Array<String> {
        content.focusableIds()
    }

    public func interactionOwnerIds(): Array<String> {
        content.interactionOwnerIds()
    }
}

/** 侧栏的行：固定区（顶）→ 弹性区 → 底栏。 */
func railRows(state: AppState, expanded: Bool, selectedTab: Int64): Unit {
    VStack(spacing: vp(0.0)) {
        // ---- 固定区 ----
        VStack(spacing: vp(0.0)) {
            ZStack { }.height(SELINE_SPACE_SM)
            SidebarItem(if (expanded) { "chevron_left" } else { "chevron_right" },
                if (expanded) { "收起侧栏" } else { "展开侧栏" }, expanded, false,
                {=>
                    state.railExpanded.value = !state.railExpanded.value
                    diagMark("rail-toggle expanded=${state.railExpanded.value}")
                })
            ZStack { }.height(SELINE_SPACE_XS)
            for (index in 0..APP_TABS.size) {
                let item = APP_TABS[index]
                SidebarItem(if (selectedTab == index) { item.activeIcon } else { item.icon },
                    item.label, expanded, selectedTab == index,
                    {=> state.tabSelectFromRail(index)})
            }
        }.hug()

        // ---- 弹性区（不再有「分区」分组） ----
        Spacer()

        // ---- 底栏：分隔线 + 设置 + 账号入口 ----
        VStack(spacing: vp(0.0)) {
            SelineRule().width(RAIL_COLLAPSED - 16.0).padding(8.0, 4.0, 8.0, 4.0)
            // 深浅色切换：辐射原点就是这个按钮的真实中心（每帧由 layout 上报）
            SidebarItem(if (state.darkMode.value) { "sun" } else { "moon" },
                if (state.darkMode.value) { "浅色模式" } else { "深色模式" }, expanded, false,
                {=> state.toggleTheme(0.0, 0.0)})
            SidebarItem(if (selectedTab == TAB_SETTINGS) { "settings" } else { "settings-o" },
                "设置", expanded, selectedTab == TAB_SETTINGS,
                {=> state.tabSelectFromRail(TAB_SETTINGS)})
            SidebarAccountChip(state, expanded, selectedTab == TAB_ACCOUNT)
            ZStack { }.height(SELINE_SPACE_SM)
        }.hug()
    }.width(RAIL_EXPANDED)
        .fillHeight()
}
