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
    // 未登录/失败/空态都放在同一个滚动容器里（与书单页一致），任何状态下都能滚动。
    let failedOnEmpty = !state.favoritesError.value.isEmpty() &&
        state.favorites.value.isEmpty() && !state.favoritesLoading.value
    VStack(spacing: vp(0.0)) {
        pageScrollView(scrollState: state.favoritesScroll) {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                if (!state.loggedIn.value) {
                    VStack(spacing: vp(0.0)) {
                        emptyBlock("user", "登录后查看收藏",
                            "去「账号」页登录 Z-Library，就能在这里看到收藏的书籍",
                            actionLabel: "去账号页登录",
                            onAction: Some({=> state.tabSelectFromRail(TAB_ACCOUNT)}))
                    }.padding(0.0, 40.0, 0.0, 0.0)
                } else if (failedOnEmpty) {
                    VStack(spacing: vp(0.0)) {
                        errorStateCard("收藏加载失败", state.favoritesError.value,
                            retry: Some({=> state.loadFavorites()}), busy: state.favoritesLoading.value)
                    }.padding(0.0, 72.0, 0.0, 0.0)
                } else {
                    let failed = !state.favoritesError.value.isEmpty()
                    if (failed && !state.favorites.value.isEmpty()) {
                        state.toastIfChanged(state.favoritesError.value)
                    }
                    // 客户端还没就绪时也走骨架：不然会显示「还没有收藏」，看起来像真的没有
                    if (state.favoritesLoading.value || state.forceSkeleton.value ||
                        !state.isClientReady()) {
                        bookSkeletonGrid(count: 12)
                    } else {
                        bookGrid(state, state.favorites.value)
                    }
                    if (state.favoritesNextPage.value > 0) {
                        LoadMoreNotice(trigger: {=>
                            if (!state.favoritesLoading.value) {
                                // 首屏没铺满窗口时的自动补页同样要提示
                                state.showToastNow("正在加载更多收藏…", kind: ToastKind.Info)
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

