/*
 * 逐角圆角示例主题：清爽浅色，靛蓝“我方”气泡。令牌集中于此。
 */
package chui_corners

import chui.{Color, Theme}

func cornersTheme(): Theme {
    Theme(
        bg: Color.rgb(244, 246, 250),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(228, 232, 239),
        text: Color.rgb(28, 34, 44),
        mutedText: Color.rgb(120, 130, 144),
        accent: Color.rgb(64, 108, 220),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(204, 78, 66),
        field: Color.rgb(240, 243, 249),
        fieldActive: Color.rgb(226, 234, 250),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 232, 250),
        shadow: Color.rgba(30, 42, 66, 22),
        radius: 12.0,
        controlRadius: 9.0
    )
}

// 气泡配色：我方靛蓝底白字，对方白底深字。
let MINE_BG = Color.rgb(64, 108, 220)
let MINE_TEXT = Color.rgb(255, 255, 255)
let OTHER_BG = Color.rgb(255, 255, 255)
let OTHER_TEXT = Color.rgb(28, 34, 44)

// 底部输入条底色（只圆上面两角，如自底升起的抽屉）。
let BAR_BG = Color.rgb(233, 237, 245)
