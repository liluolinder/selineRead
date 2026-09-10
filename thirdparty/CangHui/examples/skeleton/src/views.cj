/*
 * 骨架屏视图层：标题 + 切换按钮 + （骨架行 | 文章列表）+ 状态条。
 *
 * 未加载时列出共享一个 Pulse 的骨架行（同步呼吸），加载后换成真实文章卡；两态行数一致，切换不跳高度。
 */
package chui_skeleton

import chui.{Button, ButtonRole, CrossAxisAlignment, FontSizes, HStack, Icon, Label, LengthUnits, Panel, ScrollView,
    Spacer, VStack}

func skeletonView(model: SkeletonModel): Unit {
    VStack {
        header(model)
        ScrollView {
            VStack {
                if (model.loaded.value) {
                    for (article in ARTICLES) {
                        articleCard(article)
                    }
                } else {
                    for (row in 0..skeletonRows()) {
                        skeletonCard(model, row)
                    }
                }
            }.spacing(10.vp)
        }.flex()
        statusBar(model)
    }.spacing(12.vp).padding(20.vp)
}

private func header(model: SkeletonModel): Unit {
    HStack {
        VStack {
            Label("骨架屏").fontSize(FontSizes.TITLE).bold()
            Label("Pulse 驱动的加载占位：内容未到先给结构，底色缓慢呼吸").muted().fontSize(FontSizes.CAPTION)
        }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
        Spacer()
        Button(model.buttonLabel(), {=> model.toggle()}).role(ButtonRole.Primary)
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

private func skeletonCard(model: SkeletonModel, row: Int64): Unit {
    Panel {
        SkeletonRow(model.pulse, row)
    }.contentPadding(14.vp)
}

private func articleCard(article: Article): Unit {
    Panel {
        HStack {
            Icon(article.icon).foregroundColor(article.iconColor).iconSize(20.vp)
            VStack {
                Label(article.title).fontSize(FontSizes.BODY)
                Label(article.summary).muted().fontSize(FontSizes.CAPTION)
            }.spacing(3.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
            Spacer()
        }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center)
    }.contentPadding(14.vp)
}

private func statusBar(model: SkeletonModel): Unit {
    Panel {
        Label(model.statusText()).fontSize(FontSizes.CAPTION).wrap()
    }.contentPadding(12.vp)
}
