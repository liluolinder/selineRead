/*
 * 设置页与下载管理器页。
 *
 * 设置页：左侧竖直页签（显示设置 / 下载设置 / 网络设置），右侧内容区。
 * 下载页：selineDownload 的任务列表，带进度、速度、停止按钮。
 */
package seline_read

import std.collection.ArrayList
import std.fs.Path
import chui.*
import seline_ui.*

/* -------------------------------------------------- 设置页 */

let SETTINGS_TABS: Array<SelineRailItem> = [
    SelineRailItem("显示设置", "moon", "moon"),
    SelineRailItem("下载设置", "download", "download"),
    SelineRailItem("网络设置", "cloud", "cloud")
]

func settingsPage(state: AppState): Unit {
    let theme = selineTheme()
    VStack(spacing: vp(0.0)) {
        pageHeader("设置", "", {=> ()})
        HStack(spacing: vp(SELINE_SPACE_LG)) {
            VStack(spacing: vp(0.0)) {
                // 图标列：文字只在悬浮时以 tooltip 出现（showLabels = false）
                SelineVerticalTabs(SETTINGS_TABS, state.settingsTab.value,
                    {index => state.selectSettingsTab(index)}, width: 56.0,
                    itemHeight: 46.0, showLabels: false, stretch: false)
                Spacer()
            }.hug()
            pageScrollView(scrollState: state.settingsScroll) {
                VStack(spacing: vp(SELINE_SPACE_MD)) {
                    if (state.settingsTab.value == 0) {
                        displaySettings(state)
                    } else if (state.settingsTab.value == 1) {
                        downloadSettings(state)
                    } else {
                        networkSettings(state)
                    }
                }.hug().fillWidth().padding(0.0, 4.0, PAGE_PAD, 32.0)
            }
            .fillWidth()
        }.hug().fillWidth().fillHeight()
            .padding(PAGE_PAD, 0.0, 8.0, 0.0)
    }.fillWidth().fillHeight()
}

/** 显示设置：深浅色 + 账号（下载需要登录）。 */
func displaySettings(state: AppState): Unit {
    let theme = selineTheme()
    sectionCard("外观") {
        HStack(spacing: vp(SELINE_SPACE_MD)) {
            Label("主题").fontSize(theme.fontBody)
            Spacer()
            SelineSegmented(["深色", "浅色"],
                if (state.darkMode.value) { 0 } else { 1 },
                {index =>
                    let wantDark = index == 0
                    if (wantDark != state.darkMode.value) {
                        state.toggleTheme(100.0, 200.0)
                    }
                }, minSegment: 70.0)
        }.hug().fillWidth()
    }
}

