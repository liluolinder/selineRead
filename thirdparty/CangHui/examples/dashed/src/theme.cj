/*
 * 虚线边框主题：清爽浅色。令牌集中于此。
 */
package chui_dashed

import chui.{Color, Theme}

func dashedTheme(): Theme {
    Theme(
        bg: Color.rgb(245, 247, 250),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(226, 230, 237),
        text: Color.rgb(28, 34, 44),
        mutedText: Color.rgb(120, 130, 144),
        accent: Color.rgb(70, 104, 210),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(204, 78, 66),
        field: Color.rgb(240, 243, 249),
        fieldActive: Color.rgb(226, 234, 250),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 234, 250),
        shadow: Color.rgba(30, 42, 66, 22),
        radius: 12.0,
        controlRadius: 9.0
    )
}

// 虚线颜色令牌。
let DASH_ACCENT = Color.rgb(70, 104, 210)
let DASH_MUTED = Color.rgb(150, 160, 176)
