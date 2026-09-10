/*
 * 高亮示例主题：清爽浅色 + 琥珀色 <mark> 高亮。令牌集中于此。
 */
package chui_highlight

import chui.{Color, Theme}

func highlightTheme(): Theme {
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

// <mark> 高亮底色（温暖的琥珀）与其上的深色文字，保证对比可读。
let MARK_COLOR = Color.rgb(255, 224, 130)
let MATCH_TEXT_COLOR = Color.rgb(60, 44, 12)
