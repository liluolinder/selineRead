package SelineRead

import chui.*
import zlibraryAPI4CJ.dataModel.*

// =====================================================================
// 书籍详情页（桌面版自定设计，固定布局——不随窗口尺寸缩放）：
//   结构：顶部栏（返回/收藏）→ 英雄区（大封面+书名+胶囊）→
//         双栏（左简介弹性宽｜右元数据比例宽）。
// =====================================================================

/** 打开详情页：记录当前书籍与所在页签并切到详情视图。
 * `saved` 为 true 时强制标记为已收藏——收藏接口返回的 BookInfo 不带
 * `_isUserSavedBook`，从收藏页进入时若按 None 处理会显示成「未收藏」。 */
func openBookDetail(state: AppState, book: BookInfo, saved!: Bool = false) {
    if (saved) {
        book.isUserSavedBook = Some(true)
    }
    state.detailBook.value = Some(book)
    state.detailMsg.value = ""
    // 记住是从哪个页签打开的：详情只在该页签下显示（切走再切回仍保留）
    state.detailTab.value = state.currentTab.value
    state.detailVisible.value = true
}

/** 详情页当前是否可见（只在其来源页签下显示）。 */
func detailVisibleNow(state: AppState): Bool {
    state.detailVisible.value && state.currentTab.value == state.detailTab.value
}

/** 关闭详情页：回原页面。 */
func closeBookDetail(state: AppState) {
    state.detailVisible.value = false
    state.detailBook.value = Option<BookInfo>.None
}

/** 摘要卡片点击：以摘要秒开详情，后台 getBookInfo 拉全量刷新（简介/出版社等随后补齐）。 */
func openBriefDetail(app: DesktopApp, state: AppState, brief: BookInfoBrief) {
    openBookDetail(state, briefToBookInfo(brief))
    fetchBookDetail(app, state, brief)
}

/** 摘要模型 → 全量模型（推荐流缺简介/出版社，详情页按 ？？？ 展示）。 */
func briefToBookInfo(b: BookInfoBrief): BookInfo {
    let bi = BookInfo()
    bi.id = b.id
    bi.title = b.title
    bi.author = if (b.author.isEmpty()) { None } else { Some(b.author) }
    bi.cover = b.cover
    bi.hash = b.hash
    bi
}

/** 去掉简介里的 HTML 标签（鸿蒙版用 Web 组件渲染，桌面版无 WebView，按纯文本展示）。 */
func stripHtmlTags(html: String): String {
    let out = StringBuilder()
    var inTag = false
    for (c in html.runes()) {
        if (c == r'<') {
            inTag = true
        } else if (c == r'>') {
            inTag = false
        } else if (!inTag) {
            out.append(c)
        }
    }
    out.toString()
}

/** 可空字符串字段展示值（空/缺失 → ？？？）。 */
func detailOptText(v: ?String): String {
    match (v) {
        case Some(s) => if (s.isEmpty()) { "？？？" } else { s }
        case None => "？？？"
    }
}

func detailAuthorText(book: BookInfo): String {
    match (book.author) {
        case Some(a) => if (a.isEmpty()) { "未知作者" } else { a }
        case None => "未知作者"
    }
}

/** 页面骨架：宽度铺满内容区，双栏随窗口自然伸缩。
 * 返回/收藏键已上移到标题栏（detailNavButtons），主体从英雄区开始。 */
func detailView(app: DesktopApp, state: AppState) {
    ScrollView {
        // 内容与滚动条的间距由 chui 的 scrollBarGutter 统一提供（CUI_SCROLL_CONTENT_INSET）
        VStack(spacing: 0.vp) {
            if (state.detailSkeletonOn.value) {
                // 正在拉取全量详情：骨架屏占位
                detailSkeleton(state)
            } else if (let Some(book) <- state.detailBook.value) {
                VStack(spacing: 16.0.vp) {
                    detailHero(app, state, book)
                    // 双栏 1:1：两卡等分宽度、固定等高，简介内部滚动防溢出
                    HStack(spacing: 16.0.vp) {
                        detailDescriptionCard(state, book).flex()
                        detailMetaCard(state, book).flex()
                    }.hug().fillWidth()
                    if (!state.detailMsg.value.isEmpty()) {
                        Label(state.detailMsg.value).fontSize(14.0.vp).foregroundColor(DANGER_TEXT)
                    }
                }.crossAxisAlignment(CrossAxisAlignment.Start).hug().fillWidth()
            }
        }.hug().fillWidth()
    }.padding(20.0).fillHeight().flex()
}

