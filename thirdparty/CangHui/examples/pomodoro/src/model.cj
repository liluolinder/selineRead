/*
 * 番茄钟状态：阶段（专注/休息）、剩余毫秒、运行开关、完成计数与时长设置。
 *
 * tick 只在运行中扣减时间，扣到零自动切换阶段并弹通知；跳过与重置是同一套阶段机的
 * 手动入口。时长设置在空闲的阶段起点被修改时，剩余时间同步跟进（观察者模式）。
 */
package chui_pomodoro

import chui.{State, StateObservation, ToastKind, Toaster}

let MS_PER_MINUTE: Int64 = 60_000

class PomodoroModel {
    let focusMinutes = State<Int64>(25)
    let breakMinutes = State<Int64>(5)
    let running = State<Bool>(false)
    let inBreak = State<Bool>(false)
    let remainingMs: State<Int64>
    let completed = State<Int64>(0)
    let toaster = Toaster()
    // 观察需持有引用才存活（同 catalog 的分类观察惯例）；init 内闭包不得捕获 this，
    // 故由 newPomodoroModel 工厂在构造完成后 wire。
    private var focusObservation: ?StateObservation<Int64> = None
    private var breakObservation: ?StateObservation<Int64> = None

    init() {
        this.remainingMs = State<Int64>(25 * MS_PER_MINUTE)
    }

    // 空闲且停在对应阶段起点时修改时长，剩余时间跟着新设置走；运行中改动不打断当前段。
    func wire(): Unit {
        focusObservation = focusMinutes.observe({prev, cur =>
            if (prev != cur && !running.value && !inBreak.value) {
                remainingMs.value = cur * MS_PER_MINUTE
            }
        })
        breakObservation = breakMinutes.observe({prev, cur =>
            if (prev != cur && !running.value && inBreak.value) {
                remainingMs.value = cur * MS_PER_MINUTE
            }
        })
    }

    // 当前阶段的总时长（毫秒）。
    func phaseTotalMs(): Int64 {
        if (inBreak.value) {
            breakMinutes.value * MS_PER_MINUTE
        } else {
            focusMinutes.value * MS_PER_MINUTE
        }
    }

    // 剩余占比（0..1），驱动进度环随时间消退。
    func fraction(): Float32 {
        let total = phaseTotalMs()
        if (total <= 0) {
            return 0.0
        }
        let ratio = Float32(remainingMs.value) / Float32(total)
        if (ratio < 0.0) {
            0.0
        } else if (ratio > 1.0) {
            1.0
        } else {
            ratio
        }
    }

    // 每帧扣减；到点自动进入下一阶段并弹通知。
    func tick(deltaMs: Int64): Unit {
        if (!running.value) {
            return
        }
        let next = remainingMs.value - deltaMs
        if (next > 0) {
            remainingMs.value = next
            return
        }
        advancePhase(notify: true)
    }

    // 手动跳过当前阶段（不弹通知，不计为完成的番茄）。
    func skip(): Unit {
        if (inBreak.value) {
            inBreak.value = false
            remainingMs.value = focusMinutes.value * MS_PER_MINUTE
        } else {
            inBreak.value = true
            remainingMs.value = breakMinutes.value * MS_PER_MINUTE
        }
    }

    func toggleRun(): Unit {
        running.value = !running.value
    }

    // 回到全新的专注段起点并停表。
    func reset(): Unit {
        running.value = false
        inBreak.value = false
        remainingMs.value = focusMinutes.value * MS_PER_MINUTE
    }

    func phaseName(): String {
        if (inBreak.value) {
            "休息"
        } else {
            "专注"
        }
    }

    func runLabel(): String {
        if (running.value) {
            "暂停"
        } else {
            "开始"
        }
    }

    // 阶段到点：专注结束计一个番茄并进入休息，休息结束回到专注。
    private func advancePhase(notify!: Bool): Unit {
        if (inBreak.value) {
            inBreak.value = false
            remainingMs.value = focusMinutes.value * MS_PER_MINUTE
            if (notify) {
                toaster.show("休息结束，开始下一个专注", kind: ToastKind.Info)
            }
        } else {
            completed.value = completed.value + 1
            inBreak.value = true
            remainingMs.value = breakMinutes.value * MS_PER_MINUTE
            if (notify) {
                toaster.show("第 ${completed.value} 个番茄完成，休息 ${breakMinutes.value} 分钟", kind: ToastKind.Success)
            }
        }
    }
}

// 构造 + 接线的标准入口：应用与测试都从这里拿模型。
func newPomodoroModel(): PomodoroModel {
    let model = PomodoroModel()
    model.wire()
    model
}

// 剩余毫秒 → mm:ss；向上取整到秒，起步即显示整分（25:00 而非 24:59）。
func formatClock(ms: Int64): String {
    let clamped = if (ms < 0) {
        0
    } else {
        ms
    }
    let totalSec = (clamped + 999) / 1000
    "${pad2(totalSec / 60)}:${pad2(totalSec % 60)}"
}

func pad2(value: Int64): String {
    if (value < 10) {
        "0${value}"
    } else {
        "${value}"
    }
}
