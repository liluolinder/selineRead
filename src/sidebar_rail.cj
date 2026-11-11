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
let SIDEBAR_GROUP_HEADER_HEIGHT: Float32 = 32.0
let SIDEBAR_ZONE_ROW_HEIGHT: Float32 = 35.0
/** 弹簧步长（毫秒）。 */
let RAIL_STEP_MS: Float32 = 33.0

/** 页签下标：内容页在前，设置固定在底部。 */
let TAB_HOME: Int64 = 0
let TAB_FAVORITES: Int64 = 1
let TAB_BOOKLISTS: Int64 = 2
let TAB_DOWNLOADS: Int64 = 3
let TAB_SETTINGS: Int64 = 4

/** 内容页签（搜索不再是独立页签：结果直接显示在「热门」页签里）。 */
let APP_TABS: Array<SelineRailItem> = [
    SelineRailItem("热门", "home", "home_fill"),
    SelineRailItem("收藏", "star", "star_fill"),
    SelineRailItem("书单", "folder", "folder"),
    SelineRailItem("下载", "download", "download")
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
    let pendingMs: State<Float32>

    init() {
        this.spring = rememberState<Spring>("rail.spring") {
            Spring(0.0, stiffness: 140.0, damping: 12.0)
        }.value
        this.pendingMs = rememberState<State<Float32>>("rail.pending") {
            State<Float32>(0.0)
        }.value
    }

    /** 推进一帧；返回 `true` 表示已经到位。 */
    func advance(target: Float32, deltaMs: Float32): Bool {
        if (spring.value == target) {
            return true
        }
        if (deltaMs > 0.0) {
            pendingMs.value += deltaMs
        }
        var stepped = false
        while (pendingMs.value >= RAIL_STEP_MS) {
            pendingMs.value -= RAIL_STEP_MS
            let _ = spring.animate(target: target, deltaMs: UInt64(RAIL_STEP_MS))
            stepped = true
        }
        if (!stepped) {
            let _ = spring.animate(target: target, deltaMs: 0)
        }
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
        ctx.renderer.fill(frame, backdrop)
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
            SidebarItem(if (expanded) { "chevron_down_fill" } else { "chevron_up_fill" },
                if (expanded) { "收起侧栏" } else { "展开侧栏" }, expanded, false,
                {=> state.railExpanded.value = !state.railExpanded.value})
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
            SidebarItem("clock_fill", "设置", expanded, selectedTab == TAB_SETTINGS,
                {=> state.tabSelectFromRail(TAB_SETTINGS)})
            SidebarAccountChip(state, expanded)
            ZStack { }.height(SELINE_SPACE_SM)
        }.hug()
    }.width(RAIL_EXPANDED)
        .fillHeight()
}
