/*
 * 下载 / 设置两个一级页面。
 *
 * 设置页含登录表单（邮箱 + 密码）与本地目录说明；
 * 下载页列出本次会话下载的文件。
 */
package seline_read

import std.fs.Path
import chui.*
import seline_ui.*

func downloadsPage(state: AppState): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    VStack(spacing: vp(0.0)) {
        pageHeader("下载", state.downloadDir.value, {=> ()})
        ScrollView {
            VStack(spacing: vp(SELINE_SPACE_SM)) {
                if (!state.downloadMessage.value.isEmpty()) {
                    Label(state.downloadMessage.value).fontSize(theme.fontCaption)
                        .foregroundColor(palette.accent)
                }
                if (state.downloads.value.isEmpty()) {
                    emptyBlock("download", "还没有下载",
                        "打开一本书 → 详情页点「下载」（需要先在设置页登录）")
                } else {
                    for (entry in state.downloads.value) {
                        HStack(spacing: vp(SELINE_SPACE_MD)) {
                            SelineIcon("download", size: 16.0, color: palette.accent)
                            Label(entry.name).fontSize(theme.fontBody)
                            Spacer()
                            Label(entry.sizeText()).fontSize(theme.fontCaption).muted()
                        }.hug().fillWidth()
                            .padding(12.0)
                            .background(palette.surfaceSunken, vp(8.0))
                    }
                }
            }.padding(PAGE_PAD, 8.0, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

func settingsPage(state: AppState): Unit {
    let theme = selineTheme()
    let palette = theme.palette
    VStack(spacing: vp(0.0)) {
        pageHeader("设置", "账号与本地目录", {=> ()})
        ScrollView {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                Label("账号").fontSize(theme.fontHeading).bold()
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
                            SelineButton("刷新配额", {=> state.refreshProfile()},
                                glyph: "refresh", kind: SelineButtonKind.Ghost, compact: true)
                            SelineButton("退出登录", {=> state.logout()},
                                glyph: "person_fill", kind: SelineButtonKind.Ghost,
                                compact: true)
                            Spacer()
                        }.hug().fillWidth()
                    }.hug().fillWidth()
                        .padding(12.0)
                        .background(palette.surfaceSunken, vp(10.0))
                } else {
                    VStack(spacing: vp(SELINE_SPACE_SM)) {
                        Label("用 Z-Library 账号登录后可下载图书（凭证会保存在本机临时目录）")
                            .fontSize(theme.fontCaption).muted().wrap()
                        SelineTextField(state.loginEmail.value,
                            {text => state.loginEmail.value = text},
                            placeholder: "邮箱", glyph: "person_fill", height: 38.0,
                            width: 360.0)
                        SelineTextField(state.loginPassword.value,
                            {text => state.loginPassword.value = text},
                            placeholder: "密码", glyph: "clock_fill", height: 38.0,
                            width: 360.0, secure: true,
                            onSubmit: {=> state.submitLogin()})
                        HStack(spacing: vp(SELINE_SPACE_SM)) {
                            SelineButton("登录", {=> state.submitLogin()},
                                glyph: "person_fill", kind: SelineButtonKind.Secondary,
                                compact: true, busy: state.loginBusy.value)
                            if (!state.loginMessage.value.isEmpty()) {
                                Label(state.loginMessage.value).fontSize(theme.fontCaption)
                                    .muted()
                            }
                            Spacer()
                        }.hug().fillWidth()
                    }.hug().fillWidth()
                        .padding(12.0)
                        .background(palette.surfaceSunken, vp(10.0))
                }

                Label("本地目录").fontSize(theme.fontHeading).bold()
                    .padding(0.0, SELINE_SPACE_SM, 0.0, 0.0)
                Label("封面缓存：${Path(getTempRoot()).join("SelineRead").toString()}").fontSize(theme.fontBody).muted()
                Label("下载目录：${state.downloadDir.value}").fontSize(theme.fontBody).muted()

                Label("数据来源").fontSize(theme.fontHeading).bold()
                    .padding(0.0, SELINE_SPACE_SM, 0.0, 0.0)
                Label("Z-Library eapi · 通过 zlibraryAPI4CJ 访问").fontSize(theme.fontBody)
                    .muted()
                Label(state.status.value).fontSize(theme.fontCaption).muted().wrap()
                if (!state.error.value.isEmpty()) {
                    errorBannerText(state.error.value)
                }
            }.hug().fillWidth().padding(PAGE_PAD, 8.0, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}
