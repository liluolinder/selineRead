/*
 * 青绿山水的确定性几何与设色：山脊线、层次色板与点景（松、舟、飞鸟、涟漪）的位置表。
 *
 * 全部为纯函数与固定常量——同一画布尺寸永远画出同一幅画（快照可回归），窗口拉伸时山川
 * 随宽高连续重排。构图要点：
 *  - 山脊 = 三组正弦叠加经「峰锐谷缓」幂次整形，再乘一条沿卷轴起伏的**聚散包络**——山势
 *    有聚有散、群峰之间留出低谷，五重山各用不同的包络频相与锐度，破除彼此雷同；
 *  - 近两重山各设一座**主峰**（高斯隆起，近景主峰落在黄金分割附近），如千里江山图的主宾之势；
 *  - 水线横贯（0.80 画高）：远三重山立于水后，近两重山的低谷沉入水下——江水由此**穿过群山**，
 *    山群成岛、岸线随山势弯转。
 */
package chui_cangcui

import chui.Color
import std.math.{exp, pow, sin}

// 一重山的形与色：基线/振幅（占画高比例）、两组正弦频相、聚散包络频相、峰形锐度、
// 主峰（位置/宽度/高度，height 为 0 表示无主峰）、罩顶石青与铺底石绿。
struct MountainLayer {
    let baseFrac: Float64
    let ampFrac: Float64
    let f1: Float64
    let p1: Float64
    let f2: Float64
    let p2: Float64
    let envF: Float64
    let envP: Float64
    let sharpExp: Float64
    let peakT: Float64
    let peakW: Float64
    let peakAmp: Float64
    let cap: Color
    let base: Color

    init(
        baseFrac!: Float64,
        ampFrac!: Float64,
        f1!: Float64,
        p1!: Float64,
        f2!: Float64,
        p2!: Float64,
        envF!: Float64,
        envP!: Float64,
        sharpExp!: Float64,
        peakT!: Float64,
        peakW!: Float64,
        peakAmp!: Float64,
        cap!: Color,
        base!: Color
    ) {
        this.baseFrac = baseFrac
        this.ampFrac = ampFrac
        this.f1 = f1
        this.p1 = p1
        this.f2 = f2
        this.p2 = p2
        this.envF = envF
        this.envP = envP
        this.sharpExp = sharpExp
        this.peakT = peakT
        this.peakW = peakW
        this.peakAmp = peakAmp
        this.cap = cap
        this.base = base
    }
}

// 五重山，由远及近：远山圆浑淡若烟霭，近山峭拔、设色浓实；近两重带主峰。
let MOUNTAINS: Array<MountainLayer> = [
    MountainLayer(baseFrac: 0.52, ampFrac: 0.10, f1: 8.0, p1: 0.7, f2: 21.0, p2: 2.1,
        envF: 1.7, envP: 0.9, sharpExp: 0.78, peakT: 0.0, peakW: 1.0, peakAmp: 0.0,
        cap: Color.rgba(157, 185, 193, 115), base: Color.rgba(168, 196, 178, 115)),
    MountainLayer(baseFrac: 0.60, ampFrac: 0.16, f1: 6.4, p1: 3.8, f2: 15.0, p2: 0.4,
        envF: 1.3, envP: 3.6, sharpExp: 0.72, peakT: 0.0, peakW: 1.0, peakAmp: 0.0,
        cap: Color.rgba(127, 166, 176, 150), base: Color.rgba(139, 180, 157, 150)),
    MountainLayer(baseFrac: 0.70, ampFrac: 0.26, f1: 5.0, p1: 2.2, f2: 12.0, p2: 3.3,
        envF: 1.1, envP: 2.4, sharpExp: 0.62, peakT: 0.82, peakW: 0.09, peakAmp: 0.10,
        cap: Color.rgba(94, 147, 162, 190), base: Color.rgba(107, 162, 134, 190)),
    MountainLayer(baseFrac: 0.94, ampFrac: 0.46, f1: 3.8, p1: 5.0, f2: 10.0, p2: 5.1,
        envF: 1.0, envP: 5.4, sharpExp: 0.55, peakT: 0.62, peakW: 0.075, peakAmp: 0.20,
        cap: Color.rgba(69, 127, 147, 228), base: Color.rgba(78, 142, 112, 228)),
    MountainLayer(baseFrac: 1.10, ampFrac: 0.60, f1: 2.9, p1: 1.2, f2: 8.0, p2: 1.9,
        envF: 0.8, envP: 4.1, sharpExp: 0.50, peakT: 0.38, peakW: 0.065, peakAmp: 0.34,
        cap: Color.rgb(47, 107, 132), base: Color.rgb(56, 126, 94))
]

