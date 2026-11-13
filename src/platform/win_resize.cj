/*
 * 无边框窗口「拖边缩放」的命中码。
 *
 * 值是 WinUser.h 的 HT* 常量；UI 层（shell.cj 的 WindowResizeEdges）用它们
 * 标记这次按下命中窗口的哪条边/哪个角，再据此决定尺寸和位置怎么变。
 */
package seline_read.platform

/** 左边。 */
public let HT_LEFT: Int64 = 10
/** 右边。 */
public let HT_RIGHT: Int64 = 11
/** 上边。 */
public let HT_TOP: Int64 = 12
/** 左上角。 */
public let HT_TOPLEFT: Int64 = 13
/** 右上角。 */
public let HT_TOPRIGHT: Int64 = 14
/** 下边。 */
public let HT_BOTTOM: Int64 = 15
/** 左下角。 */
public let HT_BOTTOMLEFT: Int64 = 16
/** 右下角。 */
public let HT_BOTTOMRIGHT: Int64 = 17
