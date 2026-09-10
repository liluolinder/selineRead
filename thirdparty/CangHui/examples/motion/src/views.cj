/*
 * 缓动实验室视图层：标题 + 自定义 MotionLab 轨道面板 + 播放/复位按钮。
 *
 * MotionLab 逐帧推进各轨道的 Animator；播放按钮翻转目标，所有轨道随之朝 0 或 1 缓动。
 */
package chui_motion

import chui.{Button, ButtonRole, CrossAxisAlignment, FontSizes, HStack, Label, LengthUnits, Panel, Spacer, VStack}

func motionView(model: MotionModel): Unit {
    VStack {
        header()
        Panel {
            MotionLab(model.tracks, model.playing.value)
        }.contentPadding(16.vp).flex()
        controls(model)
    }.spacing(14.vp).padding(20.vp)
}

private func header(): Unit {
    VStack {
        Label("缓动实验室").fontSize(FontSizes.TITLE).bold()
        Label("七条轨道共享同一时长，各用一种缓动曲线；播放对比运动分布，回弹会越过终点再回落").muted()
            .fontSize(FontSizes.CAPTION).wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func controls(model: MotionModel): Unit {
    HStack {
        Button(model.playLabel(), {=> model.toggle()}).role(ButtonRole.Primary)
        Label("Animator(duration: 900ms) + Easing").muted().fontSize(FontSizes.CAPTION)
        Spacer()
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}
