package SelineRead

import chui.*

// =====================================================================
// 骨架屏：加载中的占位视图。结构与真实内容同构（列数/行高/卡形一致），
// 避免加载完成瞬间的布局跳动；纯静态块，无动画、无每帧开销。
// 注：chui 的 vp 扩展只作用于 Int64/Float64，几何量一律用 Float64。
// =====================================================================

/** 滚动条 gutter：内容可用宽 = 视口宽 - (滚动条宽 6 + 两侧边距 4 + 内容内缩 12)。
 * 骨架屏自己算宽度，必须手动扣除，取值须与 chui 的 scrollBarGutter() 一致。 */
let SKELETON_SCROLL_GUTTER: Float64 = 22.0

/** 骨架占位块：固定宽高的圆角矩形（空 HStack 撑尺寸）。 */
func skeletonBlock(state: AppState, w: Float64, h: Float64, radius: Float32) {
    HStack {}.hug().width(w.vp).height(h.vp).background(skeletonBg(state.themeMode.value), radius)
}

/** 骨架占位行：撑满可用宽度、固定高度的圆角条。 */
func skeletonLine(state: AppState, h: Float64, radius: Float32) {
    HStack {}.hug().height(h.vp).fillWidth().background(skeletonBg(state.themeMode.value), radius)
}

/** 首页骨架：按当前展示形态（网格/列表）渲染占位卡，内容可滚动。 */
func homeSkeleton(state: AppState) {
    VStack(spacing: 0.vp) {
        // 宽度探针放在滚动容器外：测量视口宽而非内容宽
        WidthProbe(state)
        ScrollView {
            if (state.showType.value == 0) {
                homeSkeletonGrid(state)
            } else {
                homeSkeletonList(state)
            }
        }.fillHeight().flex()
    }.fillHeight().flex()
}

/** 网格骨架：列数/列宽/封面高算法与 homeBookGrid 完全一致，渲染 5 行占位卡。 */
func homeSkeletonGrid(state: AppState) {
    VStack(spacing: 0.vp) {
        // 扣除滚动条 gutter，与 ScrollView 内容宽一致，避免骨架卡顶到滚动条
        let w = max(0.0, state.contentWidth.value - SKELETON_SCROLL_GUTTER)
        let spacing: Float64 = 14.0
        let cols = max(2, min(6, Int64(w / 190.0)))
        let innerW = max(120.0, (w - Float64((cols - 1) * Int64(spacing))) / Float64(cols) - 20.0)
        let coverH = innerW * 4.0 / 3.0
        VStack(spacing: spacing.vp) {
            for (_ in 0..5) {
                HStack(spacing: spacing.vp) {
                    for (_ in 0..cols) {
                        skeletonGridCard(state, innerW, coverH)
                    }
                }.hug().fillWidth()
            }
        }.hug().fillWidth()
    }
}

/** 网格占位卡：封面块 + 标题条 + 作者条（尺寸对齐真实卡）。 */
func skeletonGridCard(state: AppState, innerW: Float64, coverH: Float64) {
    Panel(style: Some(panelCardStyle(state.themeMode.value))) {
        VStack(spacing: 6.0.vp) {
            skeletonBlock(state, innerW, coverH, 8.0)
            skeletonBlock(state, innerW * 0.92, 14.0, 4.0)
            skeletonBlock(state, innerW * 0.55, 12.0, 4.0)
        }
    }.contentPadding(LengthInsets(10.0.vp, 10.0.vp)).width((innerW + 20.0).vp)
}

/** 列表骨架：列数算法与 homeBookList 一致（每列约 400px，1~3 列），渲染 6 行占位。 */
func homeSkeletonList(state: AppState) {
    // 扣除滚动条 gutter，与 ScrollView 内容宽一致
    let w = max(0.0, state.contentWidth.value - SKELETON_SCROLL_GUTTER)
    let spacing: Float64 = 10.0
    let cols = max(1, min(3, Int64(w / 400.0)))
    let cellW = max(160.0, (w - Float64((cols - 1) * Int64(spacing))) / Float64(cols))
    // 文字条宽度 = 列宽 - 左右内边距28 - 封面66 - 间隔12
    let barW = max(50.0, cellW - 28.0 - 66.0 - 12.0)
    VStack(spacing: spacing.vp) {
        for (_ in 0..6) {
            HStack(spacing: spacing.vp) {
                for (_ in 0..cols) {
                    Panel(style: Some(panelCardStyle(state.themeMode.value))) {
                        HStack(spacing: 12.0.vp) {
                            skeletonBlock(state, 66.0, 88.0, 8.0)
                            VStack(spacing: 8.0.vp) {
                                skeletonBlock(state, barW * 0.9, 16.0, 4.0)
                                skeletonBlock(state, barW * 0.5, 12.0, 4.0)
                            }.crossAxisAlignment(CrossAxisAlignment.Start).hug()
                        }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
                    }.contentPadding(LengthInsets(14.0.vp, 12.0.vp)).width(cellW.vp)
                }
            }.hug()
        }
    }.hug().fillWidth()
}

/** 详情页骨架：英雄区（封面块 + 标题/作者/胶囊条）+ 双栏卡片占位。 */
func detailSkeleton(state: AppState) {
    VStack(spacing: 16.0.vp) {
        Panel(style: Some(heroCardStyle(state.themeMode.value))) {
            HStack(spacing: 26.0.vp) {
                skeletonBlock(state, 200.0, 266.0, 10.0)
                VStack(spacing: 14.0.vp) {
                    skeletonBlock(state, 420.0, 30.0, 6.0)
                    skeletonBlock(state, 220.0, 18.0, 5.0)
                    skeletonBlock(state, 180.0, 16.0, 5.0)
                    Spacer()
                    HStack(spacing: 10.0.vp) {
                        skeletonBlock(state, 72.0, 30.0, 15.0)
                        skeletonBlock(state, 86.0, 30.0, 15.0)
                        skeletonBlock(state, 80.0, 30.0, 15.0)
                    }.hug()
                }.crossAxisAlignment(CrossAxisAlignment.Start).hug().flex()
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug().fillWidth()
        }.contentPadding(26.0.vp, 26.0.vp).fillWidth()
        HStack(spacing: 16.0.vp) {
            skeletonInfoPanel(state)
            skeletonInfoPanel(state)
        }.hug().fillWidth()
    }.crossAxisAlignment(CrossAxisAlignment.Start).hug().fillWidth()
}

/** 详情页双栏占位卡：标题条 + 分隔线 + 若干内容条。 */
func skeletonInfoPanel(state: AppState) {
    Panel(style: Some(panelCardStyle(state.themeMode.value))) {
        VStack(spacing: 12.0.vp) {
            skeletonBlock(state, 120.0, 19.0, 5.0)
            Divider(color: Some(detailDivider(state.themeMode.value)))
            skeletonLine(state, 15.0, 4.0)
            skeletonLine(state, 15.0, 4.0)
            skeletonLine(state, 15.0, 4.0)
            skeletonLine(state, 15.0, 4.0)
        }.crossAxisAlignment(CrossAxisAlignment.Start).hug().fillWidth()
    }.contentPadding(22.0.vp, 22.0.vp).flex()
}
