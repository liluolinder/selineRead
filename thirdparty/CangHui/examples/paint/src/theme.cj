/*
 * 画板的草木绿主题与画笔调色板。
 */
package chui_paint

import chui.{Color, Theme}

/** 可选画笔颜色，从冷到暖排列，方便在色板上一眼定位。 */
let PALETTE = [
    Color.rgb(38, 70, 104),
    Color.rgb(41, 121, 209),
    Color.rgb(34, 160, 100),
    Color.rgb(238, 160, 38),
    Color.rgb(224, 76, 76),
    Color.rgb(146, 84, 201)
]

/** 初始画笔颜色：调色板中的品蓝，在白色画布上辨识度最高。 */
let DEFAULT_BRUSH_COLOR = PALETTE[1]

/** 空画布提示文字的灰绿色：贴近主题底色，暗示这是提示而非已落笔内容。 */
let CANVAS_HINT_COLOR = Color.rgb(120, 142, 124)

func paintTheme(): Theme {
    Theme(
        bg: Color.rgb(241, 246, 242),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(202, 218, 203),
        text: Color.rgb(25, 36, 27),
        mutedText: Color.rgb(94, 111, 95),
        accent: Color.rgb(28, 132, 84),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(198, 65, 72),
        field: Color.rgb(251, 253, 250),
        fieldActive: Color.rgb(230, 247, 237),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(212, 242, 225),
        shadow: Color.rgba(18, 54, 31, 26),
        radius: 16.0,
        controlRadius: 12.0
    )
}
