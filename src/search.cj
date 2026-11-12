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
    VStack(spacing: vp(0.0)) {
        pageScrollView(scrollState: state.searchScroll) {
            VStack(spacing: vp(SELINE_SPACE_MD)) {

                let failed = !state.error.value.isEmpty()
                if (failed && !state.loading.value) {
                    // 搜索失败：整块错误卡片（不再同时显示"没有找到匹配的书"）
                    errorStateCard("搜索失败", state.error.value,
                        retry: Some({=> state.submitSearch()}), busy: state.loading.value)
                } else if (state.loading.value || state.forceSkeleton.value) {
                    bookSkeletonGrid(count: 12)
                } else {
                    bookGrid(state, state.results.value)
                    if (state.results.value.isEmpty()) {
                        emptyBlock("search", "没有找到匹配的书",
                            "换个关键词，或检查站点状态")
                    } else if (state.searchHasMore.value || state.searchLoadingMore.value) {
                        // 滚到底自动取下一页（之前只加载第一页，往下滚没有内容）
                        SearchLoadMoreFooter(state)
                    }
                }
            }.padding(PAGE_PAD, SELINE_SPACE_MD, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}
/**
 * 搜索结果的「滚到底加载下一页」哨兵。
 *
 * 和首页/收藏的 footer 同样的做法：自己 `draw` 时判断是否已经接近视口底部，
 * 接近就触发一次 `loadMoreSearch()`；真正的去重（loading / hasMore）在状态层做。
 */
class SearchLoadMoreFooter <: Widget {
    private let state: AppState
    private var frame = Rect.zero()

    init(state: AppState) {
        this.state = state
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, 60.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let theme = selineTheme()
        if (frame.y < ctx.viewportHeight + 120.0 && state.searchHasMore.value &&
            !state.searchLoadingMore.value && !state.loading.value) {
            state.loadMoreSearch()
        }
        let text = if (state.searchLoadingMore.value) {
            "正在加载更多…"
        } else {
            "继续向下滚动加载更多"
        }
        paintText(ctx.renderer, text,
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