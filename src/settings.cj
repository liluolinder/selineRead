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

/** 设置内容列宽：窗口很宽时也不让卡片横跨整屏（设置项是读的，不是看图的）。 */
let SETTINGS_CONTENT_W: Float32 = 760.0

func settingsPage(state: AppState): Unit {
    VStack(spacing: vp(0.0)) {
        pageHeader("设置", "外观、下载与网络", {=> ()})
        HStack(spacing: vp(SELINE_SPACE_LG)) {
            VStack(spacing: vp(0.0)) {
                // 图标列：文字只在悬浮时以 tooltip 出现（showLabels = false）
                SelineVerticalTabs(SETTINGS_TABS, state.settingsTab.value,
                    {index => state.selectSettingsTab(index)}, width: 56.0,
                    itemHeight: 46.0, showLabels: false, stretch: false)
                Spacer()
            }.hug()
            pageScrollView(scrollState: state.settingsScroll) {
                // 内容固定宽度并水平居中：窗口再宽也不让设置卡片拉满整屏
                HStack(spacing: vp(0.0)) {
                    Spacer()
                    VStack(spacing: vp(SELINE_SPACE_LG)) {
                        if (state.settingsTab.value == 0) {
                            displaySettings(state)
                        } else if (state.settingsTab.value == 1) {
                            downloadSettings(state)
                        } else {
                            networkSettings(state)
                        }
                    }.hug().width(SETTINGS_CONTENT_W)
                    Spacer()
                }.hug().fillWidth()
                    .padding(8.0, SELINE_SPACE_SM, 8.0, 40.0)
            }
            .fillWidth()
        }.hug().fillWidth().fillHeight()
            .padding(PAGE_PAD, 0.0, 8.0, 0.0)
    }.fillWidth().fillHeight()
}

/** 设置页分区卡片：图标方块 + 标题 + 右侧提示 + 内容。 */
func settingsSection(icon: String, title: String, hint!: String = "", body!: () -> Unit): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    VStack(spacing: vp(SELINE_SPACE_MD)) {
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            HStack(spacing: vp(0.0)) {
                SelineIcon(icon, size: 15.0, color: palette.accent)
            }.hug().padding(7.0).background(palette.accentSoft, vp(8.0))
            Label(title).fontSize(theme.fontHeading).bold()
            Spacer()
            if (!hint.isEmpty()) {
                Label(hint).fontSize(theme.fontCaption).muted()
            }
        }.hug().fillWidth()
        body()
    }.hug().fillWidth()
        .padding(18.0)
        .background(palette.surfaceRaised, vp(theme.radiusCard))
}

/** 一行设置：标题/说明在左，控件在右。 */
func settingsRow(title: String, detail!: String = "", control!: () -> Unit): Unit {
    let theme = selineTheme()
    HStack(spacing: vp(SELINE_SPACE_MD)) {
        VStack(spacing: vp(2.0)) {
            Label(title).fontSize(theme.fontBody)
            if (!detail.isEmpty()) {
                Label(detail).fontSize(theme.fontCaption).muted().wrap()
            }
        }.hug()
        Spacer()
        control()
    }.hug().fillWidth().padding(2.0, 8.0, 2.0, 8.0)
}

/** 设置页的一行小提示（图标 + 灰色说明）。 */
func settingsHint(icon: String, text: String): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    HStack(spacing: vp(SELINE_SPACE_SM)) {
        SelineIcon(icon, size: 14.0, color: palette.textFaint)
        Label(text).fontSize(theme.fontCaption).muted().wrap()
    }.hug().fillWidth()
}

/** 站点行左侧的单选圆点。 */
class SettingsRadioDot <: Widget {
    private let selected: Bool
    private var frame = Rect.zero()

    init(selected: Bool) {
        this.selected = selected
        emit(this)
    }