/** 账号页：一个列表管所有账号，当前账号高亮。 */
func accountPage(state: AppState): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    VStack(spacing: vp(0.0)) {
        pageHeader("账号", "", {=>
            SelineButton("添加账号", {=> state.openLoginDialog()}, glyph: "plus",
                kind: SelineButtonKind.Secondary, compact: true)
        })
        pageScrollView(scrollState: state.accountScroll) {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                VStack(spacing: vp(SELINE_SPACE_SM)) {
                    if (state.accounts.value.isEmpty()) {
                        HStack(spacing: vp(SELINE_SPACE_MD)) {
                            AccountAvatar("", 44.0)
                            VStack(spacing: vp(2.0)) {
                                Label("还没有保存的账号").fontSize(theme.fontBody).bold()
                                Label("点右上角「添加账号」登录 Z-Library")
                                    .fontSize(theme.fontCaption).muted()
                            }.hug()
                            Spacer()
                            SelineButton("登录", {=> state.openLoginDialog()},
                                glyph: "person_fill", kind: SelineButtonKind.Secondary,
                                compact: true)
                        }.hug().fillWidth().padding(12.0)
                    }
                    for (entry in state.accounts.value) {
                        accountRow(state, entry)
                    }
                }.hug().fillWidth()
            }.hug().fillWidth().padding(PAGE_PAD, 8.0, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

/** 一条账号：头像 + 身份 + 当前账号的额度；当前项高亮（底色 + 强调色）。 */
func accountRow(state: AppState, entry: AccountEntry): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    let isCurrent = state.loggedIn.value && state.accountId.value == entry.userId
    VStack(spacing: vp(SELINE_SPACE_SM)) {
        HStack(spacing: vp(SELINE_SPACE_MD)) {
            AccountAvatar(entry.label(), 44.0, accent: isCurrent)
            VStack(spacing: vp(2.0)) {
                HStack(spacing: vp(SELINE_SPACE_XS)) {
                    Label(entry.label()).fontSize(theme.fontBody).bold()
                    if (entry.isDefault) {
                        Label("默认").fontSize(theme.fontCaption)
                            .foregroundColor(palette.accent)
                    }
                    if (isCurrent) {
                        Label("当前").fontSize(theme.fontCaption)
                            .foregroundColor(palette.accent)
                    }
                }.hug()
                Label(if (entry.email.isEmpty()) {
                    "uid ${entry.userId}"
                } else {
                    "${entry.email} · uid ${entry.userId}"
                }).fontSize(theme.fontCaption).muted()
            }.hug()
            Spacer()
            if (!isCurrent) {
                SelineButton("切换", {=> state.switchToAccount(entry.userId)},
                    glyph: "refresh", kind: SelineButtonKind.Secondary, compact: true)
            }
            if (!entry.isDefault) {
                SelineButton("设为默认", {=> state.setDefaultAccount(entry.userId)},
                    kind: SelineButtonKind.Ghost, compact: true)
            }
            // 当前账号也用「删除」：删掉当前账号会自动退出登录
            SelineButton("删除", {=> state.removeAccount(entry.userId)},
                glyph: "close", kind: SelineButtonKind.Ghost, compact: true)
        }.hug().fillWidth()
        if (isCurrent) {
            // 当前账号的今日额度：数字 + 进度条 + 刷新
            VStack(spacing: vp(6.0)) {
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    SelineIcon("download", size: 15.0, color: palette.accent)
                    Label(if (state.quotaKnown.value) {
                        "今日下载 ${state.quotaToday.value} / ${state.quotaLimit.value}"
                    } else if (state.quotaLoading.value) {
                        "正在获取额度…"
                    } else {
                        "今日下载 — / —"
                    }).fontSize(theme.fontCaption).muted()
                    if (state.quotaKnown.value && state.quotaLimit.value > 0) {
                        let left = if (state.quotaLimit.value > state.quotaToday.value) {
                            state.quotaLimit.value - state.quotaToday.value
                        } else {
                            0
                        }
                        Label("剩余 ${left} 次").fontSize(theme.fontCaption).muted()
                    }
                    Spacer()
                    SelineButton("刷新", {=> state.refreshProfile()}, glyph: "refresh",
                        kind: SelineButtonKind.Ghost, compact: true,
                        busy: state.quotaLoading.value)
                }.hug().fillWidth()
                if (state.quotaKnown.value && state.quotaLimit.value > 0) {
                    DownloadProgressBar(
                        percent: Float32(state.quotaToday.value) /
                            Float32(state.quotaLimit.value) * 100.0,
                        height: 6.0, track: palette.border)
                }
            }.hug().fillWidth().padding(10.0)
                .background(palette.surfaceSunken, vp(8.0))
        }
    }.hug().fillWidth()
        .padding(12.0)
        .background(if (isCurrent) { palette.accentSoft } else { palette.surfaceRaised },
            vp(10.0))
}
/** 圆形账号头像：取名字首字，没有名字就画人形图标。 */
class AccountAvatar <: Widget {
    private let name: String
    private let diameter: Float32
    private let accent: Bool
    private var frame = Rect.zero()

    init(name: String, diameter: Float32, accent!: Bool = false) {
        this.name = name
        this.diameter = diameter
        this.accent = accent
        emit(this)
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }

