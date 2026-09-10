/*
 * 番茄钟视图层：大进度环（内嵌剩余时间）+ 控制按钮 + 时长设置 + 完成统计 + 通知层。
 *
 * 进度环显示剩余占比、随时间消退；到点自动切换阶段，ToastLayer 叠在最上层，
 * 通知从右下滑入。时长设置仅停表时可调（整卡 enabled 门控）。
 */
package chui_pomodoro

import chui.{Button, ButtonRole, CrossAxisAlignment, FontSizes, HStack, Label, LengthUnits, Panel, ProgressRing,
    RichSpan, RichText, Spacer, Stepper, ToastLayer, VStack, ZStack}

func pomodoroView(model: PomodoroModel): Unit {
    ZStack {
        VStack {
            header(model)
            timerCard(model)
            settingsCard(model)
            statsBar(model)
            Spacer()
        }.spacing(14.vp).padding(20.vp)
        ToastLayer(model.toaster)
    }
}

private func header(model: PomodoroModel): Unit {
    VStack {
        Label("番茄钟").fontSize(FontSizes.TITLE).bold()
        Label("专注 ${model.focusMinutes.value} 分钟、休息 ${model.breakMinutes.value} 分钟；到点自动切换并通知").muted()
            .fontSize(FontSizes.CAPTION)
    }.spacing(3.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func timerCard(model: PomodoroModel): Unit {
    Panel {
        VStack {
            ZStack {
                ProgressRing(model.fraction(), diameter: 200.0, thickness: 13.0, showLabel: false)
                VStack {
                    Spacer()
                    Label(formatClock(model.remainingMs.value)).fontSize(FontSizes.DISPLAY).bold()
                    Label(model.phaseName()).muted().fontSize(FontSizes.CAPTION)
                    Spacer()
                }.spacing(2.vp).crossAxisAlignment(CrossAxisAlignment.Center)
            }.height(210.vp)
            HStack {
                Button(model.runLabel(), {=> model.toggleRun()}).role(ButtonRole.Primary)
                Button("跳过阶段", {=> model.skip()})
                Button("重置", {=> model.reset()})
            }.spacing(10.vp).hug()
        }.spacing(18.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.contentPadding(24.vp).hug()
}

private func settingsCard(model: PomodoroModel): Unit {
    Panel {
        HStack {
            VStack {
                Label("专注时长（分钟）").muted().fontSize(FontSizes.CAPTION)
                Stepper(model.focusMinutes, key: "focus", lower: 15, upper: 60, step: 5)
            }.spacing(6.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
            Spacer()
            VStack {
                Label("休息时长（分钟）").muted().fontSize(FontSizes.CAPTION)
                Stepper(model.breakMinutes, key: "break", lower: 3, upper: 15)
            }.spacing(6.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
        }.spacing(16.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.contentPadding(16.vp).hug().enabled(!model.running.value)
}

private func statsBar(model: PomodoroModel): Unit {
    Panel {
        HStack {
            RichText([
                RichSpan.text("${model.completed.value}").bold().fontSize(26.0),
                RichSpan.muted(" 个番茄已完成").fontSize(13.0)
            ])
            Spacer()
            Label(sessionHint(model)).muted().fontSize(FontSizes.CAPTION)
        }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.contentPadding(14.vp).hug()
}

// 状态条右侧的一句话提示：随运行态与阶段变化。
func sessionHint(model: PomodoroModel): String {
    if (model.running.value) {
        "${model.phaseName()}中 · 点「暂停」可随时停表"
    } else if (model.completed.value == 0) {
        "点「开始」进入第一个专注段"
    } else {
        "已暂停 · 设置在停表时可调"
    }
}