    public func isFlexible(): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(20.0, 20.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let palette = selineTheme().palette
        let ring = if (selected) { palette.accent } else { palette.borderStrong }
        ctx.renderer.strokeCircle(frame.centerX(), frame.centerY(), 8.5, Pen(width: 1.5, color: ring))
        if (selected) {
            paintDot(ctx.renderer, frame.centerX(), frame.centerY(), 4.5, palette.accent)
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

/** 一个可点选的站点行：单选圆点 + 地址 + 当前使用标记（自定义站带删除按钮）。 */
func settingsSiteRow(state: AppState, site: String, isOfficial: Bool): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    let current = state.activeSite.value == site
    // 注意：删除按钮必须放在 TapRegion **外面**（SelineTapRegion 是叶子控件，不向下分发事件，
    // 放在里面会永远点不到）。
    HStack(spacing: vp(SELINE_SPACE_SM)) {
        SelineTapRegion({=> state.selectActiveSite(site)}) {
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SettingsRadioDot(current)
                VStack(spacing: vp(1.0)) {
                    Label(displaySiteUrl(site)).fontSize(theme.fontBody)
                        .foregroundColor(if (current) { palette.accent } else { palette.text })
                    Label(if (isOfficial) { "内置 · 不可编辑" } else { "自定义 · 失败自动换域名" })
                        .fontSize(theme.fontCaption).muted()
                }.hug()
                Spacer()
                if (current) {
                    SelineBadge("当前使用", fill: palette.surfaceRaised,
                        foreground: palette.accent, border: palette.border)
                }
            }.hug().fillWidth()
        }
        if (!isOfficial) {
            SelineIconButton("trash", {=> state.removeCustomSite(site)}, side: 28.0,
                tint: palette.textMuted, tooltip: "删除这个站点")
        }
    }.hug().fillWidth().padding(12.0, 9.0, 12.0, 9.0)
        .background(if (current) { palette.accentSoft } else { palette.surfaceSunken },
            vp(theme.radiusSmall))
}

/** 显示设置：深浅色 + 数据目录。 */
func displaySettings(state: AppState): Unit {
    settingsSection("moon", "外观", hint: "跟随窗口，不需要重启") {
        settingsRow("主题", detail: "深色更省眼；切换时从按钮位置向外辐射过渡") {
            SelineSegmented(["深色", "浅色"],
                if (state.darkMode.value) { 0 } else { 1 },
                {index =>
                    let wantDark = index == 0
                    if (wantDark != state.darkMode.value) {
                        state.toggleTheme(100.0, 200.0)
                    }
                }, minSegment: 72.0)
        }
    }
    settingsSection("folder", "数据与配置", hint: "全部保存在本地") {
        settingsRow("配置目录", detail: appDataDir().toString()) {
            SelineButton("打开", {=> selineOpenFolder(appDataDir().toString())},
                glyph: "folder-open", kind: SelineButtonKind.Ghost, compact: true)
        }
        selineDivider()
        settingsRow("下载目录", detail: state.downloadDir.value) {
            SelineButton("打开", {=> selineOpenFolder(state.downloadDir.value)},
                glyph: "folder-open", kind: SelineButtonKind.Ghost, compact: true)
        }
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
/** 下载设置：下载目录 + 引擎限制说明。 */
func downloadSettings(state: AppState): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    settingsSection("download", "下载目录", hint: "不存在会自动创建") {

        HStack(spacing: vp(SELINE_SPACE_SM)) {
            SelineTextField(state.downloadPathInput.value,
                {text => state.downloadPathInput.value = text},
                placeholder: state.downloadDir.value, glyph: "folder", height: 38.0,
                width: 460.0, onSubmit: {=> state.applyDownloadPath()})
            SelineButton("保存", {=> state.applyDownloadPath()}, glyph: "check",
                kind: SelineButtonKind.Secondary, compact: true)
            SelineButton("打开文件夹", {=> selineOpenFolder(state.downloadDir.value)},
                glyph: "folder-open", kind: SelineButtonKind.Ghost, compact: true)
            Spacer()
        }.hug().fillWidth()
    }
    settingsSection("warn", "下载说明", hint: "zlib 链接的限制") {
        settingsHint("warn", "zlib 的下载链接不支持 Range / 多线程，所以是单线程下载。")
        settingsHint("warn", "「停止」后需要重新下载，不会从中间继续。")
        settingsHint("about", "失败原因会写进下载页与 ~/.seline-app/SelineRead/download-log.log。")
    }
}

/** 网络设置：官方地址（前端内置 3 个）+ 自定义站（数组）+ 种子站（单值，仅对自定义站生效）。 */
func networkSettings(state: AppState): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    settingsSection("cloud", "官方地址", hint: "内置 3 个，不可编辑") {
        settingsHint("warn", "官方地址不可达时直接报「网络链接失败」，不会用种子站回退。")
        VStack(spacing: vp(6.0)) {
            for (site in state.officialSites.value) {
                settingsSiteRow(state, site, true)
            }
        }.hug().fillWidth()
    }
    settingsSection("globe", "自定义站点", hint: "数组，可增删") {
        settingsHint("about", "选中的自定义站访问失败时：用种子站查询新域名，成功后覆盖这一条。")
        if (state.customSites.value.isEmpty()) {
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SelineIcon("globe", size: 15.0, color: palette.textFaint)
                Label("还没有自定义站点").fontSize(theme.fontCaption).muted()
                Spacer()
            }.hug().fillWidth().padding(12.0, 10.0, 12.0, 10.0)
                .background(palette.surfaceSunken, vp(theme.radiusSmall))
        } else {
            VStack(spacing: vp(6.0)) {
                for (site in state.customSites.value) {
                    settingsSiteRow(state, site, false)
                }
            }.hug().fillWidth()
        }
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            SelineTextField(state.siteInput.value,
                {text => state.siteInput.value = text},
                placeholder: "https://example.com", glyph: "cloud", height: 36.0,
                width: 340.0, onSubmit: {=> state.addCustomSite()})
            SelineButton("添加站点", {=> state.addCustomSite()}, glyph: "plus",
                kind: SelineButtonKind.Secondary, compact: true)
            Spacer()
        }.hug().fillWidth()
    }
    settingsSection("link", "种子站", hint: "单值，仅对自定义站点生效") {
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            SelineIcon("link", size: 15.0, color: palette.accent)
            Label(displaySiteUrl(state.seedSite.value)).fontSize(theme.fontBody)
            Spacer()
            if (state.activeSiteIsOfficial()) {
                SelineBadge("暂不生效", fill: palette.surfaceSunken,
                    foreground: palette.textMuted, border: palette.border)
            } else {
                SelineBadge("生效中", fill: palette.accentSoft, foreground: palette.accent,
                    border: palette.border)
            }
        }.hug().fillWidth().padding(12.0, 10.0, 12.0, 10.0)
            .background(palette.surfaceSunken, vp(theme.radiusSmall))
        if (state.activeSiteIsOfficial()) {
            settingsHint("warn", "当前选中的是官方地址：种子站不参与回退；改选自定义站点后生效。")
        }
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            SelineTextField(state.seedInput.value,
                {text => state.seedInput.value = text},
                placeholder: state.seedSite.value, glyph: "cloud", height: 36.0,
                width: 340.0, onSubmit: {=> state.applySeedSite()})
            SelineButton("保存种子站", {=> state.applySeedSite()}, glyph: "check",
                kind: SelineButtonKind.Secondary, compact: true)
            Spacer()
        }.hug().fillWidth()
        if (!state.networkMessage.value.isEmpty()) {
            settingsHint("check", state.networkMessage.value)
        }
        selineDivider()
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            SelineButton("重新拉取站点", {=> state.refreshSiteNow()}, glyph: "refresh",
                kind: SelineButtonKind.Ghost, compact: true)
            Label("状态：${state.status.value}").fontSize(theme.fontCaption).muted()
            Spacer()
        }.hug().fillWidth()
    }
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
