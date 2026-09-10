/*
 * 虚线边框示例的纯逻辑。
 *
 * 当前虚线参数（实线段/间隔/圆角）拼成一句描述，纯函数便于单测。
 */
package chui_dashed

// 一句话描述当前虚线设置。
func describeDash(dash: Int64, gap: Int64, radius: Int64): String {
    "实线 ${dash} · 间隔 ${gap} · 圆角 ${radius}vp"
}
