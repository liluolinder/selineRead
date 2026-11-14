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
                        LoadMoreNotice(trigger: {=>
                            if (!state.favoritesLoading.value) {
                                if (state.favoritesScroll.value > 8.0) {
                                    state.showToastNow("正在加载更多收藏…", kind: ToastKind.Info)
                                }
                                state.loadFavorites(reset: false)
                            }
                        })
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