/** 标题栏中段按钮组（详情页）：返回 + 收藏（原详情页顶部栏上移至此）。 */
func detailNavButtons(app: DesktopApp, state: AppState) {
    HStack(spacing: 8.0.vp) {
        Button(onClick: {=> closeBookDetail(state)}, style: Some(PILL_BUTTON_STYLE)) {
            HStack(spacing: 6.0.vp) {
                Label("‹").bold().fontSize(19.0)
                Label("返回").fontSize(15.0)
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
        }
        if (let Some(book) <- state.detailBook.value) {
            Button(onClick: {=> toggleFavorite(app, state)}, style: Some(FAV_BUTTON_STYLE)) {
                HStack(spacing: 6.0.vp) {
                    Label(if (book.isUserSavedBook ?? false) { "★" } else { "☆" }).fontSize(16.0)
                        .foregroundColor(BRAND_COLOR)
                    Label(if (book.isUserSavedBook ?? false) { "已收藏" } else { "收藏" }).fontSize(15.0)
                }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            }
            // 下载：后台取下载信息并保存到系统下载目录
            // 进度绑定到「本书」的下载任务，而不是全局进度
            let activeTask = activeDownloadTask(state, book.id)
            Button(onClick: {=> downloadBook(app, state)}, style: Some(PILL_BUTTON_STYLE)) {
                HStack(spacing: 6.0.vp) {
                    ImageView(iconPath("download", false, state.themeMode.value), fit: ImageFit.Contain,
                        preferredWidth: Some(16.0.vp), preferredHeight: 16.0.vp)
                    match (activeTask) {
                        case Some(t) => Label("下载中 ${Int64(t.percent)}%").fontSize(15.0)
                        case None => Label("下载").fontSize(15.0)
                    }
                }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            }
        }
    }.hug().crossAxisAlignment(CrossAxisAlignment.Center)
}

/** 英雄区：大封面（200×266 = 3:4）+ 书名 + 作者 + 评分行 + 信息胶囊。 */
func detailHero(app: DesktopApp, state: AppState, book: BookInfo) {
    Panel(style: Some(heroCardStyle(state.themeMode.value))) {
        HStack(spacing: 26.0.vp) {
            // 封面浮起：透明容器给描边+投影，内嵌 3:4 封面
            Panel(style: Some(coverFrameStyle(state.themeMode.value))) {
                coverView(app, state, book.id, book.title, 200.0, 266.0)
            }.contentPadding(0.0.vp, 0.0.vp)
            VStack(spacing: 14.0.vp) {
                Label(book.title).bold().fontSize(30.0).maxLines(2)
                Label(detailAuthorText(book)).fontSize(17.0).muted().maxLines(2)
                // 评分行：质量 / 热度（接口打分，缺省整行隐藏）
                detailScoreRow(state, book)
                Spacer()
                // 信息胶囊：格式 / 大小 / 语言（缺省项不显示）
                HStack(spacing: 10.0.vp) {
                    if (!book.extension.isEmpty()) {
                        detailPill(book.extension)
                    }
                    if (!book.filesizeString.isEmpty()) {
                        detailPill(book.filesizeString)
                    }
                    if (!book.language.isEmpty()) {
                        detailPill(book.language)
                    }
                }.hug()
            }.crossAxisAlignment(CrossAxisAlignment.Start).hug().flex()
        }.crossAxisAlignment(CrossAxisAlignment.Center).hug().fillWidth()
    }.contentPadding(26.0.vp, 26.0.vp).fillWidth()
}

/** 评分行：★ 质量分 · 热度分（interestScore/qualityScore 为接口文案，空则整行隐藏）。 */
func detailScoreRow(state: AppState, book: BookInfo) {
    if (!book.qualityScore.isEmpty() || !book.interestScore.isEmpty()) {
        HStack(spacing: 16.0.vp) {
            if (!book.qualityScore.isEmpty()) {
                HStack(spacing: 6.0.vp) {
                    // ★ 字形在默认字体中缺字（不可见），改用 HM Symbol 导出的 PNG
                    ImageView(iconPath("star", false, state.themeMode.value), fit: ImageFit.Contain,
                        preferredWidth: Some(16.0.vp), preferredHeight: 16.0.vp)
                    Label("质量 ${book.qualityScore}").fontSize(14.0).muted()
                }.hug().crossAxisAlignment(CrossAxisAlignment.Center)
            }
            if (!book.interestScore.isEmpty()) {
                HStack(spacing: 6.0.vp) {
                    // ♥ 字形在默认字体中缺字（不可见），改用 HM Symbol 导出的 PNG
                    ImageView(iconPath("flame", false, state.themeMode.value), fit: ImageFit.Contain,
                        preferredWidth: Some(16.0.vp), preferredHeight: 16.0.vp)
                    Label("热度 ${book.interestScore}").fontSize(14.0).muted()
                }.hug().crossAxisAlignment(CrossAxisAlignment.Center)
            }
        }.hug()
    }
}

/** 胶囊标签：品牌色低透明底 + 全圆角。 */
func detailPill(text: String) {
    Label(text).fontSize(14.0).foregroundColor(BRAND_COLOR)
        .padding(12.0.vp, 6.0.vp, 12.0.vp, 6.0.vp)
        .background(BRAND_SOFT_BG, 999.0)
}

/** 简介卡片（左栏，1:1 等宽）：固定高度，长简介内部滚动，绝不溢出卡片。 */
func detailDescriptionCard(state: AppState, book: BookInfo) {
    Panel(style: Some(panelCardStyle(state.themeMode.value))) {
        VStack(spacing: 12.0.vp) {
            Label("简介").bold().fontSize(21.0)
            Divider(color: Some(detailDivider(state.themeMode.value)))
            ScrollView {
                if (book.description.isEmpty()) {
                    Label("暂无简介").fontSize(17.0).muted()
                } else {
                    Label(stripHtmlTags(book.description)).fontSize(17.0).maxLines(999)
                }
            }.fillHeight().flex()
        }.crossAxisAlignment(CrossAxisAlignment.Start).hug().fillWidth()
    }.contentPadding(22.0.vp, 22.0.vp).height(420.0)
}

/** 元数据卡片（右栏，1:1 等宽，与简介卡等高）。 */
func detailMetaCard(state: AppState, book: BookInfo) {
    Panel(style: Some(panelCardStyle(state.themeMode.value))) {
        VStack(spacing: 12.0.vp) {
            Label("书籍信息").bold().fontSize(21.0)
            Divider(color: Some(detailDivider(state.themeMode.value)))
            detailMetaRow("出版社", detailOptText(book.publisher))
            detailMetaRow("出版年份", if (book.year == UInt64(0)) { "？？？" } else { "${book.year}" })
            detailMetaRow("页数", if (book.pages == UInt64(0)) { "？？？" } else { "${book.pages}" })
            detailMetaRow("ISBN", detailOptText(book.identifier))
        }.crossAxisAlignment(CrossAxisAlignment.Start).hug().fillWidth()
    }.contentPadding(20.0.vp, 18.0.vp).height(420.0)
}

/** 元数据行：左标签（弱化色）右值（主文字色）。值用弹性宽度——只有拿到受限宽度
 * 才会按卡片宽度换行，非弹性子项按固有宽度测量会顶出卡片右边框（ISBN 多号拼接即如此）。 */
func detailMetaRow(label: String, value: String) {
    HStack(spacing: 12.0.vp) {
        Label(label).fontSize(16.0).muted()
        Label(value).fontSize(17.0).maxLines(3).textAlign(TextAlign.Trailing).flex()
    }.hug().fillWidth()
}
