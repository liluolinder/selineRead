/*
 * 邮件客户端视图层：工具栏（标题 + 计数 + 搜索）+ 左列表右阅读的双栏。
 *
 * 列表栏 = 搜索过滤后的 MailRow 竖排（未读加粗带圆点，点击选中）；阅读栏 = 主题、发件人
 * 元信息（RichText 混排）、未读徽标与操作按钮、逐段换行的正文。
 */
package chui_mail

import chui.{Axis, Badge, BadgeKind, Button, CrossAxisAlignment, Divider, FontSizes, HStack, Label, LengthUnits,
    Panel, RichSpan, RichText, ScrollView, Spacer, SplitView, TextAlign, TextField, VStack}

func mailView(model: MailModel): Unit {
    VStack {
        toolbar(model)
        SplitView(axis: Axis.Horizontal, initialRatio: 0.42, minFirst: 280.0, minSecond: 320.0,
            first: {=> listPane(model)}) {
            => readingPane(model)
        }
    }.spacing(12.vp).padding(16.vp)
}

private func toolbar(model: MailModel): Unit {
    HStack {
        VStack {
            Label("收件箱").fontSize(FontSizes.TITLE).bold()
            RichText([
                RichSpan.text("${model.visible().size}").bold().fontSize(13.0),
                RichSpan.muted(" 封 · ").fontSize(13.0),
                RichSpan.text("${model.unreadCount()}").bold().fontSize(13.0),
                RichSpan.muted(" 未读").fontSize(13.0)
            ])
        }.spacing(3.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
        Spacer()
        Label("搜索").muted().fontSize(FontSizes.CAPTION)
        TextField(model.query).width(230.vp)
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

private func listPane(model: MailModel): Unit {
    Panel {
        if (model.visible().isEmpty()) {
            VStack {
                Spacer()
                Label("没有匹配「${model.query.value}」的邮件").muted().textAlign(TextAlign.Center)
                Spacer()
            }
        }
        if (!model.visible().isEmpty()) {
            ScrollView {
                VStack {
                    for (mail in model.visible()) {
                        MailRow(mail, model.isUnread(mail.id), model.selectedId.value == mail.id,
                            {=> model.select(mail.id)})
                    }
                }.spacing(2.vp)
            }
        }
    }.contentPadding(6.vp)
}

private func readingPane(model: MailModel): Unit {
    Panel {
        match (model.selectedMail()) {
            case Some(mail) => readingBody(model, mail)
            case None =>
                VStack {
                    Spacer()
                    Label("从左侧选择一封邮件").muted().textAlign(TextAlign.Center)
                    Spacer()
                }
        }
    }.contentPadding(18.vp)
}

private func readingBody(model: MailModel, mail: Mail): Unit {
    VStack {
        Label(mail.subject).fontSize(FontSizes.TITLE).bold().wrap()
        HStack {
            RichText([
                RichSpan.text(mail.sender).bold().fontSize(14.0),
                RichSpan.muted("  ${mail.address}").fontSize(12.0)
            ])
            Spacer()
            Label(mail.time).muted().fontSize(FontSizes.CAPTION)
        }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
        HStack {
            if (model.isUnread(mail.id)) {
                Badge("未读", kind: BadgeKind.Accent)
            }
            Spacer()
            Button("标为未读", {=> model.markSelectedUnread()}).enabled(!model.isUnread(mail.id))
            Button("归档", {=> model.archiveSelected()})
        }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
        Divider()
        ScrollView {
            VStack {
                for (paragraph in mail.paragraphs) {
                    Label(paragraph).wrap()
                }
            }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Start)
        }.flex()
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Stretch)
}
