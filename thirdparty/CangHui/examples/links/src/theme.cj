/*
 * 链接示例主题：清爽浅色，靛蓝链接色。令牌集中于此。
 */
package chui_links

import chui.{Color, Theme}

func linksTheme(): Theme {
    Theme(
        bg: Color.rgb(244, 246, 250),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(228, 232, 239),
        text: Color.rgb(28, 34, 44),
        mutedText: Color.rgb(120, 130, 144),
        accent: Color.rgb(64, 108, 220), // accent（链接色）
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

// 链接文字色（与强调一致的靛蓝）。
let LINK_COLOR = Color.rgb(64, 108, 220)
