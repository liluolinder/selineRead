/*
 * 书单详情（二级页面）：标题/作者/简介 + 书单里的书（复用图书网格）。
 */
package seline_read

import chui.*
import seline_ui.*

func booklistDetailPage(state: AppState): Unit {
    let theme = selineTheme()
    let authorText = if (state.booklistAuthor.value.isEmpty()) {
        "匿名"
    } else {
        state.booklistAuthor.value
    }
    VStack(spacing: vp(0.0)) {
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            SelineButton("返回书单", {=> state.closeBooklist()}, glyph: "home",
                kind: SelineButtonKind.Ghost, compact: true)
            Spacer()
        }.hug().fillWidth().padding(PAGE_PAD, 12.0, PAGE_PAD, 4.0)
        ScrollView {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                VStack(spacing: vp(SELINE_SPACE_XS)) {
                    Label(state.booklistTitle.value).fontSize(theme.fontTitle).bold()
                        .wrap()
                    Label("${authorText} · ${state.booklistTotal.value} 本书")
                        .fontSize(theme.fontCaption).muted()
                    if (!state.booklistDescription.value.isEmpty()) {
                        Label(plainText(state.booklistDescription.value))
                            .fontSize(theme.fontBody).muted().wrap()
                    }
                }.hug().fillWidth()
                if (!state.booklistError.value.isEmpty()) {
                    errorBannerText(state.booklistError.value)
                }
                if (state.booklistLoading.value && state.booklistBooks.value.isEmpty()) {
                    loadingBlock("正在加载书单内容…")
                }
                bookGrid(state, state.booklistBooks.value)
                if (state.booklistBooks.value.isEmpty() &&
                    !state.booklistLoading.value && state.booklistError.value.isEmpty()) {
                    emptyBlock("star_fill", "这份书单还没有书", "可能已被作者清空")
                }
                if (state.booklistNextPage.value > 0) {
                    SelineButton("加载更多", {=> state.loadMoreBooklistBooks()},
                        glyph: "refresh", kind: SelineButtonKind.Ghost, compact: true,
                        busy: state.booklistLoading.value)
                }
            }.padding(PAGE_PAD, 8.0, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}
