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
        pageHeader("设置", "显示 · 下载 · 网络", {=> ()})
        HStack(spacing: vp(SELINE_SPACE_LG)) {
            VStack(spacing: vp(0.0)) {
                SelineVerticalTabs(SETTINGS_TABS, state.settingsTab.value,
                    {index => state.selectSettingsTab(index)}, width: 150.0,
                    itemHeight: 44.0, showLabels: true, stretch: false)
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
    accountCard(state)
}

/** 账号卡片：登录 / 退出。 */
func accountCard(state: AppState): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    sectionCard("账号") {
        if (state.loggedIn.value) {
            VStack(spacing: vp(4.0)) {
                Label(if (state.accountName.value.isEmpty()) {
                    "已登录"
                } else {
                    state.accountName.value
                }).fontSize(theme.fontBody).bold()
                Label("uid ${state.accountId.value}").fontSize(theme.fontCaption).muted()
                if (!state.loginMessage.value.isEmpty()) {
                    Label(state.loginMessage.value).fontSize(theme.fontCaption).muted()
                }
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    SelineButton("刷新配额", {=> state.refreshProfile()}, glyph: "refresh",
                        kind: SelineButtonKind.Ghost, compact: true)
                    SelineButton("退出登录", {=> state.logout()}, glyph: "person_fill",
                        kind: SelineButtonKind.Ghost, compact: true)
                    Spacer()
                }.hug().fillWidth()
            }.hug().fillWidth()
        } else {
            VStack(spacing: vp(SELINE_SPACE_SM)) {
                Label("用 Z-Library 账号登录后可下载图书（凭证保存在本机临时目录）")
                    .fontSize(theme.fontCaption).muted().wrap()
                SelineTextField(state.loginEmail.value, {text => state.loginEmail.value = text},
                    placeholder: "邮箱", glyph: "person_fill", height: 38.0, width: 360.0)
                SelineTextField(state.loginPassword.value,
                    {text => state.loginPassword.value = text},
                    placeholder: "密码", glyph: "clock_fill", height: 38.0,
                    width: 360.0, secure: true, onSubmit: {=> state.submitLogin()})
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    SelineButton("登录", {=> state.submitLogin()}, glyph: "person_fill",
                        kind: SelineButtonKind.Secondary, compact: true,
                        busy: state.loginBusy.value)
                    if (!state.loginMessage.value.isEmpty()) {
                        Label(state.loginMessage.value).fontSize(theme.fontCaption).muted()
                    }
                    Spacer()
                }.hug().fillWidth()
            }.hug().fillWidth()
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

/** 网络设置：官方站（占位、不可删）+ 自定义站 + 种子站。 */
func networkSettings(state: AppState): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    sectionCard("官方站点（预留，不可删除）") {
        VStack(spacing: vp(SELINE_SPACE_XS)) {
            Label("官方站占位，后续填入默认地址；也可以直接在下面添加自定义站。")
                .fontSize(theme.fontCaption).muted().wrap()
            for (index in 0..3) {
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    SelineIcon("cloud", size: 14.0, color: palette.textFaint)
                    Label("官方站点 ${index + 1}（待配置）").fontSize(theme.fontBody).muted()
                    Spacer()
                }.hug().fillWidth()
                    .padding(10.0)
                    .background(palette.surfaceSunken, vp(8.0))
            }
        }.hug().fillWidth()
    }
    sectionCard("自定义站点（单选框选当前使用的站点）") {
        VStack(spacing: vp(SELINE_SPACE_SM)) {
            if (state.customSites.value.isEmpty()) {
                Label("还没有自定义站点").fontSize(theme.fontCaption).muted()
            }
            for (site in state.customSites.value) {
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    SelineOptionRow(site, if (state.activeSite.value == site) {
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
    sectionCard("种子站（自定义站访问失败时用它换新地址）") {
        VStack(spacing: vp(SELINE_SPACE_SM)) {
            Label("回退成功后，种子站返回的新地址会覆盖当前的自定义站点，" +
                "下次启动直接用新地址。")
                .fontSize(theme.fontCaption).muted().wrap()
            if (state.seedSites.value.isEmpty()) {
                Label("没有配置种子站（默认使用官方站）").fontSize(theme.fontCaption).muted()
            }
            for (seed in state.seedSites.value) {
                HStack(spacing: vp(SELINE_SPACE_SM)) {
                    SelineIcon("cloud", size: 14.0, color: palette.accent)
                    Label(seed).fontSize(theme.fontBody)
                    Spacer()
                    SelineButton("删除", {=> state.removeSeedSite(seed)}, glyph: "close",
                        kind: SelineButtonKind.Ghost, compact: true)
                }.hug().fillWidth()
                    .padding(10.0)
                    .background(palette.surfaceSunken, vp(8.0))
            }
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SelineTextField(state.seedInput.value,
                    {text => state.seedInput.value = text},
                    placeholder: "https://seed.example.com", glyph: "cloud", height: 36.0,
                    width: 320.0, onSubmit: {=> state.addSeedSite()})
                SelineButton("添加种子站", {=> state.addSeedSite()}, glyph: "plus",
                    kind: SelineButtonKind.Secondary, compact: true)
                Spacer()
            }.hug().fillWidth()
            if (!state.networkMessage.value.isEmpty()) {
                Label(state.networkMessage.value).fontSize(theme.fontCaption)
                    .foregroundColor(palette.accent)
            }
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SelineButton("重新拉取站点", {=> state.refreshSiteNow()}, glyph: "refresh",
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
    let theme = selineTheme()
    let palette = theme.palette
    VStack(spacing: vp(0.0)) {
        pageHeader("下载", state.downloadDir.value, {=>
            HStack(spacing: vp(SELINE_SPACE_SM)) {
                SelineButton("清空已结束", {=> state.clearFinishedDownloads()}, glyph: "close",
                    kind: SelineButtonKind.Ghost, compact: true)
            }
        })
        pageScrollView(scrollState: state.downloadsScroll) {
            VStack(spacing: vp(SELINE_SPACE_SM)) {
                if (!state.downloadMessage.value.isEmpty()) {
                    Label(state.downloadMessage.value).fontSize(theme.fontCaption)
                        .foregroundColor(palette.accent)
                }
                if (state.downloadItems.value.isEmpty()) {
                    emptyBlock("download", "还没有下载",
                        "打开一本书 → 详情页点「下载」（需要先在设置页登录）")
                } else {
                    for (item in state.downloadItems.value) {
                        downloadRow(state, item)
                    }
                }
            }.padding(PAGE_PAD, 8.0, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

/** 一条下载记录：标题 + 进度条 + 状态/速度 + 停止。 */
func downloadRow(state: AppState, item: DownloadItem): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    HStack(spacing: vp(SELINE_SPACE_MD)) {
        SelineIcon(if (item.status == DL_COMPLETED) { "check" } else { "download" },
            size: 16.0, color: if (item.status == DL_FAILED) {
                palette.danger
            } else if (item.status == DL_COMPLETED) {
                palette.accent
            } else {
                palette.textMuted
            })
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

/** 细进度条。 */
class DownloadProgressBar <: Widget {
    private let percent: Float32
    private let barHeight: Float32
    private var frame = Rect.zero()

    init(percent!: Float32, height!: Float32) {
        this.percent = percent
        this.barHeight = height
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
        paintSurface(ctx.renderer, frame, palette.surfaceSunken, radius)
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
