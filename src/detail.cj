/*
 * 图书详情页（二级页面）：封面 + 元信息 + 下载 + 可选格式 + 简介。
 *
 * 数据由 `AppState.openBook` 在后台拉取，页面只读 State；
 * 首帧直接显示列表项已有的标题/作者/封面，不阻塞打开动作。
 */
package seline_read

import chui.*
import seline_ui.*

func detailPage(state: AppState): Unit {
    let theme = selineTheme()
    VStack(spacing: vp(0.0)) {
        HStack(spacing: vp(SELINE_SPACE_SM)) {
            SelineButton("返回", {=> state.closeDetail()}, glyph: "home",
                kind: SelineButtonKind.Ghost, compact: true)
            Spacer()
        }.hug().fillWidth().padding(PAGE_PAD, 12.0, PAGE_PAD, 4.0)
        ScrollView {
            VStack(spacing: vp(SELINE_SPACE_MD)) {
                if (!state.detailError.value.isEmpty()) {
                    errorBannerText(state.detailError.value)
                }
                HStack(spacing: vp(SELINE_SPACE_LG)) {
                    DetailCover(state)
                    VStack(spacing: vp(SELINE_SPACE_XS)) {
                        Label(state.detailTitle.value).fontSize(theme.fontTitle).bold().wrap()
                        Label(if (state.detailAuthor.value.isEmpty()) {
                            "未知作者"
                        } else {
                            state.detailAuthor.value
                        }).fontSize(theme.fontBody).muted()
                        Label(state.detailMeta.value).fontSize(theme.fontCaption).muted()
                        if (state.detailLoading.value) {
                            loadingBlock("正在加载详情…")
                        }
                        HStack(spacing: vp(SELINE_SPACE_SM)) {
                            SelineButton("下载", {=> state.downloadBook()}, glyph: "download",
                                kind: SelineButtonKind.Secondary, compact: true,
                                busy: state.downloading.value)
                            if (!state.loggedIn.value) {
                                Label("下载需要先在「设置」页登录").fontSize(theme.fontCaption)
                                    .muted()
                            }
                            Spacer()
                        }.hug().fillWidth()
                            .padding(0.0, 4.0, 0.0, 0.0)
                        if (!state.downloadMessage.value.isEmpty()) {
                            Label(state.downloadMessage.value).fontSize(theme.fontCaption)
                                .foregroundColor(theme.palette.accent)
                        }
                    }.hug()
                    Spacer()
                }.hug().fillWidth()
                if (!state.detailDescription.value.isEmpty()) {
                    VStack(spacing: vp(SELINE_SPACE_XS)) {
                        Label("简介").fontSize(theme.fontHeading).bold()
                        Label(state.detailDescription.value).fontSize(theme.fontBody).wrap()
                    }.hug().fillWidth()
                }
                if (!state.detailFormats.value.isEmpty()) {
                    VStack(spacing: vp(SELINE_SPACE_XS)) {
                        Label("可选格式").fontSize(theme.fontHeading).bold()
                        HStack(spacing: vp(SELINE_SPACE_SM)) {
                            FormatChip("默认", "", state.detailFormatIndex.value == 0,
                                {=> state.detailFormatIndex.value = 0})
                            var index: Int64 = 0
                            for (format in state.detailFormats.value) {
                                let position = index + 1
                                FormatChip(format.extension, format.sizeText(),
                                    state.detailFormatIndex.value == position,
                                    {=> state.detailFormatIndex.value = position})
                                index += 1
                            }
                            Spacer()
                        }.hug().fillWidth()
                    }.hug().fillWidth()
                }
            }.padding(PAGE_PAD, 8.0, PAGE_PAD, 32.0)
        }
    }.fillWidth().fillHeight()
}

/** 详情页大封面：2:3 固定槽位。 */
class DetailCover <: Widget {
    private let state: AppState
    private var frame = Rect.zero()

    init(state: AppState) {
        this.state = state
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(180.0, 270.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawBookCover(ctx, state, state.detailCover.value, frame, 10.0)
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

/** 格式徽标（可点选，选中项用强调色描边）。 */
class FormatChip <: Widget {
    private let extensionText: String
    private let sizeText: String
    private let selected: Bool
    private let onTap: () -> Unit
    private var frame = Rect.zero()
    private var hot = false

    init(extensionText: String, sizeText: String, selected: Bool, onTap: () -> Unit) {
        this.extensionText = extensionText
        this.sizeText = sizeText
        this.selected = selected
        this.onTap = onTap
        emit(this)
    }

    private func label(ctx: UiContext): String {
        if (sizeText.isEmpty()) {
            extensionText
        } else {
            "${extensionText} · ${sizeText}"
        }
    }

    public func measure(ctx: UiContext, _: Size): Size {
        let width = ctx.renderer.textWidth(label(ctx),
            pointSize: selineTheme().fontLabel, font: None<String>)
        Size(width + 24.0, 30.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let theme = selineTheme()
        let palette = theme.palette
        let fill = if (selected) { palette.accentSoft } else if (hot) {
            palette.surfaceHover
        } else {
            palette.surfaceSunken
        }
        paintSurface(ctx.renderer, frame, fill, 8.0,
            border: if (selected) { palette.accent } else { palette.border })
        paintText(ctx.renderer, label(ctx), frame, if (selected) {
            palette.accent
        } else {
            palette.text
        }, theme.fontLabel, align: SelineTextAlign.Center)
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseMove(x, y) =>
                hot = frame.contains(x, y)
                false
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                frame.contains(x, y)
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    onTap()
                    true
                } else {
                    false
                }
            case _ => false
        }
    }

    public func isFlexible(): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }
}
