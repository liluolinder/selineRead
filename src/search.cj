/*
 * 搜索页（一级页面）。
 *
 * 搜索请求由标题栏输入框的回车触发（AppState.submitSearch），结果放在
 * `results` 里；这个页面只负责把状态画出来。
 */
package seline_read

import chui.*
import seline_ui.*

func searchPage(state: AppState): Unit {
    let subtitle = if (state.lastKeyword.value.isEmpty()) {
        "在标题栏输入关键词，回车搜索"
    } else {
        "关键词：${state.lastKeyword.value}"
    }
    VStack(spacing: vp(0.0)) {
        pageHeader("搜索", subtitle, {=>
            SelineButton("回到热门", {=> state.exitSearch()}, glyph: "home",
                kind: SelineButtonKind.Ghost, compact: true)
        })
        ScrollView {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                if (!state.error.value.isEmpty()) {
                    errorBannerText(state.error.value)
                }
                if (state.loading.value) {
                    loadingBlock("正在搜索…")
                }
                if (state.lastKeyword.value.isEmpty()) {
                    emptyBlock("search", "还没有搜索",
                        "点标题栏的搜索框，输入书名 / 作者 / 关键词后回车")
                } else if (!state.loading.value) {
                    bookGrid(state, state.results.value)
                    if (state.results.value.isEmpty()) {
                        emptyBlock("search", "没有找到匹配的书",
                            "换个关键词，或检查站点状态")
                    }
                }
            }.padding(PAGE_PAD, 8.0, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}
