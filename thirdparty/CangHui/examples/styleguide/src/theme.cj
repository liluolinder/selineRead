/*
 * 样式指南主题：干净的浅色纸面，靛蓝强调。令牌集中于此。
 */
package chui_styleguide

import chui.{Color, Theme}

func styleguideTheme(): Theme {
    Theme(
        bg: Color.rgb(245, 247, 250),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(226, 230, 237),
        text: Color.rgb(28, 34, 44),
        mutedText: Color.rgb(118, 128, 142),
        accent: Color.rgb(70, 104, 210),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(204, 78, 66),
        field: Color.rgb(240, 243, 249),
        fieldActive: Color.rgb(226, 234, 250),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(222, 231, 250),
        shadow: Color.rgba(30, 42, 66, 24),
        radius: 12.0,
        controlRadius: 9.0
    )
}

// 卡片令牌（高度参考用）。
let CARD_FILL = Color.rgb(255, 255, 255)
let CARD_SHADOW = Color.rgba(28, 40, 66, 74)

// 供示意色块使用的令牌（与主题一致）。
let ACCENT = Color.rgb(70, 104, 210)
let ACCENT_SOFT = Color.rgb(222, 231, 250)
let EDGE = Color.rgb(210, 216, 226)
