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
        ScrollView {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    Label("搜索「${state.lastKeyword.value}」").fontSize(selineTheme().fontLabel)
                        .muted()
                    Spacer()
                    SelineButton("回到热门", {=> state.exitSearch()}, glyph: "home",
                        kind: SelineButtonKind.Ghost, compact: true)
                }.hug().fillWidth()
                if (!state.error.value.isEmpty()) {
                    errorBannerText(state.error.value)
                }
                if (state.loading.value) {
                    loadingBlock("正在搜索…")
                } else {
                    bookGrid(state, state.results.value)
                    if (state.results.value.isEmpty()) {
                        emptyBlock("search", "没有找到匹配的书",
                            "换个关键词，或检查站点状态")
                    }
                }
            }.padding(PAGE_PAD, SELINE_SPACE_MD, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}
