/*
 * 滚轮惯性（momentum scrolling）。
 *
 * chui 的 `ScrollView` 只做"滚轮 → 目标位置 + 缓动动画"，松手就会立刻停下。
 * 桌面端更自然的手感是：滚轮给一个初速度，之后继续滑行并逐渐衰减（惯性）。
 *
 * 做法：由全窗口覆盖层（`WindowResizeEdges`，本来就旁听所有鼠标事件）记录滚轮量，
 * 累加成"速度"，再在每帧回调里把速度叠加到当前页面的滚动偏移 `State<Float32>` 上。
 * 不改、不包 `ScrollView` —— 事件仍然交给 chui 处理，滚动条拖动、边界夹紧、
 * 命中判断全部还是原逻辑。
 *
 * 边界处理：ScrollView 到顶/到底会把偏移夹住（写了但读回来没变），此时速度清零，
 * 不会出现"到底了还在抖"。
 */
package seline_read

import std.math.abs
import std.env.getVariable
import chui.*

/** 一个滚轮格在基础位移之外额外带来的初速系数。 */
private let INERTIA_GAIN: Float32 = 0.10
/** 每 16.7ms 速度衰减比例（越小停得越快）。 */
private let INERTIA_DECAY: Float32 = 0.82
/** 低于该速度（px/帧）视为停止。 */
private let INERTIA_MIN_SPEED: Float32 = 0.5
/** 速度上限，防止连续滚动后飞太远。 */
private let INERTIA_MAX_SPEED: Float32 = 120.0
/** 惯性使用的滚轮步长（与 `appScrollOptions` 的基础步长保持一致）。 */
private let INERTIA_STEP: Float32 = 72.0

/** 验收探针开关（`SELINE_READ_INERTIA_TEST=1`）。 */
private var inertiaProbeFlag: Int64 = -1

func inertiaProbeEnabled(): Bool {
    if (inertiaProbeFlag < 0) {
        inertiaProbeFlag = if ((getVariable("SELINE_READ_INERTIA_TEST") ?? "") == "1") { 1 } else { 0 }
    }
    inertiaProbeFlag == 1
}

/** 惯性滚动状态：全局一份就够了（同一时间只有一个页面在滚）。 */
class ScrollInertia {
    private var target: ?State<Float32> = None
    private var velocity: Float32 = 0.0
    private var lastOffset: Float32 = 0.0

    /** 滚轮事件：累积初速（`wheelY` 为正表示内容下移/视图上滚）。 */
    func onWheel(offset: State<Float32>, wheelY: Float32): Unit {
        target = offset
        lastOffset = offset.value
        var next = velocity + (-wheelY) * INERTIA_STEP * INERTIA_GAIN
        if (next > INERTIA_MAX_SPEED) {
            next = INERTIA_MAX_SPEED
        } else if (next < -INERTIA_MAX_SPEED) {
            next = -INERTIA_MAX_SPEED
        }
        velocity = next
    }

    /** 当前速度（验收/诊断用）。 */
    func currentVelocity(): Float32 {
        velocity
    }

    /** 还在滑行吗（供 `keepsAlive` 判断要不要继续出帧）。 */
    func animating(): Bool {
        if (abs(velocity) < INERTIA_MIN_SPEED) {
            return false
        }
        match (target) {
            case Some(_) => true
            case None => false
        }
    }

    /**
     * 推进一帧；返回是否还需要继续出帧。
     *
     * `deltaMs` 用真实帧间隔做时间归一并做衰减，掉帧时滑行距离不会变短。
     */
    func tick(deltaMs: Float32): Bool {
        if (abs(velocity) < INERTIA_MIN_SPEED) {
            velocity = 0.0
            return false
        }
        let offset = match (target) {
            case Some(value) => value
            case None =>
                velocity = 0.0
                return false
        }
        let current = offset.value
        // 说明：基础滚动是 chui 的短缓动，和惯性的写入同向叠加，不需要额外守卫。
        // 到顶/到底时 ScrollView 会把偏移夹住，表现为"写了但没变化"，此时停住。
        lastOffset = current
        // 按 16.7ms 的子步推进：帧间隔可能是 8ms 也可能是 200ms（空闲后突然出帧），
        // 一次性乘大系数会让衰减变负、方向翻转，子步进则始终稳定。
        var remaining = if (deltaMs > 0.0) { deltaMs } else { Float32(16.6667) }
        var next = current
        var steps: Int64 = 0
        while (remaining > 0.0 && abs(velocity) >= INERTIA_MIN_SPEED && steps < 8) {
            let step = if (remaining > 16.6667) { Float32(16.6667) } else { remaining }
            next += velocity * (step / 16.6667)
            velocity = velocity * INERTIA_DECAY
            remaining -= step
            steps += 1
        }
        if (next < 0.0) {
            next = 0.0
            velocity = 0.0
        }
        offset.value = next
        // 到边界：夹住后本帧读到的值与写入值不符/未变化 → 立刻停，避免"到底还滑"
        if (abs(offset.value - current) < 0.01 && abs(velocity) > INERTIA_MIN_SPEED) {
            velocity = 0.0
        }
        lastOffset = offset.value
        abs(velocity) >= INERTIA_MIN_SPEED
    }
}

/** 全局惯性状态（由 `main` 的帧回调推进）。 */
let scrollInertia: ScrollInertia = ScrollInertia()

/**
 * 给 `ScrollView` 旁听滚轮事件并驱动惯性。
 *
 * 不拦截事件：`handle` 先记录速度，再把事件原样交给内部的 `ScrollView`，
 * 所以基础滚动、边界夹紧、滚动条拖动都保持 chui 原本的行为。
 */