    public func isFlexible(): Bool {
        false
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(diameter, diameter)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let theme = selineTheme()
        let palette = theme.palette
        paintSurface(ctx.renderer, frame,
            if (accent) { palette.accent } else { palette.surfaceSunken }, frame.w * 0.5)
        let initial = firstRuneText(name)
        if (initial.isEmpty()) {
            drawGlyph(ctx.renderer, "person_fill",
                centeredSquare(frame.centerX(), frame.centerY(), frame.w * 0.46),
                if (accent) { palette.onAccent } else { palette.textMuted }, 2.0)
            return
        }
        paintText(ctx.renderer, initial, frame,
            if (accent) { palette.onAccent } else { palette.text },
            theme.fontHeading, style: selineFontStyle(bold: true),
            align: SelineTextAlign.Center)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

/** 取字符串首个字符（按 Rune，中文/emoji 不会被截断）。 */
func firstRuneText(text: String): String {
    let runes = text.trimAscii().toRuneArray()
    if (runes.size == 0) {
        return ""
    }
    runes[0].toString().toAsciiUpper()
}
/**
 * 登录弹窗。
 *
 * 半透明遮罩铺满窗口（同时吞掉底层点击），中间一张卡片：
 * 邮箱 / 密码 / 登录 / 取消。登录成功后由状态层写账号列表并自动关闭。
 */
func loginDialogPanel(state: AppState): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    ZStack {
        DialogScrim({=> state.closeLoginDialog()})
        VStack(spacing: vp(0.0)) {
            Spacer()
            HStack(spacing: vp(0.0)) {
            Spacer()
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                Label("登录 Z-Library").fontSize(theme.fontHeading).bold()
            Label("登录后可下载图书；账号会保存到 ~/.seline-app/SelineRead，可随时切换。")
                .fontSize(theme.fontCaption).muted().wrap()
            SelineTextField(state.loginEmail.value,
                {text => state.loginEmail.value = text},
                placeholder: "邮箱", glyph: "person_fill", height: 38.0, width: 340.0)
            SelineTextField(state.loginPassword.value,
                {text => state.loginPassword.value = text},
                placeholder: "密码", glyph: "clock_fill", height: 38.0, width: 340.0,
                secure: true, onSubmit: {=> state.submitLogin()})
            if (!state.loginMessage.value.isEmpty() && state.loginMessage.value.contains("失败")) {
                Label(state.loginMessage.value).fontSize(theme.fontCaption)
                    .foregroundColor(palette.danger).wrap()
            }
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                Spacer()
                SelineButton("取消", {=> state.closeLoginDialog()}, kind: SelineButtonKind.Ghost,
                    compact: true)
                SelineButton("登录", {=> state.submitLogin()}, glyph: "person_fill",
                    kind: SelineButtonKind.Secondary, compact: true, busy: state.loginBusy.value)
            }.hug().fillWidth()
            }.hug().width(400.0)
                .padding(24.0, 22.0, 24.0, 22.0)
                .background(palette.surfaceRaised, vp(16.0))
            Spacer()
            }.hug().fillWidth()
            Spacer()
        }.fillWidth().fillHeight()
    }.fillWidth().fillHeight()
}

/** 弹窗遮罩：画一层 scrim，并且吞掉点击（点空白处关闭）。 */
class DialogScrim <: Widget {
    private let onDismiss: () -> Unit
    private var frame = Rect.zero()

    init(onDismiss: () -> Unit) {
        this.onDismiss = onDismiss
        emit(this)
    }

    public func isFlexible(): Bool {
        true
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (frame.w > 0.0 && frame.h > 0.0) {
            ctx.renderer.fill(frame, selineTheme().palette.scrim)
        }
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, _, _) =>
                onDismiss()
                true
            case UiEvent.MouseUp(_, _, _) => true
            case UiEvent.MouseWheel(_, _, _, _) => true
            case _ => false
        }
    }
}
/** 下载设置：下载目录。 */
func downloadSettings(state: AppState): Unit {
    let theme = selineTheme()
    sectionCard("下载目录") {
        VStack(spacing: vp(SELINE_SPACE_SM)) {
            Label("下载的文件保存在这个目录（不存在会自动创建）")
                .fontSize(theme.fontCaption).muted().wrap()
            SelineTextField(state.downloadPathInput.value,
                {text => state.downloadPathInput.value = text},
                placeholder: state.downloadDir.value, glyph: "folder", height: 38.0,
                width: 420.0, onSubmit: {=> state.applyDownloadPath()})
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SelineButton("保存目录", {=> state.applyDownloadPath()}, glyph: "download",
                    kind: SelineButtonKind.Secondary, compact: true)
                Label("当前：${state.downloadDir.value}").fontSize(theme.fontCaption).muted()
                Spacer()
            }.hug().fillWidth()
        }.hug().fillWidth()
    }
    sectionCard("说明") {
        Label("zlib 的下载链接不支持断点续传与多线程，所以下载是单线程的；" +
            "「停止」后需要重新下载，不会从中间继续。")
            .fontSize(theme.fontCaption).muted().wrap()
    }
}

