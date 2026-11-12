/*
 * 收藏页（一级页面）。
 *
 * 数据来自 eapi：`UserApi.saved`（`/user/book/saved`，分页）。
 * 必须登录；未登录时给出去「设置」登录的提示。
 *
 * 交互与首页一致：网格 + 滚到底自动加载下一页；没有页头/刷新按钮。
 */
package seline_read

import chui.*
import seline_ui.*

func favoritesPage(state: AppState): Unit {
    state.ensureFavoritesLoaded()
    if (!state.loggedIn.value) {
        // 未登录：整页居中空态（不套背景）
        VStack(spacing: vp(0.0)) {
            Spacer()
            emptyBlock("user", "登录后查看收藏",
                "去「账号」页登录 Z-Library，就能在这里看到收藏的书籍",
                actionLabel: "去账号页登录",
                onAction: Some({=> state.tabSelectFromRail(TAB_ACCOUNT)}))
            Spacer()
        }.fillWidth().fillHeight()
        return
    }
    if (!state.favoritesError.value.isEmpty() && state.favorites.value.isEmpty() &&
        !state.favoritesLoading.value) {
        VStack(spacing: vp(0.0)) {
            Spacer()
            errorStateCard("收藏加载失败", state.favoritesError.value,
                retry: Some({=> state.loadFavorites()}), busy: state.favoritesLoading.value)
            Spacer()
        }.fillWidth().fillHeight()
        return
    }
    VStack(spacing: vp(0.0)) {
        pageScrollView(scrollState: state.favoritesScroll) {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                if (true) {
                    let failed = !state.favoritesError.value.isEmpty()
                    if (failed && !state.favorites.value.isEmpty()) {
                        state.toastIfChanged(state.favoritesError.value)
                    }
                    if (state.favoritesLoading.value || state.forceSkeleton.value) {
                        bookSkeletonGrid(count: 12)
                    } else {
                        bookGrid(state, state.favorites.value)
                    }
                    if (state.favoritesNextPage.value > 0) {
                        FavoritesLoadMoreFooter(state)
                    }
                    if (!state.favoritesLoading.value && state.favorites.value.isEmpty() &&
                        state.favoritesError.value.isEmpty()) {
                        emptyBlock("star", "还没有收藏", "在 Z-Library 网页端收藏书籍后会显示在这里")
                    }
                }
            }.padding(PAGE_PAD, SELINE_SPACE_MD, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

/** 收藏页 footer：滚进视口就自动加载下一页。 */
class FavoritesLoadMoreFooter <: Widget {
    private let state: AppState
    private var frame = Rect.zero()

    init(state: AppState) {
        this.state = state
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, 56.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (!state.favoritesLoading.value && frame.y < ctx.viewportHeight + 100.0) {
            state.loadFavorites(reset: false)
        }
        let theme = selineTheme()
        paintText(ctx.renderer,
            if (state.favoritesLoading.value) { "正在加载更多收藏…" } else { "继续向下滚动加载更多" },
            Rect(frame.x, frame.centerY() - 9.0, frame.w, 20.0),
            theme.palette.textFaint, theme.fontCaption, align: SelineTextAlign.Center)
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