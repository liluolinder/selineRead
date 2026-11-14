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
    let failedOnEmpty = !state.booklistError.value.isEmpty() &&
        state.booklistBooks.value.isEmpty() && !state.booklistLoading.value
    VStack(spacing: vp(0.0)) {
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            SelineButton("返回书单", {=> state.closeBooklist()}, glyph: "home",
                kind: SelineButtonKind.Ghost, compact: true)
            Spacer()
        }.hug().fillWidth().padding(PAGE_PAD, 12.0, PAGE_PAD, 4.0)
        pageScrollView(scrollState: state.booklistDetailScroll) {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                if (failedOnEmpty) {
                    VStack(spacing: vp(0.0)) {
                        errorStateCard("书单内容加载失败", state.booklistError.value,
                            retry: Some({=> state.loadBooklistBooks(1)}), busy: state.booklistLoading.value)
                    }.padding(0.0, 72.0, 0.0, 0.0)
                }
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
                let failed = !state.booklistError.value.isEmpty()
                if (failed) {
                    state.toastIfChanged(state.booklistError.value)
                }
                if (state.booklistLoading.value && state.booklistBooks.value.isEmpty()) {
                    bookSkeletonGrid(count: 12)
                }
                bookGrid(state, state.booklistBooks.value)
                if (state.booklistBooks.value.isEmpty() &&
                    !state.booklistLoading.value && !failed) {
                    emptyBlock("star_fill", "这份书单还没有书", "可能已被作者清空")
                }
                if (state.booklistNextPage.value > 0 && state.booklistError.value.isEmpty()) {
                    // 页面里不再放「加载更多」按钮：滚到底自动加载，状态用 Toast 反馈
                    LoadMoreNotice(trigger: {=>
                        if (!state.booklistLoading.value) {
                            // 首屏没铺满窗口时的自动补页同样要提示
                            state.showToastNow("正在加载更多…", kind: ToastKind.Info)
                            state.loadMoreBooklistBooks()
                        }
                    })
                }
            }.padding(PAGE_PAD, 8.0, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}