/** 网络设置：官方地址（前端内置 3 个）+ 自定义站（数组）+ 种子站（单值，仅对自定义站生效）。 */
func networkSettings(state: AppState): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    sectionCard("官方地址（内置 3 个，仅前端定义，不可编辑）") {
        VStack(spacing: vp(SELINE_SPACE_XS)) {
            Label("内置 3 个官方地址，点一下设为当前站点。官方地址不可达时直接报错（不走种子站回退）。")
                .fontSize(theme.fontCaption).muted().wrap()
            for (site in state.officialSites.value) {
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    SelineOptionRow(displaySiteUrl(site), if (state.activeSite.value == site) {
                        "当前使用"
                    } else {
                        "点击切换"
                    }, state.activeSite.value == site,
                        {=> state.selectActiveSite(site)}, width: 520.0)
                    Spacer()
                }.hug().fillWidth()
            }
        }.hug().fillWidth()
    }
    sectionCard("自定义站点（数组，可增删）") {
        VStack(spacing: vp(SELINE_SPACE_SM)) {
            if (state.customSites.value.isEmpty()) {
                Label("还没有自定义站点").fontSize(theme.fontCaption).muted()
            } else {
                Label("选中的自定义站访问失败时：用种子站查询新域名，成功后覆盖这一条（下次启动直接用新地址）。")
                    .fontSize(theme.fontCaption).muted().wrap()
            }
            for (site in state.customSites.value) {
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    SelineOptionRow(displaySiteUrl(site), if (state.activeSite.value == site) {
                        "当前使用"
                    } else {
                        "点击切换"
                    }, state.activeSite.value == site,
                        {=> state.selectActiveSite(site)}, width: 520.0)
                    Spacer()
                    SelineButton("删除", {=> state.removeCustomSite(site)}, glyph: "close",
                        kind: SelineButtonKind.Ghost, compact: true)
                }.hug().fillWidth()
            }
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SelineTextField(state.siteInput.value,
                    {text => state.siteInput.value = text},
                    placeholder: "https://example.com", glyph: "cloud", height: 36.0,
                    width: 320.0, onSubmit: {=> state.addCustomSite()})
                SelineButton("添加站点", {=> state.addCustomSite()}, glyph: "plus",
                    kind: SelineButtonKind.Secondary, compact: true)
                Spacer()
            }.hug().fillWidth()
        }.hug().fillWidth()
    }
    sectionCard("种子站（单值，仅对自定义站点生效）") {
        VStack(spacing: vp(SELINE_SPACE_SM)) {
            Label("种子站是「引导站」：仅当当前选中的是自定义站、且该站访问失败时，才向它查询最新域名；" +
                "拿到新域名后覆盖这一条自定义站。官方地址失败不走种子站。")
                .fontSize(theme.fontCaption).muted().wrap()
            if (state.activeSiteIsOfficial()) {
                Label("当前选中的是官方地址：种子站暂不生效。").fontSize(theme.fontCaption)
                    .foregroundColor(palette.accent)
            }
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SelineIcon("cloud", size: 14.0, color: palette.accent)
                Label(if (state.seedSite.value.isEmpty()) {
                    "未配置（使用默认站）"
                } else {
                    state.seedSite.value
                }).fontSize(theme.fontBody)
                Spacer()
            }.hug().fillWidth()
                .padding(10.0)
                .background(palette.surfaceSunken, vp(8.0))
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SelineTextField(state.seedInput.value,
                    {text => state.seedInput.value = text},
                    placeholder: state.seedSite.value, glyph: "cloud", height: 36.0,
                    width: 320.0, onSubmit: {=> state.applySeedSite()})
                SelineButton("保存种子站", {=> state.applySeedSite()}, glyph: "check",
                    kind: SelineButtonKind.Secondary, compact: true)
                Spacer()
            }.hug().fillWidth()
            if (!state.networkMessage.value.isEmpty()) {
                Label(state.networkMessage.value).fontSize(theme.fontCaption)
                    .foregroundColor(palette.accent)
            }
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SelineButton("重新拉取站点（仅自定义站）", {=> state.refreshSiteNow()}, glyph: "refresh",
                    kind: SelineButtonKind.Ghost, compact: true)
                Label("状态：${state.status.value}").fontSize(theme.fontCaption).muted()
                Spacer()
            }.hug().fillWidth()
        }.hug().fillWidth()
    }
}

/** 统一的设置分区卡片（标题 + 圆角底色）。 */
func sectionCard(title: String, body!: () -> Unit): Unit {
    let theme = selineTheme()
    VStack(spacing: vp(SELINE_SPACE_SM)) {
        Label(title).fontSize(theme.fontHeading).bold()
        body()
    }.hug().fillWidth()
        .padding(14.0)
        .background(theme.palette.surfaceRaised, vp(12.0))
}

