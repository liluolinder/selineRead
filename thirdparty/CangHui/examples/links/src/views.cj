/*
 * 链接视图层：标题 + 通知卡列表（每条一行富文本，链接片段可点击）+ 底部详情条。
 *
 * 每条通知由片段拼成 RichText：链接片段用链接色 + 下划线 + onTap（点击设为已选择），非链接片段为常规文字。
 */
package chui_links

import chui.{CrossAxisAlignment, FontSizes, Label, LengthUnits, Panel, RichSpan, RichText, ScrollView, VStack}
import std.collection.ArrayList

func linksView(model: LinksModel): Unit {
    VStack {
        header()
        ScrollView {
            VStack {
                for (i in 0..model.notices.size) {
                    noticeRow(model, i)
                }
            }.spacing(10.vp)
        }.flex()
        detailBar(model)
    }.spacing(12.vp).padding(20.vp)
}

private func header(): Unit {
    VStack {
        Label("可点击链接").fontSize(FontSizes.TITLE).bold()
        Label("每条通知里的人名、文件、频道是 RichSpan.onTap 链接：悬停变手型、点击运行回调；也可 Tab 聚焦、Enter/空格激活").muted()
            .fontSize(FontSizes.CAPTION).wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func noticeRow(model: LinksModel, index: Int64): Unit {
    let notice = model.notices[index]
    let spans = ArrayList<RichSpan>()
    spans.add(RichSpan.icon(notice.icon, color: notice.iconColor))
    spans.add(RichSpan.text("  "))
    for (segment in notice.segments) {
        if (segment.isLink) {
            // Bind a fresh label per iteration so each link's closure captures its own text.
            let label = segment.text
            spans.add(RichSpan.text(label, color: LINK_COLOR).underline().onTap({=> model.select(label)}))
        } else {
            spans.add(RichSpan.text(segment.text))
        }
    }
    Panel {
        RichText(spans.toArray(), key: "notice-${index}")
    }.contentPadding(14.vp)
}

private func detailBar(model: LinksModel): Unit {
    Panel {
        Label(model.detailText()).fontSize(FontSizes.BODY)
    }.contentPadding(14.vp)
}
