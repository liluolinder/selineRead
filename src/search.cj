/*
 * 搜索页（一级页面）。
 *
 * 搜索请求由标题栏输入框的回车触发（AppState.submitSearch），结果放在
 * `results` 里；这个页面只负责把状态画出来。
 */
package seline_read

import chui.*
import seline_ui.*

/** 搜索结果（不再占用独立页签，显示在「热门」页签内）。 */
func searchPage(state: AppState): Unit {
    if (!state.error.value.isEmpty() && !state.loading.value) {
        VStack(spacing: vp(0.0)) {
            Spacer()
            errorStateCard("搜索失败", state.error.value,
                retry: Some({=> state.submitSearch()}), busy: state.loading.value)
            Spacer()
        }.fillWidth().fillHeight()
        return
    }
    VStack(spacing: vp(0.0)) {
        pageScrollView(scrollState: state.searchScroll) {
            VStack(spacing: vp(SELINE_SPACE_MD)) {

                if (state.loading.value || state.forceSkeleton.value) {
                    bookSkeletonGrid(count: 12)
                } else {
                    bookGrid(state, state.results.value)
                    if (state.results.value.isEmpty()) {
                        emptyBlock("search", "没有找到匹配的书",
                            "换个关键词，或检查站点状态")
                    } else if (state.searchHasMore.value || state.searchLoadingMore.value) {
                        // 滚到底自动取下一页（之前只加载第一页，往下滚没有内容）
                        LoadMoreNotice(trigger: {=>
                            if (state.searchHasMore.value && !state.searchLoadingMore.value &&
                                !state.loading.value) {
                                if (state.searchScroll.value > 8.0) {
                                    state.showToastNow("正在加载更多…", kind: ToastKind.Info)
                                }
                                state.loadMoreSearch()
                            }
                        })
                    }
                }
            }.padding(PAGE_PAD, SELINE_SPACE_MD, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}