/* -------------------------------------------------- 下载管理器页 */

func downloadsPage(state: AppState): Unit {
    // 下载页不要页头（标题 / 路径 / 清空已结束 三个都去掉）：侧栏「下载」已经表明页面，
    // 列表直接从顶部开始；右下角放一个圆形悬浮按钮打开下载文件夹。
    if (state.downloadItems.value.isEmpty()) {
        // 空态：上下两段 Spacer 把「还没有下载」顶到页面正中
        ZStack {
            VStack(spacing: vp(0.0)) {
                Spacer()
                emptyBlock("download", "还没有下载",
                    "打开一本书 → 详情页点「下载」（需要先在「账号」页登录）")
                Spacer()
            }.fillWidth().fillHeight()
            SelineFab("folder-open", {=> selineOpenFolder(state.downloadDir.value)})
        }.alignment(Alignment.BottomTrailing).fillWidth().fillHeight()
    } else {
        ZStack {
            pageScrollView(scrollState: state.downloadsScroll) {
                VStack(spacing: vp(SELINE_SPACE_SM)) {
                    for (item in state.downloadItems.value) {
                        downloadRow(state, item)
                    }
                }.padding(PAGE_PAD, 16.0, PAGE_PAD, 32.0)
            }.fillWidth().fillHeight()
            SelineFab("folder-open", {=> selineOpenFolder(state.downloadDir.value)})
        }.alignment(Alignment.BottomTrailing).fillWidth().fillHeight()
    }
}

/** 一条下载记录：标题 + 进度条 + 状态/速度 + 停止。 */
func downloadRow(state: AppState, item: DownloadItem): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    HStack(spacing: vp(SELINE_SPACE_MD)) {
        // 左侧书本封面缩略图（2:3）：没有封面 URL 时 drawBookCover 会画默认封面
        DownloadCoverThumb(state, item.cover, 44.0)
        VStack(spacing: vp(4.0)) {
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                Label(item.title).fontSize(theme.fontBody).bold()
                Label(item.status).fontSize(theme.fontCaption)
                    .foregroundColor(if (item.status == DL_FAILED) {
                        palette.danger
                    } else {
                        palette.textMuted
                    })
                Spacer()
                Label(item.progressText()).fontSize(theme.fontCaption).muted()
            }.hug().fillWidth()
            DownloadProgressBar(percent: item.percent(), height: 6.0)
            if (!item.error.isEmpty()) {
                Label(item.error).fontSize(theme.fontCaption)
                    .foregroundColor(palette.danger).wrap()
            }
        }.flex()
        if (item.active()) {
            SelineButton("停止", {=> state.stopDownload(item.taskId)}, glyph: "close",
                kind: SelineButtonKind.Ghost, compact: true)
        }
    }.hug().fillWidth()
        .padding(12.0)
        .background(palette.surfaceRaised, vp(10.0))
}

/** 下载行左侧的小封面（2:3，与书籍卡片同一套封面管线）。 */
class DownloadCoverThumb <: Widget {
    private let state: AppState
    private let url: String
    private let thumbWidth: Float32
    private var frame = Rect.zero()

    init(state: AppState, url: String, width: Float32) {
        this.state = state
        this.url = url
        this.thumbWidth = width
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(thumbWidth, thumbWidth / BOOK_COVER_ASPECT)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawBookCover(ctx, state, url, frame, 6.0)
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

/** 细进度条。 */
class DownloadProgressBar <: Widget {
    private let percent: Float32
    private let barHeight: Float32
    private let trackColor: ?Color
    private var frame = Rect.zero()

    init(percent!: Float32, height!: Float32, track!: ?Color = None) {
        this.percent = percent
        this.barHeight = height
        this.trackColor = track
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, barHeight)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let palette = selineTheme().palette
        let radius = barHeight * 0.5
        let track = match (trackColor) {
            case Some(value) => value
            case None => palette.surfaceSunken
        }
        paintSurface(ctx.renderer, frame, track, radius)
        let filled = frame.w * clamp01(percent / 100.0)
        if (filled > 0.5) {
            paintSurface(ctx.renderer,
                Rect(frame.x, frame.y, max(filled, barHeight), frame.h),
                palette.accent, radius)
        }
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