// 绢本底色、江水设色、雾带与墨色点景。
let SILK_TOP = Color.rgb(238, 227, 194)
let SILK_HORIZON = Color.rgb(227, 210, 166)
let WATER_TOP = Color.rgb(122, 162, 138)
let WATER_DEEP = Color.rgb(74, 120, 100)
let WAVE_INK = Color.rgba(236, 226, 192, 120)
let MIST = Color.rgba(242, 233, 207, 92)
let INK = Color.rgb(35, 66, 58)
let SEAL_RED = Color.rgb(176, 58, 42)
let SEAL_TEXT = Color.rgb(245, 234, 214)

// 水线（占画高比例）：其上是天与远山，其下的近山低谷沉入江中。
let WATER_FRAC: Float64 = 0.80

/*
 * 第 layer 重山在横向位置 x 处的山脊 y（屏幕坐标，向下为正）。
 * s ∈ [0,1] 为叠加波形经 `1-(1-s)^锐度` 整形；包络 env 控制山势聚散（0.35..1.0，
 * 谷不全平）；主峰为高斯隆起。y = (基线 - 振幅×包络×整形值 - 主峰) × 画高。
 */
func ridgeY(layer: Int64, x: Float32, w: Float32, h: Float32): Float32 {
    let m = MOUNTAINS[layer]
    let t = Float64(x) / Float64(max(w, 1.0))
    let s1 = sin(t * m.f1 * 6.28318 + m.p1)
    let s2 = sin(t * m.f2 * 6.28318 + m.p2)
    let s3 = sin(t * m.f1 * 12.56636 + m.p1 + 1.3)
    let s = (0.66 * s1 + 0.20 * s2 + 0.14 * s3 + 1.0) / 2.0
    let sharp = 1.0 - pow(1.0 - s, m.sharpExp)
    let env = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * m.envF * 6.28318 + m.envP))
    let d = t - m.peakT
    let boost = m.peakAmp * exp(-(d * d) / (2.0 * m.peakW * m.peakW))
    Float32(Float64(h) * (m.baseFrac - m.ampFrac * env * sharp - boost))
}

// 松针簇的横向位置（占宽比例）：中景簇植于第 4 重山、近景簇植于第 5 重山；
// 落点是否成树由绘制期按「山脊须高出水线」动态判定（山谷沉水处不植树）。
let PINE_SPOTS: Array<Float64> = [0.075, 0.115, 0.300, 0.465, 0.590, 0.775, 0.910]
let PINE_SPOTS_NEAR: Array<Float64> = [0.055, 0.245, 0.355, 0.420, 0.520, 0.700, 0.955]

// 江上小舟的候选位置（占宽比例）：仅当该处两重近山都沉于水下（开阔江面）才落舟。
let BOAT_SPOTS: Array<Float64> = [0.130, 0.220, 0.545, 0.660, 0.820]

// 天际飞鸟（横向、纵向占比），人字两笔。
let BIRD_SPOTS: Array<(Float64, Float64)> = [(0.175, 0.295), (0.205, 0.270), (0.590, 0.215), (0.615, 0.240)]

// 涟漪弧的（横向占比, 行下标）表：行错落铺出网巾纹式的水面。
let RIPPLE_SPOTS: Array<(Float64, Int64)> = [
    (0.06, 0), (0.31, 0), (0.58, 0), (0.87, 0),
    (0.12, 1), (0.27, 1), (0.44, 1), (0.71, 1), (0.95, 1),
    (0.10, 2), (0.38, 2), (0.52, 2), (0.66, 2), (0.90, 2),
    (0.21, 3), (0.48, 3), (0.79, 3)
]

// 流水纹（S 形长曲线）的起点（横向占比）与所在行：穿行于山群之间的水道里。
let STREAM_SPOTS: Array<(Float64, Int64)> = [(0.16, 0), (0.47, 1), (0.72, 0), (0.88, 2)]
